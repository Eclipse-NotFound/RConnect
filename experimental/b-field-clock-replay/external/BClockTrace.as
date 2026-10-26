package {
   import flash.display.Stage;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;

   /** External, read-only timing observer for B field9's public callback API.
    * Never calls apply/present/take/decode, never changes a frame or a clock.
    * Socket delivery and clock.push are bracketed, not intercepted internally.
    */
   public final class BClockTrace {
      private var mod:Object,displayStage:Stage,link:Object,replica:Object;
      private var previousMessage:Function,previousConfirmed:Function;
      private var messageHook:Function,confirmedHook:Function;
      private var records:Array=[],header:Object;
      private var maximum:int,active:Boolean=false,started:Boolean=false,written:Boolean=false;
      private var startAt:int=0,stopAt:int=0,reason:String="",truncated:Boolean=false;
      private var faults:uint=0,messageCount:uint=0,acceptedCount:uint=0,confirmCount:uint=0,screenCount:uint=0;
      private var faultText:String="",observerMs:Number=0;
      private var restoredMessage:Boolean=false,restoredConfirmed:Boolean=false;
      private var delivery:Object,screen:Object;
      private var sequence:uint=0;

      /** maximumLines includes one header and one footer, and is capped at 20000. */
      public function BClockTrace(module:Object,stage:Stage,maximumLines:int=20000) {
         mod=module;displayStage=stage;maximum=Math.max(16,Math.min(20000,maximumLines))-2;
      }

      /** Prefer after link/replica creation but before the first incoming frame.
       * Starting mid-session is allowed and explicitly marks incomplete history.
       */
      public function start(buildLabel:String=""):void {
         if(started)throw new Error("Clock trace can only start once");
         if(mod==null || displayStage==null || mod.role!="join" || mod.link==null || mod.replica==null)
            throw new Error("Clock trace requires an existing B join link and replica");
         link=mod.link;replica=mod.replica;
         previousMessage=link.message as Function;
         if(previousMessage==null)throw new Error("Clock trace requires the original Link.message callback");
         previousConfirmed=replica.confirmed as Function;
         startAt=getTimer();
         header={kind:"header",schema:"rconnect-b-clock-trace-1",at:startAt,build:buildLabel,
            maximumLines:maximum+2,role:String(mod.role),session:String(mod.sessionId),
            arrivalMeaning:"Link.message entry after WireCodec.decode, before original receive",
            clockPushMeaning:"inside arrival.forwardAt..returnAt, not directly hooked",
            screenMeaning:"ENTER_FRAME priorities 100001..99999 bracket RConnect before(100000); includes other work",
            confirmMeaning:"ClientReplica.confirmed entry after render(state), before previous diagnostic callback",
            completeHistory:replica.frames==0 && replica.clock.current==null && replica.clock.next==null && replica.clock.queued==0,
            initialClock:clockState(),initialFrame:frameState(replica.lastFrame)};
         messageHook=onMessage;confirmedHook=onConfirmed;
         started=true;active=true;
         link.message=messageHook;replica.confirmed=confirmedHook;
         displayStage.addEventListener(Event.ENTER_FRAME,onScreenBegin,false,100001);
         displayStage.addEventListener(Event.ENTER_FRAME,onScreenEnd,false,99999);
      }

      public function get running():Boolean {return active;}

      /** Stop observation without writing, changing session state, or closing a socket.
       * Restore only callbacks still owned by this helper; never overwrite a later owner.
       */
      public function stop(why:String="caller stopped"):void {
         if(!started || !active)return;
         active=false;stopAt=getTimer();reason=why;
         displayStage.removeEventListener(Event.ENTER_FRAME,onScreenBegin);
         displayStage.removeEventListener(Event.ENTER_FRAME,onScreenEnd);
         try {
            if(link!=null && link.message===messageHook){link.message=previousMessage;restoredMessage=true;}
         }catch(error:*){fault(error);}
         try {
            if(replica!=null && replica.confirmed===confirmedHook){replica.confirmed=previousConfirmed;restoredConfirmed=true;}
         }catch(other:*){fault(other);}
         // References to the original callbacks remain valid if another observer
         // has already wrapped ours. Inactive wrappers still forward exactly once.
      }

      private function validOwner():Boolean {
         if(!active)return false;
         if(mod.link!==link || mod.replica!==replica || mod.role!="join") {
            stop("session/link/replica identity changed");return false;
         }
         if(link.message!==messageHook || replica.confirmed!==confirmedHook) {
            stop("another owner replaced a diagnostic callback");return false;
         }
         return true;
      }

      private function fault(error:*):void {
         ++faults;
         if(faultText=="") {
            try{faultText=String(error).substr(0,256);}catch(ignored:*){faultText="observer error";}
         }
      }

      private function append(row:Object):Boolean {
         if(!active)return false;
         if(records.length>=maximum) {
            truncated=true;stop("trace row limit reached");return false;
         }
         row.seq=++sequence;records.push(row);return true;
      }

      private function clockState():Object {
         var c:Object=replica.clock,a:Object=c.current,b:Object=c.next;
         return {position:Number(c.position),delay:Number(c.delay),queued:uint(c.queued),underflows:uint(c.underflows),
            fraction:Number(c.fraction),currentTick:a==null?null:a.tick,currentTime:a==null?null:a.time,
            nextTick:b==null?null:b.tick,nextTime:b==null?null:b.time};
      }

      /** Constant-sized metadata only; never keep a full frame, pose, or bitmap. */
      private function frameState(f:Object):Object {
         if(f==null)return null;
         var players:Array=[],source:Array=f.players as Array;
         if(source!=null)for(var i:int=0;i<source.length;i++) {
            var p:Object=source[i];players.push({epoch:p.epoch,roomEpoch:p.roomEpoch});
         }
         var t:Object=f.timeControl,s:Object=f.scene;
         return {tick:f.tick,time:Number(f.time),room:f.room,pauseEpoch:f.pauseEpoch,paused:f.paused===true,
            players:players,timeControl:t==null?null:{phase:t.phase,cycle:t.cycle},
            terrainRevision:s==null?null:s.terrainRevision,
            projectileCount:f.projectiles==null?0:f.projectiles.length,
            projectileEventCount:f.projectileEvents==null?0:f.projectileEvents.length};
      }

      private function beginArrival(value:Object,at:int):Object {
         var row:Object=null,began:int=getTimer();
         try {
            if(active && value!=null && value.type=="frame") {
               ++messageCount;
               row={kind:"arrival",at:at,serial:value.serial,base:value.base,
                  welcomed:mod.welcomed===true,sessionMatches:value.session===mod.sessionId,
                  framesBefore:uint(replica.frames),confirmBefore:confirmCount,clockBefore:clockState(),complete:false};
               if(!append(row))row=null;
            }
         }catch(error:*){fault(error);row=null;}
         observerMs+=getTimer()-began;return row;
      }

      private function endArrival(row:Object,returned:int):void {
         var began:int=getTimer();
         try {
            row.returnAt=returned;
            row.framesAfter=uint(replica.frames);
            row.accepted=row.framesAfter>row.framesBefore;
            row.acceptedCount=row.framesAfter-row.framesBefore;
            // The original callback has already decoded and pushed this state.
            // Reading lastFrame does not decode again and does not repeat apply.
            row.frame=row.accepted?frameState(replica.lastFrame):null;
            row.clockAfter=clockState();row.confirmations=confirmCount-uint(row.confirmBefore);
            row.queueAccounting=row.clockAfter.queued==row.clockBefore.queued+row.acceptedCount-row.confirmations;
            row.complete=true;
            if(row.accepted)acceptedCount+=uint(row.acceptedCount);
         }catch(error:*){fault(error);row.observerError=true;}
         observerMs+=getTimer()-began;
      }

      private function onMessage(value:Object):void {
         var at:int=getTimer(),row:Object=beginArrival(value,at),priorDelivery:Object=delivery;
         if(row!=null){delivery=row;row.forwardAt=getTimer();}
         try {
            // Preserve the original argument identity and exactly one call.
            // If it throws, finally observes the outcome and the same exception
            // continues to Link.drain's original error handling.
            previousMessage.call(link,value);
         }finally {
            var returned:int=getTimer();
            if(row!=null)endArrival(row,returned);
            delivery=priorDelivery;
         }
      }

      private function onConfirmed(frame:Object):void {
         var at:int=getTimer(),began:int=at;
         try {
            if(active) {
               ++confirmCount;
               append({kind:"confirmed",at:at,arrivalSeq:delivery==null?null:delivery.seq,
                  screenSeq:screen==null?null:screen.seq,frame:frameState(frame),clock:clockState()});
            }
         }catch(error:*){fault(error);}
         observerMs+=getTimer()-began;
         // Observe before the old diagnostic callback, but never replace its work.
         // A failure there remains visible to the original ClientReplica caller.
         if(previousConfirmed!=null)previousConfirmed.call(replica,frame);
      }

      private function onScreenBegin(e:Event):void {
         var began:int=getTimer();
         try {
            if(!validOwner())return;
            // A missing end is kept explicit; it must not become a guessed take.
            if(screen!=null && screen.complete!==true)screen.missingEnd=true;
            var row:Object={kind:"screen",at:began,welcomed:mod.welcomed===true,
               clockBefore:clockState(),framesBefore:uint(replica.frames),confirmBefore:confirmCount,complete:false};
            if(append(row)){screen=row;++screenCount;}
            else screen=null;
         }catch(error:*){fault(error);}
         finally {observerMs+=getTimer()-began;}
      }

      private function onScreenEnd(e:Event):void {
         var at:int=getTimer(),began:int=at;
         try {
            if(screen==null)return;
            var row:Object=screen;screen=null;
            row.endAt=at;row.clockAfter=clockState();row.framesAfter=uint(replica.frames);
            row.confirmations=confirmCount-uint(row.confirmBefore);row.complete=true;
            row.takeObserved=row.confirmations>0 || row.clockAfter.underflows>row.clockBefore.underflows ||
               row.clockAfter.position!=row.clockBefore.position;
            // false is unknown, not proof of no present: a paused/no-motion
            // present can leave all these public fields unchanged.
         }catch(error:*){fault(error);}
         finally {observerMs+=getTimer()-began;}
      }

      public function mark(label:String):void {
         var began:int=getTimer();
         try{if(active)append({kind:"mark",at:began,label:label.substr(0,128)});}
         catch(error:*){fault(error);}
         observerMs+=getTimer()-began;
      }

      private function footer():Object {
         var arrivalAnomalies:uint=0,unpairedScreens:uint=0,lastClock:Object=null,lastFrame:Object=null;
         for each(var row:Object in records) {
            if(row.kind=="arrival" && (row.complete!==true || row.observerError===true ||
               row.acceptedCount>1 || row.queueAccounting!==true))++arrivalAnomalies;
            if(row.kind=="screen" && row.complete!==true)++unpairedScreens;
         }
         try{lastClock=clockState();lastFrame=frameState(replica.lastFrame);}catch(error:*){fault(error);}
         return {kind:"footer",at:stopAt,reason:reason,recordedRows:records.length,lines:records.length+2,
            truncated:truncated,faults:faults,firstObserverError:faultText,
            frameMessages:messageCount,acceptedFrames:acceptedCount,confirmations:confirmCount,screens:screenCount,
            observerMs:observerMs,restoredMessage:restoredMessage,restoredConfirmed:restoredConfirmed,
            pendingDelivery:delivery!=null,pendingScreen:screen!=null,
            arrivalAnomalies:arrivalAnomalies,unpairedScreens:unpairedScreens,finalClock:lastClock,finalFrame:lastFrame,
            usableForBracketedReplay:header.completeHistory && !truncated && faults==0 &&
               arrivalAnomalies==0 && unpairedScreens==0 && delivery==null && screen==null && messageCount>0,
            qualifiesExactTakeTimes:false,qualifiesNetworkArrivalTimes:false};
      }

      /** Inspection for tests or a caller-owned writer. Only call after stop,
       * outside a callback; rows are diagnostic data, not game object references.
       */
      public function data():Object {
         if(!started || active)throw new Error("Stop the clock trace before exporting");
         if(delivery!=null)throw new Error("Export after the original callback returns");
         return {header:header,rows:records.concat(),footer:footer()};
      }

      /** One bounded JSONL write, only on an explicit call after collection.
       * A new path is required; evidence is never silently overwritten.
       */
      public function writeTrace(file:File):Object {
         if(written)throw new Error("Clock trace was already written");
         if(file==null || file.exists)throw new Error("Clock trace needs a new output file");
         if(file.parent==null || !file.parent.exists)throw new Error("Clock trace output directory must exist");
         stop("caller wrote trace");
         var payload:Object=data(),lines:Array=[JSON.stringify(payload.header)];
         for each(var row:Object in payload.rows)lines.push(JSON.stringify(row));
         lines.push(JSON.stringify(payload.footer));
         var text:String=lines.join("\n")+"\n",stream:FileStream=new FileStream(),opened:Boolean=false;
         try {
            stream.open(file,FileMode.WRITE);opened=true;stream.writeUTFBytes(text);written=true;
         }finally {if(opened)stream.close();}
         return {path:file.nativePath,lines:lines.length,rows:records.length,truncated:truncated,faults:faults};
      }
   }
}
