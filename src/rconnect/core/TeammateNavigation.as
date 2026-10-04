package rconnect.core
{
   import flash.events.Event;
   import flash.utils.getTimer;
   import rconnect.game.GameBridge;

   /** Fresh teammate positions and one-shot travel. RoomSync remains the sole
    * owner of room handoff; this class only places the local player afterwards. */
   public class TeammateNavigation
   {
      private var mod:RConnectMod;
      private var seen:Object={};
      private var pending:Object;
      private var errors:int=0;
      public var players:Array=[];
      public function TeammateNavigation(m:RConnectMod)
      {
         mod=m;
         m.stage.addEventListener(Event.ENTER_FRAME,tick,false,95000,true);
      }
      public function get travelling():Boolean {return pending!=null;}
      private function tick(e:Event):void
      {
         try {refresh();advance();}
         catch(error:Error) {pending=null;if(errors++<3)Log.d("RConnectNavigation: failed "+error+" "+error.getStackTrace());}
      }
      public function refresh():void
      {
         var s:Session=mod.session,source:Array=[],now:int=getTimer(),next:Object={};
         if(s.mode==Session.HOSTING)source=s.peers;
         else if(s.mode==Session.CONNECTED && s.link!=null && s.link.isOpen)source=s.remotes;
         players=[];
         for each(var peer:Object in source)
         {
            if(peer==null || peer.snap==null || int(peer.id)==s.myId)continue;
            if(s.mode==Session.HOSTING && (peer.link==null || !peer.link.isOpen))continue;
            var key:String=String(peer.id),record:Object=seen[key];
            if(record==null)record={id:int(peer.id),snap:null,receivedAt:now};
            if(record.snap!==peer.snap) {record.snap=peer.snap;record.receivedAt=now;}
            record.name=String(peer.name || "Pony");next[key]=record;
            if(now-int(record.receivedAt)<=3000)players.push(record);
         }
         seen=next;
         if(source.length==0)pending=null;
      }
      public function sameMap(snap:Object):Boolean
      {
         var game:GameBridge=mod.game,info:Object=GameBridge.probe(snap,"worldInfo");
         if(snap==null || info==null || game.world==null || game.loc==null || game.gg==null)return false;
         var mine:Object=game.readWorldInfo();
         return mine!=null && String(snap.landId)==String(mine.curLandId)
            && String(info.curLandId)==String(mine.curLandId) && int(snap.roomEpoch)==game.roomEpoch
            && int(info.roomEpoch)==game.roomEpoch && String(info.curCoord)==String(mine.curCoord)
            && Number(info.landStage)==Number(mine.landStage);
      }
      public function teammate():Object {return players.length>0?players[0]:null;}
      private function targetRoom(snap:Object):Object
      {
         var result:Object,info:Object=GameBridge.probe(snap,"worldInfo");
         if(info!=null)try {result=mod.game.world.land.locs[int(info.landX)][int(info.landY)][int(info.landZ)];}catch(e:*){}
         return result;
      }
      public function unavailable():String
      {
         if(pending!=null)return "正在传送…";
         var game:GameBridge=mod.game,s:Session=mod.session,peer:Object=teammate();
         if(peer==null)return "队友尚未连接或位置已失效";
         if(s.pause!=null && s.pause.paused)return "请先结束联机暂停";
         if(game.gg==null || game.loc==null)return "请等待房间准备完成";
         if(game.isPlayerDead() || Number(peer.snap.hp)<=0 || int(peer.snap.sost)>=3)return "角色倒地或复活中，暂不能传送";
         if(!s.rooms.ready || s.rooms.busy || game.isTransitioning())return "请等待房间准备完成";
         if(!sameMap(peer.snap))return "传送仅支持同一地图";
         var info:Object=peer.snap.worldInfo,room:Object=targetRoom(peer.snap);
         if(String(info.landProb || "")!="" || TravelGuard.restricted(game.loc) || room==null || TravelGuard.restricted(room))
            return "剧情和挑战区域需要跟随宿主共同进入";
         if(String(peer.snap.roomKey)!=game.roomKey(room) || String(info.roomKey)!=game.roomKey(room)
            || !isFinite(Number(peer.snap.x)) || !isFinite(Number(peer.snap.y)))return "队友尚未连接或位置已失效";
         if(GameBridge.probe(GameBridge.probe(game.world,"sats"),"active")==true
            || GameBridge.probe(GameBridge.probe(game.world,"stand"),"active")==true
            || GameBridge.probe(GameBridge.probe(game.world,"gui"),"guiPause")==true)return "请先结束当前操作";
         return "";
      }
      public function request():Boolean
      {
         var accepted:Boolean=false;
         try {accepted=beginRequest();}
         catch(error:Error) {pending=null;mod.session.rooms.notice("暂时无法传送，请稍后再试");if(errors++<3)Log.d("RConnectNavigation: failed "+error+" "+error.getStackTrace());}
         return accepted;
      }
      private function beginRequest():Boolean
      {
         refresh();var reason:String=unavailable();
         if(reason!="") {mod.session.rooms.notice(reason);return false;}
         var peer:Object=teammate(),info:Object=peer.snap.worldInfo;
         pending={id:peer.id,key:String(peer.snap.roomKey),epoch:mod.game.roomEpoch,until:getTimer()+15000};
         if(GameBridge.probe(GameBridge.probe(mod.game.world,"pip"),"active")==true)mod.game.world.pip.onoff(-1);
         if(pending.key!=mod.game.roomKey())
         {
            if(!mod.session.rooms.travelToTeammate(info)) {pending=null;mod.session.rooms.notice("请等待房间准备完成");return false;}
            mod.session.rooms.notice("正在传送…");
         }
         advance();return true;
      }
      private function advance():void
      {
         if(pending==null)return;
         var game:GameBridge=mod.game,peer:Object;
         for each(var p:Object in players)if(p.id==pending.id)peer=p;
         if(peer==null || !sameMap(peer.snap) || game.roomEpoch!=pending.epoch
            || String(peer.snap.roomKey)!=pending.key || Number(peer.snap.hp)<=0 || int(peer.snap.sost)>=3
            || game.isPlayerDead() || getTimer()>pending.until)
         {pending=null;mod.session.rooms.notice("传送已取消：队友状态发生变化");return;}
         if((mod.session.pause!=null && mod.session.pause.paused) || mod.session.rooms.busy || !mod.session.rooms.ready || game.isTransitioning())return;
         if(game.roomKey()!=pending.key) {pending=null;mod.session.rooms.notice("传送已取消：队友状态发生变化");return;}
         var spot:Object=findLanding(game.gg,Number(peer.snap.x),Number(peer.snap.y));
         pending=null;
         if(spot==null) {mod.session.rooms.notice("队友附近没有可站立的落点");return;}
         var gg:Object=game.gg;
         gg.setPos(spot.x,spot.y);gg.dx=0;gg.dy=0;gg.isLaz=0;gg.setVisPos();
         mod.session.rooms.notice("已传送到队友身边");
         Log.d("RConnectNavigation: arrived room="+game.roomKey()+" x="+spot.x+" y="+spot.y);
      }
      /** Use native collision queries without moving the character during search.
       * Stay near the teammate and require support below, avoiding a blind fall. */
      public static function findLanding(gg:Object,x:Number,y:Number):Object
      {
         if(gg==null || gg.loc==null || !isFinite(x) || !isFinite(y))return null;
         var room:Object=gg.loc,half:Number=Number(gg.scX)/2,height:Number=Number(gg.scY);
         for each(var ox:Number in [64,-64,96,-96,32,-32,0,128,-128])
         for each(var oy:Number in [0,-1,1,-20,20,-40,40,-60,60,-80,80,100,120,140,160])
         {
            var px:Number=x+ox,py:Number=y+oy,dx:Number=px-Number(gg.X),dy:Number=py-Number(gg.Y);
            if(px-half<4 || px+half>Number(room.limX)-4 || py-height<4 || py>Number(room.limY)-4)continue;
            if(gg.collisionAll(dx,dy) || !gg.collisionAll(dx,dy+3))continue;
            var blocked:Boolean=false;
            for each(var box:Object in room.objs)
               if(GameBridge.probe(box,"phis")!=null && Number(box.phis)>0 && GameBridge.probe(box,"dead")!=true
                  && GameBridge.probe(box,"invis")!=true && px+half>Number(box.X1) && px-half<Number(box.X2)
                  && py>Number(box.Y1) && py-height<Number(box.Y2)) {blocked=true;break;}
            if(!blocked)return {x:px,y:py};
         }
         return null;
      }
   }
}
