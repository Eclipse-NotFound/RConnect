package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.events.TimerEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Timer;
   import rconnect.game.RemoteMotion;

   /** Actual AS3 motion class, fixed public push/sample/settle calls, no game. */
   public class RemoteMotionClockTestDoc extends Sprite {
      private var results:Array=[];
      private var failures:int=0;
      public function RemoteMotionClockTestDoc() {
         var timer:Timer=new Timer(100,1);
         timer.addEventListener(TimerEvent.TIMER_COMPLETE,function(e:TimerEvent):void {
            try {burst(false);burst(true);smallestBurst();ordinary();pause();legacy();}
            catch(error:Error){check(false,"uncaught",error.getStackTrace());}
            var fs:FileStream=new FileStream();
            fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
            fs.writeUTFBytes(JSON.stringify({pass:results.length-failures,fail:failures,checks:results}));fs.close();
            NativeApplication.nativeApplication.exit(failures?1:0);
         });timer.start();
      }
      private function check(ok:Boolean,name:String,value:*=null):void {
         results.push({name:name,pass:ok,value:value});if(!ok)failures++;
      }
      private function snap(stamp:int,x:Number=100):Object {
         return {x:x,y:100,aimX:x+100,aimY:100,sampleTime:stamp,
            wi:stamp>=3000?"lmg":"",aura:stamp>=3000?0x20D0FF:0};
      }
      private function burst(monotonic:Boolean):void {
         var m:RemoteMotion=new RemoteMotion(),stamp:int,now:int,got:Object;
         for(stamp=0;stamp<=3000;stamp+=200) {
            now=1000+stamp/200;m.push(snap(stamp),now);m.sample(monotonic?now:1000);
         }
         for(now=1025;now<=2515;now+=10) {
            if((now-1015)%50==0)m.push(snap(3000+now-1015),now);
            m.sample(now);
         }
         got=m.sample(2515);
         check(got.wi=="lmg" && got.aura==0x20D0FF,
            monotonic?"monotonic backlog displays latest weapon/aura within 1500ms":"original backlog displays latest weapon/aura within 1500ms",
            {wi:got.wi,aura:got.aura});
         var fresh:RemoteMotion=new RemoteMotion();fresh.push(snap(3000),1015);
         check(fresh.sample(2515).wi=="lmg","fresh stream latest state is a positive control");
      }
      private function ordinary():void {
         var m:RemoteMotion=new RemoteMotion(50),index:int=0,next:int=2015;
         var previous:Number=-1,lastReceived:Number=0,minStep:Number=0,maxStep:Number=0;
         var finite:Boolean=true,bounded:Boolean=true,forward:Boolean=true,jitter:Array=[15,30,5,25,10,0];
         for(var now:int=2000;now<=4500;now+=10) {
            while(index<45 && next<=now) {
               var stamp:int=1000+index*50;lastReceived=index*5;
               m.push(snap(stamp,lastReceived),next);index++;
               next=2000+index*50+int(jitter[index%jitter.length]);
            }
            var s:Object=m.sample(now);if(s==null)continue;
            finite=finite && isFinite(s.x) && isFinite(s.y);
            bounded=bounded && s.x>=0 && s.x<=lastReceived+.00001;
            if(previous>=0) {
               var step:Number=s.x-previous;forward=forward && step>=-.00001;
               minStep=Math.min(minStep,step);maxStep=Math.max(maxStep,step);
            }
            previous=s.x;
         }
         check(finite && bounded,"jitter positions stay finite and never extrapolate");
         check(forward,"jitter calibration never rewinds positions",{min:minStep,max:maxStep});
         check(maxStep<10,"ordinary jitter has no teleport-sized correction",maxStep);
         check(previous==lastReceived,"ordinary stream reaches the received endpoint");
         m.push(snap(3000,200),4510);var before:Number=m.sample(4510).x;
         m.push(snap(2900,150),4520);check(m.sample(4520).x>=before,"older source frame is ignored");
         m.push(snap(3250,1000),4530);check(m.sample(4530).x==1000,"native teleport threshold still settles immediately");
      }
      private function smallestBurst():void {
         var firstStale:int=0,values:Array=[];
         for(var count:int=2;count<=16;count++) {
            var m:RemoteMotion=new RemoteMotion(),lastStamp:int=(count-1)*200;
            var end:int=1000+count-1,now:int,k:int,s:Object;
            for(k=0;k<count;k++) {
               s=snap(k*200);s.wi=k==count-1?"lmg":"";s.aura=k==count-1?0x20D0FF:0;
               m.push(s,1000+k);m.sample(1000+k);
            }
            for(now=end+10;now<=end+1500;now+=10) {
               if((now-end)%50==0) {
                  s=snap(lastStamp+now-end);s.wi="lmg";s.aura=0x20D0FF;m.push(s,now);
               }
               m.sample(now);
            }
            s=m.sample(end+1500);values.push({count:count,wi:s.wi,aura:s.aura});
            if(s.wi!="lmg" && firstStale==0)firstStale=count;
         }
         check(firstStale==0,"backlogs from 2 to 16 frames meet the same 1500ms weapon deadline",
            {firstStaleCount:firstStale,cases:values});
      }
      private function pause():void {
         var m:RemoteMotion=new RemoteMotion();m.push(snap(0,0),1000);m.push(snap(50,5),1050);
         m.sample(1050);check(m.settle(1050).x==5,"pause closes at latest received endpoint");
         m.push(snap(100,10),1100);check(m.settle(1100).x==10,"pause accepts final in-flight endpoint");
         check(m.settle(1700).x==10,"pause holds without extrapolation");
         m.push(snap(700,20),1700);check(m.sample(1700).x>=10,"resume cannot replay pre-pause position");
         check(m.sample(1900).x<=20,"resume remains bounded by latest received endpoint");
      }
      private function legacy():void {
         var m:RemoteMotion=new RemoteMotion();m.push({x:0,y:0,aimX:10,aimY:0},1000);
         m.push({x:10,y:0,aimX:20,aimY:0},1050);
         check(m.sample(1075).x==5,"unstamped endpoint interpolation unchanged");
         check(m.settle(1075).x==10,"unstamped pause settle unchanged");
      }
   }
}
