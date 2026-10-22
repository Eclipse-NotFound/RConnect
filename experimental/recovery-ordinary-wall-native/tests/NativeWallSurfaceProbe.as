package {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.getTimer;

   /** Ordinary-room counterpart of driver04's read-only native world crop.
    * Identify the actual staged Bitmap by identity, never assume frontBmp is
    * persistent merely because that public property exists on a large scene. */
   public final class NativeWallSurfaceProbe {
      public static function capture(g:Object,area:Rectangle):Object {
         if(g.sceneLarge!==false || g.sceneX!=0 || g.sceneY!=0 || g.rconnectRasterPending===true)
            throw new Error("Ordinary front requires completed non-chunk raster at origin");
         if(g.loc==null || g.loc.grafon!==g || g.loc.spaceX!=48 || g.loc.spaceY!=25)
            throw new Error("Ordinary fixture requires current native 48x25 room");
         var data:BitmapData=g.frontBmp as BitmapData;
         if(data==null || data.width!=1920 || data.height!=1000 || !data.rect.containsRect(area))
            throw new Error("Ordinary crop must lie wholly inside persistent 1920x1000 front");
         var chunks:Array=g.sceneSurfaces();
         if(chunks==null || chunks.length!=0)throw new Error("Ordinary front cannot retain native chunks");
         var bitmap:Bitmap,found:int=0;
         for(var i:int=0;i<g.visFront.numChildren;i++) {
            var candidate:Bitmap=g.visFront.getChildAt(i) as Bitmap;
            if(candidate!=null && candidate.bitmapData===data){bitmap=candidate;found++;}
         }
         if(found!=1 || bitmap.stage==null || bitmap.parent!==g.visFront || !bitmap.visible || bitmap.alpha!=1 ||
            bitmap.x!=0 || bitmap.y!=0 || bitmap.scaleX!=1 || bitmap.scaleY!=1 || bitmap.rotation!=0)
            throw new Error("Persistent front is not the unique visible untransformed native Bitmap");
         var started:int=getTimer(),wall:Number=new Date().time,out:BitmapData,visible:BitmapData;
         try {
            out=new BitmapData(area.width,area.height,true,0);
            out.copyPixels(data,area,new Point());
            visible=new BitmapData(area.width,area.height,true,0);
            visible.draw(g.visFront,new Matrix(1,0,0,1,-area.x,-area.y));
            return {native:out,display:visible,surfaces:[{mode:"ordinary",sceneLarge:false,x:0,y:0,width:data.width,height:data.height,
               originX:int(g.sceneX),originY:int(g.sceneY),roomWidth:int(g.loc.spaceX),roomHeight:int(g.loc.spaceY),
               residentChunks:chunks.length,backingIdentity:true,uniqueFront:true,staged:true,visible:true}],
               at:started,wall:wall,cost:getTimer()-started};
         }catch(error:*){if(out)out.dispose();if(visible)visible.dispose();throw error;}
         return null;
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
