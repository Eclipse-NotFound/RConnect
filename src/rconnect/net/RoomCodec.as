package rconnect.net
{
   import flash.utils.ByteArray;
   /** Bounded compressed checkpoints keep full terrain below the TCP frame cap. */
   public class RoomCodec
   {
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      private static const PAIRS:Array=makePairs();
      private static function makePairs():Array {
         var out:Array=[];
         for(var i:int=0;i<4096;i++)out.push(DIGITS.charAt(i>>6)+DIGITS.charAt(i&63));
         return out;
      }
      public static function pack(o:Object):String
      {
         var b:ByteArray=new ByteArray();b.writeUTFBytes(JSON.stringify(o));b.compress();b.position=0;
         var out:Array=[];
         var a:int,c:int,d:int;
         // Two immutable table entries replace three temporary concatenations
         // for each compressed triplet. The JSON/zlib/base64 bytes stay exact.
         while(b.bytesAvailable>=3)
         {
            a=b.readUnsignedByte();c=b.readUnsignedByte();d=b.readUnsignedByte();
            out.push(PAIRS[(a<<4)|(c>>4)],PAIRS[((c&15)<<8)|d]);
         }
         if(b.bytesAvailable==1) {a=b.readUnsignedByte();out.push(PAIRS[a<<4],"==");}
         else if(b.bytesAvailable==2) {a=b.readUnsignedByte();c=b.readUnsignedByte();out.push(PAIRS[(a<<4)|(c>>4)],DIGITS.charAt((c&15)<<2),"=");}
         return out.join("");
      }
      public static function unpack(s:String):Object
      {
         if(s==null || s.length>1000000)throw new Error("Invalid room checkpoint");
         var b:ByteArray=new ByteArray();
         for(var i:int=0;i<s.length;i+=4)
         {
            var a:int=DIGITS.indexOf(s.charAt(i)),c:int=DIGITS.indexOf(s.charAt(i+1)),d:int=DIGITS.indexOf(s.charAt(i+2)),e:int=DIGITS.indexOf(s.charAt(i+3));
            b.writeByte((a<<2)|(c>>4));if(d>=0)b.writeByte((c<<4)|(d>>2));if(e>=0)b.writeByte((d<<6)|e);
         }
         b.uncompress();b.position=0;
         if(b.length>16000000)throw new Error("Room checkpoint exceeds limit");
         return JSON.parse(b.readUTFBytes(b.length));
      }
   }
}
