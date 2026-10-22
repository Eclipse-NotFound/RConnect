"""Read-only source/provenance verification. No compiler, JVM, AIR or production writes."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
MOD = HERE.parents[1]
GAME = MOD.parents[1]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def text(path):
    return path.read_text(encoding='utf-8-sig')

def main():
    cs = GAME / 'mods/ContinuousScene'
    manifest = json.loads(text(cs / 'build/large-map/source-manifest.json'))
    sources = [
        cs / 'src/NativeSceneAdapter.as',
        cs / 'src/ContinuousSceneMod.as',
        cs / 'build/large-map/source-manifest.json',
        cs / 'state/deployment-v090.json',
        MOD / 'experimental/recovery-early-sandy-native/tests/RoomTravelTimingTestDoc.as',
        MOD / 'experimental/recovery-early-exit-authorization/src/rconnect/core/RoomSync.as',
        MOD / 'experimental/recovery-early-exit-authorization/src/rconnect/core/MapGeneration.as',
        MOD / 'experimental/recovery-early-exit-authorization/src/rconnect/game/WallSurfaceBridge.as',
        MOD / 'build/m52/recovery-early-host-01/after/scripts/fe/loc/Game.as',
        MOD / 'build/m52/recovery-early-host-01/after/scripts/fe/loc/Land.as',
        MOD / 'build/m52/recovery-early-host-01/after/scripts/fe/graph/Grafon.as',
    ]
    checks = []
    def check(condition, name):
        assert condition, name
        checks.append(name)
    for name in ('NativeSceneAdapter.as', 'ContinuousSceneMod.as'):
        key = 'mods\\ContinuousScene\\src\\' + name
        check(sha(cs / 'src' / name) == manifest[key].lower(), 'CS 7F1F source-manifest matches ' + name)
    binary = cs / 'build/large-map/ContinuousSceneMod.swf'
    expected = '7f1f2961c6e299d949423591f3c65c610c2eaefa7fc72e8a583a402770d6b51f'
    check(sha(binary) == expected, 'preserved CS binary is exact 7F1F')
    for run in ('3b3c31c5f5', '925d5f32df'):
        data = text(MOD / 'build/cooperation' / run / 'run.json').lower()
        check(expected in data, 'actual run input contains CS 7F1F: ' + run)
    adapter = text(sources[0])
    check('region.spawn[int(Math.random()*region.spawn.length)]' in adapter,
          'continuous-map spawn uses separate Math.random')
    doc = text(sources[4])
    check('if(round==0)mod.game.world.game.beginMission(target);' in doc,
          'round0 invokes native beginMission')
    check('if(!solo && host)Object(mod.session.rooms).prepareMap(land,MAP_SEED,true);' in doc,
          'only host sends prepare; same layout seed returned')
    game, land, grafon = [text(p) for p in sources[-3:]]
    check('this.crea = true;' in game.split('public function beginMission', 1)[1].split('public function gotoNextLevel', 1)[0],
          'beginMission forces new native mission')
    check('this.curLand.land == null || this.crea ||' in game, 'native new-Land branch includes crea')
    check('Math.floor(Math.random() * this.loc.spawnPoints.length)' in land,
          'ordinary native spawn also uses Math.random')
    check('public class Grafon' in grafon and 'dynamic class Grafon' not in grafon,
          'Grafon is not a dynamic JS-style method container')
    for name in ('sceneEnsure', 'sceneRegionDrawPass', 'sceneDrawRegionChunk', 'scenePreloadAll'):
        check('private function ' + name + '(' in grafon, 'private renderer boundary: ' + name)
    check('public static var rconnectRasterBridge:Function' in grafon,
          'raster bridge is an explicit writable Function slot')
    check('return action == null ? null : action.apply(null,args);' in grafon,
          'nativeAPI true receiver is null in actual native caller')
    wall = text(sources[7])
    check('else if(hostType.rconnectWallBridge===listener)hostType.rconnectWallBridge=null;' in wall,
          'wall bridge cleanup depends on exact owner function identity')
    check(sha(HERE / 'evidence.json') == '7e155afaf167fb3ba7ac4bab1cc6fe6b0c920a4ada4b5fb7a76538ab3e389d31',
          'original first-load evidence unchanged')
    report = dict(kind='source-only first-load followup', passed=True, checks=checks,
                  sources={str(p):sha(p) for p in sources}, binary={str(binary):sha(binary)},
                  compiled=False, air_run=False, wrapper_runtime_verified=False,
                  diagnostic_implemented=False, performance_qualified=False)
    path = HERE / 'followup_sources.json'
    assert not path.exists(), 'Do not overwrite a frozen result'
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(passed=len(checks), report=str(path), sha256=sha(path)), ensure_ascii=False))

if __name__ == '__main__':
    main()
