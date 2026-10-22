"""Source-only sparse candidate. No compiler, AIR, installed-file writes."""
from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-16/src'
HOST=ROOT/'build/m52/recovery-wall-surfaces-host-01/after/scripts'
sources={}
def read(p):return p.read_text(encoding='utf-8-sig')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,a,b,n=1):
    assert s.count(a)==n,(a[:100],s.count(a),n)
    return s.replace(a,b)
def save(rel,base,source):
    p=HERE/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(source,encoding='utf-8',newline='\n')
    sources[rel]={'base':str(base.relative_to(ROOT)),'base_sha256':sha(base),'sha256':sha(p)}
    diff=''.join(difflib.unified_diff(read(base).splitlines(True),source.splitlines(True),fromfile=str(base.relative_to(ROOT)),tofile=rel))
    d=HERE/'patches'/(Path(rel).name+'.patch');d.parent.mkdir(parents=True,exist_ok=True);d.write_text(diff,encoding='utf-8')

def room():
    p=BASE/'rconnect/core/RoomSync.as';s=read(p)
    s=replace(s,'      private var firstRaster:FirstRasterGate=new FirstRasterGate();','''      private var firstRaster:FirstRasterGate=new FirstRasterGate();
      private var early:EarlyTravelGate=new EarlyTravelGate();
      private var earlyNonce:String=getTimer().toString(16)+"-"+uint(Math.random()*4294967295).toString(16);
      private var earlySerial:int=0,earlySeal:Object;
      private var earlyControlHeld:Boolean=false,earlyViewFinished:Boolean=false;''')
    s=replace(s,'      public function reset():void\n      {','      public function reset():void\n      {\n         cancelEarly(false,true,true);')
    s=replace(s,'            if(firstRaster.awaitingView)try {finishFirstRaster();}catch(error:Error){fail(error);}',
                  '            if(early.active)try {finishEarly();}catch(earlyError:Error){fail(earlyError);}\n            else if(firstRaster.awaitingView)try {finishFirstRaster();}catch(error:Error){fail(error);}')
    s=replace(s,'if(ready || busy || nativeTravelPending || seedRaster.active)reset();','if(ready || busy || nativeTravelPending || seedRaster.active || early.active)reset();')
    s=replace(s,'            game.refreshWorld();\n            if(seedRaster.active',
                  '            game.refreshWorld();\n            if(early.active && (!early.safeWorld(game.world) || game.isPlayerDead()))cancelEarly(false,true);\n            if(seedRaster.active')
    s=replace(s,'            advanceSharedTravelFade();','            if(!early.active)advanceSharedTravelFade();')
    s=replace(s,'      private function check():void\n      {','      private function check():void\n      {\n         if(early.active){checkEarly();return;}')
    s=replace(s,'         if(game.isTransitioning())return;\n         if(pending>0)return;',
                  '         if(game.isTransitioning() && !(early.active && early.valid(game.world)))return;\n         if(pending>0)return;')
    s=replace(s,'         var entryInfo:Object=game.readWorldInfo();','         var entryInfo:Object=game.readWorldInfo();\n         if(early.active)entryInfo.worldReady=true;')
    s=replace(s,'         send({op:"seal",barrier:pending,epoch:epoch,info:entryInfo,travelId:nativeTravel.id,entryAnchor:entryAnchor,\n            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),\n            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)});',
'''         var seal:Object={op:"seal",barrier:pending,epoch:epoch,info:entryInfo,travelId:nativeTravel.id,entryAnchor:entryAnchor,
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),
            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)};
         if(early.active){seal.earlyId=early.id;if(!early.acceptSeal(seal))throw new Error("Early host seal differs");}
         send(seal);''')
    s=replace(s,'         if(info==null || host() || info.worldReady===false)return;',
                  '         if(info==null || host() || info.worldReady===false || early.active)return;')
    s=replace(s,'         var message:Object=nativeTravel.offer(info,epoch,game.world);',
                  '         offerEarly(info);\n         var message:Object=nativeTravel.offer(info,epoch,game.world);')
    s=replace(s,'         send({op:"prepare",info:{curLandId:String(land.act.id),layoutSeed:seed,\n            layoutLevel:Number(land.landDifLevel),landStage:Number(land.act.landStage),\n            hostVisited:Boolean(land.act.visited),sceneMerged:game.mapGeneration.sceneMode(land,constructing),worldReady:true}});',
'''         var info:Object={curLandId:String(land.act.id),layoutSeed:seed,
            layoutLevel:Number(land.landDifLevel),landStage:Number(land.act.landStage),
            hostVisited:Boolean(land.act.visited),sceneMerged:game.mapGeneration.sceneMode(land,constructing),worldReady:true};
         offerEarly(info);send({op:"prepare",info:info});''')
    s=replace(s,'         if(game.startSharedTravel(info)) {\n            if(nativeTravel.current!=null)',
'''         armEarly(info);
         if(early.active){flush();session.flushProgress();}
         if(game.startSharedTravel(info)) {
            if(early.active && busy && pending==0) {
               if(pauseWorld!=null)pauseWorld.onPause=savedPause;
               pauseWorld=null;busy=false;game.roomHold=false;
            }
            if(nativeTravel.current!=null)''')
    s=replace(s,'            game.independentRooms=false;\n         }\n      }\n      /** Called only',
'''            game.independentRooms=false;
         }else if(early.active)cancelEarly(true,true);
      }
      /** Called only''')
    s=replace(s,'      public function openFirstRaster(w:Object,l:Object,g:Object):Object {',
'''      public function openFirstRaster(w:Object,l:Object,g:Object):Object {
         if(early.active) {
            if(blocked || w!==game.world || !early.safeWorld(w))return null;
            var ticket:Object=early.open(w,l,g);
            if(ticket==null)cancelEarly(true,true);
            return ticket;
         }''')
    s=replace(s,'      private function acceptsJoinGrant(msg:Object):Boolean {',
'''      private function acceptsJoinGrant(msg:Object):Boolean {
         if(early.active)return early.accepts(msg) && early.valid(game.world)
            && String(msg.key)==String(early.anchor.roomKey);''')
    anchor='''            if(host())
            {
               if(msg.op=="request")'''
    s=replace(s,anchor,'''            if(msg.op=="earlyCancel") {
               if(early.active && String(msg.earlyId)==early.id)cancelEarly(false,true);
               return true;
            }
            if(String(msg.earlyId || "")!="" && (!early.active || String(msg.earlyId)!=early.id))return true;
            if(early.active) {
               if(!early.safeWorld(game.world) || game.isPlayerDead()){cancelEarly(false,true);return true;}
               if(blocked)return true;
               if(msg.op=="seal" && !host()) {
                  if(!early.acceptSeal(msg))return true;
                  if(earlySeal==null && !readySent)earlySeal=msg;
                  checkEarly();return true;
               }
               if(msg.op=="activate" && !host()) {
                  if(early.accepts(msg) && early.ackSent && early.localReady)completeEarly();
                  return true;
               }
               if(msg.op=="ack" && host()) {
                  if(early.accepts(msg) && early.paintAllowed){early.peerReady=true;finishEarly();}
                  return true;
               }
               if(msg.op=="request" || msg.op=="prepare")return true;
               if(msg.op=="ready" && host() && (!early.accepts(msg) || !early.constructed || early.paintAllowed))return true;
               if(msg.op=="grant" && (!early.accepts(msg) || early.paintAllowed))return true;
            }
            if(host())
            {
               if(msg.op=="request")''')
    s=replace(s,'               var completingNative:Boolean=nativeTravel.current!=null',
                  '               var completingEarly:Boolean=early.active;\n               var completingNative:Boolean=nativeTravel.current!=null')
    s=replace(s,'               var delayedRaster:Boolean=(completingNative || completingSeed) && firstRaster.active;',
                  '               var delayedRaster:Boolean=!completingEarly && (completingNative || completingSeed) && firstRaster.active;')
    s=replace(s,'               if(completingNative) {\n                  nativeTravel.acceptAnchor(msg.entryAnchor);',
'''               if(completingEarly) {
                  if(game.roomKey()!=String(early.anchor.roomKey))throw new Error("Early entry room differs");
                  TravelPlacement.place(game.gg,Number(early.anchor.x),Number(early.anchor.y));
               }
               else if(completingNative) {
                  nativeTravel.acceptAnchor(msg.entryAnchor);''')
    s=replace(s,'               TravelGuard.endTravel();\n               if(delayedRaster)',
'''               TravelGuard.endTravel();
               if(completingEarly) {
                  early.allowPaint(game.world,nativeFrame);mod.stage.invalidate();return true;
               }
               if(delayedRaster)''')
    s=replace(s,'         if(game.isTransitioning() || game.loc==null)return;',
                  '         if(game.loc==null || game.isTransitioning() && !(early.active && early.valid(game.world)))return;')
    s=replace(s,'         if(nativeTravel.current!=null && !(nativePreviousBarrier>0 && pending==nativePreviousBarrier)',
                  '         if(!early.active && nativeTravel.current!=null && !(nativePreviousBarrier>0 && pending==nativePreviousBarrier)')
    s=replace(s,'         send({op:"ready",barrier:pending,epoch:epoch,info:info,',
                  '         send({op:"ready",barrier:pending,epoch:epoch,info:info,earlyId:early.id,')
    s=replace(s,'            travelId:nativeTravel.id,entryAnchor:nativeTravel.anchor,',
                  '            travelId:nativeTravel.id,entryAnchor:nativeTravel.anchor,earlyId:early.id,')
    s=replace(s,'         release();\n      }\n      private function flush():void',
                  '         if(early.active){early.allowPaint(game.world,nativeFrame);mod.stage.invalidate();}\n         else release();\n      }\n      private function flush():void')
    s=replace(s,'         cancelSeedRaster(true);firstRaster.cancel();\n         hold();blocked=true;',
'''         // Do not release an early raster or pause after a failed import.
         if(!early.active){cancelSeedRaster(true);firstRaster.cancel();}
         hold();blocked=true;''')
    s=replace(s,'      private function currentSettledRoom():Boolean',read(HERE/'room-methods.as.txt')+'\n      private function currentSettledRoom():Boolean')
    save('src/rconnect/core/RoomSync.as',p,s)

def mapping():
    p=BASE/'rconnect/core/MapGeneration.as';s=read(p)
    s=replace(s,'      public var nativeTravelSupported:Boolean=false;',
'''      public var nativeTravelSupported:Boolean=false;
      public var earlyTravelSupported:Boolean=false;
      private var earlyCarrier:Object,earlyWorld:Object,earlyGame:Object;
      private var earlyOwner:Object={},earlyLeaseId:String="";''')
    s=replace(s,'            nativeGame.rconnectTravelBridge=nativeTravel;nativeTravelSupported=true;',
                  '            nativeGame.rconnectTravelBridge=nativeTravel;nativeTravelSupported=true;\n            earlyTravelSupported=("rconnectEarlyTravelVersion" in nativeGame) && int(nativeGame.rconnectEarlyTravelVersion)==1;')
    s=replace(s,'         if(session.rooms==null || session.mode!=Session.CONNECTED)return null;',
                  '         if(session.rooms==null || session.mode!=Session.CONNECTED && !session.rooms.earlyTravelPending)return null;')
    s=replace(s,'         var bridge:GameBridge=session.mod.game;\n         if(bridge.world==null',
'''         var bridge:GameBridge=session.mod.game;
         if(session.rooms!=null && phase=="loadingHold")return session.rooms.nativeLoadingHold(g);
         if(session.rooms!=null && phase=="cancel-load"){session.rooms.cancelNativeLoading(g);return null;}
         if(session.rooms!=null && phase=="constructed") {
            bridge.refreshWorld();session.rooms.nativeConstructed(g);return null;
         }
         if(bridge.world==null''')
    s=replace(s,'      public function reset():void {', '''      /** Optional A-version contract. Missing or unreadable is not idle. */
      public function acquireEarly(id:String):Boolean {
         var w:Object=session.mod.game.world;
         if(id=="" || w==null || w.game==null)return false;
         if(earlyCarrier!=null)return earlyLeaseId==id && earlyWorld===w && earlyGame===w.game;
         // A local room hold may account for onPause; any other pause/menu is
         // not an eligible starting state for this optimization.
         if(w.onPause && !session.mod.game.roomHold || w.pip!=null && w.pip.active
            || w.sats!=null && w.sats.active || w.stand!=null && w.stand.active
            || w.gui!=null && w.gui.guiPause)return false;
         try {
            var c:Object=session.mod.game.main.getChildByName("SandevistanTravelHoldV1");
            if(c==null || int(c.version)!=1 || String(c.contract)!="sandy-travel-hold/1")return false;
            var state:Object=c.query(w,w.game);
            if(state==null || state.version!==1 || state.contract!=="sandy-travel-hold/1"
               || state.phase!=="idle" || state.debugTest===true)return false;
            if(c.acquire(earlyOwner,w,w.game,id)!==true)return false;
            earlyCarrier=c;earlyWorld=w;earlyGame=w.game;earlyLeaseId=id;return true;
         }catch(error:Error){Log.d("RConnectEarly: external acquire unavailable: "+error);return false;}
         return false; // ASC requires an explicit post-try fallthrough.
      }
      public function releaseEarly(id:String):Boolean {
         if(earlyCarrier==null)return true;
         if(id!=earlyLeaseId)return false;
         try {
            var released:Boolean=earlyCarrier.release(earlyOwner,id)===true;
            var current:Object=session.mod.game.world;
            if(!released && (current==null || current===earlyWorld && current.game===earlyGame))return false;
            earlyCarrier=earlyWorld=earlyGame=null;earlyLeaseId="";return true;
         }catch(error:Error){Log.d("RConnectEarly: external release failed: "+error);return false;}
         return false; // ASC requires an explicit post-try fallthrough.
      }
      public function reset():void {
         if(earlyCarrier!=null)releaseEarly(earlyLeaseId);''')
    save('src/rconnect/core/MapGeneration.as',p,s)

def session():
    p=BASE/'rconnect/core/Session.as';s=read(p)
    s=replace(s,'      public var peers:Array = [];','      public var peers:Array = [];\n      public var hostEarlyTravel:int=0;')
    s=replace(s,'      private function stop():void\n      {','      private function stop():void\n      {\n         hostEarlyTravel=0;')
    s=replace(s,'{name: myName,nativeTravel:mod.game.mapGeneration.nativeTravelSupported?1:0}',
                  '{name: myName,nativeTravel:mod.game.mapGeneration.nativeTravelSupported?1:0,earlyTravel:mod.game.mapGeneration.earlyTravelSupported?1:0}')
    s=replace(s,'            case Protocol.MSG_WELCOME:\n               myId',
                  '            case Protocol.MSG_WELCOME:\n               hostEarlyTravel=int(msg.earlyTravel);\n               myId')
    s=replace(s,'snap: null,nativeTravel:int(msg.nativeTravel)}',
                  'snap: null,nativeTravel:int(msg.nativeTravel),earlyTravel:int(msg.earlyTravel)}')
    s=replace(s,'{id: link.id, name: myName, worldInfo: wInfo,nativePrepare:',
                  '{id: link.id, name: myName, worldInfo: wInfo,earlyTravel:mod.game.mapGeneration.earlyTravelSupported?1:0,nativePrepare:')
    save('src/rconnect/core/Session.as',p,s)

def host():
    p=HOST/'fe/loc/Game.as';s=read(p)
    s=replace(s,'      public static var rconnectTravelBridge:Function = null;',
                  '      public static var rconnectTravelBridge:Function = null;\n      public static const rconnectEarlyTravelVersion:int = 1;')
    s=replace(s,'         World.w.time___metr("Вход в местность");',
                  '         World.w.time___metr("Вход в местность");\n         if(rconnectTravelBridge != null)rconnectTravelBridge("constructed",this,null);')
    save('host-import/fe/loc/Game.as',p,s)
    p=HOST/'fe/World.as';s=read(p)
    s=replace(s,'      internal function exitStep() : *',
'''      private function rconnectLoadingHold() : Boolean
      {
         return Game.rconnectTravelBridge != null && Game.rconnectTravelBridge("loadingHold",this.game,null) != null;
      }
      private function rconnectCancelLoading() : void
      {
         if(Game.rconnectTravelBridge != null)Game.rconnectTravelBridge("cancel-load",this.game,null);
      }
      internal function exitStep() : *''')
    a='''               this.cam.dblack = -10;
               this.gg.controlOn();
               this.pip.noAct = false;'''
    s=replace(s,a,'''               this.cam.dblack = -10;
               if(!this.rconnectLoadingHold())
               {
                  this.gg.controlOn();
                  this.pip.noAct = false;
               }''')
    s=replace(s,'            if(this.ng_wait > 0)\n            {',
                  '            if(this.ng_wait > 0)\n            {\n               this.rconnectCancelLoading();')
    s=replace(s,'            if(this.allStat == 1 && !this.onPause)',
                  '            if(this.allStat == 1 && (!this.onPause || this.rconnectLoadingHold()))')
    s=replace(s,'               Emitter.kol2 = Emitter.kol1;',
'''               // exitStep may have frozen this shared destination in this frame.
               if(!this.rconnectLoadingHold())
               {
               Emitter.kol2 = Emitter.kol1;''')
    s=replace(s,'               this.checkLoot = false;\n            }\n            if(this.comLoad >= 0)',
                  '               this.checkLoot = false;\n               }\n            }\n            if(this.comLoad >= 0)')
    s=replace(s,'            if(this.comLoad >= 0)\n            {',
                  '            if(this.comLoad >= 0)\n            {\n               this.rconnectCancelLoading();')
    s=replace(s,'               if(this.ctr.keyPip)\n               {',
'''               if(!this.rconnectLoadingHold())
               {
               if(this.ctr.keyPip)
               {''')
    s=replace(s,'               this.allStat = this.pip.active || this.sats.active',
'''               }
               else
               {
                  // Preserve native load-click input; discard menu hotkeys only.
                  this.ctr.keyPip = this.ctr.keyInvent = this.ctr.keyStatus = this.ctr.keySkills = false;
                  this.ctr.keyMed = this.ctr.keyMap = this.ctr.keyQuest = this.ctr.keySats = false;
               }
               this.allStat = this.pip.active || this.sats.active''')
    save('host-import/fe/World.as',p,s)

def main():
    room();mapping();session();host()
    manifest={'base':'build/m52/recovery-16','host':'build/m52/recovery-wall-surfaces-host-01',
      'baseline_grafon_sha256':sha(HOST/'fe/graph/Grafon.as'),'grafon_changed':False,
      'sources':sources,'new_gate_sha256':sha(HERE/'src/rconnect/core/EarlyTravelGate.as'),
      'compiled':False,'AIR_started':False,'native_qualified':False}
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'overlays':len(sources),'new_classes':1,'compiled':False,'AIR_started':False}))
if __name__=='__main__':main()
