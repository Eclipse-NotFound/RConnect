"""Freeze two previously tested terrain classes on exact roomload1; no JVM/AIR."""
from pathlib import Path
import argparse
import ast
import difflib
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-room-first-raster-product-01'
OLD = ROOT/'build/m52/recovery-room-perf-current-01'
DELEGATE = ROOT/'experimental/recovery-room-first-raster-current/build.py'
EARLY = ROOT/'experimental/recovery-room-first-raster-current/manifest.json'
VERSION = '0.2.24-roomload2'
BASE_SHA = '6d4655f30bc252e798304bbf99a21458d53eeec1538c6d49eeb04c1a0b655392'
INSTALLED_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
PINS = {
    BASE/'prepared.json': 'd4598712cd5d5457802b16a998136ecc3b30166183f6ac7aa38a48fd6c4bd278',
    BASE/'compile.json': '5062269f806d92d28190c56bca9c7768d0fe13b8e43929a5699d921468c24695',
    BASE/'RConnectMod.swf': BASE_SHA,
    OLD/'prepared.json': '98cefeff04e60302339c79dfa1e2ae96173da9619df9870df43d08a39f7e5ba1',
    OLD/'compile.json': '03b9234aa25a952245bb02cb7a400ae9ef6399bd7c02608887bf20600a13f1af',
    OLD/'RConnectMod.swf': '1e26bdf38811268234af8e1ef060514388719a5dcaa21a861ff7501ef558ba81',
    DELEGATE: '74a3466a134bcd78fc06572fcceafba9c64170fbed8afb913e997ec7d0e996ae',
    EARLY: 'a989a74630b7ff4b3bf750b0922a39d9e8d61ad2bf83f776c82ecc28cfa31b56',
}
NATIVE = 'rconnect/game/NativeTileState.as'
TERRAIN = 'rconnect/game/TerrainSync.as'
COPIES = {
    NATIVE: 'eec001f4de8bdfc5ad892c2de2e892c07cceac15ebe7c5cf10fda4a1047592dc',
    TERRAIN: '3bb4ac4a9ab4ca6a045d2376e3b18025d48db409bc6ad72cb62cdece02f5ebfa',
}
PROOFS = [
    ('recovery-terrain-loop-component-03', 67,
     '122778424511b8bf6d988a2dac44f93f0cf379129bc4ce31a81fd5a5a2c0d86b',
     '8fa17bbccdfdfb42b51cec0d3530ed10853c43fc23845996e02eb61bd51b4d17',
     '370ee7602d38f0cbfb27c43ab47e937d4322fd5c23dffba64d5c782e07bdd622'),
    ('recovery-terrain-capture-component-01', 154,
     '4631c58b540449f75d3ced18a51b705d72f0bfbde343ed851127b7c16966ae71',
     'db60fc5e3953b82ddcbdea1fbf390674e17cdc2af7f9a9cb389bd7600973f1db',
     'c8e831088dac012095fce9d624fa9804a0f364b35ffb3139836ef53207424c19'),
]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def adapted_builder():
    assert sha(DELEGATE) == PINS[DELEGATE]
    old = DELEGATE.read_text(encoding='utf-8')
    before = "assert len(before) == 22 and before['mods/Rconnect/release/RConnectMod.swf'] == BASE_SHA"
    after = "assert len(before) == 22 and before['mods/Rconnect/release/RConnectMod.swf'] == INSTALLED_SHA"
    assert old.count(before) == 1
    new = old.replace(before, after)
    ast.parse(new)
    patch = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
        fromfile='frozen-first-raster/build.py', tofile='bound-roomload2/build.py'))
    return new, patch


def product(path, version, digest):
    meta, result = read(path/'prepared.json'), read(path/'compile.json')
    assert meta['version'] == version and sha(path/'RConnectMod.swf') == result['candidate_sha256'] == digest
    assert result['compiled'] and result['installation_unchanged'] and result['sources_unchanged']
    assert result['installation_before'] == result['installation_after'] == meta['installation_before']
    assert len(result['commands']) == 2 and all(c['exit_code'] == 0 for c in result['commands'])
    assert inventory(path/'src') == meta['source'] and inventory(path/'tools') == meta['inputs']
    return meta


def components():
    result = []
    for name, count, receipt_sha, result_sha, intent_sha in PROOFS:
        folder = ROOT/'build/m52'/name
        for file, digest in [('receipt.json', receipt_sha), ('component-result.json', result_sha), ('intent.json', intent_sha)]:
            assert sha(folder/file) == digest, str(folder/file)
        receipt, checks, intent = read(folder/'receipt.json'), read(folder/'component-result.json'), read(folder/'intent.json')
        assert all(receipt[k] is True for k in ['passed', 'compiled', 'air_started', 'installation_unchanged', 'source_unchanged'])
        assert receipt['compile_exit'] == receipt['exit_code'] == receipt['checks_failed'] == checks['failed'] == 0
        assert intent['expected'] == receipt['observed_checks'] == len(checks['assertions']) == count
        assert checks['passed'] is True and all(row['passed'] is True for row in checks['assertions'])
        assert inventory(folder/'src') == intent['sources'] and sha(folder/'Checks.swf') == receipt['component_sha256']
        result.append(dict(path=str(folder), assertions=count, receipt_sha256=receipt_sha,
            result_sha256=result_sha, intent_sha256=intent_sha, component_sha256=receipt['component_sha256']))
    loop = ROOT/'build/m52/recovery-terrain-loop-component-03/src/rconnect/game'
    capture = ROOT/'build/m52/recovery-terrain-capture-component-01/src/rconnect/game'
    assert (loop/'ControlNativeTileState.as').read_bytes().replace(b'ControlNativeTileState', b'NativeTileState') == (BASE/'src'/NATIVE).read_bytes()
    assert (capture/'ControlTerrainSync.as').read_bytes().replace(b'ControlTerrainSync', b'TerrainSync') == (BASE/'src'/TERRAIN).read_bytes()
    assert (OLD/'src'/NATIVE).read_bytes() == (loop/'NativeTileState.as').read_bytes() == (capture/'NativeTileState.as').read_bytes()
    assert (OLD/'src'/TERRAIN).read_bytes() == (capture/'TerrainSync.as').read_bytes()
    assert (BASE/'src/rconnect/game/NativeRoomState.as').read_bytes() == (loop/'NativeRoomState.as').read_bytes() == (capture/'NativeRoomState.as').read_bytes()
    return result


def expected():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    base = product(BASE, '0.2.24-roomload1', BASE_SHA)
    product(OLD, '0.2.24-roomperf1', PINS[OLD/'RConnectMod.swf'])
    assert len(base['source']) == 82
    evidence = components()
    files = {}
    for name, digest in COPIES.items():
        assert sha(OLD/'src'/name) == digest
        files[name] = (OLD/'src'/name).read_bytes()
    entry = (BASE/'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomload1') == 1
    files['RConnectMod.as'] = entry.replace(b'0.2.24-roomload1', VERSION.encode('ascii'))
    source, changes, diff = dict(base['source']), {}, []
    for name, data in sorted(files.items()):
        digest = hashlib.sha256(data).hexdigest()
        assert digest != base['source'][name]
        changes[name] = dict(base_sha256=base['source'][name], candidate_sha256=digest)
        source[name] = digest
        diff.extend(difflib.unified_diff((BASE/'src'/name).read_bytes().decode('utf-8').splitlines(True),
            data.decode('utf-8').splitlines(True), fromfile='roomload1/'+name, tofile='roomload2/'+name))
    assert set(changes) == {NATIVE, TERRAIN, 'RConnectMod.as'}
    assert sum(source[name] == digest for name, digest in base['source'].items()) == 79
    early = read(EARLY)['sources']
    assert len(early) == 6 and all(source[name] == base['source'][name] == digest for name, digest in early.items())
    new_builder, builder_diff = adapted_builder()
    outputs = {'src/'+name: data for name, data in files.items()}
    outputs['source.diff'] = ''.join(diff).encode('utf-8')
    outputs['builder-adaptation.diff'] = builder_diff.encode('utf-8')
    for name in ['prepare.py', 'build.py']:
        ast.parse((HERE/name).read_text(encoding='utf-8'))
    manifest = dict(kind='room-first-raster-loop-overlay', version=VERSION, base=str(BASE), base_sha256=BASE_SHA,
        base_prepared_sha256=PINS[BASE/'prepared.json'], base_compile_sha256=PINS[BASE/'compile.json'],
        installed_rc_sha256=INSTALLED_SHA, sources={name: source[name] for name in files},
        candidate_source=source, changes=changes, unchanged_source_count=79, inherited_early_sources=early,
        source_origins={name: dict(path=str(OLD/'src'/name), sha256=digest) for name, digest in COPIES.items()},
        pins={str(path): digest for path, digest in PINS.items()}, historical_components=evidence,
        outputs={name: hashlib.sha256(data).hexdigest() for name, data in outputs.items()},
        prepare_sha256=sha(HERE/'prepare.py'), wrapper_sha256=sha(HERE/'build.py'), readme_sha256=sha(HERE/'README.md'),
        builder=dict(path=str(DELEGATE), source_sha256=PINS[DELEGATE],
            adapted_sha256=hashlib.sha256(new_builder.encode('utf-8')).hexdigest(), replacements=1),
        compiled=False, native_tested=False, installed=False, performance_qualified=False)
    return outputs, manifest


def verify():
    outputs, manifest = expected()
    assert read(HERE/'manifest.json') == manifest
    for name, data in outputs.items():
        assert (HERE/name).read_bytes() == data, name
    assert inventory(HERE/'src') == manifest['sources']
    assert {p.relative_to(HERE).as_posix() for p in HERE.rglob('*') if p.is_file()} == set(outputs) | {'prepare.py', 'build.py', 'README.md', 'manifest.json'}
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        assert not (HERE/'src').exists() and not (HERE/'manifest.json').exists()
        outputs, manifest = expected()
        for name, data in outputs.items():
            path = HERE/name
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('xb') as stream:
                stream.write(data)
        with (HERE/'manifest.json').open('x', encoding='utf-8') as stream:
            json.dump(manifest, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    manifest = verify()
    print(json.dumps(dict(passed=True, version=VERSION, source_count=82, overlay_classes=3,
        unchanged_source_count=79, manifest_sha256=sha(HERE/'manifest.json'), compiled=False, air_started=False)))


if __name__ == '__main__':
    main()
