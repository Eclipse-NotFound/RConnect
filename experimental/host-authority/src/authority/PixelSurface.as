package authority {
   import flash.display.BitmapData;
   import flash.utils.ByteArray;
   /** Exact native bitmap surfaces for authored effects that modify pixels.
    * This is not used for ordinary actors, weapons, terrain or the screen. */
   public final class PixelSurface {
      private static var channelTables:Object={};
      public static function capture(bitmap:BitmapData):Object {
         var bytes:ByteArray=bitmap.getPixels(bitmap.rect);bytes.compress();bytes.position=0;
         var encoded:Array=[],digits:String="0123456789abcdef";
         while(bytes.bytesAvailable>0){var b:uint=bytes.readUnsignedByte();encoded.push(digits.charAt(b>>>4)+digits.charAt(b&15));}
         return {w:bitmap.width,h:bitmap.height,bytes:encoded.join("")};
      }
      public static function restore(s:Object,bitmap:BitmapData=null):BitmapData {
         var bytes:ByteArray=new ByteArray();
         for(var i:int=0;i<s.bytes.length;i+=2)bytes.writeByte(parseInt(s.bytes.substr(i,2),16));
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
