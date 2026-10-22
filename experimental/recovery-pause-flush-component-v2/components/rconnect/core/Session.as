package rconnect.core {
   import rconnect.net.TcpLink;
   import rconnect.net.Protocol;
   import pausecheck.*;
   public class Session {
      public static const HOSTING:String="hosting",CONNECTED:String="connected",OFFLINE:String="offline";
      public var mod:Object,mode:String=HOSTING,server:FakeServer,link:TcpLink;
      public var rooms:FakeRooms=new FakeRooms(),pause:Object;
      public var peers:Array=[],myName:String="Host",myId:int=0;
      private var _tickCount:int=17;
      /** One stopped-pose flush; normal timer cadence remains unchanged. */
      public function flushPausedWorldState():void
      {
         if(mode!=HOSTING || pause==null || !pause.paused
            || mod.game==null || !mod.game.coopPaused || !rooms.canSyncWorld
            || !rooms.authority || mod.game.isTransitioning()
            || server==null || !server.bound || server.clients.length==0)return;
         try {broadcastWorldState();}
         catch(error:*) {Log.d("RConnectNet: pause flush failed "+error);}
      }


      private function broadcastWorldState():void
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

   }
}
