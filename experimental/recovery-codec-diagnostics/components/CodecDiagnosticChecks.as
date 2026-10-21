package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.core.Log;
   import rconnect.net.CodecBefore;
   import rconnect.net.CodecAfter;

   public class CodecDiagnosticChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function CodecDiagnosticChecks() {
         try {run();}catch(e:Error){check(false,"unexpected "+e.getStackTrace());}
         var out:Object={assertions:rows,failed:failed,passed:failed==0,native_runtime:false,functional_only:true};
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(out));stream.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});if(!ok)failed++;}
      private function canonical(value:*):String {
         if(value==null || typeof value!="object")return JSON.stringify(value);
         if(value is Array){var parts:Array=[];for each(var item:* in value)parts.push(canonical(item));return "["+parts.join(",")+"]";}
         var keys:Array=[];for(var k:String in value)keys.push(k);keys.sort();parts=[];
         for each(k in keys)parts.push(JSON.stringify(k)+":"+canonical(value[k]));return "{"+parts.join(",")+"}";
      }
      private function trial(input:Object,label:String):void {
         var before:String=canonical(input),expected:String=canonical(JSON.parse(JSON.stringify(input)));Log.count=0;
         var a:String=CodecBefore.pack(input),aa:Object=CodecBefore.unpack(a);
         check(Log.count==4,label+" old codec has four synchronous log calls");
         Log.count=0;CodecAfter.timingEnabled=false;
         var b:String=CodecAfter.pack(input),bb:Object=CodecAfter.unpack(b);
         check(a==b,label+" exact compressed bytes unchanged");
         check(canonical(aa)==canonical(bb) && canonical(bb)==expected,label+" full round trip unchanged");
         check(Log.count==0,label+" default path does not emit per-cell logs");
         CodecAfter.timingEnabled=true;Log.count=0;
         var c:String=CodecAfter.pack(input),cc:Object=CodecAfter.unpack(c);
         check(a==c && canonical(aa)==canonical(cc) && Log.count==4,label+" explicit diagnostic mode preserves data and log count");
         CodecAfter.timingEnabled=false;
         check(canonical(input)==before,label+" source payload not mutated");
      }
      private function failSame(input:Object,pack:Boolean,label:String):void {
         var a:String="",b:String="";
         try {if(pack)CodecBefore.pack(input);else CodecBefore.unpack(input as String);}catch(e:Error){a=e.name+":"+e.message;}
         try {if(pack)CodecAfter.pack(input);else CodecAfter.unpack(input as String);}catch(f:Error){b=f.name+":"+f.message;}
         check(a!="" && a==b,label+" rejection unchanged");
      }
      private function run():void {
         check(CodecAfter.timingEnabled===false,"diagnostic default is off before first use");
         trial([],"empty wall payload");trial([0,0,1,4294967295,1599,0xff123456],"sparse wall cell");
         var dense:Array=[];for(var i:int=0;i<1600;i++)dense.push(i,uint(i*1234567));trial(dense,"full wall cell");
         trial({key:"rbl:0_1",nested:[1,true,null,{name:"火花"}],missing:undefined},"checkpoint without table");
         for(var variant:int=0;variant<4;variant++) {
            var tiles:Array=[];
            for(i=0;i<32;i++) {
               var tile:Object={x:i%8,y:int(i/8),native:{phis:i%2,front:"wall",backwall:variant?"砖":"",alpha:1}};
               if(variant>0)tile.native.dynamic=[i,"a",null];
               if(variant>1 && i%2)tile.other=null;
               if(variant>2 && i%3)tile.native.water=variant;
               tiles.push(tile);
            }
            trial({key:"test"+variant,width:8,height:4,tiles:tiles},"terrain schema "+variant);
         }
         for(i=0;i<24;i++)trial([0,uint(i*101),i+1,uint(i*701)],"repeated sparse payload "+i);
         failSame(null,false,"null wire");failSame(new Array(1000002).join("x"),false,"encoded length cap");
         failSame("%%%",false,"bad compressed bytes");
         var malformed:Object={width:2,height:2,tiles:[{}, {}, {}, {}, {}, {}, {}, {}]};
         failSame(malformed,true,"terrain dimensions cap");
         malformed={width:4,height:2,tiles:[{}, {}, {}, {}, {}, {}, {}, {}]};
         failSame(malformed,true,"missing native tile");
         // Legacy JSON payloads still decode, even when no compact table exists.
         // Use the real encoder of an untableable object for legacy wire.
         var legacy:String=CodecBefore.pack({oldFormat:true,tiles:[{native:{phis:1}}]});Log.count=0;
         check(canonical(CodecBefore.unpack(legacy))==canonical(CodecAfter.unpack(legacy)),"legacy checkpoint decode unchanged");
      }
   }
}
