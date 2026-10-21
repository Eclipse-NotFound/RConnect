package rconnect.game {
   /** Ground-fire/acid sampling is outside this explosion transport fixture. */
   public class BurnVisuals {
      public function present(...args):void {throw new Error("burn outside special impact fixture");}
      public function reset():void {}
      public static function captureGround(b:Object):Array {return [];}
      public static function playGround(main:Object,loc:Object,parts:Array,kind:String="fire"):void {
         throw new Error("ground effects outside special impact fixture");
      }
   }
}
