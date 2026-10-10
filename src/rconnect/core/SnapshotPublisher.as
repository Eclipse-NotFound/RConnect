package rconnect.core {
   import flash.utils.getTimer;
   import rconnect.net.HostServer;
   import rconnect.net.Protocol;

   /** Publishes the current presentation from the session's existing timer.
    * Socket receipt only updates remote state; it cannot trigger a second
    * source capture. RoomSync still owns report acceptance and handoffs. */
   public class SnapshotPublisher {
      private var session:Session,mod:RConnectMod;
      private var nextScene:int=0,seq:int=0;
      private var spawnLogged:Boolean=false,lootLogged:Boolean=false;
      public function SnapshotPublisher(session:Session) {this.session=session;mod=session.mod;}
      private function get server():HostServer {return session.server;}
      private function get rooms():RoomSync {return session.rooms;}
      public function reset():void {nextScene=0;}

      public function tick(tick:int):void {
         if(session.mode==Session.CONNECTED && session.link!=null && session.link.isOpen) {
            session.link.send(Protocol.make(Protocol.MSG_PLAYERSTATE,
               {id:session.myId,seq:seq++,name:session.myName,snap:mod.game==null?null:mod.game.readSnapshot()}));
            return;
         }
         if(session.mode!=Session.HOSTING || server==null || !server.bound || session.peers.length==0)return;
         roster(tick);
         if(getTimer()>=nextScene && mod.game!=null && rooms.ready && !rooms.busy && !mod.game.isTransitioning())
            {
               // AIR coalesces delayed timers under load. Counting four callbacks
               // stretched 200ms updates to 500ms; use elapsed time without catch-up bursts.
               nextScene=getTimer()+200;
               var usnap:Array = mod.game.readUnitsSnapshot();
               var usMsg:Object = Protocol.make(Protocol.MSG_UNITSYNC,
                  {tick: tick, units: usnap != null ? usnap : [],points:session.progress.capture(mod.game.loc),
                   worldInfo: mod.game.readWorldInfo()});
               // M16：物品（箱/门）状态快照随行广播（对象级重建/破坏同步）
               var olist:Array = mod.game.readObjsSnapshot();
               if(olist != null)
               {
                  usMsg.objs = olist;
               }
               // M17：瓦片破坏差分 + 新生成物品广播
               var tpatch:Array = mod.game.readTilePatch();
               if(tpatch != null)
               {
                  usMsg.tilePatch = tpatch;
               }
               usMsg.wallPaint=mod.game.readWallPaint();
               var nspawn:Array = mod.game.readNewObjs();
               if(nspawn != null)
               {
                  usMsg.objSpawn = nspawn;
                  if(!spawnLogged)
                  {
                     spawnLogged = true;
                     Log.d("RConnectNet: objSpawn tx " + nspawn.length
                        + " first=" + String(nspawn[0].id));
                  }
               }
               // M24：可移动物品（Loot）快照随行广播（稳定键+实时位置）。
               // 空数组也必须发——"缺席"就是移除信号，不发会让 joiner
               // 永远收不到清理指令而重复上报
               var llist:Array = mod.game.readLootSync();
               usMsg.loots = llist != null ? llist : [];
               if(llist != null && !lootLogged)
               {
                  lootLogged = true;
                  Log.d("RConnectNet: loots tx first " + llist.length
                     + " k=" + String(llist[0].k));
               }
               server.broadcast(rooms.stamp(usMsg));
            }
      }

      public function roster(tick:int):void
      {
         if(server == null || !server.bound || session.peers.length==0)
         {
            return;
         }
         var players:Array = [];
         var selfSnap:Object = mod.game != null ? mod.game.readSnapshot() : null;
         players.push({id: 0, name: session.myName, snap: selfSnap});
         for each(var p:Object in session.peers)
         {
            players.push({id: p.id, name: p.name, snap: p.snap});
         }
         var ws:Object = Protocol.make(Protocol.MSG_WORLDSTATE,
            {tick: tick, players: players});
         if(mod.game!=null && rooms.ready && !rooms.busy && rooms.authority && !mod.game.isTransitioning()) {
            var movingLoot:Array=mod.game.readLootSync(true);
            if(movingLoot!=null)ws.lootMotion=movingLoot;
         }
         server.broadcast(rooms.stamp(ws));
      }

   }
}
