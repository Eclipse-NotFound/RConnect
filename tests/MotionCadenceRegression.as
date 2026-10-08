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
      }
      private static function position(t:Number):Number {return 200+45*Math.sin(t*Math.PI*2/1000);}
   }
}
