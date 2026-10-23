package rconnect.net
{
   import flash.utils.ByteArray;
   /** Bounded compressed checkpoints keep full terrain below the TCP frame cap. */
   public class RoomCodec
   {
      private static const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public static function pack(o:Object):String
      {
         var payload:Object=compact(o);
         var json:String=JSON.stringify(payload);
         var b:ByteArray=new ByteArray();b.writeUTFBytes(json);
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
         return result;
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
         var json:String=b.readUTFBytes(b.length);
         var result:Object=JSON.parse(json);result=expand(result);
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
            var row:Array=shape==null?null:sparseRow(tile,shape);
            if(row==null) {
               var keys:Array=[],nativeKeys:Array=[];
               for(key in tile)if(key!="native" && tile[key]!==undefined)keys.push(key);
               for(key in tile.native)if(tile.native[key]!==undefined)nativeKeys.push(key);
               keys.sort();nativeKeys.sort();
               var signature:String=JSON.stringify([keys,nativeKeys]);
               shape=lookup[signature];
               if(shape==null) {
                  if(shapes.length>=256)throw new Error("Too many checkpoint tile schemas");
                  shape={id:shapes.length,keys:keys,native:nativeKeys,topMap:{},nativeMap:{},base:[]};
                  var value:*;
                  for each(key in keys) {
                     shape.topMap[key]=shape.base.length;value=tile[key];
                     shape.base.push(value is Array || (value!=null && typeof value=="object")?null:value);
                  }
                  for each(key in nativeKeys) {
                     shape.nativeMap[key]=shape.base.length;value=tile.native[key];
                     shape.base.push(value is Array || (value!=null && typeof value=="object")?null:value);
                  }
                  shapes.push({keys:keys,native:nativeKeys,base:shape.base});lookup[signature]=shape;
               }
               row=sparseRow(tile,shape);
            }
            if(row==null)throw new Error("Unstable checkpoint tile schema");
            rows.push(row);
         }
         return {rconnectRoomTable:2,state:state,schemas:shapes,tiles:rows};
      }
      /** Validate names and collect changed values in the same traversal.
       * Baselines contain only primitives; arrays always belong to their row. */
      private static function sparseRow(tile:Object,shape:Object):Array {
         var key:String,n:int=0,slot:*,value:*,row:Array=[shape.id],base:Array=shape.base;
         for(key in tile)if(key!="native" && tile[key]!==undefined) {
            slot=shape.topMap[key];if(!(slot is Number))return null;n++;
            value=tile[key];if(value!==base[int(slot)])row.push(slot,value);
         }
         if(n!=shape.keys.length)return null;
         n=0;
         for(key in tile.native)if(tile.native[key]!==undefined) {
            slot=shape.nativeMap[key];if(!(slot is Number))return null;n++;
            value=tile.native[key];if(value!==base[int(slot)])row.push(slot,value);
         }
         return n==shape.native.length?row:null;
      }
      private static function expand(o:Object):Object {
         if(o==null || o.rconnectRoomTable===undefined)return o;
         var sparse:Boolean=o.rconnectRoomTable===2;
         if((o.rconnectRoomTable!==1 && !sparse) || o.state==null || !(o.schemas is Array) || !(o.tiles is Array)
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
            if(sparse) {
               if(!(shape.base is Array) || shape.base.length!=shape.keys.length+shape.native.length)
                  throw new Error("Invalid checkpoint tile baseline");
               for each(var baseline:* in shape.base)
                  if(baseline!=null && typeof baseline=="object")throw new Error("Mutable checkpoint tile baseline");
            }
         }
         state.tiles=[];
         for each(var row:* in o.tiles) {
            if(!(row is Array) || row.length<1 || int(row[0])!=row[0] || row[0]<0 || row[0]>=o.schemas.length)
               throw new Error("Invalid checkpoint tile row");
            shape=o.schemas[int(row[0])];
            var tile:Object={native:{}},i:int=1;
            if(sparse) {
               if(row.length%2!=1)throw new Error("Incomplete sparse checkpoint tile row");
               i=0;
               for each(key in shape.keys)tile[key]=shape.base[i++];
               for each(key in shape.native)tile.native[key]=shape.base[i++];
               seen={};
               for(i=1;i<row.length;i+=2) {
                  var slot:*=row[i];
                  if(!(slot is Number) || int(slot)!=slot || slot<0 || slot>=shape.base.length || seen[slot]===true)
                     throw new Error("Invalid sparse checkpoint tile slot");
                  seen[slot]=true;
                  if(slot<shape.keys.length)tile[shape.keys[int(slot)]]=row[i+1];
                  else tile.native[shape.native[int(slot)-shape.keys.length]]=row[i+1];
               }
            } else {
               if(row.length!=1+shape.keys.length+shape.native.length)throw new Error("Incomplete checkpoint tile row");
               for each(key in shape.keys)tile[key]=row[i++];
               for each(key in shape.native)tile.native[key]=row[i++];
            }
            state.tiles.push(tile);
         }
         return state;
      }
   }
}
