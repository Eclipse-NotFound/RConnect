package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   /** Runs against the exact separately loaded RV production SWF. */
   public class VisionApiTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),start:int=getTimer(),ready:int=0,done:Boolean=false;
      public function VisionApiTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"vision-api "+label);}
      private function finish():void {done=true;timer.stop();Log.d("COOP EFFECTS DONE vision-api");}
      private function tick(e:TimerEvent):void {
         if(done)return;
         if(getTimer()-start>60000){check(false,"active shared-exploration API became ready");finish();return;}
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         var carrier:Object=mod.main.getChildByName("RVExplorationAPI"),loc:Object=mod.game.loc;
         if(carrier==null || !carrier.api.active(loc))return;
         if(ready==0){ready=getTimer();return;}if(getTimer()-ready<1500)return;
         try {
            ExplorationRegression.run(mod);
            ExplorationEncodingRegression.run(check,loc);
            var api:Object=carrier.api,rows:Array=api.capture(loc),bad:int=0;
            check(rows!=null && rows.length==loc.spaceY,"exact production RV exports current room");
            for(var y:int=0;y<loc.spaceY;y++)for(var x:int=0;x<loc.spaceX;x++) {
               var n:int=Math.max(0,Math.min(15,Math.round(Number(loc.getTile(x,y).visi)*15)));
               if(rows[y].charAt(x*17)!=="0123456789abcdef".charAt(n))bad++;
            }
            check(bad==0,"all tile brightness matches native values");
            var tile:Object=loc.getTile(1,1),before:Number=tile.visi;
            try {
               var errors:int=0;
               for(var i:int=0;i<=15;i++){tile.visi=i/15;if(api.capture(loc)[1].charAt(17)!=="0123456789abcdef".charAt(i))errors++;}
               check(errors==0,"cached history still reads all sixteen changing brightness values");
            }finally{tile.visi=before;}
            var own:String=JSON.stringify(api.capture(loc)),remote:Array=[];
            for(y=0;y<loc.spaceY;y++){var row:String="";for(x=0;x<loc.spaceX;x++)row+="fffffffffffffffff";remote.push(row);}
            check(api.merge(loc,remote),"remote history accepted by exact production RV");
            check(JSON.stringify(api.capture(loc))===own,"shared history cannot become local history in capture");
            rows=api.capture(loc);rows[0]="caller-mutated";
            check(JSON.stringify(api.capture(loc))===own,"caller cannot mutate cached strings through returned rows");
            check(tile.visi===before,"native light is restored after isolated oracle input");
         }catch(error:Error){check(false,"exception "+error.getStackTrace());}
         finish();
      }
   }
}
