package authority {
   /** Geometry of an isolated test lane. Never called outside an explicit probe. */
   public final class ProbeArena {
      public static function floor(room:Object,wallX:int=-1):Number {
         var fy:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((fy+1)/40);
         for each(var old:Object in room.units)if(old!=null && !old.player){old.disabled=true;old.remVisual();}
         for(var x:int=1;x<room.spaceX-1;x++)for(var y:int=1;y<=row;y++) {
            var t:Object=room.space[x][y];t.phis=y==row || x==wallX?1:0;
            t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;t.visi=t.t_visi=1;
            t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
            if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
         }
         room.black=false;return fy;
      }
   }
}
