package authority {
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   /** Only public scalar storage crosses this boundary, never native references. */
   public final class NativeFields {
      private static var schemas:Object={};
      private static var retained:Dictionary=new Dictionary(true),deltas:Dictionary=new Dictionary(true);
      // A variable declared as a display object, array or game class cannot
      // hold a scalar. Keep Object and *: native code can store scalars there.
      private static const SCALARS:Object={"int":1,"uint":1,"Number":1,"String":1,"Boolean":1,"Object":1,"*":1};
      private static const EXCLUDE:Object={in_chain:1,n:1};
      private static const ROOM:Object={active:1,visited:1,isRebuild:1,isRecalc:1,isRelight:1,relight_t:1};
      public static const MOTION:Array=["X","Y","X1","X2","Y1","Y2","eyeX","eyeY","celX","celY"];
      public static function capture(value:Object):Object {
         if(value==null)return {};
         var began:int=Timing.start();
         var record:Object=retained[value],previous:Object=record==null?null:record.state;
         // Moving units normally change every frame. Build their next record
         // during this one read instead of copying the entire previous record
         // after its first changed field. Stable objects keep the lazy path.
         var eager:Boolean=record!=null && record.changed;
         var out:Object=previous==null || eager?{}:null,updates:Object=null,removed:Array=null,changed:Boolean=false;
         var key:String=getQualifiedClassName(value),names:Array=schemas[key];
         if(names==null) {
            names=[];
            for each(var field:XML in describeType(value).variable)
               if(SCALARS[String(field.@type)] && !field.hasOwnProperty("@uri") && !EXCLUDE[String(field.@name)] &&
                  !(key=="fe.loc::Location" && ROOM[String(field.@name)]))names.push(String(field.@name));
            schemas[key]=names;
         }
         for each(var name:String in names) {
            var item:*=value[name];
            var scalar:Boolean=item is Number?isFinite(item):item is String || item is Boolean;
            if(scalar) {
               if(eager)out[name]=item;
               if(previous!=null && previous[name]===item)continue;
               changed=true;
               if(out==null)out=copy(previous);
               if(!eager)out[name]=item;
               if(updates==null)updates={};updates[name]=item;
            }else if(previous!=null && previous.hasOwnProperty(name)) {
               changed=true;
               if(out==null)out=copy(previous);
               delete out[name];if(removed==null)removed=[];removed.push(name);
            }
         }
         if(previous!=null && !changed){record.changed=false;Timing.end("capture.nativeFields",began);return previous;}
         if(record==null)retained[value]={state:out,changed:changed};
         else {record.state=out;record.changed=changed;}
         if(previous!=null) {
            // Weak provenance prevents a newest record from keeping the
            // entire previous-frame chain alive. The normal encoder retains
            // its own prior frame while it checks this exact baseline.
            var from:Dictionary=new Dictionary(true);from[previous]=true;
            deltas[out]={from:from,updates:updates,removed:removed};
         }
         Timing.end("capture.nativeFields",began);
         return out;
      }
      private static function copy(source:Object):Object {
         var result:Object={};for(var key:String in source)result[key]=source[key];return result;
      }
      /** Local hint only; never serialized and never substitutes another baseline. */
      public static function delta(before:Object,after:Object):Object {
         var hint:Object=deltas[after];return hint!=null && hint.from[before]===true?hint:null;
      }
      public static function apply(value:Object,state:Object):void {
         var room:Boolean=getQualifiedClassName(value)=="fe.loc::Location";
         for(var key:String in state)if(!EXCLUDE[key] && !(room && ROOM[key]) && key in value)value[key]=state[key];
      }
      public static function motion(value:Object,state:Object):void {
         for each(var key:String in MOTION)if(state[key] is Number && key in value)value[key]=state[key];
      }
   }
}
