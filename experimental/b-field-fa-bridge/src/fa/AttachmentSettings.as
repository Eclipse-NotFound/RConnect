package fa {
    import flash.events.KeyboardEvent;
    import flash.filesystem.*;
    /** Owns preferences and registers callback-only pages with the native mod menu. */
    public class AttachmentSettings {
        public var values:Object;
        private var engine:Runtime, registered:*, retry:int=0, registeredKeys:Boolean=false;
        public static const HOTKEY_PAGE:String="firearmattachments-hotkeys";
        public static const KEY_DEFAULTS:Object={workbench:{code:77,ctrl:true,alt:false,shift:false},bayonet:{code:86,ctrl:true,alt:false,shift:false},
            bipod:{code:66,ctrl:true,alt:false,shift:false},optic:{code:79,ctrl:true,alt:false,shift:false},grenade:{code:71,ctrl:true,alt:false,shift:false}};
        private var bindings:Object=JSON.parse(JSON.stringify(KEY_DEFAULTS));
        public static const DEFAULTS:Object={autoBipod:true, crouchBipod:true, deploySteps:4, moveTolerance:3, turnTolerance:100, retractGrace:6,
            shortDamage:16, shortContact:8, longDamage:36, longContact:14, speedBonusPerUnit:4, speedBonusCap:100,
            impactStrength:100,impactSpeedBonus:6,impactRecovery:8};
        private static const LIMITS:Object={deploySteps:[0,60,1],moveTolerance:[0,15,.5],turnTolerance:[15,180,5],retractGrace:[0,30,1],
            shortDamage:[0,200,1],shortContact:[0,200,1],longDamage:[0,300,1],longContact:[0,300,1],speedBonusPerUnit:[0,20,1],speedBonusCap:[0,300,10],
            impactStrength:[0,300,10],impactSpeedBonus:[0,20,1],impactRecovery:[0,30,1]};
        // Keep the old grenade property readable for migration and existing integrations.
        public function get binding():Object {return getBinding("grenade");}
        public function set binding(value:Object):void {var b:Object=normalizeBinding(value);if(b)bindings.grenade=b;}
        public function AttachmentSettings(e:Runtime,localPreferences:Boolean=true) {engine=e;values=JSON.parse(JSON.stringify(DEFAULTS));if(localPreferences)load();syncCatalog();}
        private function path():File {return File.applicationStorageDirectory.resolvePath("FirearmAttachments.preferences.json");}
        public function load():void {
            var f:File=path(),stream:FileStream=new FileStream();if(!f.exists)return;
            try {
                stream.open(f,FileMode.READ);var raw:Object=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));stream.close();
                if(raw.version!=1)return;
                if(raw.values)for(var k:String in DEFAULTS)if(raw.values.hasOwnProperty(k))values[k]=sanitize(k,raw.values[k]);
                if(raw.binding!=null)binding=raw.binding;
                if(raw.bindings)for(k in KEY_DEFAULTS)if(raw.bindings.hasOwnProperty(k)) {
                    var b:Object=normalizeBinding(raw.bindings[k]);if(b)bindings[k]=b;
                }
            }catch(err:Error){try{stream.close();}catch(ignored:Error){}engine.log("settings load rejected "+err.message);}
        }
        public function save():void {
            var tmp:File=File.applicationStorageDirectory.resolvePath("FirearmAttachments.preferences.tmp"),s:FileStream=new FileStream();
            try {s.open(tmp,FileMode.WRITE);s.writeUTFBytes(JSON.stringify({version:1,values:values,binding:binding,bindings:bindings}));s.close();tmp.moveTo(path(),true);}
            catch(err:Error){try{s.close();}catch(ignored:Error){}engine.log("settings save failed "+err.message);engine.message("设置暂未保存："+err.message);}
        }
        public function sanitize(key:String,value:*):* {
            if(DEFAULTS[key] is Boolean)return value is Boolean?value:DEFAULTS[key];
            var range:Array=LIMITS[key],n:Number=Number(value);
            if(!range||value===null||value is Boolean||!isFinite(n))return DEFAULTS[key];
            return Math.max(range[0],Math.min(range[1],Math.round(n/range[2])*range[2]));
        }
        public function setValue(key:String,value:*):void {
            if(!DEFAULTS.hasOwnProperty(key))return;
            values[key]=sanitize(key,value);syncCatalog();save();
        }
        public function syncCatalog():void {
            if(!engine.catalog)return;
            for each(var id:String in ["bayonet_short","bayonet_long"]) {
                var p:Object=engine.catalog.parts[id],short:Boolean=id=="bayonet_short";
                p.melee.damage=values[short?"shortDamage":"longDamage"];p.melee.passive=values[short?"shortContact":"longContact"];
                p.melee.speedBonusPerUnit=values.speedBonusPerUnit;p.melee.speedBonusCap=values.speedBonusCap;
                p.melee.impactStrength=values.impactStrength;p.melee.impactSpeedBonus=values.impactSpeedBonus;p.melee.impactRecovery=values.impactRecovery;
                p.benefit=(short?"挥击":"戳刺")+p.melee.damage+"/"+p.melee.period+"步，穿甲"+p.melee.pier+"；碰刃/甩刀切割"+p.melee.passive+"，穿甲"+p.melee.passivePier+"；近战加成/主动暴击；速度+"+values.speedBonusPerUnit+"%/单位，最多+"+values.speedBonusCap+"%。";
            }
            p=engine.catalog.parts.bipod;p.deploySteps=values.deploySteps;
            p.cost="伏低自动展开"+values.deploySteps+"步；移动阈值"+values.moveTolerance+"，射界±"+values.turnTolerance+"°；可在模组设置调整。";
        }
        public static function normalizeBinding(value:*):Object {
            if(value is Number || value is int || value is uint)value={code:value};
            if(value==null||value.code===null||value.code is Boolean)return null;
            var code:Number=Number(value.code);
            if(!isFinite(code)||code!=int(code)||(code!=0&&(code<8||code>222||[16,17,18,91,92,93].indexOf(int(code))>=0)))return null;
            return {code:int(code),ctrl:code!=0&&value.ctrl===true,alt:code!=0&&value.alt===true,shift:code!=0&&value.shift===true};
        }
        public function getBinding(action:String):Object {
            return KEY_DEFAULTS.hasOwnProperty(action)?normalizeBinding(bindings[action]):null;
        }
        public function setBinding(action:String,value:*):void {
            var b:Object=normalizeBinding(value);if(!b||!KEY_DEFAULTS.hasOwnProperty(action))return;
            bindings[action]=b;save();
        }
        private function service():* {
            var c:*=engine.main.getChildByName("ModSettingsCarrier");return c?c["modAPI"]:null;
        }
        private function supportsKeys(api:*):Boolean {
            return api&&("keybindVersion" in api)&&int(api.keybindVersion)>=1&&("matchesKey" in api)&&("isCapturingKey" in api);
        }
        public function isCapturingKey():Boolean {
            var api:*=service();return supportsKeys(api)&&api.isCapturingKey();
        }
        public function keyLabel(action:String="grenade"):String {
            var b:Object=getBinding(action),api:*=service();
            if(!b||!b.code)return "未绑定";
            if(supportsKeys(api)&&("keyLabel" in api))return api.keyLabel(b);
            var code:int=int(b.code),name:String=code>=65&&code<=90||code>=48&&code<=57?String.fromCharCode(code):code>=112&&code<=123?"F"+(code-111):"键"+code;
            return (b.ctrl?"Ctrl+":"")+(b.alt?"Alt+":"")+(b.shift?"Shift+":"")+name;
        }
        // Bare native controls must still work after a native rebind or without the shared host.
        private function nativeConflict(b:Object):Boolean {
            if(b.ctrl||b.alt||b.shift)return false;
            if([9,27,35,36,45,46,192].indexOf(int(b.code))>=0)return true;
            if(engine.ready()) {
                var native:Object=engine.w.ctr.save();
                for(var id:String in native)if(String(native[id].a1)==String(b.code)||String(native[id].a2)==String(b.code))return true;
            }
            return false;
        }
        public function matchesAction(action:String,e:KeyboardEvent):Boolean {
            var b:Object=getBinding(action),api:*=service();
            if(!e||!b||!b.code||nativeConflict(b)||isCapturingKey())return false;
            if(supportsKeys(api)) {
                // Register before delegating: service may arrive between our periodic ticks.
                if(api!==registered||!registeredKeys){registered=api;refresh();}
                return api.matchesKey(HOTKEY_PAGE,action,e);
            }
            return e.keyCode==b.code&&e.ctrlKey==b.ctrl&&e.altKey==b.alt&&e.shiftKey==b.shift;
        }
        public function matches(e:KeyboardEvent):Boolean {return matchesAction("grenade",e);}
        public function tick():void {
            if(++retry%30!=1)return;
            var api:*=service();
            if(!api){registered=null;registeredKeys=false;return;}
            if(api!==registered||supportsKeys(api)!=registeredKeys){registered=api;refresh();engine.log("settings registered: firearmattachments");}
        }
        private function keyItem(action:String,label:String,hint:String):Object {
            return {key:action,label:label,kind:"keybind",def:normalizeBinding(KEY_DEFAULTS[action]),hint:hint,
                get:function():*{return getBinding(action);},set:function(v:*):void{setBinding(action,v);}};
        }
        private function item(key:String,label:String,hint:String,suffix:String=""):Object {
            var range:Array=LIMITS[key],scale:Number=key=="deploySteps"||key=="retractGrace"||key=="impactRecovery"?30:1;
            var o:Object={key:key,label:label,hint:hint,def:range?Number(DEFAULTS[key])/scale:DEFAULTS[key],kind:range?"slider":"check",
                get:function():*{return range?Number(values[key])/scale:values[key];},set:function(v:*):void{setValue(key,range?Number(v)*scale:v);}};
            if(range){o.min=range[0]/scale;o.max=range[1]/scale;o.step=range[2]/scale;o.suffix=suffix;}
            return o;
        }
        private function register(id:String,title:String,items:Array,desc:String,order:int):void {
            registered.registerPage(id,"枪械改装 · "+title,items,function():void{save();},desc,
                {moduleId:"firearmattachments",moduleName:"枪械改装",featureName:title,featureOrder:order});
        }
        public function refresh():void {
            if(!registered)return;
            registeredKeys=supportsKeys(registered);
            if(registeredKeys)register(HOTKEY_PAGE,"快捷键",[
                keyItem("workbench","武器改装入口","打开原版武器页，再选择要改装的武器。"),
                keyItem("bayonet","刺刀主动攻击","短刃挥击、长刃突刺；转动瞄准的自动切割不需要此键。"),
                keyItem("bipod","两脚架开关","手动展开或收起；伏低自动展开规则保持。"),
                keyItem("optic","增倍镜开关","切换已安装的增倍镜。"),
                keyItem("grenade","下挂榴弹发射","独立发射下挂榴弹；原版手雷键仍可投掷手雷。")
            ],"点击按键后输入组合；Esc取消，Delete清除。设置立即保存；额外修饰键不会触发。",99);
            register("firearmattachments-bipod","两脚架",[
                item("autoBipod","伏低自动展开","趴伏并接地时自动架枪；起身立即收起。"),
                item("crouchBipod","蹲伏也自动展开","S键蹲伏也视为低姿；取消后仅掩体趴伏自动展开。"),
                item("deploySteps","展开时间","按正常游戏速度显示秒数；0为立即展开，暂停时不推进。","秒"),
                item("moveTolerance","移动阈值（像素/步）","水平速度超过此值才累计收起等待；越大越宽松。"),
                item("turnTolerance","转向收起阈值","相对架枪朝向的偏转角；180表示转身也不收起。","°"),
                item("retractGrace","越限收起等待","移动或转向连续越限达到此时长才收起；离地和起身立即收起。","秒")
            ],"设置立即生效并保存在本机。手动开关可在「快捷键」页修改；手动收起后本次低姿不自动重开。",0);
            register("firearmattachments-grenade","下挂操控",[],
                "下挂独立发射键请到「快捷键」页查看、修改、清除或恢复默认。原版手雷键保持原用法。",1);
            register("firearmattachments-bayonet","刺刀伤害",[
                item("shortDamage","短刃主动基础伤害","仍乘角色近战加成，再结算护甲与暴击。"),
                item("shortContact","短刃碰刃/切割伤害","转动瞄准甩刀切割与接触共用基值、间隔；近战/速度加成，不暴击。"),
                item("longDamage","长刃主动基础伤害","仍乘角色近战加成，再结算护甲与暴击。"),
                item("longContact","长刃碰刃/切割伤害","转动瞄准甩刀切割与接触共用基值、间隔；不影响念力抓取/抛掷。"),
                item("speedBonusPerUnit","每单位相对速度增伤","双方水平及竖直速度之差的大小；单位为像素/步。0关闭。","%"),
                item("speedBonusCap","速度额外增伤上限","100%表示速度项最多使伤害翻倍；护甲与主动暴击随后结算。0关闭。","%")
            ],"立即生效，短/长主动及碰刃均获速度加成。默认短16/8、长36/14，速度每单位+4%、最多+100%。",2);
            register("firearmattachments-impact","刺刀冲击",[
                item("impactStrength","阻停与击退强度","100%为默认；长刃更强。0关闭新冲击，保留原减速；质量和击退抗性仍生效。","%"),
                item("impactSpeedBonus","每单位相对速度冲击加成","同时增强击退和停顿，额外最多150%；与刺刀伤害加成独立。0取消速度加成。","%"),
                item("impactRecovery","基础停顿时间","主动命中基准；碰刃/切割为75%，速度可延长，实际最多0.8秒。0只击退不停顿。","秒")
            ],"先阻停迎面冲势，再向外击退；念力抓取和抛掷期间让行。默认强度100%、每单位速度+6%、基础停顿约0.27秒。",3);
        }
    }
}
