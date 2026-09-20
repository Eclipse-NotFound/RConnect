package rconnect.game
{
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;

   /** Room-scoped identities. Once paired, moving across another equal-id object
    *  must never change ownership. Host keys travel back in client reports. */
   public class ObjectIdentity
   {
      private var room:Object;
      private var keys:Dictionary = new Dictionary();
      private var objects:Object = {};
      private var serial:int = 0;
      private var prefix:String;

      public function ObjectIdentity(prefix:String = "B") { this.prefix = prefix; }

      public function reset(next:Object = null):void
      {
         room = next;
         keys = new Dictionary();
         objects = {};
         serial = 0;
      }

      public function enter(next:Object):void
      {
         if(room !== next) reset(next);
      }

      public function key(o:Object):String
      {
         if(keys[o] == null)
         {
            var k:String = prefix + (++serial);
            keys[o] = k;
            objects[k] = o;
         }
         return String(keys[o]);
      }

      public function known(o:Object):String
      {
         return keys[o] == null ? "" : String(keys[o]);
      }

      public function bind(k:String, o:Object):void
      {
         objects[k] = o;
         keys[o] = k;
      }

      public function resolve(s:Object, list:Array, used:Dictionary):Object
      {
         if(s == null || list == null) return null;
         var k:String = s.k == null ? "" : String(s.k);
         var found:Object = k == "" ? null : objects[k];
         if(found != null && list.indexOf(found) >= 0 && used[found] != true)
         {
            used[found] = true;
            return found;
         }
         var best:Object;
         var distance:Number = 150 * 150 + 1;
         for each(var o:Object in list)
         {
            if(used[o] == true || (k != "" && keys[o] != null)) continue;
            if(String(GameBridge.probe(o, "id")) != String(s.id)) continue;
            if(s.cls != null && getQualifiedClassName(o) != String(s.cls)) continue;
            var dx:Number = Number(GameBridge.probe(o, "X")) - Number(s.x);
            var dy:Number = Number(GameBridge.probe(o, "Y")) - Number(s.y);
            var d:Number = dx * dx + dy * dy;
            if(d < distance) { best = o; distance = d; }
         }
         if(best != null)
         {
            used[best] = true;
            if(k != "") { objects[k] = best; keys[best] = k; }
         }
         return best;
      }
   }
}
