package
{
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObjectContainer;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;

   // Captures the actual tile drawn by Unit.blit through public texture/display APIs.
   // Stores tile coordinates, not one bitmap clone per history frame. Never disposes game textures.
   public class SandyBlitReplay
   {
      private var atlases:Dictionary = new Dictionary(true);

      public function SandyBlitReplay() { }

      public function reset():void { atlases = new Dictionary(true); }

      private function bodyBitmap(root:DisplayObjectContainer):Bitmap
      {
         if (root == null) return null;
         for (var i:int = 0; i < root.numChildren; i++)
         {
            var b:Bitmap = root.getChildAt(i) as Bitmap;
            if (b != null) return b;
            var child:DisplayObjectContainer = root.getChildAt(i) as DisplayObjectContainer;
            if (child != null)
            {
               b = bodyBitmap(child);
               if (b != null) return b;
            }
         }
         return null;
      }

      private function signature(data:BitmapData, x:int, y:int, w:int, h:int):String
      {
         var key:String = "";
         for (var iy:int = 1; iy <= 5; iy++)
            for (var ix:int = 1; ix <= 5; ix++)
               key += data.getPixel32(x + int(w * ix / 6), y + int(h * iy / 6)).toString(16) + ":";
         return key;
      }

      public function capture(unit:Object):Object
      {
         var result:Object = null;
         try
         {
            var atlas:BitmapData = unit.blitData as BitmapData;
            if (atlas == null) return null; // MovieClip player/NPC visuals keep their existing path.
            var b:Bitmap = bodyBitmap(unit.vis as DisplayObjectContainer);
            if (b == null || b.bitmapData == null) return null;
            var data:BitmapData = b.bitmapData;
            var w:int = data.width, h:int = data.height;
            if (w <= 0 || h <= 0 || atlas.width % w != 0 || atlas.height % h != 0) return null;
            var sizes:Object = atlases[atlas];
            if (sizes == null) { sizes = {}; atlases[atlas] = sizes; }
            var sizeKey:String = w + ":" + h;
            var index:Object = sizes[sizeKey];
            if (index == null)
            {
               index = {};
               sizes[sizeKey] = index;
               for (var row:int = 0; row < atlas.height / h; row++)
               {
                  for (var frame:int = 0; frame < atlas.width / w; frame++)
                  {
                     var key:String = signature(atlas, frame * w, row * h, w, h);
                     if (index[key] == null) index[key] = [];
                     index[key].push({ atlas: atlas, row: row, frame: frame, w: w, h: h });
                  }
               }
            }
            var candidates:Array = index[signature(data, 0, 0, w, h)];
            if (candidates == null) return null;
            // Sparse samples only filter candidates; full equality prevents pose/hash collisions.
            var actual:Vector.<uint> = data.getVector(data.rect);
            for each (var pose:Object in candidates)
            {
               var expected:Vector.<uint> = atlas.getVector(new Rectangle(pose.frame * w, pose.row * h, w, h));
               var equal:Boolean = true;
               for (var p:int = 0; p < actual.length; p++)
               {
                  if (actual[p] != expected[p]) { equal = false; break; }
               }
               if (equal) { result = pose; break; }
            }
         }
         catch (e:*) { }
         return result;
      }

      public function apply(unit:Object, pose:Object):Boolean
      {
         var applied:Boolean = false;
         try
         {
            if (pose != null && unit.blitData === pose.atlas)
            {
               unit.blit(pose.row, pose.frame);
               applied = true;
            }
         }
         catch (e:*) { }
         return applied;
      }
   }
}