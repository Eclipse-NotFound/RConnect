package rconnect.game {
   /** Compile-only shell; interpolation does not instantiate WeaponDisplay. */
   public class MeleeVisuals {
      public function apply(u:Object,w:Object,s:Object,t:Number):Boolean {
         throw new Error("MeleeVisuals.apply outside weapon-container component scope");
      }
      public function forget(w:Object):void {
         throw new Error("MeleeVisuals.forget outside weapon-container component scope");
      }
   }
}
