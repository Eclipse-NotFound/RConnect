package {
   import flash.events.Event;
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
         mod.stage.removeEventListener(Event.ENTER_FRAME,onFrame);
         mod.stage.removeEventListener(Event.RENDER,onRender);
         live.endedAt=getTimer();live.reason=reason;live.timingTotal=counters();live.timingTail=timingDelta();
         live.timingOwned=Object(mod.game)["presentationTiming"]===sink;
         Object(mod.game)["presentationTiming"]=originalTiming;
         live.timingRestored=Object(mod.game)["presentationTiming"]===originalTiming;
         pending.push(live);live=null;target=null;sink=null;originalTiming=null;
      }
      public function close():void {
         end("fixture-ended-before-window-complete");
         for each(var row:Object in pending)Log.d("NATIVE MOTION MEASURE "+JSON.stringify(row));
         pending=[];
      }
   }
}
