package {
   /** Retarget the native high-FPS camera after Sandevistan's manual simulation.
    *  Only display coordinates are interpolated; physics/recordings stay untouched.
    */
   public class SandyHighFpsView {
      public function SandyHighFpsView() {}
      private var lastLoc:Object;
      private var lastWeapon:Object;
      private var wx:Number;
      private var wy:Number;
      private var wr:Number;
      private var ws:Number;

      public function finish(w:Object, alpha:Number, manual:Boolean,
                             oldX:Number, oldY:Number, transition:Boolean):void {
         if (w == null || w.gg == null || w.cam == null) return;
         var c:Object = w.cam;
         var g:Object = w.gg;
         var weapon:Object = null;
         try {
            if (g.currentWeapon != null && g.currentWeapon.krep == 0)
               weapon = g.currentWeapon.vis;
         } catch (noWeapon:*) { }
         if (weapon != null && weapon.parent == null) weapon = null;
         if (manual) {
            // Camera.calc ran before the paused world's manual step. Keep its
            // camera motion, but replace the stale player/weapon endpoints.
            var snap:Boolean = transition || lastLoc !== w.loc || !c.i_has ||
               Math.abs(g.X-oldX)>200 || Math.abs(g.Y-oldY)>200 || g.vis.scaleX != c.i_gsx;
            c.i_gpx = snap ? g.X : oldX; c.i_gpy = snap ? g.Y : oldY;
            c.i_gtx = g.X; c.i_gty = g.Y; c.i_gsx = g.vis.scaleX;
            if (weapon != null) {
               var same:Boolean = !snap && weapon === lastWeapon;
               var tx:Number = weapon.x, ty:Number = weapon.y;
               if (Math.abs(tx-wx)>150 || Math.abs(ty-wy)>150) same=false;
               c.wpVis=weapon;
               c.i_wpx=same?wx:tx; c.i_wpy=same?wy:ty;
               c.i_wtx=tx; c.i_wty=ty;
               var delta:Number=weapon.rotation-wr;
               while(delta>180) delta-=360;
               while(delta< -180) delta+=360;
               c.i_wrok=same && weapon.scaleX==ws && Math.abs(delta)<60;
               c.i_wra=wr; c.i_wrd=delta;
               c.i_wr=weapon.rotation; c.i_wsx=weapon.scaleX;
            } else { c.wpVis=null; c.i_wrok=false; }
         }
         // Save logical endpoints before applyInterp changes the display object.
         lastWeapon=weapon; lastLoc=w.loc;
         if (weapon != null) {
            wx=c.i_wtx; wy=c.i_wty; wr=c.i_wr; ws=weapon.scaleX;
         }
         if (manual) c.applyInterp(alpha);
      }
   }
}