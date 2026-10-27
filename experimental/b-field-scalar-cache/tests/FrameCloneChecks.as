package authority {
 import flash.utils.getTimer;
 public final class FrameCloneChecks {
  public static function run(unit:Object,check:Function):void {
   var sample:Object=NativeFields.capture(unit),units:Array=[];
   for(var j:int=0;j<80;j++) {
    var fields:Object={};for(var key:String in sample)fields[key]=sample[key];
    units.push({key:j,fields:fields,pose:{x:j,y:0,m:[1,0,0,1,j,0]}});
   }
   var packets:Array=[{serial:1,base:0,full:{scene:{units:units},tag:0}}];
   for(var i:int=1;i<=100;i++) {
    var changes:Array=[];
    for(j=0;j<80;j++) {
     var updates:Object={X:j+i*.5,Y:i%3,dx:i%7},removed:Array=null;
     if(i%11==0)updates.added=i;
     if(i%11==1)removed=["added"];
     changes.push([["scene","units",String(j),"fields"],2,updates,removed]);
     changes.push([["scene","units",String(j),"pose","m"],1,[1,0,0,1,j+i*.5,i%3]]);
    }
    changes.push([[],2,{tag:i},null]);packets.push({serial:i+1,base:i,changes:changes});
   }
   var old:ReferenceFrameDelta=new ReferenceFrameDelta(),fast:FrameDelta=new FrameDelta(),held:Array=[],texts:Array=[],same:Boolean=true;
   for each(var packet:Object in packets) {
    var a:Object=old.decode(packet),b:Object=fast.decode(packet);
    same=same && VisualPose.recipeEqual(a,b);
    if(packet.serial%20==1){held.push(b);texts.push(JSON.stringify(b));}
   }
   var immutable:Boolean=true;
   for(i=0;i<held.length;i++)immutable=immutable && JSON.stringify(held[i])===texts[i];
   check(same,"decoder shape reuse preserves every field across 80 units and key additions/removals",{frames:101,fieldsPerUnit:count(sample)});
   check(immutable,"decoder shape reuse never mutates old confirmations",{held:held.length});
   // Array length writes must invalidate the cached enumerable indices too.
   old=new ReferenceFrameDelta();fast=new FrameDelta();same=true;
   var cases:Array=[{serial:1,base:0,full:{a:[1,2,3]}},{serial:2,base:1,changes:[[["a"],2,{length:1},null]]},
    {serial:3,base:2,changes:[[["a"],2,{"0":9},null]]},{serial:4,base:3,changes:[[["a","3"],1,7]]},
    {serial:5,base:4,changes:[[["a","0"],0]]},{serial:6,base:5,changes:[[[],2,{a:{x:1}},null]]},
    {serial:7,base:6,changes:[[["a"],2,{x:2},null]]}];
   for each(packet in cases)same=same && VisualPose.recipeEqual(old.decode(packet),fast.decode(packet));
   check(same,"decoder cached shapes handle array shrink, sparse keys, deletion and type replacement");
   var rows:Array=[];
   for(var round:int=0;round<6;round++) {
    var referenceMs:int=0,candidateMs:int=0;
    for(var order:int=0;order<2;order++) {
     var reference:Boolean=(round+order)%2==0;
     old=new ReferenceFrameDelta();fast=new FrameDelta();var began:int=getTimer();
     for each(packet in packets){if(reference)a=old.decode(packet);else b=fast.decode(packet);}
     if(reference)referenceMs=getTimer()-began;else candidateMs=getTimer()-began;
    }
    rows.push({referenceMs:referenceMs,candidateMs:candidateMs,equal:VisualPose.recipeEqual(a,b)});
   }
   check(true,"native unit-shaped confirmation decoding micro timing (not gameplay FPS)",{frames:101,units:80,rows:rows});
  }
  private static function count(value:Object):int {var n:int=0;for(var k:String in value)++n;return n;}
 }
}
