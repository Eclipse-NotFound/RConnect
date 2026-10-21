package {
   import flash.desktop.NativeApplication;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** External diagnostic only. Each selected frame owns a separate sampler window. */
   public final class RoomInputCpuProfile {
      private static const MAX_WINDOWS:int=6,MAX_CPU:int=12000,MAX_STACKS:int=512;
      private static const MAX_DEPTH:int=24,MAX_NAME:int=192,MAX_NATIVE:int=250000;
      private static const MAX_MARKERS:int=64,MAX_FRAMES:int=256,MAX_WINDOW_MS:int=15000;
      private var stage:Stage,eligible:Function,context:Function,links:Dictionary=new Dictionary();
      private var armed:Boolean=false,stopped:Boolean=false,exported:Boolean=false;
      private var armAt:int=-1,stopAt:int=-1,stopReason:String="not-armed",frameNo:int=0,grantFrame:int=-1;
      private var selected:int=0,observed:int=0,skipped:int=0,unrecordedFrames:int=0,markerDropped:int=0;
      private var keptCpu:int=0,keptStacks:int=0,duplicateRenders:int=0;
      private var windows:Array=[],frames:Array=[],markers:Array=[];
      private var current:Object,lastClosed:Object;

      public function RoomInputCpuProfile(targetStage:Stage,canBegin:Function,readContext:Function) {
         stage=targetStage;eligible=canBegin;context=readContext;
         stage.addEventListener(Event.ENTER_FRAME,beginFrame,false,1000000);
         stage.addEventListener(Event.RENDER,endFrame,false,-2147483647);
      }
      public function watch(link:TcpLink):void {
         if(link==null || links[link])return;
         links[link]=true;link.addEventListener(TcpLink.MESSAGE,grantReturned,false,-200001);
      }
      private function grantReturned(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(armed || stopped || p.type!="room" || p.op!="grant" || String(p.key)!="random_mane//0,0,0" || !eligible())return;
         armed=true;armAt=getTimer();grantFrame=frameNo;stopReason="running";
         mark("grant-handler-returned");
      }
      private function readContext():Object {
         try{return context();}catch(error:*){return {unavailable:true};}
         return null;
      }
      private function invalidate(w:Object,reason:String):void {
         if(w.invalidReasons.indexOf(reason)<0)w.invalidReasons.push(reason);
      }
      private function beginFrame(e:Event):void {
         frameNo++;
         if(!armed || stopped)return;
         // A second ENTER closes the actual elapsed range, never invents RENDER.
         if(current!=null)closeWindow("missing-render",true);
         if(getTimer()-armAt>MAX_WINDOW_MS){stop("diagnostic-window-cap");return;}
         observed++;
         var take:Boolean=selected<MAX_WINDOWS;
         var row:Object={frame:frameNo,t:getTimer(),selected:take,window:take?selected:-1,
            reason:take?"selected-first-six":"selection-cap",context:readContext()};
         if(frames.length<MAX_FRAMES)frames.push(row);else unrecordedFrames++;
         if(!take){skipped++;return;}
         var w:Object={id:selected++,frame:frameNo,startAt:getTimer(),endAt:-1,startNative:0,endNative:0,
            beginCostMs:0,closeCostMs:0,scanCostMs:0,nativeScanned:0,nativeScanComplete:false,
            cpuDropped:0,stackTruncated:false,stack_tail_truncated:false,complete_stack_capture:false,
            nativeTruncated:false,duplicateRenders:0,
            contextStart:row.context,contextEnd:null,closeReason:"open",
            usable_cpu:false,partial_window:false,completed_render_window:false,
            invalidReasons:[],cpuRows:[],stacks:[],stack_tails:[],lastNative:0};
         windows.push(w);current=w;lastClosed=null;
         try {
            clearSamples();sampleInternalAllocs(false);startSampling();
            w.startNative=getSampleCount();w.lastNative=w.startNative;
         } catch(error:*) {invalidate(w,"sampler-start");closeWindow("start-failed",false);}
         w.beginCostMs=getTimer()-int(w.startAt);
      }
      private function endFrame(e:Event):void {
         if(!armed || stopped)return;
         if(current!=null){closeWindow("render",true);return;}
         // Multiple RENDER broadcasts in one game frame never reopen/scan it.
         if(lastClosed!=null && int(lastClosed.frame)==frameNo) {
            duplicateRenders++;lastClosed.duplicateRenders++;
         }
      }
      private function closeWindow(reason:String,allowRead:Boolean):void {
         var w:Object=current;if(w==null)return;current=null;lastClosed=w;
         var closing:int=getTimer();w.endAt=closing;w.closeReason=reason;
         try {
            pauseSampling();w.endNative=getSampleCount();
            if(Number(w.endNative)<Number(w.lastNative))invalidate(w,"native-count-regressed");
            if(closing-int(w.startAt)>MAX_WINDOW_MS)invalidate(w,"window-time-cap");
            if(!allowRead)invalidate(w,reason);
            if(Number(w.endNative)>MAX_NATIVE){w.nativeTruncated=true;invalidate(w,"native-scan-cap");}
            if(allowRead && w.invalidReasons.length==0)scan(w);
         } catch(error:*) {invalidate(w,"sampler-close");}
         finally {
            // No sampler survives into the next selected frame or cleanup.
            try{stopSampling();clearSamples();}catch(ignored:*){invalidate(w,"sampler-stop");}
         }
         w.contextEnd=readContext();
         if(w.cpuRows.length==0)invalidate(w,"no-cpu-samples");
         w.usable_cpu=w.invalidReasons.length==0;
         w.completed_render_window=w.usable_cpu && reason=="render";
         w.partial_window=w.usable_cpu && (reason=="missing-render" || reason=="stop-before-render");
         w.complete_stack_capture=w.usable_cpu && !w.stack_tail_truncated;
         if(w.usable_cpu){keptCpu+=w.cpuRows.length;keptStacks+=w.stacks.length;}
         else {w.cpuRows=[];w.stacks=[];w.stack_tails=[];}
         w.closeCostMs=getTimer()-closing;
      }
      private function scan(w:Object):void {
         var began:int=getTimer(),seen:int=0,ids:Object={},rows:Array=[],namesById:Array=[],tailsById:Array=[];
         var remainingCpu:int=MAX_CPU-keptCpu,remainingStacks:int=MAX_STACKS-keptStacks;
         try {
            for each(var sample:Sample in getSamples()) {
               if(seen>=MAX_NATIVE){w.nativeTruncated=true;invalidate(w,"native-scan-cap");break;}
               var ordinal:int=seen++;
               if(sample is NewObjectSample || sample is DeleteObjectSample)continue;
               if(rows.length>=remainingCpu){w.cpuDropped++;invalidate(w,"cpu-cap");continue;}
               var names:Array=[],depth:int=0,tail:Boolean=false;
               if(sample.stack!=null)for each(var f:StackFrame in sample.stack) {
                  // Only outer callers are omitted; the native buffer and visible leaf remain valid.
                  if(depth++>=MAX_DEPTH){tail=true;w.stack_tail_truncated=true;break;}
                  var name:String=String(f.name);
                  if(name.length>MAX_NAME){name=name.substr(0,MAX_NAME);w.stackTruncated=true;invalidate(w,"stack-name-cap");}
                  names.push(name);
               }
               var key:String=(tail?"$tail:":"$full:")+JSON.stringify(names),id:int;
               if(ids.hasOwnProperty(key))id=int(ids[key]);
               else if(namesById.length<remainingStacks){id=namesById.length;ids[key]=id;namesById.push(names);tailsById.push(tail);}
               else {w.stackTruncated=true;invalidate(w,"stack-count-cap");continue;}
               var stamp:Number=Number(sample.time);
               if(!isFinite(stamp) || stamp<0){invalidate(w,"sample-time-invalid");continue;}
               rows.push([ordinal,stamp,id]);
            }
         } catch(error:*) {invalidate(w,"sampler-enumeration");}
         w.nativeScanned=seen;w.nativeScanComplete=seen==Number(w.endNative);
         if(!w.nativeScanComplete)invalidate(w,"native-enumeration-count");
         w.cpuRows=rows;w.stacks=namesById;w.stack_tails=tailsById;w.scanCostMs=getTimer()-began;
      }
      public function frame():void {mark("driver-frame");}
      public function mark(label:String,originalClock:int=-1):void {
         if(!armed || stopped)return;
         if(markers.length>=MAX_MARKERS){markerDropped++;return;}
         var count:Number=-1;
         if(current!=null)try {
            count=getSampleCount();
            if(count<Number(current.lastNative))invalidate(current,"native-count-regressed");
            current.lastNative=count;
         }catch(error:*){invalidate(current,"sampler-count");}
         markers.push({label:label,t:getTimer(),originalClock:originalClock,frame:frameNo,
            window:current!=null?int(current.id):-1,nativeCount:count,context:readContext()});
      }
      public function stop(why:String):void {
         if(stopped)return;
         mark("capture-stop");stopAt=getTimer();stopReason=why;
         // Keep intact CPU evidence through this actual stop; no final RENDER.
         if(current!=null)closeWindow("stop-before-render",true);
         stopped=true;
      }
      public function finish():void {
         if(exported)return;exported=true;stop("fixture-finish");
         stage.removeEventListener(Event.ENTER_FRAME,beginFrame);stage.removeEventListener(Event.RENDER,endFrame);
         for(var item:Object in links)item.removeEventListener(TcpLink.MESSAGE,grantReturned);
         links=new Dictionary();
         var report:Object={schema:3,diagnosticOnly:true,performanceQualified:false,
            applicationId:NativeApplication.nativeApplication.applicationID,role:"join",round:0,
            armed:armed,armAt:armAt,grantFrame:grantFrame,stopAt:stopAt,stopReason:stopReason,
            origin:"first six ENTER_FRAME windows after round0 target grant handlers return; grant itself excluded",
            observedFrames:observed,selectedWindows:selected,skippedFrames:skipped,unrecordedFrames:unrecordedFrames,
            duplicateRenders:duplicateRenders,markerDropped:markerDropped,cpuKept:keptCpu,stacksKept:keptStacks,
            windows:windows,frames:frames,markers:markers,
            caps:{windows:MAX_WINDOWS,cpu:MAX_CPU,stacks:MAX_STACKS,depth:MAX_DEPTH,name:MAX_NAME,
               nativePerWindow:MAX_NATIVE,markers:MAX_MARKERS,frames:MAX_FRAMES,windowMs:MAX_WINDOW_MS},
            sampleTime:"raw Sample.time microseconds; no offset to getTimer is assumed",
            ordinalMeaning:"per-window native index; reset each ENTER_FRAME, never compare across windows",
            countsAreNotDurations:true,allocationClassesExported:false,samplerCallbackUsed:false};
         var file:File=File.applicationStorageDirectory.resolvePath("room-input-cpu-frames-partial.json");
         var stream:FileStream=new FileStream();
         try {
            stream.open(file,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(report));stream.close();
            Log.d("SCENE INPUT CPU FRAMES FILE "+JSON.stringify({file:file.name,windows:windows.length,
               usableCpu:keptCpu,reason:stopReason,diagnosticOnly:true}));
         }catch(error:*) {try{stream.close();}catch(ignored:*){}
            Log.d("COOP FAIL travel-timing CPU frame diagnostic export unavailable");}
      }
   }
}
