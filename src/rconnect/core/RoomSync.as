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
      private var barrierRoom:Object,barrierLand:Object;
      private var savedPause:Boolean=false;
      private var pauseWorld:Object;
      private var deadline:int=0;
      private var readySent:Boolean=false;
      private var initial:Boolean=true;
      private var preparing:Object;
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
      private var followBlockedAt:int=-1;
      public var busy:Boolean=false;
      public var ready:Boolean=false;
      public var authority:Boolean=true;
      public var term:int=0;
      public var epoch:int=0;
      public var status:String="";

      public function RoomSync(s:Session)
      {
         session=s;mod=s.mod;game=mod.game;
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
         preparing=null;preparedToken="";restoring=false;localEntry=false;barrierRoom=null;barrierLand=null;
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
         if(entryPending)entryView.show(game.world,mod.stage,blocked?status:"");
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
         if(!connected()) {if(ready || busy)reset();else entryView.clear();return;}
         try
         {
            game.refreshWorld();
            if(game.world==null || game.loc==null || game.gg==null)return;
            if(busy && pauseWorld===game.world)game.world.onPause=true;
            if(!host())TravelGuard.guardTravel(game,this);
            advanceSharedTravelFade();
            if(host())prepareCachedMap();
            else if(preparing!=null && !game.isTransitioning())startPreparedMap();
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
         if(game.loc==null || game.gg==null || game.isTransitioning())return;
         if(!host() && preparing!=null)return;
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
         barrierRoom=game.loc;barrierLand=game.world.land;
         send({op:"seal",barrier:pending,epoch:epoch,info:game.readWorldInfo(),
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),
            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)});
         Log.d("RConnectRoom: seal "+pending+" room="+game.roomKey());
      }
      /** Called for every host world update, including while maps load. */
      public function receivedWelcome(info:Object):void
      {
         // A socket callback can arrive after this frame's Stage listener.
         // Adopt the completed seed now and close the view in the same event.
         try {observeHost(info);}
         catch(error:Error){fail(error);}
         finally {present();mod.stage.invalidate();}
      }
      public function observeHost(info:Object):void
      {
         if(info==null || host() || info.worldReady===false)return;
         game.mapGeneration.receive(info);
         hostInfo=info;
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
            || game.isTransitioning() || game.isPlayerDead())return;
         var info:Object=preparing;
         if(String(game.world.game.curLandId)==String(info.curLandId)
            && !game.mapGeneration.differs(info,game.world.land))return;
         TravelGuard.allowTravel(String(info.curLandId));
         if(game.startSharedTravel(info)) {
            initial=true;ready=false;settledRoom=null;settledKey="";nativeRoom=null;
            game.independentRooms=false;
         }
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
         followPending=null;followSeenAt=0;followAttemptAfter=0;followFailures=0;followStarted=false;followBlockedAt=-1;
      }
      private function followTeammate():void {
         if(followPending==null)return;
         var now:int=getTimer();
         if(mod.config.getValue("followTeammate")!="1"){cancelFollow();return;}
         if((session.pause!=null && session.pause.paused) || !ready || busy || pending!=0
            || game.isTransitioning() || game.isPlayerDead()) {
            if(followBlockedAt<0)followBlockedAt=now;
            return;
         }
         if(followBlockedAt>=0) {
            // New teammate packets may refresh followSeenAt while blocked.
            // Exclude only the interval since that packet, without granting
            // future time twice. Retry backoff also pauses while unplayable.
            followSeenAt+=now-Math.max(followBlockedAt,followSeenAt);
            if(followAttemptAfter>0)followAttemptAfter+=now-followBlockedAt;
            followBlockedAt=-1;
         }
         if(now-followSeenAt>3000){cancelFollow();return;}
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
            if(host())
            {
               if(msg.op=="request") {peerInfo=msg.info;requested=true;if(pending==0)begin();}
               else if(msg.op=="ready" && int(msg.barrier)==pending && int(msg.epoch)==epoch) {
                  // A request already described by this READY adds no new
                  // work. Preserve a local crossing and a newer destination.
                  if(requested && game.loc===barrierRoom && sameRequest(peerInfo,msg.info))requested=false;
                  commit(msg);
               }
               else if(msg.op=="ack" && int(msg.barrier)==pending)
               {pending=0;release();check();Log.d("RConnectRoom: resumed "+settledKey+" term="+term+" ms="+(getTimer()-barrierStarted));}
            }
            else if(msg.op=="prepare") {
               preparing=msg.info;game.mapGeneration.receive(preparing);startPreparedMap();
            }
            else if(msg.op=="seal")
            {
               if(epoch!=int(msg.epoch)){settledRoom=null;settledKey="";ready=false;}
               observeHost(msg.info);pending=int(msg.barrier);epoch=int(msg.epoch);game.roomEpoch=epoch;
               readySent=false;blocked=false;
               if(msg.together && game.loc!=null && game.roomKey()!=String(msg.info.roomKey) && !game.isTransitioning())
                  TravelGuard.follow(game,msg.info,true);
               if(game.loc!=null && game.gg!=null && !game.isTransitioning())sendReady();
            }
            else if(msg.op=="grant" && int(msg.barrier)==pending && int(msg.epoch)==epoch)
            {
               var state:Object;
               var crossedUnchanged:Boolean=false,crossingRequested:Boolean=false;
               if(msg.fresh===true && msg.owner===true && freshRoom===game.loc && freshWire!=null
                  && msg.state===freshWire && String(msg.key)==game.roomKey()) {
                  // The host returned our exact held native state and granted
                  // us authority. No simulation ran since it was captured.
                  game.roomRole(true);
               }else if(msg.unchanged===true) {
                  if(!ready || !authority || settledRoom==null || msg.owner!==true
                     || String(msg.key)!=settledKey || game.roomKey(settledRoom)!=settledKey
                     || game.world==null || game.world.land!==nativeLand || settledRoom.land!==nativeLand)
                     throw new Error("Invalid unchanged room grant");
                  crossedUnchanged=game.loc!==settledRoom;
                  // An already observed crossing sent its request before this
                  // ACK on the same TCP stream. Do not enqueue it twice.
                  crossingRequested=crossedUnchanged && nativeRoom===game.loc;
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
               if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)
                  && isFinite(Number(hostInfo.x)) && isFinite(Number(hostInfo.y)))
                  TravelPlacement.place(game.gg,Number(hostInfo.x),Number(hostInfo.y));
               authority=Boolean(msg.owner);ready=true;term=int(msg.term);
               if(!crossedUnchanged){settledRoom=game.loc;settledKey=game.roomKey();nativeRoom=game.loc;}
               initial=false;game.independentRooms=true;
               TravelGuard.endTravel();
               send({op:"ack",barrier:pending});pending=0;readySent=false;release();
               if(crossedUnchanged) {
                  hold();
                  if(!crossingRequested)check();
               }
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
         if(initial && hostInfo!=null && game.roomKey()!=String(hostInfo.roomKey)) {
            if(!TravelGuard.follow(game,hostInfo,true))return;
            nativeRoom=game.loc;
         }
         var keepOwner:Boolean=ready && authority && currentSettledRoom() && hostInfo!=null && String(hostInfo.roomKey)!=settledKey;
         hold(!keepOwner);flush();session.flushProgress();var own:Object=null;
         if(ready && authority && settledRoom!=null && !keepOwner)
            own=game.inRoom(settledRoom,function():Object{return game.checkpoint();});
         // READY already describes this native destination. Do not let the
         // next frame rediscover it and enqueue a duplicate ownership barrier.
         // Keep restricted departures unobserved so check() still returns them.
         if(!(ready && TravelGuard.restricted(game.loc) && game.roomKey()!=String(hostInfo.roomKey))) {
            nativeLand=game.world.land;nativeRoom=game.loc;
         }
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
            oldKey:settledKey,oldTerm:term,own:ownPacked,fresh:freshPacked});
         readySent=true;
      }
      private function sameRequest(a:Object,b:Object):Boolean {
         return a!=null && b!=null && String(a.roomKey)==String(b.roomKey)
            && String(a.curLandId)==String(b.curLandId) && String(a.curCoord)==String(b.curCoord)
            && Number(a.landStage)==Number(b.landStage);
      }
      private function commit(msg:Object):void
      {
         // A ready message answers the room announced by its seal. A native
         // door crossing during an unchanged-owner wait cannot change that room.
         if(barrierRoom==null || game.world==null || game.world.land!==barrierLand
            || nativeLand!==barrierLand || barrierRoom.land!==barrierLand)
            throw new Error("Room barrier changed native Land");
         if(game.loc!==barrierRoom) {
            // Only an already settled host was allowed to continue playing.
            // Never rebuild a formerly frozen destination around a remote gg.
            var oldRecord:Object=records[settledKey];
            if(!ready || !authority || settledRoom!==barrierRoom || oldRecord==null
               || int(oldRecord.owner)!=0 || oldRecord.state==null
               || String(oldRecord.state.key)!=game.roomKey(barrierRoom))
               throw new Error("Unsettled room changed during barrier");
            game.inRoom(barrierRoom,function():void {commitHeld(msg,true);});
            // inRoom restores native context before the new room is frozen.
            // check records a just-observed crossing; queued ones remain queued.
            hold();check();return;
         }
         commitHeld(msg);
      }
      private function commitHeld(msg:Object,scoped:Boolean=false):void
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
         if(scoped && (nativeFresh || settledRoom!==game.loc || !ready || int(mine.owner)!=0))
            throw new Error("Scoped commit cannot restore native room state");
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
