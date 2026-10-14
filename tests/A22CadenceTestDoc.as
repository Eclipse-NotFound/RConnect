package {
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   public class A22CadenceTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100);
      private var readyAt:int=0;
      public function A22CadenceTestDoc() {timer.addEventListener(TimerEvent.TIMER,tick);timer.start();}
      private function tick(e:TimerEvent):void {
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.main==null)return;
         mod.game.gg.invulner=true;
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning()
            || String(mod.game.readWorldInfo().curLandId)!="rbl"){readyAt=0;return;}
         if(readyAt==0)readyAt=getTimer();
         if(getTimer()-readyAt<700)return;
         timer.stop();
         try {ProjectileCadenceRegression.run(mod.main,function(ok:Boolean,label:String):void {
            Log.d("COOP "+(ok?"PASS ":"FAIL ")+"projectile-cadence "+label);
         });}catch(error:Error){Log.d("COOP FAIL projectile-cadence "+error.getStackTrace());}
         Log.d("COOP EFFECTS DONE projectile-cadence");
      }
   }
}
