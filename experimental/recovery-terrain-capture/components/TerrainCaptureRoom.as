package {
   import fe.loc.Tile;
   /** Only native room side effects are bounded fixtures; TerrainSync and Tile are complete sources. */
   public class TerrainCaptureRoom {
      public var spaceX:int,spaceY:int,space:Array=[],active:Boolean=true,destroyOn:Boolean=true;
      public var waterLevel:int=10,recalcTiles:Array=[],isRecalc:Boolean=false,isRebuild:Boolean=false;
      public var hitCalls:Array=[],dieCalls:Array=[],paintCalls:Array=[],grafon:Object;
      public function TerrainCaptureRoom(width:int=2,height:int=2) {
         spaceX=width;spaceY=height;grafon={tileDie:paint};
         for(var x:int=0;x<width;x++) {
            space[x]=[];
            for(var y:int=0;y<height;y++) {
               var t:Tile=new Tile(x,y);t.phis=1;t.hp=100;t.front="wall";t.back="back";t.opac=1;
               space[x][y]=t;
            }
         }
      }
      public function paint(t:Object,kind:int):void {paintCalls.push([t.X,t.Y,kind]);}
      public function hitTile(t:Tile,damage:int,x:Number,y:Number):void {
         hitCalls.push([t.X,t.Y,damage,x,y,active]);
         if(t.udar(damage) && t.hp<=0)dieTile(t);
      }
      public function dieTile(t:Tile):void {dieCalls.push([t.X,t.Y]);t.die();}
   }
}
