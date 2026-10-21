package rconnect.game {
   public class GameBridge {
      public static function probe(o:Object,k:String):* {try{return o==null?null:o[k];}catch(e:*){return null;}}
   }
}
