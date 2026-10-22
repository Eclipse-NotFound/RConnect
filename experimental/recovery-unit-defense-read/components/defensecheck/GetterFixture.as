package defensecheck {
   public class GetterFixture {
      public var traceCalls:Array=[];
      public function get maxhp():Number {traceCalls.push("maxhp");return 100;}
      public function get skin():* {traceCalls.push("skin");throw new Error("fixture skin");}
      public function get armor():* {traceCalls.push("armor");return undefined;}
      public function get marmor():Number {traceCalls.push("marmor");return 7;}
      public function get showNumbs():Boolean {traceCalls.push("showNumbs");return false;}
   }
}
