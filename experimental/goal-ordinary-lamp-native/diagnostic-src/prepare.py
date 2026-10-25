"""Source-only lamp raster observation on the exact original three-trip driver."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = ROOT / 'build/m52/goal-native-loading-probe-driver-01'
ORIGINAL = {
    'A22RoomMetrics.as': '314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e',
    'NativeLoadingProbe.as': '0bd3c84f3a48487ae9b9e0d651e2a901873913eba737622c2833edbc2cf64b92',
    'RoomTravelTimingTestDoc.as': 'ebe117b2b391a396eb83c79a616580b07bd7305b601b83acd9ca007e359e592c',
}
BASE_MANIFEST = '562bb57f0640eefb4f89fa2799fd52918baec49cdab42c434808a21c36840ca9'
HOOKS = (
    ('      private var loadingProbe:NativeLoadingProbe;',
     '      private var loadingProbe:NativeLoadingProbe;\n      private var lampProbe:OrdinaryLampRasterProbe;'),
    ('         if(loadingProbe==null)loadingProbe=new NativeLoadingProbe(mod);',
     '         if(loadingProbe==null)loadingProbe=new NativeLoadingProbe(mod);\n         if(lampProbe==null)lampProbe=new OrdinaryLampRasterProbe(mod);'),
    ('         if(loadingProbe!=null)loadingProbe.begin(round,target,at);',
     '         if(loadingProbe!=null)loadingProbe.begin(round,target,at);\n         if(lampProbe!=null)lampProbe.begin(round);'),
    ('         if(loadingProbe!=null)loadingProbe.finish();',
     '         if(loadingProbe!=null)loadingProbe.finish();\n         if(lampProbe!=null)lampProbe.finish();'),
)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text('utf-8-sig'))

def originals():
    assert sha(BASE / 'prepared.json') == BASE_MANIFEST
    source = {}
    for name, digest in ORIGINAL.items():
        path = BASE / 'tests' / name
        assert sha(path) == digest, name
        source[name] = path.read_bytes().decode('utf8')
    return source

def generated():
    source = originals()
    original = source['RoomTravelTimingTestDoc.as']
    changed = original
    for old, new in HOOKS:
        assert changed.count(old) == 1, old
        changed = changed.replace(old, new, 1)
    restored = changed
    for old, new in reversed(HOOKS):
        assert restored.count(new) == 1, new
        restored = restored.replace(new, old, 1)
    assert restored == original
    source['RoomTravelTimingTestDoc.as'] = changed
    return source

def diff_text():
    old = originals()
    chunks = []
    for name, text in generated().items():
        chunks += difflib.unified_diff(old[name].splitlines(True), text.splitlines(True),
                                      fromfile='original-877B/tests/' + name,
                                      tofile='lamp-diagnostic/tests/' + name)
    name = 'OrdinaryLampRasterProbe.as'
    chunks += difflib.unified_diff([], (HERE / 'tests' / name).read_text('utf8').splitlines(True),
                                  fromfile='/dev/null', tofile='lamp-diagnostic/tests/' + name)
    return ''.join(chunks)

def verify():
    ast.parse(Path(__file__).read_text('utf8'))
    expected = generated()
    for name, text in expected.items():
        assert (HERE / 'tests' / name).read_bytes() == text.encode('utf8'), name
    for name in ('A22RoomMetrics.as', 'NativeLoadingProbe.as'):
        assert (HERE / 'tests' / name).read_bytes() == (BASE / 'tests' / name).read_bytes()
    m = read(HERE / 'source-manifest.json')
    assert m['kind'] == 'ordinary-lamp-native-raster-diagnostic-source-v1'
    assert m['prepare_sha256'] == sha(__file__)
    assert m['readme_sha256'] == sha(HERE / 'README.md')
    assert m['diff_sha256'] == sha(HERE / 'source.diff')
    assert (HERE / 'source.diff').read_text('utf8') == diff_text()
    sources = {p.name: sha(p) for p in sorted((HERE / 'tests').glob('*.as'))}
    assert len(sources) == 4 and m['sources'] == sources
    assert m['original_sources'] == ORIGINAL and m['original_prepared_sha256'] == BASE_MANIFEST
    assert m['hook_count'] == len(HOOKS) == 4
    assert m['diagnosticOnly'] is True and m['performanceQualified'] is False
    assert m['entry'] == 'tests/RoomTravelTimingTestDoc.as'
    assert m['done'] == 'LAMP RASTER PROBE DONE'
    assert m['result'] == 'ordinary-lamp/result.json'
    return m

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--prepare', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        assert not (HERE / 'source-manifest.json').exists(), 'Frozen source must not be overwritten'
        for name, text in generated().items():
            with (HERE / 'tests' / name).open('x', encoding='utf8', newline='\n') as handle:
                handle.write(text)
        with (HERE / 'source.diff').open('x', encoding='utf8', newline='\n') as handle:
            handle.write(diff_text())
        m = {
            'kind': 'ordinary-lamp-native-raster-diagnostic-source-v1',
            'prepare_sha256': sha(__file__), 'readme_sha256': sha(HERE / 'README.md'),
            'diff_sha256': sha(HERE / 'source.diff'),
            'original_sources': ORIGINAL, 'original_prepared_sha256': BASE_MANIFEST,
            'sources': {p.name: sha(p) for p in sorted((HERE / 'tests').glob('*.as'))},
            'entry': 'tests/RoomTravelTimingTestDoc.as', 'hook_count': len(HOOKS),
            'done': 'LAMP RASTER PROBE DONE', 'result': 'ordinary-lamp/result.json',
            'originalTravelChecks': 35, 'originalUiChecksPerRole': 11,
            'additionalChecksPerRole': 8, 'source_count': 4,
            'diagnosticOnly': True, 'performanceQualified': False,
            'compiled': False, 'air_started': False,
        }
        with (HERE / 'source-manifest.json').open('x', encoding='utf8', newline='\n') as handle:
            json.dump(m, handle, indent=2)
            handle.write('\n')
    result = verify()
    print(json.dumps({'source_checked': True, 'sources': len(result['sources']),
                      'entry': result['entry'], 'compiled': False, 'air_started': False}))

if __name__ == '__main__':
    main()
