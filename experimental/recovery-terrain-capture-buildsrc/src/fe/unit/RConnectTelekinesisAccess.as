package fe.unit {
   import fe.Obj;

   /** A remote player taking a box must release the native enemy's pointer,
    *  just as native Q takes it away from that enemy. No other hold changes. */
   public class RConnectTelekinesisAccess {
      public static function enemyHolding(units:Array,object:Obj):Boolean {
         if(units==null || object==null)return false;
         for each(var u:Unit in units) {
            if(u is UnitAlicorn && (u as UnitAlicorn).teleObj===object)return true;
            if(u is UnitBossAlicorn && (u as UnitBossAlicorn).teleObj===object)return true;
         }
         return false;
      }
      public static function releaseEnemyCaster(units:Array,object:Obj):void {
         if(units==null || object==null)return;
         for each(var u:Unit in units) {
            if(u is UnitAlicorn && (u as UnitAlicorn).teleObj===object) {
               var a:UnitAlicorn=u as UnitAlicorn;
               a.dropTeleObj();
               a.t_tele=-a.tTeleRes; // Native Q takeover also starts this cooldown.
            }
            else if(u is UnitBossAlicorn && (u as UnitBossAlicorn).teleObj===object)
               (u as UnitBossAlicorn).dropTeleObj();
         }
      }
   }
}
