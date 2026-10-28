package {
 import flash.system.ApplicationDomain;
 import flash.utils.ByteArray;
 import flash.utils.Dictionary;
 /** Actual loaded decoder versus the frozen root-walking decoder. Tests use
  * independent AMF copies so a write in one decoder cannot help the other. */
 public final class BDeltaPrefixChecks {
  private static var Type:Class;
  private static function copy(value:*):* {var bytes:ByteArray=new ByteArray();bytes.writeObject(value);bytes.position=0;return bytes.readObject();}
  private static function freeze(value:*,seen:Dictionary=null):* {
   if(value==null || typeof(value)!="object")return value;
   if(seen==null)seen=new Dictionary();
   if(seen[value]!==undefined)return seen[value];
   var out:Object=value is Array?[]:value is ByteArray?new ByteArray():{};seen[value]=out;
   if(value is ByteArray){ByteArray(out).writeBytes(value);return out;}
   if(value is Array)out.length=value.length;
   for(var key:String in value)out[key]=freeze(value[key],seen);
   return out;
  }
  private static function same(a:*,b:*,left:Dictionary=null,right:Dictionary=null):Boolean {
   if(a is Number && b is Number)return isNaN(a)?isNaN(b):a===b && (a!==0 || 1/a===1/b);
   if(a===b)return true;
   if(a==null || b==null || typeof(a)!="object" || typeof(b)!="object" || (a is Array)!=(b is Array))return false;
   if(left==null){left=new Dictionary();right=new Dictionary();}
   if(left[a]!==undefined)return left[a]===b;
   if(right[b]!==undefined)return false;
   left[a]=b;right[b]=a;
   if(a is ByteArray || b is ByteArray) {
    if(!(a is ByteArray) || !(b is ByteArray) || a.length!=b.length)return false;
    for(var index:int=0;index<a.length;index++)if(a[index]!==b[index])return false;
    return true;
   }
   if(a is Array && a.length!=b.length)return false;
   for(var key:String in a)if(!b.hasOwnProperty(key) || !same(a[key],b[key],left,right))return false;
   for(key in b)if(!a.hasOwnProperty(key))return false;
   return true;
  }
  private static function exercise(seed:Object,batches:Array,check:Function,label:String,verify:Function=null):void {
   var actual:Object=new Type(),reference:BDeltaReferenceChecks=new BDeltaReferenceChecks();
   var history:Array=[],frozen:Array=[],expectedHistory:Array=[],expectedFrozen:Array=[];
   var packet:Object={base:0,serial:1,full:seed},result:Object,expected:Object;
   var equivalent:Boolean=true,immutable:Boolean=true,serial:int=1;
   for(var at:int=-1;at<batches.length;at++) {
    if(at>=0)packet={base:serial,serial:++serial,changes:batches[at]};
    result=actual.decode(copy(packet));expected=reference.decode(copy(packet));
    equivalent=equivalent && same(result,expected);
    for(var i:int=0;i<history.length;i++)immutable=immutable && same(history[i],frozen[i]) && same(expectedHistory[i],expectedFrozen[i]);
    // AMF turns some array holes into explicit undefined entries. Preserve
    // the actual returned graph for historical immutability assertions.
    history.push(result);frozen.push(freeze(result));expectedHistory.push(expected);expectedFrozen.push(freeze(expected));
   }
   check(equivalent,"delta prefix: value and alias graph equal to uncached reference: "+label);
   check(immutable,"delta prefix: all previous confirmations remain immutable: "+label);
   if(verify!=null)check(Boolean(verify(result)),"delta prefix: independent final-state expectation: "+label);
  }
  public static function run(domain:ApplicationDomain,check:Function):void {
   Type=domain.getDefinition("authority.FrameDelta") as Class;
   var shared:Object={child:{x:1,y:2}};
   exercise({a:shared,b:shared},[
    [[['a','child'],2,{x:10},null],[['b','child'],2,{y:20},null]],
    [[['a','child'],2,{z:30},['y']],[['b','child'],2,{z:40},null]]
   ],check,"AMF aliases split by parent path",function(v:Object):Boolean{return v.a!==v.b && v.a.child!==v.b.child && v.a.child.x==10 && !v.a.child.hasOwnProperty('y') && v.b.child.x==1 && v.b.child.y==20;});

   exercise({room:{unit:{hp:100,stats:{xp:1}}}},[
    [[['room','unit'],2,{hp:80,temp:1},null],[['room','unit','stats'],2,{xp:99},null],
     [['room','unit'],2,null,['stats']],[['room','unit','stats'],1,{xp:7}],
     [['room','unit','stats'],2,{xp:8},null]]
   ],check,"grouped ancestor deletion and reconstruction",function(v:Object):Boolean{return v.room.unit.hp==80 && v.room.unit.stats.xp==8;});

   exercise({room:{units:[{pose:{x:0,y:0}}]}},[
    [[['room','units',0,'pose'],2,{x:20},null],[['room','units'],1,[{pose:{x:40,y:50}}]],
     [['room','units',0,'pose'],2,{x:60},null],[['room','units',0,'pose','y'],1,70]]
   ],check,"ancestor array replacement invalidates deeper prefix",function(v:Object):Boolean{return v.room.units.length==1 && v.room.units[0].pose.x==60 && v.room.units[0].pose.y==70;});

   exercise({old:{a:{x:1}}},[
    [[['old','a'],2,{x:2},null],[[],1,{room:{a:{x:8}},tag:'new'}],
     [['room','a'],2,{x:9},null],[[],2,{flag:true},['tag']],[['room','a','x'],1,10]]
   ],check,"root replacement and root grouped edit",function(v:Object):Boolean{return !v.hasOwnProperty('old') && !v.hasOwnProperty('tag') && v.flag===true && v.room.a.x==10;});

   exercise({room:{a:{x:1,y:2},b:{x:3,y:4}}},[
    [[['room','a','x'],1,10],[['room','b','x'],1,20],[['room','a','x'],1,30],
     [['room','a','y'],0],[['room','a','y'],1,40],[['room','b'],2,{x:50},['y']]]
   ],check,"alternating siblings and repeated fields",function(v:Object):Boolean{return v.room.a.x==30 && v.room.a.y==40 && v.room.b.x==50 && !v.room.b.hasOwnProperty('y');});

   var sparse:Array=[];sparse[2]={pose:{x:2}};sparse[5]={pose:{x:5}};
   exercise({items:sparse},[
    [[['items',0],0],[['items',2,'pose'],2,{x:20},null],[['items','5','pose'],2,{x:50},null],
     [['items'],2,{length:3},null],[['items',2,'pose','x'],1,22],
     [['items',4],1,{pose:{x:44}}],[['items','4','pose'],2,{y:45},null]]
   ],check,"sparse arrays length changes and numeric/string path keys",function(v:Object):Boolean{return v.items.length==5 && !(0 in v.items) && v.items[2].pose.x==22 && v.items[4].pose.y==45;});

   var bytes:ByteArray=new ByteArray();bytes.writeByte(7);bytes.writeByte(9);
   exercise({room:{a:{surface:null},b:{surface:null}}},[
    [[['room','a'],2,{surface:bytes},null],[['room','b'],2,{surface:bytes},null]],
    [[['room','a'],2,{visible:false},null],[['room','b','surface'],0]]
   ],check,"shared byte payload and later removal",function(v:Object):Boolean{return v.room.a.surface is ByteArray && v.room.a.surface[0]==7 && !v.room.b.hasOwnProperty('surface');});

   var batches:Array=[];
   for(var n:int=0;n<200;n++) {
    var pair:Object={pose:{x:n,y:n+1},fields:{hp:n+2}};
    batches.push([
     [[],2,{units:[pair,pair]},null],
     [['units',0,'pose'],2,{x:n+10},null],[['units',0,'fields'],2,{hp:n+20},null],
     [['units',1,'pose'],2,{y:n+30},null],
     [['units',0],2,{pose:{x:n+40,y:n+50}},null],[['units',0,'pose'],2,{x:n+60},['y']],
     [['units',1,'fields','hp'],1,n+70]
    ]);
   }
   exercise({units:[]},batches,check,"200 packets of mixed shared-prefix and ancestor writes",function(v:Object):Boolean{return v.units[0].pose.x==259 && !v.units[0].pose.hasOwnProperty('y') && v.units[1].pose.y==229 && v.units[1].fields.hp==269;});

   var decoder:Object=new Type(),old:BDeltaReferenceChecks=new BDeltaReferenceChecks(),seed:Object={base:0,serial:1,full:{node:{v:1}}};
   decoder.decode(copy(seed));old.decode(copy(seed));
   var first:String="",second:String="";
   try{decoder.decode({base:0,serial:2,changes:[]});}catch(e:Error){first=e.message;}
   try{old.decode({base:0,serial:2,changes:[]});}catch(f:Error){second=f.message;}
   var valid:Object={base:1,serial:2,changes:[[['node'],2,{v:2},null]]};
   check(first=="Confirmation delta sequence gap" && first==second && same(decoder.decode(copy(valid)),old.decode(copy(valid))),
    "delta prefix: sequence rejection preserves the next valid packet");
  }
 }
}
