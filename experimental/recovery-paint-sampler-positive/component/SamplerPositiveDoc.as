package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /** One real CPU-sampler positive control; no game or other profiler is loaded. */
   public final class SamplerPositiveDoc extends Sprite {
      private static const TARGET_MS:int=150,MAX_CHUNKS:int=131072,CHUNK_SIZE:int=256,SAMPLE_LIMIT:int=32768;
      private var ran:Boolean=false,checksum:uint=0x6d2b79f5;
      public function SamplerPositiveDoc() {
         if(stage!=null)arm();else addEventListener(Event.ADDED_TO_STAGE,added);
      }
      private function added(event:Event):void {removeEventListener(Event.ADDED_TO_STAGE,added);arm();}
      private function arm():void {addEventListener(Event.ENTER_FRAME,run);}
      // The result is retained in the final JSON, so the arithmetic is observable.
      private function computeChunk(value:uint):uint {
         for(var i:int=0;i<CHUNK_SIZE;i++) {
            value^=value<<13;value^=value>>>17;value^=value<<5;
            value=uint(value+0x9e3779b9+i);
         }
         return value;
      }
      private function run(event:Event):void {
         if(ran)return;ran=true;removeEventListener(Event.ENTER_FRAME,run);
         var api:FlashPaintTailSampler=new FlashPaintTailSampler(true),token:Object={};
         var r:Object={kind:"real-paint-sampler-positive",diagnosticOnly:true,performanceQualified:false,
            gameLoaded:false,targetMs:TARGET_MS,maxChunks:MAX_CHUNKS,chunkSize:CHUNK_SIZE,sampleLimit:SAMPLE_LIMIT,
            chunks:0,iterations:0,checksum:0,workElapsed:0,totalSamples:0,visited:0,cpu:0,allocations:0,deletions:0,
            truncated:false,examples:[],errors:[],operations:[],clocks:{},claimed:false,started:false,paused:false,
            stopped:false,cleared:false,released:false};
         try {
            r.operations.push("claim");r.claimed=api.claim(token);
            if(!r.claimed)throw new Error("sampler lease unavailable");
            r.operations.push("clear");api.clear(token);
            r.operations.push("internalAllocs(false)");api.internalAllocs(token,false);
            r.clocks.startCall=api.now();r.clocks.startWall=api.wall();
            r.operations.push("start");api.start(token);r.started=true;r.clocks.startReturned=api.now();
            r.clocks.workStart=api.now();
            for(var chunk:int=0;chunk<MAX_CHUNKS;chunk++) {
               checksum=computeChunk(checksum);r.chunks++;
               if(api.now()-r.clocks.workStart>=TARGET_MS)break;
            }
            r.clocks.workEnd=api.now();r.workElapsed=r.clocks.workEnd-r.clocks.workStart;
            r.iterations=r.chunks*CHUNK_SIZE;r.checksum=checksum;
            r.clocks.pauseCall=api.now();r.clocks.pauseWall=api.wall();
            r.operations.push("pause");api.pause(token);r.paused=true;r.clocks.pauseReturned=api.now();
            // Count and enumeration both occur before stop/clear, while paused.
            r.clocks.collectStart=api.now();r.operations.push("count");r.totalSamples=api.count(token);
            r.operations.push("enumerate");
            for each(var sample:Object in api.samples(token)) {
               if(r.visited>=SAMPLE_LIMIT){r.truncated=true;break;}
               r.visited++;
               var kind:int=api.kind(token,sample);
               if(kind==1){r.allocations++;continue;}
               if(kind==2){r.deletions++;continue;}
               if(kind!=0)throw new Error("unexpected sample kind");
               r.cpu++;
               if(r.examples.length<4) {
                  var names:Array=[],frames:Object=api.stack(token,sample);
                  if(frames!=null)for each(var frame:Object in frames) {
                     if(names.length>=8)break;
                     names.push(String(frame.name).substr(0,128)+"@"+String(frame.file).substr(0,128)+":"+String(frame.line));
                  }
                  r.examples.push(names);
               }
            }
            if(r.totalSamples>r.visited)r.truncated=true;
            r.clocks.collectEnd=api.now();
         }catch(error:*) {r.errors.push(String(error).substr(0,512));}
         // Explicit cleanup also runs after partial start/pause/collection errors.
         // Never stop another owner's sampler, or release an uncleared sampler.
         if(r.claimed && api.owns(token)) {
            r.clocks.cleanupStart=api.now();
            try {r.operations.push("stop");api.stop(token);r.stopped=true;}
            catch(stopError:*) {r.errors.push("stop: "+String(stopError).substr(0,256));}
            if(r.stopped)try {r.operations.push("clear");api.clear(token);r.cleared=true;}
            catch(clearError:*) {r.errors.push("clear: "+String(clearError).substr(0,256));}
            if(r.stopped && r.cleared)try {r.operations.push("release");api.release(token);r.released=!api.owns(token);}
            catch(releaseError:*) {r.errors.push("release: "+String(releaseError).substr(0,256));}
            r.clocks.cleanupEnd=api.now();
         }
         var c:Object=r.clocks;
         var ordered:Boolean=c.startCall<=c.startReturned && c.startReturned<=c.workStart && c.workStart<=c.workEnd
            && c.workEnd<=c.pauseCall && c.pauseCall<=c.pauseReturned && c.pauseReturned<=c.collectStart
            && c.collectStart<=c.collectEnd && c.collectEnd<=c.cleanupStart && c.cleanupStart<=c.cleanupEnd
            && c.startWall<=c.pauseWall;
         var ok:Boolean=r.errors.length==0 && r.claimed && r.started && r.paused && r.stopped && r.cleared && r.released
            && ordered && r.workElapsed>=TARGET_MS && r.chunks>0 && r.chunks<=MAX_CHUNKS
            && !r.truncated && r.totalSamples==r.visited && r.visited==r.cpu+r.allocations+r.deletions && r.cpu>0;
         r.clockOrdered=ordered;r.passed=ok;r.failed=ok?0:1;
         r.assertions=[{passed:ok,label:"real sampler returns CPU samples during bounded AS computation; paused count/enumeration and cleanup complete"}];
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(r));stream.close();
         NativeApplication.nativeApplication.exit(ok?0:1);
      }
   }
}
