package authority {
   import flash.utils.getQualifiedClassName;
   /** Geometry of an isolated test lane. Never called outside an explicit probe. */
   public final class ProbeArena {
      public static function floor(room:Object,wallX:int=-1):Number {
         var fy:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((fy+1)/40);
         // Random maps may leave a box or a disabled enemy in the test lane.
         // Native door closing and mine sight correctly still see that obstacle.
         var old:Object=room.firstObj,next:Object;
         while(old!=null){
            next=old.nobj;
            // Native particles own bitmap surfaces and per-emitter quotas.
            // Their own teardown must run when resetting an isolated fixture.
            old.remVisual();
            if(getQualifiedClassName(old)=="fe.graph::Part")old.setNull();else room.remObj(old);
            old=next;
         }
         var players:Array=[];
         for each(old in room.units)if(old!=null){if(old.player)players.push(old);else {old.disabled=true;old.remVisual();}}
         room.units=players;room.objs=[];room.acts=[];room.bonuses=[];
         for(var x:int=1;x<room.spaceX-1;x++)for(var y:int=1;y<=row;y++) {
            var t:Object=room.space[x][y];t.phis=y==row || x==wallX?1:0;
            t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;t.visi=t.t_visi=1;
            t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
            if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
         }
         room.black=false;room.visMult=1;room.isRebuild=true;return fy;
      }
   }
}
