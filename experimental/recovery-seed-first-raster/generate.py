"""Sparse legacy-seed first-raster extension on frozen 7975167; no compiler."""
from pathlib import Path
import hashlib,json,difflib,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-first-raster-02'
PIN='7975167afc40992946624a8d73369df05f7c42ff742b52c4573bba0928b8f239'
ROOM='rconnect/core/RoomSync.as'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(name,s):
    p=HERE/name;assert p.resolve().is_relative_to(HERE);p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(s,encoding='utf-8',newline='\n')
def change(s,old,new):
    assert s.count(old)==1,old[:160]
    return s.replace(old,new,1)
def replace_method(s,name,new):
    start=re.search(r'^      (?:public|private) function '+name+r'\(',s,re.M).start()
    opening=s.index('{',start);end=opening+1;depth=1
    while depth:depth+=(s[end]=='{')-(s[end]=='}');end+=1
    return s[:start]+new.rstrip()+s[end:]
def main():
    m=json.loads((BASE/'prepared.json').read_text(encoding='utf-8-sig'))
    assert m['compiled'] and sha(BASE/'RConnectMod.swf')==m['sha256']==PIN
    for rel,h in m['source'].items():assert sha(BASE/'src'/rel)==h,rel
    s=original=(BASE/'src'/ROOM).read_text(encoding='utf-8-sig')
    s=change(s,'      private var firstRaster:FirstRasterGate=new FirstRasterGate();',
        '      private var firstRaster:FirstRasterGate=new FirstRasterGate();\n      private var seedRaster:SeedRasterEntry=new SeedRasterEntry();\n      private var seedDeadline:int=0;')
    s=change(s,'      public function reset():void\n      {\n         firstRaster.cancel();',
        '      public function reset():void\n      {\n         firstRaster.cancel();seedRaster.clear();seedDeadline=0;')
    s=change(s,'if(ready || busy || nativeTravelPending)reset();','if(ready || busy || nativeTravelPending || seedRaster.active)reset();')
    s=change(s,'            game.refreshWorld();\n            if(game.world==null || game.loc==null || game.gg==null)return;', '''            game.refreshWorld();
            if(seedRaster.active && (!seedRaster.matchesWorld(game.world) || game.isPlayerDead()))cancelSeedRaster(true);
            if(seedRaster.active && getTimer()>seedDeadline && !blocked)throw new Error("Seed raster entry timed out");
            if(game.world==null || game.loc==null || game.gg==null)return;''')
    s=change(s,'         if(nativeTravel.retiredToken(info.travelId))return;',
        '         if(seedRaster.active && !seedRaster.matchesInfo(info))return;\n         if(nativeTravel.retiredToken(info.travelId))return;')
    s=change(s,'               nativeTravel.markStarted(game.world);game.activeTravelId=nativeTravel.id;\n            }', '''               nativeTravel.markStarted(game.world);game.activeTravelId=nativeTravel.id;
            }else if(seedRaster.start(info,game.world,previousLand,epoch,pending)) {
               seedDeadline=getTimer()+45000;
            }''')
    s=change(s,'      public function openFirstRaster(w:Object,l:Object,g:Object):Object {', '''      public function openFirstRaster(w:Object,l:Object,g:Object):Object {
         if(seedRaster.active) {
            if(!seedRaster.matchesWorld(w)){cancelSeedRaster(true);return null;}
            if(session.mode!=Session.CONNECTED || blocked || w!==game.world || l==null || g==null || game.isPlayerDead())return null;
            if(!seedRaster.destination(w,l)) {firstRaster.cancel();return null;}
            if(g.scenePreload!==true && g.sceneCullRender!==true) {firstRaster.cancel();return null;}
            if(firstRaster.active && !firstRaster.matches(w,l,g,seedRaster.id)) {firstRaster.cancel();return null;}
            return firstRaster.open(w,l,g,seedRaster.id);
         }''')
    s=replace_method(s,'finishFirstRaster','''      private function finishFirstRaster():void {
         var seeded:Boolean=seedRaster.active;
         var rasterId:String=seeded?seedRaster.id:nativeTravel.id;
         var matches:Boolean=seeded?seedRaster.destination(game.world,game.loc):nativeTravel.matchesWorld(game.world);
         if(!connected() || host() || game.isPlayerDead() || !matches
            || !firstRaster.matches(game.world,game.loc,game.world==null?null:game.world.grafon,rasterId)) {
            if(seeded)cancelSeedRaster(true);else cancelNativeEntry(true);return;
         }
         if(!firstRaster.ready(game.world,game.loc,game.world.grafon,rasterId,nativeFrame))return;
         game.finishFirstRaster();
         var receipt:Object=firstRaster.complete();
         if(pending!=int(receipt.barrier) || epoch!=int(receipt.epoch)
            || seeded && !seedRaster.acceptsBarrier(pending,epoch))throw new Error("First raster barrier changed");
         send({op:"ack",barrier:pending,travelId:seeded?"":String(receipt.travelId)});
         if(seeded){seedRaster.clear();seedDeadline=0;}
         else {nativeTravel.finish(String(receipt.travelId));clearNativeEntry();nativeDeadline=0;game.activeTravelId="";}
         pending=0;readySent=false;release();
         Log.d("RConnectRoom: first raster ready "+settledKey+" term="+term+" ms="+(getTimer()-barrierStarted));
      }''')
    s=change(s,'      private function clearNativeEntry():void {', '''      private function cancelSeedRaster(discardBarrier:Boolean=false):void {
         if(!seedRaster.active)return;
         firstRaster.cancel();seedRaster.clear();seedDeadline=0;preparing=null;
         if(discardBarrier){pending=0;readySent=false;requested=false;}
         TravelGuard.endTravel();
      }
      private function clearNativeEntry():void {''')
    s=change(s,'      private function acceptsJoinGrant(msg:Object):Boolean {', '''      private function acceptsJoinGrant(msg:Object):Boolean {
         if(seedRaster.active)return seedRaster.acceptsGrant(msg,game.world,game.loc);''')
    s=change(s,'            if(!nativeTravel.matchesWorld(game.world)) {\n               cancelNativeEntry(true);return true;', '''            if(seedRaster.active && (!seedRaster.matchesWorld(game.world) || game.isPlayerDead())) {
               cancelSeedRaster(true);return true;
            }
            if(!nativeTravel.matchesWorld(game.world)) {
               cancelNativeEntry(true);return true;''')
    s=change(s,'            else if(msg.op=="prepare") {',
        '            else if(msg.op=="prepare") {\n               if(seedRaster.active)return true; // cannot replace the already started local identity')
    s=change(s,'               if(!nativeTravel.accepts(msg.travelId))return true;\n               if(nativeTravel.current!=null) {', '''               if(!nativeTravel.accepts(msg.travelId))return true;
               var repeatedSeedSeal:Boolean=seedRaster.active && seedRaster.acceptsBarrier(int(msg.barrier),int(msg.epoch));
               if(seedRaster.active && !seedRaster.acceptSeal(msg))return true;
               if(repeatedSeedSeal)return true;
               if(nativeTravel.current!=null) {''')
    s=change(s,'if(!firstRaster.sameGrant(int(msg.barrier),int(msg.epoch),String(msg.travelId)))',
        'if(!firstRaster.sameGrant(int(msg.barrier),int(msg.epoch),seedRaster.active?seedRaster.id:String(msg.travelId)))')
    s=change(s,'               var delayedRaster:Boolean=completingNative && firstRaster.active;\n               if(delayedRaster)firstRaster.beginRestore(game.world,game.loc,game.world.grafon,nativeTravel.id);', '''               var completingSeed:Boolean=seedRaster.active;
               var rasterId:String=completingSeed?seedRaster.id:nativeTravel.id;
               var delayedRaster:Boolean=(completingNative || completingSeed) && firstRaster.active;
               if(delayedRaster)firstRaster.beginRestore(game.world,game.loc,game.world.grafon,rasterId);''')
    s=change(s,'               else if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)', '''               else if(completingSeed) {
                  if(game.roomKey()!=String(seedRaster.anchor.roomKey))throw new Error("Seed entry room differs");
                  TravelPlacement.place(game.gg,Number(seedRaster.anchor.x),Number(seedRaster.anchor.y));
               }
               else if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)''')
    s=change(s,'firstRaster.restored(game.world,game.loc,game.world.grafon,nativeTravel.id,pending,epoch,nativeFrame);',
        'firstRaster.restored(game.world,game.loc,game.world.grafon,rasterId,pending,epoch,nativeFrame);')
    s=change(s,'               }else if(nativePreviousBarrier==pending)nativePreviousBarrier=0;',
        '               }else if(completingSeed){seedRaster.clear();seedDeadline=0;}\n               else if(nativePreviousBarrier==pending)nativePreviousBarrier=0;')
    s=change(s,'      private function fail(error:Error):void\n      {\n         firstRaster.cancel();',
        '      private function fail(error:Error):void\n      {\n         cancelSeedRaster(true);firstRaster.cancel();')
    put('src/'+ROOM,s)
    put('proposal.patch',''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='7975167/'+ROOM,tofile='seed-raster/'+ROOM)))
    outputs={p.relative_to(HERE/'src').as_posix():sha(p) for p in sorted((HERE/'src').rglob('*.as'))}
    put('integration.json',json.dumps(dict(base=str(BASE.relative_to(ROOT)),base_sha256=PIN,base_source_sha256=m['source'][ROOM],
        sources=outputs,host_sha256='fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e',
        compiled=False,runtime_tested=False,installed=False),indent=2)+'\n')
    print(json.dumps(dict(sparse_overlays=len(outputs),compiled=False)))
if __name__=='__main__':main()
