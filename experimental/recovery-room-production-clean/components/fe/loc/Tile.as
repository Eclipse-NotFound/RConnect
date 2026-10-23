package fe.loc {
 public class Tile {
      public static var tileX:* = 40;
      
      public static var tileY:* = 40;
      
      public var X:int;
      
      public var Y:int;
      
      public var indestruct:Boolean = false;
      
      public var phis:int = 0;
      
      public var shelf:Boolean = false;
      
      public var hp:int = 1000;
      
      public var thre:int = 0;
      
      public var phX1:Number;
      
      public var phX2:Number;
      
      public var phY1:Number;
      
      public var phY2:Number;
      
      public var zForm:int = 0;
      
      public var diagon:int = 0;
      
      public var stair:int = 0;
      
      public var water:int = 0;
      
      public var fake:Boolean = false;
      
      public var t_ghost:int = 0;
      
      public var recalc:Boolean = false;
      
      public var vid:int = 0;
      
      public var vid2:int = 0;
      
      public var front:String = "";
      
      public var back:String = "";
      
      public var zad:String = "";
      
      public var fRear:Boolean = false;
      
      public var vRear:Boolean = false;
      
      public var v2Rear:Boolean = false;
      
      public var visi:Number = 0;
      
      public var t_visi:Number = 0;
      
      public var opac:Number = 0;
      
      public var mat:int = 0;
      
      public var grav:Number = 1;
      
      public var lurk:int = 0;
      
      public var kontur:int = 0;
      
      public var konturRot:int = 0;
      
      public var floor:int = 0;
      
      public var place:Boolean = true;
      
      public var kont1:int = 0;
      
      public var kont2:int = 0;
      
      public var kont3:int = 0;
      
      public var kont4:int = 0;
      
      public var pont1:int = 0;
      
      public var pont2:int = 0;
      
      public var pont3:int = 0;
      
      public var pont4:int = 0;
      
      public var door:Object;
      
      public var trap:Object;
      
      public function Tile(param1:int, param2:int)
      {
         super();
         this.X = param1;
         this.Y = param2;
         this.phX1 = this.X * Tile.tileX;
         this.phX2 = (this.X + 1) * Tile.tileX;
         this.phY1 = this.Y * Tile.tileY;
         this.phY2 = (this.Y + 1) * Tile.tileY;
      }
      
      public var optional:Number = Number.NaN;
      public function setZForm(param1:int) : *
      {
         if(param1 < 0)
         {
            param1 = 0;
         }
         if(param1 > 3)
         {
            param1 = 3;
         }
         this.zForm = param1;
         this.phY1 = (this.Y + this.zForm / 4) * Tile.tileY;
         if(param1 > 0)
         {
            this.opac = 0;
         }
      }
      

 }
}
