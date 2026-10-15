package {
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   public class A22ImpactLifetimeTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),readyAt:int=0;
      public function A22ImpactLifetimeTestDoc() {timer.addEventListener(TimerEvent.TIMER,tick);timer.start();}
      private function tick(e:TimerEvent):void {
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.main==null)return;
         mod.game.gg.invulner=true;
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning()
            || String(mod.game.readWorldInfo().curLandId)!="rbl"){readyAt=0;return;}
         if(readyAt==0)readyAt=getTimer();
         if(getTimer()-readyAt<700)return;
         timer.stop();
         try {EnergyImpactLifetimeRegression.run(mod.main,function(ok:Boolean,label:String):void {
            Log.d("COOP "+(ok?"PASS ":"FAIL ")+"impact-lifetime "+label);
         });}catch(error:Error){Log.d("COOP FAIL impact-lifetime "+error.getStackTrace());}
         Log.d("COOP EFFECTS DONE impact-lifetime");
      }
   }
}
