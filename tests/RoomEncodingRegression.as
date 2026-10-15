package {
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import rconnect.net.RoomCodec;
   import rconnect.core.Log;
   /** Original checkpoint encoder is the byte oracle, including zlib padding. */
   public class RoomEncodingRegression {
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      private static function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || (a is Array)!=(b is Array))return false;
         if(typeof a!="object" || a is Array && a.length!=b.length)return false;
         var key:String,n:int=0,m:int=0;
         for(key in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;
         return n==m;
      }
      private static function original(o:Object):String {
         var b:ByteArray=new ByteArray();b.writeUTFBytes(JSON.stringify(o));b.compress();b.position=0;
         var out:Array=[];
         while(b.bytesAvailable) {
            var left:int=b.bytesAvailable,a:int=b.readUnsignedByte(),c:int=left>1?b.readUnsignedByte():0,d:int=left>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+
               (left>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(left>2?DIGITS.charAt(d&63):"="));
         }
         return out.join("");
      }
      public static function run(check:Function):void {
         var errors:int=0,count:int=0,padding:Object={},seed:uint=78541,byteErrors:int=0,valueErrors:int=0;
         for(var n:int=0;n<96;n++) {
            var words:Array=[];
            for(var i:int=0;i<n*3;i++) {seed=uint(seed*1664525+1013904223);words.push(i,Number(seed));}
            var input:Object={room:"中文 🦄 / русский",number:n,words:words,empty:[],nil:null};
            var expected:String=original(input),actual:String=RoomCodec.pack(input);
            if(actual!==expected){errors++;byteErrors++;}
            // Object property enumeration order is not part of JSON's value.
            // Keep the separate compressed-byte equality check unchanged.
            if(!same(RoomCodec.unpack(actual),input)){
               errors++;valueErrors++;
               if(valueErrors==1)Log.d("ROOM ENCODING DIFFERENCE "+JSON.stringify({n:n,input:input,decoded:RoomCodec.unpack(actual)}));
            }
            padding[actual.substr(actual.length-2)=="=="?2:actual.charAt(actual.length-1)=="="?1:0]=true;count++;
         }
         check(errors==0,"checkpoint encoding preserves original bytes and round trips for "+count+" mixed payloads");
         Log.d("ROOM ENCODING COUNTS "+JSON.stringify({byteErrors:byteErrors,valueErrors:valueErrors}));
         check(padding[0] && padding[1] && padding[2],"checkpoint byte comparison covers all three base64 padding lengths");
         words=[];
         for(i=0;i<1600;i++){seed=uint(seed*1664525+1013904223);words.push(i,Number(seed));}
         expected=original(words);actual=RoomCodec.pack(words);
         check(actual===expected && JSON.stringify(RoomCodec.unpack(actual))===JSON.stringify(words),
            "full native wall cell preserves every sparse pixel index and ARGB value");
         var before:int=getTimer();for(i=0;i<30;i++)original(words);var oldMs:int=getTimer()-before;
         before=getTimer();for(i=0;i<30;i++)RoomCodec.pack(words);var currentMs:int=getTimer()-before;
         Log.d("ROOM ENCODING MICRO "+JSON.stringify({iterations:30,words:words.length,oldMs:oldMs,currentMs:currentMs,
            scope:"post-oracle encoding only, not a frame-rate measurement"}));
      }
   }
}
