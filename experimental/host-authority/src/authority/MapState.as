package authority {
   /** Native layout seeds and map metadata; room contents still come from the host. */
   public final class MapState {
      public static function install(access:NativeAccess):void {
         access.definition("fe.loc.Land")["rconnectSeedSource"]=function(land:Object):uint {
            return uint(1+Math.floor(Math.random()*4294967295));
         };
      }
      public static function capture(land:Object):Object {
         var visits:Array=[];
         for each(var room:Object in land.listLocs)if(room!=null && room.visited)
            visits.push([room.landX,room.landY,room.landZ,room.landProb]);
         return {id:land.act.id,seed:land.rconnectLayoutSeed,level:land.lootLimit-3,
            stage:land.act.landStage,fields:NativeFields.capture(land),visited:visits};
      }
      public static function apply(access:NativeAccess,state:Object):Boolean {
         if(state==null)return false;
         var w:Object=access.world,changed:Boolean=w.land.act.id!=state.id || w.land.rconnectLayoutSeed!=state.seed;
         if(changed) {
            var Type:Class=access.definition("fe.loc.Land"),previous:Function=Type["rconnectSeedSource"];
            var act:Object=w.game.lands[state.id];
            if(act==null)throw new Error("Host map is unavailable: "+state.id);
            act.landStage=state.stage;
            w.game.curLandId=state.id;w.game.curLand=act;
            try {
               Type["rconnectSeedSource"]=function(land:Object):uint{return uint(state.seed);};
               // Construct native map metadata without enterToCurLand, scripts,
               // actor stepping or a second native travel/death transaction.
               w.land=new Type(w.gg,act,int(state.level));act.land=w.land;
            }finally {Type["rconnectSeedSource"]=previous;}
            w.game.curLandId=state.id;w.game.curLand=act;
         }
         NativeFields.apply(w.land,state.fields);
         if(w.loc!=null && w.loc.land===w.land) {
            w.land.locX=w.loc.landX;w.land.locY=w.loc.landY;w.land.locZ=w.loc.landZ;w.land.prob=w.loc.landProb;
         }
         for each(var visit:Array in state.visited) {
            var grid:Array=visit[3]==""?w.land.locs:w.land.probs[visit[3]];
            if(grid!=null && grid[visit[0]]!=null && grid[visit[0]][visit[1]]!=null && grid[visit[0]][visit[1]][visit[2]]!=null)
               grid[visit[0]][visit[1]][visit[2]].visited=true;
         }
         return changed;
      }
   }
}
