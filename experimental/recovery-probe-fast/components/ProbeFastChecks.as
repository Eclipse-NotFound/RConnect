package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.sampler.*;
   import flash.utils.*;
   import fe.Pt;
   import fe.unit.Unit;
   import fe.serv.Interact;
   import fe.weapon.*;
   import probecheck.*;

   /** Algorithms are extracted from real old/new GameBridge. Native classes
    * are sealed slot/hierarchy fixtures, not the game or other mods. */
   public class ProbeFastChecks extends Sprite {
      private var checks:Array=[],failed:int=0,sink:*,benchmarks:Array=[];
      private var objectValue:Object={identity:"same reference"};
      private var arrayValue:Array=[1,2];
      public function ProbeFastChecks() {addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function same(a:*,b:*):Boolean {
         if(a is Number && b is Number) {
            if(isNaN(a)&&isNaN(b))return true;
            if(a==0&&b==0)return 1/Number(a)==1/Number(b);
         }
         return a===b;
      }
      private function compare(o:Object,name:String,label:String):void {
         var old:*=ProbeBefore.probe(o,name),fresh:*=ProbeAfter.probe(o,name);
         check(same(old,fresh),label+" / "+name);
      }
      private function slots(o:Object,names:Array,label:String):void {
         var types:Object={};
         for each(var node:XML in describeType(o).variable)types[String(node.@name)]=String(node.@type);
         for each(var name:String in names) {
            var type:String=types[name],values:Array;
            if(type=="Number")values=[NaN,0,-1/Number.POSITIVE_INFINITY,1.25,Infinity,-Infinity];
            else if(type=="int")values=[-7,0,2147483647];
            else if(type=="uint")values=[0,uint.MAX_VALUE];
            else if(type=="Boolean")values=[false,true];
            else if(type=="String")values=[null,"","fixture"];
            else if(type=="Array")values=[null,arrayValue];
            else values=[null,objectValue];
            check(type!=null,label+" declares public variable "+name);
            for(var i:int=0;i<values.length;i++) {
               o[name]=values[i];compare(o,name,label+" value "+i);
            }
         }
      }
      private function sideEffects(factory:Function,name:String,label:String):void {
         var a:Object=factory(),b:Object=factory();
         var left:*=ProbeBefore.probe(a,name),right:*=ProbeAfter.probe(b,name);
         check(same(left,right),label+" result");
         check(JSON.stringify(a.traceCalls)==JSON.stringify(b.traceCalls),label+" exact access order/count");
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {
            slots(new Weapon(),FieldLists.WEAPON,"Weapon");
            slots(new Bullet(),FieldLists.BULLET,"Bullet");
            slots(new PhisBullet(),FieldLists.BULLET,"PhisBullet inherited slots");
            slots(new SmartBullet(),FieldLists.BULLET,"SmartBullet inherited slots");
            var dynamicWeapon:Object=new DynamicWeapon();dynamicWeapon.extension=71;
            compare(dynamicWeapon,"extension","dynamic subclass extension");
            compare(dynamicWeapon,"hold","dynamic subclass inherited fixed slot");
            compare(new Weapon(),"is_attack","internal member remains inaccessible");
            compare(new Bullet(),"expl_t","internal member remains inaccessible");
            compare(new Weapon(),"missing","missing sealed property");
            compare(new Bullet(),null,"null property name");
            compare(null,"owner","null object");
            var plain:Object={owner:undefined,b:null,hold:17,babah:NaN};
            for each(var key:String in ["owner","b","hold","babah","missing"])compare(plain,key,"plain object remains generic");
            sideEffects(function():Object{return new OptionalWeapon();},"unknownGetter","Weapon subclass throwing getter");
            sideEffects(function():Object{return new OptionalWeapon();},"returnsUndefined","Weapon subclass undefined getter");
            sideEffects(function():Object{return new SlotImpostor();},"hold","same field name on unrelated getter");
            sideEffects(function():Object{return new SlotImpostor();},"babah","same field name on unrelated throwing getter");
            sideEffects(function():Object{return new OtherPoint();},"hold","Pt is not proof of Weapon slots");
            sideEffects(function():Object{return new ThrowingDisplay();},"width","overridable DisplayObject getter");
            for each(var mode:String in ["value","missing","has-throws","get-throws","undefined"]) {
               // Copy the mode for each immediate factory invocation.
               var current:String=mode;
               for each(key in ["owner","hold","babah","X","unknown"]) {
                  sideEffects(function():Object{return new ReadProxy(current);},key,"Proxy "+mode+" / "+key);
               }
            }
            // Existing fast paths remain semantically identical too.
            slots(new Unit(),["X","hp","sost","currentWeapon"],"existing Unit path");
            slots(new Pt(),["X","dx","loc","vis"],"existing Pt path");
            slots(new Interact(),["owner","action","userAction"],"existing Interact path");
            var config:File=File.applicationDirectory.resolvePath("benchmark-enabled.txt");
            if(config.exists && failed==0)benchmark();
         }catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,checks:checks,benchmarks:benchmarks,
            realProbeBodies:true,nativeWorld:false,productionTiming:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function run(probe:Function,rows:Array,n:int):int {
         var at:int=getTimer();
         for(var i:int=0;i<n;i++){var row:Array=rows[i%rows.length];sink=probe(row[0],row[1]);}
         return getTimer()-at;
      }
      private function allocations(probe:Function,rows:Array):Object {
         clearSamples();sampleInternalAllocs(false);startSampling();run(probe,rows,20000);pauseSampling();
         var count:int=0,bytes:Number=0,types:Object={};
         for each(var sample:Sample in getSamples())if(sample is NewObjectSample) {
            var alloc:NewObjectSample=sample as NewObjectSample;count++;bytes+=alloc.size;
            var name:String=alloc.type==null?"unknown":getQualifiedClassName(alloc.type);
            types[name]=int(types[name])+1;
         }
         stopSampling();clearSamples();return {count:count,bytes:bytes,types:types};
      }
      /** Explicit opt-in only. No pass threshold is inferred from a microbench.
       * Six paired orders and adverse paths prevent an all-hit-only result. */
      private function benchmark():void {
         var w:Weapon=new Weapon(),b:Bullet=new Bullet(),u:Unit=new Unit(),point:Pt=new Pt(),display:Sprite=new Sprite();
         var nativeRows:Array=[],existingRows:Array=[[u,"hp"],[point,"X"],[point,"loc"]];
         for each(var key:String in FieldLists.WEAPON)nativeRows.push([w,key]);
         for each(key in FieldLists.BULLET)nativeRows.push([b,key]);
         var genericRows:Array=[[display,"width"],[display,"missing"],[{hold:1},"hold"],[{x:2},"missing"]];
         var proxyRows:Array=[[new ReadProxy("value",false),"hold"],[new ReadProxy("missing",false),"owner"]];
         var pointMissRows:Array=[[u,"missing"],[point,"hold"],[w,"missing"],[b,"missing"]];
         var sets:Array=[{name:"native slots",rows:nativeRows},{name:"existing fast slots",rows:existingRows},
            {name:"generic/display misses",rows:genericRows},{name:"Proxy protected",rows:proxyRows},
            {name:"unmatched Pt path",rows:pointMissRows},
            {name:"mixed fixture, not measured game weights",rows:nativeRows.concat(existingRows,genericRows,proxyRows,pointMissRows)}];
         for each(var set:Object in sets) {
            run(ProbeBefore.probe,set.rows,10000);run(ProbeAfter.probe,set.rows,10000);
            var data:Object={name:set.name,iterations:60000,pairs:[]};
            for(var pass:int=0;pass<6;pass++) {
               var pair:Object={order:pass%2==0?"before-after":"after-before"};
               if(pass%2==0){pair.beforeMs=run(ProbeBefore.probe,set.rows,60000);pair.afterMs=run(ProbeAfter.probe,set.rows,60000);}
               else{pair.afterMs=run(ProbeAfter.probe,set.rows,60000);pair.beforeMs=run(ProbeBefore.probe,set.rows,60000);}
               data.pairs.push(pair);
            }
            data.allocBefore=allocations(ProbeBefore.probe,set.rows);data.allocAfter=allocations(ProbeAfter.probe,set.rows);
            benchmarks.push(data);
         }
      }
   }
   internal dynamic class DynamicWeapon extends Weapon {}
   internal class OptionalWeapon extends Weapon {
      public var traceCalls:Array=[];
      public function get unknownGetter():* {traceCalls.push("get unknownGetter");throw new Error("fixture getter");}
      public function get returnsUndefined():* {traceCalls.push("get returnsUndefined");return undefined;}
   }
   internal class SlotImpostor {
      public var traceCalls:Array=[];
      public function get hold():int {traceCalls.push("get hold");return 17;}
      public function get babah():Boolean {traceCalls.push("get babah");throw new Error("fixture getter");}
   }
   internal class OtherPoint extends Pt {
      public var traceCalls:Array=[];
      public function get hold():* {traceCalls.push("get hold");throw new Error("not a Weapon");}
   }
   internal class ThrowingDisplay extends Sprite {
      public var traceCalls:Array=[];
      override public function get width():Number {traceCalls.push("get width");throw new Error("overridden getter");}
   }
   internal dynamic class ReadProxy extends Proxy {
      private var mode:String;
      private var track:Boolean;
      public var traceCalls:Array=[];
      public function ReadProxy(value:String,record:Boolean=true){mode=value;track=record;}
      override flash_proxy function hasProperty(name:*):Boolean {
         if(track)traceCalls.push("has "+String(name));
         if(mode=="has-throws")throw new Error("fixture membership");
         return mode!="missing";
      }
      override flash_proxy function getProperty(name:*):* {
         if(track)traceCalls.push("get "+String(name));
         if(mode=="get-throws")throw new Error("fixture property");
         return mode=="undefined"?undefined:37;
      }
   }
}
