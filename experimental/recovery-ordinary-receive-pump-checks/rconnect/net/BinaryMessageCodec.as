package rconnect.net {
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;

   /** Native AMF3 transport for the same anonymous JSON data model.
    * Normalize first: no shared mutable references, typed objects or callbacks.
    * Validate the bounded plain-data AMF subset BEFORE native deserialization,
    * so a peer cannot request a class constructor or readExternal callback.
    */
   public class BinaryMessageCodec {
      public static const CAPABILITY:String="plain-amf3-v1";
      public static const MAX_BYTES:int=1024*1024;
      private static const MAX_DEPTH:int=64;
      private var bytes:ByteArray,strings:int=0,traits:int=0,nodes:int=0;

      public static function pack(message:Object):ByteArray {
         try {
            var tree:Object=copy(message,new Dictionary(),0);
            var result:ByteArray=new ByteArray();result.objectEncoding=3;result.writeObject(tree);
            if(result.length>MAX_BYTES)return null;
            result.position=0;return result;
         } catch(e:*) {return null;} // Unsupported input keeps the existing JSON path.
         return null;
      }
      private static function copy(value:*,parents:Dictionary,depth:int):* {
         if(depth>MAX_DEPTH)throw new Error("Packet nesting limit");
         if(value==null)return null;
         // AIR's JSON decimal formatter/parser can round the last binary bit.
         // Keep its exact numeric result so changing transport does not alter
         // equality-based health, color or position comparisons at the receiver.
         if(value is Number) {
            // Every signed/unsigned 32-bit integer is exactly represented by
            // JSON's decimal formatter. These dominate frame counts, colours,
            // IDs and quantized state; avoid a string allocation for each one.
            // Returning the cast also normalizes -0 to JSON's positive zero.
            var integer:int=int(value);
            if(value==integer)return integer;
            var unsigned:uint=uint(value);
            if(value==unsigned)return unsigned;
            return isFinite(Number(value))?Number(String(value)):null;
         }
         if(value is String || value is Boolean)return value;
         if(parents[value])throw new Error("Cyclic packet");
         parents[value]=true;
         var out:Object,key:String,item:*,i:int;
         if(value is Array) {
            out=[];
            for(i=0;i<value.length;i++)out.push(value[i] is Function?null:copy(value[i],parents,depth+1));
         } else {
            if(getQualifiedClassName(value)!="Object")throw new Error("Non-JSON packet object");
            out={};
            for(key in value) {
               if(key=="")throw new Error("AMF object terminator is not a property name");
               item=value[key];
               if(item===undefined || item is Function)continue;
               out[key]=copy(item,parents,depth+1);
            }
         }
         delete parents[value];return out;
      }
      public static function unpack(data:ByteArray):Object {
         if(data==null || data.length==0 || data.length>MAX_BYTES)return null;
         try {
            var reader:BinaryMessageCodec=new BinaryMessageCodec();reader.bytes=data;data.position=0;
            // The wire root is a message object, never an array or primitive.
            if(data[0]!=10)return null;
            reader.value(0);
            if(data.bytesAvailable!=0)return null;
            data.position=0;data.objectEncoding=3;
            var result:Object=data.readObject();
            return result!=null && !(result is Array) && result.type!==undefined?result:null;
         } catch(e:*) {return null;}
         return null;
      }
      private function u29():uint {
         var n:uint=0,b:uint;
         for(var i:int=0;i<3;i++) {
            b=bytes.readUnsignedByte();
            if(b<128)return (n<<7)|b;
            n=(n<<7)|(b&127);
         }
         return (n<<8)|bytes.readUnsignedByte();
      }
      /** Validation only needs empty/nonempty and reference bounds. Let the
       * native reader decode UTF-8 once after the complete frame is accepted. */
      private function stringValue():Boolean {
         var header:uint=u29();
         if((header&1)==0) {
            if((header>>1)>=strings)throw new Error("Invalid packet string reference");
            return true;
         }
         var length:uint=header>>1;
         if(length>bytes.bytesAvailable)throw new Error("Truncated packet string");
         if(length==0)return false;
         bytes.position+=length;strings++;return true;
      }
      private function value(depth:int):void {
         if(depth>MAX_DEPTH || ++nodes>MAX_BYTES)throw new Error("Packet structure limit");
         var type:uint=bytes.readUnsignedByte(),header:uint,count:uint,i:uint;
         switch(type) {
            case 1:case 2:case 3:return; // null, false, true
            case 4:u29();return;
            case 5:if(!isFinite(bytes.readDouble()))throw new Error("Non-finite packet value");return;
            case 6:stringValue();return;
            case 9:
               header=u29();count=header>>1;
               // copy() emits independent dense arrays, no object aliases.
               if((header&1)==0 || count>bytes.bytesAvailable || stringValue())throw new Error("Invalid packet array");
               for(i=0;i<count;i++)value(depth+1);
               return;
            case 10:
               header=u29();
               if((header&1)==0)throw new Error("Packet object reference");
               if((header&2)!=0) {
                  // Anonymous, dynamic, zero sealed fields; never externalizable.
                  if(header!=11 || stringValue())throw new Error("Typed packet object");
                  traits++;
               } else if((header>>2)>=traits)throw new Error("Invalid packet trait");
               while(stringValue())value(depth+1);
               return;
         }
         throw new Error("Non-JSON packet value");
      }
   }
}
