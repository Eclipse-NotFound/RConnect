package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import fe.World;
   import fe.loc.Location;
   /** Exact candidate sceneOpen/ensure/tick/viewReady bodies. Asset allocation,
    * chunk painting and native entities are explicit substitutes, not pixels. */
   public class FirstRasterNativeChecks extends Sprite {
      private var rows:Array=[];
      public function FirstRasterNativeChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function fixture():Object {
         var l:Location=new Location();l.spaceX=192;l.spaceY=75;l.limX=7680;l.limY=3000;
         l.spawnPoints=[{x:5,y:4}];l.gg={X:240,Y:200};
         var g:NativeRasterHarness=new NativeRasterHarness();
         World.w={main:new Sprite(),loc:l,grafon:g,swfStage:{stageWidth:640,stageHeight:480},
            cam:{scaleV:1,vx:0,vy:0,quakeX:0,quakeY:0,screenX:640,screenY:480}};
         return {l:l,g:g};
      }
      private function run(event:Event):void {
         try {
            var f:Object=fixture(),g:NativeRasterHarness=f.g,t:Object={waiting:true,unpainted:true};
            NativeRasterHarness.rconnectRasterBridge=function(w:Object,l:Object,r:Object):Object{return t;};
            g.open(f.l);
            check(g.loc===f.l && f.l.grafon===g,"sceneOpen keeps new room renderer binding");
            check(g.order.join(",")=="lighting,clear,borders,prepare,setLight,backdrops,objects","all sceneOpen initialization remains in order");
            check(g.sceneLarge && g.sceneResident==0 && g.ensureCount==0,"held preload has initialized scene and zero chunks");
            check(g.rconnectRasterPending && !g.sceneViewReady(),"held scene is neither sampled nor ready");
            g.sceneTick();check(g.ensureCount==0 && g.sceneResident==0,"camera tick cannot bypass held raster");
            t.waiting=false;g.open(f.l);
            check(g.ensureCount==1 && g.sceneResident>0,"restore reuses complete native preload path once");
            check(!g.rconnectRasterPending && g.sceneViewReady(),"preloaded native chunks clear unpainted only after ready");
            check(g.order.length==14,"restore retains every original initialization callback");
            var scans:int=g.readyScans;
            World.w.cam.vx=-1280;World.w.cam.vy=-640;g.sceneTick();g.sceneTick();g.sceneTick();
            check(g.ensureCount==1,"preload completes full panorama once and anchor camera does not paint again");
            check(scans>0 && g.readyScans==scans,"completed preload ticket does not repeat view readiness scans on later camera ticks");

            f=fixture();g=f.g;g.scenePreload=false;t={waiting:true,unpainted:true};g.open(f.l);
            check(g.ensureCount==0 && g.sceneResident==0,"nonpreload held open builds no speculative first window");
            t.waiting=false;g.open(f.l);
            check(g.sceneResident==0 && g.rconnectRasterPending,"nonpreload drawLoc return is not proof of pixels");
            World.w.cam.vx=-1280;World.w.cam.vy=-640;g.sceneTick();
            check(g.lastLeft==1280 && g.lastTop==640,"natural camera tick ensures actual post-anchor viewport");
            check(g.sceneViewReady() && !g.rconnectRasterPending,"first native camera view becomes eligible only after ensured chunks");
            scans=g.readyScans;g.sceneTick();g.sceneTick();g.sceneTick();
            check(scans>0 && g.readyScans==scans,"completed nonpreload ticket does not repeat view readiness scans while normal viewport ensuring continues");

            f=fixture();g=f.g;t={waiting:true,unpainted:true};g.open(f.l);t.waiting=false;
            g.sceneTick();check(!t.unpainted && g.sceneResident>0,"cancel lets native renderer finish local pixels without a grant");

            f=fixture();g=f.g;NativeRasterHarness.rconnectRasterBridge=null;g.open(f.l);
            check(g.ensureCount==1 && !g.rconnectRasterPending && g.sceneViewReady(),"missing callback preserves original rendering");
            f=fixture();g=f.g;NativeRasterHarness.rconnectRasterBridge=function(w:Object,l:Object,r:Object):Object{return {};};g.open(f.l);
            check(g.ensureCount==1 && !g.rconnectRasterPending,"unknown callback state falls back to normal drawing");
            f=fixture();g=f.g;NativeRasterHarness.rconnectRasterBridge=function(w:Object,l:Object,r:Object):Object{return new Sprite();};g.open(f.l);
            check(g.ensureCount==1 && !g.rconnectRasterPending,"sealed unknown callback state also falls back safely");
            f=fixture();g=f.g;NativeRasterHarness.rconnectRasterBridge=function(w:Object,l:Object,r:Object):Object{throw new Error("fixture callback failure");};g.open(f.l);
            check(g.ensureCount==1 && !g.rconnectRasterPending,"failed callback cannot stop native initialization");
            NativeRasterHarness.rconnectRasterBridge=null;
         }catch(e:Error){check(false,e+" "+e.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,native_game_test:false,pixel_test:false}));stream.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
