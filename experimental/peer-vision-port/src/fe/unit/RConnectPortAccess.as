package fe.unit {
   /** Native spell calls, with one target's visibility lent only for the
    * synchronous call. No game step, AI, or lighting runs with lent sight. */
   public class RConnectPortAccess {
      public static function controllable(player:Object):Boolean {
         var p:UnitPlayer=player as UnitPlayer;
         return p!=null && !p.lurked && player.ggControl && !player.disabled
            && !player.trigDis && player.t_emerg<=0 && player.sost<3 && player.hp>0
            && player.work!="lurk" && player.work!="unlurk" && player.work!="res";
      }
      public static function cast(player:Object,tile:Object):Boolean {
         var p:UnitPlayer=player as UnitPlayer;
         if(p==null || tile==null)return false;
         var old:Number=Number(tile.visi),ok:Boolean=false;
         try {
            tile.visi=Math.max(old,.8);
            if(player.checkPort()) {p.actPort();ok=true;}
         } finally {tile.visi=old;}
         return ok;
      }
   }
}
