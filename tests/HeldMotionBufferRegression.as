package {
   import rconnect.game.RemoteMotion;
   /** A long native frame is followed by regular sends. Real-time recovery,
    * bounded positions and pause continuity are public behavioral contracts. */
   public final class HeldMotionBufferRegression {
      public static function run(check:Function):void {
         var held:RemoteMotion=RemoteMotion.held(),ordinary:RemoteMotion=new RemoteMotion(50);
         var stamps:Array=[0,50,100,150,200];
         for(var stamp:int=400;stamp<=1600;stamp+=50)stamps.push(stamp);
         var index:int=0,lastReceived:Number=0,previous:Number=0,maxStep:Number=0;
         var finite:Boolean=true,bounded:Boolean=true,forward:Boolean=true;
         for(var now:int=1000;now<=2400;now+=10) {
            while(index<stamps.length && 1000+int(stamps[index])<=now) {
               stamp=int(stamps[index++]);lastReceived=stamp*.05;
               var snap:Object={x:lastReceived,y:100,sampleTime:stamp};
               held.push(snap,1000+stamp);ordinary.push(snap,1000+stamp);
            }
            var shown:Object=held.sample(now);ordinary.sample(now);
            finite=finite && isFinite(shown.x) && isFinite(shown.y);
            bounded=bounded && shown.x>=0 && shown.x<=lastReceived+.00001;
            forward=forward && shown.x>=previous-.00001;
            maxStep=Math.max(maxStep,shown.x-previous);previous=shown.x;
         }
         var lag:Number=1400-held.sourceTime,oldLag:Number=1400-ordinary.sourceTime;
         check(finite && bounded,"held buffer never extrapolates during a missing source frame");
         check(forward && maxStep<5,"held clock recovers continuously without a position jump max="+maxStep);
         check(lag<=160,"held drag recovers within 160ms one second after a 200ms native-frame gap actual="+lag+" ordinary="+oldLag);
         check(held.settle(2400).x==lastReceived,"held pause settles the final received point");
         held.push({x:75,y:95,sampleTime:1500},2500);
         check(held.settle(2500).x==75 && held.settle(3100).x==75,"held pause accepts and retains a late endpoint");
         held.push({x:80,y:90,sampleTime:2200},3200);
         var resumed:Object=held.sample(3200);
         check(resumed.x>=75 && resumed.x<=80,"held resume cannot rewind or pass the newest endpoint");
      }
   }
}
