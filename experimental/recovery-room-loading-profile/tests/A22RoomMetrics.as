package {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   /** External timing only. No checkpoint or simulation calls. */
   public class A22RoomMetrics {
      private var mod:RConnectMod,links:Dictionary=new Dictionary(),starts:Dictionary=new Dictionary();
      private var last:int=0,holdAt:int=0,maxGap:int=0,gaps:Array=[];
      private var previousFrame:Object,maxGapContext:Object;
      private var lastRoomOp:String="",lastPeerPhase:String="";
      private var profileTaken:Boolean=false,profileSampling:Boolean=false,profileSaved:Boolean=false;
      private var profileActive:Object,profileGrant:NetMessageEvent,profileRows:Array=[],profileErrors:Array=[];
      private var profileFrame:int=0,profileWanted:int=0,profileTimer:Timer;
      private var profileIdentity:Object;
      private const MAX_SAMPLES:int=32768,MAX_KEYS:int=2048,MAX_DEPTH:int=64;
      public function A22RoomMetrics(m:RConnectMod) {
         mod=m;mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100006);
         mod.stage.addEventListener(Event.ENTER_FRAME,profileEnter,false,1000000);
         mod.stage.addEventListener(Event.ENTER_FRAME,profileAfterEnter,false,-1000000);
         mod.stage.addEventListener(Event.RENDER,profileRender,false,-1000000);
         profileTimer=new Timer(10000,1);profileTimer.addEventListener(TimerEvent.TIMER,profileTimeout);
      }
      private function frame(e:Event):void {
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
         profileBeforeGrant(e);
      }
      private function after(e:NetMessageEvent):void {
         var p:Object=e.data,now:int=getTimer(),began:int=starts[e];delete starts[e];
         profileAfterGrant(e);
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
      }
      // Observation only: keep all original handlers and errors outside these
      // diagnostic catches. No snapshots, simulation or protocol writes.
      private function profileFault(where:String,error:*):void {
         if(profileErrors.length<16)profileErrors.push({where:where,error:String(error)});
      }
      private function profileBeforeGrant(e:NetMessageEvent):void {
         if(profileTaken || e.data.type!="room" || e.data.op!="grant" || mod.session.mode!="connected")return;
         try {
            var app:String=NativeApplication.nativeApplication.applicationID,w:Object=mod.game.world;
            if(app.indexOf("pfe-modsettings-rconnect-coop-join-")!=0 || w==null || w.land==null || w.game==null
               || String(w.land.act.id)!="random_mane" || String(w.game.curLandId)!="random_mane")return;
            profileTaken=true;profileGrant=e;
            profileIdentity={appId:app,role:"join",room:mod.game.roomKey(),land:String(w.land.act.id),
               curLand:String(w.game.curLandId),epoch:mod.session.rooms.epoch,term:mod.session.rooms.term,
               barrier:e.data.barrier,key:e.data.key,version:Object(RConnectMod).VERSION};
            profileBegin("grant",0);
         }catch(error:*){profileFault("before-grant",error);profileAbort("before-grant-failed");}
      }
      private function profileAfterGrant(e:NetMessageEvent):void {
         if(e!==profileGrant)return;
         profileGrant=null;profileEnd("handler-returned",true);
         if(profileErrors.length==0)profileWanted=2;
      }
      private function profileEnter(e:Event):void {
         if(profileWanted<=0)return;
         if(profileActive!=null){profileAbort("next-enter-before-render");return;}
         profileWanted--;profileFrame++;profileBegin("enter-to-render",profileFrame);
         // Request only the RENDER notification; no input or world mutation.
         try{mod.stage.invalidate();}catch(error:*){profileFault("invalidate",error);profileAbort("invalidate-failed");}
      }
      private function profileAfterEnter(e:Event):void {
         if(profileActive!=null && profileActive.kind=="enter-to-render")profileActive.enterTail=getTimer();
      }
      private function profileRender(e:Event):void {
         if(profileActive!=null && profileActive.kind=="enter-to-render")profileEnd("render",true);
      }
      private function profileBegin(kind:String,index:int):void {
         var began:int=getTimer();
         profileActive={kind:kind,index:index,begin:began,beginUtc:new Date().time,enterTail:null,
            startReturned:null,end:null,complete:false,samples:0,visited:0,cpu:0,deleted:0,
            allocations:{},stacks:{},truncated:false};
         try {
            clearSamples();sampleInternalAllocs(false);startSampling();profileSampling=true;
            profileActive.startReturned=getTimer();profileTimer.reset();profileTimer.start();
         }catch(error:*){profileFault("start-sampling",error);profileAbort("sampling-start-failed");}
      }
      private function profileEnd(reason:String,complete:Boolean):void {
         if(profileActive==null)return;
         var end:int=getTimer(),row:Object=profileActive;profileActive=null;profileTimer.stop();
         row.end=end;row.endUtc=new Date().time;row.termination=reason;row.windowComplete=complete;
         var stacks:int=0,allocKeys:int=0;
         try {
            if(profileSampling) {
               pauseSampling();row.pausedAt=getTimer();row.samples=getSampleCount();
               for each(var sample:Sample in getSamples()) {
                  if(row.visited>=MAX_SAMPLES){row.truncated=true;break;}row.visited++;
                  if(sample is NewObjectSample) {
                     var created:NewObjectSample=sample as NewObjectSample;
                     var kind:String=created.type==null?"<unknown>":getQualifiedClassName(created.type);
                     var alloc:Object=row.allocations[kind];
                     if(alloc==null) {
                        if(allocKeys>=MAX_KEYS){row.truncated=true;continue;}
                        row.allocations[kind]=alloc={count:0,bytes:0};allocKeys++;
                     }
                     alloc.count++;alloc.bytes+=created.size;continue;
                  }
                  if(sample is DeleteObjectSample){row.deleted++;continue;}
                  row.cpu++;var names:Array=[];var depth:int=0;
                  if(sample.stack!=null)for each(var item:StackFrame in sample.stack) {
                     if(depth>=MAX_DEPTH){row.truncated=true;break;}
                     names.push(item.name+"@"+item.file+":"+item.line);depth++;
                  }
                  var key:String=names.join(" <- ");
                  if(!row.stacks.hasOwnProperty(key)) {
                     if(stacks>=MAX_KEYS){row.truncated=true;continue;}stacks++;
                  }
                  row.stacks[key]=int(row.stacks[key])+1;
               }
               if(row.visited!=row.samples)row.truncated=true;
               row.complete=complete && !row.truncated && row.samples>0 && row.cpu>0;
            }
         }catch(error:*){profileFault("collect",error);row.complete=false;}
         finally {
            try{stopSampling();}catch(stopError:*){profileFault("stop-sampling",stopError);row.complete=false;}
            profileSampling=false;
            try{clearSamples();}catch(clearError:*){profileFault("clear-samples",clearError);row.complete=false;}
         }
         row.collectionEnd=getTimer();row.collectionMs=row.collectionEnd-end;profileRows.push(row);
      }
      private function profileAbort(reason:String):void {
         profileWanted=0;profileGrant=null;profileEnd(reason,false);
      }
      private function profileTimeout(e:TimerEvent):void {profileAbort("ten-second-window-budget");}
      private function profileFinish():void {
         profileAbort("fixture-finished-before-window-end");
         mod.stage.removeEventListener(Event.ENTER_FRAME,profileEnter);
         mod.stage.removeEventListener(Event.ENTER_FRAME,profileAfterEnter);
         mod.stage.removeEventListener(Event.RENDER,profileRender);
         profileTimer.stop();profileTimer.removeEventListener(TimerEvent.TIMER,profileTimeout);
         if(profileSaved || !profileTaken)return;profileSaved=true;
         var stream:FileStream=new FileStream();
         try {
            var complete:Boolean=profileErrors.length==0 && profileRows.length==3;
            for each(var row:Object in profileRows)if(!row.complete)complete=false;
            var value:Object={kind:"room-loading-cpu-v1",identity:profileIdentity,complete:complete,
               windows:profileRows,errors:profileErrors,sampleLimit:MAX_SAMPLES,keyLimit:MAX_KEYS,stackDepthLimit:MAX_DEPTH,
               performanceQualified:false,scope:"first join random_mane grant handler and next two ENTER_FRAME-to-RENDER windows",
               collectionOutsideSampling:true,sampleInternalAllocs:false};
            stream.open(File.applicationStorageDirectory.resolvePath("room-loading-profile.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(value));
         }catch(error:*){profileFault("write-profile",error);}
         finally {try{stream.close();}catch(closeError:*){profileFault("close-profile",closeError);}}
      }
      public function finish():void {
         profileFinish();
         mod.stage.removeEventListener(Event.ENTER_FRAME,frame);
         for(var l:Object in links){l.removeEventListener(TcpLink.MESSAGE,before);l.removeEventListener(TcpLink.MESSAGE,after);}
         gaps.sort(Array.NUMERIC);
         Log.d("A22 ROOM FRAMES "+JSON.stringify({frames:gaps.length,max:maxGap,
            p95:gaps.length?gaps[int(gaps.length*.95)]:0,maxContext:maxGapContext,
            peerPhaseSource:"last received room-test message, not local fixture phase"}));
      }
   }
}
