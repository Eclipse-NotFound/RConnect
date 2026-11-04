package authority {
   import flash.utils.Dictionary;
   /** Consent applies only to a native throw observed from a teammate's hands. */
   public final class PeerFlights {
      private var flights:Dictionary=new Dictionary(true),patches:Dictionary=new Dictionary(true);
      public var armed:uint=0,protectedSteps:uint=0,damagingSteps:uint=0;
      public function arm(actor:PlayerActor):void {
         var g:Object=actor.unit;
         if(g.t_throw!=45 || g.levit!=0 || g.hp<=0)return;
         flights[g]={room:g.loc,epoch:actor.epoch,roomEpoch:actor.roomEpoch,counter:45};++armed;
      }
      private function valid(actor:PlayerActor,flight:Object):Boolean {
         var g:Object=actor.unit;
         return flight!=null && flight.room===g.loc && flight.epoch==actor.epoch && flight.roomEpoch==actor.roomEpoch &&
            g.hp>0 && g.sost==1 && !g.disabled && g.levit==0 && g.t_throw>0 && g.t_throw==flight.counter;
      }
      public function before(actor:PlayerActor):void {
         restore(actor.unit);
         var g:Object=actor.unit,flight:Object=flights[g];
         if(!valid(actor,flight)){delete flights[g];return;}
         var old:Number=g.damWall;
         if(!isFinite(old)){delete flights[g];return;}
         // Native damageWall clears the throw timer before testing >0. A
         // negative coefficient keeps collision cleanup without HP/stun/text.
         var value:Number=actor.personal.thrownDamage?(old>0?old:25):-1;
         patches[g]={old:old,value:value};g.damWall=value;
         if(value>0)++damagingSteps;else ++protectedSteps;
      }
      public function after(actor:PlayerActor):void {
         var g:Object=actor.unit,flight:Object=flights[g],patch:Object=patches[g];
         var replaced:Boolean=patch!=null && g.damWall!=patch.value;
         restore(g);
         if(flight==null)return;
         if(replaced || g.t_throw<=0 || g.levit!=0 || (g.t_throw!=flight.counter && g.t_throw!=flight.counter-1)) {
            delete flights[g];return;
         }
         flight.counter=g.t_throw;if(!valid(actor,flight))delete flights[g];
      }
      private function restore(g:Object):void {
         var patch:Object=patches[g];delete patches[g];
         if(patch!=null && g.damWall==patch.value)g.damWall=patch.old;
      }
   }
}
