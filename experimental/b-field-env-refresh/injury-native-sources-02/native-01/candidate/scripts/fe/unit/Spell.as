package fe.unit
{
   // PI_HOOK_V1: PermanentInjury optional exact-event bridge.
   import fe.*;
   import fe.graph.Emitter;
   import fe.loc.Location;
   import fe.loc.Tile;
   
   public class Spell
   {
      
      public var owner:Unit;
      
      public var gg:UnitPlayer;
      
      public var loc:Location;
      
      public var id:String;
      
      public var nazv:String;
      
      public var xml:XML;
      
      public var player:Boolean = false;
      
      public var X:Number = 0;
      
      public var Y:Number = 0;
      
      public var cx:Number = 0;
      
      public var cy:Number = 0;
      
      public var power:Number = 1;
      
      public var prod:Boolean = false;
      
      public var atk:Boolean = false;
      
      public var active:Boolean = false;
      
      public var teleSpell:Boolean = false;
      
      internal var est:int = 1;
      
      public var magic:Number = 0;
      
      public var dmagic:Number = 0;
      
      public var mana:Number = 0;
      
      public var dmana:Number = 0;
      
      public var culd:int = 0;
      
      public var t_culd:int = 0;
      
      public var hp:Number = 300;
      
      public var dist:Number = 0;
      
      public var rad:Number = 0;
      
      public var dam:Number = 0;
      
      public var line:int = 0;
      
      public var cf:Function;
      
      public var snd:String;
      
      public function Spell(param1:Unit, param2:String)
      {
         var own:Unit = param1;
         var nid:String = param2;
         super();
         this.id = nid;
         this.owner = own;
         if(Boolean(this.owner) && this.owner.player)
         {
            this.player = true;
            this.gg = this.owner as UnitPlayer;
         }
         this.xml = AllData.d.item.(@id == id)[0];
         if(this.xml.@hp.length())
         {
            this.hp = this.xml.@hp;
         }
         if(this.xml.@mana.length())
         {
            this.mana = this.xml.@mana;
         }
         if(this.xml.@magic.length())
         {
            this.magic = this.xml.@magic;
         }
         if(this.xml.@culd.length())
         {
            this.culd = this.xml.@culd * World.fps;
         }
         if(this.xml.@dist.length())
         {
            this.dist = this.xml.@dist;
         }
         if(this.xml.@line.length())
         {
            this.line = this.xml.@line;
         }
         if(this.xml.@rad.length())
         {
            this.rad = this.xml.@rad;
         }
         if(this.xml.@dam.length())
         {
            this.dam = this.xml.@dam;
         }
         if(this.xml.@prod.length())
         {
            this.prod = true;
         }
         if(this.xml.@tele.length())
         {
            this.teleSpell = true;
         }
         if(this.xml.@atk.length())
         {
            this.atk = true;
         }
         this.nazv = Res.txt("i",this.id);
         if(this.xml.@snd.length())
         {
            this.snd = this.xml.@snd;
         }
         if(this.id == "sp_mwall")
         {
            this.cf = this.cast_mwall;
         }
         if(this.id == "sp_mshit")
         {
            this.cf = this.cast_mshit;
         }
         if(this.id == "sp_blast")
         {
            this.cf = this.cast_blast;
         }
         if(this.id == "sp_kdash")
         {
            this.cf = this.cast_kdash;
         }
         if(this.id == "sp_slow")
         {
            this.cf = this.cast_slow;
         }
         if(this.id == "sp_cryst")
         {
            this.cf = this.cast_cryst;
         }
         if(this.id == "sp_moon")
         {
            this.cf = this.cast_moon;
         }
         if(this.id == "sp_gwall")
         {
            this.cf = this.cast_gwall;
         }
         if(this.id == "sp_invulner")
         {
            this.cf = this.cast_invulner;
         }
      }
      
      public function step() : *
      {
         if(this.t_culd > 0)
         {
            --this.t_culd;
         }
      }
      
      public function cast(param1:Number = 0, param2:Number = 0) : Boolean
      {
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         if(this.cf == null)
         {
            return false;
         }
         if(this.player)
         {
            if(World.w.alicorn && this.id != "sp_mshit")
            {
               return false;
            }
            if(this.gg.rat > 0)
            {
               return false;
            }
            if(Boolean(this.gg.invent.weapons[this.id]) && this.gg.invent.weapons[this.id].respect == 1)
            {
               World.w.gui.infoText("disSpell",null,null,false);
               Snd.ps("nomagic");
               return false;
            }
            if(World.w.pers.spellsPoss == 0 || this.atk && !this.gg.atkPoss)
            {
               World.w.gui.infoText("noSpells",null,null,false);
               Snd.ps("nomagic");
               World.w.gui.bulb(this.owner.X,this.owner.Y);
               return false;
            }
            if(this.t_culd > 0)
            {
               if(!this.active)
               {
                  if(this.culd >= 100)
                  {
                     World.w.gui.infoText("spellCuld",Math.ceil(this.t_culd / World.fps),null,false);
                     World.w.gui.bulb(this.owner.X,this.owner.Y - 20);
                  }
                  Snd.ps("nomagic");
               }
               return false;
            }
            this.dmagic = this.magic * World.w.pers.allDManaMult * World.w.pers.piFactor("mpCost");
            this.dmana = this.mana * World.w.pers.allDManaMult;
            if(this.dmagic > 999)
            {
               this.dmagic = 999;
            }
            if(this.owner.mana < this.dmagic)
            {
               World.w.gui.infoText("overMana",null,null,false);
               Snd.ps("nomagic");
               World.w.gui.bulb(this.owner.X,this.owner.Y - 20);
               return false;
            }
            if(this.dmana > World.w.pers.manaHP)
            {
               World.w.gui.infoText("noMana",null,null,false);
               Snd.ps("nomagic");
               return false;
            }
         }
         if(this.owner)
         {
            this.X = this.owner.magicX;
            this.Y = this.owner.magicY;
            this.loc = this.owner.loc;
            this.power = this.owner.spellPower;
            if(this.player && this.teleSpell)
            {
               this.power = this.gg.pers.telePower;
            }
         }
         else
         {
            this.loc = World.w.loc;
         }
         this.cx = param1;
         this.cy = param2;
         if(Boolean(this.line == 1) && Boolean(this.owner) && !this.owner.loc.isLine(this.X,this.Y,this.cx,this.cy))
         {
            if(this.player)
            {
               World.w.gui.infoText("noVisible",null,null,false);
            }
            return false;
         }
         if(this.dist > 0)
         {
            _loc3_ = (this.X - this.cx) * (this.X - this.cx) + (this.Y - this.cy) * (this.Y - this.cy);
            if(_loc3_ > this.dist * this.dist)
            {
               _loc4_ = Math.sqrt(_loc3_);
               this.cx = this.X - (this.X - this.cx) * this.dist / _loc4_;
               this.cy = this.Y - (this.Y - this.cy) * this.dist / _loc4_;
            }
         }
         this.cf();
         if(this.est == 1)
         {
            if(this.player)
            {
               this.gg.manaSpell(this.magic * this.gg.pers.warlockDManaMult,this.mana * this.gg.pers.warlockDManaMult);
               this.t_culd = Math.round(this.culd * this.gg.pers.spellDown);
            }
            if(this.snd)
            {
               Snd.ps(this.snd,this.X,this.Y);
            }
         }
         else if(this.est == 0)
         {
            Snd.ps("nomagic");
            return false;
         }
         return true;
      }
      
      internal function cast_mwall() : *
      {
         var _loc1_:Unit = this.loc.createUnit("mwall",this.cx,this.cy + 60,true);
         if(this.owner)
         {
            _loc1_.fraction = this.owner.fraction;
         }
         _loc1_.maxhp = this.hp * this.power;
         _loc1_.hp = _loc1_.maxhp;
      }
      
      internal function cast_mshit() : *
      {
         if(this.owner.player && World.w.alicorn)
         {
            this.owner.shithp = World.w.pers.alicornShitHP;
         }
         else
         {
            this.owner.shithp = this.hp * this.power;
         }
      }
      
      internal function cast_cryst() : *
      {
         this.est = 1;
         if(this.player)
         {
            if(this.gg.t_cryst > 0)
            {
               this.est = 2;
            }
            this.gg.t_cryst = 5;
         }
      }
      
      internal function cast_kdash() : *
      {
         var _loc4_:Object = null;
         if(!this.owner.loc.levitOn)
         {
            return;
         }
         var _loc1_:Number = this.cx - this.owner.X;
         var _loc2_:Number = this.cy - this.owner.Y + this.owner.scY;
         var _loc3_:Number = Math.sqrt(_loc1_ * _loc1_ + _loc2_ * _loc2_);
         _loc4_ = {
            "x":_loc1_,
            "y":_loc2_
         };
         var _loc5_:Number = this.dam * (1 + (this.power - 1) * 0.5);
         var _loc6_:int = 15;
         if(_loc5_ > _loc3_ / _loc6_)
         {
            _loc6_ = Math.round(_loc3_ / _loc5_) + 1;
         }
         if(_loc6_ < 7)
         {
            _loc6_ = 7;
         }
         this.owner.norma(_loc4_,_loc5_);
         this.owner.isLaz = 0;
         this.owner.levit = 0;
         this.owner.dx += _loc4_.x;
         this.owner.dy += _loc4_.y;
         if(this.player)
         {
            this.gg.kdash_t = _loc6_;
            this.gg.t_levitfilter = 20;
         }
      }
      
      internal function cast_blast() : *
      {
         var _loc1_:Unit = null;
         var _loc2_:Number = NaN;
         var _loc3_:Number = NaN;
         var _loc4_:Number = NaN;
         var _loc5_:Number = NaN;
         if(this.loc == null)
         {
            return;
         }
         this.X = this.owner.X;
         this.Y = this.owner.Y;
         for each(_loc1_ in this.loc.units)
         {
            if(!(_loc1_.fixed || _loc1_.fraction == this.owner.fraction || !this.owner.isMeet(_loc1_)))
            {
               _loc2_ = _loc1_.X - this.X;
               _loc3_ = _loc1_.Y - _loc1_.scY / 2 - this.Y;
               _loc4_ = _loc2_ * _loc2_ + _loc3_ * _loc3_;
               if(_loc4_ <= this.rad * this.rad)
               {
                  _loc4_ = Math.sqrt(_loc4_);
                  _loc5_ = this.dam * this.power * (1 - _loc4_ / this.rad) * (Math.random() * 0.4 + 0.8) * _loc1_.knocked / _loc1_.massa;
                  if(_loc5_ > this.dam * this.power)
                  {
                     _loc5_ = this.dam * this.power;
                  }
                  _loc1_.dx = _loc2_ / _loc4_ * _loc5_;
                  _loc1_.dy = _loc3_ / _loc4_ * _loc5_;
                  _loc1_.stun += Math.floor(Math.random() * this.power * this.dam);
                  _loc1_.t_throw = 30;
               }
            }
         }
         if(this.owner.player)
         {
            this.loc.budilo(this.X,this.Y,500);
         }
         if(this.loc.active)
         {
            Emitter.emit("blast",this.loc,this.X,this.Y);
         }
         if(this.loc.active)
         {
            World.w.quake(Math.random() * 30 - 10,Math.random() * 10 - 5);
         }
      }
      
      internal function cast_slow() : *
      {
         if(this.owner)
         {
            this.owner.addEffect("inhibitor",this.rad * this.power);
         }
      }
      
      internal function cast_moon() : *
      {
         if(this.gg.currentPet != "moon")
         {
            this.gg.pets["moon"].hp = this.gg.pets["moon"].maxhp;
            this.gg.callPet("moon",true);
         }
         else if(this.gg.pet)
         {
            this.gg.pet.heal(this.gg.pet.maxhp);
         }
      }
      
      public function gwall(param1:*, param2:*) : *
      {
         var _loc3_:Tile = this.loc.getAbsTile(param1,param2);
         if(this.loc.testTile(_loc3_))
         {
            _loc3_.phis = 3;
            _loc3_.hp = Math.round(this.hp * this.power);
            _loc3_.mat = 7;
            _loc3_.t_ghost = Math.round(this.dam * this.power);
            World.w.grafon.gwall(_loc3_.X,_loc3_.Y);
            this.est = 1;
         }
         Emitter.emit("gwall",this.loc,(_loc3_.X + 0.5) * Tile.tileX,(_loc3_.Y + 0.5) * Tile.tileY);
      }
      
      internal function cast_gwall() : *
      {
         this.est = 0;
         this.gwall(this.cx,this.cy - 40);
         this.gwall(this.cx,this.cy);
         this.gwall(this.cx,this.cy + 40);
         if(this.est > 0)
         {
            this.loc.t_gwall = World.fps;
         }
      }
      
      internal function cast_invulner() : *
      {
         if(Boolean(this.owner) && this.player)
         {
            if(this.gg.pers.bloodHP <= this.dam * 3)
            {
               this.est = 0;
            }
            else
            {
               this.owner.addEffect("bloodinv");
               this.gg.pers.bloodDamage(this.dam,Unit.D_BLEED);
               this.est = 1;
            }
         }
      }
   }
}

