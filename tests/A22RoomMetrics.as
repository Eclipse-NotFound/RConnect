package {
   import flash.events.Event;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;
   import flash.sampler.*;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   /** External timing only. No checkpoint or simulation calls. */
   public class A22RoomMetrics {
      private var mod:RConnectMod,links:Dictionary=new Dictionary(),starts:Dictionary=new Dictionary();
      private var last:int=0,holdAt:int=0,maxGap:int=0,gaps:Array=[];
      private var previousFrame:Object,maxGapContext:Object;
      private var lastRoomOp:String="",lastPeerPhase:String="";
      private var profile:Boolean=false,sampling:Boolean=false,sampleFrames:int=0,sampleAt:int=0;
      public function A22RoomMetrics(m:RConnectMod,profileFirstFrame:Boolean=false) {
         mod=m;profile=profileFirstFrame;mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100006);
      }
      private function frame(e:Event):void {
         // Start after grant, then include the complete first resumed frame.
         // The second Stage boundary closes the sample before the next work.
         if(sampling && --sampleFrames<=0)finishSample();
         var now:int=getTimer(),current:Object=context();
         if(last>0) {
            var gap:int=now-last;gaps.push(gap);
            var detail:Object;
            if(gap>maxGap || gap>=250)detail={from:last,at:now,ms:gap,before:previousFrame,after:current};
            if(gap>maxGap){maxGap=gap;maxGapContext=detail;}
            if(gap>=250)Log.d("A22 ROOM FRAME GAP "+JSON.stringify(detail));
         }
         last=now;previousFrame=current;
         var peers:Array=mod.session.mode=="hosting"?mod.session.server.clients:[mod.session.link];
         for each(var l:TcpLink in peers)if(l!=null&&!links[l]) {
            links[l]=true;l.addEventListener(TcpLink.MESSAGE,before,false,200000);l.addEventListener(TcpLink.MESSAGE,after,false,-200000);
         }
         if(mod.session.rooms.busy&&holdAt==0)holdAt=now;
         else if(!mod.session.rooms.busy&&holdAt>0) {
            Log.d("A22 ROOM HOLD "+JSON.stringify({from:holdAt,at:now,ms:now-holdAt,
               room:mod.game.roomKey(),term:mod.session.rooms.term,sampling:"frame boundaries"}));holdAt=0;
         }
      }
      private function context():Object {
         var r:Object=mod.session.rooms,w:Object=mod.game.world;
         return {room:mod.game.roomKey(),busy:r.busy,ready:r.ready,authority:r.authority,
            term:r.term,epoch:r.epoch,roomOp:lastRoomOp,peerPhase:lastPeerPhase,
            exit:w==null?-1:int(w.t_exit),nativePause:w==null?false:w.onPause,cover:r.entryPending,
            fading:w!=null && w.vblack!=null && w.vblack.visible && w.vblack.alpha>0};
      }
      private function before(e:NetMessageEvent):void {
         if(e.data.type=="room-test")lastPeerPhase=String(e.data.phase);
         starts[e]=getTimer();
         if(e.data.type=="room")lastRoomOp=String(e.data.op);
      }
      private function after(e:NetMessageEvent):void {
         var p:Object=e.data,now:int=getTimer(),began:int=starts[e];delete starts[e];
         if(p.type!="room") {
            if(now-began>=100)Log.d("A22 NETWORK RECEIVE "+JSON.stringify({type:p.type,from:began,at:now,
               ms:now-began,context:context()}));
            return;
         }
         // seal includes sendReady's capture/encoding; ready includes commit.
         // These are whole-handler times, not isolated RoomCodec.pack timings.
         // grant.fresh is Boolean, while ready.fresh is a state String or null.
         Log.d("A22 ROOM RECEIVE "+JSON.stringify({op:p.op,from:began,at:now,
            ms:now-began,barrier:p.barrier,context:context(),
            state:p.state==null?0:String(p.state).length,own:p.own==null?0:String(p.own).length,
            fresh:p.fresh==null?0:String(p.fresh).length,freshNull:p.fresh===null,
            freshMissing:!p.hasOwnProperty("fresh"),freshKind:typeof p.fresh,
            freshStateBytes:p.fresh is String?String(p.fresh).length:0}));
         if(profile && p.op=="grant" && mod.game.loc!=null && mod.game.loc.spaceX>48) {
            if(sampling)finishSample();
            clearSamples();sampleInternalAllocs(false);startSampling();
            sampling=true;sampleFrames=2;sampleAt=getTimer();
         }
      }
      private function finishSample():void {
         if(!sampling)return;
         var end:int=getTimer();pauseSampling();sampling=false;
         var counts:Object={},total:int=getSampleCount(),cpu:int=0,alloc:int=0,deleted:int=0;
         for each(var sample:Sample in getSamples()) {
            if(sample is NewObjectSample){alloc++;continue;}
            if(sample is DeleteObjectSample){deleted++;continue;}
            cpu++;var names:Array=[];
            if(sample.stack!=null)for each(var f:StackFrame in sample.stack)names.push(f.name);
            var key:String=names.join(" <- ");counts[key]=int(counts[key])+1;
         }
         stopSampling();clearSamples();
         var rows:Array=[];
         for(key in counts)rows.push({stack:key,count:counts[key]});
         rows.sortOn("count",Array.NUMERIC|Array.DESCENDING);
         Log.d("A22 ROOM FIRST FRAME CPU "+JSON.stringify({from:sampleAt,at:end,ms:end-sampleAt,
            room:mod.game.roomKey(),samples:total,cpu:cpu,allocations:alloc,deleted:deleted,top:rows.slice(0,35),
            diagnosticOnly:true}));
      }
      public function finish():void {
         finishSample();
         mod.stage.removeEventListener(Event.ENTER_FRAME,frame);
         for(var l:Object in links){l.removeEventListener(TcpLink.MESSAGE,before);l.removeEventListener(TcpLink.MESSAGE,after);}
         gaps.sort(Array.NUMERIC);
         Log.d("A22 ROOM FRAMES "+JSON.stringify({frames:gaps.length,max:maxGap,
            p95:gaps.length?gaps[int(gaps.length*.95)]:0,maxContext:maxGapContext,
            peerPhaseSource:"last received room-test message, not local fixture phase"}));
      }
   }
}
