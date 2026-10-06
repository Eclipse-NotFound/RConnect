package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.IMEEvent;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Rectangle;
   import flash.net.SharedObject;
   import flash.system.System;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.Session;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   import rconnect.ui.NetHud;

   /** Actual production HUD and native Ctr; synthetic events are not hardware input. */
   public class HudTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),n:int=0,remoteReady:Boolean=false,remoteDone:Boolean=false;
      private var chatReceived:Boolean=false,pauseAck:Boolean=false,remotePauseReady:Boolean=false,shot:String="",shotDone:Boolean=true;
      private var remoteRoom:String="",remoteLand:String="",remoteEpoch:int=-1,readySince:int=0,offlineGo:Boolean=false;
      private var oldLang:String,oldBounds:Rectangle,menus:Boolean,sats:Boolean,imeSentBefore:int=0;
      public function HudTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"hud "+s);}
      private function change(p:String):void {phase=p;at=getTimer();}
      private function landId():String {return String(GameBridge.probe(GameBridge.probe(mod.game.world,"game"),"curLandId"));}
      private function send(op:String):void {
         if(mod==null || mod.session==null)return;
         var p:Object={type:"hud-test",op:op,room:mod.game.roomKey(),land:landId(),epoch:mod.game.roomEpoch};
         if(host && mod.session.server!=null)mod.session.server.broadcast(p);
         else if(mod.session.link!=null && mod.session.link.isOpen)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function receive(e:NetMessageEvent):void {
         if(e.data.type=="chat" && String(e.data.text).indexOf("hud-exact-")==0)chatReceived=true;
         if(e.data.type!="hud-test")return;
         if(e.data.op=="done" || e.data.op=="offline-go")Log.d("HUD HANDSHAKE rx="+e.data.op+" phase="+phase);
         if(e.data.op=="ready") {
            remoteReady=true;remoteRoom=String(e.data.room);remoteLand=String(e.data.land);remoteEpoch=int(e.data.epoch);
         }
         if(e.data.op=="done")remoteDone=true;
         if(e.data.op=="pause-ack")pauseAck=true;
         if(e.data.op=="pause-ready")remotePauseReady=true;
         if(e.data.op=="offline-go")offlineGo=true;
      }
      private function uncaught(e:UncaughtErrorEvent):void {
         check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
         e.preventDefault();finish();
      }
      private function click(id:String):void {
         var t:TextField=mod.hud.getChildByName(id) as TextField;
         if(t==null || !t.visible || !t.mouseEnabled)throw new Error("unavailable visible UI control "+id);
         t.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
         t.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
         t.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
      }
      private function key(code:uint,ctrl:Boolean=false):void {
         var target:DisplayObject=mod.stage.focus as DisplayObject;
         if(target==null)target=mod.stage;
         target.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,code,code,0,ctrl));
         target.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,code,code,0,ctrl));
      }
      private function picture(s:String):void {shot=s;shotDone=false;mod.stage.invalidate();}
      private function render(e:Event):void {
         if(shot=="")return;
         var bitmap:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         bitmap.draw(mod.stage);
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath(shot+".png"),FileMode.WRITE);
         fs.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));fs.close();bitmap.dispose();
         Log.d("HUD PNG "+shot);shot="";shotDone=true;
      }
      private function step():void {
         var h:NetHud=mod.hud,w:Object=mod.game.world,ctr:Object=w.ctr,t:TextField;
         if(n==0) {
            check(h.collapsed && h.panelHeight==36,"fresh preferences default to 36-unit strip");
            check(h.tfChat.defaultTextFormat.size==12,"primary input keeps 12-unit font");
            picture("hud-collapsed");
         } else if(n==1) {
            h.openPage("connect");
            check(h.panelHeight<=240 && h.currentPage=="connect","connection page has bounded outer shell");
            check(!h.tfNick.visible && h.getChildByName("rconnect-leave").visible,"active session has leave, hides setup fields");
            picture("hud-connect");
         } else if(n==2) {
            h.openPage("peer");
            check(h.getChildByName("rconnect-teleport").parent===h,"legacy named navigation control remains direct child");
            var was:String=String(mod.config.getValue("followTeammate"));
            click("rconnect-follow");check(String(mod.config.getValue("followTeammate"))!=was,"visible follow button uses real config");
            click("rconnect-follow");
            var explored:Boolean=mod.exploration.enabled;click("rconnect-exploration");
            check(mod.exploration.enabled!=explored,"visible exploration toggle uses existing receiver");click("rconnect-exploration");
            picture("hud-peer");
         } else if(n==3) {
            h.openPage("chat",true);
            ctr.clearAll();key(65);key(32);key(81);
            check(!ctr.keyLeft && !ctr.keyJump && !ctr.keyTele,"typing keys do not reach native movement or telekinesis");
            h.tfChat.text="hud-exact-"+(host?"host":"join")+" <b>原样</b>";key(13);
            check(h.tfChat.text=="" && mod.stage.focus===h.tfChat,"Enter sends and retains native text input focus");
            picture("hud-chat");
         } else if(n==4) {
            h.collapse();
            var before:int=h.unreadCount;h.addChatLine("示例队友","<b>plain & safe</b>");
            check(h.collapsed && h.unreadCount>before && mod.stage.focus!==h.tfChat,"new message is unread without expanding or stealing focus");
            t=h.getChildByName("rconnect-chat") as TextField;
            check(t.textWidth<t.width-4,"unread chat label fits its native field");
            key(13,true);check(h.currentPage=="chat" && !h.collapsed && mod.stage.focus===h.tfChat,"Ctrl+Enter opens chat during ordinary play");
            check(h.unreadCount==0,"viewing chat clears unread count");
            h.tfChat.text="IME text retained";
            System.ime.dispatchEvent(new IMEEvent(IMEEvent.IME_START_COMPOSITION));key(13);
            check(h.tfChat.text=="IME text retained","Enter during composition does not send");
            System.ime.dispatchEvent(new IMEEvent(IMEEvent.IME_COMPOSITION));key(13);
            check(h.tfChat.text=="IME text retained","IME commit Enter is not a chat send");h.tfChat.text="";
         } else if(n==5) {
            for(var i:int=0;i<60;i++)h.addChatLine("玩家 {0}","literal-message-"+i);
            check(h.chatLog.text.indexOf("literal-message-0\n")<0 && h.chatLog.text.indexOf("literal-message-59")>=0,"chat retains last fifty records");
            check(h.chatLog.text.indexOf("玩家 {0}")>=0,"player names are not translated or interpolated");
            key(121);check(!h.visible && mod.stage.focus!==h.tfChat,"F10 hides and releases owned input");
            key(121);check(h.visible && !h.collapsed,"F10 restores prior expanded state");
            h.openPage("settings");
         } else if(n>=6 && n<=8) {
            w.lang=["en","ru","tw"][n-6];h.refresh();
            for each(var id:String in ["rconnect-pause-menus","rconnect-pause-sats"]) {
               t=h.getChildByName(id) as TextField;
               check(t.parent===h && t.textWidth<t.width-4,"real native label fits "+w.lang+" "+id);
               check(t.mouseEnabled==host,"pause policy permission matches real role "+id);
            }
            picture("hud-settings-"+w.lang);
         } else if(n==9) {
            w.lang=oldLang;h.setDock("br");h.collapse(false);
            check(h.x+h.panelWidth*h.scaleX<=mod.stage.stageWidth-7 && h.y+h.panelHeight*h.scaleY<=mod.stage.stageHeight-7,"bottom-right expansion remains in stage");
            var saved:Object=SharedObject.getLocal("RConnectHud","/").data;
            Log.d("HUD PREFERENCES "+JSON.stringify(saved));
            check(saved.dock=="br" && saved.collapsed===false,"UI anchor and expansion persist separately");
            var restored:NetHud=new NetHud(mod.stage,mod);
            check(!restored.collapsed && Math.abs(restored.x-h.x)<1 && Math.abs(restored.y-h.y)<1,"new production HUD restores saved bottom anchor and expansion");
            restored.dispose();
            picture("hud-bottom-expanded");
         } else if(n==10) {
            mod.stage.nativeWindow.width=640;mod.stage.nativeWindow.height=480;
            h.scaleX=h.scaleY=2;h.layout();h.openPage("peer");
         } else if(n==11) {
            check(h.panelHeight*h.scaleY<=mod.stage.stageHeight-16 && h.x+h.panelWidth*2<=mod.stage.stageWidth-7,"actual small AIR window and 200 percent HUD fit");
            h.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-10));
            picture("hud-small-scrolled");
         } else if(n==12) {
            h.scaleX=h.scaleY=1;mod.stage.nativeWindow.bounds=oldBounds;h.setDock("tl");h.layout();
            // Window activation can open the native PipBuck. Restore ordinary
            // play before checking controls; do not change Ctr's key state oracle.
            mod.game.forceCloseOverlays();
            h.collapse();ctr.clearAll();key(65);
            // Ctr processes key-up normally; KEY_DOWN observation is checked independently below.
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,65,65));
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,16,16));
            check(ctr.keyLeft && ctr.keyRun,"native movement and Shift are held before entering chat");
            h.openPage("chat",true);ctr.clearAll();
            var down:KeyboardEvent=new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,65,65);
            h.tfChat.dispatchEvent(down);check(!ctr.keyLeft,"new input capture prevents native key state");
            h.tfChat.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,65,65));key(16);
            check(!ctr.keyRun,"releasing Shift in chat clears the previous native run state");
            h.collapse();mod.stage.dispatchEvent(down.clone());
            check(ctr.keyLeft,"collapsed HUD restores native keyboard processing");
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,65,65));
            Log.d("HUD NATIVE MOUSE BEFORE active="+ctr.active+" clickReq="+w.clickReq+" setkey="+ctr.setkeyOn);
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
            check(ctr.active && w.clickReq!=1 && !ctr.setkeyOn,"native mouse is activated before HUD and outside comparisons");
            h.openPage("peer");ctr.clearAll();
            h.getChildByName("rconnect-follow").dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            check(!ctr.keyAttack,"HUD mouse down does not fire native weapon");
            h.getChildByName("rconnect-follow").dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
            check(SharedObject.getLocal("RConnectHud","/").data.dock=="tl","ordinary button mouse does not start title dragging");
            h.collapse();
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            check(ctr.keyAttack,"outside HUD mouse still reaches native weapon");
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
            var handle:DisplayObject=h.getChildByName("rconnect-drag-handle");
            handle.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true,false,20,10));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_MOVE,true,false,500,400));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true,false,500,400));
            saved=SharedObject.getLocal("RConnectHud","/").data;
            check(saved.dock=="free" && Math.abs(h.x-480)<1 && Math.abs(h.y-390)<1,"title drag follows event coordinates and persists free position");
            for each(var corner:String in ["tl","tr","br","bl"]) {
               h.setDock(corner);h.collapse(false);
               check(h.x>=7 && h.y>=7 && h.x+h.panelWidth*h.scaleX<=mod.stage.stageWidth-7
                  && h.y+h.panelHeight*h.scaleY<=mod.stage.stageHeight-7,"expanded panel fits corner "+corner);
               h.collapse();
               check(h.panelHeight==36 && h.x+h.panelWidth<=mod.stage.stageWidth-7 && h.y+36<=mod.stage.stageHeight-7,"collapsed panel fits corner "+corner);
            }
            h.setDock("tl");
         } else if(n==13) {
            check(chatReceived,"actual TCP peer chat reached session");
            h.openPage("settings");
            send("pause-ready");change("pause-ready");return;
         }
         n++;at=getTimer();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || phase=="done")return;
         try {
            if(host){if(mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
            if(getTimer()-at>45000)throw new Error("UI stage timed out: "+phase);
            if(phase=="boot") {
               if(mod.game.gg==null || mod.game.loc==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
               if(host?mod.session.peers.length==0:mod.session.remotes.length==0)return;
               var dest:String=String(mod.config.getValue("autoTravelLand"));
               if(dest!="" && (landId()!=dest || String(GameBridge.probe(GameBridge.probe(mod.game.world.land,"act"),"id"))!=dest))return;
               if(mod.game.world.onPause || mod.game.gg.disabled || mod.game.gg.work=="res" || Number(mod.game.gg.t_work)>0)return;
               oldLang=String(mod.game.world.lang);oldBounds=mod.stage.nativeWindow.bounds.clone();
               menus=mod.session.pause.policyMenus;sats=mod.session.pause.policySats;
               mod.stage.addEventListener(Event.RENDER,render,false,-30000);
               change("ready");
            }
            if(phase=="ready") {
               send("ready");
               if(!remoteReady || remoteRoom!=mod.game.roomKey() || remoteLand!=landId() || remoteEpoch!=mod.game.roomEpoch
                  || mod.session.rooms.busy || !mod.session.rooms.ready || mod.game.isTransitioning()) {readySince=0;return;}
               if(readySince==0)readySince=getTimer();if(getTimer()-readySince<1000)return;
               Log.d("HUD READY "+mod.game.roomKey()+" epoch="+mod.game.roomEpoch);change("steps");
            }
            if(phase=="steps" && shotDone && getTimer()-at>500)step();
            if(phase=="pause-ready") {
               send("pause-ready");
               if(remotePauseReady && !mod.session.rooms.busy && !mod.game.isTransitioning()) {
                  if(host) {mod.session.pause.setPolicy(true,sats);mod.game.world.pip.onoff(5);}
                  change("pause");
               }
            }
            if(phase=="pause" && mod.session.pause.paused) {
               if(mod.hud.visible)key(121);
               var b:TextField=mod.stage.getChildByName("rconnect-pause-banner") as TextField;
               check(!mod.hud.visible && b!=null && b.visible && b.text.length>0,"real co-op pause notice survives F10 hiding");
               picture("hud-pause-hidden");send("pause-ack");change(host?"pause-ack":"wait-resume");
            }
            if(phase=="pause-ack" && pauseAck && shotDone) {
               mod.game.world.pip.onoff(0);mod.session.pause.setPolicy(menus,sats);change("wait-resume");
            }
            if(phase=="wait-resume" && !mod.session.pause.paused && shotDone) {
               mod.hud.visible=true;mod.hud.openPage("connect");send("done");change("done-ack");
            }
            if(phase=="done-ack") {
               send("done");
               if(host && remoteDone) {send("offline-go");change("wait-peer-left");}
               else if(!host && remoteDone && offlineGo)afterLeave();
            }
            if(phase=="wait-peer-left") {
               if(mod.session.peers.length==0)afterLeave();else send("offline-go");
            }
            if(phase=="finish-shot" && shotDone)finish();
         } catch(err:Error) {check(false,err.getStackTrace());finish();}
      }
      private function afterLeave():void {
         check(remoteDone,"both sides completed online UI before explicit leave");
         mod.session.leave();mod.hud.openPage("connect");
         var nick:String=mod.hud.tfNick.text;mod.hud.tfPort.text="99999";click("rconnect-join");
         check(mod.session.mode==Session.OFFLINE && mod.hud.statusTf.text.length>0 && mod.hud.tfNick.text==nick,"invalid port fails locally and preserves input");
         mod.hud.tfPort.text=String(mod.config.getValue("port"));
         mod.hud.tfPort.dispatchEvent(new Event(Event.CHANGE));
         mod.session.error=new Array(12).join("LONG ERROR 可读取的完整错误信息 ");mod.hud.refresh();
         mod.hud.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-20));
         check(mod.hud.panelHeight<=240,"long real status does not grow outer shell");
         picture("hud-long-error");change("finish-shot");
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {mod.stage.removeEventListener(Event.RENDER,render);mod.game.world.lang=oldLang;
            mod.hud.scaleX=mod.hud.scaleY=1;if(oldBounds!=null)mod.stage.nativeWindow.bounds=oldBounds;}
         Log.d("COOP EFFECTS DONE hud "+(host?"host":"join"));
      }
   }
}
