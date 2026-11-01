package authority {
   /** Native death/resurrection animation, retained rooms and independent birth IDs. */
   public final class PlayerLives {
      private var session:HostSession,previous:Function;
      public function PlayerLives(session:HostSession) {
         this.session=session;
         var type:Class=session.access.definition("fe.unit.UnitPlayer");previous=type["rconnectDeath"];
         if(previous!=null)throw new Error("Native death seam already occupied");type["rconnectDeath"]=died;
         for each(var a:PlayerActor in session.actors)a.spawn={room:a.unit.loc,x:a.unit.X,y:a.unit.Y};
      }
      private function died(unit:Object,type:int):Boolean {
         for each(var a:PlayerActor in session.actors)if(a.unit===unit) {
            if(unit.pers.hardcore && type>=0)return false;
            a.deathTicks=300;unit.dropTeleObj();a.context.sats.clearAll();
            session.inputs[a.id].clear();
            Log.write("player-died",{player:a.id,epoch:a.epoch,room:session.access.keyFor(unit.loc)});
            return true;
         }
         throw new Error("Unregistered player death");
      }
      public function step():void {
         for each(var a:PlayerActor in session.actors)if(a.deathTicks>0) {
            --a.deathTicks;
            if(a.deathTicks==150) {
               var cp:Object=a.unit.pers.currentCP,spawn:Object=a.spawn;
               if(cp!=null && cp.loc.land===a.unit.loc.land)spawn={room:cp.loc,x:cp.X,y:cp.Y};
               // Never use Land.gotoCheckPoint/reactivate: they reset enemies.
               session.runtime.transfers.relocate(a,spawn.room,spawn.x,spawn.y);
            }
            if(a.deathTicks==100) {
               session.access.scope.run(a.context,function():void {a.unit.resurect();});
               ++a.epoch;session.inputs[a.id].epoch=a.epoch;session.inputs[a.id].clear();
               Log.write("player-resurrected",{player:a.id,epoch:a.epoch,room:session.access.keyFor(a.unit.loc)});
            }
            if(a.deathTicks==1)session.access.scope.run(a.context,function():void {a.unit.controlOn();});
         }
      }
      public function dispose():void {session.access.definition("fe.unit.UnitPlayer")["rconnectDeath"]=previous;}
   }
}
