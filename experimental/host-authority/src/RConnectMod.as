package {
   import authority.*;
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
      public static const VERSION:String="B1-0.1-experimental";
      public static var instance:RConnectMod;
      public var main:Object,stage:Stage,access:NativeAccess,host:HostSession,replica:ClientReplica;
      public var config:Object,link:Link,probe:Probe;
      public var tactics:TacticsBridge;
      private var server:ServerSocket,input:InputSource=new InputSource(),label:TextField=new TextField();
      private var started:Boolean=false,travelled:Boolean=false,network:Boolean=false,welcomed:Boolean=false;
      private var role:String,room:String,session:String,bootAt:int=getTimer(),readyFrames:int=0,failed:Boolean=false;
      public static function init(main:Object):void {
         try{instance=new RConnectMod(main);}catch(error:*){Log.error(error);}
      }
      public function RConnectMod(main:Object) {
         this.main=main;stage=main.stage;
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-b-")!=0)throw new Error("B1 requires its isolated experimental launcher");
         var file:File=File.applicationDirectory.resolvePath("mods/Rconnect/release/config.txt"),stream:FileStream=new FileStream();
         stream.open(file,FileMode.READ);config=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));stream.close();
         if(config.experimental!==true || config.session==null || (config.role!="host" && config.role!="join"))throw new Error("Missing explicit B configuration");
         role=config.role;session=config.session;access=new NativeAccess(main);access.checkHooks();
         if(config.probe===true)probe=config.scenario=="ownership"?new OwnershipProbe(access,role=="host",config.swap===true,config.enemy):new Probe(access,role=="host");
         label.defaultTextFormat=new TextFormat("Arial",13,0xFFDB58);label.width=440;label.height=22;
         label.mouseEnabled=false;label.background=true;label.backgroundColor=0x161B20;label.alpha=.85;label.x=8;label.y=8;
         stage.addChild(label);label.text="RConnect B1 · 实验原型 · "+role;
         stage.addEventListener(Event.DEACTIVATE,deactivate,false,100000);
         stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         main.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onUncaught);
         Log.write("boot",{version:VERSION,source:BuildInfo.SOURCE,role:role,session:session});
      }
      private function deactivate(e:Event):void {e.stopImmediatePropagation();}
      private function onUncaught(e:UncaughtErrorEvent):void {Log.error(e.error);fail("Uncaught runtime error");e.preventDefault();}
      private function before(e:Event):void {
         if(failed)return;
         try {
            var w:Object=access.world;
            if(w.verror.visible){fail(String(w.verror.txt.text));return;}
            if(!started && config.autoGame===true && w.landData!=null && w.allLandsLoaded) {
               started=true;Log.write("native-new-game",{landsReady:w.allLandsLoaded});
               w.mm.active=false;w.newGame(-1,"RConnect-B-"+role,null);return;
            }
            if(!access.ready()) {
               if(getTimer()-bootAt>90000)fail("Native game boot timed out");
               return;
            }
            if(!travelled && config.land!=null && config.land!="") {
               travelled=true;
               if(w.land.act.id!==config.land){w.pip.onoff(-1);w.game.beginMission(config.land);return;}
            }
            if(config.land!=null && config.land!="" && (w.land.act.id!==config.land || w.game.curLandId!==config.land))return;
            if(w.t_exit>0 || w.t_die>0 || !w.gg.ggControl || w.gg.work=="res" || w.gg.work=="change")return;
            if(++readyFrames<5)return;
            if(!network) {
               w.pip.onoff(-1);
               if(probe!=null)probe.prepare();
               network=true;startNetwork();
            }
            if(role=="join")w.onPause=true;
            if((role=="host" && host!=null && host.active) || (role=="join" && welcomed)) {
               var frame:Object=input.frame(w,session,role=="host"?0:1,room);
               frame.weaponEpoch=role=="host"?host.inputs[0].weaponEpoch:
                  (replica.lastFrame==null?1:replica.lastFrame.players[1].weaponEpoch);
               if(probe!=null)frame=probe.input(frame,host);
               if(role=="host")host.localInput(frame);else link.send(frame);
            }
            if(probe!=null)probe.observe(host,replica);
         }catch(error:*){Log.error(error);fail(String(error));}
      }
      private function startNetwork():void {
         room=access.roomKey();
         if(config.tdfc!=null)tactics=new TacticsBridge(main,access,session,role);
         if(role=="host") {
            host=new HostSession(access,session);host.failed=fail;
            host.tactics=tactics;
            server=new ServerSocket();server.bind(int(config.port),"127.0.0.1");server.listen();
            server.addEventListener(ServerSocketConnectEvent.CONNECT,onAccept);
            Log.write("listening",{port:config.port});
         } else {
            replica=new ClientReplica(access);
            replica.tactics=tactics;
            link=new Link();wire(link);
            link.connected=function():void {var hello:Object=Commands.greeting("hello",session);hello.tdfc=config.tdfc;hello.profile=access.profile();link.send(hello);};
            link.connect("127.0.0.1",int(config.port));
         }
      }
      private function onAccept(e:ServerSocketConnectEvent):void {
         if(link!=null){e.socket.close();return;}
         link=new Link(e.socket);wire(link);
      }
      private function wire(value:Link):void {
         value.message=receive;value.closed=function(reason:String):void {
            if(probe!=null && probe.finished && reason=="peer closed") {
               Log.write("probe-cleanup-peer-closed",{reason:reason});return;
            }
            fail(reason);
         };
      }
      private function receive(value:Object):void {
         try {
            if(role=="host") {
               if(value.type=="hello") {
                  if(value.tdfc!==config.tdfc)throw new Error("TDFC candidate mismatch");
                  host.accept(link,value);room=access.roomKey();welcomed=true;
               }else host.receive(value);
            } else if(value.type=="welcome") {
               if(!Commands.greetingMatches(value,session))throw new Error("Welcome architecture/build mismatch");
               if(value.room!==access.roomKey())throw new Error("B1 requires matching native room before activation");
               room=value.room;welcomed=true;Log.write("joined",{room:room});
            } else if(value.type=="frame" && welcomed && value.session===session && value.room===room)replica.apply(value);
            else if(value.type=="stopped")fail(value.reason);
            else if(value.type=="rejected")Log.write("input-rejected",value);
            else if(value.type=="probe-result")Log.write("peer-probe-result",value);
         }catch(error:*){Log.error(error);fail(String(error));}
      }
      private function fail(reason:String):void {
         if(failed)return;
         failed=true;label.text="RConnect B1 · 已停止："+reason;
         if(access!=null && access.world!=null)access.world.onPause=true;
         if(host!=null)host.fail(reason);
         Log.write("FATAL",{reason:reason});
         if(probe!=null && !probe.finished){probe.check(false,"runtime completed without fatal error",{reason:reason});probe.finish();}
      }
   }
}
