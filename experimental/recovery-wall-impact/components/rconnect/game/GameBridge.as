package rconnect.game {
   public class GameBridge {
      public static function probe(o:Object,k:String):* {return o==null?null:o[k];}
   }
}
