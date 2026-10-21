package {
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** External, join-only diagnostic. No simulation or control writes. */
   public final class RoomInputCpuProfile {
      private static const MAX_CPU:int=12000,MAX_STACKS:int=512,MAX_DEPTH:int=24,MAX_NAME:int=192;
      private static const MAX_NATIVE_PER_DRAIN:int=250000,MAX_MARKERS:int=64,MAX_WINDOW_MS:int=15000;
      private var eligible:Function,context:Function,links:Dictionary=new Dictionary();
      private var started:Boolean=false,running:Boolean=false,exported:Boolean=false;
      private var startedAt:int=-1,stoppedAt:int=-1,reason:String="not-started",fault:String="";
      private var grantEvent:NetMessageEvent;
      private var nativeBase:Number=0,drains:int=0,callbackDrains:int=0,cpuDropped:int=0;
      private var nativeTruncated:Boolean=false,stackTruncated:Boolean=false,markerTruncated:Boolean=false;
      private var cpu:Array=[],stacks:Array=[],stackIds:Object={},markers:Array=[];

      public function RoomInputCpuProfile(canBegin:Function,readContext:Function) {
         eligible=canBegin;context=readContext;
      }
      public function watch(link:TcpLink):void {
         if(link==null || links[link])return;
         links[link]=true;
         link.addEventListener(TcpLink.MESSAGE,before,false,200001);
         link.addEventListener(TcpLink.MESSAGE,after,false,-200001);
      }
      private function before(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(started || p.type!="room" || p.op!="grant" || String(p.key)!="random_mane//0,0,0" || !eligible())return;
         started=true;startedAt=getTimer();grantEvent=e;reason="running";
         try {
            clearSamples();sampleInternalAllocs(false);
            // The VM pauses around this callback. Drain then clear the native
            // buffer; retained CPU rows and stack strings have explicit caps.
            setSamplerCallback(bufferFull);startSampling();running=true;
            mark("grant-handler-before");
         }catch(error:*){fault="sampler-start";reason="sampler-unavailable";running=false;}
      }
      private function after(e:NetMessageEvent):void {
         if(e!==grantEvent)return;
         mark("grant-handler-returned");grantEvent=null;
      }
      public function frame():void {
         if(!running)return;
         mark("driver-frame");
         if(getTimer()-startedAt>MAX_WINDOW_MS)stop("diagnostic-window-cap");
      }
      public function mark(label:String,originalClock:int=-1):void {
         if(!running)return;
         if(markers.length>=MAX_MARKERS){markerTruncated=true;return;}
         markers.push({label:label,t:getTimer(),originalClock:originalClock,
            nativeOrdinal:nativeBase+getSampleCount(),context:context()});
      }
      private function bufferFull():void {
         // No file IO, logs, object/type inspection, or game calls here.
         callbackDrains++;
         try{drain();}catch(error:*){fault="sampler-buffer-drain";nativeTruncated=true;}
         finally{clearSamples();}
      }
      private function drain():void {
         var count:Number=getSampleCount(),seen:int=0;
         drains++;
         for each(var sample:Sample in getSamples()) {
            if(seen>=MAX_NATIVE_PER_DRAIN){nativeTruncated=true;break;}
            var ordinal:Number=nativeBase+seen;seen++;
            // Only CPU Sample stacks are retained. Never inspect type/object,
            // class name, size, or stack of allocation/deletion samples.
            if(sample is NewObjectSample || sample is DeleteObjectSample)continue;
            if(cpu.length>=MAX_CPU){cpuDropped++;continue;}
            var names:Array=[],depth:int=0;
            if(sample.stack!=null)for each(var f:StackFrame in sample.stack) {
               if(depth++>=MAX_DEPTH){stackTruncated=true;break;}
               var name:String=String(f.name);
               if(name.length>MAX_NAME){name=name.substr(0,MAX_NAME);stackTruncated=true;}
               names.push(name);
            }
            // Prefix prevents Object prototype names from becoming lookup hits.
            var key:String="$"+JSON.stringify(names),id:int;
            if(stackIds.hasOwnProperty(key))id=int(stackIds[key]);
            else if(stacks.length<MAX_STACKS){id=stacks.length;stackIds[key]=id;stacks.push(names);}
            else {id=-1;stackTruncated=true;}
            cpu.push([ordinal,Number(sample.time),id]);
         }
         nativeBase+=count;
      }
      public function stop(why:String):void {
         if(!running)return;
         mark("capture-stop");stoppedAt=getTimer();reason=why;running=false;
         pauseSampling();setSamplerCallback(null);
         // Keep the paused native buffer intact until the original test ends.
         // Enumeration/serialization/file IO therefore cannot prolong the
         // original 1000 ms input window or the next two travel measurements.
      }
      public function finish():void {
         if(exported)return;exported=true;
         stop("fixture-finish");
         try {if(started){pauseSampling();drain();stopSampling();clearSamples();setSamplerCallback(null);}}
         catch(error:*){fault="sampler-drain";}
         for(var item:Object in links) {
            item.removeEventListener(TcpLink.MESSAGE,before);
            item.removeEventListener(TcpLink.MESSAGE,after);
         }
         links=new Dictionary();grantEvent=null;
         var report:Object={schema:1,diagnosticOnly:true,performanceQualified:false,
            applicationId:NativeApplication.nativeApplication.applicationID,role:"join",round:0,
            started:started,startAt:startedAt,stopAt:stoppedAt,stopReason:reason,fault:fault,
            origin:"before first round0 target room grant MESSAGE handlers; TCP decode before MESSAGE excluded",
            cpuRows:cpu,stacks:stacks,markers:markers,nativeEntries:nativeBase,drains:drains,callbackDrains:callbackDrains,
            cpuDropped:cpuDropped,nativeTruncated:nativeTruncated,stackTruncated:stackTruncated,markerTruncated:markerTruncated,
            caps:{cpu:MAX_CPU,stacks:MAX_STACKS,depth:MAX_DEPTH,name:MAX_NAME,
               nativePerDrain:MAX_NATIVE_PER_DRAIN,markers:MAX_MARKERS,windowMs:MAX_WINDOW_MS},
            sampleTime:"raw Sample.time microseconds; no unverified offset to getTimer is applied",
            ordinalMeaning:"zero-based native sample index; markers count prior native entries, not CPU samples",
            countsAreNotDurations:true,allocationClassesExported:false};
         var file:File=File.applicationStorageDirectory.resolvePath("room-input-cpu-profile.json");
         var stream:FileStream=new FileStream();
         try {
            stream.open(file,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(report));stream.close();
            // Stack text stays in JSON, outside runtime error-log matching.
            Log.d("SCENE INPUT CPU FILE "+JSON.stringify({file:file.name,cpu:cpu.length,stacks:stacks.length,
               startAt:startedAt,stopAt:stoppedAt,reason:reason,diagnosticOnly:true}));
         }catch(error:*) {try{stream.close();}catch(ignored:*){}
            Log.d("COOP FAIL travel-timing CPU diagnostic export unavailable");}
      }
   }
}
