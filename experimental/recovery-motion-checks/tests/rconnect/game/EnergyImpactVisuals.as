package rconnect.game {
   /** Explicit adjacent-collector boundary; not a real Part or hit detector. */
   public class EnergyImpactVisuals {
      public function observeWeapon(w:Object,stamp:int):void {}
      public function capture(w:Object):Array {return w.fixtureImpacts as Array;}
      public function hasPending(w:Object):Boolean {
         // Fixture-owned confirmed events keep a switched weapon discoverable.
         // Native Part sampling and expiry remain outside this component.
         var events:Array=w==null?null:w.fixtureImpacts as Array;
         return events!=null && events.length>0;
      }
      public function captureDelta(w:Object):Array {
         var result:Array=w.fixtureImpacts as Array;
         if(w.fixtureImpactsSent===result)return [];
         w.fixtureImpactsSent=result;return result;
      }
      public function receive(...args):void {}
      public function tick(...args):void {}
      public function setPaused(value:Boolean):void {}
      public function reset():void {}
   }
}
