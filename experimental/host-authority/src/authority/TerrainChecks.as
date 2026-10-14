package authority {
   /** The fixed reader must remain compatible with the wire schema and immutable history. */
   public final class TerrainChecks {
      public static function run(check:Function):void {
         var tile:Object={},expected:Array=[],i:int;
         for(i=0;i<SceneSnapshot.TILE.length;i++){tile[SceneSnapshot.TILE[i]]=i+1;expected.push(i+1);}
         var first:Array=TerrainScan.capture(tile,null),current:Array=first;
         check(VisualPose.recipeEqual(first,expected),"direct terrain reader follows every wire field in exact order");
         check(TerrainScan.capture(tile,first)===first,"unchanged terrain reuses its immutable confirmation");
         var same:Boolean=true,retained:Array=[first],saved:Array=[first.concat()];
         for each(var key:String in SceneSnapshot.TILE)for each(var value:* in [0,-1,true,false,"door",null,undefined,NaN,Infinity]) {
            tile[key]=value;var next:Array=TerrainScan.capture(tile,current);
            for(i=0;i<SceneSnapshot.TILE.length;i++)if(!equal(next[i],tile[SceneSnapshot.TILE[i]]))same=false;
            retained.push(next);saved.push(next.concat());current=next;
         }
         for(i=0;i<retained.length;i++)for(var j:int=0;j<saved[i].length;j++)if(!equal(retained[i][j],saved[i][j]))same=false;
         check(same,"terrain field changes preserve exact values and every older confirmation",{transitions:retained.length-1});
      }
      private static function equal(a:*,b:*):Boolean {return a===b || a is Number && b is Number && isNaN(a) && isNaN(b);}
   }
}
