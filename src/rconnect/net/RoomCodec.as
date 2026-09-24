package rconnect.net
{
   import flash.utils.ByteArray;
   /** Bounded compressed checkpoints keep full terrain below the TCP frame cap. */
   public class RoomCodec
   {
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public static function pack(o:Object):String
      {
         var b:ByteArray=new ByteArray();b.writeUTFBytes(JSON.stringify(o));b.compress();b.position=0;
         var out:Array=[];
         while(b.bytesAvailable)
         {
            var left:int=b.bytesAvailable,a:int=b.readUnsignedByte(),c:int=left>1?b.readUnsignedByte():0,d:int=left>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+
               (left>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(left>2?DIGITS.charAt(d&63):"="));
         }
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
