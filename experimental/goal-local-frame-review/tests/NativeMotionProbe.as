package {
   import flash.events.Event;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   /** Read-only native ENTER_FRAME / final RENDER observation. No screenshot,
    * setPos, interpolation or input dispatch. Logs are deferred until the
    * original two-endpoint fixture completes all measurement windows. */
   public final class NativeMotionProbe {
      private var mod:RConnectMod,host:Boolean;
      private var live:Object=null,pending:Array=[],target:Object,key:String="";
      private var originalTiming:Object,sink:Object,previousTiming:Object;
      private var frame:int=0,frameAt:int=0,lastRender:int=-1;
      private static const LIMIT:int=4096;
      // Diagnostic phase is private to this observer, not the game's phase.
      private var phase:String="boot",densityProbe:int=0;
      private var diagSampling:Boolean=false,diagNumber:int=0,diagAt:int=0,diagAfter:int=0;
      private var diagRows:Array=[],diagRecord:Object,diagCounts:Object,diagDroppedRows:int=0;
      private var cpuReports:Array=[],cpuExported:Boolean=false;
      public function NativeMotionProbe(m:RConnectMod,h:Boolean) {mod=m;host=h;}
      private function value(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private function focused():Object {
         try{return mod.stage.nativeWindow.active;}catch(e:Error){}
         return null;
      }
      private function actor(o:Object):Object {
         if(o==null)return null;
         var v:Object=value(o,"vis"),osn:Object=value(v,"osn"),body:Object=value(osn,"body");
         return {x:value(o,"X"),y:value(o,"Y"),dx:value(o,"dx"),dy:value(o,"dy"),stay:value(o,"stay"),
            shown:v!=null&&value(v,"parent")!=null,visible:value(v,"visible"),vx:value(v,"x"),vy:value(v,"y"),
            body:value(body,"currentFrame"),pose:value(osn,"currentLabel"),levit:value(o,"levit")};
      }
      private function counters():Object {
         return {viewMs:sink.viewMs,viewCalls:sink.viewCalls,motionMs:sink.motionMs,motionCalls:sink.motionCalls};
      }
      private function timingDelta():Object {
         var now:Object=counters(),delta:Object={};
         for(var name:String in now)delta[name]=Number(now[name])-Number(previousTiming[name]);
         previousTiming=now;return delta;
      }
      public function begin(name:String,round:int,o:Object=null,targetKey:String=""):void {
         if(live!=null)throw new Error("Overlapping native motion observation");
         if(!("presentationTiming" in Object(mod.game)))throw new Error("Required roomfix5 timing sink absent");
         if(name!="native-jump" || round!=0 || cpuReports.length!=0)throw new Error("CPU fixture requires one native-jump window");
         phase="load";
         target=o;key=targetKey;frame=0;frameAt=getTimer();lastRender=-1;
         originalTiming=Object(mod.game)["presentationTiming"];
         sink={viewMs:0,viewCalls:0,motionMs:0,motionCalls:0};previousTiming=counters();
         Object(mod.game)["presentationTiming"]=sink;
         live={kind:name,round:round,role:host?"host":"join",startedAt:frameAt,
            room:mod.game.roomKey(),targetKey:key,enter:[],render:[],incoming:[],dropped:0,
            receiveDefinition:"observer MESSAGE callback after earlier listeners; not socket arrival",
            clockDefinition:"local getTimer; source sampleTime is a different process clock",
            diagnosticOnly:true,smoothnessQualified:false};
         mod.stage.addEventListener(Event.ENTER_FRAME,onFrame,false,100002);
         mod.stage.addEventListener(Event.RENDER,onRender,false,-40000);
         mod.stage.addEventListener(Event.ENTER_FRAME,diagBegin,false,1000000);
         mod.stage.addEventListener(Event.ENTER_FRAME,diagAfterFrame,false,-1000000);
         mod.stage.addEventListener(Event.RENDER,diagEnd,false,-1000000);
      }
      private function append(array:Array,row:Object):void {
         if(array.length<LIMIT)array.push(row);else live.dropped++;
      }
      private function onFrame(e:Event):void {
         if(live==null)return;
         frame++;frameAt=getTimer();
         append(live.enter,{frame:frame,at:frameAt,focused:focused(),local:actor(mod.game.gg)});
      }
      private function onRender(e:Event):void {captureRender();}
      public function captureRender():void {
         if(live==null||lastRender==frame)return;
         lastRender=frame;
         append(live.render,{frame:frame,frameAt:frameAt,at:getTimer(),focused:focused(),
            local:actor(mod.game.gg),peer:actor(mod.game.getRemoteGhost(host?1:0)),
            target:actor(target),timing:timingDelta()});
      }
      public function receive(p:Object):void {
         if(live==null||p==null)return;
         var row:Object={at:getTimer(),type:value(p,"type"),seq:value(p,"seq"),tick:value(p,"tick"),
            focused:focused(),snapshots:[],positions:[]};
         var snap:Object=host?value(p,"snap"):null;
         if(!host&&p.players is Array)for each(var player:Object in p.players)if(player.id==0)snap=player.snap;
         if(snap!=null)row.snapshots.push({sampleTime:value(snap,"sampleTime"),seq:value(snap,"seq"),
            x:value(snap,"x"),y:value(snap,"y"),dx:value(snap,"dx"),dy:value(snap,"dy"),stay:value(snap,"stay")});
         // The four original box/loot cases share these actual production
         // streams. Keep identity and collection; do not mistake the separate
         // native-position diagnostic packet for production movement.
         for each(var field:String in ["moved","objs","loots","lootMotion"]) {
            var rows:Array=value(p,field) as Array;
            if(rows==null)continue;
            for each(var pos:Object in rows) {
               if(key!=""&&String(value(pos,"k"))!=key)continue;
               if(row.positions.length>=64){live.dropped++;break;}
               row.positions.push({collection:field,k:value(pos,"k"),sampleTime:value(pos,"sampleTime"),
                  x:value(pos,"x"),y:value(pos,"y"),q:value(pos,"q"),dx:value(pos,"dx"),dy:value(pos,"dy")});
            }
         }
         if(row.snapshots.length||row.positions.length)append(live.incoming,row);
      }
      public function end(reason:String,finalRender:Boolean=false):void {
         if(live==null)return;
         // The held fixture ends from ENTER_FRAME before the actual RENDER.
         // Never label that older display as this frame's final presentation.
         if(finalRender)captureRender();
         diagClose(getTimer(),"finish");phase="done";
         mod.stage.removeEventListener(Event.ENTER_FRAME,diagBegin);
         mod.stage.removeEventListener(Event.ENTER_FRAME,diagAfterFrame);
         mod.stage.removeEventListener(Event.RENDER,diagEnd);
         cpuReports.push({role:host?"host":"join",schema:1,
            scope:"stage-render-tail-to-next-stage-enter-entry",counts:diagCounts,
            droppedRows:diagDroppedRows,frames:diagRows,diagnosticOnly:true,
            kind:nameForCpu(),samplerStopped:!diagSampling,measurementReason:reason,
            measurementStartedAt:live.startedAt,measurementEndedAt:getTimer()});
         mod.stage.removeEventListener(Event.ENTER_FRAME,onFrame);
         mod.stage.removeEventListener(Event.RENDER,onRender);
         live.endedAt=getTimer();live.reason=reason;live.timingTotal=counters();live.timingTail=timingDelta();
         live.timingOwned=Object(mod.game)["presentationTiming"]===sink;
         Object(mod.game)["presentationTiming"]=originalTiming;
         live.timingRestored=Object(mod.game)["presentationTiming"]===originalTiming;
         pending.push(live);live=null;target=null;sink=null;originalTiming=null;
      }
      /** Original +1000000 stage ENTER callback. Pause before inspecting/formatting samples. */
      private function diagBegin(e:Event):void {
         var entered:int=getTimer();
         diagClose(entered,"next-enter");
         if(phase!="load"){diagAt=0;return;}
         diagAt=entered;diagAfter=0;diagNumber++;
         if(diagCounts==null)diagCounts={};
         diagRecord={phase:densityProbe,frame:diagNumber,at:entered,after:0,renderAt:0,
            startCallAt:0,start:0,stop:0,pauseReturned:0,selected:false,sampled:false,
            complete:false,reason:"open",cpu:0,stacks:{},extraRenders:0,
            stackOverflow:0,depthTruncated:0,collectStart:0,collectEnd:0,collectMs:0};
      }
      private function diagAfterFrame(e:Event):void {
         if(diagRecord!=null){diagAfter=getTimer();diagRecord.after=diagAfter;}
      }
      /** Original -1000000 stage RENDER callback; only the old sampling window tail follows. */
      private function diagEnd(e:Event):void {
         var rendered:int=getTimer(),row:Object=diagRecord;
         if(row==null)return;
         if(phase!="load" || int(row.phase)!=densityProbe){diagClose(rendered,"render-phase-mismatch");return;}
         if(int(row.renderAt)>0){row.extraRenders++;return;}
         row.renderAt=rendered;
         var selected:Boolean=int(diagCounts[densityProbe])<6
            && rendered-int(live.startedAt)>=1000+2500*int(diagCounts[densityProbe]);
         row.selected=selected;
         if(!selected)return;
         diagCounts[densityProbe]=int(diagCounts[densityProbe])+1;
         clearSamples();sampleInternalAllocs(false);
         row.startCallAt=getTimer();
         startSampling();
         var started:int=getTimer();
         diagSampling=true;row.sampled=true;row.start=started;
      }
      /** All enumeration, string building and row retention happens while sampling is paused. */
      private function diagClose(entered:int,reason:String):void {
         if(diagRecord==null)return;
         var wasSampling:Boolean=diagSampling;
         if(wasSampling)pauseSampling();
         var paused:int=getTimer(),row:Object=diagRecord;
         diagSampling=false;diagRecord=null;
         row.stop=entered;row.pauseReturned=wasSampling?paused:0;
         row.complete=reason=="next-enter" && phase=="load" && int(row.phase)==densityProbe && int(row.renderAt)>0;
         row.reason=row.complete?"next-enter":(reason=="next-enter"?(int(row.renderAt)==0?"no-render":"phase-mismatch"):reason);
         row.collectStart=getTimer();
         var unique:int=0;
         try {
            if(wasSampling)for each(var sample:Sample in getSamples()) {
               // Never retain sampled objects or allocation summaries in this variant.
               if(sample is NewObjectSample || sample is DeleteObjectSample)continue;
               row.cpu++;
               var names:Array=[];
               if(sample.stack!=null)for each(var frame:StackFrame in sample.stack) {
                  if(names.length>=64){names.push("<stack-depth-truncated>");row.depthTruncated++;break;}
                  names.push(frame.name+"@"+frame.file+":"+frame.line);
               }
               var key:String=names.join(" <- ");
               if(!row.stacks.hasOwnProperty(key)) {
                  if(unique>=1024){row.stackOverflow++;continue;}
                  unique++;
               }
               row.stacks[key]=int(row.stacks[key])+1;
            }
         } catch(error:*) {row.error=String(error);row.complete=false;row.reason="sampler-error";}
         finally {if(wasSampling){stopSampling();clearSamples();}}
         if(diagRows.length<4096)diagRows.push(row);else diagDroppedRows++;
         row.collectEnd=getTimer();row.collectMs=int(row.collectEnd)-int(row.collectStart);
         diagAt=0;diagAfter=0;
      }
      private function nameForCpu():String {return live==null?"missing":String(live.kind);}
      private function saveCpu():void {
         if(cpuExported)return;cpuExported=true;
         var stream:FileStream=new FileStream();
         try {
            stream.open(File.applicationStorageDirectory.resolvePath("native-jump-cpu.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify({kind:"ordinary-native-jump-cpu-v1",
               applicationId:NativeApplication.nativeApplication.applicationID,
               role:host?"host":"join",diagnosticOnly:true,performanceQualified:false,
               smoothnessQualified:false,samplerStopped:!diagSampling,profiles:cpuReports}));
         } finally {stream.close();}
      }
      public function close():void {
         end("fixture-ended-before-window-complete");
         for each(var row:Object in pending)Log.d("NATIVE MOTION MEASURE "+JSON.stringify(row));
         pending=[];
         saveCpu();
      }
   }
}
