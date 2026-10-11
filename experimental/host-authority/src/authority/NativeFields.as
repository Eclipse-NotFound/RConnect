package authority {
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   /** Only public scalar storage crosses this boundary, never native references. */
   public final class NativeFields {
      private static var schemas:Object={};
      private static const EXCLUDE:Object={in_chain:1,n:1};
      private static const ROOM:Object={active:1,visited:1,isRebuild:1,isRecalc:1,isRelight:1,relight_t:1};
      public static const MOTION:Array=["X","Y","X1","X2","Y1","Y2","eyeX","eyeY","celX","celY"];
      public static function capture(value:Object):Object {
         var out:Object={};if(value==null)return out;
         var key:String=getQualifiedClassName(value),names:Array=schemas[key];
         if(names==null) {
            names=[];
            for each(var field:XML in describeType(value).variable)
               if(!field.hasOwnProperty("@uri") && !EXCLUDE[String(field.@name)] &&
                  !(key=="fe.loc::Location" && ROOM[String(field.@name)]))names.push(String(field.@name));
            schemas[key]=names;
         }
         for each(var name:String in names) {
            var item:*=value[name];
            if(item is Number){if(isFinite(item))out[name]=item;}
            else if(item is String || item is Boolean)out[name]=item;
         }
         return out;
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
