package {
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Timer;
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
      private var profileTaken:Boolean=false,profileSaved:Boolean=false;
      private var profileActive:Object,profileGrant:NetMessageEvent,profileRows:Array=[],profileErrors:Array=[];
      private var profileFrame:int=0,profileWanted:int=0,profileTimer:Timer;
      private var profileIdentity:Object,profileTraffic:Object,profileHooks:Array=[];
      public function A22RoomMetrics(m:RConnectMod) {
         mod=m;mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100006);
         mod.stage.addEventListener(Event.ENTER_FRAME,profileEnter,false,1000000);
         for each(var priority:int in [1000000,1,-1,-99,-101,-8999,-9001,-9999,-10001,-1000000])profileHook(Event.ENTER_FRAME,priority);
         for each(priority in [1000000,-9999,-10001,-1000000])profileHook(Event.RENDER,priority);
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
         profileMessage(p,began,now);
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
      // Only the observation code catches its own errors; original handlers remain unchanged.
      private function profileFault(where:String,error:*):void {
         if(profileErrors.length<16)profileErrors.push({where:where,error:String(error)});
      }
      private function profileHook(type:String,priority:int):void {
         var listener:Function=function(e:Event):void {
            if(profileActive==null || profileActive.kind!="enter-to-render")return;
            var at:int=getTimer();
            try {
               if(profileActive.marks.length>=16){profileFault("marker-overflow",type);return;}
               profileActive.marks.push({type:type,priority:priority,at:at});
            }catch(error:*){profileFault("stage-marker",error);}
         };
         profileHooks.push({type:type,listener:listener});mod.stage.addEventListener(type,listener,false,priority);
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
            profileTraffic={begin:int(starts[e]),end:null,grantReturn:null,firstEnter:null,grantToFirstEnterMs:null,
               types:{},typeCount:0,beforeFirstEnter:{},beforeFirstEnterTypeCount:0};
            profileBegin("grant",0);
         }catch(error:*){profileFault("before-grant",error);profileAbort("before-grant-failed");}
      }
      private function profileMessage(p:Object,began:int,ended:int):void {
         if(profileTraffic==null || profileTraffic.end!==null || began<profileTraffic.begin)return;
         try {
            var key:String=String(p.type),row:Object=profileTraffic.types[key],elapsed:int=ended-began;
            if(row==null) {
               if(profileTraffic.typeCount>=32){profileFault("message-type-limit",key);return;}
               profileTraffic.typeCount++;row=profileTraffic.types[key]={calls:0,totalMs:0,maxMs:0,first:began,last:ended};
            }
            row.calls++;row.totalMs+=elapsed;row.maxMs=Math.max(row.maxMs,elapsed);row.last=ended;
            if(profileTraffic.grantReturn!==null && profileTraffic.firstEnter===null) {
               row=profileTraffic.beforeFirstEnter[key];
               if(row==null) {
                  if(profileTraffic.beforeFirstEnterTypeCount>=32){profileFault("pre-enter-type-limit",key);return;}
                  profileTraffic.beforeFirstEnterTypeCount++;
                  row=profileTraffic.beforeFirstEnter[key]={calls:0,totalMs:0,maxMs:0,first:began,last:ended};
               }
               row.calls++;row.totalMs+=elapsed;row.maxMs=Math.max(row.maxMs,elapsed);row.last=ended;
            }
            if(elapsed<0)profileFault("message-clock",key);
         }catch(error:*){profileFault("message-count",error);}
      }
      private function profileAfterGrant(e:NetMessageEvent):void {
         if(e!==profileGrant)return;
         profileGrant=null;profileTraffic.grantReturn=getTimer();profileEnd("handler-returned",true);
         if(profileErrors.length==0)profileWanted=2;
      }
      private function profileEnter(e:Event):void {
         if(profileWanted<=0)return;
         if(profileActive!=null){profileAbort("next-enter-before-render");return;}
         if(profileFrame==0) {
            profileTraffic.firstEnter=getTimer();
            profileTraffic.grantToFirstEnterMs=profileTraffic.firstEnter-profileTraffic.grantReturn;
         }
         profileWanted--;profileFrame++;profileBegin("enter-to-render",profileFrame);
         try{mod.stage.invalidate();}catch(error:*){profileFault("invalidate",error);profileAbort("invalidate-failed");}
      }
      private function profileRender(e:Event):void {
         if(profileActive!=null && profileActive.kind=="enter-to-render")profileEnd("render",true);
      }
      private function profileBegin(kind:String,index:int):void {
         profileActive={kind:kind,index:index,begin:getTimer(),beginUtc:new Date().time,
            armReturned:null,end:null,complete:false,marks:[],counters:null};
         try {
            if(Object(mod.game).beginLoadingCounters(kind,index)!==true)throw new Error("Counter window refused");
            profileActive.armReturned=getTimer();profileTimer.reset();profileTimer.start();
         }catch(error:*){profileFault("begin-counters",error);profileAbort("counter-begin-failed");}
      }
      private function profileEnd(reason:String,complete:Boolean):void {
         if(profileActive==null)return;
         var end:int=getTimer(),row:Object=profileActive;profileActive=null;profileTimer.stop();
         row.end=end;row.endUtc=new Date().time;row.termination=reason;row.windowComplete=complete;
         try {
            row.counters=Object(mod.game).endLoadingCounters();
            row.complete=complete && row.counters!=null && row.counters.kind==row.kind && row.counters.index==row.index
               && row.counters.faults.length==0;
         }catch(error:*){profileFault("end-counters",error);row.complete=false;}
         row.collectionEnd=getTimer();row.collectionMs=row.collectionEnd-end;profileRows.push(row);
         if(row.index==2 || !complete)profileTraffic.end=end;
      }
      private function profileAbort(reason:String):void {
         profileWanted=0;profileGrant=null;profileEnd(reason,false);
         if(profileTraffic!=null && profileTraffic.end===null)profileTraffic.end=getTimer();
      }
      private function profileTimeout(e:TimerEvent):void {profileAbort("ten-second-window-budget");}
      private function profileFinish():void {
         profileAbort("fixture-finished-before-window-end");
         mod.stage.removeEventListener(Event.ENTER_FRAME,profileEnter);
         mod.stage.removeEventListener(Event.RENDER,profileRender);
         for each(var hook:Object in profileHooks)mod.stage.removeEventListener(hook.type,hook.listener);
         profileTimer.stop();profileTimer.removeEventListener(TimerEvent.TIMER,profileTimeout);
         if(profileSaved || !profileTaken)return;profileSaved=true;
         var stream:FileStream=new FileStream();
         try {
            var complete:Boolean=profileErrors.length==0 && profileRows.length==3;
            for each(var row:Object in profileRows)if(!row.complete)complete=false;
            var value:Object={kind:"room-loading-counters-v1",identity:profileIdentity,complete:complete,
               windows:profileRows,traffic:profileTraffic,errors:profileErrors,performanceQualified:false,
               scope:"first join random_mane grant and next two Stage ENTER_FRAME-to-RENDER windows",
               inclusiveTimes:true,recursiveReferencesOuterOnly:true};
            stream.open(File.applicationStorageDirectory.resolvePath("room-loading-counters.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(value));
         }catch(error:*){profileFault("write-counters",error);}
         finally {try{stream.close();}catch(closeError:*){profileFault("close-counters",closeError);}}
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
