package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.PresentationProbe;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.RemoteMotion;

   /** Exact production seams, with native camouflage and reproducible packet jitter. */
   public class SmoothPresentationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),mod:RConnectMod,host:Boolean,done:Boolean=false;
      private var bridge:GameBridge,enemy:Object,ghost:Object,start:int,previous:int,previousX:Number;
      private var count:int=0,nextPacket:int=0,trace:Array=[],phase:int=0,baseX:Number,baseY:Number;
      private var intervals:Array=[160,240,190,210,180,220],packets:int=0;
      private var all:Array=[];
      public function SmoothPresentationTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,boot);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"smooth "+s);}
      private function boot(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(done || mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null
            || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         done=true;timer.stop();
         if(!host){Log.d("COOP EFFECTS DONE smooth join");return;}
         try {
            jitter();
            bridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
            bridge.world=mod.game.world;bridge.loc=mod.game.loc;bridge.gg=mod.game.gg;
            bridge.roomEpoch=mod.game.roomEpoch;bridge.freezeAI=true;bridge.ghostCombat=false;
            bridge.gg.disabled=true;bridge.gg.dx=bridge.gg.dy=0;bridge.world.pers.infravis=0;
            baseX=bridge.gg.X;baseY=bridge.gg.Y;
            // Both roles run the same isolated presentation seam in their actual world.
            camouflage("UnitZebra","1",<unit tr="1"/>,50);
            camouflage("UnitAlicorn","3",<unit tr="3"/>,150);
            enemy=spawn("UnitMerc","1",<unit tr="1"/>,100);
            enemy.dx=3;enemy.stay=true;enemy.animate();
            bridge.gg.vis.osn.gotoAndStop("run");bridge.gg.vis.osn.body.play();
            var snap:Object=bridge.readSnapshot();snap.x=baseX+50;snap.dx=0;snap.dy=0;
            bridge.updateRemote(989,snap,"cadence");ghost=bridge.getRemoteGhost(989);
            reset();mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,-20000);
         } catch(error:Error){check(false,"setup "+error.getStackTrace());finish();}
      }
      private function spawn(name:String,id:String,xml:XML,offset:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new c(id,100,xml,null);u.putLoc(bridge.loc,baseX+offset,baseY);
         bridge.loc.addObj(u);bridge.loc.units.push(u);u.disabled=true;u.doop=true;u.xp=0;
         all.push(u);return u;
      }
      private function camouflage(name:String,id:String,xml:XML,offset:Number):void {
         var u:Object=spawn(name,id,xml,offset);PresentationProbe.fade(u as Unit);u.vis.visible=true;
         var alpha:Number=u.vis.alpha;
         check(alpha>0 && alpha<0.5 && !u.isVis,"native faint camouflage fixture "+name+" alpha="+alpha);
         var snaps:Array=JSON.parse(JSON.stringify(bridge.readUnitsSnapshot())) as Array;
         bridge.applyUnitsSync(snaps);bridge.tickFrozenAnims();mod.stage.dispatchEvent(new Event(Event.RENDER));
         check(u.vis.visible && Math.abs(u.vis.alpha-alpha)<0.005 && EnemyRegression.pixels(u.vis)>0,
            "faint native camouflage remains rendered "+name+" visible="+u.vis.visible+" alpha="+u.vis.alpha);
         check(u.invis && !u.isVis,"camouflage does not change native detection eligibility "+name);
      }
      private function jitter():void {
         var motion:RemoteMotion=new RemoteMotion(),arrivals:Array=[],i:int=0,t:int;
         var delays:Array=[0,30,0,40,5,0,20,0];
         for(t=0;t<=3000;t+=50)arrivals.push({arrival:t+delays[(t/50)%delays.length],time:t});
         var previous:Number=NaN,stalls:int=0,errors:Array=[];
         for(t=0;t<3000;t+=10) {
            while(i<arrivals.length && arrivals[i].arrival<=t) {
               var source:int=arrivals[i++].time;
               motion.push({x:source*0.3,y:100,aimX:source*0.3+50,aimY:100,sampleTime:source},t);
            }
            var s:Object=motion.sample(t);
            if(t>=500) {var step:Number=s.x-previous;errors.push(Math.abs(step-3));if(step<0.1)stalls++;}
            previous=s.x;
         }
         errors.sort(Array.NUMERIC);var p95:Number=errors[int(errors.length*.95)];
         check(stalls<=1 && p95<0.75,"constant-speed peer under repeatable jitter stalls="+stalls+" p95StepError="+p95.toFixed(3));
         check(motion.sample(9000).x==885,"stale stream settles at last received endpoint");
         motion.push({x:940,y:100,aimX:990,aimY:100},10000);
         check(isFinite(motion.sample(10100).x),"unstamped room checkpoint can replace a timed stream");
         motion.push({x:1800,y:100,aimX:1850,aimY:100,sampleTime:12000},12000);
         check(motion.sample(12000).x==1800,"timed teleport resets the old playback buffer");
         motion=new RemoteMotion();motion.push({x:0,y:100,sampleTime:0},500);
         for(t=550;t<=1500;t+=50){motion.push({x:t*.3,y:100,sampleTime:t},t);motion.sample(t);}
         check(Math.abs(motion.sample(1500).x-420)<25,"fresh stream recovers from a delayed initial room snapshot");
      }
      private function reset():void {start=getTimer();previous=0;count=packets=0;nextPacket=0;trace=[];}
      private function frame(e:Event):void {
         try {
            var now:int=getTimer(),elapsed:int=now-start;
            if(phase==1){bridge.gg.stay=true;bridge.gg.dx=5;bridge.gg.dy=0;bridge.gg.animate();}
            var target:Object=phase==0?enemy:ghost;
            if(previous>0 && elapsed>1000) {
               trace.push({dt:now-previous,dx:Number(target.X)-previousX,body:phase==0?PresentationProbe.frame(enemy as Unit):ghost.vis.osn.body.currentFrame,
                  source:phase==0?-1:bridge.gg.vis.osn.body.currentFrame});
            }
            previous=now;previousX=Number(target.X);count++;
            if(elapsed>=nextPacket) {
               if(phase==0) {
                  var list:Array=JSON.parse(JSON.stringify(bridge.readUnitsSnapshot())) as Array;
                  for each(var item:Object in list)if(item.id==enemy.id) {item.x=baseX+100+elapsed*.04;item.sampleTime=now;}
                  bridge.applyUnitsSync(list);
               } else {
                  var snap:Object=bridge.readSnapshot();snap.x=baseX+50+elapsed*.04;snap.sampleTime=now;snap.dx=0;snap.dy=0;
                  bridge.updateRemote(989,snap,"cadence");
               }
               nextPacket=elapsed+int(intervals[packets++%intervals.length])/(phase==0?1:3);
            }
            if(elapsed>=5000) {
               var err:Array=[],stalls:int=0,repeated:int=0,last:Number=-1,sourceRepeated:int=0,sourceLast:Number=-1;
               for each(var row:Object in trace) {
                  err.push(Math.abs(row.dx/row.dt-.04));if(row.dx<.02)stalls++;
                  if(row.body==last)repeated++;last=row.body;
                  if(row.source==sourceLast)sourceRepeated++;sourceLast=row.source;
               }
               err.sort(Array.NUMERIC);
               Log.d("SMOOTH TRACE role="+(host?"host":"join")+" phase="+phase+" "+JSON.stringify(trace));
               check(trace.length>=20 && stalls<=2 && err[int(err.length*.95)]<.018,
                  (phase==0?"enemy":"peer")+" movement cadence frames="+trace.length+" stalls="+stalls+" p95SpeedError="+err[int(err.length*.95)]);
               check(phase==0?repeated<trace.length*.5:repeated<=sourceRepeated+2,
                  (phase==0?"enemy":"peer")+" body follows native cadence repeated="+repeated+"/"+trace.length+" sourceRepeated="+sourceRepeated);
               if(phase==0){phase=1;reset();}else finish();
            }
         } catch(error:Error){check(false,"frame "+error.getStackTrace());finish();}
      }
      private function finish():void {
         mod.stage.removeEventListener(Event.ENTER_FRAME,frame);
         if(bridge!=null)bridge.endSession();
         for each(var u:Object in all){mod.game.loc.remObj(u);var index:int=mod.game.loc.units.indexOf(u);if(index>=0)mod.game.loc.units.splice(index,1);}
         Log.d("COOP EFFECTS DONE smooth "+(host?"host":"join"));
      }
   }
}
