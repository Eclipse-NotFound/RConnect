package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.RemoteMotion;

   /** Fixed input times, not a benchmark. Calls the unchanged production API. */
   public class MotionContinuityChecks extends Sprite {
      private var checks:Array=[];
      private var failures:int=0;
      public function MotionContinuityChecks() {
         try {
            calibration(false);calibration(true);
            lateCurve(false);lateCurve(true);
            HeldMotionBufferRegression.run(check);
            DropMotionBurstRegression.run(check);
            NativeEffectRateRegression.run(check);
            MotionCadenceRegression.run(check);
            ClockDebtRegression.run(check);
         } catch(e:Error){check(false,"uncaught "+e.getStackTrace());}
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({assertions:checks,failed:failures,passed:failures==0,gameLoaded:false}));
         stream.close();NativeApplication.nativeApplication.exit(failures?1:0);
      }
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failures++;
      }
      private function calibration(held:Boolean):void {
         var motion:RemoteMotion=held?RemoteMotion.held():new RemoteMotion();
         for(var now:int=1030;now<=1630;now+=10) {
            if((now-1030)%50==0)motion.push({x:(now-1030)*.8,y:100,sampleTime:now-1030},now);
            motion.sample(now);
         }
         var before:Number=motion.sample(1655).x,clock:Number=motion.sourceTime;
         // A fresh packet's latency improves by only 25ms. No display time has
         // elapsed between these calls, so it cannot move the visible actor.
         motion.push({x:650*.8,y:100,sampleTime:650},1655);
         var delta:Number=motion.sample(1655).x-before;
         check(Math.abs(delta)<.0001,(held?"held":"player")+" latency calibration does not seek visible position at same time delta="+delta);
         check(motion.sourceTime==clock,(held?"held":"player")+" small clock calibration is absorbed by playback, not an immediate seek");
      }
      private function lateCurve(drop:Boolean):void {
         var motion:RemoteMotion=drop?new RemoteMotion(50,true):RemoteMotion.held();
         motion.push({x:0,y:200,sampleTime:0},1000);
         if(!drop)motion.sample(1000);
         motion.push({x:40,y:160,sampleTime:50},drop?1000:1050);
         if(drop)motion.sample(1000);
         // Reach the interior of a known interval before its following point
         // arrives. A jump arc and a dragged object's reversal share this case.
         var at:int=drop?1025:1100;
         var before:Object=motion.sample(at),x:Number=before.x,y:Number=before.y,clock:Number=motion.sourceTime;
         motion.push({x:40,y:180,sampleTime:100},at);
         var after:Object=motion.sample(at);
         var delta:Number=Math.abs(Number(after.x)-x)+Math.abs(Number(after.y)-y);
         check(Math.abs(motion.sourceTime-clock)<.0001,"future arc point alone does not advance display time drop="+drop);
         check(delta<.0001,"future arc point does not reshape a partly displayed segment drop="+drop+" delta="+delta);
      }
   }
}
