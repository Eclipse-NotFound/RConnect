"""Prepare the exact roomfix4 sources plus one mask condition and version; text only."""
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
# Keep the original build.py contract: the complete overlay is applied to aura1.
BASE = ROOT / 'build/m52/recovery-aura-offline-01'
PREVIOUS = ROOT / 'experimental/recovery-room-production-v4'
ACTUAL = ROOT / 'build/m52/recovery-room-production-04'
MASK = ROOT / 'experimental/recovery-room-mask-reference'
VERSION = '0.2.24-roomfix5'
BASE_SHA = 'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
ACTUAL_SHA = '34a17de66e9a89165b4bde75d22ec1dd3d4295bb496b903124687af80422b703'
MASK_SHA = '540281acb7fddbf4d378a564a591048a0f6437d1bbfc42907f850984685d7264'
BUILD_SHA = '1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9'
PINS = {
    ACTUAL/'prepared.json': '093916cf37eb1502fbc3b63f88da208d680e8314a4903840807fc0e09a775807',
    ACTUAL/'compile.json': '3cde928e206d5083ea826c8b62b05ad206ea2ad311e2c2e0875ae7e2e994e370',
    ACTUAL/'RConnectMod.swf': ACTUAL_SHA,
    PREVIOUS/'source-manifest.json': 'ea42de4a3b7093bf83bc18d40fd9fdf80e898bab52bb9cc6ad1870c5d80e15eb',
    PREVIOUS/'build.py': BUILD_SHA,
    MASK/'source-manifest.json': '41434421a2a14ff9b2c7435d063f100d1bce518cf7034bf5c7108c03dba3f445',
    MASK/'src/rconnect/game/MirrorMasks.as': MASK_SHA,
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sources():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    previous, actual, compiled = read(PREVIOUS/'source-manifest.json'), read(ACTUAL/'prepared.json'), read(ACTUAL/'compile.json')
    assert previous['version'] == actual['version'] == '0.2.24-roomfix4'
    assert previous['base_sha256'] == actual['base_sha256'] == BASE_SHA
    assert actual['overlay_manifest_sha256'] == PINS[PREVIOUS/'source-manifest.json']
    assert actual['recipe_sha256'] == BUILD_SHA
    assert compiled['compiled'] is True and compiled['candidate_sha256'] == ACTUAL_SHA
    assert compiled['sources_unchanged'] is True and compiled['installation_unchanged'] is True
    assert compiled['installation_before'] == compiled['installation_after'] == actual['installation_before']
    assert len(compiled['commands']) == 2 and all(row['exit_code'] == 0 for row in compiled['commands'])
    assert inventory(ACTUAL/'src') == actual['source'] and inventory(ACTUAL/'tools') == actual['inputs']
    assert inventory(PREVIOUS/'src') == {name: row['candidate_sha256'] for name, row in previous['changes'].items()}
    base = read(BASE/'prepared.json')
    assert sha(BASE/'RConnectMod.swf') == BASE_SHA
    assert inventory(BASE/'src') == base['source'] and inventory(BASE/'tools') == base['inputs']
    assert base['inputs'] == actual['inputs']
    reconstructed = dict(base['source'])
    reconstructed.update({name: row['candidate_sha256'] for name, row in previous['changes'].items()})
    assert reconstructed == actual['source'], 'The complete frozen overlay must reconstruct actual roomfix4'
    mask = read(MASK/'source-manifest.json')
    assert mask['baseline_sha256'] == actual['source']['rconnect/game/MirrorMasks.as']
    assert all(sha(MASK/name) == digest for name, digest in mask['files'].items())
    files = {name: (ACTUAL/'src'/name).read_bytes() for name in previous['changes']}
    files['rconnect/game/MirrorMasks.as'] = (MASK/'src/rconnect/game/MirrorMasks.as').read_bytes()
    old = b'if(rootRef!=null)maskReferences(rootRef,refs);'
    new = b'if(rootRef!=null && attached(nativeMask,v) && v.mask!==nativeMask)maskReferences(rootRef,refs);'
    original_mask = (ACTUAL/'src/rconnect/game/MirrorMasks.as').read_bytes()
    assert original_mask.count(old) == 1 and files['rconnect/game/MirrorMasks.as'] == original_mask.replace(old, new)
    entry = files['RConnectMod.as']
    assert entry.count(b'0.2.24-roomfix4') == 1
    files['RConnectMod.as'] = entry.replace(b'0.2.24-roomfix4', VERSION.encode('ascii'))
    return files, actual


def expected():
    files, actual = sources()
    changes, incremental, full_diff, incremental_diff = {}, {}, [], []
    for name, data in sorted(files.items()):
        prior, previous = BASE/'src'/name, ACTUAL/'src'/name
        digest = hashlib.sha256(data).hexdigest()
        changes[name] = dict(base_sha256=sha(prior) if prior.exists() else None, candidate_sha256=digest)
        full_diff.extend(difflib.unified_diff(prior.read_text(encoding='utf-8-sig').splitlines(True) if prior.exists() else [],
            data.decode('utf-8-sig').splitlines(True), fromfile='aura1/'+name, tofile='roomfix5/'+name))
        if digest != sha(previous):
            incremental[name] = dict(previous_sha256=sha(previous), candidate_sha256=digest)
            incremental_diff.extend(difflib.unified_diff(previous.read_text(encoding='utf-8-sig').splitlines(True),
                data.decode('utf-8-sig').splitlines(True), fromfile='roomfix4/'+name, tofile='roomfix5/'+name))
    assert set(incremental) == {'RConnectMod.as', 'rconnect/game/MirrorMasks.as'}
    candidate = dict(actual['source'])
    candidate.update({name: row['candidate_sha256'] for name, row in changes.items()})
    assert {name for name in candidate if candidate[name] != actual['source'][name]} == set(incremental)
    outputs = {'src/'+name: data for name, data in files.items()}
    outputs.update({'source.diff': ''.join(full_diff).encode('utf-8'),
                    'incremental.diff': ''.join(incremental_diff).encode('utf-8'),
                    'build.py': (PREVIOUS/'build.py').read_bytes()})
    ast.parse(outputs['build.py'])
    receipt = dict(version=VERSION, base=str(BASE), base_sha256=BASE_SHA,
        previous_overlay_sha256=PINS[PREVIOUS/'source-manifest.json'], previous_compiled_sha256=ACTUAL_SHA,
        previous_prepared_sha256=PINS[ACTUAL/'prepared.json'], previous_compile_receipt_sha256=PINS[ACTUAL/'compile.json'],
        review_sources={str(path): digest for path, digest in PINS.items()},
        changes=changes, incremental_changes=incremental, candidate_source=candidate,
        recipe_sha256=sha(Path(__file__)), build_recipe_sha256=BUILD_SHA, readme_sha256=sha(HERE/'README.md'),
        source_diff_sha256=hashlib.sha256(outputs['source.diff']).hexdigest(),
        incremental_diff_sha256=hashlib.sha256(outputs['incremental.diff']).hexdigest(),
        compiled=False, tested=False, installed=False)
    return outputs, receipt


def verify():
    outputs, receipt = expected()
    assert read(HERE/'source-manifest.json') == receipt
    for name, data in outputs.items():
        assert (HERE/name).read_bytes() == data, name
    assert inventory(HERE/'src') == {name: row['candidate_sha256'] for name, row in receipt['changes'].items()}
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert args.prepare != args.check
    if args.prepare:
        assert not (HERE/'source-manifest.json').exists() and not (HERE/'src').exists()
        outputs, receipt = expected()
        for name, data in outputs.items():
            target = HERE/name
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(data)
        with (HERE/'source-manifest.json').open('x', encoding='utf-8') as stream:
            json.dump(receipt, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
    receipt = verify()
    print(json.dumps(dict(passed=True, version=VERSION, overlay_classes=len(receipt['changes']),
        incremental_changes=list(receipt['incremental_changes']), complete_source_classes=len(receipt['candidate_source']),
        manifest_sha256=sha(HERE/'source-manifest.json'), prepare_sha256=sha(Path(__file__)),
        build_recipe_sha256=sha(HERE/'build.py'), compiled=False, air_started=False, installed=False)))


if __name__ == '__main__':
    main()
