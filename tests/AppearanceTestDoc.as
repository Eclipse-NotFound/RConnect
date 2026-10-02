package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import rconnect.core.Log;
   /** Isolated real native appearance/damage lifecycle regression. */
   public class AppearanceTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),started:Boolean=false;
      private var host:Boolean;
      public function AppearanceTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function tick(e:TimerEvent):void {
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null
            || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         if(!host){timer.stop();Log.d("COOP EFFECTS DONE appearance join");return;}
         if(!started){started=true;AppearanceDamageRegression.run(mod);}
         if(AppearanceDamageRegression.complete){timer.stop();Log.d("COOP EFFECTS DONE appearance host");}
      }
   }
}
