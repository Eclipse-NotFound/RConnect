package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.TerrainSync;
   import rconnect.baseline.BaselineTerrainSync;
   import rconnect.countedBefore.CountedTerrainBefore;
   import rconnect.countedAfter.CountedTerrainAfter;

   /** Standalone calculation replay. No game SWF, saved character or networking.
    * The runner supplies verified baseline and counter-only diagnostic copies. */
   public class TerrainFixedReplayDoc extends Sprite {
      private var checks:Array=[];
      private var failures:int=0;
      private var group:String;

      public function TerrainFixedReplayDoc() {
         var result:Object={kind:"standalone-fixed-replay",gameLoaded:false,checks:checks};
         try {
            group="current terrain";TerrainRegression.run(check,TerrainSync);
            group="baseline terrain";TerrainRegression.run(check,BaselineTerrainSync);
            group="differential terrain";
            var before:Array=TerrainRegression.replay(BaselineTerrainSync);
            var after:Array=TerrainRegression.replay(TerrainSync);
            var same:Boolean=before.length==after.length;
            for(var i:int=0;i<before.length && same;i++)same=canonical(before[i])==canonical(after[i]);
            result.replayRecords=after.length;
            check(same,"180 fixed ticks preserve all reports, patches, receipts and final tile states");

            group="held motion";HeldMotionBufferRegression.run(check);
            group="recorded container drops";DropMotionBurstRegression.run(check);
            group="native effect clock rate";NativeEffectRateRegression.run(check);
            group="snapshot allocations";
            var oldCounts:Object=allocations(CountedTerrainBefore);
            var newCounts:Object=allocations(CountedTerrainAfter);
            result.snapshotObjects={baseline:oldCounts,current:newCounts};
            check(oldCounts.unchanged==64000 && newCounts.unchanged==0,
               "100 host/client scans of 320 unchanged cells allocate zero tile snapshots after warmup");
            check(oldCounts.changed==64000 && newCounts.changed==200,
               "one changed tile per scan creates only the required host/client snapshots");
         } catch(error:*) {
            group="unhandled";check(false,String(error)+" "+(error is Error?error.getStackTrace():""));
         }
         result.failures=failures;result.passed=checks.length-failures;
         var fs:FileStream=new FileStream();
         fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify(result));fs.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }

      private function check(ok:Boolean,label:String):void {
         checks.push({group:group,pass:ok,label:label});if(!ok)failures++;
      }

      private function canonical(value:*):String {
         if(value===undefined)return "undefined";
         if(value===null)return "null";
         if(value is Number && isNaN(value))return "NaN";
         if(value is Array) {
            var parts:Array=[];for each(var item:* in value)parts.push(canonical(item));
            return "["+parts.join(",")+"]";
         }
         if(typeof(value)=="object") {
            var keys:Array=[],pairs:Array=[];for(var k:String in value)keys.push(k);keys.sort();
            for each(k in keys)pairs.push(JSON.stringify(k)+":"+canonical(value[k]));
            return "{"+pairs.join(",")+"}";
         }
         return JSON.stringify(value);
      }

      private function allocations(kind:Class):Object {
         var room:Object={spaceX:20,spaceY:16,space:[]};
         for(var x:int=0;x<20;x++) {
            room.space[x]=[];
            for(var y:int=0;y<16;y++)room.space[x][y]={phis:1,hp:60,front:"A",back:"",zad:"",
               zForm:0,water:0,stair:0,opac:1,vid:null,vid2:null,diagon:0,shelf:0,door:null,indestruct:false};
         }
         var host:Object=new kind(),client:Object=new kind();host.hostPatch(room);client.report(room);
         kind["snapshotAllocations"]=0;
         for(var n:int=0;n<100;n++){host.hostPatch(room);client.report(room);}
         var quiet:int=kind["snapshotAllocations"];kind["snapshotAllocations"]=0;
         for(n=0;n<100;n++){room.space[4][9].front="B"+n;host.hostPatch(room);client.report(room);}
         return {unchanged:quiet,changed:kind["snapshotAllocations"]};
      }
   }
}
