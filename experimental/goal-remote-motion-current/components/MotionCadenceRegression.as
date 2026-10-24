package {
   import rconnect.game.RemoteMotion;
   import rconnect.core.Log;

   /** Dense display sampling around 20 Hz packet boundaries. The transmitted
    * arc is continuous; a receiver must not introduce sharp speed changes. */
   public class MotionCadenceRegression {
      public static function run(check:Function):void {
         var motion:RemoteMotion=new RemoteMotion(50),previous:Number=NaN,velocity:Number=NaN;
         var maxEdge:Number=0,edges:int=0,bounded:Boolean=true;
         for(var now:int=0;now<=3500;now++) {
            if(now%50==0)motion.push({x:position(now),y:100,sampleTime:now},now);
            var sample:Object=motion.sample(now),x:Number=Number(sample.x);
            if(now>600) {
               var source:Number=now-100,a:int=int(source/50)*50,b:int=a+50;
               bounded=bounded && x>=Math.min(position(a),position(b))-.001 && x<=Math.max(position(a),position(b))+.001;
               var nextVelocity:Number=x-previous;
               if(now%50==1 && isFinite(velocity)){maxEdge=Math.max(maxEdge,Math.abs(nextVelocity-velocity));edges++;}
               velocity=nextVelocity;
            }
            previous=x;
         }
         Log.d("CONTINUITY CADENCE "+JSON.stringify({edges:edges,maxVelocityEdge:maxEdge,bounded:bounded}));
         check(edges>=50&&bounded,"20Hz displayed curve stays inside received positions");
         check(maxEdge<=.01,"20Hz packet boundary introduces no abrupt speed change actual="+maxEdge);
         bodyTimeline(check);
         enemyRecovery(check);
      }
      private static function enemyRecovery(check:Function):void {
         var motion:RemoteMotion=RemoteMotion.enemy(),queued:Array=[];
         var previous:Number=NaN,latest:int=0,recovered:int=0,maxRate:Number=0;
         var bounded:Boolean=true,forward:Boolean=true;
         // Regular 20 Hz source, a 300 ms delivery stall, then one socket burst.
         // Keep sampling during the stall exactly as a live receiver does.
         for(var now:int=0;now<=2400;now+=10) {
            if(now%50==0)queued.push(pose(now,(now*.03)%24));
            if(now<800||now>=1100)while(queued.length) {
               var incoming:Object=queued.shift();latest=incoming.sampleTime;motion.push(incoming,now);
            }
            motion.sample(now);
            var cursor:Number=motion.sourceTime;
            bounded=bounded&&cursor<=latest+.001;
            if(isFinite(previous)) {
               forward=forward&&cursor>=previous-.001;
               if(now>=1100)maxRate=Math.max(maxRate,(cursor-previous)/10);
            }
            if(now>=1100&&latest-cursor<=110&&recovered==0)recovered=now;
            previous=cursor;
         }
         Log.d("ENEMY BUFFER RECOVERY "+JSON.stringify({recoveredAfter:recovered-1100,maxRate:maxRate,bounded:bounded,forward:forward}));
         check(recovered>0&&recovered-1100<=650,"enemy recovers a 300ms delivery stall within 650ms actual="+(recovered-1100));
         check(bounded&&forward&&maxRate<=1.50001,"enemy recovery is monotonic, bounded and at most 1.5x speed");
         motion=RemoteMotion.enemy();var effect:Object={};motion.retainRate(effect);
         for(now=0;now<=500;now+=50){motion.push(pose(now,(now*.03)%24),now);motion.sample(now);}
         previous=motion.sourceTime;
         motion.push(pose(800,0),800);motion.sample(600);
         check(Math.abs(motion.sourceTime-previous-100)<.001,"finite effect keeps its original playback duration during recovery");
         motion.releaseRate(effect);
      }
      private static function pose(stamp:int,frame:Number,loop:Boolean=true):Object {
         return {x:stamp*.1,y:100,sampleTime:stamp,visual:{anim:"walk",pose:{ai:1,
            blit:{f:frame,df:1,st:false,stab:false,first:0,length:24,ret:0,loop:loop,reverse:false}}}};
      }
      private static function bodyTimeline(check:Function):void {
         var motion:RemoteMotion=RemoteMotion.enemy(),matches:Boolean=true,observed:int=0;
         for(var now:int=0;now<=2500;now+=10) {
            if(now%50==0)motion.push(pose(now,(now*.03)%24),now);
            var sample:Object=motion.sample(now);
            if(now<200)continue;
            var expected:Number=(motion.sourceTime*.03)%24;
            matches=matches&&sample.bodyPose!=null&&Math.abs(Number(sample.bodyPose.blit.f)-expected)<.001;
            ++observed;
         }
         check(observed>=200&&matches,"walking phase follows received source time through loop boundaries");
         var final:Object=motion.settle(2600),frame:Number=Number(final.bodyPose==null?NaN:final.bodyPose.blit.f);
         sample=motion.sample(3500);
         check(sample.bodyPose!=null&&sample.bodyPose.blit.f==frame,"body stops at last received frame when packets stop");
         motion=RemoteMotion.enemy();motion.push(pose(0,10,false),0);motion.push(pose(50,0,false),50);
         sample=motion.sample(100);
         check(sample.bodyPose!=null&&sample.bodyPose.blit.f==10,"same-label attack restart holds old pose until its source boundary");
         sample=motion.settle(120);
         check(sample.bodyPose!=null&&sample.bodyPose.blit.f==0,"pause settles exactly at restarted native frame");
         motion=RemoteMotion.enemy();motion.push({x:0,y:100,sampleTime:0,visual:{anim:"walk",pose:{blit:{f:3,df:1}}}},0);
         check(motion.sample(10).bodyPose==null,"legacy pose without phase metadata keeps existing playback path");
      }
      private static function position(t:Number):Number {return 200+45*Math.sin(t*Math.PI*2/1000);}
   }
}
