package fe.unit {
   /** Test-only call into the same native action used by the interaction key. */
   public class EnemyGrabProbe {
      public static function grab(player:Object):void {(player as UnitPlayer).actTele();}
      public static function launch(player:Object):void {(player as UnitPlayer).throwTele();}
   }
}
