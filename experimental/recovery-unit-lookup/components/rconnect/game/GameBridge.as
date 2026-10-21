package rconnect.game {
   /** Fixture boundary: ordinary object/getter read only, no native Unit, game,
    * collision or presentation. The full identity algorithm is not mocked. */
   public class GameBridge {
      public static var reads:Array=[];
      public static var record:Boolean=true;
      public static function probe(o:Object,k:String):* {
         try {
            if(record)reads.push([o==null?null:o.tag,k]);
            return o!=null && k in o?o[k]:null;
         } catch(e:*) {return null;}
      }
   }
}
