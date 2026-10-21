package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.*;

   /** Real before/after production classes, renamed only; no game/TCP/pixels. */
   public class ClockCatchupChecks extends Sprite {
      private var assertions:Array=[],failed:int=0,actualReplay:Array=[],metrics:Object={};
      public function ClockCatchupChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function near(a:Number,b:Number):Boolean {
         // Four ulps at this exponent, only for numeric JSON round-trip/output.
         if(a==b)return true;if(!isFinite(a+b))return false;
         var scale:Number=Math.max(Math.abs(a),Math.abs(b));
         var exponent:int=scale==0?-1022:Math.floor(Math.log(scale)/Math.LN2);
         return Math.abs(a-b)<=4*Math.pow(2,exponent-52);
      }
      private function copy(v:*):* {
         if(v==null || typeof v!="object")return v;
         var out:*=v is Array?[]:{};for(var k:String in v)out[k]=copy(v[k]);return out;
      }
      private function equal(a:*,b:*):Boolean {
         if(a===b)return true;if(a is Number && b is Number && isNaN(a)&&isNaN(b))return true;
         if(a==null || b==null || typeof a!=typeof b || typeof a!="object" || (a is Array)!=(b is Array))return false;
         var ak:Array=[],bk:Array=[],k:String;for(k in a)ak.push(k);for(k in b)bk.push(k);ak.sort();bk.sort();
         if(ak.join("|")!=bk.join("|"))return false;
         for each(k in ak)if(!equal(a[k],b[k]))return false;return true;
      }
      private function snap(stamp:Number,x:Number=0,room:String="fixture",epoch:int=1):Object {
         return {sampleTime:stamp,x:x,y:20,aimX:x+100,aimY:40,roomKey:room,roomEpoch:epoch,
            weapons:[{slot:0,id:"fixture",variant:1,stream:1,rot:stamp/10000,ox:2,oy:3,
               display:{x:stamp/100,y:4,r:stamp/10000,sx:1,sy:1}}]};
      }
      private function pair(kind:String="actor"):Object {
         if(kind=="held")return {a:RemoteMotionBefore.held(),b:RemoteMotionAfter.held()};
         if(kind=="enemy")return {a:RemoteMotionBefore.enemy(),b:RemoteMotionAfter.enemy()};
         return {a:new RemoteMotionBefore(50,kind=="drop"),b:new RemoteMotionAfter(50,kind=="drop")};
      }
      private function push(p:Object,stamp:Number,now:int,x:Number=0,room:String="fixture",epoch:int=1,y:Number=20):void {
         var a:Object=snap(stamp,x,room,epoch),b:Object=snap(stamp,x,room,epoch);a.y=b.y=y;
         p.a.push(a,now);p.b.push(b,now);
      }
      private function samplePair(p:Object,now:int):Boolean {
         var a:Object=copy(p.a.sample(now)),b:Object=copy(p.b.sample(now));
         return equal(a,b) && p.a.sourceTime===p.b.sourceTime;
      }
      private function debt():Object {
         var p:Object=pair();push(p,1000,1000);push(p,1100,1040);push(p,1200,1080);push(p,1300,1120);return p;
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {run();}catch(error:*){check(false,"uncaught component error "+String(error)+" "+error.getStackTrace());}
         var out:Object={passed:failed==0,failed:failed,assertions:assertions,metrics:metrics,trace:actualReplay,
            native_game_test:false,performance_qualified:false};
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify(out));f.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function replay():void {
         var t:Object=ClockTrace.data(),p:Object=pair(),seed:Object=t.seed;
         var original:String=JSON.stringify(t),oldMatch:Boolean=true,noPushSeek:Boolean=true,zeroStable:Boolean=true;
         var bounded:Boolean=true,forward:Boolean=true,oldFirst:int=-1,newFirst:int=-1;
         var lastSampleTime:int=seed.sampleNow;
         push(p,seed.stamp,seed.now,seed.x,"fixture",1,seed.y);p.a.sample(seed.sampleNow);p.b.sample(seed.sampleNow);
         check(near(p.a.sourceTime,seed.cursor)&&p.a.sourceTime===p.b.sourceTime,"recorded single-frame seed reconstructed through public push/sample");
         for(var i:int=0;i<t.rows.length;i++) {
            var r:Array=t.rows[i],op:int=int(r[0]),now:int=int(r[1]);
            var before:Number=p.b.sourceTime,oldBefore:Number=p.a.sourceTime;
            if(op==1) {
               oldMatch=oldMatch&&near(oldBefore,r[3]);
               push(p,r[2],now,seed.x,"fixture",1,seed.y);
               if(i==0)lastSampleTime=now;
               // Row 0 is the existing >250ms reset, not a calibration seek.
               if(i>0)noPushSeek=noPushSeek&&p.b.sourceTime===before;
            } else if(op==2)oldMatch=oldMatch&&near(p.a.sourceTime,r[3]);
            else {
               p.a.sample(now);p.b.sample(now);oldMatch=oldMatch&&near(p.a.sourceTime,r[3]);
               if(now<=lastSampleTime)zeroStable=zeroStable&&p.b.sourceTime===before;
               lastSampleTime=Math.max(lastSampleTime,now);
               forward=forward&&p.b.sourceTime>=before;
               if(oldFirst<0 && p.a.sourceTime>=t.first_projectile_stamp)oldFirst=int(r[8]);
               if(newFirst<0 && p.b.sourceTime>=t.first_projectile_stamp)newFirst=int(r[8]);
            }
            bounded=bounded&&p.b.sourceTime<=p.b.latestSampleTime;
            actualReplay.push({index:i,op:op,now:now,at:r[8],old:p.a.sourceTime,proposed:p.b.sourceTime,
               delta:p.b.sourceTime-p.a.sourceTime,recorded:r[3]});
         }
         metrics.recorded={rows:t.rows.length,oldFirst:oldFirst,newFirst:newFirst,gainMs:oldFirst-newFirst,
            receivedAt:t.first_real_frames_receive_at,newWaitMs:newFirst-t.first_real_frames_receive_at,
            timingOnly:true,fullSnapshotsRecorded:false};
         check(t.rows.length==180 && actualReplay.length==180,"all 180 real timing records retain original push/sample order");
         check(oldMatch,"old real AS clock reproduces every recorded cursor within four numeric ulps");
         check(noPushSeek,"new actor calibration never seeks on any non-reset recorded push");
         check(zeroStable,"repeated/stale effective sample timestamps do not advance new clock");
         check(forward&&bounded,"real replay remains monotonic and never passes received endpoint");
         check(oldFirst==46159 && newFirst==45956,"real AS replay independently matches reviewed old/new first eligible instants");
         check(JSON.stringify(t)==original,"real timing input and order remain immutable");
      }
      private function protectedPolicy(kind:String):void {
         var t:Object=ClockTrace.data(),p:Object=pair(kind),same:Boolean=true;
         push(p,t.seed.stamp,t.seed.now);same=samplePair(p,t.seed.sampleNow)&&same;
         for each(var r:Array in t.rows) {
            if(r[0]==1)push(p,r[2],r[1]);
            else if(r[0]==3)same=samplePair(p,r[1])&&same;
            same=same&&p.a.sourceTime===p.b.sourceTime;
         }
         check(same,kind+" real timing replay preserves old clock and complete output exactly");
      }
      private function run():void {
         replay();protectedPolicy("held");protectedPolicy("enemy");protectedPolicy("drop");
         var p:Object=pair(),ok:Boolean=true,i:int,n:int,before:Number;push(p,1000,1000);
         for(i=1;i<=80;i++) {
            push(p,1000+i*50,1000+i*50,i);
            ok=samplePair(p,1000+i*50)&&ok;ok=samplePair(p,1015+i*50)&&ok;
         }
         check(ok,"stable traffic preserves full actor/aim/weapon interpolation exactly");
         p=pair();push(p,1000,1000);ok=true;
         for(i=1;i<=20;i++) {
            push(p,1000+i*70,1030+i*70);
            ok=samplePair(p,1030+i*70)&&samplePair(p,1055+i*70)&&ok;
         }
         check(ok,"packet delay changes without offset calibration keep original playback exactly");
         p=pair();push(p,1000,1000);push(p,1150,1150);p.b.sample(1150);
         before=p.b.sourceTime;
         push(p,1250,1190);push(p,1350,1230);push(p,1450,1270);p.b.sample(1270);
         check(near(p.b.sourceTime-before,129.6),"catch-up ramps from preceding 0.9x ordinary speed rather than snapping its rate to 1x");
         p=pair();push(p,1000,1000);before=p.b.sourceTime;
         push(p,1100,1070);
         check(p.b.sourceTime===before,"single small offset correction does not seek cursor");
         check(samplePair(p,1070)&&samplePair(p,1080),"single small correction keeps the original ordinary playback");
         p=debt();before=p.b.sourceTime;
         check(before==900 && p.a.sourceTime==900,"three 60ms corrections accumulate without a receive-side seek");
         p.a.sample(1120);p.b.sample(1120);
         check(p.b.sourceTime>p.a.sourceTime && p.b.sourceTime-before<=120*1.5,"actual cumulative debt activates bounded continuous catch-up");
         var previousTime:int=1120,previousCursor:Number=p.b.sourceTime,previousDt:Number=120;
         var previousSpeed:Number=(previousCursor-before)/120,rateBound:Boolean=true,smooth:Boolean=true;
         for(i=1;i<=20;i++) {
            n=1120+i*10;push(p,1300+i*10,n);p.b.sample(n);
            var dt:Number=n-previousTime,speed:Number=(p.b.sourceTime-previousCursor)/dt;
            rateBound=rateBound&&speed>=.9-1e-9&&speed<=1.5+1e-9;
            smooth=smooth&&Math.abs(speed-previousSpeed)<=.003*(dt+previousDt)/2+1e-9;
            previousTime=n;previousCursor=p.b.sourceTime;previousSpeed=speed;previousDt=dt;
         }
         check(rateBound,"continuous calibration speed stays within 0.9--1.5x");
         check(smooth,"successive integrated speeds respect the 0.003/ms acceleration bound");
         before=p.b.sourceTime;ok=true;
         for(i=0;i<100;i++){p.b.sample(previousTime);ok=ok&&p.b.sourceTime===before;}
         check(ok,"100 zero-time samples neither accelerate nor move the clock");
         var latest:Number=p.b.latestSampleTime;
         push(p,latest,previousTime+1);push(p,latest-10,previousTime+2);
         check(p.b.sourceTime===before&&p.b.latestSampleTime===latest,"duplicate and out-of-order packets do not advance cursor or history endpoint");
         p.b.sample(previousTime+5000);
         check(p.b.sourceTime<=latest,"catch-up does not extrapolate after packets stop");
         p=debt();p.a.sample(1120);p.b.sample(1120);ok=true;
         for(i=1;i<=100;i++) {
            push(p,1300+i*50,1120+i*50);var same:Boolean=samplePair(p,1120+i*50);
            if(i>80)ok=ok&&same;
         }
         check(ok,"after debt repayment stable network returns to old complete output exactly");
         p=pair();push(p,1000,1000);before=p.b.sourceTime;push(p,1200,1080);
         check(p.a.sourceTime>before&&p.b.sourceTime===before,"old 120ms calibration seek is replaced by continuous actor recovery");
         p.b.sample(1080);
         check(p.b.sourceTime-before<=80*1.5,"single large correction also obeys speed cap");

         p=debt();p.a.sample(1120);p.b.sample(1120);
         p.a.settle(1120);p.b.settle(1120);
         check(p.b.sourceTime===1300&&p.a.sourceTime===p.b.sourceTime,"SATS settle reaches received endpoint and clears recovery");
         check(samplePair(p,1120),"paused zero-time sample remains exact after settling");
         push(p,1350,1170);
         check(samplePair(p,1170),"resume after SATS settle does not retain prior acceleration debt");
         p=debt();p.b.sample(1120);push(p,2000,2500);
         check(samplePair(p,2500),"arrival timeout resets calibration along with original timeline");
         p=debt();p.b.sample(1120);push(p,3000,1170);
         check(samplePair(p,1170),"large source/offset discontinuity keeps original reset behavior");
         p=debt();p.b.sample(1120);
         p.a.push({x:900,y:20,aimX:1000,aimY:40},1200);p.b.push({x:900,y:20,aimX:1000,aimY:40},1200);
         push(p,1500,1250,900);
         check(samplePair(p,1250),"legacy checkpoint followed by stamped data starts with no stale debt");

         clearBoundary("room");clearBoundary("epoch");clearBoundary("teleport");
         finiteRate();
      }
      private function clearBoundary(kind:String):void {
         var p:Object=debt();p.b.sample(1120);var before:Number=p.b.sourceTime;
         var s:Object=snap(1350,0,kind=="room"?"other":"fixture",kind=="epoch"?2:1);
         if(kind=="teleport")s.port={events:[{seq:1,at:1325,fromX:0,fromY:20,toX:20,toY:20,
            postX:20,postY:20,scX:40,scY:40,roomKey:"fixture",roomEpoch:1}]};
         p.b.push(s,1170);p.b.sample(1170);
         check(p.b.sourceTime-before<=55+1e-9,kind+" boundary clears old calibration acceleration");
      }
      private function finiteRate():void {
         var p:Object=debt();p.b.sample(1120);
         var actor:RemoteMotionAfter=p.b,ownerA:Object={},ownerB:Object={};
         actor.retainRate(ownerA);actor.retainRate(ownerA);actor.retainRate(ownerB);
         var stream:Object={};ProjectileFrameStreamAfter.receiveClock(stream,actor,-180,100,1120);
         var before:Number=actor.sourceTime,ok:Boolean=true,start:Number=before;
         for(var i:int=1;i<=8;i++) {
            var n:int=1120+i*25;actor.push(snap(1300+i*25),n);actor.sample(n);
            ok=ok&&near(actor.sourceTime-before,25)&&ProjectileFrameStreamAfter.sourceTime(stream,n)===actor.sourceTime;
            before=actor.sourceTime;
            if(i==2){actor.releaseRate(ownerA);actor.releaseRate(ownerA);actor.releaseRate({});}
         }
         check(ok,"finite retainRate has priority and actor/projectile share exact 1x clock with multiple owners");
         check(near(actor.sourceTime-start,200),"200ms retained native effect keeps exact source-time duration");
         actor.releaseRate(ownerB);before=actor.sourceTime;
         actor.push(snap(1525),1345);actor.sample(1345);
         check(actor.sourceTime>=before&&actor.sourceTime-before<=25*1.5,"last finite release resumes only bounded continuous playback");
         ProjectileFrameStreamAfter.detachClock(stream,1345);
         check(near(ProjectileFrameStreamAfter.sourceTime(stream,1370),actor.sourceTime+25),"shooter death detached clock preserves displayed anchor and native 1x duration");
         p=debt();actor=p.b;actor.sample(1120);actor.retainRate(ownerA);before=actor.sourceTime;
         actor.push(snap(1520),1200);actor.sample(1200);
         check(near(actor.sourceTime-before,80),"finite retained effect stays 1x through a new 140ms offset correction");
      }
   }
}
