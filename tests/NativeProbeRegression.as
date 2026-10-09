package {
   import flash.utils.describeType;
   import rconnect.game.GameBridge;

   /** Compare every public native player variable to the original probe. */
   public class NativeProbeRegression {
      private static function original(o:Object,name:String):* {
         if(o==null)return null;
         try {
            if(!(name in o))return null;
            var value:*=o[name];return value===undefined?null:value;
         } catch(error:*) {return null;}
         return null;
      }
      public static function run(check:Function,unit:Object,main:Object):void {
         var count:int=0,same:Boolean=true;
         for each(var field:XML in describeType(unit).variable) {
            var name:String=String(field.@name),expected:*=original(unit,name),actual:*=GameBridge.probe(unit,name);
            same=same && (actual===expected || actual is Number && expected is Number && isNaN(actual) && isNaN(expected));count++;
         }
         check(count>100 && same,"native probe matches original for all "+count+" public player variables");
         check(GameBridge.probe(unit,"rconnect_missing_field")==null && GameBridge.probe(unit,"aiState")==null,
            "native probe keeps absent and inaccessible fields null");
         var values:Object={missing:undefined,zero:0,off:false,empty:"",nil:null,nan:NaN};
         same=true;
         for(name in values) {
            expected=original(values,name);actual=GameBridge.probe(values,name);
            same=same && (actual===expected || actual is Number && expected is Number && isNaN(actual) && isNaN(expected));
         }
         check(same && GameBridge.probe(null,"X")==null,"optional probe preserves null undefined zero false empty and NaN");
         var throwing:Object=new ThrowingProbeField();
         check(GameBridge.probe(throwing,"X")==null && throwing.calls==1,"optional getter exceptions remain contained");
         check(GameBridge.probe(throwing,"width")==null && throwing.calls==2,
            "overridden native display getters retain exception protection");
         check(GameBridge.probe(unit,"toString") is Function,"prototype names cannot enter the native variable whitelist");
         var cls:Class=main.loaderInfo.applicationDomain.getDefinition("fe.Pt") as Class,point:Object=new cls();
         same=true;
         for each(name in ["loc","nobj","pobj","in_chain","stay","X","Y","sloy","dx","dy","vis"]) {
            expected=original(point,name);actual=GameBridge.probe(point,name);
            same=same && (actual===expected || actual is Number && expected is Number && isNaN(actual) && isNaN(expected));
         }
         check(same,"native point fields match for a non-Unit native instance");
         same=true;
         for each(name in ["x","y","width","height","scaleX","scaleY","rotation","alpha","visible",
            "parent","stage","mask","cacheAsBitmap","name","currentFrame","totalFrames","currentLabel","isPlaying"]) {
            expected=original(unit.vis,name);actual=GameBridge.probe(unit.vis,name);same=same && actual===expected;
         }
         check(same && GameBridge.probe(unit.vis,"rconnect_absent_child")==null,
            "native display and clip getters match and absent children remain null");
         var interactions:int=0;same=true;
         for each(var object:Object in unit.loc.objs) {
            var inter:Object=original(object,"inter");if(inter==null)continue;
            interactions++;
            for each(name in ["owner","action","prob","allact","userAction","scrAct","scrOpen","scrClose","scrTouch",
               "scrDie","scrAlarm","scrOver","scrOut","questId"]) {
               expected=original(inter,name);actual=GameBridge.probe(inter,name);same=same && actual===expected;
            }
         }
         check(interactions>0 && same,"native interaction script fields and absent fields match on "+interactions+" objects");
      }
   }
}
