package rconnect.game {
   import fe.loc.Tile;

   /** A synchronous checkpoint restore may change HP/vision without changing
    * the terrain picture. Compare its inputs before object reconciliation,
    * not after it has already changed doors and supporting tiles. Unsupported
    * inputs and pending native rebuilds retain the complete redraw path. */
   public class RoomTerrainView {
      private var room:Object,renderer:Object;
      private var width:int,height:int;
      private var rows:Array=[];
      private var contours:Array=[];
      private var style:Array;
      private var backdrops:Array=[];
      private var valid:Boolean=false;
      private static const STYLE:Array=["backwall","backform","darkness","transpFon","tipWater",
         "gas","homeStable","black","lightOn","limX","limY","color"];
      private static const BACKDROP:Array=["X","Y","scX","scY","alpha","blend","sloy","er",
         "vis","erase","light"];
      private static const CONTOURS:Array=["kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4"];
      // HP and vision are deliberately absent: the full checkpoint still
      // restores them, and refresh() updates the native light map separately.
      // Contours are derived from phis/back/shelf/door by tileKontur().
      private static function tileInputs(t:Object):Array {
         return [t.X,t.Y,t.phis,t.shelf,t.phX1,t.phX2,t.phY1,t.phY2,t.zForm,
            t.diagon,t.stair,t.water,t.vid,t.vid2,t.front,t.back,t.zad,
            t.fRear,t.vRear,t.v2Rear,t.opac,t.mat,t.kontur,t.konturRot,t.floor,
            t.place,t.fake,t.door!=null];
      }
      private static function fields(o:Object,names:Array):Array {
         var out:Array=[];for each(var n:String in names)out.push(o[n]);return out;
      }
      private static function same(a:Array,b:Array):Boolean {
         if(a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++)if(a[i]!==b[i])return false;
         return true;
      }
      private static function colors(loc:Object):Array {
         var out:Array=[];
         for each(var name:String in ["cTransform","cTransformFon"]) {
            var c:Object=loc[name];
            out.push(c==null?null:c.toString());
         }
         return out;
      }
      public function RoomTerrainView(loc:Object) {
         try {
            room=loc;renderer=loc.grafon;width=int(loc.spaceX);height=int(loc.spaceY);
            if(renderer==null || renderer.loc!==loc || loc.isRebuild || loc.isRecalc
               || width<1 || height<1 || width>512 || height>256)return;
            style=fields(loc,STYLE).concat(colors(loc));
            for each(var b:Object in loc.backobjs)
               backdrops.push([b,fields(b,BACKDROP)]);
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;if(tile==null)return;
               rows.push(tileInputs(tile));
               contours.push(fields(tile,CONTOURS));
            }
            valid=true;
         } catch(e:*) {valid=false;}
      }
      public function unchanged(loc:Object):Boolean {
         if(!valid || loc!==room || loc.grafon!==renderer || renderer.loc!==room
            || loc.spaceX!=width || loc.spaceY!=height || loc.isRebuild || loc.isRecalc)return false;
         try {
            if(!same(style,fields(loc,STYLE).concat(colors(loc))))return false;
            var i:int=0;
            for each(var b:Object in loc.backobjs) {
               if(i>=backdrops.length || backdrops[i][0]!==b
                  || !same(backdrops[i][1],fields(b,BACKDROP)))return false;
               i++;
            }
            if(i!=backdrops.length)return false;
            i=0;
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;
               if(tile==null || !same(rows[i++],tileInputs(tile)))return false;
            }
            return true;
         } catch(e:*) {return false;}
         return false;
      }
      /** Keep the non-raster side effects of Grafon.drawLoc. Calling through
       * native methods preserves the installed renderer's lighting behavior. */
      public function refresh(world:Object):void {
         // ContinuousScene can give regions different backwall styles. Keep
         // the contours used to draw these exact cached pixels, rather than
         // recomputing every region under the current global room style.
         var index:int=0;
         for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
            var values:Array=contours[index++],tile:Object=room.space[x][y];
            for(var slot:int=0;slot<CONTOURS.length;slot++)tile[CONTOURS[slot]]=values[slot];
         }
         renderer.lightBmp.fillRect(renderer.lightBmp.rect,0xFF000000);
         renderer.setLight();renderer.visLight.visible=room.black && world.black;
         renderer.warShadow();renderer.drawAllObjs();
         world.cam.setLoc(room);world.gui.setAll();
      }
   }
}
