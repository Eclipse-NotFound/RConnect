package authority {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.geom.Point;

   /** Experimental B-side rendered-terrain cache.
    *
    * A keeps an unbaked input cache on one native Location.  B replaces the
    * Location on every authoritative room transition, so inputs alone cannot
    * reuse anything: the single Grafon has already rasterized another room.
    * This prototype retains the rendered native raster surfaces for a small
    * number of visited rooms.  A byte-identical authority state can then be
    * restored without Grafon.drawLoc, while contours, lighting, object layers,
    * camera and the independent ink stream are rebuilt through native methods.
    */
   public final class TerrainBitmapCache {
      public var hits:uint=0,stores:uint=0,evictions:uint=0;
      private static const LIMIT:int=2;
      private static const CONTOURS:Array=["kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4"];
      private static const STYLE:Array=["spaceX","spaceY","limX","limY","backwall","backform","darkness",
         "transpFon","tipWater","gas","homeStable","black","lightOn"];
      private var entries:Array=[];

      private static function surface(container:DisplayObjectContainer):BitmapData {
         if(container==null || container.numChildren==0)return null;
         var child:DisplayObject=container.getChildAt(0);
         var bitmap:Bitmap=child as Bitmap;
         return bitmap==null?null:bitmap.bitmapData;
      }
      private static function sameValues(a:Array,b:Array):Boolean {
         if(a==null || b==null || a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++) {
            if(a[i] is Array || b[i] is Array) {
               if(!(a[i] is Array) || !(b[i] is Array) || !sameValues(a[i] as Array,b[i] as Array))return false;
            }else if(a[i]!==b[i])return false;
         }
         return true;
      }
      private static function scalar(value:*):String {
         if(value==null)return "null";
         if(value is Array)return "array:"+value.join(",");
         return typeof value+":"+String(value);
      }
      private static function signature(s:Object):String {
         var out:Array=["key="+s.key,"fon="+s.fon,"tint="+scalar(s.tint),"fonTint="+scalar(s.fonTint)];
         for each(var name:String in STYLE)out.push(name+"="+scalar(s.fields[name]));
         return out.join("\u0001");
      }
      private static function contours(room:Object):Array {
         var out:Array=[];
         for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++) {
            var tile:Object=room.space[x][y],values:Array=[];
            for each(var name:String in CONTOURS)values.push(tile[name]);
            out.push(values);
         }
         return out;
      }
      private static function applyContours(room:Object,values:Array):void {
         var index:int=0;
         for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++) {
            var tile:Object=room.space[x][y],row:Array=values[index++];
            if(row==null)continue;
            for(var i:int=0;i<CONTOURS.length;i++)tile[CONTOURS[i]]=row[i];
         }
      }
      private static function transforms(value:Object):Array {
         return [value.x,value.y,value.scaleX,value.scaleY,value.rotation,value.alpha,value.visible];
      }
      private static function restoreTransform(value:Object,state:Array):void {
         if(state==null)return;
         value.x=state[0];value.y=state[1];value.scaleX=state[2];value.scaleY=state[3];
         value.rotation=state[4];value.alpha=state[5];value.visible=state[6];
      }
      private function find(s:Object,tiles:Array):Object {
         for each(var entry:Object in entries) {
            if(entry.key===s.key &&
               entry.signature===signature(s) &&
               VisualPose.recipeEqual(entry.backdrop,s.backdrop) &&
               sameValues(entry.tiles,tiles))return entry;
         }
         return null;
      }
      private function disposeEntry(entry:Object):void {
         for each(var bitmap:BitmapData in entry.surfaces)if(bitmap!=null)bitmap.dispose();
         entry.surfaces=null;entry.tiles=null;entry.contours=null;
      }

      /** Restore a cached raster into the current Grafon.  The caller has already
       * applied authoritative room fields, backdrops and tile values. */
      public function restore(s:Object,room:Object,renderer:Object,tiles:Array,worldBlack:Boolean):Boolean {
         var entry:Object=find(s,tiles);
         if(entry==null) {
            var keyMatch:Boolean=false,signatureMatch:Boolean=false,backdropMatch:Boolean=false,tilesMatch:Boolean=false;
            for each(var candidate:Object in entries) {
               if(candidate.key!==s.key)continue;
               keyMatch=true;signatureMatch=candidate.signature===signature(s);backdropMatch=VisualPose.recipeEqual(candidate.backdrop,s.backdrop);
               tilesMatch=sameValues(candidate.tiles,tiles);
               Log.write("terrain-cache-miss",{key:s.key,keyMatch:keyMatch,signatureMatch:signatureMatch,
                  backdropMatch:backdropMatch,tilesMatch:tilesMatch,entries:entries.length});
               break;
            }
            if(!keyMatch)Log.write("terrain-cache-miss",{key:s.key,keyMatch:false,entries:entries.length});
            return false;
         }
         var names:Array=["visFront","visBack","visBack2","visVoda","visSats"];
         var targets:Array=[],lives:Array=[];
         for(var i:int=0;i<names.length;i++) {
            var target:BitmapData=entry.surfaces[i];
            var live:BitmapData=surface(renderer[names[i]] as DisplayObjectContainer);
            if(target==null || live==null || target.width!=live.width || target.height!=live.height)return false;
            targets.push(target);lives.push(live);
         }
         applyContours(room,entry.contours);
         renderer.loc=room;room.grafon=renderer;
         for(i=0;i<lives.length;i++) {
            live=lives[i];target=targets[i];
            live.lock();live.copyPixels(target,target.rect,new Point());live.unlock();
         }
         restoreTransform(renderer.ramT,entry.ram[0]);restoreTransform(renderer.ramB,entry.ram[1]);
         restoreTransform(renderer.ramL,entry.ram[2]);restoreTransform(renderer.ramR,entry.ram[3]);
         renderer.setLight();renderer.visLight.visible=room.black && worldBlack;renderer.warShadow();
         renderer.drawAllObjs();++hits;
         return true;
      }

      /** Retain the raster produced by a real drawLoc, before ink is applied. */
      public function store(s:Object,room:Object,renderer:Object,tiles:Array):void {
         var names:Array=["visFront","visBack","visBack2","visVoda","visSats"];
         var surfaces:Array=[];
         for each(var property:String in names) {
            var source:BitmapData=surface(renderer[property] as DisplayObjectContainer);
            surfaces.push(source==null?null:source.clone());
         }
         var candidate:Object={key:s.key,signature:signature(s),backdrop:s.backdrop,tiles:tiles.concat(),
            contours:contours(room),surfaces:surfaces,
            ram:[transforms(renderer.ramT),transforms(renderer.ramB),transforms(renderer.ramL),transforms(renderer.ramR)]};
         for(var i:int=entries.length-1;i>=0;i--) {
            if(entries[i].key===s.key) {
               disposeEntry(entries[i]);entries.splice(i,1);
            }
         }
         while(entries.length>=LIMIT) {
            disposeEntry(entries[0]);entries.shift();++evictions;
         }
         entries.push(candidate);++stores;
      }

      public function dispose():void {
         for each(var entry:Object in entries)disposeEntry(entry);
         entries=[];hits=stores=evictions=0;
      }
   }
}
