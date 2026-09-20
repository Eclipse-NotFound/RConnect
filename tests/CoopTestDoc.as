package
{
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import rconnect.core.Log;
   /** Test-only document class, excluded from production builds. */
   public class CoopTestDoc extends Sprite
   {
      public static const MOD_CLASS:Class = RConnectMod;
      private var timer:Timer = new Timer(1000);
      private var n:int = 0;
      private var checked:Boolean = false;
      private var scenario:CoopNetworkScenario;
      public function CoopTestDoc()
      {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-") != 0) return;
         scenario=new CoopNetworkScenario(id.indexOf("pfe-rconnect-coop-host-")==0);
         timer.addEventListener(TimerEvent.TIMER, run);
         timer.start();
      }
      private function run(e:TimerEvent):void
      {
         n++;
         var mod:RConnectMod = RConnectMod.instance;
         if(mod == null || mod.game == null || mod.game.gg == null || mod.game.loc == null || n < 15) return;
         try
         {
            if(!checked)
            {
               checked=true;
               if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-rconnect-coop-host-")==0)
               {
                  CoopRegression.run(mod);
                  EnemyRegression.run(mod);
                  CombatRegression.run(mod);
               }
            }
            scenario.tick(mod,n);
         }
         catch(err:Error) { timer.stop(); Log.d("COOP FAIL uncaught " + err.getStackTrace()); }
      }
   }
}
