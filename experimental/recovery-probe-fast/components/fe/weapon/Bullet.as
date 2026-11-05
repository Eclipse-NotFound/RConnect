package fe.weapon {
   public class Bullet extends fe.Obj {
      public var owner:Object;
      public var weap:Object;
      public var babah:Boolean;
      public var isExpl:Boolean;
      public var vel:Number;
      public var explRadius:Number;
      public var spring:int;
      public var flame:int;
      public var parr:Array;
      public var tilehit:Boolean;
      public var tipDecal:int;
      public var inWater:int;
      public var tipDamage:int;
      public var flare:String;
      internal var expl_t:int=0;
   }
}
