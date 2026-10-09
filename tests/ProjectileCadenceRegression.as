package {
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import rconnect.game.ProjectileVisuals;
   import rconnect.game.RemoteMotion;
   /** Fixed source-time samples isolate the stair-step bug from machine load.
    * This is a presentation unit check, not a claim about measured game FPS. */
   public class ProjectileCadenceRegression {
      public static function run(main:Object,check:Function):void {
         var layer:Sprite=new Sprite(),loc:Object={},owner:Object={loc:loc};
         var ad:Object=main.loaderInfo.applicationDomain;
         var fixture:Object={loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            return name=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:ad.getDefinition(name);
         }}}};
         var visual:ProjectileVisuals=new ProjectileVisuals(),clock:ProjectileFixtureClock=new ProjectileFixtureClock();
         var frames:Array=[];
         for(var i:int=0;i<4;i++)frames.push({at:1000+i*40,x:80+i*40,y:100+i*20,rot:10,sx:1,sy:1,a:1,f:1,ls:1,lf:1});
         var flight:Object={cls:"visualBullet",x:80,y:100,dx:40,dy:20,ddy:0,rot:0,vel:45,spring:1,
            blend:"normal",frames:frames,end:1160};
         visual.receive(owner,[{id:"lmg",variant:0,stream:1,sampleTime:1120,events:[{seq:1,at:1000,flight:flight}]}],fixture,true,clock);
         var continuous:Boolean=true,moved:int=0,last:Number=NaN;
         for(i=0;i<=12;i++) {
            clock.time=1000+i*10;visual.tick(loc,12000+i*10);
            var v:DisplayObject=layer.numChildren?layer.getChildAt(0):null;
            continuous=continuous && v!=null && Math.abs(v.x-(80+i*10))<.01 && Math.abs(v.y-(100+i*5))<.01;
            if(v!=null){if(!isNaN(last) && v.x>last)moved++;last=v.x;}
         }
         check(continuous && moved==12,"between native frames projectile moves continuously without waiting for the next source tick steps="+moved);
         clock.time=1140;visual.tick(loc,12140);
         check(layer.numChildren==1 && Math.abs(layer.getChildAt(0).x-200)<.01,"missing future sample holds the endpoint without extrapolation");
         clock.time=1160;visual.tick(loc,12160);
         check(layer.numChildren==0,"native ending removes the projectile once");
         visual.reset();
      }
   }
}
import rconnect.game.RemoteMotion;
class ProjectileFixtureClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}
