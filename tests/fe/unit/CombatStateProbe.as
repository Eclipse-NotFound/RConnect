package fe.unit {
   // Test-only native state setup, equivalent to entering/exiting the AI states.
   public class CombatStateProbe {
      public static function ai(u:Unit,n:int):void {u.aiState=n;}
      public static function state(u:Unit):int {return u.aiState;}
   }
}
