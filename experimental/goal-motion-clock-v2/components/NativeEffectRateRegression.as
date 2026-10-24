package {
   import rconnect.game.RemoteMotion;

   /** A real-time clip shares the actor clock. Packet jitter may change the
    * desired buffer, but must not change the clip's playback rate. */
   public class NativeEffectRateRegression {
      public static function run(check:Function):void {
         var m:RemoteMotion=new RemoteMotion(),a:Object={},b:Object={};
         m.push({x:0,y:100,sampleTime:0},1000);m.sample(1000);
         m.push({x:20,y:100,sampleTime:200},1200);m.sample(1200);
         m.retainRate(a);m.retainRate(a);m.retainRate(b);
         var initial:Number=m.sourceTime,previous:Number=initial,steady:Boolean=true,bounded:Boolean=true;
         for(var now:int=1250;now<=1700;now+=50) {
            var stamp:int=now-1000;
            m.push({x:stamp/10,y:100,sampleTime:stamp},now);
            var sample:Object=m.sample(now);
            steady=steady && Math.abs(m.sourceTime-previous-50)<.0001;
            bounded=bounded && sample.x>=0 && sample.x<=stamp/10;
            previous=m.sourceTime;
            if(now==1400){m.releaseRate(a);m.releaseRate(a);}
         }
         check(steady && Math.abs(m.sourceTime-initial-500)<.0001,
            "overlapping native effects preserve 500ms playback despite changing packet gaps");
         check(bounded,"paced actor remains inside received positions");
         m.releaseRate(b);m.releaseRate(b);
         m.push({x:75,y:100,sampleTime:750},1750);m.sample(1750);
         check(m.sourceTime>previous+50 && m.sourceTime<=750,
            "finishing the final effect restores gradual recovery; duplicate release does not pin the clock");
         m.retainRate(a);
         check(m.settle(1750).x==75,"shared pause closes paced effects at the received endpoint");
         m.push({x:80,y:95,sampleTime:800},1800);
         check(m.settle(1800).x==80 && m.settle(2300).x==80,"paused paced actor retains late endpoint without extrapolation");
         m.releaseRate(a);
         m.push({x:85,y:90,sampleTime:1300},2300);sample=m.sample(2300);
         check(sample.x>=80 && sample.x<=85,"paced effect cleanup and resume never rewind past the pause endpoint");
      }
   }
}
