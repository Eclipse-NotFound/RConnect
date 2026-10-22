package defensecheck {
   import fe.Pt;
   public class PointGetter extends Pt {
      public var traceCalls:Array=[];
      public function get skin():Number {traceCalls.push("skin");return 12;}
      public function get armor():* {traceCalls.push("armor");throw new Error("fixture point armor");}
   }
}
