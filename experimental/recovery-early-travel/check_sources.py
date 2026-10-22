"""Static source/ordering checks only. Never compiles or runs game code."""
from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
rows=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return p.read_text(encoding='utf-8-sig')
def check(ok,label):
    rows.append({'passed':bool(ok),'label':label})
def body(s,name):
    m=re.search(r'function\s+(?:get\s+)?'+name+r'\([^\n]*\)[^{]*\{',s);assert m,name
    i=m.end();depth=1
    while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[m.end():i-1]
def main():
    meta=json.loads(read(HERE/'manifest.json'))
    for rel,v in meta['sources'].items():
        check(sha(HERE/rel)==v['sha256'],rel+' matches prepared source')
        check(sha(ROOT/v['base'])==v['base_sha256'],rel+' exact baseline unchanged')
    check(sha(HERE/'src/rconnect/core/EarlyTravelGate.as')==meta['new_gate_sha256'],'gate matches source manifest')
    components=json.loads(read(HERE/'component-inputs.json'))
    for path,digest in components['sources'].items():check(sha(ROOT/path)==digest,'component input '+path)
    for tree,files in components['components'].items():
        for rel,digest in files.items():check(sha(HERE/'components'/tree/rel)==digest,'component '+tree+'/'+rel)
    room=read(HERE/'src/rconnect/core/RoomSync.as');mapping=read(HERE/'src/rconnect/core/MapGeneration.as')
    world=read(HERE/'host-import/fe/World.as');game=read(HERE/'host-import/fe/loc/Game.as')
    construct=body(game,'enterToCurLand')
    check(construct.rstrip().endswith('if(rconnectTravelBridge != null)rconnectTravelBridge("constructed",this,null);'),'constructed callback is after all original Game work')
    basegame=read(ROOT/meta['sources']['host-import/fe/loc/Game.as']['base'])
    stripped=game.replace('      public static const rconnectEarlyTravelVersion:int = 1;\n','').replace('         if(rconnectTravelBridge != null)rconnectTravelBridge("constructed",this,null);\n','')
    check(stripped==basegame,'Game contains only version constant and tail callback')
    step=body(world,'step');exitstep=body(world,'exitStep')
    check(step.index('this.exitStep();')<step.index('if(!this.rconnectLoadingHold())')<step.index('this.land.step();'),'same-frame postconstruct simulation is rechecked solely by owned ticket')
    check('if(!this.onPause && !this.rconnectLoadingHold())' not in step,'unowned post-exit pause change retains original same-frame semantics')
    check('if(this.allStat == 1 && (!this.onPause || this.rconnectLoadingHold()))' in step,'only owned native hold may advance paused countdown')
    check('if(!this.rconnectLoadingHold())' in exitstep and 'this.gg.controlOn();' in exitstep,'exit16 control is deferred, not deleted')
    check('this.t_exit = 0' not in step+exitstep,'no forced zero native exit')
    check('this.clickReq = 0' not in step+exitstep,'native required click is not cleared')
    check(step.index('this.rconnectCancelLoading();')<step.index('this.newGame1();'),'newGame cancels hold before replacement')
    load=step[step.index('if(this.comLoad >= 0)'):]
    check(load.index('this.rconnectCancelLoading();')<load.index('this.loadGame('),'loadGame cancels hold before replacement')
    check('if(!early.active)advanceSharedTravelFade();' in room,'early path retains full native countdown')
    check('!completingEarly &&' in room and 'early.allowPaint(game.world,nativeFrame);' in room,'early restore does not release old first-raster gate midway')
    check('if(early.active){early.allowPaint' in body(room,'commit'),'host capture/grant retains simulation hold')
    check('if(!game.mapGeneration.releaseEarly(id))' in body(room,'completeEarly'),'activation requires exact external release')
    check('early.paintAllowed && resumable' in body(room,'cancelEarly'),'postgrant cancellation remains fail-closed')
    check('if(!resumable && pauseWorld===game.world)pauseWorld=null;' in room,'old Game pause is not transplanted into replacement Game')
    check('getChildByName("SandevistanTravelHoldV1")' in body(mapping,'acquireEarly'),'external hold resolves explicit public carrier')
    check('getChildByName' not in body(mapping,'releaseEarly'),'release uses retained carrier identity')
    check('sandy-travel-hold/1' in mapping and 'state.phase!=="idle"' in mapping,'external contract and idle predicate are explicit')
    check(not (HERE/'host-import/fe/graph/Grafon.as').exists(),'ACC Grafon including wall bridge is unchanged')
    check(not (HERE/'src/rconnect/game/GameBridge.as').exists(),'recovery16 wall/restore GameBridge remains unchanged')
    for name in ('NativeTileState','NativeRoomState'):
        check(sha(HERE/'components/tile/rconnect/game'/f'{name}.as')==sha(ROOT/'build/m52/recovery-16/src/rconnect/game'/f'{name}.as'),name+' is exact full serializer, no field exclusion')
    check('§§' not in world+game,'host import has no FFDec pseudo-instructions')
    result={'passed':all(r['passed'] for r in rows),'assertions':rows,'compiled':False,'AIR_started':False,'native_qualified':False}
    (HERE/'source-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'checks':len(rows),'failed':sum(not r['passed'] for r in rows),'compiled':False}))
    if not result['passed']:raise SystemExit(1)
if __name__=='__main__':main()
