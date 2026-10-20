package {
   import fe.loc.Tile;
   import rconnect.game.NativeTileState;
   import rconnect.game.NativeRoomState;
   import rconnect.net.RoomCodec;
   import flash.utils.getTimer;
   public class NativeTileStateChecks {
      private static function grid():Object {
         var loc:Object={spaceX:12,spaceY:8,space:[]};
         for(var x:int=0;x<12;x++) {
            loc.space[x]=[];
            for(var y:int=0;y<8;y++) {
               var t:Tile=new Tile(x,y);t.front=(x%3==0?"墙":"");t.back="背景";t.hp=1000-x*10-y;
               t.phis=x%2;t.vid=y%3;t.vid2=x%4;t.diagon=(x+y)%3-1;
               t.water=y%2;t.shelf=x%2==0;t.setZForm((x+y)%4);t.opac=(x+y)%5/4;
               t.door={identity:x+","+y};loc.space[x][y]=t;
            }
         }
         return loc;
      }
      public static function run(check:Function):void {
         var source:Object=grid();
         source.space[3][4].X=999;source.space[3][4].Y=-7;source.space[3][4].phX1=13.125;
         var table:Object=NativeTileState.capture(source);
         check(table!=null && table.rows.length==96,"declared native tiles are captured directly into the transport table");
         var wire:String=RoomCodec.pack({key:"native-table",width:12,height:8,tiles:table});
         table=RoomCodec.unpack(wire).tiles;
         var expected:Object=grid(),actual:Object=grid(),before:String=JSON.stringify(table),callbacks:int=0;
         var door:Object=actual.space[1][1].door;
         for(var x:int=0;x<12;x++)for(var y:int=0;y<8;y++) {
            expected.space[x][y].optional=actual.space[x][y].optional=99;
            var state:Object=NativeRoomState.scalars(source.space[x][y]);
            state=JSON.parse(JSON.stringify(state));
            NativeRoomState.restore(expected.space[x][y],state);
            expected.space[x][y].setZForm(state.zForm);expected.space[x][y].opac=state.opac;
            actual.space[x][y].hp=-1;actual.space[x][y].phis=9;actual.space[x][y].front="changed";
         }
         NativeTileState.restore(actual,table,function(t:Object,x:int,y:int):void{callbacks++;});
         var same:Boolean=true;
         for(x=0;x<12;x++)for(y=0;y<8;y++)
            if(JSON.stringify(NativeRoomState.scalars(actual.space[x][y]))!=JSON.stringify(NativeRoomState.scalars(expected.space[x][y])))same=false;
         check(same,"all scalar values and shape collision bounds match the former restore sequence");
         check(callbacks==96 && actual.space[1][1].door===door,"tile observation runs once per tile and local object references survive");
         check(JSON.stringify(table)==before,"restoring never mutates the saved transport table");
         var legacy:Object=rconnect.game.PreviousNativeTileState.capture(source),oldRoom:Object=grid();
         legacy=RoomCodec.unpack(RoomCodec.pack({tiles:legacy})).tiles;
         NativeTileState.restore(oldRoom,legacy,function(t:Object,x:int,y:int):void{});
         check(oldRoom.space[3][4].X==actual.space[3][4].X && oldRoom.space[3][4].Y==actual.space[3][4].Y
            && oldRoom.space[3][4].phX1==actual.space[3][4].phX1,"previous direct table remains readable, including non-grid coordinates");
         var broken:Object=JSON.parse(before),last:int=broken.rows.length-1;
         broken.rows[last]=[0,3,0,4];
         var untouched:Object=grid(),hp:Number=untouched.space[0][0].hp,rejected:Boolean=false;
         try {NativeTileState.restore(untouched,broken,function(t:Object,x:int,y:int):void{});}catch(e:*){rejected=true;}
         check(rejected && untouched.space[0][0].hp==hp,"late malformed row is rejected before any tile changes");
         broken=JSON.parse(before);broken.names[0]="door";rejected=false;
         try {NativeTileState.restore(untouched,broken,function(t:Object,x:int,y:int):void{});}catch(e:*){rejected=true;}
         check(rejected,"object references cannot be assigned through scalar terrain fields");
         broken=JSON.parse(before);broken.grid.push(broken.grid[0]);rejected=false;
         try {NativeTileState.restore(untouched,broken,function(t:Object,x:int,y:int):void{});}catch(e:*){rejected=true;}
         check(rejected,"duplicate coordinate defaults are rejected before native writes");
         broken=JSON.parse(before);broken.grid=[broken.names.indexOf("hp")];rejected=false;
         try {NativeTileState.restore(untouched,broken,function(t:Object,x:int,y:int):void{});}catch(e:*){rejected=true;}
         check(rejected,"a non-coordinate field cannot use grid defaults");
         source.space[2][2].optional=12;
         check(NativeTileState.capture(source)==null,"an initially absent field becoming a scalar selects the general path");
         source=grid();source.space[0][0].front=null;
         check(NativeTileState.capture(source)==null,"an unsupported required field selects the general path without data loss");
         // Same native-shaped 30,000 tiles, old/new capture and compression.
         // This benchmark isolates the representation; it is not game FPS.
         var large:Object={spaceX:240,spaceY:125,space:[]};
         for(x=0;x<large.spaceX;x++) {
            large.space[x]=[];
            for(y=0;y<large.spaceY;y++) {
               var tile:Tile=new Tile(x,y);tile.phis=(x+y)%7==0?1:0;
               tile.front=tile.phis?"wall":"";tile.hp=(x*7+y*13)%1001;tile.setZForm((x+y)%4);
               large.space[x][y]=tile;
            }
         }
         var start:int=getTimer(),previous:Object=rconnect.game.PreviousNativeTileState.capture(large),captureOld:int=getTimer()-start;
         start=getTimer();var oldWire:String=RoomCodec.pack({key:"grid-before",tiles:previous}),packOld:int=getTimer()-start;
         start=getTimer();var next:Object=NativeTileState.capture(large),captureNew:int=getTimer()-start;
         start=getTimer();var nextWire:String=RoomCodec.pack({key:"grid-after",tiles:next}),packNew:int=getTimer()-start;
         check(nextWire.length<oldWire.length,"grid defaults reduce a full scene transfer without discarding coordinate overrides");
         NativeTileState.restore(large,RoomCodec.unpack(nextWire).tiles,function(t:Object,x:int,y:int):void{});
         check(large.space[239][124].X==239 && large.space[239][124].Y==124
            && large.space[239][124].hp==(239*7+124*13)%1001,"full-sized grid table restores the final row and non-coordinate state");
         trace("NATIVE GRID BENCH "+JSON.stringify({captureOld:captureOld,packOld:packOld,charsOld:oldWire.length,
            captureNew:captureNew,packNew:packNew,charsNew:nextWire.length}));
      }
   }
}
