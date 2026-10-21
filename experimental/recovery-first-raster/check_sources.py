"""Text/hash checks only. Not an AS compiler, AIR test or native validation."""
import ast,hashlib,json,re
from pathlib import Path
from generate import HERE,ROOT,BASE,HOST,PINS,repair_closure_increments
from prepare_components import method
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def text(p):return p.read_text(encoding='utf-8-sig')
def main():
    rows=[]
    def check(ok,label):
        rows.append(dict(passed=bool(ok),label=label))
        assert ok,label
    for p in HERE.glob('*.py'):
        ast.parse(text(p));check(True,'Python syntax '+p.name)
    m=json.loads(text(HERE/'integration.json'))
    for rel,h in PINS.items():check(sha((HOST if rel.startswith('fe/') else BASE)/rel)==h,'exact base '+rel)
    for rel,h in m['overlays'].items():check(sha(HERE/rel)==h,'overlay fingerprint '+rel)
    original=text(HOST/'fe/graph/Grafon.as');candidate=text(HERE/'native/fe/graph/Grafon.as')
    changed={'sceneOpen','sceneEnsure','sceneTick','sceneViewReady','drawLoc','sceneDrawSteps'}
    names=re.findall(r'^      (?:public|private|protected|internal)(?:\s+override)?\s+function\s+(?:get\s+|set\s+)?(\w+)\(',original,re.M)
    for name in names:
        if name not in changed:check(method(original,name)==method(candidate,name),'unchanged native method '+name)
    check(method(repair_closure_increments(original),'sceneDrawSteps')==method(candidate,'sceneDrawSteps'),'sceneDrawSteps differs only by two exact captured increments')
    check('§§' not in candidate,'native import source contains no FFDec pseudo-instructions')
    for name in ('rconnectRasterPending','rconnectRasterWaiting','rconnectRasterPainted','sceneOpen','sceneEnsure','sceneTick','sceneViewReady'):
        check(method(candidate,name)==method(text(HERE/'components/native/NativeRasterHarness.as'),name),'exact extracted component method '+name)
    room=text(HERE/'src/rconnect/core/RoomSync.as')
    check('hold(' not in method(room,'openFirstRaster') and 'onPause=' not in method(room,'openFirstRaster'),'open callback never stops native exitStep')
    check('sceneMerged!==true' in method(room,'openFirstRaster'),'only confirmed merged native destination')
    check('session.mode!=Session.CONNECTED' in method(room,'openFirstRaster'),'host/offline are not deferred')
    check('if(g.scenePreload!==true && g.sceneCullRender!==true) {firstRaster.cancel();return null;}' in method(room,'openFirstRaster'),'unsupported renderer configuration cancels previous ticket')
    painted=method(candidate,'rconnectRasterPainted')
    check(painted.index('this.rconnectRasterTicket.unpainted === true')<painted.index('this.sceneViewReady()'),'completed ticket short circuits view readiness scanning')
    check('game.finishFirstRaster();' in method(room,'finishFirstRaster'),'wall finish before ACK')
    check(method(room,'finishFirstRaster').index('game.finishFirstRaster();')<method(room,'finishFirstRaster').index('send({op:"ack"'),'finish before acknowledgement')
    for rel in ('rconnect/core/RoomSync.as','rconnect/core/FirstRasterGate.as'):
        check(sha(HERE/'components/room'/rel)==sha(HERE/'src'/rel),'real component '+rel)
    check(sha(HERE/'components/gate/rconnect/core/FirstRasterGate.as')==sha(HERE/'src/rconnect/core/FirstRasterGate.as'),'real lifecycle component')
    check('rconnectRasterPending' in method(text(HERE/'src/rconnect/game/GameBridge.as'),'restoreCheckpoint'),'unpainted terrain cannot be reused')
    check('rconnectRasterPending' in method(text(HERE/'src/rconnect/game/WallImpactVisuals.as'),'front'),'unpainted wall pixels cannot be sampled')
    check('cam.calc' not in room and 'Camera.calc(' not in method(room,'finishFirstRaster'),'no extra native camera calculation')
    result=dict(passed=True,checks=len(rows),assertions=rows,compiled=False,air_started=False,native_game_test=False)
    (HERE/'source-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    manifest=dict(revision='final-03-host-closure-increment-import-repair',base=m['base'],host=m['host'],
        compiled=False,runtime_tested=False,native_game_test=False,installation_modified=False,
        previous_component_runs='01 results are preserved historical evidence; they do not qualify this revised source package.',
        overlays=m['overlays'],files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
            if p.is_file() and p.name!='final-source-manifest.json' and '__pycache__' not in p.parts})
    (HERE/'final-source-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(static_checks=len(rows),compiled=False,air_started=False)))
if __name__=='__main__':main()
