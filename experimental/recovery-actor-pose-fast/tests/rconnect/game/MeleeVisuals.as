package rconnect.game {
   import fixture.Trace;
   public final class MeleeVisuals {
      public static function observe(u:Object,w:Object,at:int):void {throw new Error("capture outside pose fixture");}
      public static function capture(u:Object,w:Object):Object {throw new Error("capture outside pose fixture");}
      public static function resetObserved():void {}
      public function apply(u:Object,w:Object,s:Object,at:Number):void {Trace.note("melee",String(w.id),s,isNaN(at)?"NaN":at,w.vis.visible,w.vis.alpha);}
      public function forget(w:Object):void {Trace.note("forget-melee",String(w.id));}
      public function reset():void {}
   }
}
