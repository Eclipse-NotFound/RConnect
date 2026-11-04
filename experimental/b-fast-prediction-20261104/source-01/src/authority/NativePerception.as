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
   var fallback:Object=null,fallbackScore:Number=Number.POSITIVE_INFINITY;
   for each(var actor:PlayerActor in actors)if(saved.priorUnit===actor.unit)priorPlayer=true;
   // Preserve native retaliation against creatures/objects which are not players.
   if(saved.priorUnit!=null && !priorPlayer)return Boolean(unit.findCel(omni));
   try {
    for each(actor in actors)if(actor.unit.loc===unit.loc && actor.unit.hp>0 && !actor.unit.disabled) {
     restore(unit,saved);
     if(saved.priorUnit!==actor.unit)unit.priorUnit=null;
     var prepared:Object=capture(unit);
     var found:Boolean=Boolean(scope.run(actor.context,function():Boolean {return Boolean(unit.findCel(omni));}));
     var data:Object=capture(unit);
     if(!found) {
      // Native false does not mean "forget everything": stun and an
      // ineligible candidate leave the old target untouched, while a quiet
      // sound can update the search position without identifying a target.
      // Keep one real native failure outcome, preferring the existing target
      // and then the nearer candidate. Undo only our temporary prior filter
      // when the native method made no changes at all.
      var changed:Boolean=false;
      for each(var key:String in TARGET_FIELDS)if(data[key]!==prepared[key])changed=true;
      var failureScore:Number=Math.pow(actor.unit.X-unit.X,2)+Math.pow(actor.unit.Y-unit.Y,2);
      if(actor.unit===saved.priorUnit)failureScore-=10000000;
      else if(actor.unit===saved.celUnit)failureScore-=1000000;
      if(failureScore<fallbackScore){fallback=changed?data:saved;fallbackScore=failureScore;}
      continue;
     }
     var score:Number=unit.celUnit==null?100000000:Math.pow(actor.unit.X-unit.X,2)+Math.pow(actor.unit.Y-unit.Y,2);
     if(unit.celUnit===saved.priorUnit && saved.priorUnit!=null)score-=10000000;
     else if(unit.celUnit===saved.celUnit && saved.celUnit!=null)score-=1000000;
     if(score<bestScore){best={data:data};bestScore=score;}
    }
   }catch(error:*){restore(unit,saved);throw error;}
   if(best!=null){restore(unit,best.data);return true;}
   restore(unit,fallback==null?saved:fallback);return false;
  }
 }
}
