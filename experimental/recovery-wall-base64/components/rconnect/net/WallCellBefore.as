package rconnect.net {
   import flash.utils.ByteArray;
   /** Only wall-cell sparse uint pixels. Room/checkpoint encoding is unchanged.
    * !W1: distinguishes these bytes from every legacy base64 RoomCodec payload.
    * Uncompressed: uint16 count, then sorted (uint16 offset, uint32 ARGB) pairs. */
   public final class WallCellBefore {
      public static const PREFIX:String="!W1:";
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      private static const MAX_RAW:int=9602; // 2 + 1600*(2+4)
      private static const MAX_COMPRESSED:int=10000; // includes conservative zlib overhead
      private static const MAX_TEXT:int=13340;
      public static function isCell(data:String):Boolean {return data!=null && data.indexOf(PREFIX)==0;}
      public static function pack(values:Object):String {
         var indices:Array=[];
         for(var key:String in values) {
            var n:Number=Number(key);
            if(!isFinite(n) || n!=int(n) || n<0 || n>=1600 || String(int(n))!=key)
               throw new Error("Invalid wall pixel offset");
            indices.push(int(n));
         }
         if(indices.length>1600)throw new Error("Too many wall pixels");
         indices.sort(Array.NUMERIC);
         var bytes:ByteArray=new ByteArray();bytes.writeShort(indices.length);
         for each(var index:int in indices) {
            var color:Number=Number(values[String(index)]);
            if(!isFinite(color) || color<0 || color>4294967295 || color!=Math.floor(color))
               throw new Error("Invalid wall pixel color");
            bytes.writeShort(index);bytes.writeUnsignedInt(uint(color));
         }
         bytes.compress();bytes.position=0;
         if(bytes.length>MAX_COMPRESSED)throw new Error("Wall cell exceeds encoded limit");
         var out:Array=[];
         while(bytes.bytesAvailable) {
            var left:int=bytes.bytesAvailable,a:int=bytes.readUnsignedByte();
            var b:int=left>1?bytes.readUnsignedByte():0,c:int=left>2?bytes.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(b>>4))+
               (left>1?DIGITS.charAt(((b&15)<<2)|(c>>6)):"=")+(left>2?DIGITS.charAt(c&63):"="));
         }
         return PREFIX+out.join("");
      }
      public static function unpack(data:String):Array {
         if(!isCell(data) || data.length>MAX_TEXT)return null;
         var text:String=data.substr(PREFIX.length);
         if(text.length==0 || text.length%4!=0)return null;
         var bytes:ByteArray=new ByteArray();
         for(var i:int=0;i<text.length;i+=4) {
            var a:int=DIGITS.indexOf(text.charAt(i)),b:int=DIGITS.indexOf(text.charAt(i+1));
            var c:int=DIGITS.indexOf(text.charAt(i+2)),d:int=DIGITS.indexOf(text.charAt(i+3));
            var padC:Boolean=text.charAt(i+2)=="=",padD:Boolean=text.charAt(i+3)=="=";
            if(a<0 || b<0 || (c<0&&!padC) || (d<0&&!padD) || (padC&&!padD)
               || ((padC||padD)&&i+4!=text.length) || (padC&&(b&15)!=0) || (padD&&!padC&&(c&3)!=0))return null;
            bytes.writeByte((a<<2)|(b>>4));
            if(!padC)bytes.writeByte((b<<4)|(c>>2));
            if(!padD)bytes.writeByte((c<<6)|d);
         }
         if(bytes.length>MAX_COMPRESSED)return null;
         // AIR's native inflate has no output-size argument. Encoded input is
         // bounded above; reject expanded content before any pixel/ACK update.
         bytes.uncompress();bytes.position=0;
         if(bytes.length<2 || bytes.length>MAX_RAW)return null;
         var count:int=bytes.readUnsignedShort();
         if(count>1600 || bytes.length!=2+6*count)return null;
         var words:Array=[],previous:int=-1;
         for(i=0;i<count;i++) {
            var index:int=bytes.readUnsignedShort();
            if(index<=previous || index>=1600)return null;
            previous=index;words.push(Number(index),Number(bytes.readUnsignedInt()));
         }
         return words;
      }
   }
}
