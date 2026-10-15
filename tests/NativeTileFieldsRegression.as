package {
   import rconnect.game.TerrainSync;
   /** Actual native Tile slots, in a private grid detached from the game map. */
   public class NativeTileFieldsRegression {
      public static function run(check:Function,main:Object,kind:Class=null):void {
         if(kind==null)kind=TerrainSync;
         var cls:Class=main.loaderInfo.applicationDomain.getDefinition("fe.loc.Tile") as Class;
         var tile:Object=new cls(0,0),room:Object={spaceX:1,spaceY:1,space:[[tile]]};
         var fields:Array=[['p','phis',1],['f','front','new-front'],['b','back','new-back'],['z','zad','new-background'],
            ['zf','zForm',2],['w','water',1],['st','stair',1],['h','hp',7],['o','opac',0.625],
            ['v','vid',3],['v2','vid2',4],['d','diagon',2],['sh','shelf',true]];
         for each(var field:Array in fields) {
            var sync:Object=new kind(),old:*=tile[field[1]];
            check(sync.hostPatch(room)==null,"native tile quiet before changing "+field[1]);
            tile[field[1]]=field[2];var patch:Array=sync.hostPatch(room);
            check(patch!=null && patch.length==1 && patch[0][field[0]]===field[2],"native tile detects exact "+field[1]+" slot");
            tile[field[1]]=old;
            check(sync.hostPatch(room)==null,"native tile returns to original "+field[1]+" baseline");
         }
      }
   }
}
