package fe.unit {
   /** Only native feedback counters; never run AI, effects, attacks or death. */
   public class RConnectFeedbackAccess {
      public static function prepare(unit:Unit):void {
         var part:Object=unit.hitPart;
         if(part!=null && (part.liv<=0 || !part.in_chain || part.vis==null || part.vis.parent==null)) {
            unit.hitPart=null;unit.hitSumm=0;unit.t_hitPart=0;
         }
      }
      public static function tick(unit:Unit):void {
         prepare(unit);
         if(unit.t_hitPart>0)unit.t_hitPart--;
         else {unit.hitPart=null;unit.hitSumm=0;}
         if(unit.t_mess>0)unit.t_mess--;
         unit.visDamDY=0;
      }
   }
}
