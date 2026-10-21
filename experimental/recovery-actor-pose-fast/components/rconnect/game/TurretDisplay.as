package rconnect.game {
   import fixture.Trace;
   public final class TurretDisplay {
      public static function receive(u:Object,b:Object):void {Trace.note("turret-receive");}
      public static function fire(u:Object):void {Trace.note("turret-fire");}
      public static function present(u:Object,b:Object):void {Trace.note("turret-present");}
   }
}
