package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.loc.Tile;
   import rconnect.core.Log;
   import rconnect.game.TerrainSync;

   /** Exact old/new terrain output on detached native Tile grids. This test
    * never writes the live map, changes report cadence or replaces physics. */
   public class TerrainComparisonTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),began:int=getTimer(),done:Boolean=false;
      private var nativeTile:Class;
      private var group:String="";
      public function TerrainComparisonTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("rconnect-coop-")<0)return;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"terrain-comparison "+group+" "+label);}
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a is Number && b is Number && isNaN(a) && isNaN(b))return true;
         if(a==null || b==null || typeof a!=typeof b || typeof a!="object" || (a is Array)!=(b is Array))return false;
         if(a is Array && a.length!=b.length)return false;
         var n:int=0,m:int=0;
         for(var key:String in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;
         return n==m;
      }
      private function grid(width:int,height:int):Object {
         var room:Object={spaceX:width,spaceY:height,space:[]};
         for(var x:int=0;x<width;x++) {
            room.space[x]=[];
            for(var y:int=0;y<height;y++) {
               var t:Object=new nativeTile(x,y);t.phis=1;t.hp=1000;t.front="wall-"+(x%3);
               t.back="background";t.zad="rear";t.opac=.75;t.vid=x%4;t.vid2=y%3;
               room.space[x][y]=t;
            }
         }
         return room;
      }
      private function nativeReplay():void {
         var room:Object=grid(20,16),old:Object=new BeforeNativeTerrainSync(),now:TerrainSync=new TerrainSync();
         check(room.space[0][0] is Tile,"uses actual native Tile type for direct-slot branch");
         check(old.hostPatch(room)==null && now.hostPatch(room)==null,"native unchanged baseline");
         var exact:Boolean=true;
         for(var n:int=0;n<180;n++) {
            var t:Object=room.space[(n*3)%20][(n*7)%16];
            t.hp-=7;t.front="front-"+int(n/3);t.stair=n%3;t.water=n%2;t.zForm=n%4;
            t.shelf=n%2==1;t.diagon=n%3;t.vid=n%5;t.vid2=n%7;
            if(n%11==0)t.opac=NaN;else if(n%13==0)t.opac=Infinity;else t.opac=(n%7)/8;
            exact=same(old.hostPatch(room),now.hostPatch(room)) && exact;
         }
         check(exact,"180 native-grid mutations preserve ordered patches and rotating 128-tile cap");
         room.spaceX=5;room.spaceY=7;
         check(same(old.hostPatch(room),now.hostPatch(room)),"native room shrink preserves coordinates");
         room.spaceX=20;room.spaceY=16;
         check(same(old.hostPatch(room),now.hostPatch(room)),"native room re-expansion preserves coordinates");
         room=grid(3,4);old=new BeforeNativeTerrainSync();now=new TerrainSync();
         old.report(room);now.report(room);room.space[2][3].hp-=23;
         check(same(old.report(room),now.report(room)),"native predicted damage report remains identical");
         room.space[2][3].hp-=31;room.space[0][0].hp-=7;
         check(same(old.finishReports(room),now.finishReports(room)),"native room close retains damage while receipt is pending");
         old.reset();now.reset();
         check(old.hostPatch(room)==null && now.hostPatch(room)==null,"reset accepts the same native baseline");
      }
      private function measurement():void {
         var room:Object=grid(40,36),old:Object=new BeforeNativeTerrainSync(),now:Object=new TerrainSync();
         old.hostPatch(room);now.hostPatch(room);old.report(room);now.report(room);
         var samples:Array=[],quiet:Boolean=true;
         for(var round:int=0;round<6;round++) {
            var times:Array=[0,0];
            for(var order:int=0;order<2;order++) {
               var index:int=(round+order)%2,scanner:Object=index==0?old:now,start:int=getTimer();
               for(var n:int=0;n<20;n++) {
                  if(scanner.hostPatch(room)!=null || scanner.report(room)!=null)quiet=false;
               }
               times[index]=getTimer()-start;
            }
            samples.push({baseline:times[0],candidate:times[1]});
         }
         check(quiet,"alternating measured scans emit no unchanged-tile packets");
         Log.d("TERRAIN COMPARISON TIMING "+JSON.stringify({tiles:1440,hostAndJoinScansPerSample:20,samples:samples,
            boundary:"isolated algorithm time, not whole-game FPS"}));
      }
      private function tick(event:TimerEvent):void {
         if(done)return;
         var mod:RConnectMod=RConnectMod.instance;
         if(getTimer()-began>120000){check(false,"native room readiness deadline");finish();return;}
         if(mod==null || mod.game.loc==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         done=true;timer.stop();
         try {
            nativeTile=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Tile") as Class;
            group="native access";NativeProbeRegression.run(check,mod.game.gg,mod.main);
            group="body color channels";BodyTintRegression.run(check,true);
            group="candidate";NativeTileFieldsRegression.run(check,mod.main,TerrainSync);
            group="frozen baseline";NativeTileFieldsRegression.run(check,mod.main,BeforeNativeTerrainSync);
            group="differential";
            check(same(TerrainRegression.replay(BeforeNativeTerrainSync),TerrainRegression.replay(TerrainSync)),
               "180 dynamic-grid ticks preserve reports, receipts, patches and final state");
            nativeReplay();measurement();
         } catch(error:*) {check(false,"exception "+(error is Error?error.getStackTrace():error));}
         finish();
      }
      private function finish():void {done=true;timer.stop();Log.d("COOP EFFECTS DONE terrain-comparison");}
   }
}
