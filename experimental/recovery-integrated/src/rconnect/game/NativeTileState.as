package rconnect.game {
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;

   /** A complete native Tile checkpoint in its final transport representation.
    * No per-tile object graph is built, encoded into a table and expanded again.
    * Null means an omitted optional scalar, just as NativeRoomState.scalars.
    * Unsupported native shapes use the existing general checkpoint path. */
   public class NativeTileState {
      private static const REQUIRED:Array=["phis","front","back","zad","zForm","water","stair",
         "hp","opac","vid","vid2","diagon","shelf"];
      private static function primitive(value:*):Boolean {
         return value is String || value is Boolean || (value is Number && isFinite(Number(value)));
      }
      private static function fieldTypes(tile:Object):Object {
         var types:Object={};
         for each(var v:XML in describeType(tile).variable)if(!v.hasOwnProperty("@uri")) {
            var type:String=String(v.@type);
            if(type=="int" || type=="uint" || type=="Number" || type=="String" || type=="Boolean")types[String(v.@name)]=type;
         }
         return types;
      }
      private static function matchesType(value:*,type:String):Boolean {
         if(value==null)return true;
         if(type=="String")return value is String;
         if(type=="Boolean")return value is Boolean;
         return value is Number && isFinite(Number(value));
      }
      private static function coordinate(name:String):int {
         if(name=="X")return 1;if(name=="Y")return 2;
         if(name=="phX1" || name=="phX2")return 3;
         if(name=="phY1" || name=="phY2")return 4;
         return 0;
      }
      private static function gridDefaults(values:Array,base:Array,names:Array,grid:Array,x:int,y:int):void {
         for each(var slot:int in grid) {
            var kind:int=coordinate(names[slot]);
            values[slot]=base[slot]+(kind%2==1?x:y)*(kind<=2?1:40);
         }
      }
      public static function capture(loc:Object):Object {
         var width:int=int(loc.spaceX),height:int=int(loc.spaceY);
         if(width<1 || height<1 || width>512 || height>256)return null;
         var first:Object=loc.space[0][0];
         if(first==null || getQualifiedClassName(first)!="fe.loc::Tile")return null;
         var initial:Object=NativeRoomState.scalars(first),names:Array=[],base:Array=[],excluded:Array=[],required:Object={};
         var types:Object=fieldTypes(first);
         var name:String;
         for each(name in REQUIRED){if(!initial.hasOwnProperty(name) || !primitive(initial[name]))return null;required[name]=true;}
         for(name in initial) {
            if(!primitive(initial[name]) || !types.hasOwnProperty(name))return null;
            names.push(name);base.push(initial[name]);
         }
         for each(var variable:XML in describeType(first).variable)
            if(!variable.hasOwnProperty("@uri") && !initial.hasOwnProperty(String(variable.@name)))excluded.push(String(variable.@name));
         // Coordinates and rectangular bounds normally follow the grid.
         // Use that as a lossless baseline; nonstandard values still travel in
         // their row verbatim. Only integral bases qualify, avoiding float
         // rounding changes when the header passes through JSON.
         var rows:Array=[],grid:Array=[],defaults:Array=base.concat();
         for(var slot:int=0;slot<names.length;slot++)
            if(coordinate(names[slot]) && base[slot] is Number && base[slot]===int(base[slot]))grid.push(slot);
         for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
            var tile:Object=loc.space[x][y];
            if(tile==null || getQualifiedClassName(tile)!="fe.loc::Tile")return null;
            // A field absent from the first tile may become a scalar later.
            // Fall back instead of silently dropping that uncommon state.
            for each(name in excluded)if(primitive(tile[name]) || tile[name] is Array)return null;
            var row:Array=[];gridDefaults(defaults,base,names,grid,x,y);
            for(var i:int=0;i<names.length;i++) {
               name=names[i];var value:*=tile[name];
               if(!primitive(value)) {
                  if(required[name] || value is Array)return null;
                  value=null;
               }
               if(value!==defaults[i])row.push(i,value);
            }
            rows.push(row);
         }
         return {nativeTileTable:2,width:width,height:height,names:names,base:base,grid:grid,rows:rows};
      }
      public static function restore(loc:Object,table:Object,after:Function):void {
         if(table==null || (table.nativeTileTable!==1 && table.nativeTileTable!==2)
            || table.width!==loc.spaceX || table.height!==loc.spaceY
            || !(table.names is Array) || !(table.base is Array) || !(table.rows is Array)
            || table.names.length<1 || table.names.length>256 || table.base.length!=table.names.length
            || table.rows.length!=int(loc.spaceX)*int(loc.spaceY))throw new Error("Invalid native terrain table");
         var allowed:Object=fieldTypes(loc.space[0][0]),required:Object={},slots:Object={},name:String,i:int;
         for each(name in REQUIRED)required[name]=true;
         for(i=0;i<table.names.length;i++) {
            var field:*=table.names[i];
            if(!(field is String) || !allowed.hasOwnProperty(field) || slots.hasOwnProperty(field)
               || !matchesType(table.base[i],allowed[field]))throw new Error("Invalid native terrain field");
            slots[field]=i;
         }
         for each(name in REQUIRED)
            if(!slots.hasOwnProperty(name) || table.base[int(slots[name])]==null)throw new Error("Incomplete native terrain fields");
         var grid:Array=[],gridSeen:Object={};
         if(table.nativeTileTable===2) {
            if(!(table.grid is Array) || table.grid.length>6)throw new Error("Invalid terrain coordinate defaults");
            for each(var gridSlot:* in table.grid) {
               if(!(gridSlot is Number) || gridSlot!=int(gridSlot) || gridSlot<0 || gridSlot>=table.names.length
                  || gridSeen[gridSlot] || !coordinate(table.names[int(gridSlot)])
                  || !(table.base[int(gridSlot)] is Number) || table.base[int(gridSlot)]!==int(table.base[int(gridSlot)]))
                  throw new Error("Invalid terrain coordinate field");
               gridSeen[gridSlot]=true;grid.push(int(gridSlot));
            }
         }
         var height:int=int(loc.spaceY),row:*,tile:Object,slot:*,seen:Object,value:*,index:int=0;
         // Validate the entire transfer before changing any native tile.
         for each(row in table.rows) {
            tile=loc.space[int(index/height)][index%height];index++;
            if(tile==null || getQualifiedClassName(tile)!="fe.loc::Tile" || !(row is Array) || row.length%2!=0
               || row.length>table.names.length*2)throw new Error("Invalid native terrain row");
            seen={};
            for(i=0;i<row.length;i+=2) {
               slot=row[i];value=row[i+1];
               if(!(slot is Number) || slot!=int(slot) || slot<0 || slot>=table.names.length || seen[slot]===true
                  || !matchesType(value,allowed[table.names[int(slot)]]) || (value==null && required[table.names[int(slot)]]))
                  throw new Error("Invalid native terrain value");
               seen[slot]=true;
            }
         }
         var values:Array=table.base.concat();index=0;
         for each(row in table.rows) {
            var x:int=int(index/height),y:int=index%height;index++;tile=loc.space[x][y];
            gridDefaults(values,table.base,table.names,grid,x,y);
            for(i=0;i<row.length;i+=2)values[int(row[i])]=row[i+1];
            for(i=0;i<values.length;i++)if(values[i]!=null)tile[table.names[i]]=values[i];
            // The former restore applies native scalars, then its top-level
            // zForm and final opacity. Keep that collision-bound side effect.
            var opacity:Number=Number(tile.opac);tile.setZForm(int(tile.zForm));tile.opac=opacity;
            after(tile,x,y);
            for(i=0;i<row.length;i+=2)values[int(row[i])]=table.base[int(row[i])];
         }
      }
   }
}
