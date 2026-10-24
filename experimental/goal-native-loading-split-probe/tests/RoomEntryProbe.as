package {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;
   import rconnect.core.Log;
   import rconnect.core.Session;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   /** Observe real native transitions at the final rendering boundary. The
    * enclosing native suites still compare templates, tiles, doors and owners. */
   public class RoomEntryProbe {
      private var mod:RConnectMod,confirmedRoom:Object,confirmedLand:Object,confirmedStamp:Object;
      private var pendingFrames:int=0,loadFrames:int=0,releasedFrames:int=0,links:Dictionary=new Dictionary();
      private var failures:Object={},finished:Boolean=false;
      private var pictures:Object={},pendingAt:int=-1,waits:Array=[];
      private var worldPackets:int=0;
      private var connection:Object;
      private var confirmation:RoomEntryConfirmation=new RoomEntryConfirmation();
      private var nativeWorld:Object,nativeWait:DisplayObject,nativeParent:DisplayObjectContainer;
      private var eligibleFrames:int=0,restoredFrames:int=0,stationaryFrames:int=0,observerFaults:int=0;
      private var stationaryUntil:int=0,stationaryRoom:Object,stationaryLand:Object;
      private static const OLD_NAMES:Array=["rconnect-room-entry","rconnect-room-entry-sats","rconnect-native-loading"];
      public function RoomEntryProbe(m:RConnectMod) {
         mod=m;m.stage.addEventListener(Event.RENDER,render,false,-2147483648);
         m.stage.addEventListener(Event.ENTER_FRAME,watch,false,200000);watch();
      }
      private function check(ok:Boolean,label:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"room-entry "+label);
      }
      private function require(ok:Boolean,label:String):void {
         if(!ok && !failures[label]) {
            failures[label]=true;check(false,label);
            Log.d("ROOM ENTRY FAILURE "+JSON.stringify({label:label,at:getTimer(),room:mod.game.roomKey(),
               confirmed:confirmedStamp,stamp:mod.session.rooms.stamp({}),sameRoom:mod.game.world.loc===confirmedRoom,
               sameLand:mod.game.world.land===confirmedLand,ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,
               exit:mod.game.world.t_exit,transition:mod.game.isTransitioning()}));
         }
      }
      private function watch(e:Event=null):void {
         var session:Object=mod.session;
         observeConnection();
         observeLink(session.link as TcpLink);
         for each(var peer:Object in session.peers)observeLink(peer.link as TcpLink);
      }
      private function observeConnection():void {
         var session:Object=mod.session;
         var current:Object=session.mode==Session.CONNECTED?session.link:
            (session.mode==Session.HOSTING && session.peers.length>0?session.peers[0].link:null);
         if(current!==connection) {
            connection=current;confirmedRoom=null;confirmedLand=null;confirmedStamp=null;confirmation.reset();
         }
      }
      private function observeLink(link:TcpLink):void {
         if(link==null || links[link])return;
         links[link]=true;link.addEventListener(TcpLink.MESSAGE,settled,false,-2147483648);
      }
      private function settled(e:NetMessageEvent):void {
         // A new TCP connection must confirm even an unchanged native Land.
         // Never inherit the previous session's render approval after rejoin.
         observeConnection();
         var p:Object=e.data,rooms:Object=mod.session.rooms;
         // Existing fixture waits 2500 ms after this message before moving the
         // host. Observe only the first 2000 ms; no new wire messages or actions.
         if(p!=null && p.type=="room-test" && p.phase=="prepared" &&
            mod.session.mode==Session.HOSTING && e.currentTarget===connection) {
            stationaryUntil=getTimer()+2000;
            stationaryRoom=mod.game.world.loc;stationaryLand=mod.game.world.land;
         }
         if(p!=null && mod.session.mode==Session.CONNECTED) {
            var info:Object=null,hasWorld:Boolean=false;
            if(p.type=="unitsync"){info=p.worldInfo;hasWorld=true;}
            else if(p.type=="worldstate" && (p.enemyMotion is Array || p.lootMotion is Array || p.wallPaint is Array)) {
               hasWorld=true;
               for each(var player:Object in p.players)if(int(player.id)==0 && player.snap!=null)info=player.snap.worldInfo;
            }
            if(hasWorld) {
               worldPackets++;
               require(info!=null && String(p.roomKey)==String(info.roomKey),"world payload and room stamp name the same native room");
            }
         }
         if(p==null || p.type!="room")return;
         // Session's priority-0 handler has already processed this exact message.
         // READY can commit/release the host locally; ACK confirms the peer later.
         // Reject messages from a previously observed (now disconnected) socket.
         if(e.currentTarget!==connection)return;
         var isHost:Boolean=mod.session.mode==Session.HOSTING;
         if((isHost && (p.op=="ready" || p.op=="ack")) ||
            (mod.session.mode==Session.CONNECTED && p.op=="grant")) {
            var view:Object=confirmationView(),accepted:Boolean=confirmation.observe(isHost,p,view);
            if(accepted) {
               confirmedRoom=confirmation.room;confirmedLand=confirmation.land;confirmedStamp=confirmation.stamp;
            }
            Log.d("ROOM ENTRY CONFIRM "+JSON.stringify({at:getTimer(),wall:new Date().time,op:p.op,
               accepted:accepted,localCommitted:confirmation.same(view),
               peerAcknowledged:confirmation.same(view) && confirmation.peerAcknowledged,confirmedStamp:confirmedStamp,
               barrier:p.barrier,epoch:rooms.epoch,term:rooms.term,stamp:rooms.stamp({}),
               ready:rooms.ready,busy:rooms.busy,canSync:rooms.canSyncWorld,
               sameRoom:mod.game.world.loc===confirmedRoom,sameLand:mod.game.world.land===confirmedLand}));
         }
      }
      private function confirmationView():Object {
         var w:Object=mod.game.world,rooms:Object=mod.session.rooms;
         return {room:w.loc,land:w.land,gameRoom:mod.game.loc,landRoom:w.land!=null?w.land.loc:null,
            playerRoom:w.gg!=null?w.gg.loc:null,key:mod.game.roomKey(),stamp:rooms.stamp({}),
            term:rooms.term,epoch:rooms.epoch,ready:rooms.ready,busy:rooms.busy,
            authority:rooms.authority,canSync:rooms.canSyncWorld};
      }
      private function render(e:Event):void {
         if(finished || mod.game==null || mod.game.world==null)return;
         var session:Object=mod.session,w:Object=mod.game.world,rooms:Object=session.rooms;
         if(session.mode!=Session.CONNECTED && !(session.mode==Session.HOSTING && session.peers.length))return;
         var visual:DisplayObject=w.visual as DisplayObject;
         if(w.loc==null || visual==null || visual.parent==null)return;
         var earlyLoad:Boolean=int(w.t_exit)>0 && int(w.t_exit)<=16;
         var sameConfirmed:Boolean=confirmation.same(confirmationView());
         // A remote-only handoff does not invalidate this confirmed native
         // scene. It must remain visible while the ownership messages travel.
         var pending:Boolean=!rooms.ready || !sameConfirmed;
         observeNative(w,rooms,sameConfirmed);
         if(pending) {
            if(pendingAt<0)pendingAt=getTimer();
            pendingFrames++;if(earlyLoad)loadFrames++;
         }
         if(confirmedRoom!=null && !sameConfirmed)
            require(!rooms.accepts(confirmedStamp),"new native room rejects previous room state");
         if(!sameConfirmed)
            require(!rooms.canSyncWorld,"new native room cannot publish before handoff");
         if(!pending) {
            if(pendingAt>=0){waits.push(getTimer()-pendingAt);pendingAt=-1;}
            releasedFrames++;
            require(w.loc===mod.game.loc && w.land.loc===w.loc && w.gg.loc===w.loc,"first released frame has one native room identity");
         }
      }
      private function effective(value:Object):Boolean {
         var d:DisplayObject=value as DisplayObject;
         if(d==null || d.stage!==mod.stage)return false;
         var p:DisplayObject=d,depth:int=0;
         while(p!=null && depth<128) {
            if(!p.visible || p.alpha<=0)return false;
            p=p.parent;depth++;
         }
         if(p!=null)throw new Error("Native display ancestor depth exceeded");
         return true;
      }
      private function blocked(w:Object):String {
         if(w.gg==null||w.loc==null||w.game==null||w.vwait==null||w.gg.pers==null)return "no-world";
         if(w.comLoad>=0||w.ng_wait>0||w.t_die>0||w.gg.pers.dead)return "native-load-or-death";
         if(w.allStat!=1)return "native-state";
         if(w.catPause||w.vscene.visible||w.clickReq!=0||w.vwait.story.visible)return "native-story";
         if(w.onConsol||w.verror.visible||(w.pip!=null&&w.pip.active)||(w.sats!=null&&w.sats.active)
            ||(w.stand!=null&&w.stand.active)||(w.gui!=null&&w.gui.guiPause))return "native-overlay";
         if(w.t_exit>20)return "native-fade";
         return "";
      }
      private function knownCopies(w:Object):int {
         var scopes:Array=[mod.stage,mod.main,w.visual==null?null:w.visual.parent,w.vsats];
         var seen:Dictionary=new Dictionary(true),found:int=0;
         for each(var scope:DisplayObjectContainer in scopes) {
            if(scope==null||seen[scope])continue;seen[scope]=true;
            for each(var name:String in OLD_NAMES)if(scope.getChildByName(name)!=null)found++;
         }
         return found;
      }
      private function observeNative(w:Object,rooms:Object,sameConfirmed:Boolean):void {
         try {
            if(nativeWorld==null) {
               nativeWait=w.vwait as DisplayObject;
               if(nativeWait==null||nativeWait.parent==null)throw new Error("Native vwait is not attached");
               nativeWorld=w;nativeParent=nativeWait.parent;
            }
            require(w===nativeWorld && w.vwait===nativeWait,"same actual native vwait throughout room transitions");
            require(nativeWait.parent===nativeParent,"native vwait keeps its original parent");
            require("rconnectLoadingUiFaults" in w && uint(w.rconnectLoadingUiFaults)==0,
               "native loading bridge is present with zero faults");
            require(knownCopies(w)==0,"no custom cover or copied loading object at final render");
            var reason:String=blocked(w),localPending:Boolean=rooms.entryPending===true;
            if(localPending && reason=="") {
               eligibleFrames++;
               require(effective(w.vwait),"eligible local entry shows actual native vwait");
               require(!w.visual.visible && !w.vfon.visible && !w.vgui.visible,
                  "eligible local entry hides native scene background and HUD");
               capture("waiting",w);
            }
            // Native exit 18..17 may still own vwait after an early grant.
            // Only a settled native exit can be checked for released visibility.
            if(!localPending && sameConfirmed && rooms.ready && int(w.t_exit)==0 && reason=="") {
               restoredFrames++;
               require(!effective(w.vwait),"released native room has no leftover wait");
               require(effective(w.visual)&&effective(w.vfon)&&effective(w.vgui),
                  "released native scene background and HUD are visible");
               if(eligibleFrames>0)capture("ready",w);
            }
            if(stationaryUntil>0 && getTimer()<stationaryUntil) {
               stationaryFrames++;
               require(w.loc===stationaryRoom && w.land===stationaryLand,
                  "stationary observation keeps its original native room");
               require(!localPending && !mod.game.roomHold,
                  "peer-only handoff does not request a local loading lease");
               require(reason=="" && int(w.t_exit)==0 && !effective(w.vwait),
                  "stationary peer never gains a native wait");
               require(effective(w.visual)&&effective(w.vfon)&&effective(w.vgui),
                  "stationary native scene background and HUD remain visible");
            }
         } catch(error:*) {
            observerFaults++;require(false,"native display observation: "+String(error));
         }
      }
      private function finalCopies():int {
         var queue:Array=[mod.stage],found:int=0,visited:int=0;
         while(queue.length>0 && visited<100000) {
            var d:DisplayObject=queue.pop() as DisplayObject;visited++;
            if(OLD_NAMES.indexOf(d.name)>=0)found++;
            var c:DisplayObjectContainer=d as DisplayObjectContainer;
            if(c!=null)for(var i:int=0;i<c.numChildren;i++)queue.push(c.getChildAt(i));
         }
         if(queue.length>0)throw new Error("Terminal display tree scan exceeded bound");
         return found;
      }
      private function capture(label:String,w:Object):void {
         if(pictures[label]!=null || (w.vblack.visible && w.vblack.alpha>0))return;
         try {
            var b:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
            b.draw(mod.stage);pictures[label]=b;
         }catch(error:Error){require(false,"capture "+label+": "+error);}
      }
      public function finish(nativeLoad:Boolean):void {
         if(finished)return;finished=true;mod.stage.removeEventListener(Event.RENDER,render);
         mod.stage.removeEventListener(Event.ENTER_FRAME,watch);
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,settled);
         check(pendingFrames>0,"observed pending frames="+pendingFrames);
         check(releasedFrames>0,"observed settled frames="+releasedFrames);
         if(nativeLoad)check(loadFrames>0,"observed native exit 16..1 frames="+loadFrames);
         if(mod.session.mode==Session.CONNECTED)check(worldPackets>0,"checked incoming world packet identities="+worldPackets);
         Log.d("ROOM ENTRY waits-ms="+JSON.stringify(waits)+" unfinished="+(pendingAt>=0));
         check(eligibleFrames>0,"observed eligible native pending frames="+eligibleFrames);
         check(restoredFrames>0,"observed released native visibility frames="+restoredFrames);
         if(mod.session.mode==Session.HOSTING)check(stationaryFrames>0,"observed stationary peer final renders="+stationaryFrames);
         check(observerFaults==0,"native visibility observer faults="+observerFaults);
         try {check(finalCopies()==0,"terminal tree has no legacy cover or copied loading object");}
         catch(treeError:*){check(false,"terminal display scan: "+String(treeError));}
         Log.d("ROOM ENTRY NATIVE VISIBILITY "+JSON.stringify({eligibleFrames:eligibleFrames,restoredFrames:restoredFrames,
            stationaryFrames:stationaryFrames,observerFaults:observerFaults,loadingViewCalled:false,
            diagnosticOnly:true,performanceQualified:false}));
         try {
            var scalarParity:Object=RoomScalarParity.run(mod.game.world);
            Log.d("ROOM SCALAR PARITY "+JSON.stringify(scalarParity));
            check(scalarParity.objects>0 && scalarParity.fields>0 && scalarParity.differences.length==0,
               "native tile/unit/weapon/object scalar capture preserves the previous implementation");
         } catch(scalarError:Error){check(false,"native scalar comparison: "+scalarError);}
         for(var label:String in pictures) {
            var b:BitmapData=pictures[label],file:FileStream=new FileStream();
            try {
               file.open(File.applicationStorageDirectory.resolvePath("presentation-room-entry-"+label+".png"),FileMode.WRITE);
               file.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));
            }catch(error:Error){check(false,"write capture "+label+": "+error);}
            finally {file.close();b.dispose();}
         }
      }
   }
}
