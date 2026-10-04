package fe.unit {
   import fe.Obj;
   /** Calls native internal actions, without reimplementing their filters. */
   public class TelekinesisProbe {
      public static function grabPlayer(u:Object):void {(u as UnitPlayer).actTele();}
      public static function grabEnemy(u:Object,target:Object):void {(u as UnitAlicorn).upTeleObj(target as Obj);}
   }
}
