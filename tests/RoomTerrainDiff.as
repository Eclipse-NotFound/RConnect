package {
   import flash.utils.getDefinitionByName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   /** Read-only diagnostic. Its capture cost invalidates whole-run timing. */
   public class RoomTerrainDiff {
      private var captured:Object;
      private var readMs:int=0;
      private function snapshot(loc:Object):Object {
         var cls:Object=getDefinitionByName("rconnect.game.NativeTileState");
         return cls.capture(loc);
      }
      public function before(loc:Object):void {
         var at:int=getTimer();captured=snapshot(loc);readMs=getTimer()-at;
      }
      private function values(table:Object,index:int):Array {
         var row:Array=table.rows[index],result:Array=table.base.concat();
         var x:int=int(index/int(table.height)),y:int=index%int(table.height);
         for each(var slot:int in table.grid) {
            var name:String=table.names[slot];
            result[slot]=Number(table.base[slot])+(name=="X"?x:name=="Y"?y:
               (name=="phX1" || name=="phX2")?x*40:y*40);
         }
         for(var i:int=0;i<row.length;i+=2)result[int(row[i])]=row[i+1];
         return result;
      }
      public function after(loc:Object):void {
         var at:int=getTimer(),next:Object=snapshot(loc),counts:Object={},changed:int=0;
         var valid:Boolean=captured!=null && next!=null && captured.width==next.width && captured.height==next.height
            && JSON.stringify(captured.names)==JSON.stringify(next.names) && captured.rows.length==next.rows.length;
         if(valid)for(var index:int=0;index<captured.rows.length;index++) {
            var a:Array=values(captured,index),b:Array=values(next,index),different:Boolean=false;
            for(var slot:int=0;slot<a.length;slot++)if(a[slot]!==b[slot]) {
               var name:String=captured.names[slot];counts[name]=int(counts[name])+1;different=true;
            }
            if(different)changed++;
         }
         Log.d("ROOM TERRAIN DIFF "+JSON.stringify({valid:valid,tiles:valid?captured.rows.length:0,
            changedTiles:changed,fields:counts,observerMs:readMs+getTimer()-at,diagnosticOnly:true}));
         captured=null;
      }
   }
}
