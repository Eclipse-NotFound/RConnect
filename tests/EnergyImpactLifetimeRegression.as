package {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.game.EnergyImpactVisuals;

   /** Replays the exact short lifetimes seen in 97fdde4ac3 against the public
    * presentation API. The clock is controlled; artwork comes from the loaded
    * game. It does not change world state or call the native damage particle. */
   public class EnergyImpactLifetimeRegression {
      private static function pose(at:int,frame:int=1,x:Number=1125.3):Object {
         return {at:at,x:x,y:754.55,r:0,sx:1,sy:1,a:1,f:frame,v:true,c:[1,1,1,1,0,0,0,0]};
      }
      private static function event(id:int,frames:Array,end:int):Object {
         return {id:id,cls:"flLaser",layer:2,blend:"normal",frames:frames,end:end};
      }
      private static function clip(layer:Sprite):MovieClip {
         return layer.numChildren?layer.getChildAt(0) as MovieClip:null;
      }
      public static function run(main:Object,check:Function):void {
         var layer:Sprite=new Sprite(),loc:Object={},nativeRequests:int=0;
         var ad:Object=main.loaderInfo.applicationDomain;
         var fixture:Object={loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            if(name=="fe.graph.Part" || name=="fe.weapon.Bullet")nativeRequests++;
            return name=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:ad.getDefinition(name);
         }}}};
         var visual:EnergyImpactVisuals=new EnergyImpactVisuals();
         var clock:EnergyImpactFixtureClock=new EnergyImpactFixtureClock();
         var channel:Object={},now:int=getTimer(),v:MovieClip;
         var seventh:Object=event(7,[pose(52289),pose(52322)],52356);
         visual.receive(channel,[seventh],loc,fixture,0,0,clock);
         clock.time=52280;visual.tick(loc,now);
         check(layer.numChildren==0 && visual.count==1,"short impact waits until its real source start");
         clock.time=52370;visual.tick(loc,now+100);v=clip(layer);
         check(v!=null && visual.count==1,"clock crossing the entire 67ms lifetime still displays the impact once");
         check(v!=null && getQualifiedClassName(v)=="flLaser" && v.x==1125.3 && v.y==754.55
            && v.scaleX==1 && v.scaleY==1 && v.alpha==1 && v.rotation==0 && v.currentFrame==1,
            "recovered impact keeps the actual native artwork and exact source pose");
         visual.tick(loc,now+100);
         check(v!=null && clip(layer)===v,"ENTER_FRAME and RENDER ticks at the same stamp cannot consume the flash");
         visual.tick(loc,now+116);
         check(layer.numChildren==0 && visual.count==0,"identical ending pose expires after one distinct display frame");
         visual.receive(channel,[seventh],loc,fixture,0,0,clock);visual.tick(loc,now+132);
         check(layer.numChildren==0 && visual.count==0,"a repeated completed event cannot create another flash");
         visual.reset();channel={};

         // The first quick shot really reached frame 2 for only 19ms. Its
         // ending and frame 2 were already present before the cursor crossed it.
         var first:Object=event(1,[pose(51855,1,1122.4),pose(51917,1,1122.4),pose(51936,2,1122.4)],51955);
         visual.receive(channel,[first],loc,fixture,0,0,clock);
         clock.time=51855;visual.tick(loc,now+200);v=clip(layer);
         check(v!=null && v.currentFrame==1,"ordinary impact starts on its received first frame");
         clock.time=51960;visual.tick(loc,now+305);
         check(clip(layer)===v && v!=null && v.currentFrame==2,"clock crossing the 19ms final-frame interval displays that received frame");
         visual.tick(loc,now+305);
         check(clip(layer)===v && v!=null && v.currentFrame==2,"same-stamp second tick preserves the recovered final frame");
         visual.tick(loc,now+321);
         check(layer.numChildren==0 && visual.count==0,"final-frame recovery finishes on the next display frame");
         visual.reset();channel={};

         // A fully missed sequence must not turn into a queue of every native
         // sample. At most the first and final visible poses are recovered.
         var many:Array=[];
         for(var i:int=0;i<64;i++)many.push(pose(1000+i,i==63?2:1));
         var bounded:Object=event(1,many,1067);
         visual.receive(channel,[bounded],loc,fixture,0,0,clock);
         clock.time=1080;visual.tick(loc,now+400);v=clip(layer);
         check(v!=null && v.currentFrame==1,"a fully skipped two-pose impact first presents its native first pose");
         visual.tick(loc,now+400);visual.tick(loc,now+416);
         check(clip(layer)===v && v!=null && v.currentFrame==2,"64 skipped source samples recover only the final pose on the next frame");
         visual.tick(loc,now+416);visual.tick(loc,now+432);
         check(layer.numChildren==0 && visual.count==0,"recovery has no unbounded per-sample playback backlog");
         visual.reset();channel={};

         // An ending can arrive after its first sample. A duplicate older
         // non-ended packet must neither reopen it nor cancel its final frame.
         visual.receive(channel,[event(1,[pose(1000)],0)],loc,fixture,0,0,clock);
         clock.time=1000;visual.tick(loc,now+500);
         visual.receive(channel,[event(1,[pose(1000),pose(1048,2)],1067)],loc,fixture,0,0,clock);
         visual.receive(channel,[event(1,[pose(1000)],0)],loc,fixture,0,0,clock);
         clock.time=1070;visual.tick(loc,now+570);v=clip(layer);
         check(v!=null && v.currentFrame==2,"late ending retains its final pose despite a duplicate older live packet");
         visual.tick(loc,now+586);
         check(layer.numChildren==0 && visual.count==0,"late ending is still finite and idempotent");
         visual.reset();channel={};

         visual.receive(channel,[bounded],loc,fixture,0,0,clock);
         clock.time=2068;visual.tick(loc,now+700);
         check(layer.numChildren==0 && visual.count==0,"an ending older than the one-second source retention window is not replayed");
         visual.reset();channel={};
         visual.receive(channel,[event(1,[pose(1000)],0)],loc,fixture,0,0,clock);
         clock.time=1000;visual.tick(loc,getTimer()+15001);
         check(layer.numChildren==0 && visual.count==0,"missing-end streams retain their existing fifteen-second stale cleanup");
         visual.reset();channel={};

         // GameBridge passes a frozen presentation stamp while paused. Several
         // real tick callbacks must not consume the same recovery frame.
         visual.receive(channel,[bounded],loc,fixture,0,0,clock);
         clock.time=1080;visual.tick(loc,getTimer());visual.setPaused(true);
         visual.tick(loc,getTimer()+100);v=clip(layer);
         var pausedFrame:int=v==null?0:v.currentFrame;
         visual.tick(loc,getTimer()+5000);
         check(v!=null && clip(layer)===v && v.currentFrame==pausedFrame,"pause preserves the visible recovery frame across repeated callbacks");
         visual.setPaused(false);
         var resumed:int=getTimer()+32;
         visual.tick(loc,resumed);visual.tick(loc,resumed+16);visual.tick(loc,resumed+32);
         check(layer.numChildren==0 && visual.count==0,"resuming completes finite recovery without replaying history");
         visual.reset();channel={};

         visual.receive(channel,[bounded],loc,fixture,0,0,clock);
         visual.tick(loc,getTimer());visual.tick({},getTimer()+16);
         check(layer.numChildren==0 && visual.count==0,"room changes immediately remove old-room effects");
         visual.receive({},[bounded],loc,fixture,0,0,clock);visual.tick(loc,getTimer()+32);visual.reset();
         check(layer.numChildren==0 && visual.count==0,"reset removes every clip and pending playback record");
         check(nativeRequests==0,"presentation never requests a native damage Part or Bullet");
      }
   }
}
import rconnect.game.RemoteMotion;
class EnergyImpactFixtureClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}
