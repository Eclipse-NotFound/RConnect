package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.describeType;
   import flash.utils.getTimer;
   import fe.loc.Tile;
   import rconnect.game.ControlTerrainSync;
   import rconnect.game.TerrainSync;
   import rconnect.game.NativeTileState;
   import rconnect.game.NativeRoomState;

   /** Complete production old/new TerrainSync, shared exact native-state code.
    * Adjacent Tile is a sealed declared-field fixture, never a game/FPS claim. */
   public class TerrainObservedReuseChecks extends Sprite {
      private static const FIELDS:Array=[['p','phis',2],['f','front','changed-front'],['b','back','changed-back'],
         ['z','zad','changed-zad'],['zf','zForm',2],['w','water',1],['st','stair',1],['h','hp',400],
         ['o','opac',0.25],['v','vid',3],['v2','vid2',4],['d','diagon',2],['sh','shelf',true]];
      private var assertions:Array=[],failed:int=0,queue:Array=[],measurements:Array=[];
      private var active:String='',done:Boolean=false,started:int=getTimer(),lastProgress:int=-1000;
      private var bench:Object,scalarNames:Array,scalarContract:Object;

      public function TerrainObservedReuseChecks() {
         nativeCase('unchanged');
         for(var i:int=0;i<FIELDS.length;i++)nativeCase('field-'+i);
         for each(var mode:String in ['mixed','extra-scalars','v1','optional-null','legacy-native','legacy-partial'])nativeCase(mode);
         for each(mode in ['damage-ack','destroy','protected','epoch'])flowCase(mode);
         for each(mode in ['snapshot-null','snapshot-object','version','dimension','names-duplicate','names-object',
            'required-null','base-type','rows-count','grid-duplicate','grid-noncoordinate','last-odd','last-duplicate',
            'last-type','last-null-required','last-slot-range','last-missing','last-foreign',
            'initialization-null-space','initialization-late-column'])failureCase(mode);
         enqueue('benchmark-start',function():void {beginBenchmark(0);});
         addEventListener(Event.ENTER_FRAME,onFrame);
      }
      private function enqueue(label:String,action:Function):void {queue.push({label:label,action:action});}
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});if(!ok)failed++;}
      private function onFrame(e:Event):void {
         if(done)return;
         var at:int=getTimer();
         try {
            do {
               if(!queue.length){finish();return;}
               var item:Object=queue.shift();active=item.label;item.action();
            }while(getTimer()-at<8);
            if(getTimer()-lastProgress>=1000)progress();
         }catch(error:*) {check(false,'unexpected component exception in '+active+': '+errorText(error));finish();}
      }
      private static function write(name:String,value:Object):void {
         var stream:FileStream=new FileStream();
         try {stream.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(value));}
         finally {stream.close();}
      }
      private function progress():void {
         lastProgress=getTimer();
         write('progress.json',{active:active,elapsed:lastProgress-started,checks:assertions.length,failed:failed,
            round:bench==null?-1:bench.round,phase:bench==null?-1:bench.phase,index:bench==null?-1:bench.index});
      }
      private function finish():void {
         if(done)return;done=true;removeEventListener(Event.ENTER_FRAME,onFrame);
         if(assertions.length!=50)check(false,'expected exactly 50 complete checks');
         var result:Object={passed:failed==0,failed:failed,assertions:assertions,measurements:measurements,
            elapsed:getTimer()-started,actual_complete_old_new:true,native_tile_is_fixture:true,
            native_game:false,performance_qualified:false,scalarContract:scalarContract};
         write('result.json',result);trace(JSON.stringify(result));NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private static function errorText(value:*):String {
         if(value is Error)return value.name+':'+value.message+':'+value.errorID;
         return String(value);
      }
      private static function canon(value:*):String {
         if(value===undefined)return 'undefined';if(value===null)return 'null';
         if(value is Number)return isNaN(Number(value))?'NaN':String(value);
         if(value is String || value is Boolean)return JSON.stringify(value);
         var parts:Array=[],key:String;
         if(value is Array){for each(var entry:* in value)parts.push(canon(entry));return '['+parts.join(',')+']';}
         var names:Array=[];for(key in value)names.push(key);names.sort();
         for each(key in names)parts.push(JSON.stringify(key)+':'+canon(value[key]));
         return '{'+parts.join(',')+'}';
      }
      private static function clone(value:Object):Object {return JSON.parse(JSON.stringify(value));}
      private static function makeTile(x:int,y:int):Tile {
         var tile:Tile=new Tile(x,y);tile.phis=1;tile.hp=900;tile.front='wall';tile.back='background';
         tile.setZForm(0);tile.opac=0.75;tile.trap={id:'trap-'+x+','+y};
         if(x==3 && y==2)tile.door={id:'door'};
         return tile;
      }
      private static function room(width:int=4,height:int=3):Object {
         var loc:Object={spaceX:width,spaceY:height,space:[],active:false,waterLevel:0,recalcTiles:[]};
         for(var x:int=0;x<width;x++){loc.space[x]=[];for(var y:int=0;y<height;y++)loc.space[x][y]=makeTile(x,y);}
         return loc;
      }
      private static function values(loc:Object):Array {
         var out:Array=[];
         for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) {
            var tile:Object=loc.space[x][y];
            if(tile is Tile){var state:Object=NativeRoomState.scalars(tile);state.optional=tile.optional;out.push(state);}
            else out.push(tile);
         }
         return out;
      }
      private static function refs(loc:Object):Array {
         var out:Array=[];for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) {
            var tile:Object=loc.space[x][y];out.push([tile,tile.door,tile.trap]);
         }return out;
      }
      private static function sameRefs(loc:Object,previous:Array):Boolean {
         var index:int=0;
         for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) {
            var tile:Object=loc.space[x][y],prior:Array=previous[index++];
            if(tile!==prior[0] || tile.door!==prior[1] || tile.trap!==prior[2])return false;
         }return true;
      }
      private static function legacy(loc:Object):Array {
         var rows:Array=[];
         for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++) {
            var tile:Object=loc.space[x][y],row:Object={x:x,y:y,native:NativeRoomState.scalars(tile)};
            for each(var field:Array in FIELDS)row[field[0]]=tile[field[1]];rows.push(row);
         }return rows;
      }
      private static function v1(table:Object,source:Object):Object {
         var out:Object=clone(table);out.nativeTileTable=1;delete out.grid;out.rows=[];
         for(var x:int=0;x<source.spaceX;x++)for(var y:int=0;y<source.spaceY;y++) {
            var row:Array=[];
            for(var i:int=0;i<out.names.length;i++) {
               var value:*=source.space[x][y][out.names[i]];
               if(value!==out.base[i])row.push(i,value);
            }out.rows.push(row);
         }return out;
      }
      private static function restored(next:Boolean,mode:String):Object {
         var sync:Object=next?new TerrainSync():new ControlTerrainSync();
         if(mode=='legacy-partial') {
            var plain:Object={spaceX:1,spaceY:1,space:[[{phis:1,hp:900}]]};
            sync.restoreCheckpoint(plain,[{x:0,y:0,h:600,native:{hp:600,extra:'retained'}}]);
            var initial:Object=sync.report(plain),patch:Array=sync.hostPatch(plain);plain.space[0][0].hp-=9;
            var damage:Object=sync.report(plain);
            return {ok:initial==null && patch!=null && damage.tiles[0].damage==9 && plain.space[0][0].extra=='retained',
               values:plain.space,patch:patch,damage:damage,dirty:sync.dirty};
         }
         var source:Object=room(),loc:Object=room(),field:Array,changed:Boolean=false;
         if(mode.indexOf('field-')==0){field=FIELDS[int(mode.substr(6))];source.space[0][0][field[1]]=field[2];changed=true;}
         if(mode=='mixed') {
            source.space[0][0].hp=600;source.space[1][1].phis=0;
            source.space[2][1].zForm=3;source.space[2][1].opac=0.625;changed=true;
         }
         if(mode=='extra-scalars')for(var sx:int=0;sx<4;sx++)for(var sy:int=0;sy<3;sy++) {
            source.space[sx][sy].grav=2;source.space[sx][sy].mat=9;source.space[sx][sy].optional=12;
         }
         if(mode=='optional-null') {
            source.space[0][0].optional=12;
            for(sx=0;sx<4;sx++)for(sy=0;sy<3;sy++)loc.space[sx][sy].optional=99;
         }
         if(mode=='v1' || mode=='legacy-native'){source.space[0][0].hp=700;changed=true;}
         var table:Object=NativeTileState.capture(source);
         if(table==null)throw new Error('fixture failed to exercise native table');
         if(mode=='v1')table=v1(table,source);
         if(mode=='legacy-native')table=legacy(source);
         var beforeInput:String=canon(table),baseline:Array=values(loc),identities:Array=refs(loc);
         sync.restoreCheckpoint(loc,table);
         var after:Array=values(loc),report:Object=sync.report(loc),first:Array=sync.hostPatch(loc),repeat:Array=sync.hostPatch(loc);
         var ok:Boolean=sync.dirty && report==null && sameRefs(loc,identities) && canon(table)==beforeInput
            && canon(first)==canon(repeat) && (changed?first!=null:first==null);
         if(field!=null)ok=ok && first[0][field[0]]===field[2];
         if(mode=='mixed')ok=ok && loc.space[2][1].phY1==70 && loc.space[2][1].opac==0.625;
         if(mode=='field-4')ok=ok && loc.space[0][0].phY1==20 && loc.space[0][0].opac==0.75;
         if(mode=='extra-scalars')ok=ok && loc.space[3][2].grav==2 && loc.space[3][2].mat==9 && loc.space[3][2].optional==12;
         if(mode=='optional-null')ok=ok && loc.space[0][0].optional==12 && loc.space[3][2].optional==99;
         var index:int=0;
         for(sx=0;sx<4;sx++)for(sy=0;sy<3;sy++) {
            var prior:Object=baseline[index++],tile:Object=loc.space[sx][sy];
            NativeRoomState.restore(tile,prior);tile.setZForm(prior.zForm);tile.opac=prior.opac;
         }
         var quiet:Object=sync.hostPatch(loc);ok=ok && quiet==null;
         return {ok:ok,values:after,report:report,first:first,repeat:repeat,quiet:quiet,dirty:sync.dirty};
      }
      private function nativeCase(mode:String):void {
         enqueue('native-'+mode,function():void {
            var old:Object=restored(false,mode),next:Object=restored(true,mode);
            check(old.ok && next.ok && canon(old)==canon(next),'complete restore/baseline/observation: '+mode);
         });
      }
      private static function flow(next:Boolean,mode:String):Object {
         var sync:Object=next?new TerrainSync():new ControlTerrainSync(),loc:Object=room(),source:Object=room();
         source.space[0][0].hp=600;var table:Object=NativeTileState.capture(source);sync.restoreCheckpoint(loc,table);
         var quiet:Object=sync.report(loc),events:Array=[],ok:Boolean=quiet==null,tile:Tile=loc.space[0][0];
         if(mode=='damage-ack') {
            tile.hp-=25;var first:Object=sync.report(loc);events.push(first);tile.hp-=5;events.push(sync.report(loc));
            sync.acknowledge(loc,{epoch:first.epoch,seq:first.seq,tiles:[{x:0,y:0,h:575}]});
            var second:Object=sync.report(loc);events.push(second);
            sync.acknowledge(loc,{epoch:second.epoch,seq:second.seq,tiles:[{x:0,y:0,h:570}]});
            events.push(sync.report(loc));
            ok=ok && first.tiles.length==1 && first.tiles[0].damage==25 && events[1]==null
               && second.tiles.length==1 && second.tiles[0].damage==5 && events[3]==null && tile.hp==570;
         }else if(mode=='destroy') {
            tile.phis=0;first=sync.report(loc);events.push(first,sync.report(loc));
            ok=ok && first.tiles[0].damage==0 && first.tiles[0].destroy===true && events[1]==null;
         }else if(mode=='protected') {
            tile.door={id:'protected-door'};loc.space[1][0].indestruct=true;tile.hp-=11;loc.space[1][0].hp-=13;
            events.push(sync.report(loc));ok=ok && events[0]==null;
         }else {
            tile.hp-=10;first=sync.report(loc);events.push(first);
            sync.restoreCheckpoint(loc,table);events.push(sync.report(loc));tile.hp-=3;second=sync.report(loc);events.push(second);
            ok=ok && first.tiles[0].damage==10 && events[1]==null && second.tiles[0].damage==3
               && second.epoch==first.epoch+1 && second.seq==first.seq+1;
         }
         return {ok:ok,events:events,patch:sync.hostPatch(loc),values:values(loc),dirty:sync.dirty};
      }
      private function flowCase(mode:String):void {
         enqueue('flow-'+mode,function():void {
            var old:Object=flow(false,mode),next:Object=flow(true,mode);
            check(old.ok && next.ok && canon(old)==canon(next),'restored state then actual local damage: '+mode);
         });
      }
      private static function failure(next:Boolean,mode:String):Object {
         var sync:Object=next?new TerrainSync():new ControlTerrainSync(),loc:Object=room(),source:Object=room();
         source.space[0][0].hp=400;var table:Object=NativeTileState.capture(source),good:Object=clone(table);
         var hp:int=table.names.indexOf('hp'),last:int=table.rows.length-1,space:Array=loc.space;
         var lastTile:Tile=space[3][2],lastColumn:Array=space[3],before:Array=values(loc);
         switch(mode) {
            case 'snapshot-null':table=null;break;
            case 'snapshot-object':table={};break;
            case 'version':table.nativeTileTable=3;break;
            case 'dimension':table.width=5;break;
            case 'names-duplicate':table.names[1]=table.names[0];table.base[1]=table.base[0];break;
            case 'names-object':table.names[0]='door';break;
            case 'required-null':table.base[hp]=null;break;
            case 'base-type':table.base[hp]='bad';break;
            case 'rows-count':table.rows.pop();break;
            case 'grid-duplicate':table.grid.push(table.grid[0]);break;
            case 'grid-noncoordinate':table.grid=[hp];break;
            case 'last-odd':table.rows[last]=[hp];break;
            case 'last-duplicate':table.rows[last]=[hp,100,hp,200];break;
            case 'last-type':table.rows[last]=[hp,'bad'];break;
            case 'last-null-required':table.rows[last]=[hp,null];break;
            case 'last-slot-range':table.rows[last]=[table.names.length,1];break;
            case 'last-missing':space[3][2]=null;break;
            case 'last-foreign':space[3][2]={};break;
            case 'initialization-null-space':loc.space=null;break;
            case 'initialization-late-column':space[3]=null;break;
         }
         var input:String=canon(table),error:String='';
         try {sync.restoreCheckpoint(loc,table);}catch(failedRestore:*) {error=errorText(failedRestore);}
         // Repair only the fixture's missing container/tile after observing failure.
         loc.space=space;space[3]=lastColumn;space[3][2]=lastTile;
         var untouched:Boolean=canon(values(loc))==canon(before),inputSame:Boolean=canon(table)==input;
         var patch:Array=sync.hostPatch(loc),report:Object=sync.report(loc);
         loc.space[0][0].hp-=7;var damage:Object=sync.report(loc),drain:Array=sync.finishReports(loc);
         sync.restoreCheckpoint(loc,good);var recovered:Object=sync.report(loc);
         return {ok:error!='' && untouched && inputSame && recovered==null && sync.dirty,
            error:error,untouched:untouched,inputSame:inputSame,patch:patch,report:report,damage:damage,
            drain:drain,recovered:recovered,values:values(loc)};
      }
      private function failureCase(mode:String):void {
         enqueue('failure-'+mode,function():void {
            var old:Object=failure(false,mode),next:Object=failure(true,mode);
            check(old.ok && next.ok && canon(old)==canon(next),'failure/init/baseline recovery equivalence: '+mode);
         });
      }

      private function prepareScalarContract(first:Tile):void {
         if(scalarNames!=null)return;
         var desc:XML=describeType(first),sample:Object=NativeRoomState.scalars(first),covered:Object={},references:Array=[],omitted:Array=[];
         if(String(desc.@name)!='fe.loc::Tile' || String(desc.@isDynamic)!='false' || desc.accessor.length()!=0)
            throw new Error('Direct validator requires the sealed getter-free declared Tile fixture');
         scalarNames=[];
         for each(var field:XML in desc.variable) {
            if(field.hasOwnProperty('@uri'))throw new Error('Unexpected namespaced fixture slot');
            var name:String=String(field.@name),type:String=String(field.@type);
            if(type=='int' || type=='uint' || type=='Number' || type=='String' || type=='Boolean') {
               scalarNames.push(name);covered[name]=true;if(!sample.hasOwnProperty(name))omitted.push(name);
            }else references.push(name);
         }
         references.sort();omitted.sort();scalarNames.sort();
         if(canon(references)!=canon(['door','trap']) || canon(omitted)!=canon(['optional']))throw new Error('Fixture schema changed');
         var count:int=0;for(name in sample){count++;if(!covered[name])throw new Error('Uncovered scalar '+name);}
         if(scalarNames.length!=count+1)throw new Error('Incomplete scalar coverage');
         scalarContract={fields:scalarNames,productionScalarCount:count,additionalNonfiniteFields:omitted,referenceFields:references,
            sealed:true,getters:false,perCellConstructorChecked:true};
      }
      private function beginBenchmark(round:int):void {
         bench={round:round,phase:0,index:0,same:true,cells:0,scalarChecks:0,rowsChecked:0,
            oldRoom:{spaceX:240,spaceY:125,space:[]},newRoom:{spaceX:240,spaceY:125,space:[]},oldRefs:[],newRefs:[],
            oldSync:new ControlTerrainSync(),newSync:new TerrainSync(),savedRows:[],
            ms:{round:round,tiles:30000,order:round%2==0?'old-new':'new-old',scenario:round<4?'unchanged':'mixed'}};
         enqueue('benchmark-'+round,benchmarkStep);
      }
      private static function setRow(table:Object,index:int,slot:int,value:*):void {
         var row:Array=table.rows[index];
         for(var i:int=0;i<row.length;i+=2)if(row[i]==slot){row[i+1]=value;return;}
         row.push(slot,value);
      }
      private static function header(table:Object):Object {var out:Object={};for(var key:String in table)if(key!='rows')out[key]=table[key];return out;}
      private static function sameRow(a:Array,b:Array):Boolean {
         if(a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++)if(a[i]!==b[i])return false;return true;
      }
      private function sameTiles(index:int,x:int,y:int):Boolean {
         var old:Object=bench.oldRoom.space[x][y],next:Object=bench.newRoom.space[x][y];
         var a:Array=bench.oldRefs[index],b:Array=bench.newRefs[index];
         var same:Boolean=old is Tile && next is Tile && old.constructor===Tile && next.constructor===Tile
            && old===a[0] && old.door===a[1] && old.trap===a[2] && next===b[0] && next.door===b[1] && next.trap===b[2];
         for each(var name:String in scalarNames) {
            var av:*=old[name],bv:*=next[name];
            if(av!==bv && !(av is Number && bv is Number && isNaN(Number(av)) && isNaN(Number(bv))))same=false;
            bench.scalarChecks++;
         }return same;
      }
      private function benchmarkStep():void {
         var at:int=getTimer(),x:int,y:int,index:int,start:int,oldFirst:Boolean=bench.round%2==0;
         if(bench.phase==0) {
            do {
               index=bench.index;x=int(index/125);y=index%125;
               if(y==0){bench.oldRoom.space[x]=[];bench.newRoom.space[x]=[];}
               var a:Tile=makeTile(x,y),b:Tile=makeTile(x,y);bench.oldRoom.space[x][y]=a;bench.newRoom.space[x][y]=b;
               bench.oldRefs.push([a,a.door,a.trap]);bench.newRefs.push([b,b.door,b.trap]);bench.index++;
            }while(bench.index<30000 && getTimer()-at<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else if(bench.phase==1) {
            prepareScalarContract(bench.oldRoom.space[0][0]);bench.table=NativeTileState.capture(bench.oldRoom);
            if(bench.table==null || bench.table.rows.length!=30000)throw new Error('Full native table not captured');
            bench.savedHeader=canon(header(bench.table));bench.phase++;
         }else if(bench.phase==2) {
            do {
               index=bench.index;
               if(bench.round>=4 && index%5==0) {
                  var field:Array=FIELDS[int(index/5)%FIELDS.length];
                  setRow(bench.table,index,bench.table.names.indexOf(field[1]),field[2]);
               }
               bench.savedRows.push(bench.table.rows[index].concat());bench.index++;
            }while(bench.index<30000 && getTimer()-at<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else if(bench.phase==3 || bench.phase==4) {
            var oldNow:Boolean=bench.phase==3?oldFirst:!oldFirst;
            // Only the complete real restoreCheckpoint call is timed.
            if(oldNow){start=getTimer();bench.oldSync.restoreCheckpoint(bench.oldRoom,bench.table);bench.ms.oldMs=getTimer()-start;}
            else {start=getTimer();bench.newSync.restoreCheckpoint(bench.newRoom,bench.table);bench.ms.newMs=getTimer()-start;}
            bench.phase++;
         }else if(bench.phase==5) {
            do {
               index=bench.index;x=int(index/125);y=index%125;
               if(!sameTiles(index,x,y) || !sameRow(bench.savedRows[index],bench.table.rows[index]))bench.same=false;
               bench.cells++;bench.rowsChecked++;bench.index++;
            }while(bench.index<30000 && getTimer()-at<8);
            if(bench.index==30000){bench.phase++;bench.index=0;}
         }else {
            var oldReport:Object=bench.oldSync.report(bench.oldRoom),newReport:Object=bench.newSync.report(bench.newRoom);
            var oldPatch:Array=bench.oldSync.hostPatch(bench.oldRoom),newPatch:Array=bench.newSync.hostPatch(bench.newRoom);
            var ok:Boolean=bench.same && bench.cells==30000 && bench.rowsChecked==30000
               && bench.scalarChecks==30000*scalarNames.length && canon(header(bench.table))==bench.savedHeader
               && oldReport==null && newReport==null && canon(oldPatch)==canon(newPatch)
               && bench.oldSync.dirty && bench.newSync.dirty;
            if(bench.round<4)ok=ok && oldPatch==null;else ok=ok && oldPatch!=null;
            check(ok,'30000-cell full restore and all-field equality round '+bench.round+' '+bench.ms.order+' '+bench.ms.scenario);
            bench.ms.cellsChecked=bench.cells;bench.ms.rowsChecked=bench.rowsChecked;bench.ms.scalarFields=scalarNames.length;
            bench.ms.scalarValuesCompared=bench.scalarChecks;bench.ms.equal=ok;measurements.push(bench.ms);
            var round:int=bench.round;bench=null;
            if(round<5)enqueue('benchmark-start-'+(round+1),function():void {beginBenchmark(round+1);});
            return;
         }
         enqueue('benchmark-'+bench.round+'-phase-'+bench.phase,benchmarkStep);
      }
   }
}
