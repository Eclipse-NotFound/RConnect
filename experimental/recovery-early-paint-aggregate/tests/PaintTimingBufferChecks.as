package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   public final class PaintTimingBufferChecks extends Sprite {
      private var assertions:Array=[],type:Object,w:Object,l:Object,p:PaintTimingBuffer,clock:int=10;
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});}
      public function PaintTimingBufferChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function setup(bind:Boolean=true):void {
         type={rconnectPaintTimingBridge:null,rconnectPaintTimingFaults:0};w={game:{},grafon:{}};l={};clock=10;
         p=new PaintTimingBuffer(type);p.begin(w);if(bind)p.bind(w,l,w.grafon);
      }
      private function value(ms:int=3):Object {
         var start:int=clock;clock+=Math.max(0,ms)+10;
         return {phase:"ensure-work",started:start,finished:start+ms,startedWall:1000+start,finishedWall:1000+start+ms,
            sameWorld:true,sameGame:true,sameLoc:true,preload:true,initial:false,residentBefore:1,residentAfter:1,
            worldRendererAtStart:true,worldRendererAtEnd:true,worldLocAtStart:true,worldLocAtEnd:true,
            completed:true,left:0,top:0,width:800,height:600};
      }
      private function fire(v:Object=null):void {type.rconnectPaintTimingBridge(w.grafon,w,w.game,l,v==null?value():v);}
      private function important():Object {var v:Object=value();v.initial=true;return v;}
      private function begin(e:Event):void {
         try {
            setup();for(var i:int=0;i<1000;i++)fire();var r:Object=p.finish("stable-positive");
            check(r.passed && r.rows.length==0 && !r.overflow,"1000 positive stable calls use fixed buckets");
            check(r.buckets.length==3 && r.buckets[0].calls==1000 && r.buckets[0].positiveMsCalls==1000,"fixed target bucket counts every positive call");
            check(r.inclusiveTotalMs==3000 && r.maxMs==3 && r.targetCalls==1000,"all positive work duration retained");
            check(r.buckets[0].firstStarted==10 && r.buckets[0].lastFinished==13000,"bucket keeps original first and last native clocks");
            check(type.rconnectPaintTimingBridge==null && p.finish("again")==null,"owned detach and idempotent finish");
            setup();for(i=0;i<1000;i++)fire(value(0));r=p.finish("stable-zero");
            check(r.passed && r.zeroMsCalls==1000 && r.buckets[0].zeroMsCalls==1000,"all zero-duration stable calls accounted");
            check(r.rows.length==0 && r.inclusiveTotalMs==0 && r.observationComplete,"zero-duration work never treated as a missing call");
            setup();for(i=0;i<32;i++)fire(important());r=p.finish("important-limit");
            check(r.passed && r.rows.length==32 && !r.overflow,"exactly 32 important calls retained");
            setup();for(i=0;i<33;i++)fire(important());r=p.finish("important-overflow");
            check(!r.passed && r.overflow && r.rows.length==32 && r.observedCalls==33,"33rd important call invalidates trace");
            check(type.rconnectPaintTimingBridge==null && !r.observationComplete,"important overflow detaches without pretending complete");
            setup();for(i=0;i<40;i++){fire();if(i%10==0)fire(important());}r=p.finish("mixed");
            check(r.passed && r.rows.length==4 && r.buckets[0].calls==40 && r.observedCalls==44,"important calls and stable calls have separate complete accounts");
            check(r.inclusiveTotalMs==132 && r.positiveMsCalls==44 && r.targetCalls==44,"mixed duration and target totals agree");
            setup();var v:Object=value(0);v.initial=true;fire(v);r=p.finish("initial");
            check(r.passed && r.rows.length==1 && r.buckets[0].calls==0,"zero-duration initial call remains important");
            setup();v=value(0);v.residentAfter=2;fire(v);r=p.finish("resident-change");
            check(r.passed && r.rows.length==1,"zero-duration resident change remains important");
            setup();v=value(0);v.completed=false;fire(v);r=p.finish("native-failure");
            check(!r.passed && r.rows.length==1 && r.incompleteCalls==1 && r.buckets[0].calls==0,"incomplete native work cannot enter a stable bucket");
            setup();v=value();v.sameWorld=false;fire(v);r=p.finish("identity");
            check(!r.passed && r.rows.length==1 && r.buckets[0].calls==0,"positive-time identity mismatch remains important and fails");
            setup();v=value();v.worldRendererAtEnd=false;fire(v);r=p.finish("replaced-renderer");
            check(!r.passed && !r.rows[0].sameRenderer,"renderer replacement is never hidden by aggregation");
            setup();v=value();v.worldLocAtEnd=false;fire(v);r=p.finish("replaced-room");
            check(!r.passed && !r.rows[0].sameLoc,"room replacement is never hidden by aggregation");
            setup();fire(value(-1));r=p.finish("bad-local-clock");
            check(!r.passed && r.rows.length==1 && !r.rows[0].clockValid,"backward local interval retained and rejected");
            setup();v=value();v.finishedWall=v.startedWall-1;fire(v);r=p.finish("bad-wall-clock");
            check(!r.passed && r.rows.length==1 && r.buckets[0].calls==0,"backward wall interval retained and rejected");
            setup();v=value();v.started=NaN;fire(v);r=p.finish("nonfinite");
            check(!r.passed && r.rows.length==1,"nonfinite timing is retained and rejected");
            setup();fire();v=value();v.started=0;v.finished=1;fire(v);r=p.finish("nonmonotonic");
            check(!r.passed && r.rows.length==1 && r.buckets[0].calls==1,"cross-call clock reversal cannot enter a stable bucket");
            setup();v=value();v.phase="bad";fire(v);r=p.finish("malformed");
            check(!r.passed && r.rows.length==1 && r.rows[0].observerError,"malformed callback leaves explicit important evidence");
            check(type.rconnectPaintTimingBridge==null,"malformed callback detaches safely");
            setup();fire();type.rconnectPaintTimingFaults++;r=p.finish("native-fault");
            check(!r.passed && r.nativeFaults==1,"native capture or observer fault invalidates aggregation");
            setup();fire();var foreign:Function=function():void {};type.rconnectPaintTimingBridge=foreign;r=p.finish("owner-change");
            check(!r.passed && !r.ownershipPreserved && type.rconnectPaintTimingBridge===foreign,"changed ownership is reported and preserved");
            setup();p.finish("clear");type.rconnectPaintTimingBridge=foreign;p.begin(w);r=p.finish("occupied");
            check(!r.passed && type.rconnectPaintTimingBridge===foreign,"occupied slot is never replaced");
            setup();p.bind({},l,w.grafon);fire();r=p.finish("binding-conflict");
            check(!r.passed && r.bindingConflicts==1,"binding conflict invalidates otherwise stable callbacks");
            setup();r=p.finish("missing-target");
            check(!r.passed && r.targetCalls==0,"a bound target requires at least one observed call");
            setup(false);r=p.finish("ordinary-room");
            check(r.passed && r.observedCalls==0 && r.buckets.length==3,"ordinary room can have no large-scene calls");
            setup(false);var oldRoom:Object=l;fire();l={};p.bind(w,l,w.grafon);fire();l=oldRoom;fire();r=p.finish("categories");
            check(r.passed && r.buckets[0].calls==1 && r.buckets[1].calls==1 && r.buckets[2].calls==1,"target unbound and other calls remain separate");
            check(r.targetCalls==1 && r.observedCalls==3,"other and pre-binding calls never count as target work");
            setup(false);for(i=0;i<20;i++){l={};fire();}r=p.finish("bucket-room-changes");
            check(r.passed && r.buckets[1].roomChanges==19 && r.rows.length==0,"fixed bucket tracks room identity transitions without allocating unbounded rows");
            setup();fire();v=value();v.residentBefore=v.residentAfter=2;fire(v);r=p.finish("stable-resident-transition");
            check(r.passed && r.buckets[0].residentTransitions==1 && r.buckets[0].firstResident==1 && r.buckets[0].lastResident==2,"stable bucket retains transitions between resident levels");
            setup();type.rconnectPaintTimingBridge(w.grafon,w,w.game,null,value());r=p.finish("null-room");
            check(!r.passed && r.rows.length==1 && !r.rows[0].sameLoc,"null room never aggregates as valid work");
            setup();p.begin(w);fire();r=p.finish("double-begin");
            check(!r.passed && r.faults>0,"overlapping observer sessions are rejected");
            setup();v=value();v.residentBefore=NaN;fire(v);r=p.finish("bad-resident");
            check(!r.passed && r.rows.length==1 && !r.rows[0].residentsValid,"nonfinite resident metadata cannot aggregate");
            setup();v=value();v.initial=null;fire(v);r=p.finish("bad-initial");
            check(!r.passed && r.rows.length==1 && r.rows[0].observerError,"nonboolean initial flag cannot silently change bucket eligibility");
         }catch(error:*){check(false,"unexpected component exception: "+error);}
         var failed:int=0;for each(var row:Object in assertions)if(!row.passed)failed++;
         var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         out.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,functional_only:true,native_runtime:false}));
         out.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
