package authority {
   import flash.display.*;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   /** Serialize drawing commands for runtime beams/trails, without running their logic. */
   public final class VectorDraw {
      private static var applied:Dictionary=new Dictionary(true);
      private static var channelTables:Object={};
      private static function matrix(m:Matrix):Array {return m==null?null:[m.a,m.b,m.c,m.d,m.tx,m.ty];}
      private static function nativeMatrix(v:Array):Matrix {return v==null?null:new Matrix(v[0],v[1],v[2],v[3],v[4],v[5]);}
      private static function array(v:Object):Array {if(v==null)return null;var a:Array=[];for each(var n:* in v)a.push(n);return a;}
      public static function capture(g:Graphics):Array {
         var result:Array=[],lossy:Boolean=false;
         for each(var data:IGraphicsData in g.readGraphicsData(false)) {
            // AIR exports premultiplied translucent colors with rounding and
            // expands strokes; drawTriangles may export nothing at all.
            if(data is GraphicsStroke || data is GraphicsGradientFill || data is GraphicsBitmapFill ||
               data is GraphicsSolidFill && GraphicsSolidFill(data).alpha!=1)lossy=true;
            result.push(encode(data));
         }
         var shape:Shape=new Shape();shape.graphics.copyFrom(g);
         var bounds:Rectangle=shape.getBounds(shape);
         if(bounds.width>0 && bounds.height>0 && (lossy || result.length==0))return surface(shape,bounds);
         return result;
      }
      private static function surface(shape:Shape,bounds:Rectangle):Array {
         var x:int=Math.floor(bounds.x),y:int=Math.floor(bounds.y),w:int=Math.ceil(bounds.right)-x,h:int=Math.ceil(bounds.bottom)-y;
         var bitmap:BitmapData=new BitmapData(w,h,true,0);
         bitmap.draw(shape,new Matrix(1,0,0,1,-x,-y));
         var bytes:ByteArray=bitmap.getPixels(bitmap.rect);bitmap.dispose();bytes.compress();bytes.position=0;
         var encoded:Array=[],digits:String="0123456789abcdef";
         while(bytes.bytesAvailable>0){var b:uint=bytes.readUnsignedByte();encoded.push(digits.charAt(b>>>4)+digits.charAt(b&15));}
         return [{k:"surface",x:x,y:y,w:w,h:h,bytes:encoded.join("")}];
      }
      private static function encode(data:IGraphicsData):Object {
         var s:Object;
         if(data is GraphicsPath) {var p:GraphicsPath=data as GraphicsPath;return {k:"path",commands:array(p.commands),data:array(p.data),winding:p.winding};}
         if(data is GraphicsSolidFill) {var f:GraphicsSolidFill=data as GraphicsSolidFill;return {k:"solid",color:f.color,alpha:f.alpha};}
         if(data is GraphicsGradientFill) {
            var g:GraphicsGradientFill=data as GraphicsGradientFill;
            return {k:"gradient",type:g.type,colors:g.colors,alphas:g.alphas,ratios:g.ratios,matrix:matrix(g.matrix),spread:g.spreadMethod,interpolation:g.interpolationMethod,focal:g.focalPointRatio};
         }
         if(data is GraphicsStroke) {
            var l:GraphicsStroke=data as GraphicsStroke;
            return {k:"stroke",thickness:isNaN(l.thickness)?null:l.thickness,hint:l.pixelHinting,scale:l.scaleMode,caps:l.caps,joints:l.joints,miter:l.miterLimit,fill:l.fill==null?null:encode(l.fill as IGraphicsData)};
         }
         if(data is GraphicsEndFill)return {k:"end"};
         if(data is GraphicsTrianglePath) {
            var t:GraphicsTrianglePath=data as GraphicsTrianglePath;return {k:"triangles",vertices:array(t.vertices),indices:array(t.indices),uvt:array(t.uvtData),culling:t.culling};
         }
         if(data is GraphicsBitmapFill) {
            var b:GraphicsBitmapFill=data as GraphicsBitmapFill;
            s={k:"bitmap",matrix:matrix(b.matrix),repeat:b.repeat,smooth:b.smooth,pixels:null,w:0,h:0};
            if(b.bitmapData!=null) {s.w=b.bitmapData.width;s.h=b.bitmapData.height;s.pixels=array(b.bitmapData.getVector(b.bitmapData.rect));}
            return s;
         }
         throw new Error("Unsupported runtime drawing command "+data);
      }
      public static function apply(display:DisplayObject,g:Graphics,recipe:Array):void {
         var key:String=JSON.stringify(recipe),rec:Object=applied[display];
         if(rec!=null && rec.key===key)return;
         dispose(display);rec={key:key,bitmaps:[]};applied[display]=rec;
         if(recipe.length==1 && recipe[0].k=="surface") {
            var s:Object=recipe[0],bytes:ByteArray=new ByteArray();
            for(var i:int=0;i<s.bytes.length;i+=2)bytes.writeByte(parseInt(s.bytes.substr(i,2),16));
            bytes.uncompress();bytes.position=0;
            // Derive AIR's inverse channel conversion from its actual setter
            // and getter. A blanket +/-1 corrupts exact values such as black.
            var restored:ByteArray=new ByteArray();
            while(bytes.bytesAvailable>=4) {
               var pixel:uint=bytes.readUnsignedInt(),alpha:uint=pixel>>>24;
               if(alpha>0 && alpha<255) {
                  var table:Array=channelTable(alpha);
                  if(table[(pixel>>>16)&255]==null || table[(pixel>>>8)&255]==null || table[pixel&255]==null)
                     throw new Error("AIR drawing channel is not representable at alpha "+alpha+": "+pixel.toString(16));
                  pixel=(alpha<<24)|(table[(pixel>>>16)&255]<<16)|(table[(pixel>>>8)&255]<<8)|table[pixel&255];
               }
               restored.writeUnsignedInt(pixel);
            }
            restored.position=0;
            var bitmap:BitmapData=new BitmapData(s.w,s.h,true,0);bitmap.setPixels(bitmap.rect,restored);rec.bitmaps.push(bitmap);
            g.clear();g.beginBitmapFill(bitmap,new Matrix(1,0,0,1,s.x,s.y),false,true);g.drawRect(s.x,s.y,s.w,s.h);g.endFill();return;
         }
         var commands:Vector.<IGraphicsData>=new Vector.<IGraphicsData>();
         for each(s in recipe)commands.push(decode(s,rec));
         g.clear();g.drawGraphicsData(commands);
      }
      private static function channelTable(alpha:uint):Array {
         if(channelTables[alpha]!=null)return channelTables[alpha];
         var table:Array=[],probe:BitmapData=new BitmapData(1,1,true,0);
         for(var value:int=0;value<256;value++) {
            probe.setPixel32(0,0,(alpha<<24)|(value<<16)|(value<<8)|value);
            var actual:int=probe.getPixel32(0,0)&255;if(table[actual]==null)table[actual]=value;
         }
         probe.dispose();
         // Only values produced by AIR's unpremultiplication are present in
         // captured pixels; reject an impossible color rather than guess it.
         channelTables[alpha]=table;return table;
      }
      private static function decode(s:Object,rec:Object):IGraphicsData {
         if(s.k=="path")return new GraphicsPath(Vector.<int>(s.commands),Vector.<Number>(s.data),s.winding);
         if(s.k=="solid")return new GraphicsSolidFill(s.color,s.alpha);
         if(s.k=="gradient")return new GraphicsGradientFill(s.type,s.colors,s.alphas,s.ratios,nativeMatrix(s.matrix),s.spread,s.interpolation,s.focal);
         if(s.k=="stroke")return new GraphicsStroke(s.thickness==null?NaN:s.thickness,s.hint,s.scale,s.caps,s.joints,s.miter,s.fill==null?null:decode(s.fill,rec) as IGraphicsFill);
         if(s.k=="end")return new GraphicsEndFill();
         if(s.k=="triangles")return new GraphicsTrianglePath(Vector.<Number>(s.vertices),s.indices==null?null:Vector.<int>(s.indices),s.uvt==null?null:Vector.<Number>(s.uvt),s.culling);
         if(s.k=="bitmap") {
            var data:BitmapData=null;
            if(s.pixels!=null){data=new BitmapData(s.w,s.h,true,0);data.setVector(data.rect,Vector.<uint>(s.pixels));rec.bitmaps.push(data);}
            return new GraphicsBitmapFill(data,nativeMatrix(s.matrix),s.repeat,s.smooth);
         }
         throw new Error("Unknown drawing recipe "+s.k);
      }
      public static function dispose(display:DisplayObject):void {
         var rec:Object=applied[display];delete applied[display];
         if(rec!=null)for each(var b:BitmapData in rec.bitmaps)b.dispose();
      }
   }
}
