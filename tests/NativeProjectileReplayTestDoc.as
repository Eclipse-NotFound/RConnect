package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.geom.Rectangle;
   import flash.geom.Matrix;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.ProjectileVisuals;
   public class NativeProjectileReplayTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),started:int=getTimer();
      public function NativeProjectileReplayTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("rconnect-coop-")<0)return;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"native-projectile-replay "+label);}
      private function tick(event:TimerEvent):void {
         var mod:RConnectMod=RConnectMod.instance;
         if(mod==null||mod.game==null||mod.game.gg==null||mod.game.isTransitioning())return;
         if(mod.game.world.vblack.visible&&mod.game.world.vblack.alpha>0)return;
         timer.stop();
         try {
            mod.game.gg.invulner=true;
            ProjectileCadenceRegression.run(mod.main,check);
            replay(mod,"visbullightning");replay(mod,"visbullightning2");
         }catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         Log.d("COOP EFFECTS DONE native-projectile-replay");
      }
      private function replay(mod:RConnectMod,name:String):void {
         var ad:Object=mod.main.loaderInfo.applicationDomain;
         var cls:Class=ad.getDefinition(name) as Class;
         var reference:MovieClip=new cls() as MovieClip;reference.gotoAndStop(1);
         var visible:int=pixels(reference);
         check(visible>0,name+" native artwork has nontransparent pixels="+visible);
         var layer:Sprite=new Sprite(),loc:Object={},owner:Object={loc:loc};
         var fixture:Object={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            return n=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:ad.getDefinition(n);
         }}}};
         var visual:ProjectileVisuals=new ProjectileVisuals(),clock:NativeReplayClock=new NativeReplayClock();
         var frames:Array=[];
         for(var i:int=0;i<4;i++)frames.push({at:1000+i*50,x:100+i*125,y:50+i*25,rot:10,sx:1,sy:1,a:1,f:1,ls:1,lf:1});
         var flight:Object={cls:name,x:100,y:50,spring:1,rot:0,blend:"normal",frames:frames,end:1200};
         visual.receive(owner,[{id:"native-lightning",variant:0,stream:1,sampleTime:1150,events:[{seq:1,flight:flight}]}],fixture,true,clock);
         var positions:Boolean=true,artwork:Boolean=true,moved:int=0,last:Number=NaN;
         for(i=0;i<=15;i++) {
            clock.time=1000+i*10;visual.tick(loc,getTimer());
            var v:DisplayObject=layer.numChildren?layer.getChildAt(0):null;
            positions=positions&&v!=null&&Math.abs(v.x-(100+i*25))<.001&&Math.abs(v.y-(50+i*5))<.001;
            if(v!=null){if(isFinite(last)&&v.x!=last)moved++;last=v.x;artwork=artwork&&pixels(v)>0;}
            else artwork=false;
         }
         check(positions&&moved==15,name+" actual native clip moves at every display sample moving="+moved+"/15");
         check(artwork,name+" native artwork stays visible while translated");
         clock.time=1200;visual.tick(loc,getTimer());
         check(layer.numChildren==0,name+" original lifetime ends with no extra clip");visual.reset();
      }
      private function pixels(v:DisplayObject):int {
         var bounds:Rectangle=v.getBounds(v);bounds.inflate(2,2);
         if(bounds.width<1||bounds.height<1||bounds.width>2048||bounds.height>2048)return 0;
         var image:BitmapData=new BitmapData(Math.ceil(bounds.width),Math.ceil(bounds.height),true,0);
         image.draw(v,new Matrix(1,0,0,1,-bounds.x,-bounds.y));
         var data:Vector.<uint>=image.getVector(image.rect),count:int=0;
         for each(var value:uint in data)if(value>>>24)count++;
         image.dispose();return count;
      }
   }
}
import rconnect.game.RemoteMotion;
class NativeReplayClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}
