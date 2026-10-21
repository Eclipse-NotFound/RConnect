package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.system.System;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.ProjectileVisuals;

   /** The same test compiles against unchanged recovery-03 and this overlay.
    * Calls the existing public forget(owner) entry, not new helper methods.
    * Real production queues/clocks/finite-effect renderer; no game/TCP/assets. */
   public class DetachChecks extends Sprite {
      private var checks:Array=[],failures:int=0,scenes:Array=[],timer:Timer;
      public function DetachChecks() {
         try {
            sameRoom();roomChanged();repeatedForget();otherOwner();timeout();
            energy();energyOtherOwner();energyRoomChanged();activeFlight();nullMotion();
            pausedDetach();
         } catch(error:Error) {check(false,"uncaught "+error.getStackTrace());finish();}
      }
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failures++;
      }
      private function later(ms:int,callback:Function):void {
         timer=new Timer(ms,1);
         timer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void {
            try {callback();}catch(error:Error){check(false,"uncaught async "+error.getStackTrace());finish();}
         });timer.start();
      }
      private function scene():Object {
         var s:Object={v:new ProjectileVisuals(),clock:new FixtureClock(),calls:[],layer:new Sprite()};
         s.loc={active:true,firstObj:null,lastObj:null,getAbsTile:function(x:Number,y:Number):Object{return {phis:0};}};
         s.owner={loc:s.loc};
         s.main={loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            if(name=="fe.graph.Emitter")return {emit:function(kind:String,loc:Object,x:Number,y:Number,options:Object):void {
               s.calls.push({kind:kind,loc:loc,x:x,y:y,count:options.kol,at:getTimer()});
            }};
            if(name=="fe.World")return {w:{grafon:{visObjs:[s.layer,s.layer,s.layer,s.layer,s.layer]}}};
            if(name=="flPlasma" || name=="FixtureFlare")return FixtureFlare;
            throw new Error("unexpected native boundary "+name);
         }}}};
         scenes.push(s);return s;
      }
      private function gun(x:Number=10,stamp:Number=1100):Array {
         // Latest received source time is intentionally ahead of the displayed
         // clock. Falling straight to channel.offset would fire immediately.
         return [{id:"lmg",variant:0,stream:1,sampleTime:1200,impacts:[],events:[
            {seq:1,impact:{at:stamp,x:x,y:20,groups:[{kind:"iskr_bul",count:4,dx:-10,dy:0}]}}]}];
      }
      private function point(at:int,x:Number):Object {
         return {at:at,x:x,y:20,r:0,sx:1,sy:1,a:1,f:1,v:true,c:[1,1,1,1,0,0,0,0]};
      }
      private function energyGun(x:Number=10):Array {
         return [{id:"nova",variant:0,stream:2,sampleTime:1200,events:[],impacts:[
            {id:1,cls:"flPlasma",layer:2,blend:"normal",frames:[point(1000,x),point(1100,x+10)],end:1150}]}];
      }
      private function receive(s:Object,packet:Array,owner:Object=null,clock:FixtureClock=null):void {
         s.v.receive(owner==null?s.owner:owner,packet,s.main,true,clock==null?s.clock:clock);
      }
      private function forget(s:Object):Object {
         var before:int=getTimer();s.v.forget(s.owner);return {before:before,after:getTimer()};
      }
      private function sameRoom():void {
         var s:Object=scene(),packet:Array=gun();receive(s,packet);receive(s,packet);
         s.v.tick(s.loc,getTimer());check(s.calls.length==0,"same room: pending hit waits for displayed cursor");
         var mark:Object=forget(s);
         s.v.tick(s.loc,mark.before+199);check(s.calls.length==0,"same room: detach does not jump to latest source or impact");
         s.v.tick(s.loc,mark.after+201);check(s.calls.length==1,"REGRESSION same room: queued hit survives shooter forget");
         s.v.tick(s.loc,mark.after+900);check(s.calls.length==1,"REGRESSION same room: duplicate packet and further ticks emit exactly once");
         s.v.reset();
      }
      private function roomChanged():void {
         var s:Object=scene();receive(s,gun());var mark:Object=forget(s),other:Object={active:true};
         s.v.tick(other,mark.after+201);s.v.tick(s.loc,mark.after+900);
         check(s.calls.length==0,"room switch: old room hit is discarded and cannot reappear on revisit");s.v.reset();
      }
      private function repeatedForget():void {
         var s:Object=scene();receive(s,gun());var mark:Object=forget(s);
         // The stopped clock must have no influence after the first detach.
         s.clock.time=50000;s.v.forget(s.owner);s.v.forget({loc:s.loc});
         s.v.tick(s.loc,mark.before+199);check(s.calls.length==0,"repeated forget: old shooter clock cannot pull a detached hit forward");
         s.v.tick(s.loc,mark.after+201);s.v.forget(s.owner);s.v.tick(s.loc,mark.after+900);
         check(s.calls.length==1,"REGRESSION repeated forget: original local anchor and once-only hit survive");s.v.reset();
      }
      private function otherOwner():void {
         var s:Object=scene(),peer:Object={loc:s.loc},clock:FixtureClock=new FixtureClock();
         receive(s,gun(10));receive(s,gun(210),peer,clock);var mark:Object=forget(s);
         s.v.tick(s.loc,mark.after+201);
         check(s.calls.length==1 && s.calls[0].x==10,"REGRESSION owner isolation: only forgotten shooter continues locally");
         clock.time=1100;s.v.tick(s.loc,mark.after+202);
         check(s.calls.length==2 && s.calls[1].x==210,"REGRESSION owner isolation: another shooter still follows its actual cursor");s.v.reset();
      }
      private function timeout():void {
         var s:Object=scene();receive(s,gun(10,20000));var mark:Object=forget(s);
         s.v.tick(s.loc,mark.after+15001);s.v.tick(s.loc,mark.after+30000);
         check(s.calls.length==0,"timeout: detached pending hit still expires without a late invented emission");s.v.reset();
      }
      private function energy():void {
         var s:Object=scene(),packet:Array=energyGun();receive(s,packet);receive(s,packet);
         var mark:Object=forget(s);s.v.tick(s.loc,mark.before+99);
         check(s.layer.numChildren==0,"finite energy: detach does not skip ahead to the first pose");
         s.v.tick(s.loc,mark.after+150);
         check(s.layer.numChildren==1 && s.layer.getChildAt(0).x==10,"REGRESSION finite energy: received first pose survives shooter forget");
         s.v.tick(s.loc,mark.after+251);
         check(s.layer.numChildren==1 && s.layer.getChildAt(0).x==20,"REGRESSION finite energy: confirmed final pose advances without old motion");
         s.v.tick(s.loc,mark.after+252);check(s.layer.numChildren==0,"finite energy: original terminal recovery removes the final pose");s.v.reset();
      }
      private function energyOtherOwner():void {
         var s:Object=scene(),peer:Object={loc:s.loc},clock:FixtureClock=new FixtureClock();
         receive(s,energyGun(10));receive(s,energyGun(210),peer,clock);var mark:Object=forget(s);
         s.v.tick(s.loc,mark.after+150);
         check(s.layer.numChildren==1 && s.layer.getChildAt(0).x==10,"REGRESSION finite owner isolation: only forgotten channel advances");
         clock.time=1050;s.v.tick(s.loc,mark.after+151);
         var found:Boolean=false;for(var i:int=0;i<s.layer.numChildren;i++)if(s.layer.getChildAt(i).x==210)found=true;
         check(found,"finite owner isolation: still-present shooter retains its own source clock");s.v.reset();
      }
      private function energyRoomChanged():void {
         var s:Object=scene();receive(s,energyGun());var mark:Object=forget(s);
         s.v.tick({active:true},mark.after+150);s.v.tick(s.loc,mark.after+200);
         check(s.layer.numChildren==0,"finite room switch: detached old-room artwork does not return");s.v.reset();
      }
      private function activeFlight():void {
         var s:Object=scene();receive(s,[{id:"test",stream:3,variant:0,sampleTime:900,impacts:[],events:[
            {seq:1,flight:{cls:"FixtureFlare",blend:"normal",spring:1,rot:0,x:0,y:0,end:0,
               frames:[{at:900,x:10,y:20,rot:0,sx:1,sy:1,a:1,f:1,ls:1,lf:1}]}}]}]);
         s.v.tick(s.loc,getTimer());check(s.v.count==1 && s.layer.numChildren==1,"flight control: original active projectile is created");
         s.v.forget(s.owner);check(s.v.count==0 && s.layer.numChildren==0,"flight control: forget still removes active flight visuals");s.v.reset();
      }
      private function nullMotion():void {
         var s:Object=scene(),before:int=getTimer(),packet:Array=gun();packet[0].sampleTime=1000;
         s.v.receive(s.owner,packet,s.main,true,null);var after:int=getTimer();s.v.forget(s.owner);
         s.v.tick(s.loc,before+199);check(s.calls.length==0,"null motion: an existing fallback is not advanced by forget");
         s.v.tick(s.loc,after+201);check(s.calls.length==1,"null motion: existing fallback continues unchanged");s.v.reset();
      }
      private function pausedDetach():void {
         var s:Object=scene();receive(s,gun());receive(s,energyGun());s.v.setPaused(true);forget(s);
         s.v.tick(s.loc,getTimer()+100000);
         check(s.calls.length==0 && s.layer.numChildren==0,"paused detach: future tick cannot advance either confirmed effect");
         later(50,function():void {
            var before:int=getTimer();s.v.setPaused(false);var after:int=getTimer();
            s.v.tick(s.loc,before+99);check(s.layer.numChildren==0,"paused detach: resume preserves the pre-impact gap");
            s.v.tick(s.loc,before+199);check(s.calls.length==0,"paused detach: resume does not fire before the last cursor plus 200ms");
            s.v.tick(s.loc,after+201);check(s.calls.length==1,"REGRESSION paused detach: hit continues once after resume");
            check(s.layer.numChildren==1,"REGRESSION paused detach: finite energy also resumes");
            s.v.reset();arrivalDuringPause();
         });
      }
      private function arrivalDuringPause():void {
         var s:Object=scene(),pausedAt:int=getTimer();s.v.setPaused(true);
         later(60,function():void {
            check(getTimer()>pausedAt,"mid-pause fixture really receives on a later local clock tick");
            receive(s,gun());receive(s,energyGun());forget(s);s.v.tick(s.loc,getTimer()+100000);
            check(s.calls.length==0 && s.layer.numChildren==0,"mid-pause detach remains frozen");
            later(60,function():void {
               var before:int=getTimer();s.v.setPaused(false);var after:int=getTimer();
               s.v.tick(s.loc,before+99);check(s.layer.numChildren==0,"mid-pause anchor: no receive-to-pause time is added to the energy cursor");
               s.v.tick(s.loc,before+199);check(s.calls.length==0,"mid-pause anchor: no receive-to-pause time is added to the hit cursor");
               s.v.tick(s.loc,after+201);check(s.calls.length==1,"REGRESSION mid-pause hit resumes at its retained cursor");
               check(s.layer.numChildren==1,"REGRESSION mid-pause finite energy resumes at its retained cursor");
               s.v.reset();pauseAfterForget();
            });
         });
      }
      private function pauseAfterForget():void {
         var s:Object=scene();receive(s,gun(10,1300));var mark:Object=forget(s);
         var beforePause:int=getTimer();s.v.setPaused(true);var afterPause:int=getTimer();
         // There is no external reference to the private per-weapon channel.
         // The queue must retain it until the hit retires so a GC cannot make
         // its existing pause/resume channel traversal miss the detached clock.
         System.gc();System.gc();
         later(450,function():void {
            s.v.tick(s.loc,getTimer()+100000);check(s.calls.length==0,"pause after forget: detached channel remains frozen across GC request");
            var beforeResume:int=getTimer();s.v.setPaused(false);var afterResume:int=getTimer();
            var elapsedBeforePause:int=afterPause-mark.before;
            s.v.tick(s.loc,beforeResume+399-elapsedBeforePause);
            check(s.calls.length==0,"pause after forget: weak channel lifetime cannot bypass pause subtraction");
            s.v.tick(s.loc,afterResume+401);
            check(s.calls.length==1,"REGRESSION pause after forget: retained channel resumes once");
            s.v.reset();finish();
         });
      }
      private function finish():void {
         if(timer!=null)timer.stop();for each(var s:Object in scenes)s.v.reset();
         var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         file.writeUTFBytes(JSON.stringify({passed:failures==0,failed:failures,total:checks.length,
            passed_count:checks.length-failures,assertions:checks,
            productionReceiver:true,productionQueue:true,productionClockFallback:true,
            controlledShooterClock:true,nativeArtwork:false,nativeGame:false,tcp:false}));file.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }
   }
}
