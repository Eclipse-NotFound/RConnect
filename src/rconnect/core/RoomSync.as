package rconnect.core
{
   import flash.events.Event;
   import flash.utils.getTimer;
   import rconnect.game.GameBridge;
   import rconnect.net.Protocol;
   import rconnect.net.RoomCodec;
   import rconnect.net.TcpLink;

   /** Two-player room ownership. Door crossings use an ordered barrier:
    * freeze -> flush mirror reports -> capture owners -> grant -> acknowledge.
    * The native simulation never advances a new room before its grant. */
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
      private var blocked:Boolean=false;
      private var requested:Boolean=false;
      public var busy:Boolean=false;
      public var ready:Boolean=false;
      public var authority:Boolean=true;
      public var term:int=0;
      public var epoch:int=0;
      public var status:String="";

      public function RoomSync(s:Session)
      {
         session=s;mod=s.mod;game=mod.game;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-9000);
      }
      public function reset():void
      {
         release();records={};nativeRoom=null;nativeLand=null;settledRoom=null;settledKey="";
         ready=false;authority=true;initial=true;epoch=0;term=0;pending=0;hostInfo=null;
         game.independentRooms=false;game.roomEpoch=0;status="";blocked=false;
         requested=false;
         TravelGuard.reset();
      }
      private function connected():Boolean
      {return session.mode==Session.CONNECTED || (session.mode==Session.HOSTING && session.peers.length>0);}
      private function host():Boolean {return session.mode==Session.HOSTING;}
      private function send(o:Object):void
      {
         o.type="room";
         if(host())session.server.broadcast(o);else if(session.link!=null)session.link.send(o);
      }
      private function hold():void
      {
         if(!busy)
         {
            pauseWorld=game.world;savedPause=Boolean(GameBridge.probe(pauseWorld,"onPause"));
            busy=true;deadline=getTimer()+45000;
         }
         game.roomHold=true;
         if(pauseWorld!=null)pauseWorld.onPause=true;
         status="房间交接中…";
      }
      private function release():void
      {
         if(busy && pauseWorld!=null)pauseWorld.onPause=savedPause;
         busy=false;game.roomHold=false;pauseWorld=null;
         status=ready?(authority?"分房探索":"共同探索"):"";
      }
      private function before(e:Event):void
      {
         if(!connected()) {if(ready || busy)reset();return;}
         try
         {
            game.refreshWorld();
            if(game.world==null || game.loc==null || game.gg==null)return;
            if(busy && pauseWorld===game.world)game.world.onPause=true;
            if(!host())TravelGuard.guardTravel(game,this);
            game.world.land.loc_t=0;
            check();
            TravelGuard.update(game,!host());
            if(busy && getTimer()>deadline && !blocked)
            {
               blocked=true;status="房间交接未完成，请断开后重连";
               Log.d("RConnectRoom: handoff timed out; simulation remains paused");
            }
         }
         catch(error:Error){fail(error);}
      }
      private function after(e:Event):void
      {
         if(!connected())return;
         try {game.refreshWorld();check();if(game.world!=null && game.world.land!=null)game.world.land.loc_t=0;}
         catch(error:Error){fail(error);}
      }
      private function check():void
      {
         if(game.loc==null || game.gg==null || game.isTransitioning())return;
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
         hold();pending=++serial;blocked=false;
         send({op:"seal",barrier:pending,epoch:epoch,info:game.readWorldInfo(),
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom)});
         Log.d("RConnectRoom: seal "+pending+" room="+game.roomKey());
      }
      /** Called for every host world update, including while maps load. */
      public function observeHost(info:Object):void
      {
         if(info==null || host())return;
         hostInfo=info;
         if(game.isPlayerDead() || game.isTransitioning())return;
         game.refreshWorld();var mine:Object=game.readWorldInfo();if(mine==null)return;
         var mapChange:Boolean=String(mine.curLandId)!=String(info.curLandId);
         if(mapChange || initial)
         {
            TravelGuard.allowTravel();
            game.independentRooms=false;
            game.followHostWorld(info);
            game.refreshWorld();
         }
         if(!mapChange && int(info.roomEpoch)>0 && epoch!=int(info.roomEpoch))
         {
            if(epoch>0 && !initial && nativeLand===game.world.land){TravelGuard.allowTravel();game.followMapGeneration(info);}
            epoch=int(info.roomEpoch);game.roomEpoch=epoch;
            settledRoom=null;settledKey="";ready=false;nativeRoom=null;
         }
      }
      public function stamp(msg:Object):Object
      {
         msg.roomKey=settledKey;msg.roomEpoch=epoch;msg.roomTerm=term;return msg;
      }
      public function accepts(msg:Object):Boolean
      {return !busy && acceptsReceipt(msg);}
      public function acceptsReceipt(msg:Object):Boolean
      {return ready && !authority && String(msg.roomKey)==settledKey && int(msg.roomEpoch)==epoch && int(msg.roomTerm)==term;}
      public function handle(msg:Object):Boolean
      {
         if(msg==null || msg.type!="room")return false;
         try
         {
            if(host())
            {
               if(msg.op=="request") {peerInfo=msg.info;if(pending==0)begin();}
               else if(msg.op=="ready" && int(msg.barrier)==pending && int(msg.epoch)==epoch)commit(msg);
               else if(msg.op=="ack" && int(msg.barrier)==pending)
               {pending=0;release();Log.d("RConnectRoom: resumed "+settledKey+" term="+term);}
            }
            else if(msg.op=="seal")
            {
               if(epoch!=int(msg.epoch)){settledRoom=null;settledKey="";ready=false;}
               observeHost(msg.info);pending=int(msg.barrier);epoch=int(msg.epoch);game.roomEpoch=epoch;
               readySent=false;blocked=false;
               if(msg.together && game.loc!=null && game.roomKey()!=String(msg.info.roomKey) && !game.isTransitioning())
                  TravelGuard.follow(game,msg.info,true);
               if(game.loc!=null && game.gg!=null && !game.isTransitioning()) {hold();sendReady();}
            }
            else if(msg.op=="grant" && int(msg.barrier)==pending && int(msg.epoch)==epoch)
            {
               var state:Object=RoomCodec.unpack(String(msg.state));
               if(game.roomKey()!=String(state.key))throw new Error("Room changed during grant");
               game.restoreCheckpoint(state,Boolean(msg.owner),msg.fresh!==true && (!authority || settledRoom!==game.loc || !ready));
               authority=Boolean(msg.owner);ready=true;term=int(msg.term);settledRoom=game.loc;settledKey=game.roomKey();
               initial=false;game.independentRooms=true;nativeRoom=game.loc;
               TravelGuard.endTravel();
               send({op:"ack",barrier:pending});pending=0;readySent=false;release();
               Log.d("RConnectRoom: grant "+settledKey+" authority="+authority+" term="+term);
            }
         }
         catch(error:Error){fail(error);}
         return true;
      }
      private function sendReady():void
      {
         if(game.isTransitioning() || game.loc==null)return;
         hold();flush();var own:Object=null;
         if(ready && authority && settledRoom!=null)
            own=game.inRoom(settledRoom,function():Object{return game.checkpoint();});
         send({op:"ready",barrier:pending,epoch:epoch,info:game.readWorldInfo(),
            oldKey:settledKey,oldTerm:term,own:own==null?null:RoomCodec.pack(own),
            fresh:RoomCodec.pack(game.checkpoint())});
         readySent=true;
      }
      private function commit(msg:Object):void
      {
         peerInfo=msg.info;
         if(ready && authority)session.flushGhostDamage();
         if(ready && settledRoom!=null && authority)
            records[settledKey]={state:game.inRoom(settledRoom,function():Object{return game.checkpoint();}),owner:0};
         if(msg.own!=null)
         {
            var previous:Object=records[String(msg.oldKey)];
            if(previous==null || int(previous.owner)!=1 || int(previous.term)!=int(msg.oldTerm))
               throw new Error("Unexpected room owner checkpoint");
            records[String(msg.oldKey)]={state:RoomCodec.unpack(String(msg.own)),owner:1};
         }
         var myKey:String=game.roomKey(),theirKey:String=String(peerInfo.roomKey);
         var mine:Object=records[myKey];
         if(mine==null)mine=records[myKey]={state:game.checkpoint(),owner:0};
         if(settledRoom!==game.loc || !ready || int(mine.owner)!=0)
            game.restoreCheckpoint(mine.state,true,int(mine.owner)!=0);
         else game.freezeAI=false;
         mine.owner=0;mine.term=pending;
         var theirs:Object=records[theirKey];
         var fresh:Boolean=theirs==null;
         if(theirs==null)theirs=records[theirKey]={state:RoomCodec.unpack(String(msg.fresh)),owner:1};
         if(theirKey!=myKey)theirs.owner=1;
         theirs.term=pending;
         authority=true;ready=true;term=pending;settledRoom=game.loc;settledKey=myKey;
         game.independentRooms=true;
         send({op:"grant",barrier:pending,epoch:epoch,term:pending,owner:theirKey!=myKey,fresh:fresh,state:RoomCodec.pack(theirs.state)});
         Log.d("RConnectRoom: commit "+pending+" host="+myKey+" join="+theirKey);
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
            else if(type==Protocol.MSG_LOOT)game.applyLootReports(msg);
            else if(type==Protocol.MSG_OBJS)game.applyObjReports(msg);
            else if(type==Protocol.MSG_TERRAIN)
            {
               var receipt:Object=game.applyTileReport(String(link.id),msg);
               if(receipt!=null){receipt.worldInfo=game.readWorldInfo();link.send(stamp(Protocol.make(Protocol.MSG_TERRAIN_ACK,receipt)));}
            }
         });
         return true;
      }
      public function notice(s:String):void {status=s;if(mod.hud!=null)mod.hud.addChatLine("RConnect",s);}
      private function fail(error:Error):void
      {
         hold();blocked=true;status="房间同步失败，请断开连接后重试";
         Log.d("RConnectRoom: ERROR "+error+" "+error.getStackTrace());
      }
   }
}
