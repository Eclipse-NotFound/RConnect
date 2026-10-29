package authority {
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   /** Only public scalar storage crosses this boundary, never native references. */
   public final class NativeFields {
      private static var schemas:Object={};
      private static var retained:Dictionary=new Dictionary(true),deltas:Dictionary=new Dictionary(true);
      private static var captureIds:Dictionary=new Dictionary(true);
      private static var nextCaptureId:Number=0;
      private static var applySchemas:Object={},applyObjects:Dictionary=new Dictionary(true);
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
         var schema:Object=record==null?null:record.schema;
         if(schema==null) {
            var key:String=getQualifiedClassName(value);schema=schemas[key];
            if(schema==null) {
               schema={names:new Vector.<String>(),modes:new Vector.<int>()};
               for each(var field:XML in describeType(value).variable) {
                  var type:String=String(field.@type),fieldName:String=String(field.@name);
                  if(SCALARS[type] && !field.hasOwnProperty("@uri") && !EXCLUDE[fieldName] &&
                     !(key=="fe.loc::Location" && ROOM[fieldName])) {
                     schema.names.push(fieldName);
                     // AS3 enforces primitive declarations. Only Object/* need
                     // repeated runtime type tests; Number still rejects NaN/Inf
                     // and String still rejects null exactly as before.
                     schema.modes.push(type=="int" || type=="uint" || type=="Boolean"?0:type=="String"?1:type=="Number"?2:3);
                  }
               }
               schemas[key]=schema;
            }
         }
         var names:Vector.<String>=schema.names,modes:Vector.<int>=schema.modes;
         var length:int=names.length;
         for(var index:int=0;index<length;index++) {
            var name:String=names[index],mode:int=modes[index];
            var item:*=value[name];
            var scalar:Boolean=mode==0 || (mode==1?item!=null:mode==2?isFinite(item):item is Number?isFinite(item):item is String || item is Boolean);
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
         if(record==null)retained[value]={state:out,changed:changed,schema:schema};
         else {record.state=out;record.changed=changed;}
         if(previous!=null) {
            // Weak provenance prevents a newest record from keeping the
            // entire previous-frame chain alive. The normal encoder retains
            // its own prior frame while it checks this exact baseline.
            var from:Number=Number(captureIds[previous]);
            if(!from){from=++nextCaptureId;captureIds[previous]=from;}
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
         var hint:Object=deltas[after];return hint!=null && captureIds[before]===hint.from?hint:null;
      }
      public static function apply(value:Object,state:Object):void {
         var schema:Object=applyObjects[value];
         if(schema==null) {
            var type:String=getQualifiedClassName(value);schema=applySchemas[type];
            if(schema==null) {
               schema={room:type=="fe.loc::Location",declared:{}};
               // A public storage slot cannot disappear from a native instance.
               // Cache only that proof, never its value: local view methods may
               // have changed the value since the previous confirmation.
               for each(var field:XML in describeType(value).variable) {
                  var name:String=String(field.@name);
                  if(!field.hasOwnProperty("@uri") && !EXCLUDE[name] && !(schema.room && ROOM[name]))schema.declared[name]=true;
               }
               applySchemas[type]=schema;
            }
            applyObjects[value]=schema;
         }
         var room:Boolean=schema.room,declared:Object=schema.declared;
         for(var key:String in state) {
            if(declared[key]===true) {
               // Only plain declared storage has no assignment side effect.
               // Compare the live value, not a prior packet, so interpolation
               // or local rendering changes are still restored immediately.
               // +0 and -0 compare strictly equal but are distinct numeric
               // values. Always write zero (and NaN naturally compares unequal).
               var incoming:*=state[key];if(value[key]!==incoming || incoming===0)value[key]=incoming;
            }else if(!EXCLUDE[key] && !(room && ROOM[key]) && key in value) {
               // Dynamic properties and accessors keep every original write,
               // including setter effects, errors and existence checks.
               value[key]=state[key];
            }
         }
      }
      public static function motion(value:Object,state:Object):void {
         for each(var key:String in MOTION)if(state[key] is Number && key in value)value[key]=state[key];
      }
   }
}
