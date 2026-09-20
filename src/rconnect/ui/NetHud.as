package rconnect.ui
{
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFieldType;
   import flash.text.TextFormat;

   /**
    * 屏幕覆盖层面板：状态、昵称/IP/端口输入、主持/加入按钮、聊天。
    * 全部为模组自建显示对象，挂在 stage 顶层，不进游戏显示树。
    *
    * 键位（shared-knowledge：模组 KEY_DOWN 先于游戏 Ctr）：
    * - F10 开关面板（bubble 阶段监听并 stopImmediatePropagation 吞掉）；
    * - 本模组输入框获得焦点时，capture 阶段吞掉可打印字符，
    *   避免打字同时驱动游戏角色（游戏 Ctr 监听在 stage 的 bubble 阶段）。
    */
   public class NetHud extends Sprite
   {
      public var mod:RConnectMod;
      public var statusTf:TextField;
      public var tfNick:TextField;
      public var tfIp:TextField;
      public var tfPort:TextField;
      public var chatLog:TextField;
      public var tfChat:TextField;

      private var _btnHost:TextField;
      private var _btnJoin:TextField;
      private var _btnLeave:TextField;
      private var _btnSend:TextField;
      private var _btnExploration:TextField;
      private var _visible:Boolean = true;
      private var _chatLines:int = 0;

      public function NetHud(stage:Stage, mod:RConnectMod)
      {
         this.mod = mod;
         buildPanel();

         if(stage != null)
         {
            stage.addChild(this);
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyCapture, true, 0, true);
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyBubble, false, 0, true);
         }
         syncInputsFromConfig();
      }

      // ---- 构建 ---------------------------------------------------------

      private function buildPanel():void
      {
         var fmt:TextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
         var fmtBold:TextFormat = new TextFormat("_sans", 12, 0xFFD040, true);

         graphics.beginFill(0x000000, 0.62);
         graphics.drawRect(0, 0, 280, 274);
         graphics.endFill();

         statusTf = makeLabel(8, 8, 264, 44, fmt);
         tfNick = makeInput(8, 56, 90, fmt);
         tfIp = makeInput(100, 56, 110, fmt);
         tfPort = makeInput(212, 56, 56, fmt);
         tfPort.restrict = "0-9";

         _btnHost = makeButton(8, 84, 62, fmtBold, "Host");
         _btnJoin = makeButton(76, 84, 62, fmtBold, "Join");
         _btnLeave = makeButton(144, 84, 62, fmtBold, "Leave");

         chatLog = makeLabel(8, 112, 264, 70, fmt);
         tfChat = makeInput(8, 188, 208, fmt);
         _btnSend = makeButton(220, 188, 52, fmtBold, "Send");

         _btnHost.addEventListener(MouseEvent.CLICK, onClickHost);
         _btnJoin.addEventListener(MouseEvent.CLICK, onClickJoin);
         _btnLeave.addEventListener(MouseEvent.CLICK, onClickLeave);
         _btnSend.addEventListener(MouseEvent.CLICK, onClickSend);

         var hint:TextField = makeLabel(8, 214, 264, 14, fmt);
         hint.text = "F10 hide/show | chat: Enter";
         hint.alpha = 0.6;
         _btnExploration = makeButton(8, 234, 264, fmtBold, "接收队友探索：开");
         _btnExploration.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
            mod.exploration.setEnabled(!mod.exploration.enabled);
            refresh();
         });
         var explorationHint:TextField = makeLabel(8, 254, 264, 16, fmt);
         explorationHint.text = "关闭后保留已收到的区域";
      }

      private function makeLabel(x:Number, y:Number, w:Number, h:Number,
                                 fmt:TextFormat):TextField
      {
         var tf:TextField = new TextField();
         tf.x = x;
         tf.y = y;
         tf.width = w;
         tf.height = h;
         tf.defaultTextFormat = fmt;
         tf.multiline = true;
         tf.wordWrap = true;
         tf.selectable = false;
         tf.mouseEnabled = false;
         addChild(tf);
         return tf;
      }

      private function makeInput(x:Number, y:Number, w:Number,
                                 fmt:TextFormat):TextField
      {
         var tf:TextField = new TextField();
         tf.x = x;
         tf.y = y;
         tf.width = w;
         tf.height = 18;
         tf.defaultTextFormat = fmt;
         tf.type = TextFieldType.INPUT;
         tf.border = true;
         tf.background = true;
         tf.backgroundColor = 0x202020;
         addChild(tf);
         return tf;
      }

      private function makeButton(x:Number, y:Number, w:Number,
                                  fmt:TextFormat, label:String):TextField
      {
         var tf:TextField = new TextField();
         tf.x = x;
         tf.y = y;
         tf.width = w;
         tf.height = 18;
         tf.defaultTextFormat = fmt;
         tf.text = label;
         tf.selectable = false;
         tf.mouseEnabled = true;
         tf.background = true;
         tf.backgroundColor = 0x303030;
         addChild(tf);
         return tf;
      }

      // ---- 事件 ---------------------------------------------------------

      private function onClickHost(e:MouseEvent):void
      {
         pushConfigFromInputs();
         mod.session.startHost();
      }

      private function onClickJoin(e:MouseEvent):void
      {
         pushConfigFromInputs();
         mod.session.startJoin();
      }

      private function onClickLeave(e:MouseEvent):void
      {
         mod.session.leave();
      }

      private function onClickSend(e:MouseEvent):void
      {
         sendChat();
      }

      private function onKeyBubble(e:KeyboardEvent):void
      {
         if(e.keyCode == 121)   // F10
         {
            _visible = !_visible;
            visible = _visible;
            e.stopImmediatePropagation();
         }
         else if(e.keyCode == 13 && stage != null && stage.focus == tfChat)
         {
            sendChat();
            e.stopImmediatePropagation();
         }
      }

      private function onKeyCapture(e:KeyboardEvent):void
      {
         // 本模组输入框聚焦时，吞掉打字字符，防止游戏角色跟着动
         if(stage == null)
         {
            return;
         }
         var focus:Object = stage.focus;
         if(focus == tfNick || focus == tfIp || focus == tfPort || focus == tfChat)
         {
            if(e.charCode >= 32 && e.charCode <= 126 || e.keyCode == 8)
            {
               e.stopImmediatePropagation();
            }
         }
      }

      private function sendChat():void
      {
         if(tfChat.text.length == 0)
         {
            return;
         }
         mod.session.sendChat(tfChat.text);
         tfChat.text = "";
         // 发送后保持焦点，方便连续聊天
         if(stage != null)
         {
            stage.focus = tfChat;
         }
      }

      // ---- 对外 ---------------------------------------------------------

      public function refresh():void
      {
         _btnExploration.text = "接收队友探索：" + (mod.exploration.enabled ? "开" : "关");
         statusTf.text = mod.session != null
            ? mod.session.statusText() : "RConnect";
      }

      public function addChatLine(name:String, text:String):void
      {
         _chatLines++;
         chatLog.appendText(name + ": " + text + "\n");
         if(_chatLines > 50)
         {
            chatLog.text = chatLog.text.substr(
               chatLog.text.indexOf("\n") + 1);
            _chatLines = 50;
         }
         chatLog.scrollV = chatLog.maxScrollV;
      }

      private function syncInputsFromConfig():void
      {
         tfNick.text = String(mod.config.getValue("nickname"));
         tfIp.text = String(mod.config.getValue("hostIp"));
         tfPort.text = String(mod.config.getValue("port"));
      }

      private function pushConfigFromInputs():void
      {
         if(tfNick.text.length > 0)
         {
            mod.config.setValue("nickname", tfNick.text);
         }
         if(tfIp.text.length > 0)
         {
            mod.config.setValue("hostIp", tfIp.text);
         }
         var p:int = int(tfPort.text);
         if(p > 0 && p <= 65535)
         {
            mod.config.setValue("port", p);
         }
         mod.config.save();
         mod.session.myName = String(mod.config.getValue("nickname"));
      }
   }
}
