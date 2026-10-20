package
{
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   /** Bounded compressed checkpoints keep full terrain below the TCP frame cap. */
   public class TableRoomCodec
   {
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public static function pack(o:Object):String
      {
         var started:int=getTimer();
         var b:ByteArray=new ByteArray();b.writeUTFBytes(JSON.stringify(compact(o)));
         if(b.length>16000000)throw new Error("Room checkpoint exceeds limit: "+b.length);
         b.compress();b.position=0;
         var out:Array=[];
         while(b.bytesAvailable)
         {
            var left:int=b.bytesAvailable,a:int=b.readUnsignedByte(),c:int=left>1?b.readUnsignedByte():0,d:int=left>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+
               (left>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(left>2?DIGITS.charAt(d&63):"="));
         }
         var result:String=out.join("");
         if(result.length>1000000)throw new Error("Compressed room checkpoint exceeds limit: "+result.length);
         Log.d("RConnectRoomTiming pack key="+o.key+" ms="+(getTimer()-started)+" chars="+result.length);
         return result;
      }
      public static function unpack(s:String):Object
      {
         var started:int=getTimer();
         if(s==null || s.length>1000000)throw new Error("Invalid room checkpoint");
         var b:ByteArray=new ByteArray();
         for(var i:int=0;i<s.length;i+=4)
         {
            var a:int=DIGITS.indexOf(s.charAt(i)),c:int=DIGITS.indexOf(s.charAt(i+1)),d:int=DIGITS.indexOf(s.charAt(i+2)),e:int=DIGITS.indexOf(s.charAt(i+3));
            b.writeByte((a<<2)|(c>>4));if(d>=0)b.writeByte((c<<4)|(d>>2));if(e>=0)b.writeByte((d<<6)|e);
         }
         b.uncompress();b.position=0;
         if(b.length>16000000)throw new Error("Room checkpoint exceeds limit");
         var result:Object=expand(JSON.parse(b.readUTFBytes(b.length)));
         Log.d("RConnectRoomTiming unpack key="+result.key+" ms="+(getTimer()-started)+" bytes="+b.length);
         return result;
      }
      /** Terrain repeats the same property names tens of thousands of times.
       * A schema table removes only those names, preserving missing/null fields,
       * native scalars, arrays and JSON's existing numeric conversion exactly.
       * The previous JSON format remains readable; byte limits are unchanged. */
      private static function compact(o:Object):Object {
         if(o==null || !(o.tiles is Array) || o.tiles.length<8)return o;
         var width:int=int(o.width),height:int=int(o.height);
         if(width<1 || height<1 || width>512 || height>256 || o.tiles.length!=width*height)
            throw new Error("Invalid checkpoint terrain dimensions");
         var state:Object={},key:String;
         for(key in o)if(key!="tiles")state[key]=o[key];
         var shapes:Array=[],rows:Array=[],lookup:Object={},shape:Object;
         for each(var tile:Object in o.tiles) {
            if(tile==null || tile.native==null)throw new Error("Missing native tile state");
            if(shape==null || !matches(tile,shape)) {
               var keys:Array=[],nativeKeys:Array=[];
               for(key in tile)if(key!="native" && tile[key]!==undefined)keys.push(key);
               for(key in tile.native)if(tile.native[key]!==undefined)nativeKeys.push(key);
               keys.sort();nativeKeys.sort();
               var signature:String=JSON.stringify([keys,nativeKeys]);
               shape=lookup[signature];
               if(shape==null) {
                  if(shapes.length>=256)throw new Error("Too many checkpoint tile schemas");
                  shape={id:shapes.length,keys:keys,native:nativeKeys,topMap:{},nativeMap:{}};
                  for each(key in keys)shape.topMap[key]=true;
                  for each(key in nativeKeys)shape.nativeMap[key]=true;
                  shapes.push({keys:keys,native:nativeKeys});lookup[signature]=shape;
               }
            }
            var row:Array=[shape.id];
            for each(key in shape.keys)row.push(tile[key]);
            for each(key in shape.native)row.push(tile.native[key]);
            rows.push(row);
         }
         return {rconnectRoomTable:1,state:state,schemas:shapes,tiles:rows};
      }
      private static function matches(tile:Object,shape:Object):Boolean {
         var key:String,n:int=0;
         for(key in tile)if(key!="native" && tile[key]!==undefined) {
            if(shape.topMap[key]!==true)return false;n++;
         }
         if(n!=shape.keys.length)return false;
         n=0;
         for(key in tile.native)if(tile.native[key]!==undefined) {
            if(shape.nativeMap[key]!==true)return false;n++;
         }
         return n==shape.native.length;
      }
      private static function expand(o:Object):Object {
         if(o==null || o.rconnectRoomTable===undefined)return o;
         if(o.rconnectRoomTable!==1 || o.state==null || !(o.schemas is Array) || !(o.tiles is Array)
            || o.schemas.length>256)throw new Error("Invalid checkpoint tile table");
         var state:Object=o.state,width:int=int(state.width),height:int=int(state.height);
         if(width<1 || height<1 || width>512 || height>256 || o.tiles.length!=width*height)
            throw new Error("Invalid checkpoint tile table dimensions");
         for each(var shape:Object in o.schemas) {
            if(shape==null || !(shape.keys is Array) || !(shape.native is Array)
               || shape.keys.length+shape.native.length>256)throw new Error("Invalid checkpoint tile schema");
            var seen:Object={},key:*;
            for each(key in shape.keys) {
               if(!(key is String) || key=="native" || seen[key]===true)throw new Error("Invalid checkpoint tile key");
               seen[key]=true;
            }
            seen={};for each(key in shape.native) {
               if(!(key is String) || seen[key]===true)throw new Error("Invalid checkpoint native tile key");seen[key]=true;
            }
         }
         state.tiles=[];
         for each(var row:* in o.tiles) {
            if(!(row is Array) || row.length<1 || int(row[0])!=row[0] || row[0]<0 || row[0]>=o.schemas.length)
               throw new Error("Invalid checkpoint tile row");
            shape=o.schemas[int(row[0])];
            if(row.length!=1+shape.keys.length+shape.native.length)throw new Error("Incomplete checkpoint tile row");
            var tile:Object={native:{}},i:int=1;
            for each(key in shape.keys)tile[key]=row[i++];
            for each(key in shape.native)tile.native[key]=row[i++];
            state.tiles.push(tile);
         }
         return state;
      }
   }
}

