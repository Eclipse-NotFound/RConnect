package fe.unit {
   /** Extra same-faction player sensor. Match native Mine.control cadence and
    * fuse countdown; provenance/policy are supplied by the room owner. */
   public final class RConnectMineAccess {
      public static function detect(mine:Mine,body:Unit):void {
         var m:Object=mine,u:Object=body;
         if(m.disabled||m.sost>=3||m.reloadTime>0||mine.aiState!=1||m.oduplenie>0||m.sens<=0
            ||(mine.aiN+1)%4!=0||!m.isMeet(body)||u.activateTrap==0||u.sost==3||u.fraction==0)return;
         if(u.X-m.X>=m.sens||u.X-m.X<=-m.sens||u.Y-m.Y>=m.sens*0.4||u.Y-m.Y<=-m.sens
            ||m.tipDamage==8&&u.vulner[8]<=0)return;
         if(m.otschet>0&&u.activateTrap==1){m.otschet--;return;}
         m.activate();
      }
   }
}
