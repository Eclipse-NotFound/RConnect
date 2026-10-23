package rconnect.net {
   import flash.utils.ByteArray;
   /** Only wall-cell sparse uint pixels. Room/checkpoint encoding is unchanged.
    * !W1: distinguishes these bytes from every legacy base64 RoomCodec payload.
    * Uncompressed: uint16 count, then sorted (uint16 offset, uint32 ARGB) pairs. */
   public final class WallCellCodec {
      public static const PREFIX:String="!W1:";
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      // One bounded ASCII alphabet; no per-group temporary strings.
      private static const ASCII:Vector.<uint> = new <uint>[
         65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,
         97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,
         48,49,50,51,52,53,54,55,56,57,43,47];
      // Invalid ASCII entries remain -1; non-ASCII is rejected before lookup.
      private static const REVERSE:Vector.<int> = new <int>[
         -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
         -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
         -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
         52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
         -1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,
         15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
         -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
         41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1];
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
         var out:ByteArray=new ByteArray();
         out.length=int((bytes.length+2)/3)*4; // MAX_COMPRESSED already enforced.
         while(bytes.bytesAvailable) {
            var left:int=bytes.bytesAvailable,a:int=bytes.readUnsignedByte();
            var b:int=left>1?bytes.readUnsignedByte():0,c:int=left>2?bytes.readUnsignedByte():0;
            // ByteArray's default big endian writes these four ASCII bytes.
            out.writeUnsignedInt((ASCII[a>>2]<<24)|(ASCII[((a&3)<<4)|(b>>4)]<<16)|
               ((left>1?ASCII[((b&15)<<2)|(c>>6)]:61)<<8)|(left>2?ASCII[c&63]:61));
         }
         out.position=0;return PREFIX+out.readUTFBytes(out.length);
      }
      public static function unpack(data:String):Array {
         if(!isCell(data) || data.length>MAX_TEXT)return null;
         var text:String=data.substr(PREFIX.length);
         if(text.length==0 || text.length%4!=0)return null;
         var bytes:ByteArray=new ByteArray();
         for(var i:int=0;i<text.length;i+=4) {
            // Each UTF-16 code unit is checked before the bounded ASCII lookup.
            // In particular, a non-ASCII character must not wrap into the table.
            var ca:int=text.charCodeAt(i),cb:int=text.charCodeAt(i+1);
            var cc:int=text.charCodeAt(i+2),cd:int=text.charCodeAt(i+3);
            var a:int=ca<128?REVERSE[ca]:-1,b:int=cb<128?REVERSE[cb]:-1;
            var c:int=cc<128?REVERSE[cc]:-1,d:int=cd<128?REVERSE[cd]:-1;
            var padC:Boolean=cc==61,padD:Boolean=cd==61;
            if(a<0 || b<0 || (c<0&&!padC) || (d<0&&!padD) || (padC&&!padD)
               || ((padC||padD)&&i+4!=text.length) || (padC&&(b&15)!=0) || (padD&&!padC&&(c&3)!=0))return null;
            if(padC)bytes.writeByte((a<<2)|(b>>4));
            else {
               // Default big endian writes the same first two decoded bytes.
               bytes.writeShort((a<<10)|(b<<4)|(c>>2));
               if(!padD)bytes.writeByte((c<<6)|d);
            }
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
