package authority {
 import flash.utils.getTimer;
 import flash.utils.ByteArray;
 /** Explicit fieldProfile only. Real-object, alternating-order cost and equality checks. */
 public final class AlgorithmProfile {
  public static function run(access:NativeAccess,check:Function):void {
   var enabled:Boolean=Timing.enabled;Timing.enabled=false;
   try {transitions(check);fields(access,check);terrain(access,check);}finally{Timing.enabled=enabled;}
  }
  private static function copy(v:Object):Object {var b:ByteArray=new ByteArray();b.writeObject(v);b.position=0;return b.readObject();}
  private static function transitions(check:Function):void {
   var unit:FieldProbeState=new FieldProbeState(),retained:Array=[],saved:Array=[],values:Array=[0,1,-2,NaN,Infinity,-Infinity,null,undefined,true,false,"", "beam",{},[],new FieldProbeState()];
   var equal:Boolean=true;
   for(var i:int=0;i<180;i++) {
    unit.optional=values[i%values.length];unit.nativeReference=values[(i*7)%values.length];unit.X=i%17==0?NaN:i;unit.hp=i%19==0?Infinity:100-i;unit.label=i%3==0?null:String(i);
    var old:Object=NativeFields.capture(unit),now:Object=AlternativeFields.capture(unit);
    if(!VisualPose.recipeEqual(old,now))equal=false;
    retained.push(now);saved.push(copy(now));
    if(now!==AlternativeFields.capture(unit))equal=false;
   }
   for(i=0;i<retained.length;i++)if(!VisualPose.recipeEqual(retained[i],saved[i]))equal=false;
   check(equal,"alternative scalar reader preserves type transitions, finite-number exclusions and old confirmations",{steps:180});
   var tile:Object={},before:Array;for each(var name:String in SceneSnapshot.TILE)tile[name]=0;
   before=TerrainScan.capture(tile,null);equal=VisualPose.recipeEqual(before,oldTile(tile,null));
   retained=[before];saved=[before.concat()];
   for each(name in SceneSnapshot.TILE)for each(var value:* in [1,-1,0,true,false,"", "door",null,undefined,NaN,Infinity]) {
    tile[name]=value;var next:Array=TerrainScan.capture(tile,before),reference:Array=oldTile(tile,before);
    for(i=0;i<next.length;i++)if(next[i]!==reference[i] && !(next[i] is Number && reference[i] is Number && isNaN(next[i]) && isNaN(reference[i])))equal=false;
    retained.push(next);saved.push(copy(next));before=next;
   }
   for(i=0;i<retained.length;i++)for(var j:int=0;j<retained[i].length;j++) {
    var a:*=retained[i][j],b:*=saved[i][j];if(a!==b && !(a is Number && b is Number && isNaN(a) && isNaN(b)))equal=false;
   }
   check(equal,"direct terrain reads preserve all schema fields and retained arrays",{fields:SceneSnapshot.TILE.length,transitions:retained.length});
  }
  private static function oldTile(value:Object,before:Array):Array {
   var changed:Boolean=before==null;
   if(!changed)for(var i:int=0;i<SceneSnapshot.TILE.length;i++)if(value[SceneSnapshot.TILE[i]]!==before[i]){changed=true;break;}
   if(!changed)return before;
   var out:Array=[];for each(var name:String in SceneSnapshot.TILE)out.push(value[name]);return out;
  }
  private static function fields(access:NativeAccess,check:Function):void {
   var Type:Class=access.definition("fe.unit.UnitZombie"),units:Array=[];
   for(var i:int=0;i<80;i++)units.push(new Type("1",10,<unit tr="1" dig="0"/>,null));
   for each(var mode:String in ["stable","moving","alternating"]) {
    var before:Array=[],after:Array=[],equal:Boolean=true;
    for each(var u:Object in units){NativeFields.capture(u);AlternativeFields.capture(u);}
    for(var round:int=0;round<24;round++) {
     var old:Array=[],now:Array=[];
     if(round%2==0){before.push(fieldBatch(units,mode,round,true,old));after.push(fieldBatch(units,mode,round,false,now));}
     else {after.push(fieldBatch(units,mode,round,false,now));before.push(fieldBatch(units,mode,round,true,old));}
     for(i=0;i<units.length;i++)if(!VisualPose.recipeEqual(old[i],now[i]))equal=false;
    }
    check(equal,"alternative native fields equal B193: "+mode);
    Log.write("algorithm-profile",{algorithm:"scalar-typeof",mode:mode,calls:320,previous:before,current:after});
   }
  }
  private static function fieldBatch(units:Array,mode:String,round:int,old:Boolean,out:Array):int {
   var start:int=getTimer();
   for(var repeat:int=0;repeat<4;repeat++)for(var i:int=0;i<units.length;i++) {
    var u:Object=units[i];if(mode=="moving" || mode=="alternating" && round%2==0){u.X=400+i+round*4+repeat;u.eyeX=u.X+5;u.Y=800+i%4+repeat;u.eyeY=u.Y-30;u.dx=repeat%2?1:-1;u.dy=-u.dx;}
    out[i]=old?NativeFields.capture(u):AlternativeFields.capture(u);
   }return getTimer()-start;
  }
  private static function terrain(access:NativeAccess,check:Function):void {
   var values:Array=[];for each(var column:Array in access.world.loc.space)for each(var tile:Object in column)values.push(tile);
   check(values.length>=100,"terrain benchmark uses actual native room tiles",{tiles:values.length});
   for each(var mode:String in ["stable","full","changed-first","changed-last"]) {
    var before:Array=[],after:Array=[],prior:Array=[],equal:Boolean=true;
    for each(tile in values){var state:Array=oldTile(tile,null);if(mode=="changed-first")state[0]=!tile.phis;else if(mode=="changed-last")state[state.length-1]=!tile.indestruct;prior.push(state);}
    for(var round:int=0;round<24;round++) {
     var old:Array=[],now:Array=[];
     if(round%2==0){before.push(tileBatch(values,prior,mode,true,old));after.push(tileBatch(values,prior,mode,false,now));}
     else {after.push(tileBatch(values,prior,mode,false,now));before.push(tileBatch(values,prior,mode,true,old));}
     for(var i:int=0;i<values.length;i++)if(!VisualPose.recipeEqual(old[i],now[i]))equal=false;
    }
    check(equal,"direct native tile reader equals B193: "+mode);
    Log.write("algorithm-profile",{algorithm:"terrain-direct",mode:mode,calls:values.length*4,previous:before,current:after});
   }
  }
  private static function tileBatch(values:Array,prior:Array,mode:String,old:Boolean,out:Array):int {
   var start:int=getTimer();for(var repeat:int=0;repeat<4;repeat++)for(var i:int=0;i<values.length;i++)out[i]=old?oldTile(values[i],mode=="full"?null:prior[i]):TerrainScan.capture(values[i],mode=="full"?null:prior[i]);return getTimer()-start;
  }
 }
}
