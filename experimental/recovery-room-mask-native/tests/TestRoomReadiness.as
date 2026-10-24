package {
   /** Wait for configured native travel as well as the network room grant.
    * The initial begin grant may arrive before Session's auto-travel tick. */
   public class TestRoomReadiness {
      public static function ready(mod:RConnectMod,host:Boolean):Boolean {
         if(mod==null || mod.game==null || mod.session==null)return false;
         var b:Object=mod.game,g:Object=b.gg,w:Object=b.world;
         if(g==null || w==null || g.disabled || g.work=="res" || w.onPause
            || (w.vblack.visible && w.vblack.alpha>0))return false;
         if(!mod.session.rooms.ready || mod.session.rooms.busy || b.isTransitioning())return false;
         var info:Object=b.readWorldInfo();
         var wanted:String=String(mod.config.getValue("autoTravelLand") || "");
         if(host && wanted!="" && String(info.curLandId)!=wanted)return false;
         return w.land!=null && w.land.act!=null && String(w.land.act.id)==String(info.curLandId)
            && w.land.loc===b.loc && g.loc===b.loc;
      }
   }
}
