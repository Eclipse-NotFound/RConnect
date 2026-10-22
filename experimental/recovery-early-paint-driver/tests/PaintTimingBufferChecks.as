package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   /** Fake callback carrier only; exercises the actual external buffer. */
   public final class PaintTimingBufferChecks extends Sprite {
      private var assertions:Array=[],type:Object,w:Object,l:Object,p:PaintTimingBuffer;
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});}
      public function PaintTimingBufferChecks() {addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function setup(bind:Boolean=true):void {
         type={rconnectPaintTimingBridge:null,rconnectPaintTimingFaults:0};w={game:{},grafon:{}};l={};
         p=new PaintTimingBuffer(type);p.begin(w);if(bind)p.bind(w,l,w.grafon);
      }
      private function value(ms:int=3):Object {
         return {phase:"ensure-work",started:10,finished:10+ms,startedWall:1000,finishedWall:1000+ms,
            sameWorld:true,sameGame:true,sameLoc:true,preload:true,initial:false,residentBefore:1,residentAfter:1,
            worldRendererAtStart:true,worldRendererAtEnd:true,worldLocAtStart:true,worldLocAtEnd:true,
            completed:true,left:0,top:0,width:800,height:600};
      }
      private function fire(v:Object=null):void {type.rconnectPaintTimingBridge(w.grafon,w,w.game,l,v==null?value():v);}
      private function begin(e:Event):void {
         try {
            setup();fire();var r:Object=p.finish("normal");
            check(r.passed && r.targetRows==1 && r.rows.length==1,"positive-work row and target identity retained");
            check(r.rows[0].started==10 && r.rows[0].finished==13 && r.inclusiveTotalMs==3,"native interval copied without clock replacement");
            check(type.rconnectPaintTimingBridge==null && p.finish("again")==null,"owned callback removed and finish idempotent");
            setup(false);for(var i:int=0;i<1000;i++)fire(value(0));r=p.finish("zero-ms");
            check(r.passed && r.observedCalls==1000,"all zero-ms calls accounted");
            check(r.rows.length==0 && r.zeroMsStableResidentSkipped==1000,"zero-ms stable resident rows explicitly aggregated");
            check(!r.overflow && r.inclusiveTotalMs==0 && r.observationComplete,"many zero-ms calls do not overflow meaningful rows");
            setup();for(i=0;i<32;i++)fire();r=p.finish("limit");
            check(r.passed && r.rows.length==32 && !r.overflow,"exactly 32 meaningful rows accepted");
            setup();for(i=0;i<33;i++)fire();r=p.finish("overflow");
            check(r.rows.length==32 && r.overflow && !r.passed,"33rd meaningful call marks incomplete trace");
            check(r.observedCalls==33 && r.inclusiveTotalMs==99,"overflow-triggering call still aggregates");
            check(type.rconnectPaintTimingBridge==null && !r.observationComplete,"overflow detaches without pretending complete");
            setup();fire();type.rconnectPaintTimingFaults++;r=p.finish("native-fault");
            check(r.nativeFaults==1 && !r.passed,"native capture failure invalidates observation");
            setup();fire();var foreign:Function=function():void {};type.rconnectPaintTimingBridge=foreign;r=p.finish("owner-change");
            check(!r.ownershipPreserved && !r.passed,"changed owner invalidates observation");
            check(type.rconnectPaintTimingBridge===foreign,"never clear another observer");
            setup();p.finish("clear");type.rconnectPaintTimingBridge=foreign;p.begin(w);r=p.finish("occupied");
            check(!r.passed && type.rconnectPaintTimingBridge===foreign,"occupied callback not overwritten");
            setup();var v:Object=value();v.phase="bad";fire(v);r=p.finish("malformed");
            check(r.faults==1 && r.rows.length==0 && !r.passed,"malformed metadata cannot silently pass");
            check(type.rconnectPaintTimingBridge==null,"malformed metadata detaches observer");
            setup();p.bind({},l,w.grafon);fire();r=p.finish("binding-conflict");
            check(r.bindingConflicts==1 && !r.passed,"wrong raster binding is recorded");
            setup();v=value(0);v.completed=false;fire(v);r=p.finish("work-error");
            check(r.rows.length==1 && r.incompleteCalls==1 && !r.passed,"zero-ms original failure is never filtered");
            setup();v=value(0);v.sameWorld=false;fire(v);r=p.finish("identity-change");
            check(r.rows.length==1 && !r.passed,"zero-ms identity change is never filtered");
            setup();v=value(-1);fire(v);r=p.finish("bad-clock");
            check(r.faults==1 && !r.passed,"backwards local clock is invalid");
            setup();r=p.finish("missing-draw");
            check(!r.passed && r.rasterRoomBound && r.targetRows==0,"bound raster room needs an observed work interval");
            setup(false);r=p.finish("ordinary-room");
            check(r.passed && !r.rasterRoomBound && r.rows.length==0,"ordinary-room segment can have no large-scene work");
            setup();v=value(0);v.initial=true;fire(v);r=p.finish("initial");
            check(r.passed && r.rows.length==1,"initial work retained even at zero-ms resolution");
            setup();v=value(0);v.residentAfter=2;fire(v);r=p.finish("new-resident");
            check(r.passed && r.rows.length==1,"new resident work retained even at zero-ms resolution");
            setup();v=value(0);v.worldRendererAtEnd=false;fire(v);r=p.finish("old-renderer");
            check(!r.passed && r.rows.length==1 && !r.rows[0].sameRenderer,"same object reference cannot hide world renderer replacement");
         }catch(error:*){check(false,"unexpected component exception: "+error);}
         var failed:int=0;for each(var row:Object in assertions)if(!row.passed)failed++;
         var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         out.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,functional_only:true,native_runtime:false}));
         out.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
