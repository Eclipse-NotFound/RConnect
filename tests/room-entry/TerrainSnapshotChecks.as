package {
   import fe.loc.Tile;
   import flash.utils.getTimer;
   import rconnect.game.TerrainSync;
   import rconnect.game.PreviousTerrainSync;
   public class TerrainSnapshotChecks {
      private static function equal(a:Object,b:Object):Boolean {
         var key:String,na:int=0,nb:int=0;
         for(key in a){na++;if(!b.hasOwnProperty(key) || a[key]!==b[key])return false;}
         for(key in b)nb++;return na==nb;
      }
      public static function run(check:Function,large:Object):void {
         var tile:Tile=new Tile(0,0),room:Object={spaceX:1,spaceY:1,space:[[tile]]};
         var fields:Array=[['p','phis',1],['f','front','front'],['b','back','back'],['z','zad','background'],
            ['zf','zForm',2],['w','water',1],['st','stair',1],['h','hp',7],['o','opac',0.625],
            ['v','vid',3],['v2','vid2',4],['d','diagon',2],['sh','shelf',true]];
         for each(var field:Array in fields) {
            var old:PreviousTerrainSync=new PreviousTerrainSync(),next:TerrainSync=new TerrainSync();
            var prior:*=tile[field[1]],quiet:Boolean=old.hostPatch(room)==null && next.hostPatch(room)==null;
            tile[field[1]]=field[2];var a:Array=old.hostPatch(room),b:Array=next.hostPatch(room);
            var matches:Boolean=a!=null && b!=null && a.length==1 && b.length==1 && equal(a[0],b[0]) && b[0][field[0]]===field[2];
            tile[field[1]]=prior;
            check(quiet && matches && old.hostPatch(room)==null && next.hostPatch(room)==null,
               'native terrain snapshot preserves exact field and baseline: '+field[1]);
         }
         room={spaceX:1,spaceY:1,space:[[{phis:1,hp:100}]]};old=new PreviousTerrainSync();next=new TerrainSync();
         old.hostPatch(room);next.hostPatch(room);room.space[0][0].hp=50;
         check(equal(old.hostPatch(room)[0],next.hostPatch(room)[0]),'non-native terrain keeps missing-field fallback semantics');
         var start:int=getTimer();old=new PreviousTerrainSync();a=old.hostPatch(large);var before:int=getTimer()-start;
         start=getTimer();next=new TerrainSync();b=next.hostPatch(large);var after:int=getTimer()-start;
         check(a==null && b==null,'full-scene native baselines report no fabricated terrain changes');
         trace('TERRAIN SNAPSHOT BENCH '+JSON.stringify({previous:before,current:after,tiles:large.spaceX*large.spaceY}));
      }
   }
}
