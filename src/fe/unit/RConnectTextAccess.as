package fe.unit {
   import fe.graph.Emitter;
   /** Only the native display emitter/aggregate; no damage calculation. */
   public class RConnectTextAccess {
      public static function emitter(u:Unit):Emitter {return u.numbEmit;}
      public static function replace(u:Unit,expected:Emitter,next:Emitter):Boolean {
         if(u.numbEmit!==expected)return false;
         u.numbEmit=next;return true;
      }
      public static function aggregate(u:Unit):Object {return u.hitPart;}
   }
}
