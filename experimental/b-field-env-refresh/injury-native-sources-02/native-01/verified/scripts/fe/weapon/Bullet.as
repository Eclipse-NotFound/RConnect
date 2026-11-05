package fe.weapon
{
   import fe.*;
   import fe.graph.Emitter;
   import fe.loc.*;
   import fe.unit.Mine;
   import fe.unit.Unit;
   import fe.unit.UnitMsp;
   
   public class Bullet extends Obj
   {
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      protected var vse:Boolean = false;
      
      public var owner:Unit;
      
      public var weap:Weapon;
      
      public var weapId:String;
      
      public var tipBullet:int = 0;
      
      public var rot:Number = 0;
      
      public var vel:Number = 15;
      
      public var liv:int = 100;
      
      public var begx:Number;
      
      public var begy:Number;
      
      public var knockx:Number;
      
      public var knocky:Number;
      
      public var ddy:Number = 0;
      
      public var ddx:Number = 0;
      
      public var accel:Number = 0;
      
      public var brakeR:Number = 0;
      
      public var vRot:Boolean = false;
      
      public var celX:Number = -100000;
      
      public var celY:Number = -100000;
      
      public var inWater:int = -1;
      
      public var isExpl:Boolean = false;
      
      public var partEmit:Boolean = true;
      
      public var spring:int = 1;
      
      public var flame:int = 0;
      
      public var flare:String;
      
      public var outspace:Boolean = false;
      
      public var otbros:* = 0;
      
      public var probiv:Number = 0;
      
      public var parr:Array;
      
      public var babah:Boolean = false;
      
      public var tilehit:Boolean = false;
      
      public var off:Boolean = false;
      
      public var checkLine:Boolean = false;
      
      public var dist:Number = 0;
      
      public var destroy:Number = 0;
      
      public var crack:int = 0;
      
      internal var box:Box;
      
      public var tileX:int = -1;
      
      public var tileY:int = -1;
      
      public var damage:Number = 0;
      
      public var pier:Number = 0;
      
      public var armorMult:Number = 1;
      
      public var tipDamage:int = 0;
      
      public var tipDecal:int = 0;
      
      public var precision:Number = 0;
      
      public var antiprec:Number = 0;
      
      public var miss:Number = 0;
      
      public var desintegr:Number = 0;
      
      public var critCh:Number = 0;
      
      public var critInvis:Number = 0;
      
      public var critDamMult:Number = 1;
      
      public var critM:Number = 0;
      
      public var explTip:int = 1;
      
      public var explKol:int = 0;
      
      public var explPeriod:int = 10;
      
      public var damageExpl:Number = 0;
      
      public var explRadius:Number = 0;
      
      public var targetObj:Obj;
      
      public var inWall:Boolean = false;
      
      internal var expl_t:int = 0;
      
      public var retDam:Boolean = false;
      
      public var piShot:Number = 0;
      
      public function Bullet(param1:Unit, param2:Number, param3:Number, param4:Class = null, param5:Boolean = true)
      {
         super();
         if(param1 == null)
         {
            this.owner = new Unit();
            loc = World.w.loc;
         }
         else
         {
            this.owner = param1;
            loc = param1.loc;
         }
         X = this.begx = param2;
         Y = this.begy = param3;
         sloy = 2;
         levitPoss = false;
         if(param4)
         {
            if(World.w.alicorn && param1.player && param4 == visualBullet)
            {
               param4 = visualRainbow;
            }
            vis = new param4();
            vis.stop();
            vis.x = X;
            vis.y = Y;
            vis.visible = false;
         }
         if(param5)
         {
            loc.addObj(this);
         }
      }
      
      override public function step() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         if(!this.babah)
         {
            dy += this.ddy;
            dx += this.ddx;
            if(this.vRot)
            {
               this.rot = Math.atan2(dy,dx);
            }
            if(Boolean(this.brakeR) && this.dist > this.brakeR)
            {
               this.vRot = true;
               dx *= 0.9;
               dy *= 0.9;
               this.vel *= 0.9;
            }
            if(this.vRot)
            {
               this.rot = Math.atan2(dy,dx);
            }
            if(Math.abs(dx) < World.maxdelta && Math.abs(dy) < World.maxdelta)
            {
               this.run();
            }
            else
            {
               _loc1_ = Math.floor(Math.max(Math.abs(dx),Math.abs(dy)) / World.maxdelta) + 1;
               _loc2_ = 0;
               while(_loc2_ < _loc1_ && !this.babah)
               {
                  this.run(_loc1_);
                  _loc2_++;
               }
            }
         }
         if(vis)
         {
            vis.x = X;
            vis.y = Y;
            vis.rotation = this.rot * 180 / Math.PI;
            if(Boolean(vis.laser) && this.spring >= 2)
            {
               vis.laser.scaleX = Math.sqrt((X - this.begx) * (X - this.begx) + (Y - this.begy) * (Y - this.begy)) / 100;
            }
            else if(this.spring == 1 && this.vel > 100)
            {
               if(!this.babah)
               {
                  vis.scaleX = this.vel / 100;
               }
            }
            else
            {
               vis.scaleX = 1;
            }
            vis.visible = true;
            if(this.liv < 4 && Boolean(vis.laser))
            {
               vis.alpha = this.liv / 4;
               if(this.weap)
               {
                  this.weap.getBulXY();
                  vis.x = X + this.weap.bulX - this.begx;
                  vis.y = Y + this.weap.bulY - this.begy;
               }
            }
         }
         if(this.expl_t > 0)
         {
            --this.expl_t;
         }
         else
         {
            --this.liv;
         }
         if(this.expl_t > 0 && this.expl_t % this.explPeriod == 1)
         {
            this.explRun();
         }
         if(this.liv <= 0 && !this.vse && this.explRadius > 0)
         {
            this.explosion();
         }
         if(this.liv <= 0 || loc != this.owner.loc)
         {
            this.vse = true;
         }
         if(this.vse)
         {
            loc.remObj(this);
         }
      }
      
      override public function setNull(param1:Boolean = false) : *
      {
         loc.remObj(this);
      }
      
      override public function err() : String
      {
         if(loc)
         {
            loc.remObj(this);
         }
         return "Error bullet " + (this.owner ? this.owner.nazv : "???") + " " + (this.weap ? this.weap.nazv : "???");
      }
      
      override public function bindMove(param1:Number, param2:Number, param3:Number = -1, param4:Number = -1) : *
      {
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         if(param3 >= 0)
         {
            X = param3;
         }
         if(param4 >= 0)
         {
            Y = param4;
         }
         dx = param1 - X;
         dy = param2 - Y;
         this.vel = Math.sqrt(dx * dx + dy * dy);
         if(Math.abs(dx) < World.maxdelta && Math.abs(dy) < World.maxdelta)
         {
            this.run();
         }
         else
         {
            _loc5_ = Math.floor(Math.max(Math.abs(dx),Math.abs(dy)) / World.maxdelta) + 1;
            _loc6_ = 0;
            while(_loc6_ < _loc5_)
            {
               this.run(_loc5_);
               _loc6_++;
            }
         }
      }
      
      public function accuracy() : Number
      {
         if(this.precision == 0)
         {
            return 1;
         }
         if(this.antiprec > 0 && this.dist < this.antiprec)
         {
            return this.dist / this.antiprec * 0.75 + 0.25;
         }
         return this.precision / this.dist;
      }
      
      public function popadalo(param1:int = 0) : *
      {
         var _loc2_:int = 0;
         if(param1 < 0)
         {
            return;
         }
         if(this.explRadius)
         {
            this.explosion();
            if(vis)
            {
               vis.visible = false;
            }
         }
         else if(this.tipDecal > 0 && this.tipDecal <= 6)
         {
            if(param1 == 1 || param1 == 2 || param1 == 5 || param1 == 7)
            {
               if(vis)
               {
                  vis.gotoAndPlay(2);
               }
               _loc2_ = Math.floor(Math.random() * 5 + this.damage / 5);
               if(World.w.alicorn)
               {
                  _loc2_ *= 0.2;
               }
               if(_loc2_ > 20)
               {
                  _loc2_ = 20;
               }
               Emitter.emit("iskr_bul",loc,X,Y,{
                  "dx":-dx / this.vel * 10,
                  "dy":-dy / this.vel * 10,
                  "kol":_loc2_
               });
               if(this.flare != null && this.flare != "")
               {
                  Emitter.emit(this.flare,loc,X,Y);
               }
            }
            else if(param1 == 3 || param1 == 4)
            {
               if(Boolean(vis) && this.dist < this.vel)
               {
                  vis.scaleX = this.dist / 100;
               }
            }
            else if(Boolean(vis) && this.dist < this.vel)
            {
               vis.visible = false;
            }
         }
         else if(this.flare != null && this.flare != "")
         {
            if(param1 > 0)
            {
               Emitter.emit(this.flare,loc,X,Y);
            }
         }
         if(this.liv > 4)
         {
            this.liv = 4;
         }
         this.babah = true;
      }
      
      public function udar(param1:*) : Boolean
      {
         var _loc2_:* = undefined;
         if(this.parr == null)
         {
            this.parr = new Array(param1);
            return true;
         }
         for(_loc2_ in this.parr)
         {
            if(this.parr[_loc2_] == param1)
            {
               return false;
            }
         }
         this.parr.push(param1);
         return true;
      }
      
      public function run(param1:int = 1) : *
      {
         var _loc2_:Unit = null;
         var _loc3_:Tile = null;
         var _loc4_:* = undefined;
         this.dist += this.vel / param1;
         X += dx / param1;
         Y += dy / param1;
         if(loc.sky)
         {
            if(X < 0 || X >= loc.limX || Y < 0 || Y >= loc.limY)
            {
               this.popadalo(0);
            }
         }
         else
         {
            if(!this.outspace && X < 0 || X >= loc.spaceX * Tile.tileX || Y < 0 || Y >= loc.spaceY * Tile.tileY)
            {
               this.popadalo(0);
            }
            _loc3_ = loc.getAbsTile(X,Y);
            if(_loc3_.water > 0)
            {
               if(this.inWater == 0)
               {
                  if(this.partEmit && (this.tipDamage == Unit.D_BUL || this.tipDamage == Unit.D_PHIS || this.tipDamage == Unit.D_BLADE))
                  {
                     Emitter.emit("kap",loc,X,Y,{
                        "dx":-dx / this.vel * 10,
                        "dy":-dy / this.vel * 10,
                        "kol":Math.floor(Math.random() * 5 + this.damage / 5)
                     });
                     this.sound(11);
                     this.partEmit = false;
                  }
               }
               if(this.tipDamage == Unit.D_FIRE || this.tipDamage == Unit.D_LASER || this.tipDamage == Unit.D_PLASMA || this.tipDamage == Unit.D_SPARK || this.tipDamage == Unit.D_ACID)
               {
                  if(this.partEmit)
                  {
                     Emitter.emit("steam",loc,X,Y);
                     this.partEmit = false;
                  }
                  this.popadalo(0);
               }
               this.inWater = 1;
            }
            else
            {
               if(this.inWater == 1)
               {
                  if(this.partEmit && (this.tipDamage == Unit.D_BUL || this.tipDamage == Unit.D_PHIS || this.tipDamage == Unit.D_BLADE))
                  {
                     Emitter.emit("kap",loc,X,Y,{
                        "dx":dx / this.vel * 10,
                        "dy":dy / this.vel * 10,
                        "kol":Math.floor(Math.random() * 5 + this.damage / 5)
                     });
                     this.sound(11);
                     this.partEmit = false;
                  }
               }
               this.inWater = 0;
            }
            if(!this.tilehit && (this.tileX < 0 || Math.floor(X / World.tileX) == this.tileX && Math.floor(Y / World.tileY) == this.tileY) && (_loc3_.phis == 1 || _loc3_.phis == 2 && Math.floor(X / World.tileX) == this.tileX && Math.floor(Y / World.tileY) == this.tileY) && X >= _loc3_.phX1 && X <= _loc3_.phX2 && Y >= _loc3_.phY1 && Y <= _loc3_.phY2)
            {
               if(!this.inWall)
               {
                  this.popadalo(_loc3_.mat);
                  this.sound(_loc3_.mat);
                  if(this.weap)
                  {
                     this.weap.crash();
                  }
                  this.owner.crash(this);
                  if(this.explRadius == 0)
                  {
                     loc.hitTile(_loc3_,this.destroy,X,Y,this.tipDecal);
                  }
                  this.tilehit = true;
               }
            }
            else
            {
               this.inWall = false;
            }
         }
         if(this.off)
         {
            return;
         }
         for each(_loc2_ in loc.units)
         {
            if(this.targetObj)
            {
               if(!(this.targetObj is Unit))
               {
                  break;
               }
               _loc2_ = this.targetObj as Unit;
            }
            if(!(_loc2_.sost == 4 || _loc2_.disabled || _loc2_.trigDis || _loc2_.loc != loc))
            {
               if(Unit.rconnectAllowed(this.owner,_loc2_,this.targetObj || _loc2_.fraction != this.owner.fraction) && X >= _loc2_.X1 && X <= _loc2_.X2 && Y >= _loc2_.Y1 && Y <= _loc2_.Y2)
               {
                  if(this.checkLine && Boolean(this.weap) && !this.weap.isLine(X,Y))
                  {
                     this.off = true;
                     return;
                  }
                  if(_loc2_.dopTestOn)
                  {
                     if(!_loc2_.dopTest(this))
                     {
                        continue;
                     }
                  }
                  if(this.udar(_loc2_))
                  {
                     _loc4_ = _loc2_.udarBullet(this);
                     this.sound(_loc4_);
                     if(!(this.probiv > 0 && this.damage > 0))
                     {
                        if(_loc4_ >= 0)
                        {
                           this.popadalo(_loc4_);
                           if(this.weap)
                           {
                              if((_loc2_ is Mine || _loc2_ is UnitMsp) && _loc2_.sost > 2)
                              {
                                 this.weap.crash(15);
                              }
                              else if(_loc2_.tipDamage == Unit.D_ACID)
                              {
                                 this.weap.crash(3);
                              }
                              else
                              {
                                 this.weap.crash();
                              }
                           }
                           break;
                        }
                     }
                  }
               }
               if(this.targetObj)
               {
                  break;
               }
            }
         }
         if(loc.celObj && loc.celObj is Box && this.crack && Boolean(this.owner) && this.owner.player)
         {
            this.box = loc.celObj as Box;
            if(X >= this.box.X1 && X <= this.box.X2 && Y >= this.box.Y1 && Y <= this.box.Y2 && this.udar(this.box))
            {
               _loc4_ = this.box.udarBullet(this,1);
               this.sound(_loc4_);
               if(_loc4_ >= 0)
               {
                  this.popadalo(_loc4_);
                  if(this.weap)
                  {
                     this.weap.crash();
                  }
               }
               if(this.box.dead && Boolean(this.weap))
               {
                  this.weap.crash(this.box.montdam);
               }
            }
         }
         if(World.w.gg.loc == loc && World.w.gg.teleObj && World.w.gg.teleObj is Box && this.owner != World.w.gg)
         {
            this.box = World.w.gg.teleObj as Box;
            if(X >= this.box.X1 && X <= this.box.X2 && Y >= this.box.Y1 && Y <= this.box.Y2 && this.udar(this.box))
            {
               _loc4_ = this.box.udarBullet(this,0);
               this.sound(_loc4_);
               if(_loc4_ >= 0)
               {
                  this.popadalo(_loc4_);
               }
            }
         }
         if(this.celX > -10000 && this.celY > -10000 && this.explRadius > 0)
         {
            if(Math.abs(this.celX - X) < 50 && Math.abs(this.celY - Y) < 200 && Math.random() < 0.3)
            {
               this.popadalo(100);
            }
         }
      }
      
      internal function sound(param1:int) : *
      {
         if(Boolean(this.weap) && this.weap.sndHit != "")
         {
            Snd.ps(this.weap.sndHit,X,Y);
         }
         if(this.tipDecal <= 0 || this.tipDecal > 6)
         {
            return;
         }
         if(Snd.t_hit <= 0)
         {
            if(param1 == 1)
            {
               Snd.ps("hit_metal",X,Y,0,0.4);
            }
            if(param1 == 2 || param1 == 4 || param1 == 6)
            {
               Snd.ps("hit_concrete",X,Y,0,0.5);
            }
            if(param1 == 3)
            {
               Snd.ps("hit_wood",X,Y,0,0.5);
            }
            if(param1 == 5)
            {
               Snd.ps("hit_glass",X,Y,0,0.5);
            }
            if(param1 == 7)
            {
               Snd.ps("hit_pole",X,Y,0,0.5);
            }
            if(param1 == 10)
            {
               if(this.tipDamage == Unit.D_BUL)
               {
                  Snd.ps("hit_bullet",X,Y,0,0.8);
               }
               else if(this.tipDamage == Unit.D_BLADE)
               {
                  Snd.ps("hit_blade",X,Y,0,0.8);
               }
               else
               {
                  Snd.ps("hit_flesh",X,Y,0,0.5);
               }
            }
            if(param1 == 11)
            {
               Snd.ps("hit_water",X,Y,0,0.5);
            }
            if(param1 == 12)
            {
               Snd.ps("hit_slime",X,Y,0,0.5);
            }
            Snd.t_hit = Math.random() * 3 + 3;
         }
      }
      
      public function explosion() : *
      {
         if(this.isExpl)
         {
            return;
         }
         var _loc1_:Tile = loc.getAbsTile(X,Y);
         this.inWall = false;
         this.isExpl = true;
         levitPoss = false;
         if(_loc1_ && _loc1_.phis && X >= _loc1_.phX1 && X <= _loc1_.phX2 && Y >= _loc1_.phY1 && Y <= _loc1_.phY2)
         {
            this.inWall = true;
         }
         if(Boolean(this.targetObj) && this.destroy > 0 && this.targetObj is Box)
         {
            (this.targetObj as Box).damage(this.destroy);
         }
         if(this.explKol <= 0)
         {
            this.explRun();
         }
         else
         {
            this.explRun();
            this.expl_t = (this.explKol - 1) * this.explPeriod;
         }
      }
      
      public function iExpl(param1:Number, param2:Number, param3:Number) : *
      {
         loc = this.owner.loc;
         this.tipDamage = Unit.D_EXPL;
         this.otbros = 10;
         this.damageExpl = param1;
         this.destroy = param2;
         this.explRadius = param3;
         this.explosion();
      }
      
      public function explRun() : *
      {
         if(this.destroy > 0)
         {
            this.explDestroy();
         }
         if(this.explTip == 1 || this.explTip == 3 && this.expl_t == 0)
         {
            this.explBlast();
         }
         if(this.explTip == 2 || this.explTip == 3 && this.expl_t > 0)
         {
            this.explGas();
         }
         this.explVis();
      }
      
      internal function explDestroy() : *
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         var _loc1_:* = Math.floor((X - this.explRadius) / Tile.tileX);
         while(_loc1_ <= Math.floor((X + this.explRadius) / Tile.tileX))
         {
            _loc2_ = Math.floor((Y - this.explRadius) / Tile.tileY);
            while(_loc2_ <= Math.floor((Y + this.explRadius) / Tile.tileY))
            {
               _loc3_ = X - (_loc1_ + 0.5) * Tile.tileX;
               _loc4_ = Y - (_loc2_ + 0.5) * Tile.tileY;
               _loc5_ = _loc3_ * _loc3_ + _loc4_ * _loc4_;
               if(_loc5_ < this.explRadius * this.explRadius)
               {
                  loc.hitTile(loc.getTile(_loc1_,_loc2_),this.destroy,(_loc1_ + 0.5) * Tile.tileX,(_loc2_ + 0.5) * Tile.tileY,this.tipDecal);
               }
               _loc2_++;
            }
            _loc1_++;
         }
      }
      
      internal function explGas() : *
      {
         var _loc1_:Unit = null;
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         for each(_loc1_ in loc.units)
         {
            if(Unit.rconnectAllowed(this.owner,_loc1_,true,"explosion"))
            {
               if(!(_loc1_.sost == 4 || _loc1_.invulner || _loc1_.disabled || _loc1_.trigDis || _loc1_.loc != loc))
               {
                  if(!(this.explTip == 3 && !_loc1_.stay))
                  {
                     _loc2_ = _loc1_.X - X;
                     _loc3_ = _loc1_.Y - _loc1_.scY / 2 - Y;
                     _loc4_ = Math.sqrt(_loc2_ * _loc2_ + _loc3_ * _loc3_);
                     _loc5_ = this.damageExpl * (Math.random() * 0.6 + 0.7);
                     if(Boolean(this.weap) && this.weap.owner.fraction == _loc1_.fraction && _loc1_.fraction != Unit.F_PLAYER)
                     {
                        _loc5_ *= 0.25;
                     }
                     if(_loc4_ < this.explRadius)
                     {
                        if(_loc4_ > this.explRadius * 0.5)
                        {
                           _loc5_ *= 2 - _loc4_ * 2 / this.explRadius;
                        }
                        if(this.weap != null)
                        {
                           _loc1_.dieWeap = this.weap.id;
                        }
                        if(this.weapId != null)
                        {
                           _loc1_.dieWeap = this.weapId;
                        }
                        if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER && _loc1_.player && (Unit.rconnectHitPolicy == null || this.weap.owner == _loc1_))
                        {
                           _loc1_.damage(_loc5_ * World.w.pers.autoExpl,this.tipDamage);
                        }
                        else
                        {
                           _loc1_.damage(_loc5_,this.tipDamage);
                        }
                     }
                  }
               }
            }
         }
      }
      
      internal function explBlast() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         var _loc3_:Unit = null;
         var _loc4_:Bullet = null;
         var _loc5_:* = undefined;
         if(loc != this.owner.loc)
         {
            return;
         }
         for each(_loc3_ in loc.units)
         {
            if(Unit.rconnectAllowed(this.owner,_loc3_,true,"explosion"))
            {
               if(!(_loc3_.sost == 4 || _loc3_.invulner || _loc3_.disabled || _loc3_.trigDis || _loc3_.loc != loc))
               {
                  _loc1_ = _loc3_.X - X;
                  _loc2_ = _loc3_.Y - _loc3_.scY / 2 - Y;
                  _loc4_ = this.explBullet(_loc1_,_loc2_,this.explRadius + _loc3_.scX);
                  if(_loc4_)
                  {
                     _loc4_.targetObj = _loc3_;
                     if(Boolean(this.weap) && this.weap.owner.fraction == _loc3_.fraction && _loc3_.fraction != Unit.F_PLAYER)
                     {
                        _loc4_.damage *= _loc3_.friendlyExpl;
                     }
                     if(_loc3_.player)
                     {
                        if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER && (Unit.rconnectHitPolicy == null || this.weap.owner == _loc3_))
                        {
                           _loc4_.damage *= World.w.pers.autoExpl;
                        }
                        _loc5_ = {
                           "x":_loc4_.knockx,
                           "y":_loc4_.knocky
                        };
                        norma(_loc5_,10);
                        _loc4_.knockx = _loc5_.x;
                        _loc4_.knocky = _loc5_.y;
                     }
                  }
               }
            }
         }
      }
      
      internal function explBullet(param1:Number, param2:Number, param3:Number) : Bullet
      {
         var _loc5_:Bullet = null;
         var _loc4_:* = Math.sqrt(param1 * param1 + param2 * param2);
         if(_loc4_ < param3)
         {
            _loc5_ = new Bullet(this.owner,X,Y,null);
            _loc5_.inWall = this.inWall;
            _loc5_.vel = param3 * (1 + _loc4_ / param3 * 4) / 3;
            _loc5_.dx = param1 / _loc4_ * param3 / 3;
            _loc5_.dy = param2 / _loc4_ * param3 / 3;
            _loc5_.knockx = _loc5_.dx / _loc5_.vel;
            _loc5_.knocky = _loc5_.dy / _loc5_.vel;
            if(!loc.levitOn)
            {
               _loc5_.knockx = _loc5_.knocky = 0;
            }
            _loc5_.damage = this.damageExpl;
            if(_loc4_ > param3 * 0.5)
            {
               _loc5_.damage *= 2 - _loc4_ * 2 / param3;
            }
            _loc5_.otbros = this.otbros;
            _loc5_.pier = this.pier;
            _loc5_.weapId = this.weapId;
            _loc5_.tipDamage = this.tipDamage;
            _loc5_.precision = 0;
            _loc5_.liv = 3;
            _loc5_.weap = this.weap;
            _loc5_.critCh = this.critCh;
            _loc5_.critDamMult = this.critDamMult;
            _loc5_.critInvis = this.critInvis;
         }
         return _loc5_;
      }
      
      internal function explVis() : *
      {
         if(Boolean(this.weap) && Boolean(this.weap.visexpl))
         {
            if(this.weap.visexpl == "sparkle")
            {
               if(this.inWater > 0)
               {
                  loc.budilo(X,Y,700);
                  Emitter.emit("explw",loc,X,Y);
                  Emitter.emit("bubble",loc,X,Y,{
                     "kol":30,
                     "rx":100,
                     "ry":100,
                     "rdx":10,
                     "rdy":10
                  });
                  Snd.ps("expl_uw",X,Y);
               }
               else
               {
                  loc.budilo(X,Y,1500);
                  Emitter.emit("expl",loc,X,Y);
                  Emitter.emit("sparkleexpl",loc,X,Y);
                  Emitter.emit("iskr",loc,X,Y,{"kol":16});
                  Snd.ps("bale_e",X,Y);
               }
            }
            else
            {
               loc.budilo(X,Y,500);
               Emitter.emit(this.weap.visexpl,loc,X,Y);
            }
         }
         else if(this.tipDamage == Unit.D_EMP)
         {
            loc.budilo(X,Y,500);
            Emitter.emit("impexpl",loc,X,Y);
            Snd.ps("emp_e",X,Y);
         }
         else if(this.tipDamage == Unit.D_CRIO)
         {
            loc.budilo(X,Y,500);
            Emitter.emit("iceexpl",loc,X,Y);
            Emitter.emit("snow",loc,X,Y,{"kol":16});
            Snd.ps("cryo_e",X,Y);
         }
         else if(this.tipDamage == Unit.D_PLASMA)
         {
            loc.budilo(X,Y,500);
            Emitter.emit("plaexpl",loc,X,Y);
            Snd.ps("exppla_e",X,Y);
         }
         else if(this.tipDamage == Unit.D_VENOM)
         {
            Emitter.emit("gas",loc,X,Y);
            if(this.expl_t == 0)
            {
               Snd.ps("gas_e",X,Y);
            }
         }
         else if(this.tipDamage == Unit.D_PINK)
         {
            Emitter.emit("pinkgas",loc,X,Y);
            if(this.expl_t == 0)
            {
               Snd.ps("gas_e",X,Y);
            }
         }
         else if(this.tipDamage == Unit.D_ACID)
         {
            if(this.expl_t == 0)
            {
               Emitter.emit("acidexpl",loc,X,Y);
               Emitter.emit("acidkap",loc,X,Y,{"kol":Math.floor(Math.random() * 5 + 30)});
               Snd.ps("acid_e",X,Y);
               this.explLiquid("acid");
            }
         }
         else if(this.tipDamage == Unit.D_BALE)
         {
            loc.budilo(X,Y,3000);
            Emitter.emit("balefire",loc,X,Y - 60);
            Emitter.emit("baleblast",loc,X,Y);
            Snd.ps("bale_e",X,Y);
         }
         else if(this.tipDamage == Unit.D_EXPL)
         {
            if(this.inWater > 0)
            {
               loc.budilo(X,Y,700);
               Emitter.emit("explw",loc,X,Y);
               Emitter.emit("bubble",loc,X,Y,{
                  "kol":30,
                  "rx":100,
                  "ry":100,
                  "rdx":10,
                  "rdy":10
               });
               Snd.ps("expl_uw",X,Y);
            }
            else
            {
               loc.budilo(X,Y,1500);
               Emitter.emit("expl",loc,X,Y);
               Emitter.emit("flare",loc,X,Y);
               Emitter.emit("iskr",loc,X,Y,{"kol":16});
               Snd.ps("expl_e",X,Y);
            }
         }
         else if(this.tipDamage == Unit.D_FIRE)
         {
            if(this.inWater <= 0)
            {
               if(this.expl_t == 0)
               {
                  loc.budilo(X,Y,500);
                  Emitter.emit("fireexpl",loc,X,Y);
                  Emitter.emit("flare",loc,X,Y);
                  Emitter.emit("iskr",loc,X,Y,{"kol":16});
                  Snd.ps("fire_e",X,Y);
                  this.explLiquid("fire",-33);
               }
            }
         }
         if(this.otbros > 0)
         {
            World.w.quake((Math.random() * 8 - 4) * this.otbros,this.otbros * 0.8);
         }
      }
      
      internal function explLiquid(param1:String, param2:int = 0) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:Tile = null;
         var _loc3_:* = Math.floor((X - this.explRadius) / Tile.tileX);
         while(_loc3_ <= Math.floor((X + this.explRadius) / Tile.tileX))
         {
            _loc4_ = Math.floor((Y - this.explRadius) / Tile.tileY);
            while(_loc4_ <= Math.floor((Y + this.explRadius) / Tile.tileY))
            {
               _loc5_ = X - (_loc3_ + 0.5) * Tile.tileX;
               _loc6_ = Y - (_loc4_ + 0.5) * Tile.tileY;
               _loc7_ = _loc5_ * _loc5_ + _loc6_ * _loc6_;
               if(_loc7_ < this.explRadius * this.explRadius)
               {
                  _loc8_ = loc.getTile(_loc3_,_loc4_);
                  if(_loc4_ > 1 && (_loc8_.phis || _loc8_.shelf) && (Boolean(_loc8_.zForm) || loc.getTile(_loc3_,_loc4_ - 1).phis == 0))
                  {
                     Emitter.emit(param1,loc,(_loc3_ + 0.5) * Tile.tileX + Math.random() * 4 - 2,_loc8_.phY1 + param2);
                  }
               }
               _loc4_++;
            }
            _loc3_++;
         }
      }
   }
}

