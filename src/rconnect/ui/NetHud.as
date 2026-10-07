package rconnect.ui {
   import modlocales.connect.RCLocale;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.FocusEvent;
   import flash.events.IMEEvent;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.TextEvent;
   import flash.geom.Rectangle;
   import flash.net.SharedObject;
   import flash.system.System;
   import flash.text.TextField;
   import flash.text.TextFieldType;
   import flash.text.TextFormat;
   import flash.utils.getTimer;
   import rconnect.core.Session;
   import rconnect.game.GameBridge;

   /** Compact, local UI. Session/RoomSync remain the owners of gameplay. */
   public class NetHud extends Sprite {
      public var mod:RConnectMod;
      public var statusTf:TextField,tfNick:TextField,tfIp:TextField,tfPort:TextField;
      public var chatLog:TextField,tfChat:TextField;
      private var surface:Stage,header:Sprite=new Sprite(),scrollbar:Sprite=new Sprite(),entries:Array=[],tabs:Array=[];
      private var title:TextField,stateLine:TextField,chatButton:TextField,expandButton:TextField;
      private var footer:TextField,dockButton:TextField,helpButton:TextField,helpText:TextField;
      private var nickLabel:TextField,ipLabel:TextField,portLabel:TextField,liveLabel:TextField;
      private var peerLabel:TextField,healthLabel:TextField,peerHint:TextField,chatHint:TextField;
      private var policyLabel:TextField,policyHint:TextField,versionLabel:TextField;
      private var opacityLabel:TextField,opacityValue:TextField,opacityLess:TextField,opacityMore:TextField;
      private var opacityPercent:int=100;
      private var _btnHost:TextField,_btnJoin:TextField,_btnLeave:TextField,_btnSend:TextField;
      private var _btnExploration:TextField,_btnFollow:TextField,_btnTeleport:TextField;
      private var _btnPauseMenus:TextField,_btnPauseSats:TextField,_pauseBanner:TextField;
      private var page:String="connect",folded:Boolean=true,help:Boolean=false,unread:int=0;
      private var lines:Array=[],scroll:Number=0,dock:String="tl",preferredX:Number=8,preferredY:Number=8;
      private var box:Object={w:280,h:36,body:156},prefs:SharedObject,lastMode:String="",localError:String="";
      private var drag:Object,blockedKeys:Object={},imeActive:Boolean=false,imeCommitAt:int=-1000;
      private var disposed:Boolean=false;

      public function NetHud(stage:Stage,m:RConnectMod) {
         mod=m;surface=stage;name="rconnect-hud";
         readPreferences();build();
         tfNick.text=String(mod.config.getValue("nickname"));
         tfIp.text=String(mod.config.getValue("hostIp"));tfPort.text=String(mod.config.getValue("port"));
         if(surface!=null) {
            surface.addChild(this);
            _pauseBanner=new TextField();_pauseBanner.name="rconnect-pause-banner";
            _pauseBanner.defaultTextFormat=new TextFormat("_sans",13,0xFFE890,true,null,null,null,null,"center");
            _pauseBanner.multiline=_pauseBanner.wordWrap=true;_pauseBanner.selectable=false;
            _pauseBanner.mouseEnabled=false;_pauseBanner.background=true;_pauseBanner.backgroundColor=0x202020;
            _pauseBanner.visible=false;surface.addChild(_pauseBanner);
            surface.addEventListener(KeyboardEvent.KEY_DOWN,keyDown,true,1000,true);
            surface.addEventListener(KeyboardEvent.KEY_UP,keyUp,true,1000,true);
            // A keyboard event whose target is Stage has no ancestor capture
            // phase. High-priority target/bubble listeners cover that case.
            surface.addEventListener(KeyboardEvent.KEY_DOWN,keyDown,false,1000,true);
            surface.addEventListener(KeyboardEvent.KEY_UP,keyUp,false,1000,true);
            surface.addEventListener(Event.RESIZE,resized,false,0,true);
            surface.addEventListener(MouseEvent.MOUSE_MOVE,dragMove,true,1000,true);
            surface.addEventListener(MouseEvent.MOUSE_UP,dragEnd,true,1000,true);
            surface.addEventListener(MouseEvent.MOUSE_MOVE,dragMove,false,1000,true);
            surface.addEventListener(MouseEvent.MOUSE_UP,dragEnd,false,1000,true);
            surface.addEventListener(Event.DEACTIVATE,cancelDrag,false,0,true);
            surface.addEventListener(MouseEvent.CLICK,outsideClick,true,1000,true);
         }
         try {
            System.ime.addEventListener(IMEEvent.IME_START_COMPOSITION,imeStart,false,0,true);
            System.ime.addEventListener(IMEEvent.IME_COMPOSITION,imeCommit,false,0,true);
         } catch(e:*) {}
         addEventListener(FocusEvent.FOCUS_IN,focusIn);
         for each(var type:String in [MouseEvent.MOUSE_DOWN,MouseEvent.MOUSE_UP,MouseEvent.CLICK,
            MouseEvent.RIGHT_MOUSE_DOWN,MouseEvent.RIGHT_MOUSE_UP,MouseEvent.RIGHT_CLICK,
            MouseEvent.MIDDLE_MOUSE_DOWN,MouseEvent.MIDDLE_MOUSE_UP])addEventListener(type,blockMouse);
         addEventListener(MouseEvent.MOUSE_WHEEL,wheel);
         refresh();
      }

      private function tr(zh:String,en:String,ru:String):String {
         var lang:String=RCLocale.language();return lang=="zh"?zh:lang=="ru"?ru:en;
      }
      private function field(id:String,p:String,xx:Number,yy:Number,ww:Number,hh:Number,
         button:Boolean=false,input:Boolean=false):TextField {
         var t:TextField=new TextField();t.name=id;t.x=xx;t.y=yy;t.width=ww;t.height=hh;
         t.defaultTextFormat=new TextFormat("_sans",12,button?0xF1D16D:0xE7E8DD,button);
         t.multiline=t.wordWrap=!input;t.selectable=input;t.mouseEnabled=button||input;
         t.tabEnabled=button||input;t.type=input?TextFieldType.INPUT:TextFieldType.DYNAMIC;
         if(button||input) {t.background=true;t.backgroundColor=input?0x20251D:0x2D3329;
            t.border=true;t.borderColor=0x46503D;}
         if(input) {
            t.addEventListener(TextEvent.TEXT_INPUT,textInput);
            t.addEventListener(FocusEvent.FOCUS_OUT,focusOut);
            t.addEventListener(Event.CHANGE,inputChanged);
         }
         addChild(t);
         if(p!="")entries.push({tf:t,page:p,x:xx,y:yy,w:ww,h:hh});
         return t;
      }
      private function action(t:TextField,f:Function):void {
         t.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void {
            if(t.mouseEnabled && visible) {
               if(surface!=null && t.visible)surface.focus=t;
               f();refresh();
            }
         });
      }
      private function build():void {
         header.name="rconnect-drag-handle";header.buttonMode=true;addChild(header);
         title=field("rconnect-title","",17,8,65,22);title.text="RConnect";
         stateLine=field("rconnect-state","",83,8,100,22);
         chatButton=field("rconnect-chat","",176,6,52,24,true);
         expandButton=field("rconnect-expand","",240,6,32,24,true);
         action(chatButton,function():void {openPage("chat",true);});
         action(expandButton,function():void {collapse(!folded);});
         for(var i:int=0;i<4;i++) {
            var id:String=["connect","peer","chat","settings"][i];
            var t:TextField=field("rconnect-tab-"+id,"",i*70,36,70,28,true);
            tabs.push(t);bindTab(t,id);
         }
         footer=field("rconnect-shortcuts","",8,0,128,20);
         footer.defaultTextFormat=new TextFormat("_sans",10,0xB6BF9D);
         dockButton=field("rconnect-dock","",140,0,68,20,true);
         helpButton=field("rconnect-help","",212,0,60,20,true);
         action(dockButton,function():void {
            var corners:Array=["tl","tr","br","bl"];setDock(corners[(corners.indexOf(dock)+1)%4]);
         });
         action(helpButton,function():void {help=!help;scroll=0;layout();});
         scrollbar.name="rconnect-scrollbar";scrollbar.mouseEnabled=false;addChild(scrollbar);
         helpText=field("rconnect-help-text","help",8,8,264,230);

         nickLabel=field("rconnect-nick-label","connect",8,8,40,26);
         tfNick=field("rconnect-nickname","connect",52,8,220,26,false,true);tfNick.maxChars=24;
         ipLabel=field("rconnect-address-label","connect",8,37,180,18);
         portLabel=field("rconnect-port-label","connect",198,37,74,18);
         tfIp=field("rconnect-address","connect",8,55,182,26,false,true);
         tfPort=field("rconnect-port","connect",198,55,74,26,false,true);tfPort.restrict="0-9";tfPort.maxChars=5;
         liveLabel=field("rconnect-live","live",8,8,264,64);
         statusTf=field("rconnect-status","connect",8,85,264,34);
         _btnHost=field("rconnect-host","connect",8,122,128,28,true);
         _btnJoin=field("rconnect-join","connect",144,122,128,28,true);
         _btnLeave=field("rconnect-leave","connect",8,122,264,28,true);
         action(_btnHost,function():void {connect(true);});
         action(_btnJoin,function():void {connect(false);});
         action(_btnLeave,function():void {mod.session.leave();localError="";openPage("connect");});

         peerLabel=field("rconnect-peer","peer",8,8,194,32);
         healthLabel=field("rconnect-peer-health","peer",208,8,64,32);
         _btnExploration=field("rconnect-exploration","peer",8,45,128,32,true);
         _btnFollow=field("rconnect-follow","peer",144,45,128,32,true);
         _btnTeleport=field("rconnect-teleport","peer",8,83,264,28,true);
         peerHint=field("rconnect-peer-hint","peer",8,115,264,72);
         action(_btnExploration,function():void {
            mod.exploration.setEnabled(!mod.exploration.enabled);
         });
         action(_btnFollow,function():void {
            mod.config.setValue("followTeammate",mod.config.getValue("followTeammate")=="1"?"0":"1");
            mod.config.save();
         });
         action(_btnTeleport,function():void {if(mod.navigation!=null)mod.navigation.request();});

         chatLog=field("rconnect-chat-log","chat",8,8,264,84);
         chatLog.background=true;chatLog.backgroundColor=0x10160B;
         chatLog.mouseEnabled=true;
         tfChat=field("rconnect-chat-input","chat",8,99,208,26,false,true);tfChat.maxChars=512;
         _btnSend=field("rconnect-send","chat",222,99,50,26,true);
         chatHint=field("rconnect-chat-hint","chat",8,129,264,20);
         action(_btnSend,function():void {sendChat();});

         opacityLabel=field("rconnect-opacity-label","settings",8,8,144,28);
         opacityLess=field("rconnect-opacity-less","settings",154,8,28,28,true);opacityLess.text="−";
         opacityValue=field("rconnect-opacity-value","settings",185,10,54,26);opacityValue.text="100%";
         opacityMore=field("rconnect-opacity-more","settings",244,8,28,28,true);opacityMore.text="+";
         action(opacityLess,function():void {setOpacity(opacityPercent-10);});
         action(opacityMore,function():void {setOpacity(opacityPercent+10);});
         policyLabel=field("rconnect-policy-owner","settings",8,48,264,24);
         _btnPauseMenus=field("rconnect-pause-menus","settings",8,76,264,30,true);
         _btnPauseSats=field("rconnect-pause-sats","settings",8,112,264,30,true);
         policyHint=field("rconnect-policy-hint","settings",8,150,264,40);
         versionLabel=field("rconnect-version","settings",8,194,264,38);
         action(_btnPauseMenus,function():void {
            if(mod.session.pause!=null)mod.session.pause.setPolicy(!mod.session.pause.policyMenus,mod.session.pause.policySats);
         });
         action(_btnPauseSats,function():void {
            if(mod.session.pause!=null)mod.session.pause.setPolicy(mod.session.pause.policyMenus,!mod.session.pause.policySats);
         });
      }
      private function bindTab(t:TextField,id:String):void {action(t,function():void {openPage(id);});}
      public function get collapsed():Boolean {return folded;}
      public function get currentPage():String {return page;}
      public function get unreadCount():int {return unread;}
      public function get panelWidth():Number {return box.w;}
      public function get panelHeight():Number {return box.h;}
      public function get windowOpacity():int {return opacityPercent;}
      public function setOpacity(percent:Number):void {
         if(!isFinite(percent))return;
         opacityPercent=Math.max(30,Math.min(100,Math.round(percent)));
         alpha=opacityPercent/100;refresh();savePreferences();
      }
      public function openPage(id:String,focusChat:Boolean=false):void {
         if(["connect","peer","chat","settings"].indexOf(id)<0)return;
         releaseFocus();page=id;folded=false;help=false;visible=true;scroll=0;
         if(id=="chat")unread=0;
         refresh();savePreferences();
         if(focusChat && tfChat.mouseEnabled && surface!=null) {surface.focus=tfChat;clearControls();}
      }
      public function collapse(value:Boolean=true):void {
         releaseFocus();folded=value;help=false;scroll=0;refresh();savePreferences();
      }
      public function setDock(value:String):void {
         if(["tl","tr","bl","br","free"].indexOf(value)<0)return;
         dock=value;layout();savePreferences();
      }
      private function readPreferences():void {
         try {
            // Shared by the production module and its isolated external UI driver.
            // AIR application IDs still isolate each player's preferences.
            prefs=SharedObject.getLocal("RConnectHud","/");
            var d:Object=prefs.data;
            if(["tl","tr","bl","br","free"].indexOf(d.dock)>=0)dock=String(d.dock);
            if(d.x!=null && isFinite(Number(d.x)))preferredX=Number(d.x);
            if(d.y!=null && isFinite(Number(d.y)))preferredY=Number(d.y);
            if(d.collapsed is Boolean)folded=d.collapsed;
            if(d.opacity!=null && isFinite(Number(d.opacity)))
               opacityPercent=Math.max(30,Math.min(100,Math.round(Number(d.opacity))));
            alpha=opacityPercent/100;
         } catch(e:*) {}
      }
      private function savePreferences():void {
         if(prefs==null)return;
         try {prefs.data.dock=dock;prefs.data.x=preferredX;prefs.data.y=preferredY;
            prefs.data.collapsed=folded;prefs.data.opacity=opacityPercent;prefs.flush();} catch(e:*) {}
      }
      private function enabled(t:TextField,on:Boolean):void {
         t.mouseEnabled=on;t.tabEnabled=on;t.alpha=on?1:.55;
      }
      private function peers():Array {
         var s:Session=mod.session;
         return s==null?[]:s.mode==Session.HOSTING?s.peers:s.mode==Session.CONNECTED?s.remotes:[];
      }
      public function refresh():void {
         if(disposed)return;
         var s:Session=mod.session,mode:String=s==null?Session.OFFLINE:s.mode;
         var connected:Boolean=mode==Session.CONNECTED || mode==Session.HOSTING && peers().length>0;
         var active:Boolean=mode==Session.HOSTING || mode==Session.CONNECTED;
         if(mode==Session.CONNECTED && lastMode==Session.JOINING) {
            releaseFocus();folded=true;help=false;scroll=0;
            savePreferences();
         }
         lastMode=mode;
         var pause:Object=s==null?null:s.pause;
         var error:String=localError!=""?localError:s==null?"":s.error;
         var status:String=error!="" && mode==Session.OFFLINE?tr("连接失败","Failed","Ошибка"):
            mode==Session.JOINING?tr("连接中","Connecting","Вход"):
            mode==Session.HOSTING?peers().length==0?tr("等待队友","Waiting","Ожидание"):tr("宿主","Host","Ведущий")+" 2/2":
            mode==Session.CONNECTED?tr("已加入","Joined","В игре")+" 2/2":tr("离线","Offline","Офлайн");
         stateLine.text=pause!=null && pause.paused?tr("已暂停","Paused","Пауза"):status;
         chatButton.text=tr("聊","Chat","Чат")+(unread>0?" "+Math.min(9,unread):"");
         if(visible && !folded && page=="chat" && !help)unread=0;
         chatButton.text=tr("聊","Chat","Чат")+(unread>0?" "+Math.min(9,unread):"");
         expandButton.text=folded?"▼":"▲";
         for(var i:int=0;i<tabs.length;i++) {
            var t:TextField=tabs[i];t.text=i==0?tr("连接","Connect","Связь"):
               i==1?tr("队友","Teammate","Напарник"):i==2?tr("聊天","Chat","Чат"):tr("设置","Settings","Настройки");
            t.backgroundColor=page==["connect","peer","chat","settings"][i]?0x3A3B25:0x20261C;
         }
         nickLabel.text=tr("昵称","Name","Имя");ipLabel.text=tr("宿主地址","Host address","Адрес ведущего");
         portLabel.text=tr("端口","Port","Порт");
         _btnHost.text=tr("创建房间","Host","Создать");_btnJoin.text=tr("加入","Join","Войти");
         _btnLeave.text=mode==Session.JOINING?tr("取消连接","Cancel","Отмена"):
            mode==Session.HOSTING && peers().length==0?tr("停止主持","Stop hosting","Закрыть комнату"):tr("离开联机","Leave","Выйти");
         liveLabel.text=(mode==Session.HOSTING?tr("房间已创建","Room created","Комната создана"):
            tr("已加入房间","Joined room","Вход в комнату"))+"\n"+
            (mode==Session.HOSTING?tr("监听端口","Listening on","Порт")+": "+mod.config.getValue("port"):
            String(s==null?"":s.hostName)+" · "+mod.config.getValue("hostIp")+":"+mod.config.getValue("port"));
         statusTf.text=error!=""?RCLocale.render(error):
            s!=null && s.rooms.status!=""?RCLocale.text(s.rooms.status):
            mode==Session.JOINING?tr("正在连接，可取消后修改地址。","Connecting; cancel to edit the address.","Соединение. Отмените, чтобы изменить адрес."):
            active?status:tr("填写地址加入，或创建房间。","Enter a host address or create a room.","Введите адрес или создайте комнату.");
         statusTf.textColor=error!=""?0xFFB6A3:0xBFC7AF;
         for each(t in [tfNick,tfIp,tfPort])enabled(t,!active && mode!=Session.JOINING);
         enabled(_btnHost,mode==Session.OFFLINE);enabled(_btnJoin,mode==Session.OFFLINE);
         enabled(_btnLeave,active || mode==Session.JOINING);
         var peer:Object=peers().length>0?peers()[0]:null;
         peerLabel.text=peer==null?tr("队友尚未加入","No teammate yet","Напарник ещё не вошёл"):String(peer.name);
         healthLabel.text=peer!=null && peer.snap!=null && isFinite(Number(peer.snap.hp))?
            "HP "+Math.ceil(Number(peer.snap.hp)):"HP —";
         _btnExploration.text=tr("共享探索","Exploration","Разведка")+": "+
            RCLocale.text(mod.exploration.enabled?"开":"关");
         _btnFollow.text=tr("跟随队友","Follow","Следовать")+": "+
            RCLocale.text(mod.config.getValue("followTeammate")=="1"?"开":"关");
         RCLocale.bind(_btnTeleport,mod.navigation!=null && mod.navigation.travelling?"正在传送…":"传送到队友身边",false);
         var teleportReason:String=mod.navigation==null?"请等待房间准备完成":mod.navigation.unavailable();
         enabled(_btnTeleport,teleportReason=="");
         peerHint.text=RCLocale.text("关闭后保留已收到的区域");
         if(!connected)peerHint.text=tr("先在“连接”中开始联机。","Start a session in Connect.","Начните игру на вкладке «Связь».");
         else if(teleportReason!="")peerHint.appendText("\n"+RCLocale.text(teleportReason));
         else if(s.rooms.status!="")peerHint.appendText("\n"+RCLocale.text(s.rooms.status));
         if(lines.length==0)chatLog.text=tr("暂无消息。\n聊天记录只在这一页展开。","No messages.\nChat stays in this tab.","Нет сообщений.\nЧат находится на этой вкладке.");
         _btnSend.text=tr("发送","Send","Отпр.");enabled(_btnSend,connected);enabled(tfChat,connected);
         chatHint.text=connected?tr("Enter 发送 · Esc 收起","Enter: send · Esc: close","Enter: отправить · Esc: свернуть"):
            tr("连接后可聊天，已有记录保留。","Connect to chat; history is retained.","Войдите для чата. История сохранена.");
         opacityLabel.text=tr("窗口不透明度","Window opacity","Непрозрачность");
         opacityValue.text=opacityPercent+"%";
         enabled(opacityLess,opacityPercent>30);enabled(opacityMore,opacityPercent<100);
         policyLabel.text=pause==null || pause.canChangePolicy?
            mode==Session.OFFLINE?tr("离线预设","Offline presets","Настройки офлайн"):tr("由你设置","Host settings","Настройки ведущего"):
            tr("宿主设置 · 只读","Host settings · read only","Настройки ведущего · только чтение");
         RCLocale.bind(_btnPauseMenus,"菜单同步暂停："+(pause!=null && pause.policyMenus?"开":"关"),false);
         RCLocale.bind(_btnPauseSats,"SATS同步暂停："+(pause!=null && pause.policySats?"开":"关"),false);
         enabled(_btnPauseMenus,pause!=null && pause.canChangePolicy);enabled(_btnPauseSats,pause!=null && pause.canChangePolicy);
         policyHint.text=RCLocale.text("由宿主设置；任意一方打开后全队暂停");
         versionLabel.text="RConnect v"+RConnectMod.VERSION+" · "+(mod.versionInfo==null?"":mod.versionInfo.version);
         footer.text=tr("Ctrl+Enter 聊天 · F10","Ctrl+Enter: chat · F10","Ctrl+Enter: чат · F10");
         dockButton.text=tr("停靠","Dock","Край")+" "+(dock=="tl"?"↖":dock=="tr"?"↗":dock=="br"?"↘":dock=="bl"?"↙":"◇");
         helpButton.text=tr("说明","Help","Справка");
         helpText.text=tr("拖动标题可移动浮窗；“停靠”依次切换四角。\n\nCtrl+Enter 打开聊天；Enter 发送；Esc 收起。\nF10 隐藏或恢复，开合状态保留。\n\n共享探索只影响本端接收；关闭后保留已收到区域。\n\n全队暂停由宿主设置；双方都关闭相关界面后继续。\n\n滚轮可滚动当前页。原版菜单优先使用自己的快捷键。",
            "Drag the title to move. Dock cycles through four corners.\n\nCtrl+Enter opens chat; Enter sends; Esc collapses.\nF10 hides or restores the panel.\n\nExploration controls receiving locally; received areas remain.\n\nThe host sets co-op pause. Both players must close the relevant menus to resume.\n\nScroll the current tab with the wheel. Native menus keep their shortcuts.",
            "Перетащите заголовок. Кнопка «Край» меняет угол.\n\nCtrl+Enter открывает чат; Enter отправляет; Esc сворачивает.\nF10 скрывает и возвращает панель.\n\nРазведка влияет только на приём; полученные области сохраняются.\n\nПаузу настраивает ведущий. Для продолжения оба игрока закрывают соответствующие окна.\n\nПрокручивайте вкладку колёсиком. Игровые меню сохраняют свои клавиши.");
         if(_pauseBanner!=null) {
            _pauseBanner.visible=pause!=null && pause.paused;
            _pauseBanner.width=Math.min(500,Math.max(1,surface.stageWidth-16));
            _pauseBanner.height=40;_pauseBanner.x=(surface.stageWidth-_pauseBanner.width)/2;_pauseBanner.y=8;
            if(_pauseBanner.visible)_pauseBanner.text=pause.description();
         }
         layout();
      }

      private function nativeObstacles():Array {
         var result:Array=[],v:Object=GameBridge.probe(GameBridge.probe(mod.game==null?null:mod.game.world,"gui"),"vis");
         for each(var id:String in ["hpBar","hp","manaBar","xpBar","hpPet","textWeapon","textMana","odBar","visibility"]) {
            var child:DisplayObject=GameBridge.probe(v,id) as DisplayObject;
            if(child==null || child.stage!==surface || !shown(child))continue;
            var r:Rectangle=child.getBounds(surface);
            if(r.width>0 && r.height>0 && r.intersects(new Rectangle(0,0,surface.stageWidth,surface.stageHeight)))result.push(r);
         }
         return result;
      }
      private function shown(v:DisplayObject):Boolean {
         for(var p:DisplayObject=v;p!=null;p=p.parent)if(!p.visible || p.alpha<=.01)return false;
         return true;
      }
      public function layout():void {
         if(surface==null || disposed)return;
         box=HudLayout.measure(surface.stageWidth,surface.stageHeight,Math.abs(scaleX),folded,dock,preferredX,preferredY,nativeObstacles());
         x=box.x;y=box.y;
         graphics.clear();graphics.beginFill(0x141813,.95);graphics.drawRect(0,0,box.w,box.h);graphics.endFill();
         header.graphics.clear();header.graphics.beginFill(0x242B20);header.graphics.drawRect(0,0,box.w,36);header.graphics.endFill();
         chatButton.x=box.w-104;expandButton.x=box.w-40;
         stateLine.width=Math.max(16,box.w-187);
         var active:Boolean=mod.session!=null && (mod.session.mode==Session.HOSTING || mod.session.mode==Session.CONNECTED);
         var joining:Boolean=mod.session!=null && mod.session.mode==Session.JOINING;
         // Read real TextField wrapping before laying out dependent rows.
         // Long errors grow inside the scrolling page, never the outer shell.
         var noteHeight:Number=Math.max(34,statusTf.textHeight+6);
         var ownerExtra:Number=Math.max(0,policyLabel.textHeight+6-24);
         var policyHeight:Number=Math.max(40,policyHint.textHeight+6);
         var pageHeight:Number=156;
         for each(var item:Object in entries) {
            item.renderY=item.y;item.renderH=item.h;
            var f:TextField=item.tf;
            if(f==statusTf)item.renderH=noteHeight;
            if(f==_btnHost || f==_btnJoin || f==_btnLeave)item.renderY=85+noteHeight+4;
            if(f==policyLabel)item.renderH=24+ownerExtra;
            if(item.page=="settings" && item.y>48)item.renderY+=ownerExtra;
            if(f==policyHint)item.renderH=policyHeight;
            if(f==versionLabel)item.renderY=Math.max(194,150+policyHeight+4)+ownerExtra;
            if(f==peerHint || f==helpText)item.renderH=Math.max(item.h,f.textHeight+6);
            if(help?item.page=="help":item.page==page || item.page=="live" && page=="connect" && active)
               pageHeight=Math.max(pageHeight,item.renderY+item.renderH+8);
         }
         scroll=Math.max(0,Math.min(scroll,Math.max(0,pageHeight-box.body)));
         scrollbar.graphics.clear();scrollbar.visible=!folded && pageHeight>box.body;
         if(scrollbar.visible) {
            var thumb:Number=Math.max(12,box.body*box.body/pageHeight);
            scrollbar.graphics.beginFill(0x46503D);scrollbar.graphics.drawRect(box.w-4,64,2,box.body);scrollbar.graphics.endFill();
            scrollbar.graphics.beginFill(0xD9C374);scrollbar.graphics.drawRect(box.w-4,64+(box.body-thumb)*scroll/(pageHeight-box.body),2,thumb);scrollbar.graphics.endFill();
         }
         for each(var entry:Object in entries) {
            var t:TextField=entry.tf,on:Boolean=!folded && (help?entry.page=="help":
               entry.page==page || entry.page=="live" && page=="connect" && active);
            if(entry.page=="connect") {
               if([tfNick,tfIp,tfPort,nickLabel,ipLabel,portLabel].indexOf(t)>=0)on=on&&!active;
               if(t==_btnHost || t==_btnJoin)on=on&&!active&&!joining;
               if(t==_btnLeave)on=on&&(active||joining);
            }
            var natural:Number=64+entry.renderY-scroll,clipTop:Number=Math.max(0,64-natural);
            var clipped:Number=Math.max(0,Math.min(entry.renderH,64+box.body-natural)-clipTop);
            t.x=entry.x;t.y=Math.max(64,natural);
            t.width=entry.w==264?box.w-16:entry.w;
            t.height=entry.renderH;
            t.scrollRect=new Rectangle(0,clipTop,t.width,clipped);
            t.visible=on&&clipped>0;t.tabEnabled=t.visible && t.mouseEnabled && (t.type==TextFieldType.INPUT || t.background && t!=chatLog);
         }
         for(var i:int=0;i<tabs.length;i++) {tabs[i].visible=!folded;tabs[i].tabEnabled=!folded;tabs[i].width=box.w/4;tabs[i].x=i*box.w/4;}
         for each(t in [footer,dockButton,helpButton]) {t.visible=!folded;t.y=box.h-20;t.tabEnabled=!folded && t!=footer;}
         dockButton.x=box.w-140;helpButton.x=box.w-68;
         if(surface.focus!=null && contains(surface.focus) && !shown(surface.focus))releaseFocus();
      }
      private function resized(e:Event):void {layout();}
      private function wheel(e:MouseEvent):void {
         if(folded)return;
         if(e.target==chatLog && !help)chatLog.scrollV-=e.delta;
         else {scroll-=e.delta*14;layout();}
         e.stopImmediatePropagation();
      }
      private function blockMouse(e:MouseEvent):void {
         if(e.type==MouseEvent.MOUSE_DOWN) {
            clearControls();
            if(e.target===header) {
               drag={x:e.stageX-x,y:e.stageY-y};dock="free";
            }
         }
         e.stopImmediatePropagation();
      }
      private function dragMove(e:MouseEvent):void {
         if(drag==null)return;
         preferredX=e.stageX-drag.x;preferredY=e.stageY-drag.y;
         layout();e.stopImmediatePropagation();
      }
      private function dragEnd(e:MouseEvent):void {
         if(drag==null)return;
         drag=null;preferredX=x;preferredY=y;savePreferences();e.stopImmediatePropagation();
      }
      private function cancelDrag(e:Event):void {
         if(drag!=null) {drag=null;preferredX=x;preferredY=y;savePreferences();}
      }
      private function outsideClick(e:MouseEvent):void {
         if(e.target is DisplayObject && !contains(e.target as DisplayObject))releaseFocus();
      }
      private function ownsInput():Boolean {
         return surface!=null && visible && !folded && surface.focus!=null &&
            contains(surface.focus) && surface.focus is TextField && TextField(surface.focus).type==TextFieldType.INPUT;
      }
      private function releaseFocus():void {
         if(surface!=null && surface.focus!=null && contains(surface.focus))surface.focus=null;
         imeActive=false;
      }
      private function clearControls():void {
         var ctr:Object=GameBridge.probe(mod.game==null?null:mod.game.world,"ctr");
         if(ctr!=null && GameBridge.probe(ctr,"clearAll") is Function)ctr.clearAll();
      }
      private function focusIn(e:FocusEvent):void {if(e.target is TextField && TextField(e.target).type==TextFieldType.INPUT)clearControls();}
      private function focusOut(e:FocusEvent):void {imeActive=false;}
      private function imeStart(e:IMEEvent):void {if(ownsInput())imeActive=true;}
      private function imeCommit(e:IMEEvent):void {if(ownsInput()){imeActive=false;imeCommitAt=getTimer();}}
      private function textInput(e:TextEvent):void {if(imeActive){imeActive=false;imeCommitAt=getTimer();}}
      private function inputChanged(e:Event):void {
         if(e.currentTarget!==tfChat && localError!="") {localError="";refresh();}
      }
      private function nativeBusy():Boolean {
         var w:Object=mod.game==null?null:mod.game.world;
         if(w==null)return true;
         if(GameBridge.probe(w,"onConsol")==true || GameBridge.probe(w,"onPause")==true)return true;
         for each(var name:String in ["mm","pip","sats","stand"])if(GameBridge.probe(GameBridge.probe(w,name),"active")==true)return true;
         var gui:Object=GameBridge.probe(w,"gui");
         return GameBridge.probe(gui,"guiPause")==true || GameBridge.probe(GameBridge.probe(gui,"dial"),"visible")==true ||
            GameBridge.probe(GameBridge.probe(gui,"inform"),"visible")==true;
      }
      private function keyDown(e:KeyboardEvent):void {
         var mine:Boolean=ownsInput();
         if(e.keyCode==121) {
            visible=!visible;help=false;releaseFocus();refresh();blockedKeys[e.keyCode]=true;e.stopImmediatePropagation();return;
         }
         if(mine) {
            blockedKeys[e.keyCode]=true;
            if(e.keyCode==13 && surface.focus==tfChat && !imeActive && getTimer()-imeCommitAt>100)sendChat();
            else if(e.keyCode==27) {
               if(imeActive){imeActive=false;imeCommitAt=getTimer();}
               else collapse();
            }
            e.stopImmediatePropagation();return;
         }
         if(visible && !folded && !help && page=="settings" && surface!=null &&
            (surface.focus===opacityLess || surface.focus===opacityMore) &&
            [37,39,36,35,13,32].indexOf(e.keyCode)>=0) {
            clearControls();
            setOpacity(e.keyCode==36?30:e.keyCode==35?100:opacityPercent+
               (e.keyCode==37 || (e.keyCode==13 || e.keyCode==32) && surface.focus===opacityLess?-10:10));
            blockedKeys[e.keyCode]=true;e.stopImmediatePropagation();return;
         }
         // A fresh native key-down supersedes an older swallowed UI key-down.
         // Its later key-up must reach Ctr and clear that new native state.
         delete blockedKeys[e.keyCode];
         if(e.keyCode==13 && e.ctrlKey && !nativeBusy() && !(surface.focus is TextField && TextField(surface.focus).type==TextFieldType.INPUT)) {
            openPage("chat",true);blockedKeys[e.keyCode]=true;e.stopImmediatePropagation();return;
         }
         if(e.keyCode==27 && visible && !folded && !nativeBusy()) {
            collapse();blockedKeys[e.keyCode]=true;e.stopImmediatePropagation();
         }
      }
      private function keyUp(e:KeyboardEvent):void {
         if(blockedKeys[e.keyCode]) {
            // Ctr.clearAll leaves modifiers and its internal key-down vector.
            // Release the native state without forwarding input to game/UI listeners.
            var ctr:Object=GameBridge.probe(mod.game==null?null:mod.game.world,"ctr");
            if(ctr!=null && GameBridge.probe(ctr,"onKeyboardUpEvent") is Function)ctr.onKeyboardUpEvent(e);
            delete blockedKeys[e.keyCode];e.stopImmediatePropagation();
         }
      }
      private function connect(host:Boolean):void {
         var port:String=tfPort.text,number:int=int(port);
         if(tfNick.text.replace(/^\s+|\s+$/g,"")=="" || !host && tfIp.text.replace(/^\s+|\s+$/g,"")=="" ||
            !/^\d+$/.test(port) || number<1 || number>65535) {
            localError=tr("请填写昵称、地址和 1–65535 的端口。","Enter a name, address and port (1–65535).","Введите имя, адрес и порт (1–65535).");
            return;
         }
         localError="";mod.config.setValue("nickname",tfNick.text.substr(0,24));
         if(tfIp.text.length>0)mod.config.setValue("hostIp",tfIp.text);
         mod.config.setValue("port",number);mod.config.save();mod.session.myName=tfNick.text.substr(0,24);
         if(host)mod.session.startHost();else mod.session.startJoin();
         if(host && mod.session.mode==Session.HOSTING)collapse();
      }
      private function sendChat():void {
         if(tfChat.text.replace(/^\s+|\s+$/g,"")=="" || !tfChat.mouseEnabled)return;
         mod.session.sendChat(tfChat.text);tfChat.text="";
         if(surface!=null && tfChat.visible)surface.focus=tfChat;
      }
      public function addChatLine(who:String,text:String):void {
         lines.push(String(who)+": "+String(text));
         if(lines.length>50)lines.shift();
         chatLog.text=lines.join("\n")+"\n";chatLog.scrollV=chatLog.maxScrollV;
         if(!visible || folded || page!="chat" || help)unread++;
         refresh();
      }
      public function dispose():void {
         if(disposed)return;
         releaseFocus();disposed=true;
         if(surface!=null) {
            surface.removeEventListener(KeyboardEvent.KEY_DOWN,keyDown,true);
            surface.removeEventListener(KeyboardEvent.KEY_UP,keyUp,true);
            surface.removeEventListener(KeyboardEvent.KEY_DOWN,keyDown);
            surface.removeEventListener(KeyboardEvent.KEY_UP,keyUp);
            surface.removeEventListener(Event.RESIZE,resized);
            surface.removeEventListener(MouseEvent.MOUSE_MOVE,dragMove,true);
            surface.removeEventListener(MouseEvent.MOUSE_UP,dragEnd,true);
            surface.removeEventListener(MouseEvent.MOUSE_MOVE,dragMove);
            surface.removeEventListener(MouseEvent.MOUSE_UP,dragEnd);
            surface.removeEventListener(Event.DEACTIVATE,cancelDrag);
            surface.removeEventListener(MouseEvent.CLICK,outsideClick,true);
            if(_pauseBanner!=null && _pauseBanner.parent===surface)surface.removeChild(_pauseBanner);
         }
         try {System.ime.removeEventListener(IMEEvent.IME_START_COMPOSITION,imeStart);
            System.ime.removeEventListener(IMEEvent.IME_COMPOSITION,imeCommit);} catch(e:*) {}
         if(parent!=null)parent.removeChild(this);
      }
   }
}
