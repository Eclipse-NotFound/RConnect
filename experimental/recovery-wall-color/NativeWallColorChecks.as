package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.BitmapData;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.utils.getTimer;
 import rconnect.game.NativeWallColor;
 public class NativeWallColorChecks extends Sprite {
  private var assertions:Array=[],failed:int=0,details:Object={};
  public function NativeWallColorChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
  private function check(v:Boolean,label:String):void{assertions.push({label:label,passed:v});if(!v)failed++;}
  private function run(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,run);
   try {
    var source:BitmapData=new BitmapData(1,1,true,0),dest:BitmapData=new BitmapData(1,1,true,0);
    var mismatches:Array=[],oldChanged:int=0,start:int=getTimer();
    // Every alpha and every input channel: all native observable premultiplied
    // channel states, in each of R/G/B independently, including opaque/zero.
    for(var a:int=0;a<256;a++)for(var c:int=0;c<256;c++) {
     source.setPixel32(0,0,uint(a<<24|c<<16|(255-c)<<8|((c*73)&255)));
     var expected:uint=source.getPixel32(0,0);
     dest.setPixel32(0,0,expected);if(dest.getPixel32(0,0)!=expected)oldChanged++;
     var input:uint=NativeWallColor.setter(expected);
     dest.setPixel32(0,0,input);var actual:uint=dest.getPixel32(0,0);
     if(actual!=expected && mismatches.length<12)mismatches.push({alpha:a,input:c,expected:Number(expected),actual:Number(actual)});
    }
    details={states:65536,oldChanged:oldChanged,elapsedMs:getTimer()-start,mismatches:mismatches};
    check(mismatches.length==0,"65536 native observable ARGB states retain exact colors");
    check(oldChanged>0,"same native data reproduces old direct-set rounding loss");
    var colors:Array=[0xf664625b,0xf6817f77,0xee595953,0xff43433c,0xe64d4d48,0xe6524d4b];
    for each(var value:uint in colors){dest.setPixel32(0,0,NativeWallColor.setter(value));check(dest.getPixel32(0,0)==value,"exact native mismatch color "+value.toString(16));}
    check(NativeWallColor.setter(0xffffffff)==0xffffffff && NativeWallColor.setter(0xff43433c)==0xff43433c,"opaque colors unchanged");
    check(NativeWallColor.setter(0x00123456)==0,"transparent state is canonical native zero");
    source.dispose();dest.dispose();
   }catch(error:*){check(false,String(error));}
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   f.writeUTFBytes(JSON.stringify({assertions:assertions,count:assertions.length,failed:failed,passed:failed==0,details:details,diagnostic_only:true,performance_qualified:false}));
   f.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
