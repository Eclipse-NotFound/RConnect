package {
   import rconnect.game.RemoteMotion;

   /** Repeatable arrival ordering: pause before the lifted endpoint reaches
    * the display cursor. The legacy fallback is the former bridge call and
    * keeps this same driver usable as a negative control. */
   public class RemoteMotionPauseRegression {
      public static function run(check:Function):void {
         var m:RemoteMotion=new RemoteMotion(200),t:int,s:Object;
         for(t=100;t<=720;t+=10) {
            if((t-100)%200==0)m.push({x:180,y:t<700?319:200,stay:true,sampleTime:t-100},t);
            s=m.sample(t);
         }
         check(s.y>280,"pause ordering begins before the lifted pose reaches the display cursor");
         s=paused(m,720);
         check(s.y==200 && s.stay===true,"pause settles an already received lifted endpoint");
         for(t=900;t<=3900;t+=200) {
            m.push({x:180,y:200,stay:true,sampleTime:t-100},t);
            s=paused(m,720);
         }
         check(s.y==200 && s.stay===true,"late pause packets preserve the lifted endpoint for over 1500ms");
         s=m.sample(4200);
         check(s.y==200,"resume never rewinds to the buffered ground pose");
         var previous:Number=Number(s.y),monotone:Boolean=true;
         for(t=4300;t<=4700;t+=200) {
            m.push({x:180,y:Math.min(319,200+(t-4100)*.2),stay:t>=4700,sampleTime:t-100},t);
            s=m.sample(t);
            monotone=monotone && s.y>=previous && s.y<=319;previous=Number(s.y);
         }
         check(monotone && m.sample(9000).y==319,"resumed falling stays within received positions and reaches the floor");
         m=new RemoteMotion(200);m.push({x:0,y:319,stay:true},0);
         m.push({x:180,y:200,stay:false},100);s=paused(m,100);
         check(s.x==180 && s.y==200 && s.stay===false,"unstamped pause settles the received endpoint and its state");
      }
      private static function paused(m:RemoteMotion,at:int):Object {
         var settle:Function="settle" in Object(m)?Object(m)["settle"] as Function:null;
         return settle!=null?settle(at):m.sample(at);
      }
   }
}
