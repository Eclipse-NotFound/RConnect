package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import flash.utils.describeType;
   import fe.loc.Tile;
   import rconnect.game.NativeRoomState;
   import rconnect.game.NativeTileState;
   import rconnect.game.ControlNativeTileState;
   import rconnect.net.RoomCodec;

   /** Real whole production classes, distinct names in one AIR domain.
    * Native Tile shape/setZForm is a declared fixture, not the running game.
    * Timings compare the loop only and never qualify whole-game performance. */
   public class TerrainLoopChecks extends Sprite {
      private var checks:Array=[],failed:int=0,measurements:Array=[];
      private var work:Array=[],active:String="",done:Boolean=false;
      private var started:int=getTimer(),frameCount:int=0,bench:Object;
      private var lastProgress:String="",lastProgressAt:int=-1000;
      private var scalarFields:Vector.<String>,scalarContract:Object;
      public function TerrainLoopChecks() {
         enqueue("small-cases-prepare",run);
         progress("queued");
         addEventListener(Event.ENTER_FRAME,onFrame);
      }
      private function enqueue(label:String,action:Function):void {work.push({label:label,action:action});}
      private function onFrame(e:Event):void {
         if(done)return;
         frameCount++;
         var frameStart:int=getTimer();
         try {
            // Yield at each bounded verification batch. Each production call
            // remains synchronous and can exceed this scheduling budget.
            do {
               if(!work.length){finish();return;}
               var item:Object=work.shift();active=item.label;progress("begin");
               item.action();progress("complete");
            }while(getTimer()-frameStart<8);
         }catch(error:Error) {
            check(false,"uncaught component exception in "+active+": "+error.getStackTrace());
            progress("exception");finish();
         }
      }
      private function progress(state:String):void {
         var at:int=getTimer(),key:String=bench==null?active:"benchmark-"+bench.round+"-phase-"+bench.phase;
         if(state!="finished" && state!="exception" && key==lastProgress && at-lastProgressAt<1000)return;
         lastProgress=key;lastProgressAt=at;
         var value:Object={state:state,phase:active,at:getTimer(),elapsed:getTimer()-started,
            frames:frameCount,checks:checks.length,failed:failed,queued:work.length,measurements:measurements};
         if(bench!=null)value.benchmark={round:bench.round,phase:bench.phase,index:bench.index,
            tableRowsChecked:bench.tableRowsChecked,cellsChecked:bench.cellsChecked,timing:bench.ms};
         var file:FileStream=new FileStream();
         file.open(File.applicationStorageDirectory.resolvePath("progress.json"),FileMode.WRITE);
         file.writeUTFBytes(JSON.stringify(value));file.close();
         trace("TERRAIN_PROGRESS "+JSON.stringify(value));
      }
      private function finish():void {
         if(done)return;done=true;removeEventListener(Event.ENTER_FRAME,onFrame);
         if(checks.length!=67)check(false,"component did not complete exactly 67 planned checks");
         progress("finished");
         var result:Object={passed:failed==0,failed:failed,assertions:checks,measurements:measurements,
            native_game:false,tcp_socket:false,performance_qualified:false,
            actual_complete_old_new:true,native_tile_is_fixture:true,
            complete:true,elapsed:getTimer()-started,frames:frameCount,scalarContract:scalarContract};
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify(result));f.close();
         trace(JSON.stringify(result));NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function check(ok:Boolean,label:String):void {checks.push({passed:ok,label:label});if(!ok)failed++;}
      private static function canon(value:*):String {
         if(value===undefined)return "undefined";
         if(value===null)return "null";
         if(value is Number)return isNaN(Number(value))?"NaN":String(value);
         if(value is String || value is Boolean)return JSON.stringify(value);
         if(value is Array){var arr:Array=[];for each(var v:* in value)arr.push(canon(v));return "["+arr.join(",")+"]";}
         var keys:Array=[];for(var k:String in value)keys.push(k);keys.sort();arr=[];
         for each(k in keys)arr.push(JSON.stringify(k)+":"+canon(value[k]));return "{"+arr.join(",")+"}";
      }
      private static function clone(value:Object):Object {return JSON.parse(JSON.stringify(value));}
      private static function room(width:int=12,height:int=8):Object {
         var out:Object={spaceX:width,spaceY:height,space:[]};
         for(var x:int=0;x<width;x++) {
            out.space[x]=[];
            for(var y:int=0;y<height;y++) {
               out.space[x][y]=makeTile(x,y);
            }
         }
         return out;
      }
      private static function makeTile(x:int,y:int):Tile {
         var t:Tile=new Tile(x-7,y+11);t.phis=(x+y)%7==0?1:0;
         t.front=t.phis?"墙":"";t.back="背景";t.hp=(x*7+y*13)%1001;
         t.vid=x%3;t.vid2=y%4;t.water=y%2;t.shelf=x%2==0;
         t.setZForm((x+y)%4);t.opac=(x+y)%5/4;t.door={id:x+","+y};t.trap={id:"trap"};
         return t;
      }
      private static function values(loc:Object):Array {
         var out:Array=[];
         for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++)
            out.push(NativeRoomState.scalars(loc.space[x][y]));
         return out;
      }
      private static function restoreResult(next:Boolean,table:Object,mode:int=0):Object {
         var loc:Object=room(),calls:Array=[],identities:Boolean=true,refs:Array=[],before:String=canon(table),error:String="";
         for(var x:int=0;x<12;x++)for(var y:int=0;y<8;y++) {
            var t:Tile=loc.space[x][y];refs.push([t,t.door,t.trap]);
            t.hp=-99;t.phis=7;t.front="changed";t.optional=99;
         }
         var original:String=canon(values(loc));
         var after:Function=function(tile:Object,cx:int,cy:int):void {
            identities=identities && loc.space[cx][cy]===tile;
            calls.push({x:cx,y:cy,state:NativeRoomState.scalars(tile)});
            if(mode==1)tile.hp-=3;
            if(mode==2 && calls.length==3)throw new Error("fixture callback failure");
            if(mode==3 && calls.length==1) {
               // The inner restore cannot reuse or overwrite the outer row markers.
               var inner:Object=room(1,1),s:Object=next?NativeTileState.capture(inner):ControlNativeTileState.capture(inner);
               if(next)NativeTileState.restore(inner,s,function(a:Object,b:int,c:int):void{});
               else ControlNativeTileState.restore(inner,s,function(a:Object,b:int,c:int):void{});
            }
         };
         try {
            if(next)NativeTileState.restore(loc,table,after);else ControlNativeTileState.restore(loc,table,after);
         }catch(e:Error){error=e.name+":"+e.message+":"+e.errorID;}
         var index:int=0;
         for(x=0;x<12;x++)for(y=0;y<8;y++) {
            t=loc.space[x][y];var ref:Array=refs[index++];
            identities=identities && t===ref[0] && t.door===ref[1] && t.trap===ref[2];
         }
         return {error:error,values:values(loc),calls:calls,identities:identities,
            inputUnchanged:canon(table)==before,untouched:canon(values(loc))==original};
      }
      private function compare(label:String,table:Object,mode:int=0,reject:Boolean=false):void {
         enqueue(label,function():void {compareNow(label,table,mode,reject);});
      }
      private function compareNow(label:String,table:Object,mode:int,reject:Boolean):void {
         var old:Object=restoreResult(false,table,mode),next:Object=restoreResult(true,table,mode);
         var ok:Boolean=canon(old)==canon(next) && old.identities && old.inputUnchanged;
         if(reject)ok=ok && old.error!="" && old.calls.length==0 && old.untouched;
         else if(mode==2)ok=ok && old.error.indexOf("fixture callback failure")>=0 && old.calls.length==3;
         else ok=ok && old.error=="" && old.calls.length==96;
         check(ok,label);
      }
      private static function v1(table:Object,loc:Object):Object {
         var out:Object=clone(table);out.nativeTileTable=1;delete out.grid;out.rows=[];
         for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) {
            var row:Array=[];
            for(var i:int=0;i<out.names.length;i++) {
               var value:*=loc.space[x][y][out.names[i]];
               if(value!==out.base[i])row.push(i,value);
            }
            out.rows.push(row);
         }
         return out;
      }
      private static function reordered(table:Object):Object {
         var out:Object=clone(table),last:int=out.names.length-1;
         out.names.reverse();out.base.reverse();
         for each(var row:Array in out.rows)for(var i:int=0;i<row.length;i+=2)row[i]=last-int(row[i]);
         for(i=0;i<out.grid.length;i++)out.grid[i]=last-int(out.grid[i]);
         return out;
      }
      private function run():void {
         var source:Object=room();source.space[3][4].X=999;source.space[3][4].Y=-77;
         source.space[3][4].phX1=13.125;source.space[3][4].phX2=2000000000.25;
         var old:Object=ControlNativeTileState.capture(source),next:Object=NativeTileState.capture(source);
         check(canon(old)==canon(next),"actual old/new capture preserves complete table and row order");
         var wireOld:String=RoomCodec.pack({tiles:old}),wireNext:String=RoomCodec.pack({tiles:next});
         check(wireOld==wireNext,"actual production RoomCodec bytes match before and after");
         var table:Object=RoomCodec.unpack(wireOld).tiles;
         check(canon(table)==canon(old),"codec roundtrip retains complete table inputs");
         compare("v2 full restore with negative and overridden coordinates",table);
         compare("v1 table without coordinate defaults",v1(table,source));
         var changed:Object=clone(table);changed.grid.reverse();compare("coordinate defaults in a different order",changed);
         changed=v1(table,source);changed.nativeTileTable=2;changed.grid=[];compare("v2 empty defaults keeps explicit coordinate rows",changed);
         compare("schema slot reorder retains type and required-field semantics",reordered(table));
         compare("callbacks observe final shape and may update tile scalars",table,1);
         compare("callback exception stops at same tile without rollback or swallowing",table,2);
         compare("reentrant restore uses independent per-call metadata and markers",table,3);
         changed=clone(table);for(var empty:int=0;empty<changed.rows.length;empty++)changed.rows[empty]=[];
         compare("empty override rows retain independent row markers and defaults",changed);

         var cases:Array=["null","version","width-type","width-value","height-value","names-type","base-type","rows-type",
            "empty-names","too-many-names","base-size","row-count","field-object","field-unknown","field-duplicate",
            "field-type","missing-required","null-required","grid-type","grid-too-long","grid-string","grid-negative",
            "grid-fraction","grid-range","grid-duplicate","grid-noncoordinate","grid-base-fraction","row-type",
            "row-odd","row-too-long","slot-string","slot-negative","slot-fraction","slot-range","slot-duplicate",
            "slot-negative-zero-duplicate","slot-nan","slot-infinity","value-type","value-null-required"];
         for each(var name:String in cases) {
            var b:Object=clone(table),last:int=b.rows.length-1;
            var hp:int=b.names.indexOf("hp"),front:int=b.names.indexOf("front"),coord:int=b.grid[0];
            switch(name) {
               case "null":b=null;break;
               case "version":b.nativeTileTable=3;break;
               case "width-type":b.width="12";break;
               case "width-value":b.width=13;break;
               case "height-value":b.height=9;break;
               case "names-type":b.names={};break;
               case "base-type":b.base={};break;
               case "rows-type":b.rows={};break;
               case "empty-names":b.names=[];b.base=[];break;
               case "too-many-names":b.names.length=257;b.base.length=257;break;
               case "base-size":b.base.pop();break;
               case "row-count":b.rows.pop();break;
               case "field-object":b.names[0]="door";break;
               case "field-unknown":b.names[0]="notNative";break;
               case "field-duplicate":b.names[1]=b.names[0];b.base[1]=b.base[0];break;
               case "field-type":b.base[hp]="bad";break;
               case "missing-required":b.names[hp]="optional";b.base[hp]=1;break;
               case "null-required":b.base[hp]=null;break;
               case "grid-type":b.grid={};break;
               case "grid-too-long":b.grid=[0,0,0,0,0,0,0];break;
               case "grid-string":b.grid=[String(coord)];break;
               case "grid-negative":b.grid=[-1];break;
               case "grid-fraction":b.grid=[0.5];break;
               case "grid-range":b.grid=[b.names.length];break;
               case "grid-duplicate":b.grid=[coord,coord];break;
               case "grid-noncoordinate":b.grid=[hp];break;
               case "grid-base-fraction":b.base[coord]=1.5;break;
               case "row-type":b.rows[last]={};break;
               case "row-odd":b.rows[last]=[hp];break;
               case "row-too-long":b.rows[last]=new Array(b.names.length*2+2);break;
               case "slot-string":b.rows[last]=[String(hp),1];break;
               case "slot-negative":b.rows[last]=[-1,1];break;
               case "slot-fraction":b.rows[last]=[0.5,1];break;
               case "slot-range":b.rows[last]=[b.names.length,1];break;
               case "slot-duplicate":b.rows[last]=[hp,1,hp,2];break;
               case "slot-negative-zero-duplicate":b.rows[last]=[0,b.base[0],-0,b.base[0]];break;
               case "slot-nan":b.rows[last]=[Number.NaN,1];break;
               case "slot-infinity":b.rows[last]=[Number.POSITIVE_INFINITY,1];break;
               case "value-type":b.rows[last]=[front,123];break;
               case "value-null-required":b.rows[last]=[hp,null];break;
            }
            compare("reject before any write/callback: "+name,b,0,true);
         }
         captureFallbacks();nativeRowFailures(table);benchmark();
      }
      private function nativeRowFailures(table:Object):void {
         for each(var kind:String in ["null","foreign"])queueNativeRowFailure(table,kind);
      }
      private function queueNativeRowFailure(table:Object,kind:String):void {
         enqueue("late-native-room-"+kind,function():void {
            var result:Array=[];
            for each(var next:Boolean in [false,true]) {
               var loc:Object=room(),error:String="",calls:int=0;
               loc.space[11][7]=kind=="null"?null:{};
               var before:String=canon(values(loc));
               try {
                  var after:Function=function(t:Object,x:int,y:int):void {calls++;};
                  if(next)NativeTileState.restore(loc,table,after);else ControlNativeTileState.restore(loc,table,after);
               }catch(e:Error){error=e.name+":"+e.message+":"+e.errorID;}
               result.push({error:error,calls:calls,untouched:before==canon(values(loc))});
            }
            check(canon(result[0])==canon(result[1]) && result[0].error!="" && result[0].calls==0 && result[0].untouched,
               "late native room tile rejected before writes: "+kind);
         });
      }
      private function captureFallbacks():void {
         var cases:Array=["zero-width","large-width","large-height","null-first","null-last","foreign-last",
            "later-optional","required-null","initial-array","later-reference-scalar"];
         for each(var name:String in cases)queueCaptureFallback(name);
      }
      private function queueCaptureFallback(name:String):void {
         enqueue("capture-fallback-"+name,function():void {
            var loc:Object=room();
            switch(name) {
               case "zero-width":loc.spaceX=0;break;
               case "large-width":loc.spaceX=513;break;
               case "large-height":loc.spaceY=257;break;
               case "null-first":loc.space[0][0]=null;break;
               case "null-last":loc.space[11][7]=null;break;
               case "foreign-last":loc.space[11][7]={};break;
               case "later-optional":loc.space[11][7].optional=12;break;
               case "required-null":loc.space[0][0].front=null;break;
               case "initial-array":loc.space[0][0].door=[1,2];break;
               case "later-reference-scalar":loc.space[11][7].door=12;break;
            }
            check(ControlNativeTileState.capture(loc)==null && NativeTileState.capture(loc)==null,
               "unsupported capture keeps general-path fallback: "+name);
         });
      }
      private function benchmark():void {
         // Alternate order. Preserve all raw samples including first-use costs.
         // No assertion assumes the new loop is faster.
         enqueue("benchmark-round-0",function():void {beginBenchmark(0);});
      }
      private function beginBenchmark(round:int):void {
         bench={round:round,phase:0,index:0,same:true,callsOld:0,callsNew:0,tableRowsChecked:0,cellsChecked:0,
            scalarValuesCompared:0,referencesChecked:0,oldRefs:[],newRefs:[],
            loc:{spaceX:240,spaceY:125,space:[]},oldRoom:{spaceX:240,spaceY:125,space:[]},
            newRoom:{spaceX:240,spaceY:125,space:[]},ms:{round:round,tiles:30000}};
         queueBenchmark();
      }
      private function queueBenchmark():void {
         enqueue("benchmark-"+bench.round+"-phase-"+bench.phase+"-at-"+bench.index,benchmarkStep);
      }
      private static function tableHeader(value:Object):Object {
         var out:Object={};for(var key:String in value)if(key!="rows")out[key]=value[key];return out;
      }
      /** Only this sealed, getter-free Tile fixture qualifies for direct checks.
       * The production NativeRoomState schema remains untouched. The complete
       * primitive field list includes non-finite optional Number slots that
       * scalars() omits, so this is at least as strict as the old comparison. */
      private function prepareScalarContract(first:Tile):void {
         if(scalarFields!=null)return;
         var description:XML=describeType(first),sample:Object=NativeRoomState.scalars(first),covered:Object={};
         if(String(description.@name)!="fe.loc::Tile" || String(description.@isDynamic)!="false"
            || description.accessor.length()!=0 || Object(first).constructor!==Tile)
            throw new Error("Direct validation requires the exact sealed getter-free Tile fixture");
         scalarFields=new Vector.<String>();var references:Array=[],omitted:Array=[];
         for each(var field:XML in description.variable) {
            if(field.hasOwnProperty("@uri"))throw new Error("Namespaced Tile fixture slot is unsupported");
            var name:String=String(field.@name),type:String=String(field.@type);
            if(type=="int" || type=="uint" || type=="Number" || type=="String" || type=="Boolean") {
               scalarFields.push(name);covered[name]=true;
               if(!sample.hasOwnProperty(name))omitted.push(name);
            }else references.push(name);
         }
         // All instances are constructed by makeTile() as this sealed class;
         // the variable slots cannot be added/removed between cells. The only
         // non-primitive slots are independently identity-checked after restore.
         references.sort();omitted.sort();
         if(canon(references)!=canon(["door","trap"]) || canon(omitted)!=canon(["optional"]))
            throw new Error("Tile fixture schema changed; direct validator must be reviewed");
         var sampleCount:int=0;
         for(name in sample) {if(!covered[name])throw new Error("Scalar validation omitted "+name);sampleCount++;}
         if(scalarFields.length!=sampleCount+1 || !isNaN(first.optional))
            throw new Error("NativeRoomState scalar coverage differs from declared fixture slots");
         var names:Array=[];for each(name in scalarFields)names.push(name);names.sort();
         scalarContract={sealed:true,getters:false,className:String(description.@name),
            fields:names,productionScalarCount:sampleCount,additionalNonfiniteFields:omitted,
            referenceFields:references,perCellConstructorChecked:true};
      }
      private static function sameRow(a:*,b:*):Boolean {
         if(!(a is Array) || !(b is Array) || a.length!=b.length)return false;
         var same:Boolean=true;
         for(var i:int=0;i<a.length;i++)if(a[i]!==b[i])same=false;
         return same;
      }
      private function sameTiles(old:Object,next:Object,index:int):Boolean {
         var same:Boolean=old is Tile && next is Tile
            && old.constructor===Tile && next.constructor===Tile;
         var oldRef:Array=bench.oldRefs[index],newRef:Array=bench.newRefs[index];
         same=same && old===oldRef[0] && old.door===oldRef[1] && old.trap===oldRef[2]
            && next===newRef[0] && next.door===newRef[1] && next.trap===newRef[2];
         bench.referencesChecked++;
         for each(var name:String in scalarFields) {
            var a:*=old[name],b:*=next[name];
            if(a!==b && !(a is Number && b is Number && isNaN(Number(a)) && isNaN(Number(b))))same=false;
         }
         bench.scalarValuesCompared+=scalarFields.length;
         return same;
      }
      private function benchmarkStep():void {
         var stepStart:int=getTimer(),start:int,x:int,y:int,loc:Object,firstOld:Boolean=int(bench.round)%2==0;
         var ms:Object=bench.ms;
         if(bench.phase==0 || bench.phase==5) {
            // Setup is not included in measured production durations.
            do {
               x=int(bench.index/125);y=int(bench.index%125);
               if(bench.phase==0) {
                  loc=bench.loc;if(y==0)loc.space[x]=[];loc.space[x][y]=makeTile(x,y);
               }else {
                  for each(loc in [bench.oldRoom,bench.newRoom]) {
                     if(y==0)loc.space[x]=[];loc.space[x][y]=makeTile(x,y);
                  }
                  var oldTile:Tile=bench.oldRoom.space[x][y],newTile:Tile=bench.newRoom.space[x][y];
                  bench.oldRefs.push([oldTile,oldTile.door,oldTile.trap]);
                  bench.newRefs.push([newTile,newTile.door,newTile.trap]);
               }
               bench.index++;
            }while(bench.index<30000 && getTimer()-stepStart<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else if(bench.phase==1 || bench.phase==2) {
            var captureOld:Boolean=bench.phase==1?firstOld:!firstOld;
            if(captureOld) {
               start=getTimer();bench.a=ControlNativeTileState.capture(bench.loc);ms.captureOld=getTimer()-start;
            }else {
               start=getTimer();bench.b=NativeTileState.capture(bench.loc);ms.captureNew=getTimer()-start;
            }
            bench.phase++;
         }else if(bench.phase==3) {
            // Header plus every row is the same complete structural comparison
            // as canon(table), without one uninterruptible giant string build.
            bench.same=bench.a!=null && bench.b!=null && canon(tableHeader(bench.a))==canon(tableHeader(bench.b))
               && bench.a.rows.length==30000 && bench.b.rows.length==30000;
            if(!bench.same)throw new Error("30000-cell capture has incomplete/different table header");
            prepareScalarContract(bench.loc.space[0][0]);
            bench.phase++;
         }else if(bench.phase==4) {
            do {
               if(!sameRow(bench.a.rows[bench.index],bench.b.rows[bench.index]))bench.same=false;
               bench.index++;bench.tableRowsChecked++;
            }while(bench.index<30000 && getTimer()-stepStart<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else if(bench.phase==6 || bench.phase==7) {
            var restoreOld:Boolean=bench.phase==6?firstOld:!firstOld;
            if(restoreOld) {
               var oldCallback:Function=function(t:Object,cx:int,cy:int):void {bench.callsOld++;};
               start=getTimer();ControlNativeTileState.restore(bench.oldRoom,bench.a,oldCallback);ms.restoreOld=getTimer()-start;
            }else {
               var newCallback:Function=function(t:Object,cx:int,cy:int):void {bench.callsNew++;};
               start=getTimer();NativeTileState.restore(bench.newRoom,bench.b,newCallback);ms.restoreNew=getTimer()-start;
            }
            bench.phase++;
         }else if(bench.phase==8) {
            do {
               x=int(bench.index/125);y=int(bench.index%125);
               if(!sameTiles(bench.oldRoom.space[x][y],bench.newRoom.space[x][y],bench.index))bench.same=false;
               bench.index++;bench.cellsChecked++;
            }while(bench.index<30000 && getTimer()-stepStart<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else {
            ms.tableRowsChecked=bench.tableRowsChecked;ms.cellsChecked=bench.cellsChecked;
            ms.callbacksOld=bench.callsOld;ms.callbacksNew=bench.callsNew;
            ms.scalarFields=scalarFields.length;ms.scalarValuesCompared=bench.scalarValuesCompared;
            ms.referenceCellsChecked=bench.referencesChecked;
            check(bench.same && bench.callsOld==30000 && bench.callsNew==30000
               && bench.tableRowsChecked==30000 && bench.cellsChecked==30000
               && bench.scalarValuesCompared==30000*scalarFields.length && bench.referencesChecked==30000,
               "30000-cell actual old/new equality and callbacks round "+bench.round);
            measurements.push(ms);var round:int=bench.round;bench=null;
            if(round<2)enqueue("benchmark-round-"+(round+1),function():void {beginBenchmark(round+1);});
            return;
         }
         queueBenchmark();
      }
   }
}
