package rconnect.game {
   /** Compile-only shell. Any accidental non-component call must fail. */
   public class GameBridge {
      public static function probe(o:Object,k:String):* {
         throw new Error("GameBridge.probe outside weapon-container component scope");
      }
   }
}
