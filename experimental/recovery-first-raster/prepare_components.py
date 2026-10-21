"""Prepare small real RoomSync/Gate component closures; source only."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-11/src'
FIX=ROOT/'experimental/recovery-native-travel/tests/native-room-component'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(name,value):
    p=HERE/name;assert p.resolve().is_relative_to(HERE)
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value,encoding='utf-8',newline='\n')
def change(s,old,new):
    assert s.count(old)==1,old[:100]
    return s.replace(old,new,1)
def method(s,name):
    import re
    match=re.search(r'      (?:public|private|protected|internal)(?:\s+(?:override|static))* function (?:get |set )?'+name+r'\(',s)
    assert match,name
    start=s.index('{',match.start());depth=1;i=start+1
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[match.start():i]+'\n'
def native_component(sources):
    native=HERE/'native/fe/graph/Grafon.as';s=native.read_text(encoding='utf-8')
    sources[str(native.relative_to(ROOT))]=sha(native)
    bodies='\n'.join(method(s,n) for n in ('rconnectRasterPending','rconnectRasterWaiting','rconnectRasterPainted',
                                         'sceneOpen','sceneEnsure','sceneTick','sceneViewReady'))
    prefix='''package {
   import flash.events.Event;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import fe.World;
   import fe.loc.Location;
   public class NativeRasterHarness {
      public static var rconnectRasterBridge:Function=null;
      private var rconnectRasterTicket:Object;
      public var loc:Location,sceneLarge:Boolean=false,sceneSide:int=320,sceneChunkSide:int=320;
      public var sceneHistory:Dictionary=new Dictionary(),sceneMarks:Array,sceneRasterizing:Boolean=false;
      public var scenePreload:Boolean=true,sceneResident:int=0,sceneChunks:Object={};
      public var lightRect:Rectangle=new Rectangle(),lightBmp:Object={fillRect:function(r:Object,c:uint):void{}};
      public var order:Array=[],ensureCount:int=0,readyScans:int=0,lastLeft:Number=0,lastTop:Number=0;
      public function open(l:Location):void{sceneOpen(l);}
      private function sceneSyncRegionLighting(l:Location):void{order.push("lighting");}
      private function sceneClear():void{order.push("clear");sceneResident=0;sceneChunks={};}
      private function sceneConfigureBorders():void{order.push("borders");}
      private function scenePrepare(l:Location):void{order.push("prepare");}
      private function setLight():void{order.push("setLight");}
      private function sceneIndexBackdrops():void{order.push("backdrops");}
      private function drawAllObjs():void{order.push("objects");}
      private function sceneCullSurfaces():void{}
      private function sceneViewport():Rectangle {
         // Only the exact sceneViewReady body calls this substituted helper.
         // Count scan entry without instrumenting any extracted native method.
         readyScans++;
         var c:Object=World.w.cam;return new Rectangle(-c.vx,-c.vy,c.screenX,c.screenY);
      }
      private function scenePreloadAll():void{fill(0,0,loc.limX,loc.limY);}
      private function sceneEnsureUpcoming(x:Number,y:Number,w:Number,h:Number):void{fill(x,y,w,h);}
      private function fill(x:Number,y:Number,w:Number,h:Number):void {
         ensureCount++;lastLeft=x;lastTop=y;
         for(var cx:int=int(x/sceneSide);cx<int(Math.ceil((x+w)/sceneSide));cx++)
            for(var cy:int=int(y/sceneSide);cy<int(Math.ceil((y+h)/sceneSide));cy++)
               if(sceneChunks[cx+":"+cy]==null){sceneChunks[cx+":"+cy]={};sceneResident++;}
      }
'''
    put('components/native/NativeRasterHarness.as',prefix+bodies+'   }\n}\n')
    put('components/native/fe/World.as','package fe { public class World { public static var w:Object; } }\n')
    put('components/native/fe/loc/Location.as','package fe.loc { public dynamic class Location {} }\n')
    p=HERE/'tests/FirstRasterNativeChecks.as';sources[str(p.relative_to(ROOT))]=sha(p)
    put('components/native/FirstRasterNativeChecks.as',p.read_text(encoding='utf-8'))
def main():
    sources={}
    for p in FIX.rglob('*.as'):
        rel=p.relative_to(FIX).as_posix();s=p.read_text(encoding='utf-8-sig');sources[str(p.relative_to(ROOT))]=sha(p)
        if rel=='NativeTravelRoomChecks.as':
            s=change(s,'         try{run();}','         try{run();rasterCases();}')
            s=change(s,'      private function run():void {',
                     (HERE/'tests/room-cases.inc').read_text(encoding='utf-8')+'\n      private function run():void {')
        if rel=='rconnect/game/GameBridge.as':
            s=change(s,'      public var activeTravelId:String="";',
                     '      public var activeTravelId:String="";\n      public var dead:Boolean=false,rasterFinishes:int=0;\n      public function finishFirstRaster():void {rasterFinishes++;}')
            s=change(s,'public function isPlayerDead():Boolean{return false;}','public function isPlayerDead():Boolean{return dead;}')
        put('components/room/'+rel,s)
    for rel in ('rconnect/core/RoomSync.as','rconnect/core/FirstRasterGate.as','rconnect/core/NativeTravelPlan.as',
                'rconnect/ui/RoomEntryView.as','rconnect/net/RoomCodec.as','rconnect/net/Protocol.as'):
        p=HERE/'src'/rel
        if not p.is_file():p=BASE/rel
        sources[str(p.relative_to(ROOT))]=sha(p);put('components/room/'+rel,p.read_text(encoding='utf-8-sig'))
    for rel,p in [('FirstRasterGateChecks.as',HERE/'tests/FirstRasterGateChecks.as'),
                  ('rconnect/core/FirstRasterGate.as',HERE/'src/rconnect/core/FirstRasterGate.as')]:
        sources[str(p.relative_to(ROOT))]=sha(p);put('components/gate/'+rel,p.read_text(encoding='utf-8-sig'))
    sources[str((HERE/'tests/room-cases.inc').relative_to(ROOT))]=sha(HERE/'tests/room-cases.inc')
    native_component(sources)
    put('component-inputs.json',json.dumps(dict(sources=sources,
        components={folder:{p.relative_to(HERE/'components'/folder).as_posix():sha(p)
                           for p in sorted((HERE/'components'/folder).rglob('*.as'))} for folder in ('room','gate','native')},
        compiled=False,runtime_tested=False,native_game_test=False),indent=2)+'\n')
    print('Prepared room, gate and extracted native-method component sources only')
if __name__=='__main__':main()
