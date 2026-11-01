package authority {
   import flash.net.ObjectEncoding;
   import flash.utils.ByteArray;
   /** Native AMF3 preserves plain confirmation data and shared immutable pose
    * branches without expanding every field name into JSON text each tick.
    * The outer Link still owns ordering, size bounds and input validation. */
   public final class WireCodec {
      public static const RAW_LIMIT:uint=8*1024*1024;
      public static const PACKED_LIMIT:uint=1024*1024;
      private static const TAG:int=0x42;
      public static function encode(value:Object):ByteArray {
         var began:int=Timing.start(),body:ByteArray=new ByteArray();body.objectEncoding=ObjectEncoding.AMF3;body.writeObject(value);
         if(body.length>RAW_LIMIT)throw new Error("Uncompressed message exceeds bound");
         Timing.end("wire.serialize",began);began=Timing.start();
         var packed:Boolean=body.length>=4096;
         if(packed)body.compress();
         Timing.end("wire.compress",began);
         var out:ByteArray=new ByteArray();out.writeByte(TAG);out.writeByte(packed?1:0);out.writeBytes(body);
         if(out.length>PACKED_LIMIT)throw new Error("Message exceeds packed bound");return out;
      }
      public static function decode(bytes:ByteArray):Object {
         if(bytes.length<3 || bytes.length>PACKED_LIMIT)throw new Error("Invalid payload length");
         bytes.position=0;if(bytes.readUnsignedByte()!=TAG)throw new Error("Unsupported B wire format");
         var flag:int=bytes.readUnsignedByte();if(flag>1)throw new Error("Invalid B wire flags");
         var body:ByteArray=new ByteArray();bytes.readBytes(body,0,bytes.bytesAvailable);
         if(flag==1)body.uncompress();if(body.length>RAW_LIMIT)throw new Error("Uncompressed message exceeds bound");
         body.position=0;body.objectEncoding=ObjectEncoding.AMF3;var result:Object=body.readObject();
         if(body.bytesAvailable!=0)throw new Error("Trailing data after B message");
         if(result==null || result is Array || !(result.type is String))throw new Error("Invalid message");return result;
      }
   }
}
