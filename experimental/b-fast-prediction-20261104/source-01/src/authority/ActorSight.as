package authority {
   import flash.display.BitmapData;
   import flash.utils.Dictionary;
   /** The remote actor's native interaction light, separate from the host's
    * screen. Native Location.lighting owns the ray and fade calculations.
    * Only its light grid is borrowed during this synchronous calculation. */
   public final class ActorSight {
      private var actor:PlayerActor,rooms:Dictionary=new Dictionary(true),bitmap:BitmapData;
      public function ActorSight(actor:PlayerActor){this.actor=actor;}
      public function update():void {
         var room:Object=actor.unit.loc;
         if(room==null || !room.active)return;
         var record:Object=rooms[room];
         if(!room.black){if(record==null || record.lit!==true)rooms[room]={lit:true};return;}
         var wasLit:Boolean=record!=null && record.lit===true,fresh:Boolean=record==null || wasLit;
         if(fresh) {
            record={space:[],relight:0,x:NaN,y:NaN,d1:NaN,d2:NaN,water:NaN,dark:null};
            var Tile:Class=actor.access.definition("fe.loc.Tile");
            for(var x:int=0;x<room.spaceX;x++) {
               record.space[x]=[];
               for(var y:int=0;y<room.spaceY;y++) {
                  record.space[x][y]=new Tile(x,y);
                  if(wasLit)record.space[x][y].visi=record.space[x][y].t_visi=1;
               }
            }
            rooms[room]=record;
         }
         var changed:Boolean=fresh;
         for(x=0;x<room.spaceX;x++)for(y=0;y<room.spaceY;y++) {
            var source:Object=room.space[x][y],tile:Object=record.space[x][y];
            if(tile.opac!==source.opac || tile.water!==source.water)changed=true;
            tile.opac=source.opac;tile.water=source.water;
         }
         var px:Number=actor.unit.X+actor.unit.storona*12,py:Number=actor.unit.Y1+actor.unit.stayY*.247;
         changed=changed || Math.abs(px-record.x)>.5 || Math.abs(py-record.y)>.5 ||
            record.d1!==room.lDist1 || record.d2!==room.lDist2 || record.water!==room.opacWater || record.dark!==room.retDark;
         if(!changed && record.relight<=0)return;
         var priorSpace:Array=room.space,priorPlayer:Object=room.gg,priorRelight:int=room.relight_t;
         var grafon:Object=room.grafon,priorBitmap:BitmapData=grafon.lightBmp;
         if(bitmap==null || bitmap.width<room.spaceX+1 || bitmap.height<room.spaceY+2) {
            if(bitmap!=null)bitmap.dispose();bitmap=new BitmapData(room.spaceX+1,room.spaceY+2,true,0xFF000000);
         }
         try {
            room.space=record.space;room.gg=actor.unit;room.relight_t=record.relight;grafon.lightBmp=bitmap;
            if(changed)room.lighting();else room.lighting2();
            record.relight=room.relight_t;record.x=px;record.y=py;
            record.d1=room.lDist1;record.d2=room.lDist2;record.water=room.opacWater;record.dark=room.retDark;
         }finally {
            room.space=priorSpace;room.gg=priorPlayer;room.relight_t=priorRelight;grafon.lightBmp=priorBitmap;
         }
      }
      /** Native checkPort/alicornPort read only the aimed tile's visibility.
       * Borrow this player's native light value while executing its controls;
       * physical tiles and the host's display grid remain the real originals. */
      public function withCursorLight(x:Number,y:Number,operation:Function):void {
         var room:Object=actor.unit.loc;
         if(actor.id==0 || room==null || !room.black || room.sky){operation();return;}
         var record:Object=rooms[room];
         if(record==null || record.lit===true){update();record=rooms[room];}
         var ix:int=Math.floor(x/40),iy:int=Math.floor(y/40);
         if(record==null || record.space==null || ix<0 || iy<0 || ix>=room.spaceX || iy>=room.spaceY){operation();return;}
         var tile:Object=room.space[ix][iy],before:Number=tile.visi;
         try {tile.visi=record.space[ix][iy].visi;operation();}
         finally {tile.visi=before;}
      }
      public function visible(target:Object):Boolean {
         if(target==null || target.loc!==actor.unit.loc)return false;
         var room:Object=target.loc;
         if(!room.black)return true;
         if(actor.id==0)return Boolean(target.getTileVisi());
         var record:Object=rooms[room];if(record==null || record.lit===true){update();record=rooms[room];}
         var x:int=Math.floor(target.X/40),y:int=Math.floor((target.Y-target.scY/2)/40);
         return record!=null && record.space!=null && x>=0 && y>=0 && x<room.spaceX && y<room.spaceY && record.space[x][y].visi>.3;
      }
      public function dispose():void {rooms=new Dictionary(true);if(bitmap!=null){bitmap.dispose();bitmap=null;}}
   }
}
