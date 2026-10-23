package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.core.Log;
   import rconnect.net.CodecBefore;
   import rconnect.net.RoomCodec;
   import rconnect.game.NativeTileState;
   import fe.loc.Tile;

   public class CodecCleanChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function CodecCleanChecks() {
         try {run();}catch(e:Error){check(false,"unexpected "+e.getStackTrace());}
         if(rows.length!=211)check(false,"expected exactly 211 completed checks");
         var out:Object={assertions:rows,failed:failed,passed:failed==0,native_runtime:false,functional_only:true,native_tile_is_fixture:true,exact_old_new_codec:true};
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
         Log.count=0;
         var b:String=RoomCodec.pack(input),bb:Object=RoomCodec.unpack(b);
         check(a==b,label+" exact compressed bytes unchanged");
         check(canonical(aa)==canonical(bb) && canonical(bb)==expected,label+" full round trip unchanged");
         check(Log.count==0,label+" default path does not emit per-cell logs");
         var crossOld:Object=CodecBefore.unpack(b),crossNew:Object=RoomCodec.unpack(a);
         check(canonical(crossOld)==expected && canonical(crossNew)==expected,
            label+" old/new cross decoding preserves complete transport semantics");
         check(canonical(input)==before,label+" source payload not mutated");
      }
      private function failSame(input:Object,pack:Boolean,label:String):void {
         var a:String="",b:String="";
         try {if(pack)CodecBefore.pack(input);else CodecBefore.unpack(input as String);}catch(e:Error){a=e.name+":"+e.message;}
         try {if(pack)RoomCodec.pack(input);else RoomCodec.unpack(input as String);}catch(f:Error){b=f.name+":"+f.message;}
         check(a!="" && a==b,label+" rejection unchanged");
      }
      private function run():void {
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
         // Actual production capture, with only the native Tile boundary reused
         // from the existing terrain component. This is not a running game.
         var loc:Object={spaceX:8,spaceY:4,space:[]};
         for(var x:int=0;x<8;x++) {
            loc.space[x]=[];
            for(var y:int=0;y<4;y++) {
               var t:Tile=new Tile(x-7,y+11);t.front="墙";t.back="背景";t.hp=1000-x*7-y;
               t.phis=(x+y)%2;t.setZForm((x+y)%4);t.opac=(x+y)%5/4;
               loc.space[x][y]=t;
            }
         }
         loc.space[3][2].X=999;loc.space[3][2].phX1=13.125;loc.space[2][1].optional=Number.NaN;
         var table:Object=NativeTileState.capture(loc);
         check(table!=null && table.nativeTileTable===2 && table.rows.length==32,
            "actual current NativeTileState captures the declared native Tile fixture");
         if(table==null)throw new Error("Native tile fixture did not capture");
         trial({key:"native-table-v2",width:8,height:4,tiles:table},"current native tile table v2");
         var v1:Object=JSON.parse(JSON.stringify(table));v1.nativeTileTable=1;
         for(i=0;i<v1.rows.length;i++) {
            var row:Array=v1.rows[i];x=int(i/4);y=i%4;
            for each(var slot:int in v1.grid) {
               var present:Boolean=false;
               for(var n:int=0;n<row.length;n+=2)if(row[n]===slot){present=true;break;}
               if(!present)row.push(slot,loc.space[x][y][v1.names[slot]]);
            }
         }
         delete v1.grid;
         trial({key:"native-table-v1",width:8,height:4,tiles:v1},"legacy native tile table v1");
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
         check(canonical(CodecBefore.unpack(legacy))==canonical(RoomCodec.unpack(legacy)),"legacy checkpoint decode unchanged");
      }
   }
}
