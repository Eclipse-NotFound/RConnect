package fe.unit {
   import fe.Obj;
   // Slot/hierarchy fixture only. Not a game constructor or production declaration.
   public class Unit extends Obj {
      public var maxhp:Number=0;
      public var skin:Number=0;
      public var armor:Number=0;
      public var marmor:Number=0;
      public var armor_hp:Number=0;
      public var armor_maxhp:Number=0;
      public var armor_qual:Number=0;
      public var shithp:Number=0;
      public var shitArmor:Number=0;
      public var allVulnerMult:Number=0;
      public var vulner:Array=null;
      public var dexter:Number=0;
      public var dexterPlus:Number=0;
      public var dodge:Number=0;
      public var invulner:Boolean=false;
      public var transp:Boolean=false;
      public var opt:Object=null;
      public var mech:Boolean=false;
      public var blood:int=0;
      public var mat:int=0;
      public var maxShok:int=0;
      public var showNumbs:Boolean=false;
      public var levit_max:*=0;
      public var massaMove:Number=1;
      public var levit_r:int=0;
      public var t_throw:int=0;
      public var isFly:Boolean=false;
      public var isLaz:int=0;
      public var npc:Boolean=false;
      public var noAgro:Boolean=false;
   }
}
