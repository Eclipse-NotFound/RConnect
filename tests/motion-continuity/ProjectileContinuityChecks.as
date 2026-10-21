package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.ProjectileVisuals;
   public class ProjectileContinuityChecks extends Sprite {
      private var checks:Array=[],failures:int=0;
      public function ProjectileContinuityChecks() {
         try {
            run("visualBullet",1,true);run("visbullightning",1,true);run("visbullightning2",1,true);
            run("visbullightning",2,false);run("visbulflame",1,false);
            incremental();
         }catch(e:Error){check(false,"uncaught "+e.getStackTrace());}
         var s:FileStream=new FileStream();s.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         s.writeUTFBytes(JSON.stringify({pass:checks.length-failures,fail:failures,checks:checks,gameLoaded:false}));s.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }
      private function check(ok:Boolean,label:String):void {checks.push({pass:ok,label:label});if(!ok)failures++;}
      private function incremental():void {
         var visual:ProjectileVisuals=new ProjectileVisuals(),clock:MotionFixtureClock=new MotionFixtureClock();
         var layer:Sprite=new Sprite(),loc:Object={},owner:Object={loc:loc};
         var main:Object={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            return n=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:Sprite;
         }}}};
         function point(t:int):Object{return {at:t,x:(t-1000)*2,y:20,rot:0,sx:1,sy:1,a:1,f:1,ls:1,lf:1};}
         function packet(points:Array,end:int=0):Array {return [{id:"incremental",variant:0,stream:1,sampleTime:1100,
            events:[{seq:1,flight:{cls:"visbullightning",spring:1,x:0,y:20,rot:0,blend:"normal",frames:points,delta:true,end:end}}]}];}
         visual.receive(owner,packet([point(1000),point(1050)]),main,true,clock);
         clock.time=1025;visual.tick(loc,2000);
         var first:Boolean=layer.numChildren==1&&layer.getChildAt(0).x==50;
         visual.receive(owner,packet([point(1100)]),main,true,clock);
         clock.time=1075;visual.tick(loc,2050);
         check(first&&layer.numChildren==1&&layer.getChildAt(0).x==150,"incremental trajectory keeps earlier bracketing points");
         visual.receive(owner,packet([point(1050),point(1100)]),main,true,clock);
         clock.time=1075;visual.tick(loc,2050);
         check(layer.numChildren==1&&layer.getChildAt(0).x==150,"duplicate incremental packet neither respawns nor rewinds");
         visual.receive(owner,packet([],1150),main,true,clock);
         clock.time=1125;visual.tick(loc,2100);
         check(layer.numChildren==1&&layer.getChildAt(0).x==200,"empty ending keeps received flight and never extrapolates");
         clock.time=1150;visual.tick(loc,2150);
         check(layer.numChildren==0,"incremental ending retires the original projectile exactly once");
         visual.reset();
      }
      private function run(name:String,spring:int,continuous:Boolean):void {
         var visual:ProjectileVisuals=new ProjectileVisuals(),clock:MotionFixtureClock=new MotionFixtureClock();
         var layer:Sprite=new Sprite(),loc:Object={},owner:Object={loc:loc};
         var main:Object={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            return n=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:Sprite;
         }}}};
         var frames:Array=[];
         for(var i:int=0;i<4;i++)frames.push({at:1000+i*50,x:100+i*125,y:50+i*25,rot:10,sx:1,sy:1,a:1,f:1,ls:1,lf:1});
         var flight:Object={cls:name,x:100,y:50,spring:spring,rot:0,blend:"normal",frames:frames,end:1200};
         visual.receive(owner,[{id:"test",variant:0,stream:1,sampleTime:1150,events:[{seq:1,flight:flight}]}],main,true,clock);
         var good:Boolean=true,moved:int=0,last:Number=NaN;
         for(i=0;i<=15;i++) {
            clock.time=1000+i*10;visual.tick(loc,2000+i*10);
            var v:DisplayObject=layer.numChildren?layer.getChildAt(0):null;
            var step:Number=continuous?i*10:Math.floor(i/5)*50;
            good=good&&v!=null&&Math.abs(v.x-(100+step*2.5))<.001&&Math.abs(v.y-(50+step*.5))<.001;
            if(v!=null){if(isFinite(last)&&v.x!=last)moved++;last=v.x;}
         }
         check(good,name+" spring="+spring+" confirmed segment position continuous="+continuous+" movingSteps="+moved);
         clock.time=1199;visual.tick(loc,2199);
         check(layer.numChildren==1&&layer.getChildAt(0).x==475,name+" no extrapolation beyond latest sample");
         clock.time=1200;visual.tick(loc,2200);
         check(layer.numChildren==0,name+" original ending respected");visual.reset();
      }
   }
}
import rconnect.game.RemoteMotion;
class MotionFixtureClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}
