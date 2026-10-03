package fe.unit {
   public class FeedbackProbe {
      public static function read(unit:Unit):Object {
         var part:Object=unit.hitPart;
         return {ticks:unit.t_hitPart,sum:unit.hitSumm,stack:unit.visDamDY,
            liv:part==null?-1:part.liv,chain:part!=null && part.in_chain,
            text:part==null || part.vis==null?null:part.vis.numb.text};
      }
   }
}
