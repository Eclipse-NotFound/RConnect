package {
   import rconnect.game.RemoteMotion;

   /** Deterministic behavioral checks, not a native performance qualification. */
   public class ClockDebtRegression {
      public static function run(check:Function):void {
         cumulative(check,0);cumulative(check,1);cumulative(check,2);
         retained(check);rejectedPackets(check);lifecycle(check);largeCorrection(check);
         recorded(check,RecordedMotionInputs.BASELINE,"baseline");
         recorded(check,RecordedMotionInputs.CANDIDATE,"candidate");
      }
      private static function motion(policy:int):RemoteMotion {
         if(policy==1)return RemoteMotion.held();
         if(policy==2)return RemoteMotion.enemy();
         return new RemoteMotion();
      }
      private static function point(stamp:Number):Object {
         return {sampleTime:stamp,x:300+stamp*.05,y:640};
      }
      private static function close(a:Number,b:Number):Boolean {return Math.abs(a-b)<.00001;}
      private static function stampAt(now:int):Number {
         return now<=6600?(now-5000)*2:3200+now-6600;
      }
      private static function cumulative(check:Function,policy:int):void {
         var m:RemoteMotion=motion(policy),same:Boolean=true,bounded:Boolean=true,received:Boolean=true;
         m.push(point(0),5000);var lastX:Number=m.sample(5000).x,lastClock:Number=m.sourceTime;
         var latest:Number=0,maxAdvance:Number=0,maxStep:Number=0,lagAtDeadline:Number=NaN;
         for(var now:int=5010;now<=7100;now+=10) {
            var shown:Object=m.sample(now),clock:Number=m.sourceTime,x:Number=shown.x;
            var advance:Number=clock-lastClock,step:Number=x-lastX;
            maxAdvance=Math.max(maxAdvance,advance);maxStep=Math.max(maxStep,step);
            bounded=bounded&&advance>=-.00001&&advance<=20.00001&&step>=-.00001&&step<=1.00001;
            if((now-5000)%50==0) {
               latest=stampAt(now);m.push(point(latest),now);
               shown=m.sample(now);
               same=same&&close(m.sourceTime,clock)&&close(Number(shown.x),x);
               shown=m.sample(now);same=same&&close(m.sourceTime,clock)&&close(Number(shown.x),x);
            }
            // The 32 calibrations each improve offset by 50ms (1600ms total).
            // No frame may hide that debt in a >2x jump. By 50ms after the
            // final calibration the current 125/100ms buffer must be restored.
            if(now==6650)lagAtDeadline=latest-m.sourceTime;
            received=received&&m.sourceTime<=latest+.00001&&Number(shown.x)>=299.99999
               &&Number(shown.x)<=300+latest*.05+.00001;
            lastClock=m.sourceTime;lastX=Number(shown.x);
         }
         check(same,"calibration32 policy="+policy+" push/repeated sample never changes same-time clock or position");
         check(bounded,"calibration32 policy="+policy+" monotone clock <=20ms and line step <=1px per10ms max="+maxAdvance+"/"+maxStep);
         check(received,"calibration32 policy="+policy+" remains within received positions and source endpoint");
         check(lagAtDeadline<=(policy==0?125.00001:100.00001),"calibration32 policy="+policy+" restores current buffer by50ms after last correction lag="+lagAtDeadline);
      }
      private static function retained(check:Function):void {
         var m:RemoteMotion=new RemoteMotion(),a:Object={},b:Object={};
         m.push(point(0),5000);m.sample(5000);var initial:Number=m.sourceTime;
         m.retainRate(a);m.retainRate(b);
         for(var now:int=5010;now<=6600;now+=10) {
            m.sample(now);if((now-5000)%50==0)m.push(point(stampAt(now)),now);
         }
         check(close(m.sourceTime-initial,1600),"calibration debt never accelerates a retained finite effect for1600ms");
         m.releaseRate(a);m.releaseRate(a);var before:Number=m.sourceTime;
         for(now=6610;now<=6800;now+=10) {
            m.sample(now);if((now-5000)%50==0)m.push(point(stampAt(now)),now);
         }
         check(close(m.sourceTime-before,200),"remaining finite-effect owner retains exact1x despite1600ms debt");
         m.releaseRate(b);m.releaseRate(b);before=m.sourceTime;
         var bounded:Boolean=close(m.sample(6800).x,300+Math.max(0,before)*.05)&&close(m.sourceTime,before);
         for(now=6810;now<=8800;now+=10) {
            m.sample(now);bounded=bounded&&m.sourceTime>=before-.00001&&m.sourceTime-before<=20.00001;
            before=m.sourceTime;if((now-5000)%50==0)m.push(point(stampAt(now)),now);
         }
         check(bounded,"release repays retained debt only on later frames, never above2x or backwards");
         check(m.latestSampleTime-m.sourceTime<=125.00001,"retained1600ms debt recovers by2000ms after release lag="+(m.latestSampleTime-m.sourceTime));
      }
      private static function rejectedPackets(check:Function):void {
         var a:RemoteMotion=new RemoteMotion(),b:RemoteMotion=new RemoteMotion();
         for(var now:int=5000;now<=5500;now+=50) {
            a.push(point(stampAt(now)),now);b.push(point(stampAt(now)),now);a.sample(now);b.sample(now);
         }
         var before:Number=a.sourceTime,x:Number=a.currentSample.x;
         a.push(point(1000),5500);a.push(point(999),5500);a.sample(5500);
         check(close(a.sourceTime,before)&&close(a.currentSample.x,x),"duplicate/out-of-order packets do not seek the current frame");
         var same:Boolean=true;
         for(now=5510;now<=6000;now+=10) {
            a.sample(now);b.sample(now);same=same&&close(a.sourceTime,b.sourceTime)&&close(a.currentSample.x,b.currentSample.x);
            if((now-5000)%50==0){a.push(point(stampAt(now)),now);b.push(point(stampAt(now)),now);}
         }
         check(same,"duplicate/out-of-order packets cannot inflate later calibration repayment");
      }
      private static function lifecycle(check:Function):void {
         var m:RemoteMotion=new RemoteMotion(),owner:Object={};m.retainRate(owner);
         for(var now:int=5000;now<=6600;now+=50){m.push(point(stampAt(now)),now);m.sample(now);}
         m.releaseRate(owner);m.settle(6600);var same:Boolean=close(m.sourceTime,3200)&&close(m.currentSample.x,460);
         m.sample(6600);m.sample(6590);same=same&&close(m.sourceTime,3200)&&close(m.currentSample.x,460);
         var previous:Number=m.sourceTime;
         for(now=6610;now<=7000;now+=10) {
            if((now-6600)%50==0)m.push(point(stampAt(now)),now);
            m.sample(now);same=same&&m.sourceTime>=previous&&m.sourceTime<=m.latestSampleTime;
            previous=m.sourceTime;
         }
         check(same,"settle closes debt at received endpoint; repeated/past samples and resume never replay old positions");
         // A real idle/reset discontinuity is explicitly outside the no-seek
         // packet-calibration contract. It must not inherit old debt.
         m.push(point(20),9000);var fresh:RemoteMotion=new RemoteMotion();fresh.push(point(20),9000);
         same=true;
         for(now=9000;now<=9300;now+=10) {
            if(now>9000&&(now-9000)%50==0){m.push(point(20+now-9000),now);fresh.push(point(20+now-9000),now);}
            m.sample(now);fresh.sample(now);same=same&&close(m.sourceTime,fresh.sourceTime)&&close(m.currentSample.x,fresh.currentSample.x);
         }
         check(same,"idle continuity reset starts a fresh clock without inherited debt");
      }
      private static function largeCorrection(check:Function):void {
         var m:RemoteMotion=new RemoteMotion();
         for(var now:int=1000;now<=1200;now+=50){m.push(point(now-1000),now);m.sample(now);}
         m.sample(1250);var before:Number=m.sourceTime,x:Number=m.currentSample.x;
         m.push(point(450),1250);m.sample(1250);
         check(close(before,m.sourceTime)&&close(x,m.currentSample.x),"single200ms calibration also waits for next advancing sample");
         var bounded:Boolean=true;
         for(now=1260;now<=1500;now+=10) {
            m.sample(now);bounded=bounded&&m.sourceTime>=before-.00001&&m.sourceTime-before<=20.00001;before=m.sourceTime;
            if((now-1250)%50==0)m.push(point(450+now-1250),now);
         }
         check(bounded,"single200ms calibration has no >2x cross-frame repayment");
         check(m.latestSampleTime-m.sourceTime<=250.00001,"single200ms calibration reaches original maximum250ms buffer within250ms");
      }
      private static function recorded(check:Function,input:Object,label:String):void {
         var events:Array=[],row:Array;
         for each(row in input.arrivals)events.push({at:row[0],kind:0,row:row});
         // Recorded RENDER event time is a deterministic replay clock here.
         // It is NOT asserted to equal production presentationTime().
         for each(row in input.displays)events.push({at:row[0],kind:1,row:row});
         events.sort(function(a:Object,b:Object):Number{return a.at==b.at?a.kind-b.kind:a.at-b.at;});
         var m:RemoteMotion=new RemoteMotion(),started:Boolean=false,sampled:Boolean=false;
         var same:Boolean=true,bounded:Boolean=true,received:Boolean=true,lastAt:int=0,count:int=0;
         var lastClock:Number=0,lastX:Number=0,lastY:Number=0,minY:Number=Infinity,maxY:Number=-Infinity;
         var maxSlope:Number=0,previousRow:Array=null,latest:Number=0,maxStep:Number=0;
         for each(row in input.arrivals) {
            if(previousRow!=null&&Number(row[1])>Number(previousRow[1]))
               maxSlope=Math.max(maxSlope,Math.abs(Number(row[3])-Number(previousRow[3]))/(Number(row[1])-Number(previousRow[1])));
            if(previousRow==null||Number(row[1])>Number(previousRow[1]))previousRow=row;
         }
         for each(var event:Object in events) {
            row=event.row;
            if(event.kind==0) {
               m.push({sampleTime:row[1],x:row[2],y:row[3],dy:row[5],stay:Boolean(row[6])},int(row[0]));
               latest=Number(row[1]);minY=Math.min(minY,Number(row[3]));maxY=Math.max(maxY,Number(row[3]));started=true;
               if(sampled) {
                  var held:Object=m.sample(lastAt);
                  same=same&&close(m.sourceTime,lastClock)&&close(Number(held.x),lastX)&&close(Number(held.y),lastY);
               }
            } else if(started) {
               var shown:Object=m.sample(int(row[0])),clock:Number=m.sourceTime;
               if(sampled) {
                  var dt:Number=Number(row[0])-lastAt,advance:Number=clock-lastClock;
                  var distance:Number=Math.abs(Number(shown.y)-lastY);maxStep=Math.max(maxStep,distance);
                  bounded=bounded&&advance>=-.00001&&advance<=2*dt+.00001;
                  // Monotone cubic tangents cannot exceed 3x the largest
                  // input slope; the clock is independently bounded by2x.
                  received=received&&distance<=maxSlope*3*2*dt+.00001;
               }
               received=received&&clock<=latest+.00001&&close(Number(shown.x),300)
                  &&Number(shown.y)>=minY-.00001&&Number(shown.y)<=maxY+.00001;
               lastAt=int(row[0]);lastClock=clock;lastX=Number(shown.x);lastY=Number(shown.y);sampled=true;count++;
            }
         }
         check(same,"recorded "+label+" slice packets cannot move last sampled frame");
         check(count>=50&&bounded,"recorded "+label+" slice RENDER cadence has monotone <=2x source-clock advance frames="+count);
         check(received,"recorded "+label+" slice stays inside received endpoints and bounded cross-frame displacement maxYStep="+maxStep);
         check(latest-m.sourceTime<=250.00001,"recorded "+label+" reinitialized slice ends within original250ms buffer lag="+(latest-m.sourceTime));
      }
   }
}
