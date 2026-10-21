package rconnect.game {
   public final class EnergyImpactVisuals {
      public function hasPending(w:Object):Boolean {return false;}
      public function beginGasFrame(loc:Object):void {throw new Error("capture outside pose fixture");}
      public function observeGasPart(p:Object,at:int):void {throw new Error("capture outside pose fixture");}
      public function finishGasFrame(at:int):void {throw new Error("capture outside pose fixture");}
      public function observeWeapon(w:Object,at:int):void {throw new Error("capture outside pose fixture");}
      public function capture(w:Object):Array {throw new Error("capture outside pose fixture");}
      public function captureGas(loc:Object):Array {throw new Error("capture outside pose fixture");}
      public function captureDelta(w:Object):Array {throw new Error("capture outside pose fixture");}
      public function reset():void {}
   }
}
