package
{
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;
   /** Test-only document class, excluded from production builds. */
   public class CoopTestDoc extends Sprite
   {
      public static const MOD_CLASS:Class = RConnectMod;
      private var timer:Timer = new Timer(1000);
      private var n:int = 0;
      private var checked:Boolean = false;
      private var appearanceChecked:Boolean=false;
      private var host:Boolean;
      private var watched:TcpLink;
      private var networkAt:int=-1;
      private var scenario:CoopNetworkScenario;
      private var lmgScenario:LightMachineGunScenario;
      public function CoopTestDoc()
      {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-") != 0) return;
         host=id.indexOf("pfe-rconnect-coop-host-")==0;
         Log.d("M32 test document starting");
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            Log.d("COOP FAIL uncaught runtime "+e.error);e.preventDefault();
         });
         scenario=new CoopNetworkScenario(id.indexOf("pfe-rconnect-coop-host-")==0);
         lmgScenario=new LightMachineGunScenario(id.indexOf("pfe-rconnect-coop-host-")==0);
         timer.addEventListener(TimerEvent.TIMER, run);
         timer.start();
      }
      private function run(e:TimerEvent):void
      {
         n++;
         var mod:RConnectMod = RConnectMod.instance;
         if(mod == null || mod.game == null || mod.game.gg == null || mod.game.loc == null || n < 15 || !mod.session.rooms.ready || mod.session.rooms.busy) return;
         if(!host && watched!==mod.session.link) {
            watched=mod.session.link;
            watched.addEventListener(TcpLink.MESSAGE,function(e:NetMessageEvent):void {
               if(e.data.type=="coop-fixtures-ready" && networkAt<0)
                  networkAt=getTimer()-int(e.data.elapsed)*1000;
            });
         }
         try
         {
            if(!checked)
            {
               checked=true;
               if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-rconnect-coop-host-")==0)
               {
                  CoopRegression.run(mod);
                  EnemyRegression.run(mod);
                  ExplorationRegression.run(mod);
                  CombatRegression.run(mod);
               }
            }
            // Native fixtures share the room, local armor and alicorn id. Finish
            // their asynchronous observations before either endpoint starts the
            // network scenarios, which deliberately change those same values.
            if(host) {
               if(!CombatRegression.complete)return;
               if(n>=20 && !appearanceChecked)
               {appearanceChecked=true;AppearanceDamageRegression.run(mod);}
               if(!AppearanceDamageRegression.complete)return;
               if(networkAt<0)networkAt=getTimer();
               mod.session.server.broadcast({type:"coop-fixtures-ready",elapsed:int((getTimer()-networkAt)/1000)});
            }
            if(networkAt<0)return;
            var networkTick:int=25+int((getTimer()-networkAt)/1000);
            scenario.tick(mod,networkTick);
            lmgScenario.tick(mod,networkTick);
         }
         catch(err:Error) { timer.stop(); Log.d("COOP FAIL uncaught " + err.getStackTrace()); }
      }
   }
}
