package defensecheck {
   import fe.unit.Unit;
   public dynamic class DynamicUnit extends Unit {
      public var traceCalls:Array=[];
      public function get extension():* {traceCalls.push("extension");return undefined;}
      public function get failingExtension():* {traceCalls.push("failingExtension");throw new Error("fixture extension");}
   }
}
