package rconnect.game {
   /** Component boundary: optional properties of plain objects/display nodes.
    * No native typed-object fast paths, rooms, physics or peers are emulated. */
   public class GameBridge {
      public static function probe(o:Object,name:String):* {
         if(o==null)return null;
         try {if(!(name in o))return null;var v:*=o[name];return v===undefined?null:v;}
         catch(e:*){return null;}
      }
   }
}
