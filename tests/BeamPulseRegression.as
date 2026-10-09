package {
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import rconnect.game.ProjectileVisuals;
   /** Native display symbols with explicit clocks. This isolates a render
    * interval crossing a whole queued pulse, independent of machine load. */
   public class BeamPulseRegression {
      public static function run(main:Object,check:Function):void {
         var layer:Sprite=new Sprite(),loc:Object={},owner:Object={loc:loc};
         var ad:Object=main.loaderInfo.applicationDomain;
         var fixture:Object={loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            return name=="fe.World"?{w:{grafon:{visObjs:[null,null,layer]}}}:ad.getDefinition(name);
         }}}};
         var v:ProjectileVisuals=new ProjectileVisuals(),clock:BeamFixtureClock=new BeamFixtureClock();
         var frames:Array=[{at:1000,x:10,y:20,rot:0,sx:1,sy:1,a:1,f:1,v:true,ls:3,lf:1},
            {at:1060,x:10,y:20,rot:0,sx:1,sy:1,a:.6,f:1,v:true,ls:3,lf:1},
            {at:1120,x:10,y:20,rot:0,sx:1,sy:1,a:0,f:1,v:false,ls:3,lf:1}];
         var flight:Object={cls:"visbullaser",x:10,y:20,rot:0,spring:2,blend:"add",frames:frames,end:1120};
         var event:Object={seq:1,at:1000,flight:flight};
         var gun:Object={id:"pulse-boundary",variant:0,stream:1,sampleTime:1100,events:[event]};
         v.receive(owner,[gun],fixture,false,clock);v.tick(loc,12000,true);
         check(v.count==1&&layer.numChildren==0,"queued future beam waits for its first source frame");
         clock.time=1160;v.tick(loc,12210,false);
         check(layer.numChildren==1&&layer.getChildAt(0).visible,"whole queued beam crossed by one frame stall is presented");
         v.tick(loc,12210,true);v.tick(loc,12210,true);
         check(layer.numChildren==1&&layer.getChildAt(0).visible,"repeated final pass preserves the recovered beam until a render boundary");
         clock.time=1190;v.tick(loc,12243,false);
         check(v.count==0&&layer.numChildren==0,"recovered beam leaves on the next display frame");
         v.receive(owner,[gun],fixture,false,clock);v.tick(loc,12243,true);
         check(v.count==0,"duplicate completed beam never replays");
         event.seq=2;clock.time=2000;v.receive(owner,[gun],fixture,false,clock);v.tick(loc,13000,true);
         check(v.count==0&&layer.numChildren==0,"historical beam first received after its ending remains expired");
         event.seq=3;clock.time=1000;v.receive(owner,[gun],fixture,false,clock);v.tick(loc,14000,true);
         check(layer.numChildren==1,"ordinary native beam frame is presented at its source time");
         clock.time=1160;v.tick(loc,14210,true);
         check(v.count==0,"already rendered beam expires without an extra recovery frame");
         event.seq=4;clock.time=950;v.receive(owner,[gun],fixture,false,clock);v.tick(loc,15000,true);
         clock.time=1160;v.setPaused(true);v.tick(loc,15210,true);
         check(v.count==0,"shared pause settlement does not resurrect an ended beam");v.setPaused(false);
         event.seq=5;clock.time=950;v.receive(owner,[gun],fixture,false,clock);v.tick(loc,16000,true);
         clock.time=2300;v.tick(loc,17350,true);
         check(v.count==0,"a stale beam beyond the recovery window is discarded");
         event.seq=6;clock.time=950;v.receive(owner,[gun],fixture,false,clock);
         clock.time=1160;v.tick(loc,18210,true);
         check(layer.numChildren==1&&layer.getChildAt(0).visible,"freshly queued beam also survives a stall before its first tick");
         clock.time=1190;v.tick(loc,18243,true);
         check(v.count==0,"first-tick recovery also expires after its single presented frame");
         v.reset();
      }
   }
}
