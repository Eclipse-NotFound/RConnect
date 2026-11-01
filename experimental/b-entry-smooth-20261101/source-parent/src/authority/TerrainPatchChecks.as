package authority {
   /** Optional component checks; no production initialization or world step. */
   public final class TerrainPatchChecks {
      public static function run(check:Function):void {
         var before:Array=[],indices:Object={};
         for(var i:int=0;i<SceneSnapshot.TILE.length;i++){indices[SceneSnapshot.TILE[i]]=i;before.push(0);}
         before[indices.phis]=1;before[indices.hp]=100;before[indices.front]="metal";before[indices.back]="brick";
         before[indices.zad]="";before[indices.opac]=1;before[indices.vid]=4;before[indices.vid2]=7;
         var after:Array=before.concat();
         after[indices.phis]=0;after[indices.hp]=-20;after[indices.front]="";after[indices.opac]=after[indices.vid]=after[indices.vid2]=0;
         check(TerrainPatch.isFrontDestruction(before,after,true),"plain native wall death permits exact changed-pixel proof");
         check(!TerrainPatch.isFrontDestruction(before,after,false),"door/trap reference provenance is required");
         check(!TerrainPatch.isFrontDestruction(null,after,true),"full scene never qualifies as incremental destruction");
         var variant:Array;
         for each(var name:String in SceneSnapshot.TILE) {
            if(["hp","phis","front","opac","vid","vid2"].indexOf(name)>=0)continue;
            variant=after.concat();variant[indices[name]]=variant[indices[name]] is String?"different":1;
            check(!TerrainPatch.isFrontDestruction(before,variant,true),"unrelated change requires native redraw: "+name);
         }
         for each(name in ["water","diagon","stair","shelf","fRear","vRear","v2Rear"]) {
            var otherBefore:Array=before.concat();variant=after.concat();otherBefore[indices[name]]=variant[indices[name]]=1;
            check(!TerrainPatch.isFrontDestruction(otherBefore,variant,true),"unchanged special geometry is excluded: "+name);
         }
         variant=before.concat();variant[indices.phis]=3;
         check(!TerrainPatch.isFrontDestruction(variant,after,true),"background/alternate collision type is not a plain wall");
         var prior:Object={epoch:4,front:{}},state:Object={epoch:4,front:{}};
         for(var bx:int=0;bx<2;bx++)for(var by:int=0;by<2;by++) {
            var key:String=bx+":"+by;
            prior.front[key]={x:bx*64,y:by*64,pixels:{w:64,h:64}};
            state.front[key]={x:bx*64,y:by*64,pixels:{w:64,h:64}};
         }
         check(TerrainInk.freshFrontCoverage(prior,state,40,40,40,40),"four newly confirmed blocks cover a crossed tile");
         var block:Object=state.front["1:1"];
         state.front["1:1"]=prior.front["1:1"];
         check(!TerrainInk.freshFrontCoverage(prior,state,40,40,40,40),"one reused block rejects partial new coverage");
         delete state.front["1:1"];
         check(!TerrainInk.freshFrontCoverage(prior,state,40,40,40,40),"one missing block rejects coverage");
         state.front["1:1"]=block;block.pixels.w=15;
         check(!TerrainInk.freshFrontCoverage(prior,state,40,40,40,40),"short edge block cannot cover its missing pixel");
         block.pixels.w=64;state.epoch=5;
         check(!TerrainInk.freshFrontCoverage(prior,state,40,40,40,40),"new native raster epoch requires full draw");
         state.epoch=4;
         check(!TerrainInk.freshFrontCoverage(null,state,40,40,40,40),"no established bitmap baseline rejects coverage");
         check(!TerrainInk.freshFrontCoverage(prior,state,-1,40,40,40),"out-of-bounds tile rejects coverage");
      }
   }
}
