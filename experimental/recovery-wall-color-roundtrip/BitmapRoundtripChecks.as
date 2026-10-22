package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.BitmapData;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.geom.Rectangle;
 import flash.utils.ByteArray;
 public class BitmapRoundtripChecks extends Sprite {
  private var assertions:Array=[],rows:Array=[],failed:int=0;
  public function BitmapRoundtripChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
  private function check(v:Boolean,label:String):void{assertions.push({label:label,passed:v});if(!v)failed++;}
  private function run(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,run);
   try {
    var colors:Array=[0xf664625b,0xf6817f77,0xee595953,0xff43433c,0xe64d4d48,0xe6524d4b];
    var b:BitmapData=new BitmapData(1,1,true,0),r:Rectangle=b.rect,maps:Object={};
    for each(var value:uint in colors) {
     var alpha:int=value>>>24,m:Object=maps[alpha],c:int;
     if(m==null) {
      m={};maps[alpha]=m;
      for(c=0;c<256;c++) {
       b.setPixel32(0,0,uint(alpha<<24|c<<16|c<<8|c));
       var shown:uint=b.getPixel32(0,0);m[int(shown&255)]=c;
      }
     }
     b.setPixel32(0,0,value);var pixel:uint=b.getPixel32(0,0);
     var vector:Vector.<uint>=new <uint>[value];b.setVector(r,vector);var fromVector:uint=b.getVector(r)[0];
     var bytes:ByteArray=new ByteArray();bytes.writeUnsignedInt(value);bytes.position=0;b.setPixels(r,bytes);var fromBytes:uint=b.getPixel32(0,0);
     var channels:Array=[int(value>>>16&255),int(value>>>8&255),int(value&255)];
     var reachable:Boolean=m[channels[0]]!==undefined&&m[channels[1]]!==undefined&&m[channels[2]]!==undefined;
     var corrected:uint=0,correctedRead:uint=0;
     if(reachable) {
      corrected=uint(alpha<<24|int(m[channels[0]])<<16|int(m[channels[1]])<<8|int(m[channels[2]]));
      b.setPixel32(0,0,corrected);correctedRead=b.getPixel32(0,0);
     }
     rows.push({requested:Number(value),setPixel:Number(pixel),setVector:Number(fromVector),setPixels:Number(fromBytes),
       reachable:reachable,preimage:Number(corrected),preimageRead:Number(correctedRead)});
     check(reachable&&correctedRead==value,"observed source color has exact BitmapData setter preimage "+value.toString(16));
    }
    b.dispose();
    check(rows[3].setPixel==rows[3].requested,"opaque observed mismatch is not reproduced by a single setter");
   }catch(error:*){check(false,String(error));}
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   f.writeUTFBytes(JSON.stringify({assertions:assertions,count:assertions.length,failed:failed,passed:failed==0,rows:rows,diagnostic_only:true,performance_qualified:false}));
   f.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
