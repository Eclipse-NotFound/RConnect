package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.describeType;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import defensecheck.*;

   /** Real old/new extracted functions. Fixtures model public slots, not a game. */
   public class DefenseReadChecks extends Sprite {
      private var assertions:Array=[],failed:int=0,work:Array=[],benchmarks:Array=[];
      private var benchmarkUnit:Unit,benchmarkObject:Object,sink:Object;
      private var started:int=getTimer();
      public function DefenseReadChecks() {
         work=[basic,edgeValues,fallbacks,ordering,otherGroups,mutableNames,prepareBench,
            function():void{measure(false,"A1");},function():void{measure(true,"B1");},
            function():void{measure(true,"B2");},function():void{measure(false,"A2");},verifyBench];
         addEventListener(Event.ENTER_FRAME,next);
      }
      private function next(e:Event):void {
         try {if(work.length){var f:Function=work.shift();f();}else finish();}
         catch(error:Error){check(false,"uncaught "+error.getStackTrace());finish();}
      }
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});if(!ok)failed++;}
      private static function canon(v:*):String {
         if(v===undefined)return "undefined";if(v===null)return "null";
         if(v is Number){if(isNaN(Number(v)))return "NaN";if(v===0 && 1/Number(v)<0)return "-0";return String(v);}
         if(v is Boolean || v is String)return JSON.stringify(v);
         var items:Array=[],key:String;
         if(v is Array){for each(var item:* in v)items.push(canon(item));return "["+items.join(",")+"]";}
         var names:Array=[];for(key in v)names.push(key);names.sort();
         for each(key in names)items.push(key+":"+canon(v[key]));return "{"+items.join(",")+"}";
      }
      private static function keys(v:Object):Array {var a:Array=[];for(var k:String in v)a.push(k);return a;}
      private function same(a:*,b:*,label:String):void {check(canon(a)==canon(b),label);}
      private static function plain():Object {
         return {maxhp:101,skin:1,armor:2,marmor:3,armor_hp:4,armor_maxhp:5,armor_qual:6,
            shithp:7,shitArmor:8,allVulnerMult:9,vulner:[1,2,3],dexter:10,dexterPlus:11,dodge:12,
            invulner:false,transp:true,opt:{shared:"native"},mech:false,blood:2,mat:1,maxShok:30,showNumbs:true};
      }
      private static function fill(u:Object):void {var p:Object=plain();for each(var key:String in DefenseBefore.FIELDS)u[key]=p[key];}
      private function basic():void {
         var u:Unit=new Unit();fill(u);var a:Object=DefenseBefore.capture(u),b:Object=DefenseAfter.capture(u);
         same(a,b,"native all 22 fields equal");
         check(keys(a).length==22 && keys(b).length==22,"native all 22 fields present");
         same(keys(a),keys(b),"same output enumeration order");
         var types:Object={};for each(var node:XML in describeType(u).variable)types[String(node.@name)]=String(node.@type);
         var expected:Object={vulner:"Array",opt:"Object",invulner:"Boolean",transp:"Boolean",mech:"Boolean",showNumbs:"Boolean",blood:"int",mat:"int",maxShok:"int"};
         for each(var name:String in DefenseBefore.FIELDS)
            check(types[name]==(name in expected?expected[name]:"Number"),"verified native public slot type "+name);
         check(a.vulner!==u.vulner && b.vulner!==u.vulner && a.vulner!==b.vulner,"vulner independently cloned by numbers");
         check(a.opt===u.opt && b.opt===u.opt,"opt Object reference preserved");
         var second:Object=DefenseAfter.capture(u);check(b!==second && b.vulner!==second.vulner,"each capture has fresh output and array");
         u.armor=99;u.vulner[0]=88;check(a.armor==2 && b.armor==2 && a.vulner[0]==1 && b.vulner[0]==1,"source mutation cannot rewrite old scalar or vulner");
         check(DefenseAfter.capture(u).armor==99,"next capture sees new native slot");
         var child:DynamicUnit=new DynamicUnit();fill(child);child.extra="kept outside defense";
         same(DefenseBefore.capture(child),DefenseAfter.capture(child),"third-party dynamic Unit subclass keeps inherited slots");
         check(!("extra" in DefenseAfter.capture(child)),"subclass extension does not enter defense output");
      }
      private function edgeValues():void {
         var u:Unit=new Unit();fill(u);u.skin=NaN;u.armor=Infinity;u.marmor=-Infinity;u.armor_hp=-1/Infinity;
         u.vulner=null;u.opt=null;u.invulner=false;u.maxShok=0;
         var a:Object=DefenseBefore.capture(u),b:Object=DefenseAfter.capture(u);same(a,b,"native NaN infinity signed zero null false zero");
         check(isNaN(b.skin) && b.armor===Infinity && b.marmor===-Infinity && 1/b.armor_hp===-Infinity,"numeric values are not sanitized");
         check(!("vulner" in b) && !("opt" in b) && b.invulner===false && b.maxShok===0,"null omitted but false and zero retained");
         var sparse:Array=[];sparse[2]="3";sparse[5]=undefined;sparse[7]=null;u.vulner=sparse;
         same(DefenseBefore.capture(u),DefenseAfter.capture(u),"sparse vulner follows original for-each conversion");
         var nested:Object={id:"shared"};u.opt=[nested,undefined,null];a=DefenseBefore.capture(u);b=DefenseAfter.capture(u);
         check(a.opt!==u.opt && b.opt!==u.opt && a.opt!==b.opt && a.opt[0]===nested && b.opt[0]===nested,"opt Array shallow clone and nested aliases");
         same(a,b,"opt Array undefined null contents");
         var p:Object=plain();p.skin=undefined;p.armor=null;p.vulner=undefined;p.opt=null;
         same(DefenseBefore.capture(p),DefenseAfter.capture(p),"plain undefined and null fallback");
         b=DefenseAfter.capture(p);check(!("skin" in b) && !("armor" in b) && !("vulner" in b) && !("opt" in b),"plain absent-value properties omitted");
         same(DefenseBefore.capture(null),DefenseAfter.capture(null),"null source stays protected fallback");
         check(keys(DefenseAfter.capture(null)).length==0,"null source yields empty object");
      }
      private function fallbacks():void {
         var a:GetterFixture=new GetterFixture(),b:GetterFixture=new GetterFixture();
         var va:Object=DefenseBefore.capture(a),vb:Object=DefenseAfter.capture(b);same(va,vb,"throwing getters result unchanged");
         same(a.traceCalls,b.traceCalls,"throwing getter order and count unchanged");
         check(vb.marmor===7 && vb.showNumbs===false && !("skin" in vb) && !("armor" in vb),"throw or undefined skips only that field");
         same(b.traceCalls,["maxhp","skin","armor","marmor","showNumbs"],"getter independent expected access sequence");
         for each(var mode:String in ["normal","missing","has-throws","get-throws","undefined"]) {
            var pa:ReadProxy=new ReadProxy(plain(),mode),pb:ReadProxy=new ReadProxy(plain(),mode);
            va=DefenseBefore.capture(pa);vb=DefenseAfter.capture(pb);
            same(va,vb,"Proxy "+mode+" output");same(pa.traceCalls,pb.traceCalls,"Proxy "+mode+" exact has/get sequence");
            if(mode=="normal") {
               var expected:Array=[];for each(var key:String in DefenseBefore.FIELDS){expected.push("has:"+key);expected.push("get:"+key);}
               same(pb.traceCalls,expected,"all 22 source fields are read in original order");
            }
         }
         var ap:PointGetter=new PointGetter(),bp:PointGetter=new PointGetter();
         same(DefenseBefore.capture(ap),DefenseAfter.capture(bp),"Pt without Unit slots uses fallback");
         same(ap.traceCalls,bp.traceCalls,"Pt getter side effects unchanged");
         check(bp.traceCalls.join(",")=="skin,armor","Pt getters are still protected");
      }
      private static function mutationFixture(throws:Boolean=false):Object {
         var u:Unit=new Unit();fill(u);var traceCalls:Array=[];
         var value:Object={};value.valueOf=function():Number {traceCalls.push("vulner.valueOf");u.dexter=77;u.opt={after:"conversion"};if(throws)throw new Error("fixture conversion");return 2.5;};
         u.vulner=[value];return {u:u,traceCalls:traceCalls};
      }
      private static function outcome(f:Function,u:Object):Object {
         try {return {value:f(u)};}catch(error:Error){return {error:error.name+":"+error.message};}
         return null;
      }
      private function ordering():void {
         var a:Object=mutationFixture(),b:Object=mutationFixture();
         var va:Object=DefenseBefore.capture(a.u),vb:Object=DefenseAfter.capture(b.u);
         same(va,vb,"vulner valueOf mutates later native slots in both paths");
         check(vb.dexter===77 && vb.vulner[0]===2.5 && vb.opt===b.u.opt,"later slots read after current conversion");
         same(a.traceCalls,b.traceCalls,"native conversion callback order and count");
         check(b.traceCalls.join(",")=="vulner.valueOf","no prefetch or duplicate native conversion");
         a=mutationFixture(true);b=mutationFixture(true);
         same(outcome(DefenseBefore.capture,a.u),outcome(DefenseAfter.capture,b.u),"conversion exceptions propagate unchanged");
         same(a.traceCalls,b.traceCalls,"throwing conversion still executes once");
         var source:Unit=new Unit();fill(source);var first:Object=DefenseAfter.capture(source);source.skin=47;
         var next:Object=DefenseAfter.capture(source);check(first.skin===1 && next.skin===47,"two sampling times remain independent");
      }
      private function otherGroups():void {
         var u:DynamicUnit=new DynamicUnit();fill(u);u.levit_max=new XML("<limit>4.5</limit>").text();u.dx=4;u.dy=-2;u.npc=true;
         var names:Array=["dx","dy","stay","isFly","isLaz","levit","scX","scY","levit_max","npc","extension","failingExtension","absent"];
         var a:Object=DefenseBefore.other(u,names),log:Array=u.traceCalls.concat();u.traceCalls=[];
         var b:Object=DefenseAfter.other(u,names);same(a,b,"all non-defense call bodies remain unchanged");
         same(log,u.traceCalls,"non-defense native subclass getters remain protected");
         check(b.levit_max===4.5 && !("extension" in b) && !("failingExtension" in b),"XML numeric conversion and undefined/throw behavior unchanged");
         var p:Object={levit_max:undefined,skin:NaN,opt:{same:true}};
         same(DefenseBefore.other(p,["levit_max","skin","opt"]),DefenseAfter.other(p,["levit_max","skin","opt"]),"arbitrary field list stays generic");
      }
      private function prepareBench():void {
         benchmarkUnit=new Unit();fill(benchmarkUnit);benchmarkObject=plain();
         run(DefenseBefore.capture,benchmarkUnit,1000);run(DefenseAfter.capture,benchmarkUnit,1000);
         run(DefenseBefore.capture,benchmarkObject,1000);run(DefenseAfter.capture,benchmarkObject,1000);
      }
      private function mutableNames():void {
         var a:DynamicUnit=new DynamicUnit(),b:DynamicUnit=new DynamicUnit();fill(a);fill(b);a.extra=73;b.extra=73;
         var names:Array=["extension","failingExtension","absent","extra"];
         for each(var name:String in names){DefenseBefore.FIELDS.push(name);DefenseAfter.FIELDS.push(name);}
         try {
            var va:Object=DefenseBefore.capture(a),vb:Object=DefenseAfter.capture(b);
            same(va,vb,"public defense array appended unknown and dynamic fields");
            same(a.traceCalls,b.traceCalls,"appended native subclass getter side effects remain protected");
            check(vb.extra===73 && !("extension" in vb) && !("failingExtension" in vb) && !("absent" in vb),"appended undefined throw missing and dynamic values retain semantics");
            same(b.traceCalls,["extension","failingExtension"],"appended unknown getters execute once in original order");
         } finally {
            for(var i:int=0;i<names.length;i++){DefenseBefore.FIELDS.pop();DefenseAfter.FIELDS.pop();}
         }
         check(DefenseBefore.FIELDS.length==22 && DefenseAfter.FIELDS.length==22,"mutable fixture list restored before benchmarks");
         same(DefenseBefore.capture(a),DefenseAfter.capture(b),"fixed list returns to original 22-field result");
      }
      private function run(f:Function,u:Object,n:int):int {
         var at:int=getTimer();for(var i:int=0;i<n;i++)sink=f(u);return getTimer()-at;
      }
      private function measure(after:Boolean,label:String):void {
         var f:Function=after?DefenseAfter.capture:DefenseBefore.capture;
         benchmarks.push({label:label,after:after,iterations:20000,nativeMs:run(f,benchmarkUnit,20000),
            genericIterations:10000,genericMs:run(f,benchmarkObject,10000)});
      }
      private function verifyBench():void {
         check(benchmarks.length==4 && benchmarks[0].label=="A1" && benchmarks[1].label=="B1" && benchmarks[2].label=="B2" && benchmarks[3].label=="A2","ABBA full-capture measurement completed");
         same(DefenseBefore.capture(benchmarkUnit),DefenseAfter.capture(benchmarkUnit),"benchmark native outputs still equal");
         same(DefenseBefore.capture(benchmarkObject),DefenseAfter.capture(benchmarkObject),"benchmark generic outputs still equal");
         check(sink!=null && keys(sink).length==22,"benchmark consumes complete 22-field output");
      }
      private function finish():void {
         removeEventListener(Event.ENTER_FRAME,next);
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,benchmarks:benchmarks,
            elapsedMs:getTimer()-started,nativeWorld:false,productionTiming:false,performanceQualified:false,
            realExtractedMethods:true,fixtureSlotsOnly:true,measurementIncludesFullCapture:true}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
