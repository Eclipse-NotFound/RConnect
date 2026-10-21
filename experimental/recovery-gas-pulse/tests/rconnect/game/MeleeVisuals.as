package rconnect.game {
   public class MeleeVisuals {
      public static function observe(u:Object,w:Object,stamp:int):void {}
      public static function capture(u:Object,w:Object):Object {return null;}
      public static function resetObserved():void {}
      public function apply(...args):void {throw new Error("melee outside capture fixture");}
      public function forget(w:Object):void {}
      public function reset():void {}
   }
}
