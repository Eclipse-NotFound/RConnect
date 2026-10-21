package rconnect.game {
   import fixture.Trace;
   public final class TelekinesisVisuals {
      public static function captureWeapon(w:Object):Object {throw new Error("capture outside pose fixture");}
      public function weapon(w:Object,s:Object):void {Trace.note("aura",String(w.id),s);}
      public function forgetWeapon(w:Object):void {Trace.note("forget-aura",String(w.id));}
      public function reset():void {}
   }
}
