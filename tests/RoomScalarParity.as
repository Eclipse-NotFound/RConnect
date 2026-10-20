package {
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   import rconnect.game.GameBridge;
   import rconnect.game.NativeRoomState;

   /** Read-only comparison with the former optional-read implementation.
    * Runs after scenario timing, on actual native tiles, units and weapons. */
   public class RoomScalarParity {
      private static const OMIT:Object={visible:1,alpha:1,visFrame:1,visDamDY:1,n:1,in_chain:1};
      private static var namesByClass:Object={};
      private static function simple(a:Array,depth:int=0):Boolean {
         if(depth>3 || a.length>1024)return false;
         for each(var v:* in a)
            if(v!=null && !(v is String) && !(v is Boolean) && !(v is Number)
               && !(v is Array && simple(v,depth+1)))return false;
         return true;
      }
      private static function before(o:Object):Object {
         var s:Object={},cls:String=getQualifiedClassName(o),names:Array=namesByClass[cls];
         if(names==null) {
            names=[];
            for each(var v:XML in describeType(o).variable)
               if(!OMIT[String(v.@name)] && !v.hasOwnProperty("@uri"))names.push(String(v.@name));
            namesByClass[cls]=names;
         }
         for each(var name:String in names) {
            var value:*=GameBridge.probe(o,name);
            if(value is Number){if(isFinite(Number(value)))s[name]=value;}
            else if(value is String || value is Boolean)s[name]=value;
            else if(value is Array && (name=="vulner" || name=="begvulner"))s[name]=NativeRoomState.numbers(value);
            else if(value is Array && simple(value))s[name]=JSON.parse(JSON.stringify(value));
         }
         return s;
      }
      private static function equal(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a is Number && b is Number && isNaN(a) && isNaN(b))return true;
         if(!(a is Array) || !(b is Array) || a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++)if(!equal(a[i],b[i]))return false;
         return true;
      }
      public static function run(world:Object):Object {
         var room:Object=world.loc,objects:Array=[],seen:Dictionary=new Dictionary();
         var count:int=int(room.spaceX)*int(room.spaceY),stride:int=Math.max(1,Math.ceil(count/256));
         for(var i:int=0;i<count;i+=stride)objects.push(room.space[int(i/int(room.spaceY))][i%int(room.spaceY)]);
         for each(var u:Object in room.units) {
            objects.push(u);var children:Array=GameBridge.probe(u,"childObjs") as Array;
            if(children!=null)for each(var child:Object in children)objects.push(child);
         }
         for each(var box:Object in room.objs){objects.push(box);objects.push(GameBridge.probe(box,"inter"));}
         var result:Object={objects:0,fields:0,classes:{},differences:[]};
         for each(var o:Object in objects) {
            if(o==null || seen[o])continue;seen[o]=true;
            var expected:Object=before(o),actual:Object=NativeRoomState.scalars(o),cls:String=getQualifiedClassName(o);
            result.objects++;result.classes[cls]=int(result.classes[cls])+1;
            var keys:Object={},key:String;
            for(key in expected)keys[key]=true;for(key in actual)keys[key]=true;
            for(key in keys) {
               result.fields++;
               if(expected.hasOwnProperty(key)!=actual.hasOwnProperty(key) || !equal(expected[key],actual[key]))
                  if(result.differences.length<8)result.differences.push(cls+"."+key);
            }
         }
         return result;
      }
   }
}
