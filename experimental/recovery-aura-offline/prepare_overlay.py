"""Copy only the verified peer aura fix onto the exact installed offline1 source."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-offline-production-01'
DONOR = ROOT / 'build/m52/recovery-21'
PINS = {
    'rconnect/core/PeerGrip.as': 'e85e81da3c318e9163592ffdaae84e067fda6f8d3af93cd66c7dc043905d8840',
    'rconnect/game/TelekinesisVisuals.as': '2a98e2d94bf6d0cfcf62f64e830845a3919a9cb461719b81ae5f152031be30b1',
    'rconnect/game/PlayerBodyEffects.as': '11260028854167d8bd0c9f7e806e23081204dd0386902fdf746ba8e10485ccbd',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    assert sha(BASE / 'RConnectMod.swf') == 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
    assert sha(DONOR / 'RConnectMod.swf') == '9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba'
    assert not (HERE / 'src').exists(), 'Never replace a frozen overlay'
    receipt = read(ROOT / 'build/m52/recovery21-peer-grip-01/result.json')
    assert receipt['passed'] and receipt['host']['passed_checks'] == 296 and receipt['join']['passed_checks'] == 295
    changes, rows, patch = {}, {}, []
    for name, digest in PINS.items():
        source = DONOR / 'src' / name
        assert sha(source) == digest
        # These three original classes did not participate in the offline change.
        assert (BASE / 'src' / name).read_bytes() == (ROOT / 'build/m52/coop-bundle-04/src' / name).read_bytes()
        changes[name] = source.read_bytes()
        rows[name] = {'base': sha(BASE / 'src' / name), 'donor': digest, 'operation': 'exact verified aura class'}
    name = 'rconnect/game/GameBridge.as'
    body = (BASE / 'src' / name).read_bytes()
    for expr, count in [('rec.ghost,peerSample.bodyEffects', 1), ('ghost,snap.bodyEffects', 2)]:
        old = ('_bodyEffects.apply(' + expr + ',coopPaused)').encode()
        unit = expr.split(',')[0]
        new = ('_bodyEffects.apply(' + expr + ',coopPaused,peerGrip!=null && peerGrip.locallyHeld(' + unit + '))').encode()
        assert body.count(old) == count
        body = body.replace(old, new)
    changes[name] = body
    rows[name] = {'base': sha(BASE / 'src' / name), 'operation': 'three nativeGrip arguments only; offline collection retained'}
    for name, data in changes.items():
        target = HERE / 'src' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        rows[name]['output'] = sha(target)
        old = (BASE / 'src' / name).read_text(encoding='utf-8-sig').splitlines(True)
        new = target.read_text(encoding='utf-8-sig').splitlines(True)
        patch.extend(difflib.unified_diff(old, new, fromfile='offline1/' + name, tofile='aura1/' + name))
    (HERE / 'source.diff').write_text(''.join(patch), encoding='utf-8', newline='\n')
    (HERE / 'source-manifest.json').write_text(json.dumps({'base': str(BASE), 'donor': str(DONOR),
        'files': rows, 'overlay_recipe_sha256': sha(Path(__file__)),
        'prior_evidence_only': str(ROOT / 'build/m52/recovery21-peer-grip-01/result.json'),
        'current_native_verified': False}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(rows, ensure_ascii=False))


if __name__ == '__main__':
    main()
