package fe.unit {
   // Test-only native state setup, equivalent to entering/exiting the AI states.
   public class CombatStateProbe {
      public static function ai(u:Unit,n:int):void {u.aiState=n;}
      public static function state(u:Unit):int {return u.aiState;}
      public static function aware(u:Unit):Boolean {return u is UnitRaider && (u as UnitRaider).aiVKurse;}
      public static function shield(u:Unit):Object {return u is UnitAlicorn?(u as UnitAlicorn).visshit:null;}
   }
}
