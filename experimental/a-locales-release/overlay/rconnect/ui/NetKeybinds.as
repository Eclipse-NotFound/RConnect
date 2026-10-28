package rconnect.ui {
   import flash.events.KeyboardEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getDefinitionByName;
   import modlocales.connect.RCLocale;

   /** Local shortcut preferences; no session, network or actor state is changed. */
   public class NetKeybinds {
      private var bindings:Object={panel:{code:121,ctrl:false,alt:false,shift:false},chat:{code:13,ctrl:true,alt:false,shift:false}};
      private var api:*,registered:*;
      private static const PAGE:String="rconnect-hotkeys";
      public function NetKeybinds(){load();}
      private function canonical(v:*):Object {
         var b:Object=null;
         try{var n:Number=Number(v.code);if(v!=null&&!(v.code is Boolean)&&isFinite(n)&&n==int(n)&&(n==0||n>=8&&n<=222&&[16,17,18,91,92,93].indexOf(int(n))<0))
            b={code:int(n),ctrl:n!=0&&v.ctrl===true,alt:n!=0&&v.alt===true,shift:n!=0&&v.shift===true};}catch(e:*){}
         return b;
      }
      private function file():File{return File.applicationStorageDirectory.resolvePath("RConnect.hotkeys.json");}
      private function load():void {
         var s:FileStream=new FileStream();
         try{var f:File=file();if(!f.exists)return;s.open(f,FileMode.READ);var d:Object=JSON.parse(s.readUTFBytes(s.bytesAvailable));s.close();
            if(d.version!=1||d.bindings==null)return;for(var id:String in bindings){var b:Object=canonical(d.bindings[id]);if(b!=null)bindings[id]=b;}}
         catch(e:*){try{s.close();}catch(ignored:*){}trace("[RConnect] shortcut preferences rejected: "+e);}
      }
      private function setBinding(id:String,v:*):void {
         var b:Object=canonical(v);if(b==null)throw new Error("Invalid shortcut");
         var old:Object=bindings[id],s:FileStream=new FileStream();bindings[id]=b;
         try{var t:File=File.applicationStorageDirectory.resolvePath("RConnect.hotkeys.tmp");s.open(t,FileMode.WRITE);
            s.writeUTFBytes(JSON.stringify({version:1,bindings:bindings}));s.close();t.moveTo(file(),true);}
         catch(e:*){try{s.close();}catch(ignored:*){}bindings[id]=old;throw e;}
      }
      private function item(id:String,label:String,code:int,ctrl:Boolean=false):Object {
         var self:NetKeybinds=this;
         return {key:id,label:label,kind:"keybind",def:{code:code,ctrl:ctrl,alt:false,shift:false},
            get:function():*{return self.bindings[id];},set:function(v:*):void{self.setBinding(id,v);}};
      }
      private function translate(text:String):String {
         return RCLocale.text(text);
      }
      public function tick():void {
         try{var w:*=getDefinitionByName("fe.World")["w"];if(w==null||w.main==null)return;
            var c:*=w.main.getChildByName("ModSettingsCarrier");api=c==null?null:c["modAPI"];
            if(api==null||!("keybindVersion" in api)||api.keybindVersion<1||registered===api)return;
            api.registerPage(PAGE,"RConnect · 快捷键",[item("panel","联机浮窗显隐",121),item("chat","打开聊天",13,true)],null,
               "修改后立即生效并保存在本机。原版Enter和聊天输入框的Enter、Esc保持原用法。F10共用会显示占用提示。",
               {moduleId:"rconnect",moduleName:"RConnect",featureName:"快捷键",featureOrder:99,translate:translate});registered=api;
         }catch(e:*){trace("[RConnect] shortcut menu registration: "+e);}
      }
      public function capturing():Boolean{return api!=null&&"isCapturingKey" in api&&api.isCapturingKey();}
      public function matches(id:String,e:KeyboardEvent):Boolean {
         if(registered===api&&api!=null&&"keybindVersion" in api)return api.matchesKey(PAGE,id,e);
         var b:Object=bindings[id];return b!=null&&b.code!=0&&b.code==e.keyCode&&b.ctrl==e.ctrlKey&&b.alt==e.altKey&&b.shift==e.shiftKey;
      }
      public function label(id:String):String {
         var b:Object=bindings[id];if(api!=null&&"keyLabel" in api)return api.keyLabel(b);
         if(b.code==0)return translate("未绑定");
         var name:String=b.code==13?"Enter":b.code>=112&&b.code<=123?"F"+(b.code-111):b.code>=65&&b.code<=90?String.fromCharCode(b.code):RCLocale.text("按键")+" "+b.code;
         return (b.ctrl?"Ctrl+":"")+(b.alt?"Alt+":"")+(b.shift?"Shift+":"")+name;
      }
   }
}
