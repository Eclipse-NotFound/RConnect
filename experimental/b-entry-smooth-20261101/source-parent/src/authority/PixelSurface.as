package authority {
   import flash.display.BitmapData;
   import flash.utils.ByteArray;
   /** Exact native bitmap surfaces for authored effects that modify pixels.
    * Used for modified effect pixels and small changed terrain blocks;
    * ordinary actors/weapons and the screen keep their native display tree. */
   public final class PixelSurface {
      private static var channelTables:Object={};
      public static function capture(bitmap:BitmapData):Object {
         var bytes:ByteArray=bitmap.getPixels(bitmap.rect);bytes.compress();bytes.position=0;
         // AMF3 transports binary data directly. Do not expand every compressed
         // byte into two text characters and parse them back on every playback.
         return {w:bitmap.width,h:bitmap.height,bytes:bytes};
      }
      public static function sameBytes(a:ByteArray,b:ByteArray):Boolean {
         if(a===b)return true;if(a==null || b==null || a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++)if(a[i]!=b[i])return false;return true;
      }
      public static function restore(s:Object,bitmap:BitmapData=null):BitmapData {
         var bytes:ByteArray=new ByteArray();
         if(!(s.bytes is ByteArray))throw new Error("Native pixel payload must be binary");
         // A confirmation can be displayed repeatedly and retained by the
         // interpolation buffer. Decompress a private copy, never its payload.
         bytes.writeBytes(s.bytes);
         bytes.uncompress();bytes.position=0;
         if(bytes.length!=uint(s.w)*uint(s.h)*4)throw new Error("Native bitmap dimensions do not match its pixels");
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
         if(bitmap==null || bitmap.width!=s.w || bitmap.height!=s.h){if(bitmap!=null)bitmap.dispose();bitmap=new BitmapData(s.w,s.h,true,0);}
         bitmap.setPixels(bitmap.rect,restored);return bitmap;
      }
      private static function channelTable(alpha:uint):Array {
         if(channelTables[alpha]!=null)return channelTables[alpha];
         var table:Array=[],probe:BitmapData=new BitmapData(1,1,true,0);
         for(var value:int=0;value<256;value++) {
            probe.setPixel32(0,0,(alpha<<24)|(value<<16)|(value<<8)|value);
            var actual:int=probe.getPixel32(0,0)&255;if(table[actual]==null)table[actual]=value;
         }
         probe.dispose();channelTables[alpha]=table;return table;
      }
   }
}
