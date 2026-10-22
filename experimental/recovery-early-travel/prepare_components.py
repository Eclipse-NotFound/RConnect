"""Generate real-class components and exact native-method probes; no JVM/AIR."""
from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-16/src'
FIX=ROOT/'build/m52/recovery-seed-first-raster-room-01/src'
HOST=ROOT/'build/m52/recovery-wall-surfaces-host-01/after/scripts'
sources={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def text(p):sources[str(p.relative_to(ROOT))]=sha(p);return p.read_text(encoding='utf-8-sig')
def put(p,s):
    p=HERE/p;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def change(s,a,b):
    assert s.count(a)==1,(a[:90],s.count(a))
    return s.replace(a,b)
def method(s,name):
    m=re.search(r'      (?:public|private|protected|internal)(?:\s+(?:override|static))* function '+name+r'\(',s)
    assert m,name
    start=s.index('{',m.start());depth=1;i=start+1
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[m.start():i]+'\n'
def rooms():
    for p in FIX.rglob('*.as'):
        rel=p.relative_to(FIX).as_posix();s=text(p)
        if rel=='rconnect/game/GameBridge.as':
            s=change(s,'      public var dead:Boolean=false,rasterFinishes:int=0;',
                '      public var dead:Boolean=false,rasterFinishes:int=0,captures:int=0;\n      public var onRestore:Function,restoreFailure:Boolean=false;')
            s=change(s,'public function checkpoint():Object{return {key:roomKey(),width:12,height:8};}',
                'public function checkpoint():Object{captures++;return {key:roomKey(),width:12,height:8};}')
            s=change(s,'         if(String(s.key)!=roomKey())throw new Error("Fixture: foreign-room checkpoint");restores++;',
                '         if(onRestore!=null)onRestore();\n         if(restoreFailure)throw new Error("Fixture: intentional restore failure");\n         if(String(s.key)!=roomKey())throw new Error("Fixture: foreign-room checkpoint");restores++;')
        if rel=='rconnect/core/Session.as':
            s=change(s,'      public var peers:Array=[],outbox:Array=[],link:TcpLink=new TcpLink(),server:Object;',
                '      public var peers:Array=[],outbox:Array=[],link:TcpLink=new TcpLink(),server:Object;\n      public var hostEarlyTravel:int=0;')
        if rel=='rconnect/core/MapGeneration.as':
            s=change(s,'      public var nativeTravelSupported:Boolean=true;',
                '      public var nativeTravelSupported:Boolean=true,earlyTravelSupported:Boolean=false;')
            s=change(s,'public function sceneMode(land:Object,constructing:Boolean=false):Boolean{return false;}',
                'public function sceneMode(land:Object,constructing:Boolean=false):Boolean{return land.sceneMerged===true;}')
            s=change(s,'      public function reset():void{}',
                '      public var externalAvailable:Boolean=true,externalAcquires:int=0,externalReleases:int=0;\n'
                '      private var heldId:String="";\n'
                '      public function acquireEarly(id:String):Boolean{externalAcquires++;if(!externalAvailable)return false;heldId=id;return true;}\n'
                '      public function releaseEarly(id:String):Boolean{if(heldId==id){externalReleases++;heldId="";}return true;}\n'
                '      public function reset():void{}')
        put('components/room/'+rel,s)
    for rel in ('rconnect/core/RoomSync.as','rconnect/core/EarlyTravelGate.as','rconnect/core/FirstRasterGate.as',
                'rconnect/core/SeedRasterEntry.as','rconnect/core/NativeTravelPlan.as','rconnect/ui/RoomEntryView.as',
                'rconnect/net/RoomCodec.as','rconnect/net/Protocol.as'):
        p=HERE/'src'/rel
        if not p.is_file():p=BASE/rel
        put('components/room/'+rel,text(p))
    put('components/room/EarlyTravelRoomChecks.as',text(HERE/'tests/EarlyTravelRoomChecks.as'))
    put('components/gate/EarlyTravelGateChecks.as',text(HERE/'tests/EarlyTravelGateChecks.as'))
    put('components/gate/rconnect/core/EarlyTravelGate.as',text(HERE/'src/rconnect/core/EarlyTravelGate.as'))
def native():
    for name,p in [('NativeWorldBefore',HOST/'fe/World.as'),('NativeWorldAfter',HERE/'host-import/fe/World.as')]:
        s=text(p);names=['exitStep','step']
        if name=='NativeWorldAfter':names=['rconnectLoadingHold','rconnectCancelLoading']+names
        body='\n'.join(method(s,n) for n in names)
        body=body.replace('internal function exitStep','public function exitStep')
        prefix='''package {
   import flash.ui.Mouse;
   import fe.loc.Game;
   public dynamic class NAME {
      public static var fps:Number=30;
      public var errors:Array=[],saves:int=0,loads:int=0,newCalls:int=0,dieCalls:int=0;
      public function showError(e:*):void{errors.push(String(e));}
      public function cur(s:String):void{}
      public function getLoadScreen():Object{return null;}
      public function setLoadScreen(s:Object=null):void{}
      public function offLoadScreen():void{}
      public function waitLoadClick():void{this.clickReq=1;}
      public function newGame1():void{newCalls++;}
      public function newGame2():void{newCalls++;}
      public function saveGame():void{saves++;}
      public function loadGame(n:int):void{loads++;}
      public function ggDieStep():void{dieCalls++;}
'''.replace('NAME',name)
        put('components/native/'+name+'.as',prefix+body+'   }\n}\n')
    put('components/native/fe/loc/Game.as','package fe.loc { public class Game {public static var rconnectTravelBridge:Function;} }\n')
    put('components/native/Snd.as','package {public class Snd {public static var off:Boolean;public static function step():void{}}}\n')
    put('components/native/Emitter.as','package {public class Emitter {public static var kol1:int=0,kol2:int=0;}}\n')
    put('components/native/EarlyNativeChecks.as',text(HERE/'tests/EarlyNativeChecks.as'))
def external():
    s=text(HERE/'src/rconnect/core/MapGeneration.as')
    bodies='\n'.join(method(s,n) for n in ('acquireEarly','releaseEarly'))
    prefix='''package {
   import rconnect.core.Log;
   public class NativeMapLeaseProbe {
      private var session:Object,earlyCarrier:Object,earlyWorld:Object,earlyGame:Object;
      private var earlyOwner:Object={},earlyLeaseId:String="";
      public function NativeMapLeaseProbe(s:Object){session=s;}
'''
    put('components/external/NativeMapLeaseProbe.as',prefix+bodies+'   }\n}\n')
    put('components/external/rconnect/core/Log.as',text(FIX/'rconnect/core/Log.as'))
    put('components/external/EarlyExternalChecks.as',text(HERE/'tests/EarlyExternalChecks.as'))
def tiles():
    fixture=ROOT/'experimental/recovery-terrain-loop/components'
    for rel in ('rconnect/game/NativeTileState.as','rconnect/game/NativeRoomState.as'):
        put('components/tile/'+rel,text(BASE/rel))
    for rel in ('fe/loc/Tile.as','fe/unit/Unit.as','fe/unit/RConnectUnitAccess.as',
                'rconnect/game/GameBridge.as','rconnect/game/TurretDisplay.as'):
        put('components/tile/'+rel,text(fixture/rel))
    put('components/tile/EarlyTileChecks.as',text(HERE/'tests/EarlyTileChecks.as'))
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--only-room',action='store_true');args=parser.parse_args()
    if args.only_room:
        sources.update(json.loads((HERE/'component-inputs.json').read_text(encoding='utf-8'))['sources']);rooms()
    else:rooms();native();external();tiles()
    roots={n:{p.relative_to(HERE/'components'/n).as_posix():sha(p) for p in sorted((HERE/'components'/n).rglob('*.as'))} for n in ('room','gate','native','external','tile')}
    put('component-inputs.json',json.dumps({'sources':sources,'components':roots,
        'entries':{'room':['EarlyTravelRoomChecks','NativeTravelRoomChecks'],'gate':['EarlyTravelGateChecks'],'native':['EarlyNativeChecks'],
                   'external':['EarlyExternalChecks'],'tile':['EarlyTileChecks']},
        'legacy_expected_assertions':109,'compiled':False,'AIR_started':False},indent=2)+'\n')
    print(json.dumps({'components':{k:len(v) for k,v in roots.items()},'compiled':False,'AIR_started':False}))
if __name__=='__main__':main()
