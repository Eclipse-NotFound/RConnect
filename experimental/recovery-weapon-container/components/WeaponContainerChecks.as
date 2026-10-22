package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import rconnect.game.RemoteMotionBefore;
   import rconnect.game.RemoteMotionAfter;

   /** Full production classes, only renamed and with a reversible test adapter. */
   public class WeaponContainerChecks extends Sprite {
      private static const EXPECTED:int=70;
      private static const BENCH_CALLS:int=12000;
      private var assertions:Array=[],failed:int=0,work:Array=[],benchmarks:Array=[],fixtures:Array=[];
      private var lastResult:Array,started:int=getTimer();
      public function WeaponContainerChecks() {
         work=[modern,compatibility,containers,edges,publicPaths,prepareBench,
            function():void{measure(false,"A1");},function():void{measure(true,"B1");},
            function():void{measure(true,"B2");},function():void{measure(false,"A2");},verifyBench];
         addEventListener(Event.ENTER_FRAME,next);
      }
      private function next(e:Event):void {
         try {if(work.length){var f:Function=work.shift();f();}else finish();}
         catch(error:Error){check(false,"uncaught "+error.getStackTrace());finish();}
      }
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
      }
      private static function names(v:Object):Array {var out:Array=[];for(var k:String in v)out.push(k);return out;}
      private static function canon(v:*,seen:Array=null):String {
         if(v===undefined)return "undefined";if(v===null)return "null";
         if(v is Number){if(isNaN(v))return "NaN";if(v===0 && 1/Number(v)<0)return "-0";return String(v);}
         if(v is Boolean || v is String)return JSON.stringify(v);
         if(seen==null)seen=[];
         var prior:int=seen.indexOf(v);if(prior>=0)return "ref:"+prior;
         seen.push(v);
         var keys:Array=names(v).sort(),items:Array=[];
         for each(var key:String in keys)items.push(key+":"+canon(v[key],seen));
         return (v is Array?"Array:"+v.length:"Object")+"{"+items.join(",")+"}";
      }
      private static function eq(a:*,b:*):Boolean {return canon(a)==canon(b);}
      private static function weapon(slot:int,modern:Boolean=true):Object {
         var a:Object={slot:slot,id:"gun"+slot,variant:1,stream:2,shots:3,reload:0,cadence:50,
            ox:2,oy:4,rot:3,melee:{samples:[1,2]},extra:{tag:"shared"}};
         if(modern)a.display={x:2,y:4,r:3,sx:1,sy:-1,frame:3,label:"shoot",extra:a.extra};
         return a;
      }
      private static function endpoint(a:Object):Object {
         var b:Object={};for(var k:String in a)b[k]=a[k];
         b.ox=10;b.oy=12;b.rot=-3;b.melee={samples:[3,4]};
         if(a.display!=null)b.display={x:10,y:12,r:-3,sx:2,sy:1,frame:5,label:"reload",extra:{tag:"later"}};
         return b;
      }
      private static function outputs(first:Array,last:Array,t:Number=.5):Object {
         return {a:RemoteMotionBefore.componentBlend(first,last,t),b:RemoteMotionAfter.componentBlend(first,last,t)};
      }
      // Ten assertions: shape/values alone cannot prove the required aliasing.
      private function modern():void {
         var a:Object=weapon(0),b:Object=endpoint(a),first:Array=[a],last:Array=[b];
         var original:String=canon([first,last]),p:Object=outputs(first,last);
         check(eq(p.a,p.b),"modern complete values and alias graph equal");
         check(p.a!==first && p.b!==first && p.a!==last && p.b!==last && p.a!==p.b,"both return independently fresh containers");
         check(p.a[0]!==a && p.b[0]!==a && p.a[0]!==p.b[0],"matched modern items remain independent copies");
         check(p.a[0].display!==a.display && p.b[0].display!==a.display && p.a[0].display!==p.b[0].display,"modern display records remain independent copies");
         check(p.a[0].extra===a.extra && p.b[0].extra===a.extra && p.b[0].display.extra===a.extra,"nested source references remain shallow shared");
         check(p.a[0].melee===b.melee && p.b[0].melee===b.melee,"modern melee selects the same later packet reference");
         check(p.b[0].display.sx===1 && p.b[0].display.sy===-1 && p.b[0].display.frame===3,"reflection scale and native frame stay discrete from first pose");
         check(p.a[0].display.r===Math.PI && p.b[0].display.r===Math.PI,"modern angle crosses wrap on the original shortest arc");
         check(eq(names(p.a),names(p.b)) && eq(names(p.a[0]),names(p.b[0])) && eq(names(p.a[0].display),names(p.b[0].display)),"container and copied field enumeration order equal");
         check(canon([first,last])===original,"modern sources retain every scalar and reference");
      }
      // Ten assertions: compatibility copies and coercions are not optimized out.
      private function compatibility():void {
         var a:Object=weapon(0,false),b:Object=endpoint(a),first:Array=[a],last:Array=[b];
         var original:String=canon([first,last]),p:Object=outputs(first,last);
         check(eq(p.a,p.b),"compatibility complete values and alias graph equal");
         check(p.a!==first && p.b!==first && p.b!==last && p.a!==p.b,"compatibility keeps fresh containers");
         check(p.a[0]!==a && p.b[0]!==a && p.a[0]!==p.b[0],"compatibility items are still copied each time");
         check(p.a[0].extra===a.extra && p.b[0].extra===a.extra,"compatibility nested references preserved");
         check(!("display" in p.a[0]) && !("display" in p.b[0]),"missing display property is not introduced");
         check(p.a[0].rot===Math.PI && p.b[0].rot===Math.PI,"compatibility angle keeps shortest arc wrapping");
         check(p.b[0].ox===6 && p.b[0].oy===8,"compatibility offsets keep original Number interpolation");
         check(p.a[0].melee===a.melee && p.b[0].melee===a.melee,"compatibility retains original first melee reference");
         var unmatched:Object=outputs(first,[]);
         check(unmatched.a[0]!==a && unmatched.b[0]!==a && eq(unmatched.a,unmatched.b) && eq(unmatched.b[0],a),"unmatched compatibility item still receives shallow copy");
         check(canon([first,last])===original,"compatibility sources are not mutated");
      }
      // Twelve assertions for arrays, matching and repeated references.
      private function containers():void {
         var p:Object=outputs([],[]);
         check(eq(p.a,p.b) && p.b.length===0,"both empty arrays return an empty result");
         p=outputs([],[weapon(0)]);check(eq(p.a,p.b) && p.b.length===0,"empty first array does not copy later-only weapons");
         var m:Object=weapon(0),c:Object=weapon(1,false);
         p=outputs([m,c],[]);
         check(eq(p.a,p.b) && p.a[0]===m && p.b[0]===m && p.b[1]!==c,"empty last keeps unmatched modern identity and compatibility copy");
         var first:Array=[weapon(3),weapon(1,false),weapon(7),weapon(2,false)],last:Array=[];
         for each(var w:Object in first)last.unshift(endpoint(w));
         p=outputs(first,last);
         check(eq(p.a,p.b) && p.b.length===4 && p.b[0].slot===3 && p.b[1].slot===1 && p.b[2].slot===7 && p.b[3].slot===2,"mixed slots preserve first-array order independently of last order");
         p=outputs([m,m],[endpoint(m)]);
         check(eq(p.a,p.b) && p.a[0]!==p.a[1] && p.b[0]!==p.b[1] && p.b[0].extra===p.b[1].extra,"repeated matched modern references clone separately but share nested source");
         p=outputs([c,c],[endpoint(c)]);
         check(eq(p.a,p.b) && p.a[0]!==p.a[1] && p.b[0]!==p.b[1] && p.b[0].melee===c.melee,"repeated compatibility references clone separately");
         p=outputs([m,m],[]);
         check(eq(p.a,p.b) && p.a[0]===p.a[1] && p.b[0]===m && p.b[1]===m,"repeated unmatched modern references keep alias identity");
         var b:Object=endpoint(c),later:Object=endpoint(c);later.ox=900;
         p=outputs([c],[b,later]);check(eq(p.a,p.b) && p.b[0].ox===6,"first matching later record wins duplicate identity");
         var different:Array=[];
         for each(var key:String in ["slot","id","variant","stream"]){var d:Object=endpoint(m);d[key]="different";different.push(d);}
         p=outputs([m],different);check(eq(p.a,p.b) && p.b[0]===m,"all four identity fields remain necessary for matching");
         var sparse:Array=[];sparse[0]=m;sparse[5]=c;
         p=outputs(sparse,[]);check(eq(p.a,p.b) && p.b.length===2 && p.b[0]===m && p.b[1].slot===1,"sparse input becomes the same dense two-entry intermediate");
         var named:Array=[m];named["extraWeapon"]=c;
         p=outputs(named,[]);check(eq(p.a,p.b) && p.b.length===2 && eq(names(p.a),names(p.b)),"named enumerable input entry preserves original enumeration into dense result");
         first=[m,c];var original:String=canon(first);p=outputs(first,first);
         check(eq(p.a,p.b) && p.a[0]!==m && p.b[0]!==m && p.b[1]!==c && canon(first)===original,"same input array on both sides keeps original cloning and input ownership");
      }
      // Twelve safe numeric cases. Infinite angles would hang the ORIGINAL
      // while loop, so are intentionally not supplied or repaired here.
      private function edges():void {
         for(var i:int=0;i<12;i++) {
            var m:Object=weapon(0),c:Object=weapon(1,false),n:Object=endpoint(m),d:Object=endpoint(c),t:Number=.5;
            if(i==0)t=0;
            else if(i==1)t=1;
            else if(i==2)t=-.25;
            else if(i==3)t=1.25;
            else if(i==4)t=NaN;
            else if(i==5){m.display.r=NaN;c.rot=NaN;}
            else if(i==6){delete m.display.x;delete c.ox;}
            else if(i==7){m.display.y=null;c.oy=null;}
            else if(i==8){m.display=null;n.display=undefined;}
            else if(i==9){m.display.r=-0;c.rot=-0;n.display.r=-0;d.rot=-0;t=0;}
            else if(i==10){m.display.r=0;n.display.r=Math.PI;c.rot=0;d.rot=-Math.PI;}
            else {m.display.r=100*Math.PI;n.display.r=-99*Math.PI;c.rot=-120*Math.PI;d.rot=119*Math.PI;}
            var before:String=canon([m,c,n,d]),p:Object=outputs([m,c],[n,d],t);
            check(eq(p.a,p.b) && canon([m,c,n,d])===before,"numeric boundary "+i+" exact values signed zero NaN and source ownership");
         }
      }
      private static function snapshot(stamp:Number,x:Number=0):Object {
         var a:Object=weapon(0),b:Object=weapon(1,false);
         a.display.x=stamp/10;a.display.r=stamp/1000;b.ox=stamp/20;b.rot=-stamp/1000;
         return {sampleTime:stamp,x:x,y:20,aimX:x+100,aimY:40,roomKey:"room",roomEpoch:1,weapons:[a,b],
            visual:{anim:"run",pose:{blit:{first:1,length:8,ret:1,loop:true,st:false,stab:false,df:1,f:stamp/50%8+1}}}};
      }
      private static function pair(kind:String):Object {
         if(kind=="held")return {a:RemoteMotionBefore.held(),b:RemoteMotionAfter.held()};
         if(kind=="enemy")return {a:RemoteMotionBefore.enemy(),b:RemoteMotionAfter.enemy()};
         return {a:new RemoteMotionBefore(50,kind=="drop"),b:new RemoteMotionAfter(50,kind=="drop")};
      }
      private static function sampleEqual(p:Object,now:int):Boolean {
         var a:Object=p.a.sample(now),b:Object=p.b.sample(now);
         return eq(a,b) && eq(p.a.sourceTime,p.b.sourceTime) && eq(p.a.latestSampleTime,p.b.latestSampleTime)
            && eq(p.a.latestPosition,p.b.latestPosition) && p.a.currentSample===a && p.b.currentSample===b;
      }
      // Four assertions for each of four complete public clock paths, plus four boundaries.
      private function publicPaths():void {
         for each(var kind:String in ["actor","held","enemy","drop"]) {
            var p:Object=pair(kind),all:Boolean=true,records:Array=[],originals:Array=[];
            for(var i:int=0;i<12;i++) {
               var s:Object=snapshot(1000+i*50,i*2);records.push(s);originals.push(canon(s));
               p.a.push(s,1100+i*50);p.b.push(s,1100+i*50);
               all=sampleEqual(p,1100+i*50)&&sampleEqual(p,1115+i*50)&&all;
            }
            check(all,kind+" full sample output source clock latest position and current identity equal");
            var unchanged:Boolean=true;for(i=0;i<records.length;i++)unchanged=unchanged&&canon(records[i])===originals[i];
            check(unchanged,kind+" public push/sample leaves every input snapshot unchanged");
            var cursor:Number=p.b.sourceTime,previous:Array=p.b.currentSample.weapons;
            all=sampleEqual(p,1665);
            check(all && p.b.sourceTime===cursor && p.b.currentSample.weapons!==previous,kind+" zero-time sample retains original fresh-container behavior without clock change");
            p.a.settle(1665);p.b.settle(1665);
            s=snapshot(1600,24);p.a.push(s,1700);p.b.push(s,1700);
            var owner:Object={};p.a.retainRate(owner);p.b.retainRate(owner);
            all=sampleEqual(p,1716);p.a.releaseRate(owner);p.b.releaseRate(owner);
            check(all && sampleEqual(p,1732),kind+" settle resume and finite-rate ownership stay equivalent");
         }
         p=pair("actor");s=snapshot(1000);p.a.push(s,1100);p.b.push(s,1100);
         s=snapshot(1050,2);p.a.push(s,1150);p.b.push(s,1150);sampleEqual(p,1166);
         s=snapshot(1050,3);p.a.push(s,1167);p.b.push(s,1167);
         var older:Object=snapshot(1020,-1);p.a.push(older,1168);p.b.push(older,1168);
         check(sampleEqual(p,1182),"same-stamp replacement and older rejection use unchanged public path");
         s={x:7,y:8,aimX:9,aimY:10,weapons:[weapon(0)]};p.a.push(s,1200);p.b.push(s,1200);
         check(sampleEqual(p,1216) && p.a.currentSample.weapons===s.weapons && p.b.currentSample.weapons===s.weapons,"legacy unstamped path bypass and source reference are unchanged");
         p=pair("actor");s=snapshot(1000);p.a.push(s,1000);p.b.push(s,1000);
         s=snapshot(1100,20);s.port={events:[{seq:1,at:1050,fromX:0,fromY:20,toX:20,toY:20,
            postX:20,postY:20,scX:40,scY:40,roomKey:"room",roomEpoch:1}]};
         p.a.push(s,1100);p.b.push(s,1100);
         check(sampleEqual(p,1150) && sampleEqual(p,1190),"real TeleportVisuals.split and discontinuity selection stay unchanged");
         s=snapshot(1200,22);s.weapons=null;p.a.push(s,1200);p.b.push(s,1200);
         var plain:Object=snapshot(1250,24);plain.weapons={slot:0};p.a.push(plain,1250);p.b.push(plain,1250);
         check(sampleEqual(p,1266) && sampleEqual(p,1350),"null and non-Array weapons remain excluded at actual caller guard");
      }
      private function prepareBench():void {
         for each(var kind:String in ["modern","compatibility","mixed"]) {
            var first:Array=[],last:Array=[];
            for(var i:int=0;i<4;i++){var a:Object=weapon(i,kind=="modern"||(kind=="mixed"&&i%2==0));first.push(a);last.push(endpoint(a));}
            fixtures.push({kind:kind,first:first,last:last,original:canon([first,last]),expected:canon(RemoteMotionBefore.componentBlend(first,last,.375))});
            for(i=0;i<100;i++){lastResult=RemoteMotionBefore.componentBlend(first,last,.375);lastResult=RemoteMotionAfter.componentBlend(first,last,.375);}
         }
      }
      private function measure(after:Boolean,label:String):void {
         for each(var fixture:Object in fixtures) {
            var first:Array=fixture.first,last:Array=fixture.last,start:int=getTimer(),i:int;
            if(after)for(i=0;i<BENCH_CALLS;i++)lastResult=RemoteMotionAfter.componentBlend(first,last,.375);
            else for(i=0;i<BENCH_CALLS;i++)lastResult=RemoteMotionBefore.componentBlend(first,last,.375);
            var elapsed:int=getTimer()-start;
            // Serialization, assertions and source checks occur only after timing.
            benchmarks.push({block:label,after:after,kind:fixture.kind,calls:BENCH_CALLS,slots:4,ms:elapsed,
               output_ok:canon(lastResult)===fixture.expected,source_ok:canon([first,last])===fixture.original});
         }
      }
      private function verifyBench():void {
         for each(var kind:String in ["modern","compatibility","mixed"]) {
            var seq:Array=[],correct:Boolean=true,unchanged:Boolean=true;
            for each(var row:Object in benchmarks)if(row.kind===kind){seq.push(row.block);correct=correct&&row.output_ok;unchanged=unchanged&&row.source_ok;}
            check(seq.join(",")==="A1,B1,B2,A2" && correct,kind+" local ABBA keeps original result in all four timed blocks");
            check(unchanged,kind+" local ABBA leaves source objects unchanged");
         }
      }
      private function finish():void {
         removeEventListener(Event.ENTER_FRAME,next);
         if(assertions.length!==EXPECTED){failed++;assertions.push({passed:false,label:"expected "+EXPECTED+" assertions but got "+assertions.length});}
         var result:Object={passed:failed===0,failed:failed,assertions:assertions,benchmarks:benchmarks,
            expected:EXPECTED,elapsed_ms:getTimer()-started,native_game_test:false,performance_qualified:false,
            allocation_note:"One fewer fresh result Array per non-null blend call, inferred from source; elapsed ms are local ABBA only, not exact allocation or FPS."};
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify(result));f.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
