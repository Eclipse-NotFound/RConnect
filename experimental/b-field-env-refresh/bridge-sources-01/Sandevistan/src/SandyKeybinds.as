package {
   import flash.events.KeyboardEvent;
   import flash.net.SharedObject;
   import flash.text.TextField;
   import flash.text.TextFieldType;
   import modlocales.sandy.SandyLocale;

   /** Client-owned binding and persistence; the settings host owns capture UI. */
   public final class SandyKeybinds {
      public static const PAGE:String = "sandevistan-hotkeys";
      public static const ACTION:String = "activate";
      private var main:Object, changed:Function, store:SharedObject;
      private var value:Object, api:Object, registered:Boolean = false;
      private var held:Object = {}, frames:int = 0;

      public function SandyKeybinds(main:Object, legacyCode:int, changed:Function = null) {
         this.main = main; this.changed = changed;
         value = normalize({code:legacyCode,ctrl:false,alt:false,shift:false});
         if(value == null) value = defaults();
         try {
            store = SharedObject.getLocal("SandevistanKeybinds", "/");
            var saved:Object = normalize(store.data.binding);
            if(saved != null) value = saved;
         } catch(e:*) { store = null; }
      }
      public function get binding():Object { return copy(value); }
      private static function defaults():Object { return {code:220,ctrl:false,alt:false,shift:false}; }
      private static function copy(v:Object):Object { return {code:v.code,ctrl:v.ctrl,alt:v.alt,shift:v.shift}; }
      private static function normalize(v:*):Object {
         if(v == null || typeof v != "object" || !(v.code is Number) || !isFinite(Number(v.code)) ||
            Number(v.code) != int(v.code) || int(v.code) < 0 || int(v.code) > 255 ||
            !(v.ctrl is Boolean) || !(v.alt is Boolean) || !(v.shift is Boolean)) return null;
         if(int(v.code) == 0) return {code:0,ctrl:false,alt:false,shift:false};
         return {code:int(v.code),ctrl:v.ctrl,alt:v.alt,shift:v.shift};
      }
      private function setBinding(v:*):void {
         var next:Object = normalize(v);
         if(next == null) return;
         if(store == null) store = SharedObject.getLocal("SandevistanKeybinds", "/");
         var previous:* = store.data.binding;
         store.data.binding = copy(next);
         try { store.flush(); }
         catch(e:*) { store.data.binding = previous; throw e; }
         value = next;
         // Capture may consume KEY_UP; do not retain an old binding's latch.
         held = {};
         if(changed != null) changed(int(value.code));
      }
      private function refresh():void {
         var found:Object = null;
         try {
            var carrier:Object = main != null ? main.getChildByName("ModSettingsCarrier") : null;
            if(carrier != null) found = carrier["modAPI"];
         } catch(e:*) {}
         if(found !== api) { api = found; registered = false; }
      }
      public function step():void {
         // The host consumes releases while capturing, including on cancel.
         if(isCapturingKey()) releaseAll();
         if(frames++ % 10 != 0) return;
         refresh();
         if(registered || api == null) return;
         try {
            if(!("keybindVersion" in api) || int(api.keybindVersion) < 1 ||
               !(api.registerPage is Function) || !(api.matchesKey is Function) ||
               !(api.isCapturingKey is Function)) return;
            var self:SandyKeybinds = this;
            var item:Object = {key:ACTION,label:"发动或结束时停",kind:"keybind",
               hint:"在游戏中立即生效；按键捕获由公共菜单处理。",
               get:function():Object { return self.binding; }, set:setBinding, def:defaults()};
            var navigation:Object = {moduleId:"sandevistan",moduleName:"斯安维斯坦",
               featureName:"快捷键",featureOrder:99};
            if("localizationVersion" in api) navigation.translate = SandyLocale.render;
            api.registerPage(PAGE,"快捷键",[item],null,"",navigation);
            registered = true;
         } catch(e:*) { registered = false; }
      }
      public function isCapturingKey():Boolean {
         refresh();
         try {
            if(api != null && "isCapturingKey" in api && api.isCapturingKey is Function)
               return Boolean(api.isCapturingKey());
         } catch(e:*) { return true; }
         return false;
      }
      /** One action per physical press, including when using an older host. */
      public function press(event:KeyboardEvent):Boolean {
         if(event == null) return false;
         var code:uint = event.keyCode;
         var repeated:Boolean = held[code] === true;
         held[code] = true;
         if(repeated || isCapturingKey()) return false;
         try {
            var focus:Object = main != null && main.stage != null ? main.stage.focus : event.target;
            if(focus is TextField && TextField(focus).type == TextFieldType.INPUT) return false;
         } catch(e:*) {}
         if(registered && api != null) {
            try { return Boolean(api.matchesKey(PAGE,ACTION,event)); }
            catch(error:*) { registered = false; }
         }
         return value.code != 0 && code == uint(value.code) && event.ctrlKey == value.ctrl &&
            event.altKey == value.alt && event.shiftKey == value.shift;
      }
      public function releaseKey(code:uint):void { delete held[code]; }
      public function releaseAll():void { held = {}; }
   }
}
