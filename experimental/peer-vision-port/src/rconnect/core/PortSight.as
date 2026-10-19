package rconnect.core {
   /** Point-only form of native Location.lighting (1.02). Native Tile.visi may
    * retain history when retDark=false, so it cannot alone grant current sight.
    * No tile, exploration array, or renderer is written by this calculation. */
   public class PortSight {
      public static function visible(loc:Object,g:Object,tile:Object):Boolean {
         if(loc==null || g==null || tile==null || Number(tile.visi)<.8)return false;
         var near:Number=Number(loc.lDist1),far:Number=Number(loc.lDist2);
         if(!isFinite(near) || !isFinite(far) || near<0 || far<=near)return false;
         var x:Number=Number(g.X)+Number(g.storona)*12;
         var y:Number=Number(g.Y1)+Number(g.stayY)*.247;
         var dx:Number=int(tile.X)*40-x,dy:Number=int(tile.Y)*40-y;
         var distance:Number=Math.sqrt(dx*dx+dy*dy);
         var light:Number=distance<=near?1:(far-distance)/(far-near);
         if(!isFinite(light) || light<.8)return false;
         if(Math.abs(dx)==Math.abs(dy))dy++;
         var sx:Number,sy:Number,steps:Number;
         if(Math.abs(dx)>=Math.abs(dy)) {sx=dx>0?40:-40;sy=sx*dy/dx;steps=dx/sx;}
         else {sy=dy>0?40:-40;sx=sy*dx/dy;steps=dy/sy;}
         if(!isFinite(steps) || steps>200)return false;
         for(var i:int=1;i<=steps;i++) {
            var p:Object=loc.getAbsTile(x+i*sx,y+i*sy);
            if(p==null)return false;
            var opacity:Number=Number(p.opac);
            if(Number(loc.opacWater)>opacity && Number(p.water)>0)opacity=Number(loc.opacWater);
            if(!isFinite(opacity))return false;
            if(opacity>0)light-=opacity;
            if(light<.8)return false;
         }
         return true;
      }
   }
}
