package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.game.*;

   /** Full production ObjectIdentity before/after. Native GameBridge.probe is
    * the only dependency fixture. Timed classes contain no instrumentation. */
   public class UnitLookupChecks extends Sprite {
      private var assertions:Array=[],cases:Array=[],failed:int=0;
      private var measurements:Object={};
      public function UnitLookupChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function make(after:Boolean,indexed:Boolean=true):Object {
         return {identity:after?new ObjectIdentity("U"):new ObjectIdentityControl("U"),
            after:after,indexed:indexed,list:[],all:[],by:{},keys:[],used:new Dictionary(),
            members:null,steps:[],events:[],expected:true,inputs:true};
      }
      private function unit(f:Object,tag:String,id:String,x:Number=0,y:Number=0):LookupUnit {
         var u:LookupUnit=new LookupUnit(tag,id,x,y);f.all.push(u);f.by[tag]=u;return u;
      }
      private function key(f:Object,k:String):void {
         if(f.keys.indexOf(k)<0)f.keys.push(k);
      }
      private function bind(f:Object,k:String,u:Object):void {key(f,k);f.identity.bind(k,u);}
      private function members(list:Array):Dictionary {
         var result:Dictionary=new Dictionary();
         for(var i:int=0;i<list.length;i++)if(list[i]!=null)result[list[i]]=i;
         return result;
      }
      private function begin(f:Object):void {f.members=members(f.list);f.used=new Dictionary();}
      private function tags(list:Array):Array {
         if(list==null)return null;var out:Array=[];
         for each(var u:Object in list)out.push(u==null?null:u.tag);return out;
      }
      private function state(f:Object):Object {
         var objects:Array=[],lookups:Array=[];
         for each(var u:Object in f.all)objects.push([u.tag,f.identity.known(u),f.used[u]===true]);
         for each(var k:String in f.keys){var v:Object=f.identity.lookup(k);lookups.push([k,v==null?null:v.tag]);}
         return {list:tags(f.list),objects:objects,lookups:lookups,events:f.events.concat()};
      }
      private function resolve(f:Object,s:Object,label:String,expected:*):void {
         var before:String=JSON.stringify(s);if(s!=null && s.k!=null)key(f,String(s.k));
         var result:Object;
         if(f.after && f.indexed)result=f.identity.resolve(s,f.list,f.used,f.members);
         else result=f.identity.resolve(s,f.list,f.used);
         var name:*=result==null?null:result.tag;
         f.inputs=f.inputs && before===JSON.stringify(s);
         f.expected=f.expected && name===expected;
         f.steps.push({label:label,result:name,state:state(f)});
      }
      private function runCase(name:String,body:Function,indexed:Boolean=true):void {
         var a:Object=make(false,indexed),b:Object=make(true,indexed);
         GameBridge.record=true;GameBridge.reads=[];body(a);var readsA:Array=GameBridge.reads.concat();
         GameBridge.reads=[];body(b);var readsB:Array=GameBridge.reads.concat();
         check(JSON.stringify(a.steps)===JSON.stringify(b.steps),name+": every result/used/binding/list/callback state equal");
         check(JSON.stringify(readsA)===JSON.stringify(readsB),name+": probe side-effect order equal");
         check(a.expected && b.expected,name+": independently specified expected identities");
         check(a.inputs && b.inputs,name+": input snapshots not mutated");
         cases.push({name:name,before:a.steps,after:b.steps,probe_reads:readsA});
      }
      private function equivalence():void {
         runCase("bound key and repeated used key",function(f:Object):void {
            var a:Object=unit(f,"a","same",0),b:Object=unit(f,"b","same",5);
            f.list=[a,b];bind(f,"U1",a);begin(f);
            resolve(f,{k:"U1",id:"same",x:0,y:0},"bound","a");
            resolve(f,{k:"U1",id:"same",x:0,y:0},"used falls through to unbound","b");
            resolve(f,{k:"U1",id:"same",x:0,y:0},"all used",null);
         });
         runCase("bound key ignores id/cls exactly as old",function(f:Object):void {
            var a:Object=unit(f,"a","native");f.list=[a];bind(f,"U1",a);begin(f);
            resolve(f,{k:"U1",id:"other",cls:"different::Class",x:9999,y:9999},"bound","a");
         });
         runCase("preused target is not reusable",function(f:Object):void {
            var a:Object=unit(f,"a","native");f.list=[a];bind(f,"U1",a);begin(f);f.used[a]=true;
            resolve(f,{k:"U1",id:"native",x:0,y:0},"used",null);
         });
         runCase("remove cached target then reclaim",function(f:Object):void {
            var a:Object=unit(f,"a","same"),b:Object=unit(f,"b","same",3);
            f.list=[a,b];bind(f,"U1",a);begin(f);f.list.splice(0,1);
            resolve(f,{k:"U1",id:"same",x:0,y:0},"old object absent","b");
         });
         runCase("unshift shifts cached slot",function(f:Object):void {
            var a:Object=unit(f,"a","same"),b:Object=unit(f,"b","same",3);
            f.list=[a];bind(f,"U1",a);begin(f);f.list.unshift(b);
            resolve(f,{k:"U1",id:"same",x:0,y:0},"found at new index","a");
         });
         runCase("splice and reverse shifts",function(f:Object):void {
            var a:Object=unit(f,"a","a"),b:Object=unit(f,"b","b"),c:Object=unit(f,"c","c");
            f.list=[a,b,c];bind(f,"U1",a);bind(f,"U2",b);bind(f,"U3",c);begin(f);
            f.list.splice(1,1);f.list.reverse();
            resolve(f,{k:"U1",id:"a",x:0,y:0},"a moved","a");
            resolve(f,{k:"U2",id:"b",x:0,y:0},"b removed",null);
            resolve(f,{k:"U3",id:"c",x:0,y:0},"c moved","c");
         });
         runCase("replace target without changing length",function(f:Object):void {
            var a:Object=unit(f,"a","same"),b:Object=unit(f,"b","same",2);
            f.list=[a];bind(f,"U1",a);begin(f);f.list[0]=b;
            resolve(f,{k:"U1",id:"same",x:0,y:0},"replacement reclaimed","b");
         });
         runCase("append and bind after indexing",function(f:Object):void {
            var a:Object=unit(f,"a","a"),b:Object=unit(f,"b","b");
            f.list=[a];bind(f,"U1",a);begin(f);f.list.push(b);bind(f,"U2",b);
            resolve(f,{k:"U2",id:"b",x:0,y:0},"new member fallback","b");
            resolve(f,{k:"U1",id:"a",x:0,y:0},"old slot still valid","a");
         });
         runCase("duplicate object last-index hint becomes stale",function(f:Object):void {
            var a:Object=unit(f,"a","same"),b:Object=unit(f,"b","same",1);
            f.list=[a,a,b];bind(f,"U1",a);begin(f);f.list.splice(1,1);
            resolve(f,{k:"U1",id:"same",x:0,y:0},"first copy remains","a");
            resolve(f,{k:"U1",id:"same",x:0,y:0},"used excludes duplicated identity","b");
         });
         runCase("callback between resolves mutates array",function(f:Object):void {
            var a:Object=unit(f,"a","a"),b:Object=unit(f,"b","b"),c:Object=unit(f,"c","b",1);
            f.list=[a,b];bind(f,"U1",a);bind(f,"U2",b);begin(f);
            resolve(f,{k:"U1",id:"a",x:0,y:0},"before callback","a");
            var callback:Function=function():void {f.list[1]=c;f.events.push("native-style callback replaced b");};
            callback();
            resolve(f,{k:"U2",id:"b",x:0,y:0},"after callback","c");
         });
         runCase("getter callback mutates later bound member",function(f:Object):void {
            var a:LookupUnit=unit(f,"a","a"),b:Object=unit(f,"b","b"),c:Object=unit(f,"c","b",1);
            f.list=[a,b];bind(f,"U2",b);begin(f);
            a.onRead=function():void {f.list[1]=c;f.events.push("id getter replaced b");};
            resolve(f,{k:"U1",id:"a",x:0,y:0},"getter fires during fallback","a");
            resolve(f,{k:"U2",id:"b",x:0,y:0},"cached b rejected","c");
         });
         runCase("nearest unknown key plus tie order",function(f:Object):void {
            var a:Object=unit(f,"a","same",-10),b:Object=unit(f,"b","same",10);
            f.list=[a,b];begin(f);
            resolve(f,{k:"U7",id:"same",x:0,y:0},"equal distance keeps first","a");
            resolve(f,{k:"U8",id:"same",x:0,y:0},"second unclaimed","b");
         });
         runCase("unknown key cannot steal an already keyed body",function(f:Object):void {
            var a:Object=unit(f,"a","same",0),b:Object=unit(f,"b","same",20);
            f.list=[a,b];bind(f,"U1",a);begin(f);
            resolve(f,{k:"U9",id:"same",x:0,y:0},"nearest keyed excluded","b");
         });
         runCase("missing and empty key keep legacy claiming",function(f:Object):void {
            var a:Object=unit(f,"a","same",0),b:Object=unit(f,"b","same",20);
            f.list=[a,b];bind(f,"U1",a);begin(f);
            resolve(f,{id:"same",x:0,y:0},"missing key may use keyed body","a");
            resolve(f,{k:"",id:"same",x:0,y:0},"empty key next body","b");
         });
         runCase("class filtering and radius boundary",function(f:Object):void {
            var a:Object=unit(f,"a","same",150),b:Object=unit(f,"b","far",151);
            f.list=[a,b];begin(f);
            resolve(f,{k:"U1",id:"same",cls:"Object",x:0,y:0},"wrong class",null);
            resolve(f,{k:"U1",id:"same",cls:getQualifiedClassName(a),x:0,y:0},"150px accepted","a");
            resolve(f,{k:"U2",id:"far",x:0,y:0},"151px rejected",null);
         });
         runCase("null and empty inputs",function(f:Object):void {
            f.list=[];begin(f);resolve(f,null,"null snapshot",null);
            resolve(f,{k:"U1",id:"none",x:0,y:0},"empty array",null);
            f.list=null;resolve(f,{k:"U1",id:"none",x:0,y:0},"null array",null);
         });
         runCase("room restore and reset retain full class behavior",function(f:Object):void {
            var a:Object=unit(f,"a","a"),b:Object=unit(f,"b","b"),roomA:Object={},roomB:Object={};
            f.list=[a,b];f.identity.enter(roomA);bind(f,"U1",a);begin(f);
            resolve(f,{k:"U1",id:"a",x:0,y:0},"room a","a");
            f.identity.enter(roomB);bind(f,"U1",b);begin(f);
            resolve(f,{k:"U1",id:"b",x:0,y:0},"room b","b");
            f.identity.enter(roomA);begin(f);
            resolve(f,{k:"U1",id:"a",x:0,y:0},"restored a binding","a");
            f.identity.reset(roomA);begin(f);
            resolve(f,{k:"U1",id:"b",x:0,y:0},"reset permits new claim","b");
         });
         runCase("unknown caller default members null",function(f:Object):void {
            var a:Object=unit(f,"a","same"),b:Object=unit(f,"b","same",2);
            f.list=[a,b];bind(f,"U1",a);begin(f);f.list.reverse();
            resolve(f,{k:"U1",id:"same",x:0,y:0},"original API","a");
            resolve(f,{k:"U1",id:"same",x:0,y:0},"original fallback","b");
         },false);
      }

      private function density():Object {
         var list:Array=[],snapshots:Array=[];
         for(var i:int=0;i<136;i++) {
            list.push({tag:"u"+i,id:"enemy",X:i,Y:0});
            snapshots.push({k:"U"+(i+1),id:"enemy",x:i,y:0});
         }
         // Same scale as observed large-room units + local collision receivers.
         for(i=0;i<131;i++)list.push({tag:"proxy"+i,id:"proxy",X:i,Y:0});
         return {list:list,snapshots:snapshots};
      }
      private function bindDensity(identity:Object,d:Object):void {
         for(var i:int=0;i<136;i++)identity.bind("U"+(i+1),d.list[i]);
      }
      private function passes(identity:Object,d:Object,indexed:Boolean,count:int):Object {
         var start:int=getTimer(),checksum:Number=0;
         for(var pass:int=0;pass<count;pass++) {
            var used:Dictionary=new Dictionary(),index:Dictionary=indexed?members(d.list):null;
            for each(var s:Object in d.snapshots) {
               var result:Object=indexed?identity.resolve(s,d.list,used,index):identity.resolve(s,d.list,used);
               if(result==null)throw new Error("Density lost "+s.k);
               checksum+=Number(result.X);
            }
         }
         return {ms:getTimer()-start,checksum:checksum,passes:count,lookups:count*136,
            index_builds:indexed?count:0,index_entries_per_build:indexed?d.list.length:0};
      }
      private function counterChecks():void {
         GameBridge.record=false;
         var d:Object=density(),a:Object=new ObjectIdentityCountControl("U"),b:Object=new ObjectIdentityCountProposal("U");
         bindDensity(a,d);bindDensity(b,d);LookupCounters.reset();
         var ra:Object=passes(a,d,false,40),rb:Object=passes(b,d,true,40);
         check(ra.checksum===367200 && rb.checksum===367200,"136-unit x40 full passes preserve exact output checksum");
         check(LookupCounters.before===5440,"control executes 5440 actual native indexOf calls");
         check(LookupCounters.after===0,"indexed proposal executes zero native indexOf calls for intact membership");
         measurements.calls={before:LookupCounters.before,after:LookupCounters.after,passes:40,units:136,list_length:267};
         LookupCounters.reset();passes(b,d,false,1);
         check(LookupCounters.after===136,"unspecified index retains 136 native indexOf calls");
         LookupCounters.reset();
         var index:Dictionary=members(d.list),old:Object=d.list[0];
         d.list.unshift(d.list.pop());
         var resolved:Object=b.resolve(d.snapshots[0],d.list,new Dictionary(),index);
         check(resolved===old && LookupCounters.after===1,"stale slot invokes exactly one real indexOf fallback");
         LookupCounters.reset();index=members(d.list);
         var newUnit:Object={tag:"added",id:"enemy",X:777,Y:0};d.list.push(newUnit);b.bind("U777",newUnit);
         resolved=b.resolve({k:"U777",id:"enemy",x:777,y:0},d.list,new Dictionary(),index);
         check(resolved===newUnit && LookupCounters.after===1,"new member absent from index uses exactly one real fallback");
      }
      private function median(values:Array):Number {
         var a:Array=values.concat();a.sort(Array.NUMERIC);return (Number(a[2])+Number(a[3]))/2;
      }
      private function timing():void {
         GameBridge.record=false;
         var d:Object=density(),a:Object=new ObjectIdentityControl("U"),b:Object=new ObjectIdentity("U");
         bindDensity(a,d);bindDensity(b,d);
         passes(a,d,false,20);passes(b,d,true,20);
         var oldTimes:Array=[],newTimes:Array=[],trials:Array=[];
         for(var i:int=0;i<6;i++) {
            var ra:Object,rb:Object;
            if(i%2==0){ra=passes(a,d,false,200);rb=passes(b,d,true,200);}
            else {rb=passes(b,d,true,200);ra=passes(a,d,false,200);}
            oldTimes.push(ra.ms);newTimes.push(rb.ms);
            check(ra.checksum===1836000 && rb.checksum===1836000,"timing trial "+i+" exact identities/checksum");
            trials.push({order:i%2==0?"control-first":"proposal-first",control:ra,proposal:rb});
         }
         var oldMedian:Number=median(oldTimes),newMedian:Number=median(newTimes);
         measurements.directional={trials:trials,control_median_ms:oldMedian,proposal_median_ms:newMedian,
            ratio:oldMedian>0?newMedian/oldMedian:null,includes_index_allocation:true,
            instrumented:false,qualification:false,
            note:"Standalone lookup-only getTimer measurement; no game, no CPU isolation, no speed assertion."};
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {equivalence();counterChecks();timing();}
         catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,
            case_count:cases.length,cases:cases,measurements:measurements,
            native_game:false,tcp_socket:false,gamebridge_native_methods_tested:false,
            performance_qualified:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
