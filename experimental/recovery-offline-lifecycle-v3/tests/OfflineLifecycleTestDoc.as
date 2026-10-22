package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.ErrorEvent;
   import flash.events.IOErrorEvent;
   import flash.events.MouseEvent;
   import flash.events.ProgressEvent;
   import flash.events.SecurityErrorEvent;
   import flash.events.ServerSocketConnectEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.net.ServerSocket;
   import flash.net.Socket;
   import flash.utils.ByteArray;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** One real Session, real localhost transports, no protocol impersonation.
    * Compile against existing external declarations; new APIs use Object access. */
   public final class OfflineLifecycleTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const EXPECTED_VERSION:String="0.2.24-offline1";
      private static const TOTAL_MS:int=240000,BOOT_MS:int=180000,PHASE_MS:int=15000;
      private var mod:RConnectMod,session:Object,bridge:Object,config:Object,world:Object,nativeGame:Object,actor:Object;
      private var eligibility:Function,savedConfig:Object,version:String="";
      private var phase:String="boot",began:int=getTimer(),phaseAt:int=began,frame:int=0,phaseFrame:int=0;
      private var checks:int=0,failed:int=0,finished:Boolean=false,prepared:Boolean=false,bootTravel:Boolean=false;
      private var observations:Array=[],phases:Array=[],servers:Array=[],sockets:Array=[],ports:Array=[];
      private var coverage:Object={virgin:false,virginLeave:false,hostNoPeer:false,hostLeave:false,
         joinFailed:false,failedLeave:false,failedRetry:false,loopbackConnected:false,
         loopbackClosed:false,loopbackRetry:false,occupiedHostFailed:false,finalLeave:false};
      private var watchdog:Timer;
      private var refusal:ServerSocket,acceptor:ServerSocket,blocker:ServerSocket,accepted:Socket;
      private var observedLink:Object,observedSocket:Socket,linkTag:String="";
      private var linkConnected:int=0,linkClosed:int=0,linkFailed:int=0,rawErrors:int=0,accepts:int=0;
      private var receivedBytes:int=0,abortReason:String="",stableFrames:int=0;

      public function OfflineLifecycleTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-host-")!=0)return;
         phases.push({name:phase,at:phaseAt,frame:frame});
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         addEventListener(Event.ENTER_FRAME,tick);
         watchdog=new Timer(250);watchdog.addEventListener(TimerEvent.TIMER,watch);watchdog.start();
      }
      private function ensure(ok:Boolean,label:String):void {
         ++checks;if(!ok)++failed;
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"offline-lifecycle "+label);
         if(!ok)throw new Error(label);
      }
      private function note(label:String,extra:Object=null):void {
         if(observations.length>=96)throw new Error("Observation bound exceeded");
         var row:Object={label:label,at:getTimer(),frame:frame,phase:phase,phaseFrame:phaseFrame};
         if(session!=null){row.mode=String(session.mode);row.error=String(session.error);}
         if(extra!=null)row.detail=extra;
         observations.push(row);
      }
      private function closePhase():void {
         var p:Object=phases[phases.length-1];
         if(p.endAt==null){p.endAt=getTimer();p.endFrame=frame;p.elapsedMs=p.endAt-p.at;p.enterCallbacks=frame-p.frame;}
      }
      private function change(next:String):void {
         closePhase();if(phases.length>=24)throw new Error("Phase bound exceeded");
         phase=next;phaseAt=getTimer();phaseFrame=0;phases.push({name:phase,at:phaseAt,frame:frame});note("phase");
      }
      private function identity():void {
         if(RConnectMod.instance!==mod || Object(mod.session)!==session || Object(mod.game)!==bridge
            || Object(mod.config)!==config || bridge.world!==world || world.game!==nativeGame || bridge.gg!==actor)
            throw new Error("Native mod/Session/GameBridge/World/Game/player identity changed");
         if(bridge.offlinePresentationEligibility!==eligibility)throw new Error("Eligibility hook identity changed");
         if(world.verror!=null && world.verror.visible)throw new Error("Native error dialog: "+String(world.verror.txt.text));
      }
      private function qualifies(expected:Boolean,label:String):void {
         identity();
         var direct:*=session.canSkipOfflinePresentation(),hook:*=eligibility();
         ensure(direct===expected && hook===expected,label);
         note(label,{direct:direct,hook:hook});
      }
      private function prepare():void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.session==null || mod.game.gg==null)return;
         var w:Object=mod.game.world;
         if(w==null || w.game==null)return;
         if(w.verror!=null && w.verror.visible)throw new Error("Native boot error dialog: "+String(w.verror.txt.text));
         if(w.clickReq==1) {
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
         }
         // The production auto-travel path is inactive for this offline role.
         // Use the native public journey once after normal new-game bootstrap.
         if(!bootTravel && String(w.game.curLandId)=="begin" && !mod.game.isTransitioning()
            && int(w.ng_wait)==0 && int(w.comLoad)<0 && w.allStat==1 && !w.onPause) {
            bootTravel=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand("rbl");
            note("native-bootstrap-travel",{target:"rbl"});return;
         }
         if(String(w.game.curLandId)!=="rbl" || w.land==null || w.land.act==null || String(w.land.act.id)!=="rbl") {
            stableFrames=0;return;
         }
         if(mod.game.isTransitioning() || int(w.ng_wait)>0 || int(w.comLoad)>=0){stableFrames=0;return;}
         if(++stableFrames<5)return;
         session=Object(mod.session);bridge=Object(mod.game);config=Object(mod.config);
         world=w;nativeGame=w.game;actor=bridge.gg;
         version=String(Object(MOD_CLASS)["VERSION"]);
         ensure(version===EXPECTED_VERSION,"exact offline1 production version is loaded");
         ensure(String(config.getValue("autoRole"))==="","isolated runner has no automatic network role");
         ensure(session.canSkipOfflinePresentation is Function && bridge.offlinePresentationEligibility is Function,
            "real public eligibility API and production hook exist");
         eligibility=bridge.offlinePresentationEligibility as Function;
         ensure(session.mode==="offline" && session.server==null && session.link==null
            && session.peers.length==0 && session.remotes.length==0,"virgin real Session is initially offline");
         savedConfig={port:config.getValue("port"),hostIp:config.getValue("hostIp")};prepared=true;
         config.setValue("hostIp","127.0.0.1");
         qualifies(true,"never-networked Session and hook permit offline collection shortcut");coverage.virgin=true;
         session.leave();
         qualifies(true,"ordinary leave before any attempt preserves virgin eligibility");coverage.virginLeave=true;
         change("virgin-leave");
      }
      private function localServer(label:String,listen:Boolean):ServerSocket {
         var s:ServerSocket=new ServerSocket();servers.push(s);
         s.bind(0,"127.0.0.1");if(listen)s.listen();
         ensure(s.bound && s.localPort>0 && s.localPort<=65535 && s.localAddress==="127.0.0.1"
            && s.listening===listen,"owned bind0 localhost endpoint: "+label);
         ports.push({purpose:label,port:s.localPort,listening:listen});return s;
      }
      private function beginEmptyHost():void {
         var reservation:ServerSocket=localServer("empty-host-reservation",false),port:int=reservation.localPort;
         reservation.close();config.setValue("port",port);change("host-empty");session.startHost();
         ensure(session.server!=null && session.server.bound===true && session.server.port==port
            && session.mode==="hosting" && session.peers.length==0 && session.server.clients.length==0,
            "actual host listens with no peer");
         qualifies(false,"startHost revokes eligibility even without a peer");
      }
      private function detachLink():void {
         if(observedLink!=null) {
            observedLink.removeEventListener("connected",onLinkEvent);
            observedLink.removeEventListener("closed",onLinkEvent);
            observedLink.removeEventListener("failed",onLinkEvent);
         }
         if(observedSocket!=null) {
            observedSocket.removeEventListener(IOErrorEvent.IO_ERROR,onRawError);
            observedSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,onRawError);
         }
         observedLink=null;observedSocket=null;
      }
      private function beginJoin(next:String,port:int):void {
         detachLink();linkConnected=linkClosed=linkFailed=rawErrors=0;accepted=null;linkTag=next;
         config.setValue("port",port);change(next);session.startJoin();
         observedLink=session.link;
         ensure(observedLink!=null && observedLink.socket is Socket,"startJoin created an actual TcpLink and Socket");
         observedSocket=observedLink.socket as Socket;sockets.push(observedSocket);
         observedLink.addEventListener("connected",onLinkEvent);
         observedLink.addEventListener("closed",onLinkEvent);
         observedLink.addEventListener("failed",onLinkEvent);
         observedSocket.addEventListener(IOErrorEvent.IO_ERROR,onRawError);
         observedSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onRawError);
         qualifies(false,"eligibility remains revoked at "+next);
      }
      private function onLinkEvent(e:Event):void {
         if(finished)return;
         try {
            identity();if(e.currentTarget!==observedLink)throw new Error("Unexpected link event owner");
            if(e.type==="connected")++linkConnected;else if(e.type==="closed")++linkClosed;else ++linkFailed;
            note("actual-link-event",{kind:e.type,attempt:linkTag,isOpen:observedLink.isOpen});
         }catch(error:*){abort(error);}
      }
      private function onRawError(e:ErrorEvent):void {
         if(finished)return;
         try {
            identity();if(e.currentTarget!==observedSocket)throw new Error("Unexpected socket error owner");
            ++rawErrors;note("actual-socket-error",{attempt:linkTag,kind:e.type,text:e.text});
            if(phase!=="join-refused" && phase!=="join-refused-retry")throw new Error("Unexpected transport error "+e.text);
         }catch(error:*){abort(error);}
      }
      private function onAccept(e:ServerSocketConnectEvent):void {
         sockets.push(e.socket);
         if(finished){try{e.socket.close();}catch(ignored:*){}return;}
         try {
            identity();
            if(e.currentTarget!==acceptor || phase.indexOf("loopback-")!=0 || accepted!=null
               || e.socket.remoteAddress!=="127.0.0.1")throw new Error("Unexpected local acceptance");
            accepted=e.socket;++accepts;
            accepted.addEventListener(ProgressEvent.SOCKET_DATA,discardGreeting);
            accepted.addEventListener(IOErrorEvent.IO_ERROR,acceptedError);
            accepted.addEventListener(SecurityErrorEvent.SECURITY_ERROR,acceptedError);
            note("actual-loopback-accept",{attempt:linkTag,remoteAddress:accepted.remoteAddress,remotePort:accepted.remotePort});
         }catch(error:*){abort(error);}
      }
      private function discardGreeting(e:ProgressEvent):void {
         if(finished)return;
         try {
            identity();var s:Socket=e.currentTarget as Socket,count:uint=s.bytesAvailable;
            receivedBytes+=count;if(receivedBytes>16384)throw new Error("Greeting traffic exceeds bounded test scope");
            if(count>0)s.readBytes(new ByteArray(),0,count);
            note("discard-native-greeting",{bytes:count});
            // Do not decode/respond/send WELCOME. This is transport-only, not a fake cooperating game.
         }catch(error:*){abort(error);}
      }
      private function acceptedError(e:ErrorEvent):void {if(!finished)abort(new Error("Loopback accepted socket error: "+e.text));}
      private function rejectedUnexpectedPeer(e:ServerSocketConnectEvent):void {
         sockets.push(e.socket);try{e.socket.close();}catch(ignored:*){}
         if(!finished)abort(new Error("Unexpected connection to reserved conflict endpoint"));
      }
      private function observeRefusal():Boolean {
         if(linkFailed==0 || rawErrors==0)return false;
         ensure(refusal!=null && refusal.bound && !refusal.listening && observedLink.isOpen===false
            && !observedSocket.connected && session.mode==="offline"
            && String(session.error)==="connect failed (check ip/port)","actual FAILED and socket error came from owned non-listening port");
         qualifies(false,"real failed connection does not re-enable offline shortcut");return true;
      }
      private function observeConnected():Boolean {
         if(linkConnected==0 || accepted==null || !accepted.connected || observedLink.isOpen!==true)return false;
         ensure(linkFailed==0 && rawErrors==0 && observedSocket.connected && observedSocket.remoteAddress==="127.0.0.1"
            && session.mode==="joining" && session.remotes.length==0,"real localhost transport connected without a cooperative handshake");
         qualifies(false,"transport connection and greeting keep eligibility revoked");return true;
      }
      private function tick(e:Event):void {
         if(finished)return;++frame;++phaseFrame;
         try {
            deadline();if(phase==="boot"){prepare();return;}identity();
            if(phase==="virgin-leave" && phaseFrame>=5) {
               qualifies(true,"virgin leave remains eligible across real ENTER callbacks");beginEmptyHost();
            }else if(phase==="host-empty" && phaseFrame>=5) {
               ensure(session.peers.length==0 && session.server.clients.length==0,"host remained peer-free");
               qualifies(false,"peer-free hosting remains on normal path across callbacks");coverage.hostNoPeer=true;
               session.leave();qualifies(false,"leaving host preserves attempted-session history");coverage.hostLeave=true;change("host-left");
            }else if(phase==="host-left" && phaseFrame>=5) {
               ensure(session.mode==="offline" && session.server==null && session.link==null,"normal host leave cleaned transport references");
               refusal=localServer("refused-join",false);beginJoin("join-refused",refusal.localPort);
            }else if(phase==="join-refused" && observeRefusal()) {
               coverage.joinFailed=true;session.leave();detachLink();
               qualifies(false,"leave after a real FAILED preserves history");coverage.failedLeave=true;change("failed-left");
            }else if(phase==="failed-left" && phaseFrame>=5) {
               ensure(session.mode==="offline" && session.link==null,"failed-link leave completed native cleanup");
               beginJoin("join-refused-retry",refusal.localPort);
            }else if(phase==="join-refused-retry" && observeRefusal()) {
               coverage.failedRetry=true;session.leave();detachLink();refusal.close();
               acceptor=localServer("transport-only-loopback",false);
               acceptor.addEventListener(ServerSocketConnectEvent.CONNECT,onAccept);acceptor.listen();
               beginJoin("loopback-connect",acceptor.localPort);
            }else if(phase==="loopback-connect" && observeConnected()) {
               coverage.loopbackConnected=true;change("loopback-peer-close");accepted.close();
            }else if(phase==="loopback-peer-close" && linkClosed>0) {
               ensure(observedLink.isOpen===false && !observedSocket.connected && session.mode==="offline",
                  "real peer close triggered native link-close cleanup");
               qualifies(false,"actual disconnect preserves history");coverage.loopbackClosed=true;
               beginJoin("loopback-retry",acceptor.localPort);
            }else if(phase==="loopback-retry" && observeConnected()) {
               ensure(accepts==2,"manual reconnect reached the real loopback listener twice");coverage.loopbackRetry=true;
               session.leave();detachLink();qualifies(false,"manual reconnect and leave do not reset eligibility");
               acceptor.close();blocker=localServer("occupied-host",true);
               blocker.addEventListener(ServerSocketConnectEvent.CONNECT,rejectedUnexpectedPeer);
               config.setValue("port",blocker.localPort);change("host-conflict");session.startHost();
               // 574D sets HOSTING after listen() even if its synchronous FAILED fired. Do not fix or reject that existing quirk.
               ensure(blocker.bound && blocker.listening && session.server!=null && session.server.bound===false
                  && String(session.error)==="host failed (port busy?)","owned listening port caused actual native host bind failure");
               qualifies(false,"real host bind failure cannot re-enable shortcut");coverage.occupiedHostFailed=true;
               note("host-failure-existing-mode",{bound:session.server.bound,mode:String(session.mode)});
            }else if(phase==="host-conflict" && phaseFrame>=5) {
               session.leave();blocker.close();qualifies(false,"final leave remains in attempted-session path");
               ensure(session.mode==="offline" && session.server==null && session.link==null
                  && session.peers.length==0 && session.remotes.length==0,"final actual Session transport state is clean");
               coverage.finalLeave=true;change("final-offline");
            }else if(phase==="final-offline" && phaseFrame>=5) {
               qualifies(false,"final eligibility remains false across real callbacks");
               for(var key:String in coverage)ensure(coverage[key]===true,"required lifecycle coverage: "+key);
               finish();
            }
         }catch(error:*){abort(error);}
      }
      private function deadline():void {
         if(getTimer()-began>TOTAL_MS || getTimer()-phaseAt>(phase==="boot"?BOOT_MS:PHASE_MS))
            throw new Error("Absolute/phase timeout at "+phase);
      }
      private function watch(e:TimerEvent):void {
         if(finished)return;
         try{deadline();if(prepared)identity();}catch(error:*){abort(error);}
      }
      private function uncaught(e:UncaughtErrorEvent):void {e.preventDefault();abort(e.error);}
      private function abort(error:*):void {
         if(finished)return;abortReason=String(error);++failed;Log.d("COOP FAIL offline-lifecycle "+abortReason);finish();
      }
      private function cleanupFailure(errors:Array,error:*):void {errors.push(String(error));++failed;Log.d("COOP FAIL offline-lifecycle cleanup "+error);}
      private function finish():void {
         if(finished)return;finished=true;closePhase();removeEventListener(Event.ENTER_FRAME,tick);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         if(watchdog!=null){watchdog.stop();watchdog.removeEventListener(TimerEvent.TIMER,watch);}
         var errors:Array=[],cleanup:Object={errors:errors,configRestored:false,sessionReleased:false,ownedServers:servers.length,ownedSockets:sockets.length,socketStates:[],serverStates:[]};
         try {
            try{detachLink();}catch(detachError:*){cleanupFailure(errors,detachError);}
            if(prepared && RConnectMod.instance===mod && Object(mod.session)===session && Object(mod.game)===bridge) {
               try{session.leave();cleanup.sessionReleased=session.mode==="offline" && session.server==null && session.link==null;}
               catch(leaveError:*){cleanupFailure(errors,leaveError);}
            }
         }finally {
            for each(var s:Socket in sockets) {
               s.removeEventListener(ProgressEvent.SOCKET_DATA,discardGreeting);
               s.removeEventListener(IOErrorEvent.IO_ERROR,acceptedError);
               s.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,acceptedError);
               // Session.leave already closes its transports. Only connected
               // endpoints still need closing; do not re-close a released one.
               try {
                  var socketState:Object={index:sockets.indexOf(s),connectedBefore:s.connected};
                  cleanup.socketStates.push(socketState);
                  if(s.connected)s.close();
                  socketState.connectedAfter=s.connected;
                  if(s.connected)throw new Error("Owned socket remains connected after cleanup");
               }catch(socketError:*){cleanupFailure(errors,"Socket["+sockets.indexOf(s)+"] "+socketError);}
            }
            for each(var server:ServerSocket in servers) {
               server.removeEventListener(ServerSocketConnectEvent.CONNECT,onAccept);
               server.removeEventListener(ServerSocketConnectEvent.CONNECT,rejectedUnexpectedPeer);
               try {
                  var serverState:Object={index:servers.indexOf(server),boundBefore:server.bound,listeningBefore:server.listening};
                  cleanup.serverStates.push(serverState);
                  if(server.bound)server.close();
                  serverState.boundAfter=server.bound;serverState.listeningAfter=server.listening;
                  if(server.bound || server.listening)throw new Error("Owned server remains bound after cleanup");
               }catch(serverError:*){cleanupFailure(errors,"ServerSocket["+servers.indexOf(server)+"] "+serverError);}
            }
            if(prepared && Object(mod.config)===config) {
               try {
                  config.setValue("port",savedConfig.port);config.setValue("hostIp",savedConfig.hostIp);
                  cleanup.configRestored=config.getValue("port")===savedConfig.port && config.getValue("hostIp")===savedConfig.hostIp;
                  if(!cleanup.configRestored)throw new Error("Private config restore differs");
               }catch(configError:*){cleanupFailure(errors,configError);}
            }
         }
         if(prepared && !cleanup.sessionReleased)cleanupFailure(errors,"Owned Session cleanup not confirmed");
         if(prepared && !cleanup.configRestored)cleanupFailure(errors,"Private config cleanup not confirmed");
         Log.d("OFFLINE LIFECYCLE RESULT "+JSON.stringify({passed:failed==0,checks:checks,failed:failed,version:version,
            applicationId:NativeApplication.nativeApplication.applicationID,phase:phase,abortReason:abortReason,
            elapsedMs:getTimer()-began,enterCallbacks:frame,phases:phases,observations:observations,coverage:coverage,
            ports:ports,runnerPort:savedConfig==null?null:savedConfig.port,loopbackAccepts:accepts,discardedGreetingBytes:receivedBytes,
            cleanup:cleanup,functionOnly:true,performanceQualified:false,twoGameConnectionQualified:false,
            cooperativeHandshakeQualified:false,automaticReconnectQualified:false,failedFirstAttemptQualified:false,
            collectorExecutionQualified:false,nullThrowCollectorFallbackQualified:false}));
         Log.d("COOP EFFECTS DONE offline-lifecycle");
      }
   }
}
