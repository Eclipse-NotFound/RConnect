package rconnect.game {
   /** Adjacent access boundary only; NativeRoomState itself is exact recovery-09. */
   public class GameBridge {
      public static function probe(o:Object,key:String):* {return o==null?null:o[key];}
   }
}
