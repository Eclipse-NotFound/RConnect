package authority {
 /** Native findCel cadence and exposure rules, evaluated for each local native player. */
 public class NativePerception {
  private static const TARGET_FIELDS:Array=["celUnit","priorUnit","celX","celY","celDX","celDY"];
  private var scope:NativeScope,actors:Array;
  public function NativePerception(scope:NativeScope,actors:Array){this.scope=scope;this.actors=actors;}
  private function capture(unit:Object):Object {
   var data:Object={};for each(var key:String in TARGET_FIELDS)data[key]=unit[key];return data;
  }
  private function restore(unit:Object,data:Object):void {for each(var key:String in TARGET_FIELDS)unit[key]=data[key];}
  public function find(unit:Object,omni:Boolean):Boolean {
   var saved:Object=capture(unit),best:Object=null,bestScore:Number=Number.POSITIVE_INFINITY,priorPlayer:Boolean=false;
   for each(var actor:PlayerActor in actors)if(saved.priorUnit===actor.unit)priorPlayer=true;
   // Preserve native retaliation against creatures/objects which are not players.
   if(saved.priorUnit!=null && !priorPlayer)return Boolean(unit.findCel(omni));
   try {
    for each(actor in actors)if(actor.unit.loc===unit.loc && actor.unit.hp>0 && !actor.unit.disabled) {
     restore(unit,saved);
     if(saved.priorUnit!==actor.unit)unit.priorUnit=null;
     var found:Boolean=Boolean(scope.run(actor.context,function():Boolean {return Boolean(unit.findCel(omni));}));
     if(!found)continue;
     var data:Object=capture(unit);
     var score:Number=unit.celUnit==null?100000000:Math.pow(actor.unit.X-unit.X,2)+Math.pow(actor.unit.Y-unit.Y,2);
     if(unit.celUnit===saved.priorUnit && saved.priorUnit!=null)score-=10000000;
     else if(unit.celUnit===saved.celUnit && saved.celUnit!=null)score-=1000000;
     if(score<bestScore){best={data:data};bestScore=score;}
    }
   }catch(error:*){restore(unit,saved);throw error;}
   if(best!=null){restore(unit,best.data);return true;}
   restore(unit,saved);unit.celUnit=null;unit.priorUnit=null;return false;
  }
 }
}
