package {
   import fe.inter.MenuProbe;
   import authority.*;
   import authority.ui.*;
   import flash.desktop.NativeApplication;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.ServerSocketConnectEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.net.ServerSocket;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.getTimer;
   public class RConnectMod {
      public static const VERSION:String="B3-0.1-experimental";
      public static var instance:RConnectMod;
      public var main:Object,stage:Stage,access:NativeAccess,host:HostSession,replica:ClientReplica;
      public var config:Object,link:Link,probe:Probe;
      public var preferences:Preferences,hud:NetHud,ui:HudModel;
      public var vision:SharedVision;
      public var mode:String=HudModel.OFFLINE,peerName:String="队友",welcomed:Boolean=false;
      public var role:String="";
      public var tactics:TacticsBridge;
      public function get sessionId():String{return session;}
      private var intents:NativeIntents;
      private var nativeMenus:NativeMenus;
      private var saves:PersonalSaves;
      private var server:ServerSocket,input:InputSource=new InputSource(),label:TextField=new TextField();
      private var started:Boolean=false,travelled:Boolean=false,network:Boolean=false,stopping:Boolean=false;
      private var room:String,session:String,bootAt:int=getTimer(),readyFrames:int=0,failed:Boolean=false,lastHud:int=-1000;
      private var lastPolicy:String="";
      public static function init(main:Object):void {
         try{instance=new RConnectMod(main);}catch(error:*){Log.error(error);}
      }
      public function RConnectMod(main:Object) {
         this.main=main;stage=main.stage;
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-b-")!=0)throw new Error("B requires its isolated experimental launcher");
         var file:File=File.applicationDirectory.resolvePath("mods/Rconnect/release/config.txt"),stream:FileStream=new FileStream();
         stream.open(file,FileMode.READ);config=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));stream.close();
         if(config.experimental!==true || config.session==null || (config.role!=null && config.role!="" && config.role!="host" && config.role!="join"))throw new Error("Missing explicit B configuration");
         role=config.role==null?"":config.role;session=config.session;access=new NativeAccess(main);access.checkHooks();
         preferences=new Preferences(config);ui=new HudModel(this);hud=new NetHud(stage,ui);
         vision=new SharedVision(this);
         if(access.definition("fe.World")["rconnectChangeWorld"]!=null)throw new Error("Native lifecycle seam occupied");
         access.definition("fe.World")["rconnectChangeWorld"]=function():void {if(network)leaveSession(false);vision.resetJourney();};
         MapState.install(access);
         if(config.probe===true)probe=config.scenario=="dialogue"?new DialogueProbe(access,role=="host"):
            config.scenario=="menus"?new MenuProbe(access,role=="host"):
            config.scenario=="hud"?new HudProbe(access,role=="host"):
            config.scenario=="party"?new PartyProbe(access,role=="host"):
            config.scenario=="areas"?new AreasProbe(access,role=="host"):
            config.scenario=="mines"?new MinesProbe(access,role=="host"):
            config.scenario=="vectors"?new VectorProbe(access,role=="host"):
            config.scenario=="throw"?new ThrowProbe(access,role=="host"):
            config.scenario=="personal"?new PersonalProbe(access,role=="host"):
            config.scenario=="grabs"?new GrabsProbe(access,role=="host"):
            config.scenario=="friendly"?new FriendlyProbe(access,role=="host"):
            config.scenario=="travel"?new TravelProbe(access,role=="host"):
            config.scenario=="sats"?new SatsProbe(access,role=="host"):
            config.scenario=="lifecycle"?new LifecycleProbe(access,role=="host"):
            config.scenario=="cooperation"?new CooperationProbe(access,role=="host"):
            config.scenario=="split-rooms"?new SplitRoomProbe(access,role=="host",config.enemy):
            config.scenario=="ownership"?new OwnershipProbe(access,role=="host",config.swap===true,config.enemy):new Probe(access,role=="host");
         label.defaultTextFormat=new TextFormat("Arial",13,0xFFDB58);label.width=440;label.height=22;
         label.mouseEnabled=false;label.background=true;label.backgroundColor=0x161B20;label.alpha=.85;label.x=8;label.y=8;
         label.visible=false;label.text="RConnect B · 开发测试 · "+role;
         stage.addEventListener(Event.DEACTIVATE,deactivate,false,100000);
         stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         main.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onUncaught);
         Log.write("boot",{version:VERSION,source:BuildInfo.SOURCE,role:role,session:session});
      }
      private function deactivate(e:Event):void {e.stopImmediatePropagation();}
      private function onUncaught(e:UncaughtErrorEvent):void {Log.error(e.error);fail("Uncaught runtime error");e.preventDefault();}
      private function before(e:Event):void {
         if(getTimer()-lastHud>=100){lastHud=getTimer();ui.refresh();hud.refresh();}
         if(failed)return;
         try {
            var w:Object=access.world;
            if(w.verror.visible){fail(String(w.verror.txt.text));return;}
            if(!started && config.autoGame===true && w.landData!=null && w.allLandsLoaded) {
               started=true;Log.write("native-new-game",{landsReady:w.allLandsLoaded});
               w.mm.active=false;w.newGame(-1,"RConnect-B-"+role,null);return;
            }
            if(!access.ready()) {
               if(config.autoGame===true && getTimer()-bootAt>90000)fail("Native game boot timed out");
               return;
            }
            if(role==""){if(probe!=null)probe.observe(host,replica);return;}
            if(!travelled && config.land!=null && config.land!="") {
               travelled=true;
               if(w.land.act.id!==config.land){w.pip.onoff(-1);w.game.beginMission(config.land);return;}
            }
            if(!network && config.land!=null && config.land!="" && (w.land.act.id!==config.land || w.game.curLandId!==config.land))return;
            if(!network && (w.t_exit>0 || w.t_die>0 || !w.gg.ggControl || w.gg.work=="res" || w.gg.work=="change"))return;
            if(++readyFrames<5)return;
            if(!network) {
               w.pip.onoff(-1);
               if(probe!=null)probe.prepare();
               network=true;startNetwork();
            }
            if(role=="join")w.onPause=true;
            if(replica!=null && welcomed) {
               ++NativeIntents.replaying;
               try{replica.present();}finally{--NativeIntents.replaying;}
               if(replica.displayFrame!=null && replica.displayFrame.character!=null)saves.confirm(replica.displayFrame.character.saveRequests);
            }
            if(host!=null && host.active){host.menus();host.pause.update(host);}
            applyPreferences();
            if((role=="host" && host!=null && host.active) || (role=="join" && welcomed)) {
               input.acknowledge(role=="host"?host.inputs[0].receivedAction:
                  (replica.lastFrame==null?0:int(replica.lastFrame.players[1].actionAck)));
               var frame:Object=input.frame(w,session,role=="host"?0:1,room);
               var identity:Object=role=="host"?host.inputs[0]:(replica.lastFrame==null?null:replica.lastFrame.players[1]);
               if(identity!=null){frame.room=identity.room;frame.roomEpoch=identity.roomEpoch;frame.epoch=identity.epoch;}
               frame.weaponEpoch=role=="host"?host.inputs[0].weaponEpoch:
                  (replica.lastFrame==null?1:replica.lastFrame.players[1].weaponEpoch);
               if(probe!=null)frame=probe.input(frame,host);
               if(role=="host")host.localInput(frame);else link.send(frame);
            }
            if(vision!=null)vision.step();
            if(probe!=null)probe.observe(host,replica);
         }catch(error:*){Log.error(error);fail(String(error));}
      }
      private function startNetwork():void {
         room=access.roomKey();
         if(config.tdfc!=null)tactics=new TacticsBridge(main,access,session,role);
         if(role=="host") {
            host=new HostSession(access,session);host.failed=fail;
            lastPolicy="";
            host.pause.enabled=config.sharedPause===true;
            host.tactics=tactics;
            applyPreferences();mode=HudModel.HOSTING;
            server=new ServerSocket();server.bind(int(config.port),"127.0.0.1");server.listen();
            server.addEventListener(ServerSocketConnectEvent.CONNECT,onAccept);
            Log.write("listening",{port:config.port});
         } else {
            mode=HudModel.JOINING;
            replica=new ClientReplica(access);
            intents=new NativeIntents(access,input);
            nativeMenus=new NativeMenus(access,input);
            saves=new PersonalSaves(access,null,input);
            input.scene=replica.scene;
            replica.tactics=tactics;
            link=new Link();wire(link);
            link.connected=function():void {var hello:Object=Commands.greeting("hello",session);hello.tdfc=config.tdfc;hello.name=preferences.getValue("nickname");hello.profile=access.profile();link.send(hello);};
            link.connect(String(preferences.getValue("hostIp")),int(config.port));
         }
      }
      private function onAccept(e:ServerSocketConnectEvent):void {
         if(link!=null){e.socket.close();return;}
         link=new Link(e.socket);wire(link);
      }
      private function wire(value:Link):void {
         value.message=receive;value.closed=function(reason:String):void {
            if(stopping)return;
            if(probe!=null && probe.finished && reason=="peer closed") {
               Log.write("probe-cleanup-peer-closed",{reason:reason});return;
            }
            if(probe==null){leaveSession();ui.session.error=reason;}else fail(reason);
         };
      }
      private function receive(value:Object):void {
         if(failed)return;
         try {
            if(probe!=null)probe.message(value);
            if(value.type=="exploration" && welcomed && value.session===session){vision.receive(value);return;}
            if(value.type=="exploration-request" && welcomed && value.session===session){vision.resetLink();return;}
            if(value.type=="chat" && welcomed && value.session===session) {
               if(value.text is String && value.text.length<=512)hud.addChatLine(peerName,value.text);return;
            }
            if(value.type=="leave" && value.session===session){leaveSession();return;}
            if(role=="host") {
               if(value.type=="hello") {
                  if(value.tdfc!==config.tdfc)throw new Error("TDFC candidate mismatch");
                  peerName=value.name is String?String(value.name).substr(0,24):"加入侧";
                  host.accept(link,value);room=access.roomKey();welcomed=true;lastPolicy="";applyPreferences();
                  link.send({type:"peer-name",name:preferences.getValue("nickname")});
               }else host.receive(value);
            } else if(value.type=="welcome") {
               if(!Commands.greetingMatches(value,session))throw new Error("Welcome architecture/build mismatch");
               replica.peerProfile=value.profile;
               room=value.room;welcomed=true;mode=HudModel.CONNECTED;Log.write("joined",{room:room});
            } else if(value.type=="frame" && welcomed && value.session===session) {
               ++NativeIntents.replaying;
               try{replica.apply(value);}finally{--NativeIntents.replaying;}
               label.text="RConnect B · 开发测试 · "+role;
            }
            else if(value.type=="stopped")fail(value.reason);
            else if(value.type=="peer-name" && welcomed && value.name is String)peerName=String(value.name).substr(0,24);
            else if(value.type=="rejected")Log.write("input-rejected",value);
            else if(value.type=="notice"){label.text=String(value.text);ui.session.rooms.status=String(value.text);Log.write("notice",{text:value.text});}
            else if(value.type=="probe-result")Log.write("peer-probe-result",value);
         }catch(error:*){Log.error(error);fail(String(error));}
      }
      private function fail(reason:String):void {
         if(failed)return;
         failed=true;label.text="RConnect B · 已停止："+reason;
         ui.session.error=reason;
         if(access!=null && access.world!=null)access.world.onPause=true;
         if(host!=null)host.fail(reason);
         Log.write("FATAL",{reason:reason});
         if(probe!=null && !probe.finished){probe.check(false,"runtime completed without fatal error",{reason:reason});probe.finish();}
      }
      public function applyPreferences():void {
         input.settings.allowGrab=preferences.getValue("allowPeerGrip")=="1";
         input.settings.struggle=preferences.getValue("peerGripStruggle")!="0";
         input.settings.thrownDamage=preferences.getValue("peerThrowDamage")=="1";
         input.settings.follow=preferences.getValue("followTeammate")=="1";
         if(vision!=null)vision.enabled=preferences.getValue("sharedExploration")=="1";
         var policy:String=[preferences.getValue("pauseMenus"),preferences.getValue("pauseSats"),preferences.getValue("friendlyFire")].join(":");
         if(host!=null && policy!==lastPolicy) {
            lastPolicy=policy;
            host.pause.policyMenus=preferences.getValue("pauseMenus")=="1";
            host.pause.policySats=preferences.getValue("pauseSats")=="1";
            if(host.combat!=null)host.combat.enabled=preferences.getValue("friendlyFire")=="1";
         }
      }
      public function connectAs(requestedRole:String):void {
         if(network || requestedRole!="host" && requestedRole!="join")return;
         if(!access.ready() || access.world.mm.active || access.world.t_exit>0){ui.session.error="请先进入自己的游戏或载入角色，再开始联机。";return;}
         failed=false;role=requestedRole;config.port=int(preferences.getValue("port"));network=true;ui.session.error="";
         try {startNetwork();}catch(error:*){Log.error(error);leaveSession();ui.session.error=String(error);}
      }
      public function leaveSession(restoreJoin:Boolean=true):void {
         if(stopping)return;stopping=true;
         var oldReplica:ClientReplica=replica;
         try {
            if(link!=null){link.finish({type:"leave",session:session},"left session");link=null;}
            if(server!=null){try{server.close();}catch(ignored:*){}server=null;}
            if(intents!=null){intents.dispose();intents=null;}
            if(nativeMenus!=null){nativeMenus.dispose();nativeMenus=null;}
            if(saves!=null){saves.dispose();saves=null;}
            if(host!=null){host.dispose();host=null;tactics=null;}
            if(replica!=null){replica.dispose();replica=null;if(tactics!=null){tactics.dispose();tactics=null;}}
            if(restoreJoin && oldReplica!=null)oldReplica.returnToOwnGame();
            access.world.onPause=false;access.world.ctr.clearAll();input=new InputSource();
            welcomed=network=failed=false;role="";mode=HudModel.OFFLINE;ui.session.rooms.status="";
            vision.resetLink();
         }finally{stopping=false;}
      }
      public function sendChat(text:String):void {
         text=text.substr(0,512);if(!welcomed || text.replace(/^\s+|\s+$/g,"")=="")return;
         if(link.send({type:"chat",session:session,text:text}))hud.addChatLine(String(preferences.getValue("nickname")),text);
      }
      public function meetReason():String {
         var f:Object=host!=null?host.lastFrame:replica==null?null:replica.lastFrame;
         if(!welcomed || f==null)return "请先连接队友。";
         if(f.players[0].hp<=0 || f.players[1].hp<=0)return "双方存活后可传送。";
         return "";
      }
      public function meetPeer():void {var reason:String=meetReason();if(reason!=""){ui.session.rooms.status=reason;return;}input.enqueue({type:"native",key:"meetPeer",args:[]});}
   }
}
