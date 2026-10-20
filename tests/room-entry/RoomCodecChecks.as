package {
   import rconnect.net.RoomCodec;
   public class RoomCodecChecks {
      private static function equal(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b)return false;
         if(a is Array) {
            if(!(b is Array) || a.length!=b.length)return false;
            for(var i:int=0;i<a.length;i++)if(!equal(a[i],b[i]))return false;
            return true;
         }
         if(typeof a!="object")return false;
         var ac:int=0,bc:int=0,key:String;
         for(key in a){ac++;if(!b.hasOwnProperty(key) || !equal(a[key],b[key]))return false;}
         for(key in b)bc++;return ac==bc;
      }
      public static function run(check:Function):void {
         var sample:Object={key:"map//0,0,0",width:4,height:4,tiles:[],units:[{hp:99.37,name:"精英守卫"}],loots:[]};
         for(var i:int=0;i<16;i++) {
            var t:Object={x:int(i/4),y:i%4,p:i%2,h:49.27,native:{X:int(i/4),Y:i%4,front:"墙",hp:49.27,enabled:i%2==0,extra:[1,null,false,"中"]}};
            if(i%3==0)t.native.optional=null;
            if(i%4==0)t.native.other=0;
            if(i%5==0){delete t.h;delete t.native.extra;}
            sample.tiles.push(t);
         }
         var expected:Object=OriginalRoomCodec.unpack(OriginalRoomCodec.pack(sample));
         var actual:Object=RoomCodec.unpack(RoomCodec.pack(sample));
         check(equal(expected,actual),"tile schema preserves every field, number, missing/null value and nested array");
         check(equal(RoomCodec.unpack(OriginalRoomCodec.pack(sample)),expected),"existing checkpoint format remains readable");
         actual.tiles[0].native.X=999;
         check(sample.tiles[0].native.X==0,"decoded state never aliases the source snapshot");
         var rejected:Boolean=false;
         try {RoomCodec.unpack(OriginalRoomCodec.pack({rconnectRoomTable:1,state:{width:1,height:1},schemas:[],tiles:[[0]]}));}
         catch(error:*){rejected=true;}
         check(rejected,"missing schema is rejected before restore");
         rejected=false;
         try {RoomCodec.unpack(OriginalRoomCodec.pack({rconnectRoomTable:1,state:{width:1,height:1},schemas:[{keys:["x"],native:["hp"]}],tiles:[[0,1]]}));}
         catch(error:*){rejected=true;}
         check(rejected,"truncated tile rows are rejected before restore");
         var native:Object={};
         for(i=0;i<42;i++)native["nativeTerrainScalarProperty"+i]=i%2==0?i:0.125;
         var large:Object={key:"large",width:192,height:125,units:[],tiles:[]};
         for(i=0;i<24000;i++)large.tiles.push({x:int(i/125),y:i%125,p:1,f:"A",native:native});
         check(JSON.stringify(large).length>16000000,"large-scene fixture exceeds the old decoded JSON bound");
         var wire:String=RoomCodec.pack(large),decoded:Object=RoomCodec.unpack(wire);
         check(wire.length<=1000000 && decoded.tiles.length==24000 && equal(large,decoded),"large terrain round-trips completely without relaxing either byte limit");
      }
   }
}
