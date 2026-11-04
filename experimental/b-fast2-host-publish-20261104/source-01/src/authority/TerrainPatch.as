package authority {
   /** Exact Tile.die scalar shape. Rendering proof is separately supplied by
    * TerrainInk's authoritative changed pixel blocks, never by guessing art. */
   public final class TerrainPatch {
      private static var indices:Object;
      public static function isFrontDestruction(before:Array,after:Array,plain:Boolean):Boolean {
         if(!plain || before==null || after==null || before.length!=SceneSnapshot.TILE.length || after.length!=before.length)return false;
         if(indices==null){indices={};for(var n:int=0;n<SceneSnapshot.TILE.length;n++)indices[SceneSnapshot.TILE[n]]=n;}
         // Native doors, traps, rear layers, slopes, platforms and water have
         // additional visual/physical services. The host eligibility stamp
         // excludes them before and after the change; keep defensive checks.
         if(before[indices.phis]!==1 || after[indices.phis]!==0 || after[indices.front]!=="" ||
            after[indices.opac]!==0 || after[indices.vid]!==0 || after[indices.vid2]!==0)return false;
         for each(var disallowed:String in ["water","diagon","stair","shelf","fRear","vRear","v2Rear"])
            if(before[indices[disallowed]] || after[indices[disallowed]])return false;
         for(var i:int=0;i<before.length;i++)if(before[i]!==after[i]) {
            var field:String=SceneSnapshot.TILE[i];
            if(field!="hp" && field!="phis" && field!="front" && field!="opac" && field!="vid" && field!="vid2")return false;
         }
         return true;
      }
   }
}
