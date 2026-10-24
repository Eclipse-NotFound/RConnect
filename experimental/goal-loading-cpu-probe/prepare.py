"""Prepare/check only the external first-loading CPU observer text sources."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/goal-native-loading-probe-driver-01'
TAIL = ROOT / 'experimental/recovery-early-paint-tail-sampler-v3/src'
BASE_PINS = {
    'prepared.json': '562bb57f0640eefb4f89fa2799fd52918baec49cdab42c434808a21c36840ca9',
    'compile.json': '02f8efa0c92a6ee964de0e0c87b360387dedf73c1d03e04b61461bc393875045',
    'timing/EffectsDriver.swf': '877b05dacfca220f69345c3f83b4d8d2cc7796d6d03ea6389682fef7061d474a',
}
TAIL_PINS = {
    'FlashPaintTailSampler.as': 'f0706d7fdff62a0aaeebd1e200e8899a3f534a1d1abb76a56d4a2d4ade3f1601',
    'PaintTailSampler.as': '1d35215b6a24a1dae4e6d5071ab168b1777c9789d96340931417177448b81c61',
}
HOOKS = (
    ('      private var loadingProbe:NativeLoadingProbe;',
     '      private var loadingProbe:NativeLoadingProbe;\n      private var loadingCpu:LoadingCpuProbe;'),
    ('         if(loadingProbe==null)loadingProbe=new NativeLoadingProbe(mod);',
     '         if(loadingProbe==null)loadingProbe=new NativeLoadingProbe(mod);\n         if(loadingCpu==null)loadingCpu=new LoadingCpuProbe(mod,true);'),
    ('         if(loadingProbe!=null)loadingProbe.begin(round,target,at);',
     '         if(loadingProbe!=null)loadingProbe.begin(round,target,at);\n         if(loadingCpu!=null)loadingCpu.begin(round,target,at);'),
    ('         if(loadingProbe!=null)loadingProbe.finish();',
     '         if(loadingProbe!=null)loadingProbe.finish();\n         if(loadingCpu!=null)loadingCpu.finish();'),
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def originals():
    for name, digest in BASE_PINS.items():
        assert sha(BASE / name) == digest, name
    for name, digest in TAIL_PINS.items():
        assert sha(TAIL / name) == digest, name
    prepared, compiled = read(BASE / 'prepared.json'), read(BASE / 'compile.json')
    assert compiled['compiled'] and compiled['inputs_unchanged']
    assert compiled['prepared_sha256'] == BASE_PINS['prepared.json']
    assert compiled['error'] is None and compiled['validation_error'] is None
    assert len(compiled['commands']) == 1 and compiled['commands'][0]['exit_code'] == 0
    assert compiled['commands'][0]['reaped']
    source = {name[6:]: digest for name, digest in prepared['files'].items() if name.startswith('tests/')}
    assert set(source) == {'A22RoomMetrics.as', 'NativeLoadingProbe.as', 'RoomTravelTimingTestDoc.as'}
    for name, digest in source.items():
        assert sha(BASE / 'tests' / name) == digest, name
    return source


def driver_text():
    originals()
    before = (BASE / 'tests/RoomTravelTimingTestDoc.as').read_text('utf8')
    after = before
    for old, new in HOOKS:
        assert after.count(old) == 1, old
        after = after.replace(old, new, 1)
    restored = after
    for old, new in reversed(HOOKS):
        assert restored.count(new) == 1
        restored = restored.replace(new, old, 1)
    assert restored == before
    return after


def diff_text():
    text = ''.join(difflib.unified_diff(
        (BASE / 'tests/RoomTravelTimingTestDoc.as').read_text('utf8').splitlines(True),
        driver_text().splitlines(True), fromfile='probe-driver-01/tests/RoomTravelTimingTestDoc.as',
        tofile='loading-cpu/tests/RoomTravelTimingTestDoc.as'))
    for name in ('LoadingCpuProbe.as', 'FlashPaintTailSampler.as'):
        text += ''.join(difflib.unified_diff([], (HERE / 'tests' / name).read_text('utf8').splitlines(True),
                         fromfile='/dev/null', tofile='loading-cpu/tests/' + name))
    return text


def verify():
    source = originals()
    manifest = read(HERE / 'source-manifest.json')
    assert manifest['kind'] == 'initial-loading-cpu-source-v1'
    assert manifest['prepare_sha256'] == sha(__file__)
    assert manifest['readme_sha256'] == sha(HERE / 'README.md')
    assert manifest['base'] == BASE_PINS and manifest['original_sources'] == source
    assert manifest['sampler_sources'] == TAIL_PINS
    assert manifest['sources'] == {p.name: sha(p) for p in sorted((HERE / 'tests').glob('*.as'))}
    assert set(manifest['sources']) == set(source) | {'LoadingCpuProbe.as', 'FlashPaintTailSampler.as'}
    for name in ('A22RoomMetrics.as', 'NativeLoadingProbe.as'):
        assert (HERE / 'tests' / name).read_bytes() == (BASE / 'tests' / name).read_bytes()
    assert (HERE / 'tests/RoomTravelTimingTestDoc.as').read_text('utf8') == driver_text()
    assert (HERE / 'tests/FlashPaintTailSampler.as').read_bytes() == (TAIL / 'FlashPaintTailSampler.as').read_bytes()
    assert manifest['diff_sha256'] == sha(HERE / 'source.diff')
    assert (HERE / 'source.diff').read_text('utf8') == diff_text()
    cpu = (HERE / 'tests/LoadingCpuProbe.as').read_text('utf8')
    old = (TAIL / 'PaintTailSampler.as').read_text('utf8')
    collect = lambda text: text.split('      private function collect():void {', 1)[1].split('      private function cleanup():void {', 1)[0]
    assert collect(cpu) == collect(old), 'Bounded collector must remain exact v3 text'
    assert 'Event.RENDER,render,false,-2147483000' in (HERE / 'tests/NativeLoadingProbe.as').read_text('utf8')
    assert 'Event.RENDER,beforeRender,false,2147483000' in cpu
    assert 'Event.RENDER,afterRender,false,-2147483001' in cpu
    assert 'row.stopExit==19' in cpu and 'w.game===game' in cpu
    assert 'loc===' not in cpu and '.t_exit=' not in cpu
    assert 'nativeBufferMemoryBounded:false' in cpu
    assert all(token not in cpu for token in ('Math.random(', 'rconnectLoadingView(', '.invalidate(', 'setSamplerCallback('))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check:
        source = originals()
        for name in source:
            destination = HERE / 'tests' / name
            with destination.open('xb') as stream:
                stream.write(driver_text().encode('utf8') if name == 'RoomTravelTimingTestDoc.as'
                             else (BASE / 'tests' / name).read_bytes())
        with (HERE / 'tests/FlashPaintTailSampler.as').open('xb') as stream:
            stream.write((TAIL / 'FlashPaintTailSampler.as').read_bytes())
        with (HERE / 'source.diff').open('x', encoding='utf8', newline='\n') as stream:
            stream.write(diff_text())
        value = dict(kind='initial-loading-cpu-source-v1', base=BASE_PINS, original_sources=source,
                     sampler_sources=TAIL_PINS, sources={p.name: sha(p) for p in sorted((HERE / 'tests').glob('*.as'))},
                     prepare_sha256=sha(__file__), readme_sha256=sha(HERE / 'README.md'),
                     diff_sha256=sha(HERE / 'source.diff'), hook_count=4, original_assertions_preserved=True,
                     original_loading_observer_byte_exact=True, compiled=False, air_started=False,
                     diagnosticOnly=True, performanceQualified=False)
        with (HERE / 'source-manifest.json').open('x', encoding='utf8') as stream:
            json.dump(value, stream, indent=2); stream.write('\n')
    proof = verify()
    print(json.dumps(dict(source_checked=True, source_manifest_sha256=sha(HERE / 'source-manifest.json'),
                         sources=len(proof['sources']), hook_count=4, compiled=False, air_started=False)))


if __name__ == '__main__':
    main()
