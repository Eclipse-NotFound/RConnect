package rconnect.game {
   /** Only MirrorMasks' optional public property read; no game, native Unit or renderer. */
   public final class GameBridge {
      public static function probe(o:Object,name:String):* {
         try {
            if(o==null || !(name in o))return null;
            var value:*=o[name];return value===undefined?null:value;
         } catch(error:*) {return null;}
      }
   }
}
