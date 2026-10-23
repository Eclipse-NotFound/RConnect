package {
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** External, read-only observation after native generation returns. */
   public final class UnitRunGenerationProbe {
      private var armed:Boolean=false,generated:Boolean=false,errorSeen:Boolean=false;
      private var previous:Object;
      public function arm(world:Object):void {if(!armed){armed=true;previous=world.land;}}
      public function observe(world:Object,phase:String,round:int):Boolean {
         if(world==null)return false;
         if(!errorSeen && world.verror!=null && world.verror.visible) {
            errorSeen=true;
            capture(world,"first-error",phase,round,String(world.verror.txt.text));
            return true;
         }
         if(armed && !generated && world.land!=null && world.land!==previous
            && String(world.land.act.id)=="random_mane") {
            generated=true;capture(world,"generation-returned",phase,round,"");
         }
         return false;
      }
      private function capture(world:Object,kind:String,phase:String,round:int,error:String):void {
         var started:int=getTimer(),land:Object=world.land;
         var out:Object={kind:kind,applicationId:NativeApplication.nativeApplication.applicationID,
            at:started,wall:Number(new Date().time),phase:phase,round:round,error:error,
            observationOnly:true,performanceQualified:false,complete:true,
            worldLandId:land==null?null:String(land.act.id),curLandId:String(world.game.curLandId),
            stage:land==null?null:land.act.landStage,seed:land==null?null:land.rconnectLayoutSeed,
            exit:world.t_exit,rooms:[],unitsVisited:0,anomalyCount:0,anomalies:[],faults:[]};
         var seen:Dictionary=new Dictionary(),roomCount:int=0;
         try {
            if(land==null || land.locs==null)throw new Error("No completed land to inspect");
            for(var ix:String in land.locs)for(var iy:String in land.locs[ix])for(var iz:String in land.locs[ix][iy]) {
               var loc:Object=land.locs[ix][iy][iz];
               if(loc==null || seen[loc])continue;
               seen[loc]=true;
               if(++roomCount>512){out.complete=false;throw new Error("Room observation bound exceeded");}
               var key:String=ix+","+iy+","+iz;
               var units:Array=loc.units as Array,space:Array=loc.space as Array;
               out.rooms.push({key:key,id:String(loc.id),width:loc.spaceX,height:loc.spaceY,
                  limX:loc.limX,limY:loc.limY,columns:space==null?-1:space.length,
                  landIdentity:loc.land===land,worldLocation:loc===world.loc,sky:Boolean(loc.sky),
                  unitCount:units==null?-1:units.length});
               if(units==null){out.complete=false;out.faults.push("Missing units array at "+key);continue;}
               for(var unitIndex:int=0;unitIndex<units.length;unitIndex++) {
                  var unit:Object=units[unitIndex];
                  if(++out.unitsVisited>8192){out.complete=false;throw new Error("Unit observation bound exceeded");}
                  if(unit==null){out.complete=false;out.faults.push("Null unit at "+key);continue;}
                  var reasons:Array=[],numbers:Object={},fields:Array=["X","Y","X1","X2","Y1","Y2","scX","scY","dx","dy","osndx","osndy"];
                  for each(var field:String in fields) {
                     var value:Number=Number(unit[field]);
                     numbers[field]=isFinite(value)?value:String(value);
                     if(!isFinite(value))reasons.push("nonfinite:"+field);
                  }
                  if(unit.loc!==loc)reasons.push("unit.loc identity");
                  if(loc.land!==land)reasons.push("loc.land identity");
                  var left:Number=Math.floor(Number(unit.X1)/40),right:Number=Math.floor(Number(unit.X2)/40);
                  var missing:Array=[];
                  if(isFinite(left) && isFinite(right)) {
                     if(right<left)reasons.push("inverted horizontal bounds");
                     if(space==null || space[left]==null)missing.push(left);
                     if(right!=left && (space==null || space[right]==null))missing.push(right);
                     if(missing.length>0)reasons.push("missing endpoint column");
                  }
                  if(reasons.length>0) {
                     out.anomalyCount++;
                     if(out.anomalies.length<100)out.anomalies.push({room:key,index:unitIndex,
                        cls:getQualifiedClassName(unit),id:String(unit.id),name:String(unit.nazv),
                        values:numbers,reasons:reasons,missingColumns:missing,
                        unitLocIdentity:unit.loc===loc,unitLocId:unit.loc==null?null:String(unit.loc.id),
                        disabled:unit.disabled,sost:unit.sost,inChain:unit.in_chain,mater:unit.mater,
                        isLaz:unit.isLaz,diagon:"protected-not-read",levit:unit.levit,isFly:unit.isFly});
                  }
               }
            }
         }catch(fault:*){out.complete=false;out.faults.push(String(fault));}
         out.anomaliesTruncated=out.anomalyCount>out.anomalies.length;
         out.scanMs=getTimer()-started;
         var stream:FileStream=new FileStream();
         try {
            var dir:File=File.applicationStorageDirectory.resolvePath("unit-run-generation");dir.createDirectory();
            var file:File=dir.resolvePath(kind+".json");
            if(file.exists)throw new Error("Observation output already exists: "+kind);
            stream.open(file,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(out));stream.close();
            Log.d("UNIT RUN OBSERVATION "+JSON.stringify({kind:kind,path:file.nativePath,complete:out.complete,
               rooms:out.rooms.length,units:out.unitsVisited,anomalies:out.anomalyCount,
               anomaliesTruncated:out.anomaliesTruncated,scanMs:out.scanMs,errorPresent:error.length>0}));
         }catch(writeError:*) {
            try{stream.close();}catch(closeError:*){}
            Log.d("COOP FAIL travel-timing unit observation output "+String(writeError));
         }
      }
   }
}
