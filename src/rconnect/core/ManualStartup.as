package rconnect.core {
   import flash.desktop.NativeApplication;
   import flash.events.Event;
   import flash.utils.getTimer;

   /** Open the native save chooser once for the persistent manual second
    * profile. Never bootstrap a new game or select a save on the user's behalf. */
   public class ManualStartup {
      public static const PROFILE:String = "pfe-modsettings-rconnect-player2";
      private var mod:Object;
      private var started:int;

      public function ManualStartup(m:Object) {
         if (NativeApplication.nativeApplication.applicationID != PROFILE) return;
         mod = m;
         started = getTimer();
         mod.stage.addEventListener(Event.ENTER_FRAME, tick, false, -20000);
      }

      /** Kept separate so the native menu path can be exercised in isolated
       * profiles without ever opening or editing the real player's storage. */
      public static function openSaveChooser(world:Object):Boolean {
         if (world == null || world.mm == null || !world.mm.loaded || world.landData == null) return false;
         // A user who already left the menu wins; do not interrupt gameplay.
         if (!world.mm.active || world.gg != null) return true;
         world.mm.funLoadGame(null);
         Log.d("RConnectLauncher: native save chooser opened");
         return true;
      }

      private function tick(e:Event):void {
         try {
            if (openSaveChooser(mod.game.world)) { stop(); return; }
            if (getTimer() - started > 120000) {
               Log.d("RConnectLauncher: menu not ready; use Load Game manually");
               stop();
            }
         } catch (error:Error) {
            Log.d("RConnectLauncher: save chooser unavailable: " + error.message);
            stop();
         }
      }

      private function stop():void {
         mod.stage.removeEventListener(Event.ENTER_FRAME, tick);
         mod = null;
      }
   }
}
