package rconnect.core {
   /** Never reached by interpolation or the real TeleportVisuals.split. */
   public class Log {
      public static function d(message:String):void {
         throw new Error("Log.d outside weapon-container component scope: "+message);
      }
   }
}
