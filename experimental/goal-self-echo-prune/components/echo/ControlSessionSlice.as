package echo {
   import rconnect.net.HostServer;
   import rconnect.net.TcpLink;
   import rconnect.net.Protocol;
   // Record-only dependencies: this is a method component, not a game session.
   public class ControlSessionSlice {
      public var server:HostServer;
      public var mod:Object;
      public var rooms:Object;
      public var peers:Array=[];
      public var remotes:Array=[];
      public var myName:String="host";
      public var myId:int=1;
      private var _tickCount:int=37;
      public function broadcastWorldState():void
      {
         if(server == null || !server.bound)
         {
            return;
         }
         var players:Array = [];
         var selfSnap:Object = mod.game != null ? mod.game.readSnapshot() : null;
         players.push({id: 0, name: myName, snap: selfSnap});
         for each(var p:Object in peers)
         {
            players.push({id: p.id, name: p.name, snap: p.snap});
         }
         var ws:Object = Protocol.make(Protocol.MSG_WORLDSTATE,
            {tick: _tickCount, players: players});
         if(mod.game!=null && rooms.canSyncWorld && rooms.authority && !mod.game.isTransitioning()) {
            ws.enemyMotion=mod.game.readEnemyMotion();
            var movingLoot:Array=mod.game.readLootSync(true);
            if(movingLoot!=null)ws.lootMotion=movingLoot;
            var wallPaint:Array=mod.game.readWallPaintUpdates();
            if(wallPaint!=null)ws.wallPaint=wallPaint;
         }
         server.broadcast(rooms.stamp(ws));
         // Keep the 200ms cumulative unitsync repair: a predicted pixel can
         // intentionally reject this fast update until its own ACK arrives.
         // Do not consume revisions just by reading them, or with no peer.
         if(wallPaint!=null && server!=null && server.clients.length>0)
            mod.game.wallPaintUpdatesSent(wallPaint);
      }

      public function applyWorldState(players:Array):void
      {
         if(players == null || mod.game == null)
         {
            return;
         }
         var seen:Object = {};
         var next:Array = [];
         for each(var p:Object in players)
         {
            var id:int = int(p.id);
            seen[id] = true;
            if(id == myId)
            {
               continue;
            }
            rooms.observeTeammate(p.snap==null?null:p.snap.worldInfo);
            mod.game.updateRemote(id, p.snap != null ? p.snap : {},
               p.name != undefined ? String(p.name) : "");
            next.push({id: id, name: p.name, snap: p.snap});
         }
         // 清理已消失的远程玩家
         for each(var r:Object in remotes)
         {
            if(!seen[int(r.id)])
            {
               mod.game.removeRemote(int(r.id));
            }
         }
         remotes = next;
      }


   }
}
