package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.ProjectilePlayback;

   /** Deterministic component replay. Compile against this candidate's src;
    * run in an isolated build folder. It does not load or operate the game. */
   public class ProjectilePlaybackReplay extends Sprite {
      private var checks:Array=[];
      public function ProjectilePlaybackReplay() {
         var result:Object={passed:false,checks:checks};
         try {run();result.passed=true;}catch(error:*){result.error=String(error);}
         var output:FileStream=new FileStream();
         output.open(File.applicationDirectory.resolvePath("projectile-playback-result.json"),FileMode.WRITE);
         output.writeUTFBytes(JSON.stringify(result));output.close();
         trace(JSON.stringify(result));NativeApplication.nativeApplication.exit(result.passed?0:1);
      }
      private function ok(condition:Boolean,name:String):void {if(!condition)throw new Error(name);checks.push(name);}
      private function near(a:Number,b:Number):Boolean {return Math.abs(a-b)<.00001;}
      private function frame(at:Number,x:Number,sx:Number=1,f:int=1):Object {
         return {at:at,x:x,y:x/2,rot:0,sx:sx,sy:1,a:1,f:f,ls:sx,lf:f};
      }
      private function run():void {
         var flight:Object={cls:"visualBullet",spring:1,frames:[frame(100,0),frame(133,100),frame(166,200)],end:200};
         var copy:String=JSON.stringify(flight),reuse:Object={},p:Object=ProjectilePlayback.sample(flight,116.5,reuse);
         ok(p===reuse && near(p.x,50)&&near(p.y,25),"ordinary intermediate segment, reusable output");
         ok(ProjectilePlayback.sample(flight,99)==null,"before first visible source frame stays hidden");
         ok(near(ProjectilePlayback.sample(flight,190).x,200),"no extrapolation or invented terminal movement");
         ok(ProjectilePlayback.sample(flight,200)==null,"native end removes exactly at boundary");
         ok(JSON.stringify(flight)==copy,"source history remains immutable");

         for each(var cls:String in ["visbullightning","visbullightning2","visbulflame","visbulflame2","visbuldflame","visbullaser"]){
            var special:Object={cls:cls,spring:cls=="visbullaser"?2:1,
               frames:[frame(100,0,1,2),frame(133,100,3,3)],end:166};
            p=ProjectilePlayback.sample(special,116.5);
            ok(near(p.x,50)&&near(p.sx,2)&&near(p.ls,2)&&p.f==2&&p.lf==2,cls+" moves and scales between known frames, authored frame retained");
         }
         var flip:Object={frames:[frame(100,0,1),frame(133,100,-1)],end:166};
         ok(ProjectilePlayback.sample(flip,116.5).sx==1,"authored flip does not interpolate through zero");

         var channel:Object={records:{}},one:Object={vis:null,s:{frames:[frame(100,0),frame(133,100)],end:166},channel:channel},
             two:Object={vis:null,s:{frames:[frame(150,0),frame(183,100)],end:216},channel:channel};
         channel.records.one=one;channel.records.two=two;
         // Actual ProjectileVisuals ticks active records backwards: newest first.
         var t:Number=ProjectilePlayback.time(two,250,1000);
         ok(t==100&&ProjectilePlayback.sample(two.s,t)==null,"late burst newest-first preserves original shot spacing");
         t=ProjectilePlayback.time(one,250,1000);
         ok(t==100&&ProjectilePlayback.sample(one.s,t).x==0,"short expired shot is visible once on first render");
         one.vis={};
         ok(ProjectilePlayback.time(one,9000,1033)==133,"late recovery follows display time, independent of moving actor cursor");
         ok(ProjectilePlayback.time(two,9000,1050)==150,"second late shot starts at original fifty-ms separation");
         ok(ProjectilePlayback.sample(one.s,ProjectilePlayback.time(one,9000,1066))==null,"late shot retains original duration");
         ok(ProjectilePlayback.time(one,250,1100)==200,"duplicate or older packet cannot restart a late replay");
         // Mirror the pause offset adjustment performed by ProjectileVisuals.
         var frozen:Number=ProjectilePlayback.time(two,9000,1050);two.lateOffset+=1000;
         ok(ProjectilePlayback.time(two,9000,2050)==frozen,"pause duration shifts recovery offset without consuming flight");
         ok(ProjectilePlayback.time(two,NaN,2083)==183,"recovered flight continues when shooter clock is absent");

         var shown:Object={vis:{},s:{frames:[frame(100,0)],end:133},channel:{records:{}}};
         ok(ProjectilePlayback.time(shown,300,1000)==300,"already shown expired flight is not restarted");
         var invisible:Object={vis:null,s:{frames:[],end:133},channel:{records:{}}};invisible.channel.records.one=invisible;
         ok(ProjectilePlayback.time(invisible,300,1000)==300,"empty invisible helper never receives a replay");
      }
   }
}
