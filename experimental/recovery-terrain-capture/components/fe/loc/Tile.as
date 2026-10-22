package fe.loc
{
   import fe.*;
   
   public class Tile
   {
      
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
      
      public var door:Box;
      
      public var trap:Obj;
      
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
      
      internal function inForm(param1:Form) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.tip == 2)
         {
            if(param1.front)
            {
               this.back = param1.front;
            }
         }
         else
         {
            if(param1.front)
            {
               this.front = param1.front;
               if(param1.rear)
               {
                  this.fRear = true;
               }
            }
            if(param1.back)
            {
               this.zad = param1.back;
            }
         }
         if(param1.vid > 0)
         {
            if(this.vid == 0)
            {
               this.vid = param1.vid;
               if(param1.rear)
               {
                  this.vRear = true;
               }
            }
            else
            {
               this.vid2 = param1.vid;
               if(param1.rear)
               {
                  this.v2Rear = true;
               }
            }
         }
         if(param1.mat)
         {
            this.mat = param1.mat;
         }
         if(param1.hp)
         {
            this.hp = param1.hp;
         }
         if(param1.thre)
         {
            this.thre = param1.thre;
         }
         if(param1.indestruct)
         {
            this.indestruct = true;
         }
         if(param1.lurk)
         {
            this.lurk = param1.lurk;
         }
         if(param1.phis)
         {
            this.phis = param1.phis;
         }
         if(param1.shelf)
         {
            this.shelf = true;
         }
         if(param1.diagon)
         {
            this.diagon = param1.diagon;
         }
         if(param1.stair)
         {
            this.stair = param1.stair;
         }
         if(this.phis > 0)
         {
            this.opac = 1;
         }
      }
      
      public function dec(param1:String, param2:Boolean = false) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:String = null;
         this.phis = this.vid = this.vid2 = this.diagon = this.stair = this.water = 0;
         this.front = this.back = this.zad = "";
         this.shelf = this.indestruct = false;
         this.setZForm(0);
         var _loc3_:int = param1.charCodeAt(0);
         if(_loc3_ > 64 && _loc3_ != 95)
         {
            this.inForm(Form.fForms[param1.charAt(0)]);
         }
         if(param1.length > 1)
         {
            _loc4_ = 1;
            while(_loc4_ < param1.length)
            {
               _loc3_ = param1.charCodeAt(_loc4_);
               _loc5_ = param1.charAt(_loc4_);
               if(_loc5_ == "*")
               {
                  this.water = 1;
               }
               else if(_loc5_ == ",")
               {
                  this.setZForm(1);
               }
               else if(_loc5_ == ";")
               {
                  this.setZForm(2);
               }
               else if(_loc5_ == ":")
               {
                  this.setZForm(3);
               }
               else if(param2 && Boolean(Form.oForms[_loc5_].idMirror))
               {
                  this.inForm(Form.oForms[Form.oForms[_loc5_].idMirror]);
               }
               else
               {
                  this.inForm(Form.oForms[_loc5_]);
               }
               _loc4_++;
            }
         }
         if(this.zForm == 0)
         {
            if(this.zad != "")
            {
               this.back = this.zad;
            }
         }
      }
      
      public function hole() : Boolean
      {
         if(this.phis > 0)
         {
            this.phis = 0;
            return true;
         }
         this.phis = 0;
         return false;
      }
      
      public function updVisi() : Number
      {
         this.visi += 0.1;
         if(this.visi > this.t_visi)
         {
            this.visi = this.t_visi;
         }
         return this.visi;
      }
      
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
      
      public function mainFrame(param1:String = "A") : *
      {
         this.phis = 1;
         this.vid = this.vid2 = this.diagon = this.stair = 0;
         this.mat = Form.fForms[param1].mat;
         this.front = param1;
         this.back = Form.fForms[param1].back;
         this.indestruct = true;
         this.hp = 10000;
         this.opac = 1;
      }
      
      public function getMaxY(param1:Number) : Number
      {
         if(this.diagon == 0)
         {
            return this.phY1;
         }
         if(this.diagon > 0)
         {
            if(param1 < this.phX1)
            {
               return this.phY2;
            }
            if(param1 > this.phX2)
            {
               return this.phY1;
            }
            return this.phY2 - (this.phY2 - this.phY1) * ((param1 - this.phX1) / (this.phX2 - this.phX1));
         }
         if(param1 < this.phX1)
         {
            return this.phY1;
         }
         if(param1 > this.phX2)
         {
            return this.phY2;
         }
         return this.phY2 - (this.phY2 - this.phY1) * ((this.phX2 - param1) / (this.phX2 - this.phX1));
      }
      
      public function udar(param1:int) : Boolean
      {
         if(this.indestruct || this.thre > param1)
         {
            return false;
         }
         this.hp -= param1;
         return true;
      }
      
      public function die() : *
      {
         if(this.phis != 3)
         {
            this.front = "";
         }
         this.phis = 0;
         this.opac = 0;
         this.vid = this.vid2 = 0;
         this.t_ghost = 0;
         if(this.trap)
         {
            this.trap.die();
         }
      }
   }
}

