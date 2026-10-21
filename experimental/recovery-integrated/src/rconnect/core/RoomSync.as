package rconnect.core
{
   import modlocales.connect.RCLocale;
   import flash.events.Event;
   import flash.utils.getTimer;
   import rconnect.game.GameBridge;
   import rconnect.net.Protocol;
   import rconnect.net.RoomCodec;
   import rconnect.net.TcpLink;
   import rconnect.ui.RoomEntryView;

   /** Two-player room ownership. Changed rooms flush reports, capture owners,
    * receive a grant and acknowledge it. Unchanged owners keep running.
    * At native transition completion, an unconfirmed room waits for its grant. */
   public class RoomSync
   {
      private var session:Session;
      private var mod:RConnectMod;
      private var game:GameBridge;
      private var records:Object={};
      private var nativeRoom:Object;
      private var nativeLand:Object;
      private var settledRoom:Object;
      private var settledKey:String="";
      private var hostInfo:Object;
      private var peerInfo:Object;
      private var serial:int=0;
      private var pending:int=0;
      private var savedPause:Boolean=false;
      private var pauseWorld:Object;
      private var deadline:int=0;
      private var readySent:Boolean=false;
      private var initial:Boolean=true;
      private var preparing:Object;
      private var nativeTravel:NativeTravelPlan;
      private var nativeDeadline:int=0;
      private var deferredNative:Object;
      private var nativeSeal:Object,nativeStartLand:Object;
      private var nativeBarrier:int=0,nativePreviousBarrier:int=0;
      private var preparedToken:String="";
      private var restoring:Boolean=false;
      private var localEntry:Boolean=false;
      private var barrierStarted:int=0;
      private var freshRoom:Object;
      private var freshWire:String;
      private var heldRoom:Object,heldState:Object,heldWire:String;
      private var blocked:Boolean=false;
      private var requested:Boolean=false;
      private var entryView:RoomEntryView=new RoomEntryView();
      private var teammate:Object,followPending:Object;
      private var followSeenAt:int=0,followAttemptAfter:int=0,followFailures:int=0;
      private var followStarted:Boolean=false;
      public var busy:Boolean=false;
      public var ready:Boolean=false;
      public var authority:Boolean=true;
      public var term:int=0;
      public var epoch:int=0;
      public var status:String="";
      public function get nativeTravelPending():Boolean {return nativeTravel.current!=null || deferredNative!=null;}
      public function get nativePrepare():Object {return nativeTravel.current;}

      public function RoomSync(s:Session)
      {
         session=s;mod=s.mod;game=mod.game;
         nativeTravel=new NativeTravelPlan(getTimer().toString(16)+"-"+uint(Math.random()*4294967295).toString(16));
         game.mapGeneration=new MapGeneration(s);
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-9000);
         // Native exitStep exposes the generated room before t_exit reaches
         // zero. Gate presentation at RENDER as well as the frame boundary;
         // network callbacks/native room activation can run after `after`.
         mod.stage.addEventListener(Event.RENDER,present,false,-2000000000);
      }
      public function reset():void
      {
         if(mod.peerGrip!=null)mod.peerGrip.reset();
         release();records={};nativeRoom=null;nativeLand=null;settledRoom=null;settledKey="";
         ready=false;authority=true;initial=true;epoch=0;term=0;pending=0;hostInfo=null;
         game.independentRooms=false;game.roomEpoch=0;status="";blocked=false;
         requested=false;
         preparing=null;preparedToken="";restoring=false;localEntry=false;
         nativeTravel.reset();nativeDeadline=0;deferredNative=null;game.activeTravelId="";
         clearNativeEntry();
         teammate=null;cancelFollow();
         TravelGuard.reset();
         game.mapGeneration.reset();
         entryView.clear();
      }
      private function currentSettledRoom():Boolean
      {
         return game.world!=null && settledRoom!=null && game.loc===settledRoom
            && game.world.loc===settledRoom && game.world.land===nativeLand;
      }
      /** The locally generated scene is not a confirmed multiplayer room. */
      public function get entryPending():Boolean
      {
         return connected() && game.world!=null && game.world.loc!=null
            && (!ready || localEntry || restoring || blocked || !currentSettledRoom());
      }
      private function present(e:Event=null):void
      {
         if(e!=null)game.refreshWorld();
         if(entryPending)entryView.show(game.world,mod.stage,"");
         else entryView.clear();
      }
      private function connected():Boolean
      {return session.mode==Session.CONNECTED || (session.mode==Session.HOSTING && session.peers.length>0);}
      private function host():Boolean {return session.mode==Session.HOSTING;}
      private function send(o:Object):void
      {
         o.type="room";
         if(host())session.server.broadcast(o);else if(session.link!=null)session.link.send(o);
      }
      private function hold(freeze:Boolean=true):void
      {
         if(!busy){busy=true;deadline=getTimer()+45000;barrierStarted=getTimer();}
         if(!ready || !currentSettledRoom())localEntry=true;
         if(!freeze)return;
         // A room checkpoint must never preserve levitation without its caster.
         if(mod.enemyGrip!=null)mod.enemyGrip.releaseForHandoff();
         if(mod.peerGrip!=null)mod.peerGrip.reset();
         game.releaseMovablesForHandoff();
         if(pauseWorld==null)
         {
            pauseWorld=game.world;savedPause=Boolean(GameBridge.probe(pauseWorld,"onPause"));
         }
         game.roomHold=true;
         if(pauseWorld!=null)pauseWorld.onPause=true;
         // Loading uses the game's own localized artwork. Keep diagnostics in
         // the log and expose only actionable errors through the network HUD.
         status="";
      }
      private function release():void
      {
         if(pauseWorld!=null)pauseWorld.onPause=savedPause;
         busy=false;game.roomHold=false;pauseWorld=null;
         localEntry=false;
         freshRoom=null;freshWire=null;
         heldRoom=null;heldState=null;heldWire=null;
         if(ready && session.progress!=null)session.progress.prepare();
         status=ready?(authority?"分房探索":"共同探索"):"";
      }
      private function before(e:Event):void
      {
         // Force a final presentation check even when native children handle
         // ENTER_FRAME after the Stage listener or turn visibility back on.
         if(connected())mod.stage.invalidate();
         if(!connected()) {if(ready || busy || nativeTravelPending)reset();else entryView.clear();return;}
         try
         {
            game.refreshWorld();
            if(game.world==null || game.loc==null || game.gg==null)return;
            if(deferredNative!=null) {var deferred:Object=deferredNative;deferredNative=null;receiveNativePrepare(deferred);}
            if(!nativeTravel.matchesWorld(game.world)) {
               cancelNativeEntry(true);
            }
            if(nativeTravel.current!=null && game.isPlayerDead()) {
               cancelNativeEntry();
            }
            if(nativeTravel.current!=null && getTimer()>nativeDeadline && !blocked)
               throw new Error("Native travel plan timed out before room confirmation");
            if(busy && pauseWorld===game.world)game.world.onPause=true;
            if(!host())TravelGuard.guardTravel(game,this);
            advanceSharedTravelFade();
            if(host())prepareCachedMap();
            else if(preparing!=null && !game.isTransitioning()) {
               startPreparedMap();
               // Native generation is allowed to run; a completed but not yet
               // granted map must not simulate while waiting for the host seal.
               if(nativeTravel.current!=null && nativeTravel.started && !game.isTransitioning())hold();
            }
            game.world.land.loc_t=0;
            check();
            followTeammate();
            TravelGuard.update(game,!host());
            if((busy || (host() && pending>0)) && getTimer()>deadline && !blocked)
            {
               hold();
               blocked=true;status="房间交接未完成，请断开后重连";
               Log.d("RConnectRoom: handoff timed out; simulation remains paused");
            }
         }
         catch(error:Error){fail(error);}
         finally {present();}
      }
      private function after(e:Event):void
      {
         if(!connected())return;
         try {game.refreshWorld();check();if(game.world!=null && game.world.land!=null)game.world.land.loc_t=0;}
         catch(error:Error){fail(error);}
         finally {present();}
      }
      private function check():void
      {
         if(!host())applyWaitingNativeSeal();
         if(game.loc==null || game.gg==null || game.isTransitioning())return;
         if(!host() && preparing!=null) {
            if(nativeTravel.current!=null && nativePreviousBarrier>0 && pending==nativePreviousBarrier && !readySent)sendReady();
            return;
         }
         if(!host() && hostInfo==null)return;
         if(!host() && String(game.readWorldInfo().curLandId)!=String(hostInfo.curLandId))
         {observeHost(hostInfo);return;}
         var land:Object=game.world.land;
         if(nativeLand!==land)
         {
            nativeLand=land;nativeRoom=null;
            if(host()){epoch++;game.roomEpoch=epoch;records={};settledRoom=null;settledKey="";ready=false;}
         }
         if(nativeRoom!==game.loc)
         {
            nativeRoom=game.loc;
            if(!host() && ready && TravelGuard.restricted(nativeRoom) && game.roomKey()!=String(hostInfo.roomKey))
            {
               if(settledRoom!=null)TravelGuard.returnTo(game,settledRoom);
               nativeRoom=game.loc;notice("剧情和挑战区域需要跟随宿主共同进入");return;
            }
            hold();
            if(host())begin();else
            {
               flush();send({op:"request",epoch:epoch,info:game.readWorldInfo()});
            }
         }
         if(!host() && pending>0 && !readySent && busy)sendReady();
         if(host() && requested && pending==0)begin();
      }
      private function begin():void
      {
         requested=true;
         if(game.isTransitioning())return;
         if(pending>0)return;
         requested=false;
         session.flushProgress();
         hold(!ready || !currentSettledRoom());pending=++serial;blocked=false;
         var entryInfo:Object=game.readWorldInfo();
         var entryAnchor:Object=nativeTravel.captureAnchor(entryInfo);
         send({op:"seal",barrier:pending,epoch:epoch,info:entryInfo,travelId:nativeTravel.id,entryAnchor:entryAnchor,
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),
            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)});
         Log.d("RConnectRoom: seal "+pending+" room="+game.roomKey());
      }
      /** Called for every host world update, including while maps load. */
      public function receivedWelcome(info:Object,nativePrepare:Object=null):void
      {
         // A socket callback can arrive after this frame's Stage listener.
         // Adopt the completed seed now and close the view in the same event.
         try {
            if(nativePrepare!=null)receiveNativePrepare(nativePrepare);
            if(deferredNative==null)observeHost(info);
         }
         catch(error:Error){fail(error);}
         finally {present();mod.stage.invalidate();}
      }
      public function observeHost(info:Object):void
      {
         if(info==null || host() || info.worldReady===false)return;
         if(nativeTravel.retiredToken(info.travelId))return;
         if(nativeTravel.current!=null && String(info.travelId)!=nativeTravel.id)return;
         if(nativeTravel.current!=null && nativePreviousBarrier>0)return;
         game.mapGeneration.receive(info);
         hostInfo=info;
         if(nativeTravel.current!=null && !nativeTravel.started) {
            preparing=nativeTravel.current.info;startPreparedMap();return;
         }
         preparing=null;
         if(game.isPlayerDead() || game.isTransitioning())return;
         game.refreshWorld();var mine:Object=game.readWorldInfo();if(mine==null)return;
         var mapChange:Boolean=String(mine.curLandId)!=String(info.curLandId);
         if(mapChange || game.mapGeneration.differs(info,game.world.land))
         {
            TravelGuard.allowTravel(String(info.curLandId));
            if(game.startSharedTravel(info)) {
               initial=true;game.independentRooms=false;
               settledRoom=null;settledKey="";ready=false;nativeRoom=null;
            }
            return;
         }
         if(!mapChange && int(info.roomEpoch)>0 && epoch!=int(info.roomEpoch))
         {
            epoch=int(info.roomEpoch);game.roomEpoch=epoch;
            settledRoom=null;settledKey="";ready=false;nativeRoom=null;
         }
         if(initial && game.roomKey()!=String(info.roomKey))TravelGuard.follow(game,info,true);
      }
      /** Native Game supplies its actual post-Encounter construction inputs. */
      public function announceNativeTravel(info:Object):void {
         if(!host() || !connected() || nativeTravel.current!=null || pending>0)return;
         if(game.mapGeneration==null || !game.mapGeneration.nativeTravelSupported)return;
         for each(var peer:Object in session.peers)if(int(peer.nativeTravel)!=1)return;
         var message:Object=nativeTravel.offer(info,epoch,game.world);
         game.activeTravelId=nativeTravel.id;nativeDeadline=getTimer()+45000;
         send(message);
         Log.d("RConnectTravel: native prepare "+nativeTravel.id+" target="+info.curLandId+" t="+getTimer());
      }
      public function adoptNativeTravel(nativeGame:Object):Object {
         // loadGame replaces Game/gg inside the same World. The native caller
         // can reach this bridge before the next Stage cancellation check.
         if(!nativeTravel.matchesWorld(game.world)){cancelNativeEntry(true);return null;}
         return nativeTravel.adopt(game.world,nativeGame);
      }
      public function replayNativePrepare(link:TcpLink):void {
         if(!host() || nativeTravel.current==null || link==null)return;
         for each(var peer:Object in session.peers)
            if(peer.link===link && int(peer.nativeTravel)==1){link.send(nativeTravel.current);return;}
      }
      private function receiveNativePrepare(msg:Object):void {
         if(game.mapGeneration==null || !game.mapGeneration.nativeTravelSupported) {
            throw new Error("Native travel plan requires matching host bridge");
         }
         if(!NativeTravelPlan.valid(msg))throw new Error("Invalid native prepare");
         if(game.world==null || game.world.game==null || game.gg==null) {
            if(deferredNative!=null && deferredNative.travelId!==msg.travelId)throw new Error("Native prepare overtook boot");
            deferredNative=msg;return;
         }
         var act:Object=game.world.game.lands[String(msg.info.curLandId)];
         if(act==null || act.rnd)throw new Error("Native prepare target unavailable or random");
         if(!nativeTravel.receive(msg,game.world,epoch))return;
         clearNativeEntry();nativePreviousBarrier=pending;
         msg.info.travelId=nativeTravel.id;preparing=msg.info;
         nativeDeadline=getTimer()+45000;
         game.mapGeneration.receive(preparing);startPreparedMap();
      }
      /** Announce a seed as soon as native construction selects it. The peer
       * can build concurrently instead of waiting for host loading/fade-out. */
      public function prepareMap(land:Object,seed:uint,constructing:Boolean=false):void {
         if(!host() || !connected() || land==null)return;
         var token:String=String(land.act.id)+":"+seed+":"+constructing;
         if(preparedToken==token)return;
         preparedToken=token;
         send({op:"prepare",info:{curLandId:String(land.act.id),layoutSeed:seed,
            layoutLevel:Number(land.landDifLevel),landStage:Number(land.act.landStage),
            hostVisited:Boolean(land.act.visited),sceneMerged:game.mapGeneration.sceneMode(land,constructing),worldReady:true}});
         Log.d("RConnectTravel: prepare "+token+" t="+getTimer());
      }
      private function prepareCachedMap():void {
         var w:Object=game.world;
         if(int(w.t_exit)<=0){preparedToken="";return;}
         if(int(w.t_exit)<=20 || w.game.crea)return;
         var act:Object=w.game.lands[String(w.game.curLandId)];
         if(act!=null && act.land!=null)prepareMap(act.land,uint(GameBridge.probe(act.land,"rconnectLayoutSeed")));
      }
      /** Native quick travel starts at 21. Keep every work-bearing boundary:
       * 20 loading UI, 19 generation, 18/17 required click, 16 control, 1 HUD.
       * Only decorative countdown frames are skipped after the fade completes. */
      private function advanceSharedTravelFade():void {
         var w:Object=game.world;
         if(w==null || w.cam==null || w.vblack==null || int(w.t_exit)<=0
            || int(w.t_die)>0 || int(w.comLoad)>=0)return;
         if(int(w.t_exit)>21) {
            if(Number(w.vblack.alpha)>=1)w.t_exit=21;
            else if(Number(w.cam.dblack)>0)w.cam.dblack=100;
         }else if(int(w.t_exit)<=16 && int(w.t_exit)>2) {
            if(Number(w.cam.dblack)<0)w.cam.dblack=-100;
            if(!w.vblack.visible || Number(w.vblack.alpha)<=0)w.t_exit=2;
         }
      }
      private function startPreparedMap():void {
         if(preparing==null || game.world==null || game.world.game==null || game.gg==null
            || game.isTransitioning() || game.isPlayerDead() || int(game.world.ng_wait)>0)return;
         var info:Object=preparing;
         if(nativeTravel.current!=null && (nativeTravel.started || pending>0 || session.pause!=null && session.pause.paused))return;
         if(nativeTravel.current==null && String(game.world.game.curLandId)==String(info.curLandId)
            && !game.mapGeneration.differs(info,game.world.land))return;
         TravelGuard.allowTravel(String(info.curLandId),nativeTravel.id);
         var previousLand:Object=game.world.land;
         if(game.startSharedTravel(info)) {
            if(nativeTravel.current!=null) {
               // A boot-time unconfirmed room may already be held. Let native
               // exitStep run, without declaring that old room confirmed.
               if(busy && pending==0) {
                  if(pauseWorld!=null)pauseWorld.onPause=savedPause;
                  pauseWorld=null;busy=false;game.roomHold=false;
               }
               nativeStartLand=previousLand;
               nativeTravel.markStarted(game.world);game.activeTravelId=nativeTravel.id;
            }
            initial=true;ready=false;settledRoom=null;settledKey="";nativeRoom=null;
            game.independentRooms=false;
         }
      }
      private function clearNativeEntry():void {
         nativeSeal=null;nativeStartLand=null;nativeBarrier=0;nativePreviousBarrier=0;
      }
      private function cancelNativeEntry(discardBarrier:Boolean=false):void {
         if(discardBarrier) {
            // A replacement Game cannot inherit the previous world's grant,
            // including the legacy barrier that was ahead of this native plan.
            // Clearing only the plan would make an empty travelId valid again.
            pending=0;readySent=false;requested=false;
         }
         nativeTravel.cancel();nativeDeadline=0;preparing=null;game.activeTravelId="";
         clearNativeEntry();TravelGuard.endTravel();
      }
      /** An exit counter alone does not prove this plan built its destination:
       * a paused, rejected or failed native entry can still expose the old Land. */
      private function nativeDestinationReady():Boolean {
         return nativeTravel.current!=null && nativeTravel.started && nativeTravel.consumed
            && nativeTravel.matchesWorld(game.world) && !game.isTransitioning()
            && game.world!=null && game.world.land!=null && game.world.land!==nativeStartLand
            && String(game.world.land.act.id)==String(nativeTravel.current.info.curLandId)
            && String(game.world.game.curLandId)==String(nativeTravel.current.info.curLandId);
      }
      private function applyWaitingNativeSeal():void {
         if(nativeSeal==null || nativePreviousBarrier>0 || !nativeDestinationReady())return;
         // Do not let a seal for a new map replace an unfinished old room grant.
         if(pending>0 && pending!=nativeBarrier)return;
         var msg:Object=nativeSeal;nativeSeal=null;nativeBarrier=int(msg.barrier);
         applySeal(msg);
      }
      private function acceptsJoinGrant(msg:Object):Boolean {
         if(nativeTravel.current==null)return nativeTravel.accepts(msg.travelId);
         if(String(msg.travelId)==nativeTravel.id)
            return nativeBarrier>0 && pending==nativeBarrier && nativeDestinationReady();
         return nativeTravel.current!=null && nativePreviousBarrier>0
            && pending==nativePreviousBarrier && int(msg.barrier)==nativePreviousBarrier
            && String(msg.travelId || "")=="";
      }
      private function applySeal(msg:Object):void {
         if(epoch!=int(msg.epoch)){settledRoom=null;settledKey="";ready=false;}
         observeHost(msg.info);pending=int(msg.barrier);epoch=int(msg.epoch);game.roomEpoch=epoch;
         readySent=false;blocked=false;
         if(msg.together && game.loc!=null && game.roomKey()!=String(msg.info.roomKey) && !game.isTransitioning())
            TravelGuard.follow(game,msg.info,true);
         if(game.loc!=null && game.gg!=null && !game.isTransitioning())sendReady();
      }
      public function stamp(msg:Object):Object
      {
         msg.roomKey=settledKey;msg.roomEpoch=epoch;msg.roomTerm=term;return msg;
      }
      /** Follow departures from a shared room. This prevents two followers
       * exchanging rooms when their two position packets cross in flight. */
      public function observeTeammate(info:Object):void {
         if(info==null){teammate=null;cancelFollow();return;}
         if(mod.config.getValue("followTeammate")!="1")cancelFollow();
         else if(followPending!=null) {
            // A new destination replaces the old request, including its retry
            // timer. A map/epoch change belongs to the normal map barrier.
            if(!sameFollowMap(followPending,info))cancelFollow();
            else {
               if(String(followPending.roomKey)!=String(info.roomKey)) {
                  followAttemptAfter=0;followFailures=0;followStarted=false;
               }
               followPending=info;followSeenAt=getTimer();
            }
         }
         else if(teammate!=null && sameFollowMap(teammate,info)
            && String(teammate.roomKey)!=String(info.roomKey)
            && String(teammate.roomKey)==game.roomKey()
            && mod.config.getValue("followTeammate")=="1") {
            followPending=info;followSeenAt=getTimer();followAttemptAfter=0;followFailures=0;
         }
         teammate=info;
      }
      private function sameFollowMap(a:Object,b:Object):Boolean {
         return a!=null && b!=null && String(a.curLandId)==String(b.curLandId)
            && String(a.curCoord)==String(b.curCoord) && int(a.roomEpoch)==int(b.roomEpoch)
            && Number(a.landStage)==Number(b.landStage);
      }
      private function cancelFollow():void {
         followPending=null;followSeenAt=0;followAttemptAfter=0;followFailures=0;followStarted=false;
      }
      private function followTeammate():void {
         if(followPending==null)return;
         var now:int=getTimer();
         if(mod.config.getValue("followTeammate")!="1" || now-followSeenAt>3000){cancelFollow();return;}
         if(session.pause!=null && session.pause.paused)return;
         if(!ready || busy || pending!=0 || game.isTransitioning() || game.isPlayerDead())return;
         var info:Object=followPending,mine:Object=game.readWorldInfo();
         if(mine==null)return;
         if(!sameFollowMap(info,mine) || int(info.roomEpoch)!=epoch
            || String(info.landProb || "")!="" || TravelGuard.restricted(game.loc)){cancelFollow();return;}
         if(String(info.roomKey)==game.roomKey()) {
            // Reaching a native room is not completion until its ownership
            // handoff has finished. The ready/busy gates above enforce that.
            var arrived:Boolean=followStarted;cancelFollow();
            if(arrived)notice("已跟随队友进入房间");return;
         }
         if(now<followAttemptAfter)return;
         var target:Object;
         try {target=game.world.land.locs[int(info.landX)][int(info.landY)][int(info.landZ)];}catch(e:*){}
         if(target!=null && (String(info.roomKey)!=game.roomKey(target) || TravelGuard.restricted(target))){cancelFollow();return;}
         // Temporary unavailability is not success. Keep the latest intent
         // without reactivating a room every frame or waiting for a new door.
         followAttemptAfter=now+Math.min(2000,500*(1+followFailures));
         if(target==null || !TravelGuard.follow(game,info,!host())) {
            if(followFailures++<3)Log.d("RConnectRoom: follow deferred room="+info.roomKey+" attempt="+followFailures);
            return;
         }
         followStarted=true;check();
      }
      public function accepts(msg:Object):Boolean
      {return canSyncWorld && acceptsReceipt(msg);}
      /** A native activation can precede the next barrier/frame callback. Do
       * not label its snapshots/reports with the previous room's authority. */
      public function get canSyncWorld():Boolean
      {return ready && !busy && currentSettledRoom();}
      /** Explicit local travel shares the ordinary-room handoff with walking. */
      public function travelToTeammate(info:Object):Boolean
      {
         if((session.pause!=null && session.pause.paused) || !connected() || !ready || busy || pending!=0 || info==null || game.isTransitioning() || game.isPlayerDead())return false;
         var mine:Object=game.readWorldInfo(),target:Object;
         if(mine==null || String(info.curLandId)!=String(mine.curLandId) || int(info.roomEpoch)!=epoch
            || String(info.landProb || "")!="" || TravelGuard.restricted(game.loc))return false;
         try {target=game.world.land.locs[int(info.landX)][int(info.landY)][int(info.landZ)];}catch(e:*){}
         if(target==null || String(info.roomKey)!=game.roomKey(target) || TravelGuard.restricted(target))return false;
         cancelFollow();
         if(target!==game.loc)
         {
            if(!TravelGuard.follow(game,{landX:info.landX,landY:info.landY,landZ:info.landZ,landProb:""},!host()))return false;
            check();
         }
         return true;
      }
      public function acceptsReceipt(msg:Object):Boolean
      {
         // Final player hits are flushed before the next grant. They belong to
         // this authority term even when the native player has crossed a door;
         // only world-state packets also require currentSettledRoom().
         return ready && !authority && String(msg.roomKey)==settledKey
            && int(msg.roomEpoch)==epoch && int(msg.roomTerm)==term;
      }
      public function handle(msg:Object):Boolean
      {
         if(msg==null || msg.type!="room")return false;
         try
         {
            game.refreshWorld();
            // Socket callbacks can arrive before the next frame/adopt callback.
            // Retire the old barrier before inspecting any room message so a
            // delayed legacy grant cannot import state into a replacement Game.
            if(!nativeTravel.matchesWorld(game.world)) {
               cancelNativeEntry(true);return true;
            }
            if(host())
            {
               if(msg.op=="request") {peerInfo=msg.info;if(pending==0)begin();}
               else if(msg.op=="ready" && int(msg.barrier)==pending && int(msg.epoch)==epoch && nativeTravel.accepts(msg.travelId))commit(msg);
               else if(msg.op=="ack" && int(msg.barrier)==pending && nativeTravel.accepts(msg.travelId))
               {if(nativeTravel.current!=null)nativeTravel.finish(String(msg.travelId));nativeDeadline=0;game.activeTravelId="";pending=0;release();Log.d("RConnectRoom: resumed "+settledKey+" term="+term+" ms="+(getTimer()-barrierStarted));}
            }
            else if(msg.op=="prepare") {
               if(msg.planVersion!=null) {receiveNativePrepare(msg);return true;}
               if(nativeTravel.current!=null)return true;
               preparing=msg.info;game.mapGeneration.receive(preparing);startPreparedMap();
            }
            else if(msg.op=="seal")
            {
               if(!nativeTravel.accepts(msg.travelId))return true;
               if(nativeTravel.current!=null) {
                  nativeTravel.acceptAnchor(msg.entryAnchor);
                  if(nativeSeal!=null && (int(nativeSeal.barrier)!=int(msg.barrier) || int(nativeSeal.epoch)!=int(msg.epoch)))
                     throw new Error("Native seal overtook its pending destination");
                  if(nativeBarrier>0) {
                     if(nativeBarrier!=int(msg.barrier) || epoch!=int(msg.epoch))throw new Error("Native barrier changed");
                     return true; // This exact seal has already produced its ready.
                  }
                  nativeSeal=msg;applyWaitingNativeSeal();
               }else applySeal(msg);
            }
            else if(msg.op=="grant" && int(msg.barrier)==pending && int(msg.epoch)==epoch && acceptsJoinGrant(msg))
            {
               var completingNative:Boolean=nativeTravel.current!=null && String(msg.travelId)==nativeTravel.id;
               var state:Object;
               if(msg.fresh===true && msg.owner===true && freshRoom===game.loc && freshWire!=null
                  && msg.state===freshWire && String(msg.key)==game.roomKey()) {
                  // The host returned our exact held native state and granted
                  // us authority. No simulation ran since it was captured.
                  game.roomRole(true);
               }else if(msg.unchanged===true) {
                  if(!currentSettledRoom() || !ready || !authority || msg.owner!==true || String(msg.key)!=game.roomKey())
                     throw new Error("Invalid unchanged room grant");
               }else if(msg.retained===true) {
                  // Only reuse our own exact checkpoint while this same native
                  // room remained frozen. Unit/loot authority still changes.
                  if(!ready || !authority || heldRoom!==game.loc || !game.roomHold || heldState==null
                     || heldWire==null || msg.state!==heldWire || String(msg.key)!=game.roomKey())
                     throw new Error("Invalid retained room grant");
                  restoring=true;
                  // Retain the exact JSON-decoded numbers used by the new
                  // authority too; the original capture can differ by one ULP.
                  state=RoomCodec.unpack(String(msg.state));
                  game.restoreCheckpoint(state,Boolean(msg.owner),false,true);
                  restoring=false;
               }else {
                  state=RoomCodec.unpack(String(msg.state));
                  if(game.roomKey()!=String(state.key))throw new Error("Room changed during grant");
                  restoring=true;
                  game.restoreCheckpoint(state,Boolean(msg.owner),msg.fresh!==true && (!authority || settledRoom!==game.loc || !ready));
                  restoring=false;
               }
               if(completingNative) {
                  nativeTravel.acceptAnchor(msg.entryAnchor);
                  if(game.roomKey()!=String(nativeTravel.anchor.roomKey))throw new Error("Native entry room differs");
                  TravelPlacement.place(game.gg,Number(nativeTravel.anchor.x),Number(nativeTravel.anchor.y));
               }
               else if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)
                  && isFinite(Number(hostInfo.x)) && isFinite(Number(hostInfo.y)))
                  TravelPlacement.place(game.gg,Number(hostInfo.x),Number(hostInfo.y));
               authority=Boolean(msg.owner);ready=true;term=int(msg.term);settledRoom=game.loc;settledKey=game.roomKey();
               initial=false;game.independentRooms=true;nativeRoom=game.loc;
               TravelGuard.endTravel();
               send({op:"ack",barrier:pending,travelId:completingNative?nativeTravel.id:""});
               if(completingNative) {
                  nativeTravel.finish(String(msg.travelId));clearNativeEntry();nativeDeadline=0;game.activeTravelId="";
               }else if(nativePreviousBarrier==pending)nativePreviousBarrier=0;
               pending=0;readySent=false;release();
               Log.d("RConnectRoom: grant "+settledKey+" authority="+authority+" term="+term+" ms="+(getTimer()-barrierStarted));
            }
         }
         catch(error:Error){fail(error);}
         finally {present();}
         return true;
      }
      private function sendReady():void
      {
         if(game.isTransitioning() || game.loc==null)return;
         if(nativeTravel.current!=null && !(nativePreviousBarrier>0 && pending==nativePreviousBarrier)
            && (nativeBarrier<=0 || pending!=nativeBarrier || !nativeDestinationReady()))return;
         if(initial && hostInfo!=null && game.roomKey()!=String(hostInfo.roomKey)) {
            if(!TravelGuard.follow(game,hostInfo,true))return;
            nativeRoom=game.loc;
         }
         var keepOwner:Boolean=ready && authority && currentSettledRoom() && hostInfo!=null && String(hostInfo.roomKey)!=settledKey;
         hold(!keepOwner);flush();session.flushProgress();var own:Object=null;
         if(ready && authority && settledRoom!=null && !keepOwner)
            own=game.inRoom(settledRoom,function():Object{return game.checkpoint();});
         var info:Object=game.readWorldInfo();
         var ownPacked:String=own==null?null:RoomCodec.pack(own);
         // Owner state remains complete (including mines, loot and wall marks).
         // Reuse that capture when both fields refer to the same held room.
         var sameCapture:Boolean=own!=null && settledRoom===game.loc;
         heldRoom=sameCapture?game.loc:null;heldState=sameCapture?own:null;heldWire=sameCapture?ownPacked:null;
         var knownCurrent:Boolean=ready && settledRoom===game.loc && settledKey==game.roomKey();
         // For a shared destination the host already owns its complete native
         // state. A second freshly generated copy is never used by commit.
         var needFresh:Boolean=!knownCurrent && (hostInfo==null || game.roomKey()!=String(hostInfo.roomKey));
         var freshState:Object=needFresh?(sameCapture?own:game.checkpoint()):null;
         // Previously granted rooms are already in the host's records. Fresh
         // state is required only for a new independently occupied room.
         var freshPacked:String=needFresh?(sameCapture?ownPacked:RoomCodec.pack(freshState)):null;
         freshRoom=needFresh?game.loc:null;freshWire=freshPacked;
         send({op:"ready",barrier:pending,epoch:epoch,info:info,
            travelId:nativePreviousBarrier>0 && pending==nativePreviousBarrier?"":nativeTravel.id,
            oldKey:settledKey,oldTerm:term,own:ownPacked,fresh:freshPacked});
         readySent=true;
      }
      private function commit(msg:Object):void
      {
         peerInfo=msg.info;
         if(ready && authority)session.flushGhostDamage();
         var myKey:String=game.roomKey(),theirKey:String=String(msg.info.roomKey);
         if(ready && settledRoom!=null && authority && (settledRoom!==game.loc || theirKey==myKey))
            records[settledKey]={state:game.inRoom(settledRoom,function():Object{return game.checkpoint();}),owner:0};
         if(msg.own!=null)
         {
            var previous:Object=records[String(msg.oldKey)];
            if(previous==null || int(previous.owner)!=1 || int(previous.term)!=int(msg.oldTerm))
               throw new Error("Unexpected room owner checkpoint");
            records[String(msg.oldKey)]={state:RoomCodec.unpack(String(msg.own)),owner:1};
         }
         var mine:Object=records[myKey];
         var nativeFresh:Boolean=mine==null;
         if(mine==null)mine=records[myKey]={state:game.checkpoint(),owner:0};
         // This exact native room has just supplied the snapshot. Importing
         // it into itself would rebuild live loot and replay object state.
         if(nativeFresh)game.roomRole(true);
         else if(settledRoom!==game.loc || !ready || int(mine.owner)!=0)
            game.restoreCheckpoint(mine.state,true,int(mine.owner)!=0);
         else game.freezeAI=false;
         mine.owner=0;mine.term=pending;
         var theirs:Object=records[theirKey];
         var unchanged:Boolean=theirs!=null && int(theirs.owner)==1 && theirKey!=myKey
            && String(msg.oldKey)==theirKey && msg.own==null && msg.fresh==null;
         var fresh:Boolean=theirs==null;
         // The former owner is still in the same frozen room. Return its exact
         // validated bytes, not a newly serialized copy of an equivalent state.
         var retained:Boolean=msg.own!=null && String(msg.oldKey)==theirKey;
         var grantPacked:String=null;
         if(theirs==null)
         {
            if(msg.fresh==null)throw new Error("Missing new-room checkpoint: "+theirKey);
            grantPacked=String(msg.fresh);
            // Still decode before accepting the checkpoint into records. Only
            // owner/term change below; its state stays untouched, so the already
            // validated input is also the exact state sent in this fresh grant.
            theirs=records[theirKey]={state:RoomCodec.unpack(grantPacked),owner:1};
         }
         if(theirKey!=myKey)theirs.owner=1;
         theirs.term=pending;
         authority=true;ready=true;term=pending;settledRoom=game.loc;settledKey=myKey;
         game.independentRooms=true;
         if(retained)grantPacked=String(msg.own);
         if(grantPacked==null && !unchanged)grantPacked=RoomCodec.pack(theirs.state);
         send({op:"grant",barrier:pending,epoch:epoch,term:pending,owner:theirKey!=myKey,fresh:fresh,
            travelId:nativeTravel.id,entryAnchor:nativeTravel.anchor,
            unchanged:unchanged,retained:retained,key:theirKey,state:grantPacked});
         Log.d("RConnectRoom: commit "+pending+" host="+myKey+" join="+theirKey);
         // The host's ownership and native state are now committed. TCP keeps
         // this grant ahead of subsequent snapshots, so rendering the peer's
         // copy is not a prerequisite for local simulation. Keep `pending`
         // until ACK: another handoff still cannot overtake this transaction.
         release();
      }
      private function flush():void
      {
         if(!ready || authority || settledRoom==null)return;
         game.inRoom(settledRoom,function():void {session.flushRoomReports(true,true);});
      }
      /** Late reports are settled in the old native room before its snapshot.
       * They cannot be accepted again after the authority term changes. */
      public function report(msg:Object,link:TcpLink):Boolean
      {
         var type:String=String(msg.type);
         if([Protocol.MSG_DAMAGE,Protocol.MSG_LOOT,Protocol.MSG_OBJS,Protocol.MSG_TERRAIN].indexOf(type)<0)return false;
         if(!ready || !authority || String(msg.roomKey)!=settledKey || int(msg.roomEpoch)!=epoch || int(msg.roomTerm)!=term)return true;
         game.inRoom(settledRoom,function():void
         {
            if(type==Protocol.MSG_DAMAGE)for each(var h:Object in msg.hits)
               game.applyDamage(String(h.id),Number(h.dmg),game.getRemoteGhost(link.id),String(h.k),h);
            else if(type==Protocol.MSG_LOOT) {
               var lootReceipt:Object=game.applyLootReports(msg);
               if(lootReceipt!=null)link.send(stamp(Protocol.make(Protocol.MSG_LOOT_ACK,lootReceipt)));
            }
            else if(type==Protocol.MSG_OBJS)game.applyObjReports(msg);
            else if(type==Protocol.MSG_TERRAIN)
            {
               var receipt:Object=game.applyTileReport(String(link.id),msg);
               if(receipt!=null){receipt.worldInfo=game.readWorldInfo();link.send(stamp(Protocol.make(Protocol.MSG_TERRAIN_ACK,receipt)));}
            }
         });
         return true;
      }
      public function notice(s:String):void {status=s;if(mod.hud!=null)mod.hud.addChatLine("RConnect",RCLocale.text(s));}
      private function fail(error:Error):void
      {
         hold();blocked=true;status="房间同步失败，请断开连接后重试";
         Log.d("RConnectRoom: ERROR "+error+" "+error.getStackTrace());
      }
   }
}
