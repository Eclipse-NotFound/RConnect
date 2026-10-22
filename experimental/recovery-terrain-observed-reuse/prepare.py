"""Prepare/check the exact D356 TerrainSync one-callback proposal. No compiler/AIR."""
from pathlib import Path
import argparse, difflib, hashlib, json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'experimental/recovery-early-exit-authorization/src'
BUILD = ROOT / 'build/m52/recovery-early-exit-compile-01'
BASE_SHA = 'd356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3'
MANIFEST_SHA = 'a59473631fb28dcddfbd2dd96d795c98d61b2776ba33d91e3efa9e5ffe8922fe'
PINS = {
    'rconnect/game/TerrainSync.as': '317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44',
    'rconnect/game/NativeTileState.as': 'eec001f4de8bdfc5ad892c2de2e892c07cceac15ebe7c5cf10fda4a1047592dc',
    'rconnect/game/NativeRoomState.as': '1e91028348b29dc1bd00dc55cf4d5df5d5ee40469ef9ea0f7e9626d30a601938',
}
OLD = 'function(t:Object,x:int,y:int):void {observed[key(x,y)]=state(t,x,y);}'
NEW = '''function(t:Object,x:int,y:int):void {
               var k:String=key(x,y);
               if(!matchesTile(t,observed[k]))observed[k]=state(t,x,y);
            }'''
FIXTURES = ['fe/loc/Tile.as', 'fe/unit/Unit.as', 'fe/unit/RConnectUnitAccess.as',
            'rconnect/game/GameBridge.as', 'rconnect/game/TurretDisplay.as']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def planned():
    assert sha(BUILD/'prepared.json') == MANIFEST_SHA
    manifest = json.loads((BUILD/'prepared.json').read_text(encoding='utf-8-sig'))
    assert manifest['sha256'] == BASE_SHA and manifest['compiled']
    for name, digest in PINS.items():
        assert manifest['source'][name] == digest and sha(BASE/name) == digest
        assert sha(BUILD/'src'/name) == digest
    original = (BASE/'rconnect/game/TerrainSync.as').read_text(encoding='utf-8-sig')
    assert original.count(OLD) == 1
    candidate = original.replace(OLD, NEW)
    assert candidate.replace(NEW, OLD) == original
    control = original.replace('public class TerrainSync', 'public class ControlTerrainSync')
    assert control.replace('public class ControlTerrainSync', 'public class TerrainSync') == original
    files = {
        'src/rconnect/game/TerrainSync.as': candidate.encode(),
        'components/rconnect/game/TerrainSync.as': candidate.encode(),
        'components/rconnect/game/ControlTerrainSync.as': control.encode(),
        'proposal.patch': ''.join(difflib.unified_diff(original.splitlines(True), candidate.splitlines(True),
            fromfile='early2-D356/rconnect/game/TerrainSync.as',
            tofile='observed-reuse/rconnect/game/TerrainSync.as')).encode(),
    }
    inputs = {str(BASE/name): digest for name, digest in PINS.items()}
    inputs[str(BUILD/'prepared.json')] = MANIFEST_SHA
    for name in ('rconnect/game/NativeTileState.as', 'rconnect/game/NativeRoomState.as'):
        files['components/'+name] = (BASE/name).read_bytes()
    for name in FIXTURES:
        path = ROOT/'experimental/recovery-terrain-loop/components'/name
        inputs[str(path)] = sha(path)
        files['components/'+name] = path.read_bytes()
    return files, inputs

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--materialize', action='store_true')
    args = parser.parse_args()
    files, inputs = planned()
    if args.materialize:
        assert not (HERE/'inputs.json').exists(), 'Already frozen; check instead'
        for name, body in files.items():
            target = HERE/name
            assert not target.exists(), name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(body)
        outputs = {p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()}
        (HERE/'inputs.json').write_text(json.dumps(dict(kind='terrain-observed-reuse-proposal',
            base_swf_sha256=BASE_SHA, input_sources=inputs, outputs=outputs,
            expected_assertions=50, production_overlays=1, actual_complete_old_new=True,
            compiled=False, air_started=False, performance_qualified=False), indent=2)+'\n', encoding='utf-8')
    else:
        assert sha(BUILD/'RConnectMod.swf') == BASE_SHA
        manifest = json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
        assert manifest['input_sources'] == inputs
        for name, body in files.items():
            assert (HERE/name).read_bytes() == body, name
        for name, digest in manifest['outputs'].items():
            assert sha(HERE/name) == digest, name
        assert len(list((HERE/'src').rglob('*.as'))) == 1
    print(json.dumps(dict(verified=True, materialized=args.materialize, expected_assertions=50,
        production_overlays=1, actual_complete_old_new=True, jvm_started=False, air_started=False)))

if __name__ == '__main__':
    main()
