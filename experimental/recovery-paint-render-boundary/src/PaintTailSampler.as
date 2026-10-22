package {
   import flash.events.Event;
   import flash.events.IEventDispatcher;

   /** External diagnostic only. The injected adapter owns every sampler operation.
    * observe is called AFTER the existing aggregate observer, never installed
    * into Grafon's slot by this class. No game/ticket/renderer writes or logs. */
   public final class PaintTailSampler {
      public static const SEGMENTS:int=3, SAMPLE_LIMIT:int=32768, STACK_LIMIT:int=1024;
      public static const DEPTH_LIMIT:int=64, TEXT_LIMIT:int=262144, FRAME_TEXT_LIMIT:int=512;
      private var api:Object,token:Object={},stage:IEventDispatcher,slotOwned:Function;
      private var world:Object,game:Object,renderer:Object,room:Object;
      private var row:Object,rows:Array=[],segment:int=-1,enterSequence:int=0;
      private var pending:Boolean=false,disposed:Boolean=false,blocked:Boolean=false;
      private var globalFaults:int=0;
      private static const RENDER_LIMIT:int=16,RENDER_HIGH:int=2147483647,RENDER_LOW:int=-2147483648;
      private var renderAttached:Boolean=false,renderFaults:int=0,renderSerial:int=0;
      private var lastRenderT:int=-1,lastRenderWall:Number=NaN,lastRenderPhase:String="";

      /** slotOwner must only check the existing observer's exact Function identity.
       * The real adapter must be admitted as the only sampler in this AIR process. */
      public function PaintTailSampler(adapter:Object,slotOwner:Function) {api=adapter;slotOwned=slotOwner;}
      public function attach(value:IEventDispatcher):Boolean {
         if(disposed || stage!=null || value==null){globalFaults++;return false;}
         var attached:Boolean=false;
         try {value.addEventListener(Event.ENTER_FRAME,onEnter,false,1000000);stage=value;attached=true;}
         catch(error:*){globalFaults++;}
         if(attached)attachRender(value);
         return attached;
      }
      private function attachRender(value:IEventDispatcher):void {
         try {
            value.addEventListener(Event.RENDER,onRenderHigh,false,RENDER_HIGH);
            value.addEventListener(Event.RENDER,onRenderLow,false,RENDER_LOW);
            renderAttached=true;
         }catch(error:*) {renderFaults++;detachRender(value);}
      }
      private function detachRender(value:IEventDispatcher):void {
         try {value.removeEventListener(Event.RENDER,onRenderHigh);}catch(error:*){renderFaults++;}
         try {value.removeEventListener(Event.RENDER,onRenderLow);}catch(error:*){renderFaults++;}
         renderAttached=false;
      }
      private function onRenderHigh(event:Event):void {markRender(event,"high");}
      private function onRenderLow(event:Event):void {markRender(event,"low");}
      private function markRender(event:Event,phase:String):void {
         // Both marks precede actual display-list rendering. Never invalidate here.
         // No events is unavailable evidence, not proof that rendering did not run.
         var boundary:Object=row==null?null:row.renderBoundary;
         try {
            var at:Object=stamp();
            if(event.currentTarget!==stage || (lastRenderT>=0 && (at.t<lastRenderT || at.wall<lastRenderWall)))
               throw new Error("render target/clock mismatch");
            lastRenderT=at.t;lastRenderWall=at.wall;lastRenderPhase=phase;renderSerial++;
            if(boundary==null)return;
            if(pending) {
               boundary.available=true;boundary.observed++;
               if(boundary.marks.length>=RENDER_LIMIT){boundary.incomplete=true;boundary.overflow++;return;}
               boundary.marks.push({phase:phase,t:at.t,wall:at.wall,serial:renderSerial,enter:enterSequence});
            }else if(row.closed && row.triggered && row.clocks.stop!=null && boundary.afterStop==null) {
               boundary.afterStop={phase:phase,t:at.t,wall:at.wall,serial:renderSerial,enter:enterSequence};
            }
         }catch(error:*) {
            renderFaults++;
            if(boundary!=null){boundary.incomplete=true;boundary.faults++;}
         }
      }
      public function begin(w:Object):Boolean {
         if(disposed || blocked || segment>=SEGMENTS-1){globalFaults++;return false;}
         finish("segment-change");
         if(blocked){globalFaults++;return false;}
         segment++;
         row={segment:segment,triggered:false,claimed:false,started:false,closed:false,reason:"not-triggered",
            complete:false,diagnosticOnly:true,performanceQualified:false,eligibleCalls:0,
            samplingComplete:false,cpuEvidenceAvailable:false,cpuEvidenceComplete:false,
            observeCalls:0,errors:[],clocks:{},startStage:-1,stopStage:-1,
            ownerPreserved:true,identityPreserved:true,slotPreserved:true,cleanupComplete:true,
            totalSamples:0,visited:0,cpu:0,allocationsSkipped:0,deletionsSkipped:0,
            sampleTruncated:false,stackOverflow:0,depthTruncated:0,textTruncated:0,
            textOverflow:0,stackTextChars:0,uniqueStacks:0,stacks:{},collectMs:0,cleanupMs:0};
         row.renderBoundary={attached:renderAttached,limit:RENDER_LIMIT,available:false,
            incomplete:!renderAttached,overflow:0,observed:0,faults:0,marks:[],afterStop:null,
            beforeBegin:lastRenderT<0?null:{phase:lastRenderPhase,t:lastRenderT,wall:lastRenderWall,serial:renderSerial},
            highPriority:RENDER_HIGH,lowPriority:RENDER_LOW,
            scope:"Same Stage RENDER listeners only; both before native pixel rendering; no forced invalidate"};
         rows.push(row);world=w;room=null;
         try {game=w==null?null:w.game;renderer=w==null?null:w.grafon;}
         catch(error:*){fault("begin-identity",error);game=renderer=null;}
         return true;
      }
      public function bind(w:Object,l:Object,g:Object):void {
         if(row==null || row.closed)return;
         try {
            if(w!==world || w.game!==game || g!==renderer || l==null || (room!=null && room!==l)) {
               row.identityPreserved=false;fault("raster-binding",null);return;
            }
            room=l;
         }catch(error:*){row.identityPreserved=false;fault("raster-binding",error);}
      }
      public function observe(g:Object,w:Object,gameValue:Object,l:Object,v:Object):void {
         if(row==null || row.closed)return;
         row.observeCalls++;
         try {
            if(v==null || v.phase!=="ensure-work" || v.completed!==true)return;
            if(!integer(v.residentBefore) || !integer(v.residentAfter)) {fault("resident-metadata",null);return;}
            if(Number(v.residentBefore)!=0 || Number(v.residentAfter)<=0)return;
            row.eligibleCalls++;
            if(row.triggered)return;
            // Only the room bound by the real raster bridge may start a window.
            if(room==null || l!==room || w!==world || gameValue!==game || g!==renderer)return;
            if(v.sameWorld!==true || v.sameGame!==true || v.sameLoc!==true
               || v.worldRendererAtStart!==true || v.worldRendererAtEnd!==true
               || v.worldLocAtStart!==true || v.worldLocAtEnd!==true || !identity()) {
               row.identityPreserved=false;fault("ensure-identity",null);return;
            }
            if(!integer(v.started) || !integer(v.finished) || v.finished<v.started
               || !finite(v.startedWall) || !finite(v.finishedWall) || v.finishedWall<v.startedWall) {
               fault("ensure-clock",null);return;
            }
            if(!ownsSlot()){row.slotPreserved=false;fault("observer-ownership",null);return;}
            row.triggered=true;row.reason="starting";row.startStage=enterSequence;
            row.ensure={started:v.started,finished:v.finished,startedWall:v.startedWall,
               finishedWall:v.finishedWall,initial:v.initial===true,preload:v.preload===true,
               residentBefore:v.residentBefore,residentAfter:v.residentAfter};
            row.clocks.observed=stamp();
            if(row.clocks.observed.t<v.finished || row.clocks.observed.wall<v.finishedWall)
               throw new Error("observer clock precedes ensure completion");
            if(stage==null)throw new Error("stage listener unavailable");
            if(!api.claim(token)) {row.ownerPreserved=false;row.reason="sampler-conflict";row.closed=true;return;}
            row.claimed=true;row.cleanupComplete=false;
            row.clocks.setupStart=stamp();api.clear(token);api.internalAllocs(token,false);
            row.clocks.setupEnd=stamp();row.clocks.startCall=stamp();
            // A throwing start may have partly started: cancellation still owns cleanup.
            pending=true;api.start(token);row.started=true;row.clocks.startReturned=stamp();
            row.reason="sampling";
         }catch(error:*) {
            fault("start",error);
            if(row!=null && row.triggered)close("start-error");
         }
      }
      private function onEnter(event:Event):void {
         enterSequence++;
         if(!pending)return;
         close("next-stage-enter");
      }
      private function finite(value:*):Boolean {return value is Number && isFinite(Number(value));}
      private function integer(value:*):Boolean {return finite(value) && Number(value)>=0 && Number(value)==int(value);}
      private function stamp():Object {
         var t:*=api.now(),wall:*=api.wall();
         if(!integer(t) || !finite(wall))throw new Error("invalid clock");
         return {t:int(t),wall:Number(wall)};
      }
      private function identity():Boolean {
         return world!=null && game!=null && renderer!=null && room!=null
            && world.game===game && world.grafon===renderer && world.loc===room && renderer.loc===room;
      }
      private function ownsSlot():Boolean {return slotOwned!=null && slotOwned()===true;}
      private function owns():Boolean {
         var owned:Boolean=false;
         try {owned=api.owns(token)===true;}catch(error:*){fault("ownership-query",error);}
         return owned;
      }
      private function fault(where:String,error:*):void {
         if(row==null){globalFaults++;return;}
         // No arbitrary Error/stack object retention; at most eight short fault strings.
         var detail:String="";
         try {if(error!=null)detail=": "+String(error).substr(0,256);}catch(ignored:*){detail=": <unprintable>";}
         if(row.errors.length<8)row.errors.push(where+detail);
         else row.extraErrors=int(row.extraErrors)+1;
         row.complete=false;row.samplingComplete=false;row.cpuEvidenceComplete=false;
      }
      private function close(reason:String):void {
         if(row==null || row.closed)return;
         var paused:Boolean=false;
         // The first stamp precedes ownership/identity inspection and enumeration.
         try {row.clocks.stop=stamp();}catch(error:*){fault("stop-clock",error);}
         row.stopStage=enterSequence;row.reason=reason;row.closed=true;pending=false;
         if(!row.claimed)return;
         if(!owns()) {row.ownerPreserved=false;blocked=true;fault("sampler-ownership-lost",null);return;}
         try {api.pause(token);paused=true;row.clocks.pauseReturned=stamp();}
         catch(error:*){fault("pause",error);}
         try {
            row.clocks.collectStart=stamp();
            row.identityPreserved=row.identityPreserved && identity();
            row.slotPreserved=row.slotPreserved && ownsSlot();
            if(!row.identityPreserved)fault("end-identity",null);
            if(!row.slotPreserved)fault("end-observer-ownership",null);
            if(paused && row.started)collect();
         }catch(error:*){fault("collect",error);}
         cleanup();
         try {
            row.clocks.collectEnd=stamp();
            row.collectMs=row.clocks.collectEnd.t-row.clocks.collectStart.t;
            var c:Object=row.clocks;
            var ordered:Boolean=c.startReturned!=null && c.stop!=null && c.pauseReturned!=null
               && row.ensure.finished<=c.observed.t && c.observed.t<=c.setupStart.t
               && c.setupStart.t<=c.setupEnd.t && c.setupEnd.t<=c.startCall.t && c.startCall.t<=c.startReturned.t
               && c.startReturned.t<=c.stop.t && c.stop.t<=c.pauseReturned.t
               && c.pauseReturned.t<=c.collectStart.t && c.collectStart.t<=c.collectEnd.t
               && row.ensure.finishedWall<=c.observed.wall && c.observed.wall<=c.setupStart.wall
               && c.setupStart.wall<=c.setupEnd.wall && c.setupEnd.wall<=c.startCall.wall
               && c.startCall.wall<=c.startReturned.wall && c.startReturned.wall<=c.stop.wall
               && c.stop.wall<=c.pauseReturned.wall && c.pauseReturned.wall<=c.collectStart.wall
               && c.collectStart.wall<=c.collectEnd.wall;
            row.clockOrdered=ordered;
            row.complete=reason=="next-stage-enter" && row.started && paused && ordered
               && row.stopStage==row.startStage+1 && row.ownerPreserved && row.identityPreserved
               && row.slotPreserved && row.cleanupComplete && row.errors.length==0;
            row.samplingComplete=row.complete && !row.sampleTruncated && row.stackOverflow==0
               && row.depthTruncated==0 && row.textTruncated==0 && row.textOverflow==0;
            row.cpuEvidenceAvailable=row.cpu>0;
            row.cpuEvidenceComplete=row.samplingComplete && row.cpu>0;
         }catch(error:*){fault("finish-clock",error);}
      }
      private function collect():void {
         row.totalSamples=api.count(token);
         if(!integer(row.totalSamples))throw new Error("invalid sample count");
         for each(var sample:Object in api.samples(token)) {
            if(row.visited>=SAMPLE_LIMIT){row.sampleTruncated=true;break;}
            row.visited++;
            var kind:int=api.kind(token,sample);
            if(kind==1){row.allocationsSkipped++;continue;}
            if(kind==2){row.deletionsSkipped++;continue;}
            if(kind!=0)throw new Error("unknown sample kind");
            row.cpu++;
            var names:Array=[],frames:Object=api.stack(token,sample);
            if(frames!=null)for each(var frame:Object in frames) {
               if(names.length>=DEPTH_LIMIT){row.depthTruncated++;break;}
               var text:String=String(frame.name)+"@"+String(frame.file)+":"+String(frame.line);
               if(text.length>FRAME_TEXT_LIMIT){text=text.substr(0,FRAME_TEXT_LIMIT);row.textTruncated++;}
               names.push(text);
            }
            var key:String=names.length?names.join(" <- "):"<no-stack>";
            if(!row.stacks.hasOwnProperty(key)) {
               if(row.uniqueStacks>=STACK_LIMIT){row.stackOverflow++;continue;}
               if(row.stackTextChars+key.length>TEXT_LIMIT){row.textOverflow++;continue;}
               row.uniqueStacks++;row.stackTextChars+=key.length;
            }
            row.stacks[key]=int(row.stacks[key])+1;
         }
         if(row.visited>row.totalSamples || (row.totalSamples>row.visited && row.visited<SAMPLE_LIMIT))
            throw new Error("paused sample count disagrees with enumeration");
         if(row.totalSamples>row.visited)row.sampleTruncated=true;
      }
      private function cleanup():void {
         if(!owns()){row.ownerPreserved=false;row.cleanupComplete=false;blocked=true;return;}
         try {row.clocks.cleanupStart=stamp();}catch(error:*){fault("cleanup-clock",error);}
         var stopped:Boolean=false,cleared:Boolean=false;
         try {api.stop(token);stopped=true;}catch(error:*){fault("stop",error);}
         if(stopped)try {api.clear(token);cleared=true;}catch(error:*){fault("clear",error);}
         // Never release a possibly-running or uncleared sampler to a new window.
         if(stopped && cleared)try {api.release(token);}catch(error:*){fault("release",error);}
         row.cleanupComplete=stopped && cleared && !owns();blocked=!row.cleanupComplete;
         try {row.clocks.cleanupEnd=stamp();row.cleanupMs=row.clocks.cleanupEnd.t-row.clocks.cleanupStart.t;}
         catch(error:*){fault("cleanup-clock",error);}
      }
      public function finish(reason:String="finish"):Object {
         if(row==null)return null;
         if(!row.closed) {
            if(row.triggered)close(reason);
            else {row.closed=true;row.reason="not-triggered";row.finishReason=reason;}
         }
         var result:Object=row;row=null;world=game=renderer=room=null;return result;
      }
      public function dispose():Object {
         if(!disposed) {
            finish("dispose");
            if(stage!=null)try {stage.removeEventListener(Event.ENTER_FRAME,onEnter);}
            catch(error:*){globalFaults++;}
            if(stage!=null)detachRender(stage);
            stage=null;disposed=true;
         }
         return {kind:"ensure-tail-cpu-source-v1",diagnosticOnly:true,performanceQualified:false,
            runtimeQualified:false,globalFaults:globalFaults,cleanupBlocked:blocked,rows:rows,
            renderObserverFaults:renderFaults,renderObserverAttached:renderAttached,
            segmentLimit:SEGMENTS,sampleLimit:SAMPLE_LIMIT,stackLimit:STACK_LIMIT,
            depthLimit:DEPTH_LIMIT,textLimit:TEXT_LIMIT,scope:"target resident 0-to-positive ensure observer tail to next stage ENTER +1000000",
            noCpuMeaning:"No CPU samples do not establish waiting, sleep, GPU or network time"};
      }
   }
}
