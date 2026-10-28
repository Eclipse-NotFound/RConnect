package fa {
    import flash.utils.ByteArray;
    public class Catalog {
        [Embed(source="../../data/catalog.json",mimeType="application/octet-stream")]
        private static const Bytes:Class;
        public var data:Object;
        public var guns:Object={};
        public var parts:Object={};
        public static const FACES:Array=["top","side","under"];
        public static const SLOTS:Object={top:"顶部导轨",side:"侧面导轨",under:"下导轨",stock:"枪托",bipod:"两脚架",mag:"供弹",muzzle:"枪口"};
        public function Catalog() {
            data=JSON.parse(ByteArray(new Bytes()).toString());
            for each(var w:Object in data.weapons) guns[w.id]=w;
            for each(var p:Object in data.components) parts[p.id]=p;
        }
        public static function clone(o:Object):Object { return JSON.parse(JSON.stringify(o)); }
        public static function has(s:Object,id:String):Boolean { return s && s.items.indexOf(id)>=0; }
        public static function blank():Object { return {items:[],rails:{top:0,side:0,under:0},railStarts:{top:0,side:0,under:0},positions:{},mode:"near",grenadeWait:0}; }
        public function validate(id:String,s:Object):String {
            var w:Object=guns[id], p:Object, seen:Object={}, slots:Object={}, optic:int=0, a:Array, f:String, end:int, start:Number;
            if(!w || !s || !(s.items is Array) || !s.rails || !s.railStarts || !s.positions) return "装配记录不完整";
            if(s.items.length>22) return "组件过多";
            for each(var pid:String in s.items) {
                p=parts[pid];
                if(!p || p.compat.indexOf(id)<0) return "此枪不支持该组件";
                if(seen[pid]) return "同一组件不能重复安装";
                seen[pid]=true;
                if(p.requires && !has(s,p.requires)) return "请先安装快瞄红点";
                if(p.kind=="optic") optic++;
                if(FACES.indexOf(p.slot)<0) { if(slots[p.slot]) return "独立接口已被占用"; slots[p.slot]=true; }
            }
            if(optic>1) return "只能安装一个主瞄具";
            for each(f in FACES) {
                start=Number(s.railStarts[f]);
                var len:Number=Number(s.rails[f]);
                if(!isFinite(start)||!isFinite(len)||start!=int(start)||len!=int(len)||start<0||len<0||start+len>w.rails[f]) return "导轨超出枪体范围";
                a=[];
                for each(pid in s.items) if(parts[pid].slot==f) a.push({id:pid,start:s.positions[pid],length:parts[pid].length});
                a.sortOn("start",Array.NUMERIC); end=-1;
                for each(p in a) {
                    var pos:Number=Number(p.start);
                    if(!isFinite(pos)||pos!=int(pos)||pos<start||pos+p.length>start+len) return "部件需要完整落在已铺导轨上";
                    if(pos<end) return "部件位置重叠";
                    end=pos+p.length;
                }
            }
            if(has(s,"magnifier")&&int(s.positions.magnifier)+2!=int(s.positions.dot)) return "增倍模块须紧接红点左侧，请预留两格";
            return "";
        }
        public function paint(id:String,s:Object,face:String,start:int,len:int):Object {
            var n:Object=clone(s);
            if(FACES.indexOf(face)<0) return {error:"请选择三侧导轨"};
            n.railStarts[face]=start; n.rails[face]=len;
            var e:String=validate(id,n); return e?{error:e}:{state:n};
        }
        public function install(id:String,s:Object,pid:String,slot:String,start:int):Object {
            var p:Object=parts[pid], n:Object=clone(s), olds:Array=[], moving:Boolean=has(s,pid), linked:Boolean;
            if(!p || p.slot!=slot) return {error:"接口不符"};
            if(p.compat.indexOf(id)<0) return {error:"此枪不支持该组件"};
            linked=moving&&has(n,"dot")&&has(n,"magnifier")&&(pid=="dot"||pid=="magnifier");
            for each(var old:String in n.items) {
                if(old==pid) continue;
                var op:Object=parts[old];
                if(!moving&&((p.kind=="optic"&&(op.kind=="optic"||old=="magnifier"))||(FACES.indexOf(slot)<0&&op.slot==slot))) { delete n.positions[old]; continue; }
                olds.push(old);
            }
            olds.push(pid); n.items=olds; n.positions[pid]=start;
            if(linked) n.positions[pid=="dot"?"magnifier":"dot"]=start+(pid=="dot"?-2:2);
            if(!has(n,"magnifier")) n.mode="near";
            var e:String=validate(id,n); return e?{error:e}:{state:n};
        }
        public function remove(s:Object,pid:String):Object {
            var n:Object=clone(s), a:Array=[];
            for each(var p:String in n.items) if(p!=pid && !(pid=="dot"&&p=="magnifier")) a.push(p); else delete n.positions[p];
            n.items=a; if(!has(n,"magnifier"))n.mode="near"; return n;
        }
        public function numbers(id:String,b:Object,s:Object,still:Boolean=false,supported:Boolean=false):Object {
            var r:Object=clone(b), pm:Number=1, tm:Number=1, rm:Number=1, p:Object,k:String;
            r.jitter=1;
            for each(var pid:String in s.items) {
                p=parts[pid];
                if(p.mag && p.mag[id]) {
                    // Preserve variant/other-mod base ratios instead of replacing them with vanilla base values.
                    r.holder=b.holder*p.mag[id][0]/guns[id].holder;
                    r.reload=b.reload*p.mag[id][1]/guns[id].reload;
                }
                if(p.overrides&&p.overrides[id]) for(k in p.overrides[id]) {
                    // Keep a unique weapon's native recharge/consumption advantage.
                    var scaled:Number=b[k]*p.overrides[id][k]/guns[id][k];
                    r[k]=k=="rashod"?Math.max(1,pid=="economy_cell"?Math.floor(scaled+1e-8):Math.ceil(scaled-1e-8)):scaled;
                }
            }
            for each(pid in s.items) {
                p=parts[pid];
                for(k in p.fx) {
                    if(k=="precision") pm*=p.fx[k];
                    else if(k=="turn")tm*=p.fx[k];
                    else if(k=="recoil")rm*=p.fx[k];
                    else if(k=="capacity")r.holder*=p.fx[k];
                    else if(k=="recovery")r[b.recharg>0?"recharg":"reload"]*=p.fx[k];
                    else r[k]*=p.fx[k];
                }
            }
            if(has(s,"dot")&&has(s,"magnifier")&&s.mode=="far") {pm*=1.15;tm*=.9;}
            else if(has(s,"dot")&&b.antiprec>0)r.antiprec*=.85;
            if(has(s,"scope_precision")&&still)pm*=1.25;
            if(has(s,"bipod")&&supported){pm*=1.2;r.jitter*=.85;}
            r.precision*=Math.min((supported||has(s,"scope_precision")&&still)?1.5:1.35,pm);
            r.drot*=Math.min(1.3,tm);r.drot2*=Math.min(1.3,tm);
            r.jitter=Math.max(.7,r.jitter);r.recoilFactor=Math.max(.65,rm);
            r.holder=Math.floor(r.holder+1e-8);
            for each(k in ["reload","recharg","prep","noise","shine"])r[k]=Math.round(r[k]);
            return r;
        }
    }
}
