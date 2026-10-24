package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.getTimer;

   /** Sole sampler in a new, game-free component process. */
   public final class SamplerRetentionDoc extends Sprite {
      private static const PHASE_LIMIT_MS:int=3000,WORK_LIMIT_MS:int=2000;
      private static const ARITHMETIC_MS:int=150,MAX_CHUNKS:int=4096,CHUNK_SIZE:int=256;
      private static const RING_SIZE:int=64,SAMPLE_LIMIT:int=32768,SEGMENT_LIMIT:int=8192,CALLBACK_LIMIT:int=8;
      private var phase:int=0,state:String="arm",row:Object,rows:Array=[],assertions:Array=[];
      private var ring:Vector.<Object>=new Vector.<Object>(RING_SIZE,true);
      private var checksum:uint=0x6d2b79f5,insideCallback:Boolean=false,finished:Boolean=false;
      private var appId:String;

      public function SamplerRetentionDoc() {
         appId=NativeApplication.nativeApplication.applicationID;
         if(stage!=null)arm();else addEventListener(Event.ADDED_TO_STAGE,added);
      }
      private function added(event:Event):void {removeEventListener(Event.ADDED_TO_STAGE,added);arm();}
      private function arm():void {
         if(appId.indexOf("rconnect-recovery-component-")!=0)throw new Error("isolated component AppID required");
         stage.addEventListener(Event.ENTER_FRAME,onEnter);
         stage.addEventListener(Event.RENDER,onRender);
         stage.invalidate();
      }
      private function note(where:String,error:*):void {
         row.errorCount++;
         if(row.errors.length<16)row.errors.push(where+": "+String(error).substr(0,256));
      }
      private function validCount(value:Number):Boolean {return isFinite(value) && value>=0 && Math.floor(value)==value;}
      private function count():Number {
         var value:Number=getSampleCount();
         if(!validCount(value))throw new Error("invalid sample count");
         return value;
      }
      private function tick(value:uint):uint {
         value^=value<<13;value^=value>>>17;value^=value<<5;
         return uint(value+0x9e3779b9);
      }
      private function startPhase():void {
         row={phase:phase,name:phase==0?"arithmetic-cross-event":(phase==1?"pressure-no-callback":"pressure-callback"),
            phaseStart:getTimer(),startRender:true,startCall:0,startReturned:0,workStart:0,workEnd:0,
            pauseCall:0,pauseReturned:0,nextEnter:0,cleanupStart:0,cleanupEnd:0,
            started:false,paused:false,stopped:false,cleared:false,callbackUnset:false,
            chunks:0,objects:0,checksum:0,positiveSeen:false,positiveThenZero:false,firstPositiveAt:-1,firstZeroAt:-1,
            lastObservedCount:0,maximumObservedCount:0,pauseCount:-1,nextEnterCount:-1,
            callbackCalls:0,callbackRecords:[],callbackAbort:false,callbackCapped:false,callbackClears:0,
            postCallbackCpu:0,callbackMs:0,callbackDepthError:false,enumerated:0,truncated:false,
            errorCount:0,errors:[],finalSamples:null,retainedAcrossEvent:null,callbackSupported:false};
         rows.push(row);checksum=0x6d2b79f5;
         try {
            // Every phase starts independently; do not inherit a previous callback or buffer.
            setSamplerCallback(null);stopSampling();clearSamples();sampleInternalAllocs(false);
            if(phase==2)setSamplerCallback(onSamplerFull);
            row.startCall=getTimer();startSampling();row.started=true;row.startReturned=getTimer();
            state="work";
         }catch(error:*){note("start",error);state="pause";stage.invalidate();}
      }
      private function observeCount():void {
         var n:Number=count();
         row.maximumObservedCount=Math.max(row.maximumObservedCount,n);
         if(n>0 && !row.positiveSeen){row.positiveSeen=true;row.firstPositiveAt=getTimer();}
         // Callback clear is intentional and separately recorded. Only a no-callback phase
         // can establish an unexplained positive-to-zero transition during workload.
         if(phase!=2 && row.positiveSeen && row.lastObservedCount>0 && n==0 && !row.positiveThenZero) {
            row.positiveThenZero=true;row.firstZeroAt=getTimer();
         }
         row.lastObservedCount=n;
      }
      private function work():void {
         row.workStart=getTimer();
         try {
            var deadline:int=row.workStart+(phase==0?ARITHMETIC_MS:WORK_LIMIT_MS);
            var max:int=phase==0?131072:MAX_CHUNKS;
            for(var chunk:int=0;chunk<max;chunk++) {
               for(var i:int=0;i<CHUNK_SIZE;i++) {
                  checksum=tick(checksum);
                  if(phase!=0){ring[int(row.objects)&(RING_SIZE-1)]={number:row.objects,value:checksum};row.objects++;}
               }
               row.chunks++;observeCount();
               if(getTimer()>=deadline || getTimer()-row.phaseStart>=PHASE_LIMIT_MS || row.callbackAbort)break;
            }
            row.checksum=checksum;
         }catch(error:*){note("work",error);}
         row.workEnd=getTimer();row.workElapsed=row.workEnd-row.workStart;
         state="pause";stage.invalidate();
      }
      private function enumerateSamples():Object {
         var result:Object={before:count(),after:0,visited:0,cpu:0,allocations:0,deletions:0,truncated:false,unreadAtLeast:0};
         // Reserve one whole segment for the post-pause ENTER observation.
         var limit:int=insideCallback?SAMPLE_LIMIT-SEGMENT_LIMIT:SAMPLE_LIMIT;
         for each(var sample:Object in getSamples()) {
            if(result.visited>=SEGMENT_LIMIT || row.enumerated>=limit || getTimer()-row.phaseStart>=PHASE_LIMIT_MS) {
               result.truncated=true;row.truncated=true;break;
            }
            result.visited++;row.enumerated++;
            if(sample is NewObjectSample)result.allocations++;
            else if(sample is DeleteObjectSample)result.deletions++;
            else if(sample is Sample)result.cpu++;
            else throw new Error("unknown sample type");
         }
         result.after=count();
         if(result.visited<result.before){result.truncated=true;row.truncated=true;}
         result.unreadAtLeast=Math.max(0,result.before-result.visited);
         return result;
      }
      private function onSamplerFull():Boolean {
         row.callbackCalls++;
         if(insideCallback){row.callbackDepthError=true;row.callbackAbort=true;return false;}
         if(row.callbackCalls>CALLBACK_LIMIT || getTimer()-row.phaseStart>=PHASE_LIMIT_MS) {
            row.callbackCapped=true;row.callbackAbort=true;return false;
         }
         insideCallback=true;
         var entered:int=getTimer(),ok:Boolean=false,segment:Object;
         try {
            // No explicit start/stop here: verify whether the runtime resumes after true.
            pauseSampling();segment=enumerateSamples();
            if(row.callbackClears>0)row.postCallbackCpu+=segment.cpu;
            clearSamples();segment.afterClear=count();
            if(segment.afterClear!=0)throw new Error("callback clear left samples");
            row.callbackClears++;segment.at=entered;
            row.callbackRecords.push(segment);
            // A bounded prefix is sufficient to test clear/resume mechanics. Unread
            // samples are explicitly counted as discarded, never complete profiling.
            ok=row.enumerated<SAMPLE_LIMIT-SEGMENT_LIMIT && getTimer()-row.phaseStart<PHASE_LIMIT_MS;
            if(!ok)row.callbackAbort=true;
         }catch(error:*){note("callback",error);row.callbackAbort=true;}
         finally {row.callbackMs+=getTimer()-entered;insideCallback=false;}
         return ok;
      }
      private function pausePhase():void {
         try {
            row.pauseCall=getTimer();pauseSampling();row.paused=true;row.pauseReturned=getTimer();
            // The first operation after pause is a count; no aggregation/JSON in between.
            row.pauseCount=count();
         }catch(error:*){note("pause",error);}
         state="collect";
      }
      private function cleanup():void {
         row.cleanupStart=getTimer();
         try{stopSampling();row.stopped=true;}catch(error:*){note("stop",error);}
         try{clearSamples();row.cleared=count()==0;}catch(clearError:*){note("clear",clearError);}
         try{setSamplerCallback(null);row.callbackUnset=true;}catch(callbackError:*){note("unset callback",callbackError);}
         row.cleanupEnd=getTimer();
      }
      private function collectPhase():void {
         row.nextEnter=getTimer();
         try {
            row.nextEnterCount=count();row.finalSamples=enumerateSamples();
            if(row.callbackClears>0)row.postCallbackCpu+=row.finalSamples.cpu;
            row.retainedAcrossEvent=row.pauseCount>0?row.nextEnterCount>0:null;
            row.callbackSupported=phase==2 && row.callbackCalls>0 && row.callbackClears>0 && row.postCallbackCpu>0;
            row.callbackCoverage=phase!=2?"not-requested":(row.callbackCalls==0?"no-callback-observed":
               (row.callbackSupported?"observed-clear-and-new-cpu":"called-without-new-cpu-proof"));
         }catch(error:*){note("collection",error);}
         finally {cleanup();}
         row.elapsedMs=row.cleanupEnd-row.phaseStart;
         row.withinTimeLimit=row.elapsedMs<=PHASE_LIMIT_MS;
         var ordered:Boolean=row.startCall<=row.startReturned && row.startReturned<=row.workStart
            && row.workStart<=row.workEnd && row.workEnd<=row.pauseCall && row.pauseCall<=row.pauseReturned
            && row.pauseReturned<=row.nextEnter && row.nextEnter<=row.cleanupStart && row.cleanupStart<=row.cleanupEnd;
         row.clockOrdered=ordered;
         add(row.started && row.paused && row.stopped && row.cleared && row.callbackUnset && ordered && row.errorCount==0,
            row.name+": actual cross-event lifecycle and cleanup");
         add(row.withinTimeLimit && row.chunks>0 && row.chunks<=(phase==0?131072:MAX_CHUNKS)
            && row.objects<=(phase==0?0:MAX_CHUNKS*CHUNK_SIZE) && row.enumerated<=SAMPLE_LIMIT,
            row.name+": bounded work and enumeration");
         add(phase==0?(row.pauseCount>0 && row.workElapsed>=ARITHMETIC_MS && row.finalSamples!=null && row.finalSamples.cpu>0):
            (phase==1?row.callbackCalls==0:!row.callbackDepthError),
            row.name+": positive-control or callback-accounting prerequisite");
         if(!row.stopped || !row.cleared || !row.callbackUnset){finish();return;}
         // Release only the small live allocation ring after sampler teardown.
         for(var i:int=0;i<RING_SIZE;i++)ring[i]=null;
         phase++;if(phase>=3)finish();else{state="arm";stage.invalidate();}
      }
      private function add(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});}
      private function onEnter(event:Event):void {
         if(finished)return;
         if(state=="work")work();else if(state=="collect")collectPhase();else if(state=="arm")stage.invalidate();
      }
      private function onRender(event:Event):void {
         if(finished)return;
         if(state=="arm")startPhase();else if(state=="pause")pausePhase();
      }
      private function finish():void {
         if(finished)return;finished=true;
         stage.removeEventListener(Event.ENTER_FRAME,onEnter);stage.removeEventListener(Event.RENDER,onRender);
         var failed:int=0;for each(var assertion:Object in assertions)if(!assertion.passed)failed++;
         if(rows.length!=3 || assertions.length!=9){add(false,"all three phases completed");failed++;}
         var result:Object={kind:"sampler-retention-component-v1",appId:appId,gameLoaded:false,diagnosticOnly:true,
            performanceQualified:false,nativeBufferMemoryBounded:false,passed:failed==0,failed:failed,assertions:assertions,
            phases:rows,limits:{phaseMs:PHASE_LIMIT_MS,workMs:WORK_LIMIT_MS,objects:MAX_CHUNKS*CHUNK_SIZE,
               ring:RING_SIZE,enumeratedPerPhase:SAMPLE_LIMIT,enumeratedPerSegment:SEGMENT_LIMIT,callbacks:CALLBACK_LIMIT},
            interpretation:"PASS validates the bounded experiment, not callback support or absence of buffer exhaustion; inspect per-phase evidence"};
         var stream:FileStream=new FileStream();
         try {stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(result));}
         finally {stream.close();}
         NativeApplication.nativeApplication.exit(failed==0?0:1);
      }
   }
}
