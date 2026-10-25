"""Exact 78C plus the frozen native UI and jump-pose sources; text only."""
import argparse
import ast
import contextlib
import difflib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-room-production-05'
UI = ROOT/'build/m52/goal-native-loading-product-01'
JUMP = ROOT/'build/m52/goal-jump-pose-product-01'
JUMP_RECIPE = ROOT/'experimental/goal-jump-pose-product'
DELEGATE = ROOT/'experimental/recovery-room-production-v5/build.py'
BASE_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
UI_SHA = '9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
JUMP_SHA = '52d4723c1cf43e9ed2949c2e20debf7beda0b6068767c0bbaf83e83eb6a56e88'
RUNTIME_HOST_SHA = '2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
VERSION = '0.2.24-nativeui2'
PINS = {
    'build/m52/recovery-room-production-05/prepared.json':'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
    'build/m52/recovery-room-production-05/compile.json':'68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
    'build/m52/goal-native-loading-product-01/prepared.json':'d9f9fda6e92b24984be597f291a1beb9050b2ac5658e059c39aaf65cd6d2874a',
    'build/m52/goal-native-loading-product-01/compile.json':'08d67d337773592e35093ffba954f49ffcf7018ee7e60d6e8b9b8a11a27c1659',
    'build/m52/goal-jump-pose-product-01/prepared.json':'bb3c119487bf76d2267b2394324f427ac042f3893735a654a297792ae17de4f0',
    'build/m52/goal-jump-pose-product-01/compile.json':'2bdc27070ce01eaf9275646d354561b530210c7a22e0a75be2516a1679404750',
    'experimental/goal-jump-pose-product/prepare.py':'4d82ed27a4483fd4339fb8ec87b8d82e2c3b74f480161e3118783c33045e7804',
    'experimental/goal-jump-pose-product/build.py':'ff10e4e5351b559264c58de389068ba9f4e386508afbab8c646c181c08cc7b77',
    'experimental/goal-native-loading-ui/source-manifest.json':'a4792939834f8ff197be63374034e1e6e0c479b8f5d3c09816ef1c754a5bb5c7',
    'experimental/recovery-room-production-v5/build.py':'1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
    'tools/validation/run_security_terminals.py':'4e4ad73dd0f8df69db5c0c11f6c2c1c94c96fb1235dbaa1aad18caaf9877b9cb',
    'tools/validation/prepare_security_terminals.py':'5d156d663f616baf793b03ca183388951a10375a5d11e561e81c2b81ab7e13b5',
    'tools/validation/runtime_memory.py':'d4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    '../ModLoader/tools/test_registry.py':'8b35a6d6ca1dd94cfd5cba9a42979ebd14d9ae65497688fa859d084425922049',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def historical_product(folder, digest):
    """Verify an exact pinned historical receipt, never pretend it is current."""
    meta, receipt = read(folder/'prepared.json'), read(folder/'compile.json')
    assert sha(folder/'RConnectMod.swf') == digest == receipt['candidate_sha256']
    assert all(receipt[k] is True for k in ('compiled', 'sources_unchanged', 'installation_unchanged'))
    assert receipt['air_started'] is False and receipt['installed'] is False
    assert receipt['installation_before'] == receipt['installation_after'] == meta['installation_before']
    assert len(receipt['installation_before']) == 22
    assert len(receipt['commands']) == 2 and all(c['exit_code'] == 0 for c in receipt['commands'])
    assert inventory(folder/'src') == meta['source'] and inventory(folder/'tools') == meta['inputs']
    return meta


def expected():
    for name, digest in PINS.items():
        assert sha(ROOT/name) == digest, name
    # Reuse the complete frozen jump recipe/source checker, without changing it.
    with contextlib.redirect_stdout(io.StringIO()):
        jump_source = load('native_ui2_frozen_jump_source', JUMP_RECIPE/'prepare.py').verify()
        load('native_ui2_frozen_jump_product', JUMP_RECIPE/'build.py').verify(JUMP)
    old = historical_product(BASE, BASE_SHA)
    ui = historical_product(UI, UI_SHA)
    jump = historical_product(JUMP, JUMP_SHA)
    assert len(old['source']) == 81
    assert ui['base_sha256'] == jump['base_sha256'] == BASE_SHA
    assert ui['inputs'] == jump['inputs'] == old['inputs']
    ui_source = read(ROOT/'experimental/goal-native-loading-ui/source-manifest.json')
    assert ui['source'] == old['source'] | ui_source['product_overlay']
    assert jump['source'] == jump_source['candidate_source']
    names = ('rconnect/game/GameBridge.as', 'rconnect/game/RemoteMotion.as', 'rconnect/game/NativeJumpPose.as')
    files = {'src/'+name:(JUMP/'src'/name).read_bytes() for name in names}
    view = 'rconnect/ui/RoomEntryView.as'
    files['src/'+view] = (UI/'src'/view).read_bytes()
    assert sha(UI/'src'/view) == 'd4a24f64fffaa3b1620b536c7615d0caea8e7edf2a146feed6c6c0113c81ec2f'
    entry = (BASE/'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomfix5') == 1
    files['src/RConnectMod.as'] = entry.replace(b'0.2.24-roomfix5', VERSION.encode('ascii'))
    changes, candidate, diff = {}, dict(old['source']), ''
    for rel, data in sorted(files.items()):
        name = rel[4:]
        digest = hashlib.sha256(data).hexdigest()
        changes[name] = {'base_sha256':old['source'].get(name), 'candidate_sha256':digest}
        candidate[name] = digest
        before = (BASE/'src'/name).read_text(encoding='utf-8').splitlines(True) if name in old['source'] else []
        diff += ''.join(difflib.unified_diff(before, data.decode('utf-8').replace('\r\n', '\n').splitlines(True),
                                           fromfile='78C/'+name, tofile='nativeui2/'+name))
    assert len(changes) == 5 and len(candidate) == 82
    assert sum(candidate[k] == v for k, v in old['source'].items()) == 77
    assert changes['rconnect/game/NativeJumpPose.as']['base_sha256'] is None
    files['source.diff'] = diff.encode('utf-8')
    for name in ('prepare.py', 'build.py'):
        ast.parse((HERE/name).read_text('utf-8'))
    manifest = dict(kind='native-ui-jump-bounded-product-v1', base_sha256=BASE_SHA, version=VERSION,
                    ui_product_sha256=UI_SHA, jump_product_sha256=JUMP_SHA,
                    required_runtime_host_sha256=RUNTIME_HOST_SHA, current_environment_bound=False,
                    inputs=PINS, base_source=old['source'], candidate_source=candidate, changes=changes,
                    historical_build_environments={name:meta['installation_before'] for name, meta in
                        (('base78C', old), ('ui9C', ui), ('jump52D', jump))},
                    native_tested=False, performance_qualified=False)
    manifest['files'] = {name:hashlib.sha256(data).hexdigest() for name, data in files.items()}
    manifest['files'].update({name:sha(HERE/name) for name in ('prepare.py', 'build.py', 'README.md')})
    return files, manifest


def verify():
    files, manifest = expected()
    for name, data in files.items():
        assert (HERE/name).read_bytes() == data, name
    assert read(HERE/'source-manifest.json') == manifest
    assert inventory(HERE/'src') == {name:row['candidate_sha256'] for name, row in manifest['changes'].items()}
    actual = {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
              if p.is_file() and p.name != 'source-manifest.json'}
    assert actual == manifest['files'], 'Frozen nativeui2 recipe changed'
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare', action='store_true')
    group.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        files, manifest = expected()
        files['source-manifest.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
        for name, data in files.items():
            path = HERE/name
            if path.exists():
                assert path.read_bytes() == data, 'Refuse overwriting frozen text: '+name
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with path.open('xb') as stream:
                    stream.write(data)
    verify()
    print(json.dumps(dict(checked=True, changed_existing_classes=4, added_classes=1, unchanged_classes=77,
                         final_classes=82, compiled=False, air_started=False, current_environment_bound=False)))
