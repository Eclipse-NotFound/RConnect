package {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.getTimer;

   /** Read-only canonical world crop. Own only the non-gutter core of each
    * chunk, so overlapping native gutters never count one world pixel twice.
    * No pixel readback here: getVector and PNG belong to the post-sample phase. */
   public final class NativeWallSurfaceProbe {
      public static function capture(g:Object,area:Rectangle):Object {
         if(g.sceneLarge!==true)throw new Error("Surface fixture requires sceneLarge");
         var started:int=getTimer(),wall:Number=new Date().time,visible:BitmapData;
         var out:BitmapData=new BitmapData(area.width,area.height,true,0),covered:Number=0,rows:Array=[];
         try {
         var rects:Array=[],list:Array=g.sceneSurfaces();
         for each(var s:Object in list) {
            var data:BitmapData=s.nativeBuffers[0] as BitmapData;
            var core:Rectangle=new Rectangle(Number(s.x)+Number(s.gutter),Number(s.y)+Number(s.gutter),s.side,s.side);
            var cut:Rectangle=core.intersection(area);if(cut.isEmpty())continue;
            if(data==null || data===g.frontBmp)throw new Error("Scratch must differ from real chunk buffer");
            var native:Bitmap=s.bitmaps[0] as Bitmap;
            if(native==null || native.bitmapData!==data || native.parent!==g.visFront || native.stage==null)
               throw new Error("Real native front bitmap is not staged");
            for each(var prior:Rectangle in rects)if(prior.intersects(cut))throw new Error("Overlapping chunk cores");
            rects.push(cut);covered+=cut.width*cut.height;
            out.copyPixels(data,new Rectangle(cut.x-s.x,cut.y-s.y,cut.width,cut.height),new Point(cut.x-area.x,cut.y-area.y));
            rows.push({x:Number(s.x),y:Number(s.y),side:int(s.side),gutter:int(s.gutter),revision:int(s.revision),
               width:data.width,height:data.height,scratchDifferent:true,staged:true});
         }
         if(covered!=area.width*area.height)throw new Error("Target world crop is not completely resident: "+covered);
         // Includes the real WallBlend overlays without changing their settings,
         // visibility, alpha, source pixels or native render frequency.
         visible=new BitmapData(area.width,area.height,true,0);
         visible.draw(g.visFront,new Matrix(1,0,0,1,-area.x,-area.y));
         return {native:out,display:visible,surfaces:rows,at:started,wall:wall,cost:getTimer()-started};
         }catch(error:*){out.dispose();if(visible)visible.dispose();throw error;}
         return null; // Unreachable; ASC requires an explicit function-tail return.
      }
      public static function dispose(value:Object):void {
         if(value==null)return;if(value.native)value.native.dispose();if(value.display)value.display.dispose();
      }
      public static function words(b:BitmapData):Array {
         var out:Array=[];for each(var v:uint in b.getVector(b.rect))out.push(Number(v));return out;
      }
      public static function patch(a:Array,b:Array):Array {
         var out:Array=[];if(a.length!=b.length)throw new Error("Crop size differs");
         for(var i:int=0;i<a.length;i++)if(uint(a[i])!=uint(b[i]))out.push(i,b[i]);return out;
      }
   }
}
