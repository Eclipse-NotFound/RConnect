package lad {
    import flash.events.KeyboardEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;

    /** Client-owned bindings; optional shared UI and physical-state service. */
    public final class LadKeys {
        public static const PAGE:String="light-and-darkness-hotkeys";
        private var values:Object={headlamp:{code:76,ctrl:false,alt:true,shift:false},fixture:{code:69,ctrl:false,alt:true,shift:false}};
        private var file:File;
        private var api:*;
        private var registered:*=null;
        private var down:Object={};
        private var ctrl:Boolean=false,alt:Boolean=false,shift:Boolean=false;
        private var writable:Boolean=true;
        public function LadKeys(storage:File=null) {
            file=storage || File.applicationStorageDirectory.resolvePath("LightAndDarkness.keys.json");
            load();
        }
        public function getBinding(action:String):Object {return copy(values[action]);}
        public function setBinding(action:String,value:*):void {
            if(!values.hasOwnProperty(action)) throw new Error("Unknown light action");
            if(!writable) throw new Error("Unsupported key configuration; original file retained");
            var next:Object={headlamp:getBinding("headlamp"),fixture:getBinding("fixture")};
            next[action]=normalize(value);
            var stream:FileStream=new FileStream(),temporary:File=file.parent.resolvePath(file.name+".tmp");
            try {
                stream.open(temporary,FileMode.WRITE);
                stream.writeUTFBytes(JSON.stringify({version:1,headlamp:next.headlamp,fixture:next.fixture}));
                stream.close();temporary.moveTo(file,true);
            } catch(error:*) {
                try {stream.close();} catch(ignored:*) {}
                try {if(temporary.exists) temporary.deleteFile();} catch(cleanup:*) {}
                throw error;
            }
            values=next;clear();
        }
        private function load():void {
            if(!file.exists) return;
            var stream:FileStream=new FileStream();
            try {
                stream.open(file,FileMode.READ);
                var saved:Object=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
                if(saved.version!=1) throw new Error("unsupported key configuration");
                var next:Object={headlamp:getBinding("headlamp"),fixture:getBinding("fixture")};
                for each(var action:String in ["headlamp","fixture"]) if(saved.hasOwnProperty(action)) next[action]=normalize(saved[action]);
                values=next;
            } catch(error:*) {writable=false;LadLog.write("KEYS_LOAD_REJECT "+error+"; original file retained");}
            finally {try {stream.close();} catch(ignored:*) {}}
        }
        private static function copy(value:Object):Object {return {code:value.code,ctrl:value.ctrl,alt:value.alt,shift:value.shift};}
        private static function normalize(value:*):Object {
            // A legacy numeric binding has no modifiers; missing actions keep defaults.
            if(value is Number || value is int || value is uint) value={code:value};
            if(value==null || typeof value!="object" || value is Array || !value.hasOwnProperty("code")) throw new Error("Invalid key binding");
            var code:Number=Number(value.code);
            if(!isFinite(code) || code!=int(code) || code<0 || code>255 || code==16 || code==17 || code==18) throw new Error("Invalid key code");
            return {code:int(code),ctrl:code!=0 && Boolean(value.ctrl),alt:code!=0 && Boolean(value.alt),shift:code!=0 && Boolean(value.shift)};
        }
        public function attach(service:*):void {
            if(api!==service) {api=service;registered=null;clear();}
            if(!supported() || registered===api) return;
            var self:LadKeys=this;
            api.registerPage(PAGE,"光与暗 · 快捷键",[
                {key:"headlamp",kind:"keybind",label:"随身灯开关",
                 get:function():* {return self.getBinding("headlamp");},set:function(v:*):void {self.setBinding("headlamp",v);},
                 def:{code:76,ctrl:false,alt:true,shift:false},hint:"切换随身照明。"},
                {key:"fixture",kind:"keybind",label:"灯具开关 / 按住维修",
                 get:function():* {return self.getBinding("fixture");},set:function(v:*):void {self.setBinding("fixture",v);},
                 def:{code:69,ctrl:false,alt:true,shift:false},hint:"完整灯按一下开关；受损或故障灯按住两秒维修。"}
            ],null,"绑定立即保存；维修时需一直按住完整组合键。",
                {moduleId:"light-and-darkness",moduleName:"光与暗",featureName:"快捷键",featureOrder:99});
            registered=api;
        }
        private function supported():Boolean {
            return api && "keybindVersion" in api && int(api.keybindVersion)>=1 &&
                "matchesKey" in api && "isKeyDown" in api && "isCapturingKey" in api;
        }
        public function capturing():Boolean {
            var result:Boolean=true;
            try {result=api && "isCapturingKey" in api && Boolean(api.isCapturingKey());}
            catch(error:*) {}
            return result;
        }
        public function observeDown(event:KeyboardEvent):Boolean {
            var fresh:Boolean=!down[event.keyCode];
            down[event.keyCode]=true;ctrl=event.ctrlKey;alt=event.altKey;shift=event.shiftKey;
            return fresh;
        }
        public function observeUp(event:KeyboardEvent):void {
            delete down[event.keyCode];
            ctrl=event.keyCode==17?false:event.ctrlKey;
            alt=event.keyCode==18?false:event.altKey;
            shift=event.keyCode==16?false:event.shiftKey;
        }
        public function matches(action:String,event:KeyboardEvent):Boolean {
            if(capturing()) return false;
            if(registered===api && supported()) {
                try {return Boolean(api.matchesKey(PAGE,action,event));} catch(error:*) {return false;}
            }
            var binding:Object=values[action];
            return binding.code!=0 && event.keyCode==binding.code && event.ctrlKey==binding.ctrl && event.altKey==binding.alt && event.shiftKey==binding.shift;
        }
        public function held(action:String):Boolean {
            if(capturing()) return false;
            if(registered===api && supported()) {
                try {return Boolean(api.isKeyDown(PAGE,action));} catch(error:*) {return false;}
            }
            var binding:Object=values[action];
            return binding.code!=0 && Boolean(down[binding.code]) && ctrl==binding.ctrl && alt==binding.alt && shift==binding.shift;
        }
        public function clear():void {down={};ctrl=alt=shift=false;}
        public function label(action:String):String {
            var binding:Object=values[action],code:int=binding.code;
            if(code==0) return "未绑定";
            var name:String=code>=65 && code<=90 || code>=48 && code<=57?String.fromCharCode(code):
                code>=112 && code<=135?"F"+(code-111):String(code);
            var names:Object={8:"Backspace",9:"Tab",13:"Enter",27:"Esc",32:"空格",33:"PageUp",34:"PageDown",35:"End",36:"Home",
                37:"←",38:"↑",39:"→",40:"↓",45:"Insert",46:"Delete",186:";",187:"=",188:",",189:"-",190:".",191:"/",192:"~",219:"[",220:"\\",221:"]",222:"'"};
            if(names.hasOwnProperty(code)) name=names[code];
            return (binding.ctrl?"Ctrl+":"")+(binding.alt?"Alt+":"")+(binding.shift?"Shift+":"")+name;
        }
    }
}
