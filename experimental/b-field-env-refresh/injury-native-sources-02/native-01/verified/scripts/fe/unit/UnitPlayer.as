package fe.unit
{
   import fe.*;
   import fe.graph.Emitter;
   import fe.inter.*;
   import fe.loc.*;
   import fe.serv.Interact;
   import fe.weapon.*;
   import flash.display.MovieClip;
   import flash.filters.BlurFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Point;
   
   public class UnitPlayer extends UnitPon
   {
      
      public static var rconnectIntent:Function = null;
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectDamage:Function = null;
      
      public static var rconnectDeath:Function = null;
      
      public var ctr:Ctr;
      
      public var maxjumpp:int;
      
      public var jumpNumb:int = 0;
      
      public var jumpp:int = 0;
      
      public var downp:int = 0;
      
      public var dash:int = 22;
      
      public var dash_t:int = 0;
      
      public var dash_maxt:int = 30;
      
      public var kdash_t:int = 0;
      
      public var dash_dy:int = -2;
      
      public var osnSpeed:Number;
      
      internal var t_fly:Number = 0;
      
      public var noReanim:Boolean = false;
      
      public var pinok:Number = 0;
      
      public var noStairs:Boolean = false;
      
      public var dstam:Number = 5;
      
      public var levitOn:int = 0;
      
      public var teleObj:Obj;
      
      public var teleSqrtMassa:Number;
      
      public var teleSpeed:Number = 8;
      
      public var teleAccel:Number = 1;
      
      public var maxTeleDist:int = 200;
      
      public var levitup:Boolean = false;
      
      public var ggControl:Boolean = true;
      
      public var actionObj:Interact;
      
      public var t_action:int = 0;
      
      public var mt_action:int = 20;
      
      public var work:String = "";
      
      public var t_work:int = 0;
      
      private var actionReady:Boolean = true;
      
      private var t_stay:int = 3;
      
      private var t_walk:int = 3;
      
      private var t_run:int = 0;
      
      public var runForever:int = 0;
      
      public var h2o:Number = 1000;
      
      public var stam:Number = 1000;
      
      public var possRun:Boolean = true;
      
      public var zaput:int = 0;
      
      public var aJump:int = 0;
      
      internal var weapUp:Boolean = false;
      
      internal var inBattle:Boolean = false;
      
      public var noRad:Boolean = true;
      
      public var dodgePlus:Number = 0;
      
      public var isStayDam:int = 0;
      
      public var dJump:Boolean = false;
      
      public var dJump2:Boolean = false;
      
      public var djumpdy:Number = 5;
      
      public var maxdjumpp:int = 10;
      
      public var isFetter:int = 0;
      
      public var fetX:Number = 0;
      
      public var fetY:Number = 0;
      
      internal var dfx:Number = 0;
      
      internal var dfy:Number = 0;
      
      internal var rfetter:Number = 0;
      
      public var t_raddam:int = 0;
      
      public var t_nogas:int = 0;
      
      internal var ddam1:Number = 0;
      
      internal var ddam2:Number = 0;
      
      internal var ddam3:Number = 0;
      
      public var currentSpell:Spell;
      
      internal var t_dclick:int = 0;
      
      public var t_port:int = 0;
      
      public var t_culd:int = 0;
      
      private var teleReady:Boolean = true;
      
      public var t_cryst:int = 0;
      
      public var cryst:Boolean = false;
      
      public var sneak:Number = 0;
      
      public var obs:Number = 0;
      
      public var maxObs:Number = 20;
      
      internal var minusObs:Number = 0.1;
      
      internal var isObs:int = 0;
      
      public var showObsInd:Boolean = true;
      
      internal var t_up:int = 0;
      
      internal var lurked:Boolean = false;
      
      internal var lurkTip:int = 1;
      
      internal var lurkX:Number = 0;
      
      internal var lurkBox:Box;
      
      public var sats:Sats;
      
      public var invent:Invent;
      
      public var isTake:int = 0;
      
      public var changeWeaponTime1:int = 30;
      
      public var changeWeaponTime2:int = 20;
      
      public var changeWeaponTime3:int = 10;
      
      internal var t_reload:int = 0;
      
      public var punchWeapon:Weapon;
      
      public var throwWeapon:Weapon;
      
      public var magicWeapon:Weapon;
      
      public var paintWeapon:Weapon;
      
      public var newWeapon:Weapon;
      
      public var currentArmor:Armor;
      
      public var prevArmor:String = "";
      
      public var armorEffect:Effect;
      
      public var currentAmul:Armor;
      
      public var atkPoss:int = 1;
      
      public var attackForever:int = 0;
      
      public var autoAttack:int = 0;
      
      public var atkWeapon:int = 0;
      
      public var eyeMind:int = 0;
      
      public var pipOff:int = 0;
      
      public var rad:Number = 0;
      
      public var drad:Number = 0;
      
      public var drad2:Number = 0;
      
      public var radX:Number = 1;
      
      public var healhp:Number = 0;
      
      public var pers:Pers;
      
      public var pet:UnitPet;
      
      public var defpet:UnitPet;
      
      public var pets:Array;
      
      public var currentPet:String = "";
      
      public var retPet:String = "";
      
      public var noPet:int = 0;
      
      public var noPet2:int = 0;
      
      internal var k_pet:int = 0;
      
      public var levitFilter1:GlowFilter;
      
      public var levitFilter2:GlowFilter;
      
      protected var dieFilter:GlowFilter;
      
      protected var shadowFilter:DropShadowFilter;
      
      protected var invulnerFilter1:GlowFilter;
      
      protected var invulnerFilter2:GlowFilter;
      
      internal var dashFilter:BlurFilter;
      
      internal var stealthFilter:BlurFilter;
      
      protected var dieTransform:ColorTransform = new ColorTransform();
      
      protected var teleTransform:ColorTransform = new ColorTransform();
      
      public var shineTransform:ColorTransform = new ColorTransform();
      
      public var t_levitfilter:int = -1;
      
      internal var freeAnim:int = 0;
      
      internal var prev_levit:*;
      
      internal var f_levit:Boolean = false;
      
      internal var f_die:Boolean = false;
      
      internal var f_dash:Boolean = false;
      
      internal var f_stealth:Boolean = false;
      
      internal var f_inv:Boolean = false;
      
      public var f_shad:Boolean = false;
      
      internal var aMagic:int = 50;
      
      internal var aMC:int = 50;
      
      internal var headR:Number = 0;
      
      internal var headRO:Number = 0;
      
      internal var headRA:Number = 0;
      
      internal var t_head:int = 100;
      
      internal var hair:MovieClip;
      
      internal var tail:MovieClip;
      
      internal var hairY:Number = -1000;
      
      internal var hairDY:Number = 0;
      
      internal var hairR:Number = 0;
      
      internal var prev_replic:String;
      
      internal var prev_dx:Number = 0;
      
      public var rat:int = 0;
      
      public var ratX:int = 30;
      
      public var ratY:int = 17;
      
      public var mordaN:int = 1;
      
      public var reloadbar:MovieClip;
      
      internal var showRadius:Boolean = false;
      
      internal var klip:int = 300;
      
      public var visSel:Boolean = false;
      
      public var animOff:Boolean = false;
      
      public function UnitPlayer(param1:String = null, param2:Number = 100, param3:XML = null, param4:Object = null)
      {
         super();
         player = true;
         id = "littlepip";
         vis = new visualPlayer();
         vis.osn.body.pip2.visible = false;
         vis.osn.stop();
         vis.inh.visible = vis.cryst.visible = vis.fetter.visible = vis.rat.visible = false;
         this.reloadbar = new reloadBar();
         this.reloadbar.visible = false;
         vis.addChild(this.reloadbar);
         if(vis.shit)
         {
            vis.shit.visible = false;
         }
         if(vis.svet)
         {
            vis.svet.visible = false;
         }
         storona = 1;
         id_replic = "pip";
         getXmlParam();
         walkSpeed = this.osnSpeed = maxSpeed;
         plavSpeed = walkSpeed * 0.75;
         sitSpeed = walkSpeed * 0.5;
         lazSpeed = walkSpeed * 0.75;
         runSpeed = walkSpeed * 2;
         critCh = 0.05;
         brake = 2;
         this.maxjumpp = 8;
         plavdy = accel * 0.5;
         levidy = accel * 0.25;
         if(World.w.alicorn)
         {
            levidy = accel * 0.5;
         }
         hp = maxhp;
         this.reloadbar.y = -scY - 10;
         weaponKrep = 0;
         teleColor = World.w.app.cMagic;
         this.levitFilter1 = new GlowFilter(teleColor,0,6,6,2,3);
         teleFilter = new GlowFilter(teleColor,1,6,6,1,3);
         this.dieFilter = new GlowFilter(13369599,0,6,6,2,3);
         this.dashFilter = new BlurFilter(5,0,3);
         this.stealthFilter = new BlurFilter(3,3);
         this.shadowFilter = new DropShadowFilter(0,90,0,0.5,3,3,1,3,false,false,true);
         this.teleTransform.redMultiplier = Appear.trMagic.redMultiplier * 0.5 + 1;
         this.teleTransform.greenMultiplier = Appear.trMagic.greenMultiplier * 0.5 + 1;
         this.teleTransform.blueMultiplier = Appear.trMagic.blueMultiplier * 0.5 + 1;
         this.shineTransform.greenMultiplier = 1.5;
         this.shineTransform.blueMultiplier = 1.2;
         this.invulnerFilter1 = new GlowFilter(16733525,1,2,2,3,3);
         this.invulnerFilter2 = new GlowFilter(16711680,1,7,7,1,3);
         doop = true;
         transT = true;
         fraction = F_PLAYER;
      }
      
      internal function testFunction() : *
      {
         if(World.w.chitOn)
         {
            World.w.godMode = true;
            World.w.chit = "port";
            World.w.drawAllMap = true;
            World.w.black = false;
            World.w.showAddInfo = true;
            World.w.grafon.visLight.visible = false;
         }
      }
      
      public function attach() : *
      {
         this.invent = World.w.invent;
         this.invent.gg = this;
         this.invent.owner = this;
         this.invent.addAllSpells();
         this.pers = World.w.pers;
         this.pers.gg = this;
         hp = maxhp = this.pers.begHP;
         if(this.invent.cArmorId != "" && this.invent.cArmorId != null && !World.w.alicorn)
         {
            this.changeArmor(this.invent.cArmorId,true);
         }
         else
         {
            this.pers.setParameters();
         }
         if(this.invent.cAmulId != "" && this.invent.cAmulId != null)
         {
            this.changeArmor(this.invent.cAmulId,true);
         }
         if(!this.pers.dead && this.invent.cWeaponId != "" && this.invent.cWeaponId != null)
         {
            this.changeWeapon(this.invent.cWeaponId);
         }
         if(this.invent.cSpellId != "" && this.invent.cSpellId != null)
         {
            this.changeSpell(this.invent.cSpellId,false);
         }
         this.prevArmor = this.invent.prevArmor;
         this.punchWeapon = new WKick(this,"punch");
         this.paintWeapon = new WPaint(this,"paint");
         childObjs = new Array(currentWeapon,this.punchWeapon);
         if(this.invent.fav[29])
         {
            this.throwWeapon = this.invent.weapons[this.invent.fav[29]];
            this.throwWeapon.setNull();
            this.throwWeapon.setPers(this,this.pers);
         }
         if(this.invent.fav[30])
         {
            this.magicWeapon = this.invent.weapons[this.invent.fav[30]];
            this.magicWeapon.setNull();
            this.magicWeapon.setPers(this,this.pers);
         }
         this.pets = new Array();
         this.pet = new UnitPet("phoenix");
         this.pet.gg = this;
         this.pet.setLevel(this.pers.level);
         this.pets["phoenix"] = this.pet;
         this.defpet = this.pet;
         this.pet = new UnitPet("owl");
         this.pet.gg = this;
         this.pet.setLevel(this.pers.level);
         this.pets["owl"] = this.pet;
         this.pet.hp = this.pet.maxhp * this.pers.owlhpProc;
         if(this.pers.owlhpProc <= 0)
         {
            this.pet.sost = 4;
         }
         this.pet = new UnitPet("moon");
         this.pet.gg = this;
         this.pet.setLevel(this.pers.level);
         this.pets["moon"] = this.pet;
         this.pet = null;
         neujazMax = this.pers.neujazMax;
         if(this.pers.dead)
         {
            hp = 0;
            this.controlOff();
            this.anim("die",true);
         }
         else
         {
            this.currentPet = this.pers.currentPet;
            if(this.currentPet != "" && this.currentPet != null && this.currentPet != "moon")
            {
               this.pet = this.pets[this.currentPet];
               childObjs[2] = this.pet;
               this.rconnectCallPet();
            }
            if(this.currentPet == "moon")
            {
               this.currentPet = "";
            }
            this.invent.nextItem(1);
            weaponLevit();
         }
         World.w.calcMassW = World.w.calcMass = true;
         this.setAddictions();
         if(World.w.alicorn)
         {
            this.alicornOn(false);
         }
         else
         {
            this.pers.setParameters();
         }
      }
      
      override public function setNull(param1:Boolean = false) : *
      {
         Y1 = Y - scY;
         Y2 = Y;
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         this.setWeaponPos();
         if(currentWeapon)
         {
            currentWeapon.setNull();
         }
         this.dropTeleObj();
         this.actionObj = null;
         isLaz = 0;
         levit = 0;
         this.f_stealth = stealthMult < 1;
         this.f_die = this.f_levit = this.f_dash = this.f_inv = false;
         this.setFilters();
         vis.osn.alpha = 1;
         vis.osn.transform.colorTransform = new ColorTransform();
      }
      
      public function setSpeeds() : *
      {
         walkSpeed = this.osnSpeed * this.pers.allSpeedMult;
         if(walkSpeed > this.pers.maxSpeed)
         {
            walkSpeed = this.pers.maxSpeed;
         }
         runSpeed = walkSpeed * this.pers.runSpeedMult;
         if(runSpeed > this.pers.maxSpeed)
         {
            runSpeed = this.pers.maxSpeed;
         }
         runSpeed -= Math.max(0,runSpeed - walkSpeed) * (1 - this.pers.piFactor("runBonus"));
         plavSpeed = walkSpeed * 0.75;
         sitSpeed = walkSpeed * 0.5;
         lazSpeed = walkSpeed * 0.75;
      }
      
      override public function outLoc(param1:int, param2:Number = -1, param3:Number = -1) : Boolean
      {
         if(this.teleObj || this.actionObj || this.t_work > 0 || this.isFetter > 0 || loc.sky)
         {
            return false;
         }
         var _loc4_:int = World.w.possiblyOut();
         if(_loc4_ > 0 && !(param1 == 3 && loc.bezdna) && this.rat == 0)
         {
            if(param1 == 3 && !loc.bezdna)
            {
               dy = -jumpdy;
               dx = maxSpeed * storona;
            }
            if(_loc4_ == 2)
            {
               World.w.gui.infoText("noOutLoc",null,null,false);
            }
            return false;
         }
         var _loc5_:* = isLaz;
         var _loc6_:* = levit;
         var _loc7_:Object = World.w.land.gotoLoc(param1,param2,param3);
         if(_loc7_ != null)
         {
            if(_loc7_.die)
            {
               this.die(-1);
               vis.visible = false;
               return false;
            }
            if(param1 == 3 || param1 == 4)
            {
               if(_loc5_ != 0)
               {
                  checkStairs();
                  if(!isLaz)
                  {
                     checkStairs(1,-Tile.tileX * _loc5_);
                  }
                  if(!isLaz)
                  {
                     checkStairs(1,Tile.tileX * _loc5_);
                  }
               }
            }
            if(param1 == 4)
            {
               if(!isLaz && !isFly && _loc6_ == 0)
               {
                  dy = -jumpdy;
                  dx = maxSpeed * storona;
               }
               else if(isFly || _loc6_ == 1)
               {
                  dy = -jumpdy;
               }
            }
            if(param1 == 5)
            {
               dx = 3 * storona;
            }
            if(this.sats.que.length > 0)
            {
               this.sats.clearAll();
            }
            if(levit == 1 && !this.ctr.keyJump)
            {
               levit = 0;
            }
            return true;
         }
         return false;
      }
      
      public function inLoc(param1:Location) : *
      {
         var _loc2_:* = undefined;
         if(this.pet)
         {
            if(!param1.petOn && loc.petOn)
            {
               World.w.gui.infoText("noPetFollow");
               this.pet.vis.alpha = 0;
               if(this.pet.hpbar)
               {
                  this.pet.hpbar.alpha = this.pet.vis.alpha;
               }
            }
            else
            {
               this.pet.loc = param1;
            }
            param1.units[1] = this.pet;
            this.pet.vis.visible = param1.petOn && this.pet.sost < 3;
         }
         else
         {
            param1.units[1] = this.defpet;
         }
         loc = param1;
         if(currentWeapon)
         {
            currentWeapon.loc = loc;
         }
         if(this.throwWeapon)
         {
            this.throwWeapon.loc = loc;
         }
         if(this.magicWeapon)
         {
            this.magicWeapon.loc = loc;
         }
         cTransform = loc.cTransform;
         this.t_nogas = 90;
         vis.transform.colorTransform = cTransform;
         if(Boolean(currentWeapon) && currentWeapon.tip != 5)
         {
            currentWeapon.vis.transform.colorTransform = cTransform;
         }
         if(effects.length > 0)
         {
            for each(_loc2_ in effects)
            {
               _loc2_.visEff();
            }
         }
         if(!loc.levitOn && isFly)
         {
            isFly = false;
         }
         if(loc.electroDam > 0)
         {
            World.w.gui.infoText("electroOn",null,null,true);
            this.isStayDam = 45;
         }
         vis.svet.visible = loc.sky;
      }
      
      override public function addVisual() : *
      {
         super.addVisual();
         if(this.throwWeapon)
         {
            this.throwWeapon.addVisual2();
         }
         if(this.magicWeapon)
         {
            this.magicWeapon.addVisual2();
         }
      }
      
      public function setLocPos(param1:Number, param2:Number) : *
      {
         X = param1;
         Y = param2;
         this.setNull();
         if(this.pet)
         {
            this.pet.X = X;
            this.pet.Y = Y - 30;
            if(isSit)
            {
               this.pet.Y = Y;
            }
            this.pet.setNull();
            this.pet.oduplenie = 60;
         }
      }
      
      override public function forces() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:Tile = null;
         var _loc3_:Number = Number(NaN);
         grav = 1;
         if(this.kdash_t > 0)
         {
            if(this.kdash_t == 1)
            {
               dx *= 0.3;
               dy *= 0.3;
            }
         }
         else if(isLaz != 0)
         {
            dy = 0;
            dx *= 0.8;
         }
         else if(levit)
         {
            dy *= 0.8;
            dx *= 0.8;
         }
         else if(isFly)
         {
            if(this.ctr.keyRun)
            {
               dy *= 0.96;
               dx *= 0.96;
            }
            else if(t_throw <= 0)
            {
               dy *= 0.9;
               dx *= 0.9;
            }
            this.t_fly += 0.1;
            if(loc.electroDam > 0)
            {
               dy += Math.sin(this.t_fly) * 0.7;
               dx += storona * Math.cos(this.t_fly) * 0.5;
            }
            else
            {
               dy += Math.sin(this.t_fly) / 5;
            }
         }
         else
         {
            _loc1_ = brake;
            if(inWater && !isPlav)
            {
               dx *= 0.5;
            }
            if(isPlav)
            {
               dy += World.ddy * ddyPlav;
               dy *= 0.8;
            }
            else
            {
               _loc2_ = loc.getAbsTile(X,Y - scY / 4);
               if(_loc2_.grav > 0 && dy < loc.maxdy * _loc2_.grav || _loc2_.grav < 0 && dy > loc.maxdy * _loc2_.grav)
               {
                  if(this.dash_t > this.dash_maxt - 11)
                  {
                     dy += World.ddy * _loc2_.grav * 0.1;
                  }
                  else
                  {
                     dy += World.ddy * _loc2_.grav;
                  }
               }
               if(_loc2_.grav > 0)
               {
                  grav = _loc2_.grav;
               }
               else
               {
                  grav = 0;
               }
               if(_loc2_.grav < 0)
               {
                  dx *= 0.8;
               }
            }
            if(isSit)
            {
               _loc1_ = 0.4 * brake;
            }
            if(!stay)
            {
               _loc1_ = 0.1 * brake;
            }
            if(walk < 0)
            {
               if(dx < -maxSpeed)
               {
                  dx += _loc1_;
               }
            }
            else if(walk > 0)
            {
               if(dx > maxSpeed)
               {
                  dx -= _loc1_;
               }
            }
            else if(dx > -_loc1_ && dx < _loc1_)
            {
               dx = 0;
            }
            else if(dx > 0)
            {
               dx -= _loc1_;
            }
            else if(dx < 0)
            {
               dx += _loc1_;
            }
            if(stay)
            {
               dx *= tormoz;
               if(Boolean(loc.quake) && massa <= 2)
               {
                  _loc3_ = (1 + (2 - massa) / 2) * loc.quake;
                  if(_loc3_ > 10)
                  {
                     _loc3_ = 10;
                  }
                  dy = -_loc3_ * Math.random();
                  dx += _loc3_ * (Math.random() * 2 - 1);
               }
            }
         }
         osndx = osndy = 0;
         if(stayOsn)
         {
            if(stayOsn.cdx > 10 || stayOsn.cdx < -10 || stayOsn.cdy > 10 || stayOsn.cdy < -10)
            {
               stay = false;
            }
            else
            {
               osndx = stayOsn.cdx;
               osndy = stayOsn.cdy;
            }
         }
         stayOsn = null;
         if(this.isFetter > 0)
         {
            isLaz = 0;
            this.dfx = this.fetX - X;
            this.dfy = this.fetY - Y + 30;
            this.rfetter = Math.sqrt(this.dfx * this.dfx + this.dfy * this.dfy);
            if(this.rfetter > this.isFetter * 2)
            {
               this.fetX = X;
               this.fetY = Y;
               this.dfx = this.dfy = this.rfetter = 0;
            }
            if(this.rfetter > this.isFetter * 0.95)
            {
               if(this.rfetter > this.isFetter)
               {
                  dx += this.dfx / 20;
                  dy += this.dfy / 20;
               }
               else
               {
                  dx += this.dfx / 20 * (this.rfetter / this.isFetter * 20 - 19);
                  dy += this.dfy / 20 * (this.rfetter / this.isFetter * 20 - 19);
               }
            }
         }
         else
         {
            this.rfetter = 0;
         }
      }
      
      override public function actions() : *
      {
         var _loc2_:Spell = null;
         var _loc3_:Number = Number(NaN);
         super.actions();
         this.inBattle = World.w.t_battle > 0 || World.w.testBattle;
         if(this.isTake > 0)
         {
            --this.isTake;
         }
         if(this.noRad)
         {
            this.noRad = false;
         }
         else
         {
            this.drad += loc.rad;
            if(inWater)
            {
               this.drad += loc.wrad;
            }
         }
         if(this.drad2 > 0)
         {
            this.drad += this.drad2;
            this.drad2 -= 0.1;
         }
         if(this.drad > 0)
         {
            if(this.radX > 0 && !invulner && !World.w.godMode)
            {
               this.rad += this.drad / 30 * this.radX;
               if(this.pers.radChild > 0 && this.rad > maxhp * (1 - this.pers.radChild))
               {
                  this.rad = maxhp * (1 - this.pers.radChild);
               }
               if(hp > maxhp - this.rad)
               {
                  hp = maxhp - this.rad;
                  if(hp <= 0)
                  {
                     this.die();
                  }
               }
               World.w.gui.setHp();
            }
            _loc3_ = Math.min(0.5,this.drad / 10);
            if(this.drad > 0.1 && isrnd(_loc3_))
            {
               sound("geiger");
            }
            if(this.pet)
            {
               this.pet.heal(this.drad / 15,1);
            }
            this.drad = 0;
         }
         else if(this.drad == 0)
         {
            World.w.gui.setHp();
            this.drad = -0.0001;
         }
         if(this.healhp > 0)
         {
            this.healhp -= this.pers.healMult / 5 * this.pers.metaMult * this.pers.piFactor("hpRate");
            hp += this.pers.healMult / 5 * this.pers.metaMult * this.pers.piFactor("hpRate");
            if(hp > maxhp - this.rad)
            {
               hp = maxhp - this.rad;
            }
            World.w.gui.setHp();
         }
         if(this.pers.regenFew > 0 && hp < Math.min(maxhp * this.pers.regenMax,maxhp - this.rad) && hp > 0)
         {
            hp += this.pers.regenFew;
            World.w.gui.setHp();
         }
         if(World.w.alicorn && sost == 1)
         {
            if(hp < maxhp)
            {
               hp += this.pers.alicornHeal;
               if(hp > maxhp)
               {
                  hp = maxhp;
               }
               World.w.gui.setHp();
            }
            if(this.pers.manaHP < this.pers.inMaxMana)
            {
               this.pers.manaHP += this.pers.alicornManaHeal;
               if(this.pers.manaHP > this.pers.inMaxMana)
               {
                  this.pers.manaHP = this.pers.inMaxMana;
               }
               World.w.gui.setMana();
            }
         }
         if(this.t_work > 0)
         {
            --this.t_work;
         }
         else
         {
            this.work = "";
         }
         if(this.work == "change" && this.t_work == this.changeWeaponTime2)
         {
            this.changeWeaponNow(1);
         }
         if(this.work == "change" && this.t_work == this.changeWeaponTime3)
         {
            this.changeWeaponNow(2);
         }
         if(this.work == "lurk" && this.t_work == 10)
         {
            if(sloy == 2)
            {
               if(this.lurkTip == 1)
               {
                  this.chSloy(0);
               }
               else
               {
                  this.chSloy(1);
               }
            }
            if(Boolean(this.lurkBox) && this.lurkBox.sloy == 1 && sloy == 1)
            {
               this.lurkBox.vis.parent.setChildIndex(this.lurkBox.vis,this.lurkBox.vis.parent.numChildren - 1);
            }
         }
         if(this.work == "unlurk" && this.t_work == 5)
         {
            if(sloy == 1 || sloy == 0)
            {
               this.chSloy(2);
            }
         }
         if(this.work == "lurk")
         {
            if(this.lurkX - X > 3)
            {
               dx = 4;
            }
            if(this.lurkX - X < -3)
            {
               dx = -4;
            }
         }
         if(this.lurked)
         {
            if(!stay)
            {
               this.lurked = false;
            }
            if(Boolean(this.lurkBox) && this.lurkBox.wall == 0 && !this.lurkBox.stay)
            {
               this.lurked = false;
            }
            if(this.work != "lurk" && (X - this.lurkX > 10 || X - this.lurkX < -10))
            {
               this.lurked = false;
            }
         }
         if(!this.lurked && this.work != "unlurk" && (sloy == 1 || sloy == 0))
         {
            this.chSloy(2);
         }
         this.f_dash = this.dash_t > this.dash_maxt - 20;
         if(this.dash_t > 0)
         {
            --this.dash_t;
         }
         if(this.kdash_t > 0)
         {
            --this.kdash_t;
            stay = false;
         }
         this.f_stealth = stealthMult < 1;
         if(this.actionObj)
         {
            if(this.actionObj.active == 0)
            {
               this.actionObj = null;
            }
            else if(this.t_action > 0)
            {
               --this.t_action;
            }
            else
            {
               this.ctr.keyAction = false;
               this.actionObj.is_act = true;
               this.actionObj = null;
            }
         }
         if(Snd.actionCh != null && this.actionObj == null)
         {
            Snd.actionCh.stop();
            Snd.actionCh = null;
         }
         visibility = 2000;
         if(dx < 2 && dx > -2 && dy < 2 && dy > -2)
         {
            visibility = 1500;
         }
         if(dx > 10 || dx < -10 || dy > 10 || dy < -10)
         {
            if(demask < 200 * this.pers.visiMult)
            {
               demask = 200 * this.pers.visiMult;
            }
         }
         if(this.obs > 0 && this.isObs <= 0)
         {
            this.obs -= this.minusObs;
         }
         if(this.isObs >= 0)
         {
            --this.isObs;
         }
         if(levit > 0 && demask < 200)
         {
            demask = 200;
         }
         dexterPlus = 0;
         detecting = 80;
         if(isSit)
         {
            dexterPlus = this.pers.sitDexterPlus;
         }
         if(this.lurked)
         {
            detecting = 0;
            dexterPlus = this.pers.lurkDexterPlus;
            visibility *= 0.5;
         }
         if(stealthMult < 0.5)
         {
            detecting = 0;
         }
         if(Boolean(currentWeapon) && currentWeapon.is_shoot)
         {
            if(this.sats.que.length > 0)
            {
               this.sats.act();
               World.w.gui.setWeapon();
            }
            currentWeapon.is_shoot = false;
         }
         if(currentWeapon && currentWeapon.tip != 5 && Boolean(currentWeapon.vis) && currentWeapon.vis.visible)
         {
            this.aMagic = 50;
         }
         else
         {
            this.aMagic = 0;
         }
         if(this.sats.que.length > 0)
         {
            if(currentWeapon == null || currentWeapon.noSats || currentWeapon.status() > 3)
            {
               this.sats.clearAll();
            }
            else if(this.sats.getReady())
            {
               this.sats.que[0].run();
               celX = this.sats.que[0].X;
               celY = this.sats.que[0].Y;
               currentWeapon.attack(true);
            }
            else
            {
               this.sats.unsetCel(true);
            }
         }
         else if(this.attackForever)
         {
            if(isrnd(0.05))
            {
               celX = Math.random() * loc.limX;
               celY = Math.random() * loc.limY;
            }
         }
         else
         {
            celX = World.w.celX;
            celY = World.w.celY;
         }
         precMult = this.pers.allPrecMult * this.pers.piFactor("accuracy");
         mazil = this.pers.mazilAdd;
         if(this.sats.que.length == 0 && !this.lurked)
         {
            if(this.pers.runPenalty > 0 && (dx > 10 || dx < -10 || dy > 10 || dy < -10))
            {
               precMult *= 1 - this.pers.runPenalty;
            }
            if(!stay)
            {
               precMult *= 1 - this.pers.jumpPenalty;
            }
            if(stay && dx < 1 && dx > -1)
            {
               precMult *= 1 + this.pers.stayBonus;
            }
            if(Boolean(currentWeapon) && currentWeapon.storona != storona)
            {
               precMult *= 1 - this.pers.backPenalty;
            }
         }
         if(Boolean(this.throwWeapon) && currentWeapon != this.throwWeapon)
         {
            this.throwWeapon.actions();
            if(this.throwWeapon.tip == 5)
            {
               this.throwWeapon.animate();
            }
         }
         if(Boolean(this.magicWeapon) && currentWeapon != this.magicWeapon)
         {
            this.magicWeapon.actions();
            if(this.magicWeapon.tip == 5)
            {
               this.magicWeapon.animate();
            }
         }
         this.atkWeapon = 0;
         if(Boolean(currentWeapon) && !currentWeapon.attackPos())
         {
            this.atkWeapon = 1;
         }
         if(Boolean(this.throwWeapon) && currentWeapon != this.throwWeapon && !this.throwWeapon.attackPos())
         {
            this.atkWeapon = 2;
         }
         if(Boolean(this.magicWeapon) && currentWeapon != this.magicWeapon && !this.magicWeapon.attackPos())
         {
            this.atkWeapon = 3;
         }
         var _loc1_:* = 15;
         if(this.teleObj)
         {
            this.aMagic = 50;
            if(this.teleObj.massa >= 1)
            {
               this.aMagic = 100;
            }
            if(demask < 200)
            {
               demask = 200;
            }
            if(this.isTake < 10)
            {
               this.isTake = 40;
            }
            if(this.teleObj.X < celX - _loc1_ && this.teleObj.dx < this.teleSpeed)
            {
               this.teleObj.dx += this.teleAccel;
            }
            if(this.teleObj.X > celX + _loc1_ && this.teleObj.dx > -this.teleSpeed)
            {
               this.teleObj.dx -= this.teleAccel;
            }
            if(this.teleObj.Y - this.teleObj.scY / 2 < celY - _loc1_ && this.teleObj.dy < this.teleSpeed)
            {
               this.teleObj.dy += this.teleAccel;
            }
            if(this.teleObj.Y - this.teleObj.scY / 2 > celY + _loc1_ && this.teleObj.dy > -this.teleSpeed)
            {
               this.teleObj.dy -= this.teleAccel;
            }
            if(this.teleObj is Unit)
            {
               if((this.teleObj as Unit).levit_max > 0 && (this.teleObj as Unit).levit_r > (this.teleObj as Unit).levit_max * this.pers.unitLevitMult)
               {
                  this.teleObj.levitPoss = false;
                  this.dropTeleObj();
               }
            }
         }
         if(this.teleObj)
         {
            if(loc.celDist > this.pers.teleDist * 1.2 || mana <= 0 || !this.teleObj.levitPoss)
            {
               this.dropTeleObj();
            }
            else if(this.teleObj is Unit && (this.teleObj as Unit).sost == 1)
            {
            }
         }
         if(levit == 1)
         {
            this.aMagic = 100;
         }
         if(sost > 1)
         {
            this.aMagic = 0;
         }
         if(this.t_dclick > 0)
         {
            --this.t_dclick;
         }
         if(this.t_culd > 0)
         {
            --this.t_culd;
         }
         if(shithp > 0)
         {
            shithp -= 0.05;
         }
         if(Boolean(this.teleObj) || levit == 1 || this.cryst)
         {
            dmana = 0;
            if(this.teleObj)
            {
               dmana -= this.teleSqrtMassa * this.pers.teleMult;
            }
            if(levit == 1)
            {
               if(this.levitup)
               {
                  dmana -= this.pers.levitDManaUp * grav + this.pers.levitDMana;
               }
               else
               {
                  dmana -= this.pers.levitDMana;
               }
            }
            dmana *= this.pers.allDManaMult;
            if(this.pers.teleMana > 0)
            {
               if(levit == 1)
               {
                  this.pers.manaDamage(-dmana * this.pers.teleMana * this.pers.teleManaMult);
               }
               else
               {
                  this.pers.manaDamage(-dmana / 3 * this.pers.teleMana * this.pers.teleManaMult);
               }
            }
         }
         else if(World.w.alicorn && isFly && this.ctr.keyRun && (this.ctr.keyLeft || this.ctr.keyRight || this.ctr.keyBeUp))
         {
            dmana = -this.pers.alicornRunMana;
            if(!loc.sky)
            {
               Emitter.emit("magrun",loc,X,Y - scY / 2,{
                  "dx":dx * 0.5 + Math.random() * 4 - 2,
                  "dy":dy * 0.5 + Math.random() * 4 - 2
               });
            }
         }
         else
         {
            var piRecovery:Number = this.pers.piFactor("mpRecovery");
            if(piRecovery <= 0)
            {
               dmana = 0;
            }
            else
            {
               if(dmana < this.pers.recManaMin * this.pers.shtrManaRes * piRecovery)
               {
                  dmana = this.pers.recManaMin * this.pers.shtrManaRes * piRecovery;
               }
               dmana += this.pers.recMana * this.pers.shtrManaRes * piRecovery;
            }
         }
         mana += dmana;
         if(mana > maxmana)
         {
            mana = maxmana;
         }
         if(this.pers.manaHP < this.pers.manaMin)
         {
            this.pers.manaHP += this.pers.manaHPRes;
            World.w.gui.setMana();
         }
         if(isPlav)
         {
            isFly = false;
            if(this.h2o > 0)
            {
               this.h2o -= this.pers.h2oPlav;
               if(sost == 1 && isrnd(0.1))
               {
                  Emitter.emit("bubble",loc,X + storona * 23,Y - 58);
               }
            }
            else
            {
               this.damage(maxhp / 500,D_INSIDE,null,true);
               if(sost == 1 && isrnd())
               {
                  Emitter.emit("bubble",loc,X + storona * 23,Y - 58);
               }
            }
         }
         else if(this.h2o < 1000)
         {
            this.h2o += 10;
            if(this.h2o > 1000)
            {
               this.h2o = 1000;
            }
         }
         if(isRun && walk && stay && !isSit && dx != 0)
         {
            if(this.stam > 0)
            {
               if(this.inBattle)
               {
                  this.stam -= this.pers.stamRun * this.dstam * this.pers.piFactor("runCost");
               }
            }
            else
            {
               this.possRun = false;
            }
         }
         else if(this.stam < 1000)
         {
            this.stam += this.pers.stamRes * this.pers.piFactor("staminaRecovery");
            if(this.stam > 200)
            {
               this.possRun = true;
            }
            if(this.stam > 1000)
            {
               this.stam = 1000;
            }
         }
         if(this.dash_t > this.dash_maxt - 10 || this.kdash_t > 0)
         {
            dodge = 1 + this.dodgePlus;
         }
         else
         {
            dodge = 0 + this.dodgePlus;
         }
         if(Boolean(this.currentArmor) && this.currentArmor.maxmana > 0)
         {
            if(this.currentArmor.abilActive)
            {
               if(this.currentArmor.mana > 0)
               {
                  this.currentArmor.mana -= this.currentArmor.dmana_use;
               }
               else
               {
                  if(this.armorEffect)
                  {
                     this.armorEffect.unsetEff(true,false,true);
                  }
                  this.currentArmor.abilActive = false;
               }
            }
            else if(this.currentArmor.mana < this.currentArmor.maxmana)
            {
               this.currentArmor.mana += this.currentArmor.dmana_res;
            }
         }
         if(this.t_cryst > 0)
         {
            if(this.t_cryst == 4)
            {
               vis.cryst.gotoAndPlay(10);
            }
            --this.t_cryst;
            if(!this.cryst)
            {
               vis.cryst.gotoAndPlay(1);
               vis.cryst.visible = true;
            }
            this.cryst = true;
         }
         else
         {
            if(this.cryst)
            {
               vis.cryst.visible = false;
            }
            this.cryst = false;
         }
         stun = 0;
         weaponR = -(celY - Y) / 10;
         if(weaponR > 85)
         {
            weaponR = 85;
         }
         if(weaponR < -85)
         {
            weaponR = -85;
         }
         if(this.aMC < this.aMagic)
         {
            this.aMC += 5;
         }
         if(this.aMC > this.aMagic)
         {
            this.aMC -= 5;
         }
         if(this.noPet > 0)
         {
            --this.noPet;
            World.w.gui.setPet();
         }
         if(this.noPet2 > 0)
         {
            --this.noPet2;
         }
         if(this.pet && this.pet.sost == 4 && this.noPet <= 0 && this.pet.optAutores)
         {
            this.pet.resurrect();
         }
         if(this.pipOff == 1)
         {
            World.w.gui.allOn();
         }
         if(this.pipOff > 0)
         {
            --this.pipOff;
         }
         if(this.attackForever)
         {
            if(isrnd(0.1))
            {
               this.autoAttack = 1 - this.autoAttack;
            }
         }
         else
         {
            this.autoAttack = 0;
         }
         if(this.pinok > 0)
         {
            if(stay || isLaz != 0)
            {
               --this.pinok;
            }
            else
            {
               this.pinok -= 3;
            }
         }
         ++this.t_raddam;
         if(this.t_nogas > 0)
         {
            --this.t_nogas;
         }
         if(this.t_raddam > 30)
         {
            this.t_raddam = 0;
            if(this.ddam1 > 0)
            {
               this.damage(this.ddam1 / 30,Unit.D_VENOM,null,true);
               this.ddam1 = 0;
            }
            if(this.ddam2 > 0)
            {
               this.damage(this.ddam2 / 30,Unit.D_PINK,null,true);
               this.ddam2 = 0;
            }
            if(this.ddam3 > 0)
            {
               this.damage(this.ddam3 / 30,Unit.D_NECRO,null,true);
               this.ddam3 = 0;
            }
         }
         if(this.isStayDam > 0)
         {
            --this.isStayDam;
         }
         if(loc.electroDam > 0 && this.isStayDam == 0)
         {
            if(stay && stayMat == 1 || isLaz || inWater || tykMat == 1)
            {
               this.isStayDam = 20;
               if(tykMat == 1)
               {
                  if(turnX != 0)
                  {
                     Emitter.emit("moln",loc,X,Y - scY / 2,{
                        "celx":X + 45 * storona,
                        "cely":Y - 10
                     });
                  }
                  else if(turnY == 1)
                  {
                     Emitter.emit("moln",loc,X,Y - scY / 2,{
                        "celx":X,
                        "cely":Y - 70
                     });
                  }
                  else if(turnY == -1)
                  {
                     Emitter.emit("moln",loc,X,Y - scY / 2,{
                        "celx":X,
                        "cely":Y + 20
                     });
                  }
               }
               else if(isLaz)
               {
                  Emitter.emit("moln",loc,X,Y - scY / 2,{
                     "celx":X + 20 * storona,
                     "cely":Y - 10
                  });
               }
               else if(stay)
               {
                  Emitter.emit("moln",loc,X,Y - scY / 2,{
                     "celx":X - 25 * shX2 + Math.random() * 25 * (shX1 + shX2),
                     "cely":Y + 20
                  });
               }
               this.electroDamage();
            }
         }
         if(loc.electroDam > 0)
         {
            this.showElectroBlock();
         }
         if(loc.sky)
         {
            isFly = true;
         }
         turnY = turnX = 0;
         tykMat = 0;
         for each(_loc2_ in this.invent.spells)
         {
            _loc2_.step();
         }
         --t_replic;
      }
      
      public function otbrosTele(param1:Number) : *
      {
         mana -= this.pers.teleMult * param1 * 5;
      }
      
      internal function actPort() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         if(!loc.portOn)
         {
            return;
         }
         if(mana < this.pers.portMana * this.pers.allDManaMult * this.pers.piFactor("mpCost") && mana < maxmana * 0.99)
         {
            World.w.gui.infoText("overMana",null,null,false);
            World.w.gui.bulb(X,Y - 20);
         }
         else
         {
            _loc1_ = Math.round(World.w.celX / World.tileX) * World.tileX;
            _loc2_ = Math.round(World.w.celY / World.tileY + 1) * World.tileY - 1;
            if(this.checkPort())
            {
               teleport(_loc1_,_loc2_,1);
               sound("teleport");
               this.manaSpell(this.pers.portMagic,this.pers.portMana);
               if(loc.electroDam)
               {
                  this.electroDamage(loc.electroDam);
                  addEffect("burning",40);
                  newPart("iskr",40);
               }
               this.t_culd = Math.floor(this.pers.spellDown * this.pers.portDown);
               dx = dy = 0;
            }
         }
      }
      
      internal function alicornPort() : *
      {
         var _loc3_:Tile = null;
         if(mana < this.pers.alicornPortMana && mana < maxmana * 0.99)
         {
            World.w.gui.infoText("overMana",null,null,false);
            World.w.gui.bulb(X,Y - 20);
            return;
         }
         if(!loc.sky)
         {
            _loc3_ = loc.getAbsTile(World.w.celX,World.w.celY);
            if(_loc3_.visi < 0.8)
            {
               return;
            }
         }
         var _loc1_:* = Math.round(World.w.celX / World.tileX) * World.tileX;
         var _loc2_:* = Math.round(World.w.celY / World.tileY + 1) * World.tileY - 1;
         if(loc.sky || !loc.collisionUnit(_loc1_,_loc2_,stayX,stayY))
         {
            teleport(_loc1_,_loc2_,1);
            if(this.teleObj)
            {
               this.dropTeleObj();
            }
            mana -= this.pers.alicornPortMana;
            dmana = 0;
         }
      }
      
      public function checkPort() : Boolean
      {
         if(mana < this.pers.portMana * this.pers.allDManaMult * this.pers.piFactor("mpCost"))
         {
            return false;
         }
         if(loc.sky)
         {
            return true;
         }
         var _loc1_:* = Math.round(World.w.celX / World.tileX) * World.tileX;
         var _loc2_:* = Math.round(World.w.celY / World.tileY + 1) * World.tileY - 1;
         var _loc3_:Tile = loc.getAbsTile(World.w.celX,World.w.celY);
         if(_loc3_.visi >= 0.8 && !loc.collisionUnit(_loc1_,_loc2_,stayX,stayY))
         {
            return true;
         }
         return false;
      }
      
      internal function manaSpell(param1:Number, param2:Number) : *
      {
         mana -= param1 * this.pers.allDManaMult * this.pers.piFactor("mpCost");
         this.pers.piEvent("castBegin");
         try
         {
            this.pers.manaDamage(param2 * this.pers.allDManaMult);
         }
         finally
         {
            this.pers.piEvent("castEnd");
         }
         dmana = 0;
         if(this.teleObj)
         {
            this.dropTeleObj();
         }
      }
      
      internal function castSpell(param1:String = null) : *
      {
      }
      
      internal function spellDisact() : *
      {
         this.ctr.keyDef = false;
      }
      
      public function bindChain(param1:Number, param2:Number) : *
      {
         addEffect("fetter",0,10,false);
         this.fetX = param1;
         this.fetY = param2;
      }
      
      internal function actTele() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:Pt = null;
         var _loc3_:* = undefined;
         if(this.t_dclick > 0)
         {
         }
         if(this.t_dclick == 0)
         {
            this.t_dclick = 15;
         }
         if(this.teleObj)
         {
            this.dropTeleObj();
            return;
         }
         if(mana < 200)
         {
            return;
         }
         if(loc.celObj == null)
         {
            _loc1_ = (X - World.w.celX) * (X - World.w.celX) + (Y - scY / 2 - World.w.celY) * (Y - scY / 2 - World.w.celY);
            if(_loc1_ > this.pers.teleDist)
            {
               return;
            }
            if(!loc.isLine(X,Y - scY * 0.75,World.w.celX,World.w.celY))
            {
               return;
            }
            _loc2_ = loc.firstObj;
            _loc3_ = 50 * 50;
            while(_loc2_)
            {
               if(_loc2_ is Obj && (_loc2_ as Obj).levitPoss && (_loc2_ as Obj).massa <= this.pers.maxTeleMassa)
               {
                  _loc1_ = (World.w.celX - _loc2_.X) * (World.w.celX - _loc2_.X) + (World.w.celY - _loc2_.Y + (_loc2_ as Obj).scY / 2) * (World.w.celY - _loc2_.Y + (_loc2_ as Obj).scY / 2);
                  if(_loc1_ < _loc3_)
                  {
                     loc.celObj = _loc2_ as Obj;
                     _loc3_ = _loc1_;
                  }
               }
               _loc2_ = _loc2_.nobj;
            }
            if(loc.celObj)
            {
               loc.celObj.onCursor = 1;
               loc.celDist = 0;
            }
         }
         if(loc.celObj && loc.celObj.levitPoss && loc.celObj.onCursor && loc.celDist <= this.pers.teleDist && loc.celObj.massa <= this.pers.maxTeleMassa)
         {
            if((this.pers.telemaster == 0 || !loc.portOn) && !loc.isLine(X,Y - scY * 0.75,loc.celObj.X,loc.celObj.Y - loc.celObj.scY / 2))
            {
               World.w.gui.infoText("noVisible",null,null,false);
               return;
            }
            if(Boolean(loc.electroDam) && loc.celObj is Box && (loc.celObj as Box).mat == 1)
            {
               this.electroDamage(loc.electroDam,loc.celObj.X,loc.celObj.Y - loc.celObj.scY / 2);
               return;
            }
            this.teleObj = loc.celObj;
            if(this.teleObj == null)
            {
               return;
            }
            if(this.teleObj.massa > this.pers.telePorog)
            {
               this.teleSqrtMassa = Math.sqrt(this.teleObj.massa);
            }
            else
            {
               this.teleSqrtMassa = 0;
            }
            if(this.teleObj.vis)
            {
               this.teleObj.vis.filters = [teleFilter];
               this.teleObj.vis.transform.colorTransform = this.teleTransform;
               this.teleObj.vis.parent.setChildIndex(this.teleObj.vis,this.teleObj.vis.parent.numChildren - 1);
            }
            if(this.teleObj is Unit)
            {
               (this.teleObj as Unit).alarma(X,Y);
            }
            this.teleObj.levit = 1;
            if(this.teleObj.inter)
            {
               this.teleObj.inter.sign = 0;
            }
            this.teleObj.fracLevit = fraction;
            this.teleObj.stay = false;
            this.ctr.keyTele = false;
         }
      }
      
      internal function throwTele() : *
      {
         var _loc1_:Object = null;
         var _loc2_:* = undefined;
         if(this.teleObj)
         {
            if(this.pers.spellsPoss <= 0)
            {
               this.dropTeleObj();
               return;
            }
            _loc1_ = {
               "x":this.teleObj.X - X,
               "y":this.teleObj.Y - this.teleObj.scY / 2 - Y + scY / 2 - 10
            };
            _loc2_ = 0;
            if(this.pers.throwForce > 0)
            {
               _loc2_ = this.teleObj.massa * this.pers.throwDmagic * this.pers.allDManaMult;
            }
            if(_loc2_ <= mana)
            {
               norma(_loc1_,this.pers.throwForce);
               mana -= _loc2_;
               this.pers.manaDamage(_loc2_ * this.pers.throwDmanaMult);
            }
            else
            {
               norma(_loc1_,this.pers.throwForce * mana / _loc2_);
               this.pers.manaDamage(mana * this.pers.throwDmanaMult);
               mana = 0;
            }
            if(this.teleObj is Box)
            {
               (this.teleObj as Box).isThrow = true;
               (this.teleObj as Box).t_throw = 2;
            }
            if(this.teleObj is Unit)
            {
               (this.teleObj as Unit).t_throw = 45;
            }
            World.w.gui.setMana();
            this.teleObj.dx += _loc1_.x;
            this.teleObj.dy += _loc1_.y;
            if(this.pers.throwForce > 0)
            {
               Emitter.emit("throw",loc,this.teleObj.X,this.teleObj.Y - this.teleObj.scY / 2,{"rotation":Math.atan2(this.teleObj.dy,this.teleObj.dx) * 180 / Math.PI});
               Snd.ps("dash",this.teleObj.X,this.teleObj.Y);
            }
            this.dropTeleObj();
         }
      }
      
      public function throwForceRelat() : Number
      {
         var _loc1_:Number = Number(NaN);
         if(this.teleObj)
         {
            _loc1_ = this.teleObj.massa * this.pers.throwDmagic * this.pers.allDManaMult;
            if(_loc1_ > mana)
            {
               return mana / _loc1_;
            }
            return 1;
         }
         return 0;
      }
      
      public function dropTeleObj() : *
      {
         if(this.teleObj)
         {
            if(this.teleObj.vis)
            {
               this.teleObj.vis.filters = [];
               if(this.teleObj.cTransform)
               {
                  this.teleObj.vis.transform.colorTransform = this.teleObj.cTransform;
               }
            }
            this.teleObj.levit = 0;
            this.teleObj = null;
            World.w.gui.setMana();
         }
      }
      
      internal function actAction() : *
      {
         if(this.actionObj)
         {
            if((X - this.actionObj.X) * (X - this.actionObj.X) + (Y - this.actionObj.Y) * (Y - this.actionObj.Y) > World.w.actionDist)
            {
               this.actionObj = null;
            }
         }
         else if(this.actionReady && loc.celObj && Boolean(loc.celObj.onCursor) && loc.celDist <= World.w.actionDist)
         {
            this.actionReady = false;
            if((this.pers.telemaster == 0 || !loc.portOn || loc.celObj is Loot || loc.celObj.inter && loc.celObj.inter.allact == "comein") && !loc.isLine(X,Y - scY * 0.75,loc.celObj.X,loc.celObj.Y - loc.celObj.scY / 2,loc.celObj))
            {
               World.w.gui.infoText("noVisible",null,null,false);
               return;
            }
            if(Boolean(loc.electroDam) && loc.celObj is Box && (loc.celObj as Box).mat == 1)
            {
               this.electroDamage(loc.electroDam,loc.celObj.X,loc.celObj.Y - loc.celObj.scY / 2);
               return;
            }
            if(Boolean(loc.celObj.inter) && loc.celObj.inter.active && loc.celObj.inter.action > 0)
            {
               if(loc.celObj.inter.needSkill)
               {
                  loc.celObj.inter.unlock = this.pers.getSkillLevel(loc.celObj.inter.needSkill);
               }
               if(loc.celObj.inter.mine > 0)
               {
                  loc.celObj.inter.unlock = this.pers.getLockTip(loc.celObj.inter.mineTip);
                  this.t_action = loc.celObj.inter.t_action + this.pers.getLockPickTime(loc.celObj.inter.mine,3);
                  this.actionObj = loc.celObj.inter;
               }
               else if(loc.celObj.inter.lock > 0 && Boolean(loc.celObj.inter.lockKey) && this.invent.items[loc.celObj.inter.lockKey].kol > 0)
               {
                  loc.celObj.inter.unlock = 1;
                  this.t_action = 20;
                  this.actionObj = loc.celObj.inter;
               }
               else
               {
                  if(loc.celObj.inter.lock >= 100)
                  {
                     return;
                  }
                  if(loc.celObj.inter.lock > 0)
                  {
                     if(loc.celObj.inter.lockTip == 0)
                     {
                        return;
                     }
                     loc.celObj.inter.unlock = this.pers.getLockTip(loc.celObj.inter.lockTip);
                     loc.celObj.inter.master = this.pers.getLockMaster(loc.celObj.inter.lockTip);
                     this.t_action = loc.celObj.inter.t_action + this.pers.getLockPickTime(loc.celObj.inter.lock,loc.celObj.inter.lockTip);
                     this.actionObj = loc.celObj.inter;
                  }
                  else if(loc.celObj.inter.t_action)
                  {
                     this.t_action = loc.celObj.inter.t_action;
                     this.actionObj = loc.celObj.inter;
                     this.actionObj.beginAct();
                  }
                  else
                  {
                     loc.celObj.inter.is_act = true;
                  }
               }
               this.mt_action = this.t_action;
               if(this.mt_action <= 0)
               {
                  this.mt_action = 1;
               }
               if(this.actionObj)
               {
                  this.actionObj.sound();
               }
            }
         }
      }
      
      internal function crackAction() : *
      {
         if(this.actionReady && loc.celObj && Boolean(loc.celObj.onCursor) && loc.celDist <= World.w.actionDist)
         {
            if(Boolean(loc.celObj.inter) && Boolean(loc.celObj.inter.needRuna(this)))
            {
               loc.celObj.inter.useRuna(this);
            }
         }
      }
      
      internal function chit() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         if(World.w.chit == "fly")
         {
            isFly = !isFly;
         }
         if(World.w.chit == "port")
         {
            _loc1_ = Math.round(World.w.celX / World.tileX) * World.tileX;
            _loc2_ = Math.round(World.w.celY / World.tileY + 1) * World.tileY - 1;
            if(!loc.collisionUnit(_loc1_,_loc2_,stayX,stayY))
            {
               teleport(_loc1_,_loc2_);
            }
         }
         if(World.w.chit == "emit")
         {
            Emitter.emit(World.w.chitX,loc,World.w.celX,World.w.celY);
         }
      }
      
      public function controlOff() : *
      {
         this.ctr.clearAll();
         this.ggControl = false;
         this.dropTeleObj();
         this.actionObj = null;
         invulner = true;
         isRun = false;
         walk = 0;
         if(currentWeapon)
         {
            currentWeapon.vis.visible = false;
         }
         World.w.pip.noAct = true;
      }
      
      public function controlOn() : *
      {
         if(this.pers.dead)
         {
            return;
         }
         invulner = false;
         this.ggControl = true;
         if(currentWeapon)
         {
            currentWeapon.vis.visible = true;
         }
         World.w.pip.noAct = false;
      }
      
      override public function sit(param1:Boolean) : *
      {
         if(this.rat)
         {
            return;
         }
         super.sit(param1);
      }
      
      override public function control() : *
      {
         var _loc3_:* = undefined;
         var _loc5_:Spell = null;
         if(!this.ggControl)
         {
            return;
         }
         var _loc1_:Boolean = this.zaput ? this.ctr.keyRight : this.ctr.keyLeft;
         var _loc2_:Boolean = this.zaput ? this.ctr.keyLeft : this.ctr.keyRight;
         if(this.work == "lurk" || this.work == "unlurk" || this.work == "res")
         {
            return;
         }
         if(this.lurked)
         {
            if(this.ctr.keyBeUp || this.ctr.keySit || this.ctr.keyJump)
            {
               this.unlurk();
               this.ctr.clearAll();
               return;
            }
            if(_loc1_ || _loc2_)
            {
               if(this.lurkTip == 1 || this.lurkTip == 3)
               {
                  if(_loc1_)
                  {
                     storona = -1;
                  }
                  if(_loc2_)
                  {
                     storona = 1;
                  }
               }
               return;
            }
         }
         if(this.ctr.keyAction && this.rat == 0)
         {
            if(!this.teleObj)
            {
               if(this.sats.que.length > 0)
               {
                  this.sats.clearAll();
               }
               this.actAction();
            }
            else
            {
               this.throwTele();
               this.ctr.keyAction = false;
            }
         }
         else
         {
            this.actionReady = true;
            this.actionObj = null;
         }
         if(this.ctr.keyCrack && !this.ctr.keyAction && !loc.base && this.rat == 0)
         {
            this.ctr.keyCrack = false;
            this.crackAction();
         }
         if(this.ctr.keyTele && !this.ctr.keyAction && !loc.base && this.rat == 0)
         {
            if(!this.teleReady)
            {
               if(this.sats.que.length > 0)
               {
                  this.sats.clearAll();
               }
               if(this.visSel)
               {
                  World.w.gui.unshowSelector(0);
               }
               else
               {
                  this.actTele();
               }
               this.teleReady = true;
            }
            if(this.t_culd <= 0 && this.pers.portPoss && Boolean(this.pers.spellsPoss) && !World.w.alicorn)
            {
               ++this.t_port;
            }
         }
         else
         {
            if(this.teleReady)
            {
               if(this.t_port >= this.pers.portTime && this.pers.portPoss && Boolean(this.pers.spellsPoss) && loc.portOn)
               {
                  this.actPort();
               }
               this.teleReady = false;
            }
            this.t_port = 0;
         }
         if(this.ctr.keyFly)
         {
            this.chit();
            this.ctr.keyFly = false;
         }
         if(this.ctr.keyTest1)
         {
            this.testFunction();
            this.ctr.keyTest1 = false;
         }
         if(this.ctr.keyGrenad && !loc.base && !this.ctr.keyAttack && this.attackForever <= 0 && Boolean(this.atkPoss) && (this.atkWeapon == 0 || this.atkWeapon == 2))
         {
            if(this.sats.que.length > 0)
            {
               this.sats.clearAll();
            }
            if(this.throwWeapon)
            {
               this.throwWeapon.attack();
               this.spellDisact();
               if(this.throwWeapon.tip == 4)
               {
                  this.ctr.keyGrenad = false;
               }
            }
            else
            {
               this.ctr.keyGrenad = false;
            }
         }
         if(this.ctr.keyMagic && !loc.base && !this.ctr.keyAttack && this.attackForever <= 0 && Boolean(this.atkPoss) && (this.atkWeapon == 0 || this.atkWeapon == 3))
         {
            if(this.sats.que.length > 0)
            {
               this.sats.clearAll();
            }
            if(this.magicWeapon)
            {
               this.magicWeapon.attack();
               this.spellDisact();
               if(this.magicWeapon.tip == 4)
               {
                  this.ctr.keyMagic = false;
               }
            }
            else
            {
               this.ctr.keyMagic = false;
            }
         }
         if(this.ctr.keyDef && this.rat == 0)
         {
            if(this.sats.que.length > 0)
            {
               this.sats.clearAll();
            }
            if(World.w.alicorn)
            {
               this.currentSpell = this.invent.spells["sp_mshit"];
            }
            if(this.currentSpell)
            {
               if(!this.currentSpell.cast(World.w.celX,World.w.celY))
               {
                  this.ctr.keyDef = false;
               }
               if(!this.currentSpell.prod)
               {
                  this.ctr.keyDef = false;
               }
            }
            else
            {
               this.ctr.keyDef = false;
            }
         }
         _loc3_ = 1;
         while(_loc3_ <= World.kolQS)
         {
            if(this.ctr["keySpell" + _loc3_])
            {
               if(this.invent.fav[World.kolHK * 2 + _loc3_] != null)
               {
                  if(this.sats.que.length > 0)
                  {
                     this.sats.clearAll();
                  }
                  _loc5_ = this.invent.spells[this.invent.fav[World.kolHK * 2 + _loc3_]];
                  if(_loc5_)
                  {
                     if(!_loc5_.cast(World.w.celX,World.w.celY))
                     {
                        this.ctr["keySpell" + _loc3_] = false;
                     }
                     if(!_loc5_.prod)
                     {
                        this.ctr["keySpell" + _loc3_] = false;
                     }
                  }
                  else
                  {
                     this.ctr["keySpell" + _loc3_] = false;
                  }
               }
               else
               {
                  this.ctr["keySpell" + _loc3_] = false;
               }
            }
            _loc3_++;
         }
         if(this.ctr.keyPet)
         {
            ++this.k_pet;
            if(this.k_pet > 20)
            {
               if(this.pet)
               {
                  this.pet.goto(X,Y - 40,true);
               }
               this.k_pet = 0;
               this.ctr.keyPet = false;
            }
         }
         else
         {
            if(this.k_pet > 0)
            {
               if(this.pet)
               {
                  if(Boolean(loc.celObj) && loc.celObj is Unit && (loc.celObj as Unit).fraction != fraction)
                  {
                     this.pet.atk(loc.celObj as Unit);
                  }
                  else
                  {
                     this.pet.goto(celX,celY);
                  }
               }
            }
            this.k_pet = 0;
         }
         if((this.ctr.keyAttack || this.autoAttack) && (!loc.base || this.visSel) && Boolean(this.atkPoss) && (this.atkWeapon == 0 || this.atkWeapon == 1))
         {
            if(this.visSel)
            {
               World.w.gui.unshowSelector(1);
               this.ctr.keyAttack = false;
            }
            else if(this.ctr.keyTele)
            {
               this.ctr.keyTele = false;
               this.ctr.keyAttack = false;
               this.t_port = 0;
               this.spellDisact();
            }
            else if(Boolean(currentWeapon) && this.t_work <= 0)
            {
               if(this.sats.que.length > 0)
               {
                  this.sats.clearAll();
                  this.ctr.keyAttack = false;
               }
               else
               {
                  weaponSkill = this.pers.weaponSkills[currentWeapon.skill];
                  if(!currentWeapon.attack())
                  {
                     this.ctr.keyAttack = false;
                  }
                  World.w.gui.setWeapon();
                  this.spellDisact();
               }
            }
         }
         if(this.ctr.keyReload && Boolean(currentWeapon) && this.attackForever <= 0)
         {
            if(this.t_reload >= 30)
            {
               currentWeapon.unloadWeapon();
               this.ctr.keyReload = false;
            }
            if(currentWeapon.detonator())
            {
               this.ctr.keyReload = false;
            }
            ++this.t_reload;
         }
         else
         {
            if(Boolean(currentWeapon) && this.t_reload > 0 && this.t_reload < 10)
            {
               currentWeapon.initReload();
            }
            this.t_reload = 0;
         }
         if(this.ctr.keyPunch && World.w.alicorn)
         {
            this.ctr.keyPunch = false;
            this.alicornPort();
         }
         if(this.ctr.keyPunch && !World.w.alicorn && stay && this.t_work == 0 && !isSit && !_loc1_ && !_loc2_ && !loc.base && !this.lurked && this.attackForever <= 0 && Boolean(this.atkPoss))
         {
            (this.punchWeapon as WKick).kick = this.ctr.keyRun;
            this.punchWeapon.attack();
            this.spellDisact();
            this.work = "punch";
            this.t_work = 13;
            this.ctr.keyPunch = false;
         }
         if(this.ctr.keyPunch && this.rat > 0)
         {
            remEffect("potion_rat");
            this.ctr.keyPunch = false;
         }
         if(this.rat == 0)
         {
            if(this.t_work <= 0 && this.attackForever <= 0)
            {
               _loc3_ = 1;
               while(_loc3_ <= World.kolHK)
               {
                  if(this.ctr["keyWeapon" + _loc3_])
                  {
                     this.ctr["keyWeapon" + _loc3_] = false;
                     this.invent.useFav(_loc3_ + (this.ctr.keyRun ? World.kolHK : 0));
                     if(this.visSel)
                     {
                        World.w.gui.unshowSelector(0);
                     }
                     if(this.currentSpell)
                     {
                        this.currentSpell.active = false;
                     }
                     this.ctr.keyDef = this.ctr.keyAttack = false;
                  }
                  _loc3_++;
               }
            }
            if(this.ctr.keyScrDown && !this.autoAttack)
            {
               World.w.gui.showSelector(1,this.ctr.keyRun ? 1 : 0);
               this.ctr.keyScrDown = this.ctr.keyScrUp = false;
            }
            if(this.ctr.keyScrUp && !this.autoAttack)
            {
               World.w.gui.showSelector(-1,this.ctr.keyRun ? 1 : 0);
               this.ctr.keyScrDown = this.ctr.keyScrUp = false;
            }
            if(this.ctr.keyItemNext)
            {
               this.invent.nextItem(1);
               this.ctr.keyItemNext = this.ctr.keyItemPrev = false;
            }
            if(this.ctr.keyItemPrev)
            {
               this.invent.nextItem(-1);
               this.ctr.keyItemNext = this.ctr.keyItemPrev = false;
            }
            if(this.ctr.keyItem)
            {
               this.invent.useItem();
               this.ctr.keyItem = false;
            }
            if(this.ctr.keyPot)
            {
               this.invent.usePotion();
               this.ctr.keyPot = false;
            }
            if(this.ctr.keyMana)
            {
               this.invent.usePotion("mana");
               this.ctr.keyMana = false;
            }
            if(this.ctr.keyArmor)
            {
               this.armorAbil();
               this.ctr.keyArmor = false;
            }
         }
         var _loc4_:* = accel * this.pers.accelMult;
         maxSpeed = walkSpeed;
         if(stay && this.ctr.keyAction && maxSpeed > 3)
         {
            _loc4_ = accel * 0.4;
            maxSpeed = 3;
         }
         if(loc.sky)
         {
            maxSpeed *= 3;
         }
         isRun = (this.possRun || this.stam > 200) && this.ctr.keyRun || this.runForever > 0;
         if(this.h2o <= 0)
         {
            isRun = false;
         }
         if(isRun && stay)
         {
            maxSpeed = runSpeed;
         }
         if(isSit && stay)
         {
            maxSpeed = sitSpeed;
         }
         if(diagon != 0)
         {
            maxSpeed = walkSpeed * 0.75;
         }
         if(isPlav)
         {
            maxSpeed = plavSpeed * this.pers.speedPlavMult;
         }
         if(maxSpeed > walkSpeed && currentWeapon && currentWeapon.massa >= 0.1 && this.pers.bigGunsSlow > 0)
         {
            maxSpeed *= 1 - currentWeapon.massa * this.pers.bigGunsSlow;
         }
         if(!stay)
         {
            _loc4_ = 0.1 * accel;
         }
         if(isPlav)
         {
            _loc4_ = 0.3 * accel * this.pers.speedPlavMult;
         }
         if(isFly)
         {
            maxSpeed *= 1.3;
            if(World.w.alicorn && this.ctr.keyRun && mana > 20)
            {
               _loc4_ = accel;
               maxSpeed = runSpeed * this.pers.alicornFlyMult;
               if(loc.sky)
               {
                  maxSpeed *= 2;
               }
            }
            else
            {
               _loc4_ = 0.5 * accel;
            }
         }
         if(isLaz)
         {
            _loc4_ = 1.4 * accel;
         }
         if(levit)
         {
            maxSpeed = 1000;
            _loc4_ = 0.3 * accel;
         }
         if(this.cryst)
         {
            maxSpeed = sitSpeed;
         }
         porog = 0;
         porog_jump = 0;
         if((isRun || this.ctr.keyBeUp) && this.jumpNumb == 0)
         {
            porog_jump = 10;
         }
         if(!isLaz)
         {
            if(_loc1_ && !_loc2_)
            {
               storona = -1;
            }
            if(!_loc1_ && _loc2_)
            {
               storona = 1;
            }
         }
         walk = 0;
         if(_loc1_ && !_loc2_ || this.runForever > 0 && storona < 0)
         {
            porog = 20;
            this.isTake = 40;
            if(storona > 0 && stay)
            {
               storona = -1;
            }
            else if(dx > -maxSpeed && (!this.ctr.keyRun || this.t_run > 3))
            {
               dx -= _loc4_;
               if(dx < -maxSpeed)
               {
                  dx = -maxSpeed;
               }
            }
            walk = -1;
            ++this.t_run;
         }
         else if(!_loc1_ && _loc2_ || this.runForever > 0 && storona > 0)
         {
            porog = 20;
            this.isTake = 40;
            if(storona < 0 && stay)
            {
               storona = 1;
            }
            else if(dx < maxSpeed && (!this.ctr.keyRun || this.t_run > 3))
            {
               dx += _loc4_;
               if(dx > maxSpeed)
               {
                  dx = maxSpeed;
               }
            }
            walk = 1;
            ++this.t_run;
         }
         else
         {
            this.t_run = 0;
         }
         if(this.ctr.keyDubRight && !this.zaput || this.ctr.keyDubLeft && this.zaput || this.ctr.keyDash && storona == 1)
         {
            if(stay && !isSit && (this.ctr.keyRun || this.ctr.keyDash) && this.dash_t <= 0 && this.stam > 200 && this.pers.speedShtr <= 0 && this.rat == 0)
            {
               if(dx < this.dash)
               {
                  dx = this.dash;
               }
               this.aJump = 2;
               dy += this.dash_dy;
               this.dash_t = this.dash_maxt;
               this.jumpNumb = 2;
               this.dJump = false;
               stay = false;
               this.jumpp = 0;
               this.ctr.keyJump = false;
               if(this.inBattle)
               {
                  this.stam -= this.pers.stamRun * this.pers.stamDash * this.dstam * this.pers.piFactor("dashCost");
               }
            }
            this.ctr.keyDubRight = this.ctr.keyDubLeft = this.ctr.keyDash = false;
         }
         if(this.ctr.keyDubLeft && !this.zaput || this.ctr.keyDubRight && this.zaput || this.ctr.keyDash && storona == -1)
         {
            if(stay && !isSit && (this.ctr.keyRun || this.ctr.keyDash) && this.dash_t <= 0 && this.stam > 200 && this.pers.speedShtr <= 0 && this.rat == 0)
            {
               if(dx > -this.dash)
               {
                  dx = -this.dash;
               }
               this.aJump = 2;
               dy += this.dash_dy;
               this.dash_t = this.dash_maxt;
               this.jumpNumb = 2;
               this.dJump = false;
               stay = false;
               this.jumpp = 0;
               this.ctr.keyJump = false;
               if(this.inBattle)
               {
                  this.stam -= this.pers.stamRun * this.pers.stamDash * this.dstam * this.pers.piFactor("dashCost");
               }
            }
            this.ctr.keyDubLeft = this.ctr.keyDubRight = this.ctr.keyDash = false;
         }
         if(levit == 1)
         {
            levit = 0;
         }
         throu = (this.ctr.keyJump || !stay) && this.ctr.keySit || isPlav || this.kdash_t > 3 || this.pinok > 70;
         if(stay && !this.ctr.keyJump || Boolean(isLaz))
         {
            this.jumpp = this.maxjumpp;
            this.dJump = false;
            if(Boolean(isLaz) && !_loc1_ && !_loc2_)
            {
               this.jumpp = 0;
            }
            this.jumpNumb = 0;
            if(this.dash_t <= 0)
            {
               this.aJump = 0;
            }
         }
         else if(!stay && !this.ctr.keyJump && this.pers.isDJ && this.jumpNumb <= 1 && loc.levitOn)
         {
            this.jumpp = this.maxdjumpp;
            this.dJump = true;
         }
         else if(!this.ctr.keyJump && this.jumpNumb == 0)
         {
            this.jumpNumb = 1;
         }
         if(throu && stayPhis == 2)
         {
            this.jumpp = 0;
         }
         if(!stay && this.ctr.keyJump)
         {
            --this.jumpp;
         }
         if(!stay && !this.ctr.keyJump && !(Boolean(this.pers.isDJ) && loc.levitOn && this.jumpNumb <= 1))
         {
            this.jumpp = 0;
         }
         if(isPlav && (this.jumpp <= 2 || this.jumpNumb > 1))
         {
            this.jumpp = 5;
            this.jumpNumb = 1;
            this.dJump = false;
         }
         this.dJump2 = false;
         if(this.ctr.keyJump && this.dash_t < this.dash_maxt - 15)
         {
            this.isTake = 40;
            this.t_stay = 0;
            if(!isJump)
            {
               if(this.inBattle && this.stam > -100)
               {
                  this.stam -= this.pers.stamRun * this.pers.stamJump * this.dstam * this.pers.piFactor("jumpCost");
               }
               isJump = true;
               ++this.jumpNumb;
            }
            if(stay && World.w.hardInv)
            {
               this.invent.damageItems(0,false);
            }
            if(isPlav)
            {
               dy -= plavdy * this.pers.speedPlavMult;
            }
            else if(this.jumpp > 0)
            {
               if(isSit)
               {
                  unsit();
               }
               if(!isSit)
               {
                  this.spellDisact();
                  if(this.dJump && Boolean(this.pers.ableFly) && loc.levitOn)
                  {
                     isFly = !isFly;
                     if(loc.sky)
                     {
                        isFly = true;
                     }
                     this.t_fly = 0;
                     this.ctr.keyJump = false;
                  }
                  else if(this.dJump)
                  {
                     dy = -this.djumpdy * this.pers.jumpMult;
                     if(this.jumpp == this.maxdjumpp - 1)
                     {
                        Emitter.emit("quake",loc,X,Y);
                        if(_loc1_)
                        {
                           dx -= this.djumpdy * 0.5;
                        }
                        if(_loc2_)
                        {
                           dx += this.djumpdy * 0.5;
                        }
                        if(dx > 25)
                        {
                           dx = 25;
                        }
                        if(dx < -25)
                        {
                           dx = -25;
                        }
                        this.jumpNumb = 3;
                     }
                     this.dJump2 = true;
                     if(this.jumpp == 1 && this.levitOn && loc.levitOn && !isPlav)
                     {
                        this.jumpNumb = 3;
                     }
                  }
                  else
                  {
                     dy = -jumpdy * this.pers.jumpMult;
                  }
                  this.aJump = 1;
               }
            }
            else if(Boolean(this.pers.ableFly) && loc.levitOn && this.rat == 0)
            {
               if(isLaz)
               {
                  isLaz = 0;
               }
               isFly = !isFly;
               this.t_fly = 0;
               this.ctr.keyJump = false;
            }
            else if(this.levitOn && loc.levitOn && this.jumpNumb > (this.pers.isDJ ? 2 : 1) && !isPlav)
            {
               if(levit > 1)
               {
                  --levit;
               }
               else
               {
                  levit = 1;
                  fracLevit = fraction;
               }
               isFly = false;
            }
            if(Boolean(isLaz) || stay)
            {
               if(!_loc1_ && _loc2_ && dx < maxSpeed - _loc4_)
               {
                  dx += _loc4_;
               }
               if(_loc1_ && !_loc2_ && dx > -maxSpeed + _loc4_)
               {
                  dx -= _loc4_;
               }
            }
            if(levit == 1 && mana <= 0)
            {
               levit = 0;
               this.jumpNumb = 2;
            }
         }
         else
         {
            isJump = false;
         }
         if(isPlav && this.ctr.keyBeUp && !this.ctr.keyJump)
         {
            dy -= plavdy * this.pers.speedPlavMult;
         }
         if(levit == 1)
         {
            if(this.ctr.keyBeUp)
            {
               dy -= levidy * 0.7;
               this.levitup = true;
               this.t_up = 10;
            }
            else
            {
               this.levitup = false;
            }
            if(this.ctr.keySit)
            {
               dy += levidy;
            }
         }
         if(isFly)
         {
            if(this.ctr.keyBeUp)
            {
               dy -= levidy;
            }
            if(this.ctr.keySit)
            {
               dy += levidy;
            }
         }
         if(this.ctr.keySit)
         {
            porog = 0;
            if(stay && diagon == 0 && this.runForever <= 0 && !inWater && this.isFetter <= 0 && !this.noStairs && this.rat == 0)
            {
               if(checkStairs(2))
               {
                  this.t_stay = 0;
                  dy = lazSpeed;
                  throu = true;
               }
               else if(stayPhis == 2 && checkStairs(2,-20 * storona))
               {
                  this.t_stay = 0;
                  dy = lazSpeed;
                  throu = true;
               }
               else if(stayPhis == 2 && checkStairs(2,20 * storona))
               {
                  this.t_stay = 0;
                  dy = lazSpeed;
                  throu = true;
               }
               else if(stayPhis == 1 && this.downp == 1 || stayPhis == 2 && this.downp == 5)
               {
                  this.sit(true);
               }
            }
            else if(Boolean(isLaz) && !this.noStairs)
            {
               if(checkStairs(2))
               {
                  dy = lazSpeed * 1.5;
               }
            }
            else if(isPlav)
            {
               dy += plavdy * this.pers.speedPlavMult / 2;
            }
            if(this.downp < 6)
            {
               ++this.downp;
            }
         }
         else
         {
            this.downp = 0;
         }
         if(isSit && this.ctr.keyBeUp && !this.ctr.keySit && this.rat == 0)
         {
            this.t_up = 10;
            unsit();
         }
         if(isSit && !stay && this.rat == 0)
         {
            unsit();
         }
         this.weapUp = false;
         if(stay && this.ctr.keyBeUp && this.rat == 0)
         {
            if(isSit)
            {
               this.t_up = 10;
            }
            ++this.t_up;
            if(this.t_up > 10)
            {
               this.weapUp = true;
            }
         }
         else
         {
            if(this.t_up > 0 && this.t_up <= 7 && !_loc1_ && !_loc2_ && this.rat == 0)
            {
               this.lurk();
            }
            if(!this.ctr.keyBeUp)
            {
               this.t_up = 0;
            }
         }
         if(this.ctr.keyDubSit)
         {
            if(stay && stayPhis == 2)
            {
               this.t_stay = 0;
               throu = true;
               dy += 10;
            }
            this.ctr.keyDubSit = false;
         }
         if(loc.quake > 5)
         {
            throu = true;
         }
         if(!isSit && !isFly && this.ctr.keyBeUp && this.runForever <= 0 && loc.quake <= 5 && !this.cryst && this.isFetter <= 0 && !this.noStairs && this.pinok < 30 && this.rat == 0)
         {
            if(checkStairs())
            {
               this.t_stay = 0;
               dy = -lazSpeed;
               this.t_up = 10;
            }
         }
         if(this.runForever > 0 || this.ctr.keyJump && !this.ctr.keyBeUp || loc.quake > 5)
         {
            isLaz = 0;
         }
         isUp = this.ctr.keyBeUp;
         if(this.rat == 1)
         {
            isSit = false;
            scX = this.ratX;
            scY = this.ratY;
         }
      }
      
      public function lookInvis(param1:Unit, param2:Number = -1) : Boolean
      {
         if(param2 == -1)
         {
            param2 = this.pers.visiTrap;
         }
         if(loc != param1.loc)
         {
            return false;
         }
         return look(param1,false,param2) > 0;
      }
      
      public function lineCel(param1:int = 0, param2:int = 0) : int
      {
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc10_:Tile = null;
         var _loc3_:* = 0;
         var _loc4_:* = celX + param1 - X;
         var _loc5_:* = celY + param2 - Y + scY / 2;
         var _loc6_:* = Math.floor(Math.max(Math.abs(_loc4_),Math.abs(_loc5_)) / World.maxdelta) + 1;
         var _loc7_:* = 1;
         while(_loc7_ < _loc6_)
         {
            _loc8_ = X + _loc4_ * _loc7_ / _loc6_;
            _loc9_ = Y - scY / 2 + _loc5_ * _loc7_ / _loc6_;
            _loc10_ = World.w.loc.getAbsTile(Math.floor(_loc8_),Math.floor(_loc9_));
            if(_loc10_.phis == 1 && _loc8_ >= _loc10_.phX1 && _loc8_ <= _loc10_.phX2 && _loc9_ >= _loc10_.phY1 && _loc9_ <= _loc10_.phY2)
            {
               celX = _loc8_;
               celY = _loc9_;
               return 0;
            }
            _loc7_++;
         }
         return 1;
      }
      
      internal function lurk() : *
      {
         var _loc1_:Box = null;
         this.lurkTip = 0;
         if(stay && !isSit && dx < 5 && dx > -5 && stayPhis >= 1 && this.work == "")
         {
            this.lurkBox = null;
            for each(_loc1_ in loc.objs)
            {
               if(_loc1_.lurk > this.lurkTip && X > _loc1_.X1 && X < _loc1_.X2 && Y - 10 > _loc1_.Y1 && Y - 10 < _loc1_.Y2)
               {
                  this.lurkTip = _loc1_.lurk;
                  this.lurkBox = _loc1_;
               }
            }
            if(this.lurkBox)
            {
               this.lurkX = X;
               dx = 0;
               this.t_work = 20;
               this.work = "lurk";
               this.lurked = true;
               if(this.lurkBox.lurk == 2)
               {
                  if(X > this.lurkBox.X)
                  {
                     storona = 1;
                     this.lurkX = this.lurkBox.X2 - 10;
                  }
                  else
                  {
                     storona = -1;
                     this.lurkX = this.lurkBox.X1 + 10;
                  }
               }
               else
               {
                  this.lurkX = this.lurkBox.X;
               }
            }
            else if(Boolean(loc.getAbsTile(X - 20,Y - 10).lurk) && Boolean(loc.getAbsTile(X + 20,Y - 10).lurk))
            {
               this.lurkTip = 1;
               this.lurkX = Math.round(X / Tile.tileX) * Tile.tileX;
               dx = 0;
               this.t_work = 20;
               this.work = "lurk";
               this.lurked = true;
            }
            else
            {
               this.armorAbil();
            }
         }
      }
      
      internal function unlurk() : *
      {
         if(this.lurked && stay)
         {
            this.t_work = 10;
            this.work = "unlurk";
         }
         this.lurked = false;
      }
      
      public function setAddictions() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:Effect = null;
         for(_loc1_ in this.pers.addictions)
         {
            if(this.pers.addictions[_loc1_] >= this.pers.ad1)
            {
               _loc2_ = addEffect(_loc1_);
               if(this.pers.addictions[_loc1_] >= this.pers.ad2)
               {
                  _loc2_.lvl = 2;
               }
               if(this.pers.addictions[_loc1_] >= this.pers.ad3)
               {
                  _loc2_.lvl = 3;
               }
               _loc2_.forever = true;
            }
         }
         if(World.w.game.triggers["curse"] > 0)
         {
            addEffect("curse");
         }
      }
      
      internal function endAllEffect() : *
      {
         var _loc1_:* = undefined;
         if(effects.length > 0)
         {
            for each(_loc1_ in effects)
            {
               _loc1_.unsetEff();
            }
            effects = new Array();
         }
      }
      
      internal function clearAddictions() : *
      {
         var _loc1_:* = undefined;
         for(_loc1_ in this.pers.addictions)
         {
            this.pers.addictions[_loc1_] = 0;
         }
      }
      
      public function observation(param1:Number, param2:Number = -1000) : Boolean
      {
         var _loc3_:* = this.sneak - demask / 20;
         if(_loc3_ < 0)
         {
            _loc3_ = 0;
         }
         if(param2 > -1000)
         {
            if(param2 > _loc3_)
            {
               param1 *= 1 + (param2 - _loc3_) * 0.2;
            }
            else if(param2 < _loc3_)
            {
               param1 /= 1 - (param2 - _loc3_) * 0.3;
            }
         }
         param1 *= this.pers.visiMult * stealthMult;
         if(this.lurked)
         {
            param1 -= this.pers.sneakLurk;
         }
         if(isSit)
         {
            param1 -= this.pers.sneakLurk / 5;
         }
         if(param1 < 0)
         {
            param1 = 0;
         }
         this.obs += param1;
         if(param1 > 0)
         {
            this.isObs = 30;
         }
         if(this.obs > this.maxObs * 2)
         {
            this.obs = this.maxObs * 2;
         }
         return this.obs >= this.maxObs;
      }
      
      override public function heal(param1:Number, param2:int = 0, param3:Boolean = true) : *
      {
         if(param1 == 0)
         {
            return;
         }
         if(param2 == 0)
         {
            if(param1 > maxhp - this.rad - hp)
            {
               param1 = maxhp - this.rad - hp;
               hp = maxhp - this.rad;
            }
            else
            {
               hp += param1;
            }
         }
         else if(param2 == 1)
         {
            this.healhp += param1;
         }
         else if(param2 == 2)
         {
            this.rad -= param1;
            if(this.rad < 0)
            {
               this.rad = 0;
            }
         }
         else if(param2 == 3)
         {
            cut -= param1;
            if(cut < 0)
            {
               cut = 0;
            }
         }
         else if(param2 == 4)
         {
            if(param1 > 0)
            {
               poison -= param1;
               if(poison < 0)
               {
                  poison = 0;
               }
            }
            else
            {
               poison -= param1;
            }
         }
         if(param3 && (sost == 1 || sost == 2) && showNumbs && param1 > 0.5)
         {
            numbEmit.cast(loc,X,Y - scY / 2,{
               "txt":(param2 == 2 ? "-" : "+") + Math.round(param1),
               "frame":(param2 == 2 ? 7 : 4),
               "rx":20,
               "ry":20
            });
         }
         World.w.gui.setHp();
      }
      
      override public function udarUnit(param1:Unit, param2:Number = 1) : Boolean
      {
         if(super.udarUnit(param1,param2))
         {
            if(param1.radDamage)
            {
               this.drad2 = param1.radDamage;
            }
            return true;
         }
         return false;
      }
      
      public function raddamage(param1:Number, param2:Number, param3:int = 0) : *
      {
         if(this.t_nogas > 0)
         {
            return;
         }
         if(param3 == 0)
         {
            World.w.gg.drad += param2 * param1;
         }
         else if(this["ddam" + param3] != null)
         {
            if(param1 < 0.25)
            {
               param1 *= 4;
            }
            else
            {
               param1 = 1;
            }
            this["ddam" + param3] += param2 * param1;
         }
      }
      
      override public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number
      {
         var _loc5_:*;
         var _loc6_:Number;
         if(Unit.rconnectDeferDamage != null && Boolean(Unit.rconnectDeferDamage(this,param1,param2,param3,param4)))
         {
            return 0;
         }
         if(rconnectDamage != null && World.w.gg != this)
         {
            return Number(rconnectDamage(this,param1,param2,param3,param4));
         }
         if(Boolean(param3) && Boolean(param3.weap) && param3.weap.dopEffect == "psy")
         {
            if(isrnd(0.33))
            {
               addEffect("horror");
            }
            else if(isrnd())
            {
               addEffect("vote");
            }
            else
            {
               addEffect("disorient");
            }
         }
         _loc5_ = hp;
         if(loc.train || loc.base)
         {
            return 0;
         }
         if(param2 == Unit.D_EMP && param1 > 30 && this.pers.pipEmpVulner > 0)
         {
            this.pipOff += Math.round(param1 * this.pers.pipEmpVulner);
            if(this.sats.que.length > 0)
            {
               this.sats.clearAll();
            }
            World.w.gui.allOff();
         }
         if(this.cryst && param2 != Unit.D_BLEED && param2 != Unit.D_POISON && param2 != Unit.D_INSIDE)
         {
            param1 *= 5 / spellPower;
            mana -= param1;
            if(mana <= 0)
            {
               this.cryst = false;
               this.spellDisact();
            }
            this.pers.manaDamage(param1 * 0.1);
            dmana = 0;
            return 0;
         }
         if(Boolean(this.currentArmor) && !World.w.godMode)
         {
            this.currentArmor.damage(param1 * this.pers.armorVulner,param2);
         }
         if(param2 != Unit.D_BLEED && param2 != Unit.D_POISON && param2 != Unit.D_INSIDE && param2 != Unit.D_PINK)
         {
            this.pinok += param1 / maxhp * 200 * knocked;
            if(!param4 && World.w.hardInv && !World.w.alicorn)
            {
               this.invent.damageItems(param1);
            }
         }
         if(this.pinok > 100)
         {
            this.pinok = 100;
         }
         if(this.pinok > 60 && levit == 1)
         {
            levit = 0;
            this.ctr.keyJump = false;
         }
         if(this.pinok > 60 && Boolean(this.teleObj))
         {
            this.dropTeleObj();
         }
         if(this.pinok > 30)
         {
            isLaz = 0;
         }
         _loc6_ = super.damage(param1,param2,param3,param4);
         if(_loc5_ / maxhp >= 0.2 && hp / maxhp < 0.2)
         {
            World.w.gui.critHP();
         }
         if(_loc6_ / maxhp > 0.1 && isrnd(_loc6_ / maxhp))
         {
            this.replic("dam");
         }
         if(World.w.godMode)
         {
            hp = _loc5_;
         }
         else if(!World.w.alicorn)
         {
            this.pers.piEvent("begin",{
               "dot":param2 == Unit.D_BLEED || param2 == Unit.D_POISON || param2 == Unit.D_INSIDE,
               "shot":(param3 == null ? 0 : param3.piShot)
            });
            try
            {
               this.pers.damage(_loc6_,param2);
               this.pers.bloodDamage(_loc6_,param2);
            }
            finally
            {
               this.pers.piEvent("end");
            }
         }
         return _loc6_;
      }
      
      public function electroDamage(param1:Number = -1, param2:* = null, param3:* = null) : *
      {
         if(param1 < 0)
         {
            param1 = loc.electroDam;
         }
         if(this.pinok > 0)
         {
            param1 *= 2;
         }
         if(this.pers.potShad == 0)
         {
            this.damage(param1,D_SPARK,null,true);
         }
         else
         {
            this.damage(param1,D_INSIDE,null,true);
            this.pinok = 90;
         }
         Snd.ps("electro",X,Y);
         if(param2 != null && param3 != null)
         {
            Emitter.emit("moln",loc,X,Y - scY / 2,{
               "celx":param2,
               "cely":param3
            });
         }
      }
      
      override public function udarBox(param1:Box) : int
      {
         var _loc2_:int = super.udarBox(param1);
         if(_loc2_ == 2 && Boolean(loc.electroDam) && param1.mat == 1)
         {
            this.electroDamage(loc.electroDam,param1.X,param1.Y - param1.scY / 2);
         }
         return _loc2_;
      }
      
      override public function die(param1:int = 0) : *
      {
         if(sost > 1 || World.w.godMode && param1 >= 0)
         {
            return;
         }
         if(param1 >= 0)
         {
            if(this.pers.lastCh > 0)
            {
               hp = 1;
               this.heal(this.pers.lastCh * 0.1,0,false);
               this.heal(this.pers.lastCh * 0.9,1,false);
               remEffect("potion_chance");
               addEffect("post_chance");
               return;
            }
            if(this.pers.reanimHp > 0 && !this.noReanim)
            {
               hp = 0;
               this.heal(this.pers.reanimHp);
               addEffect("reanim");
               return;
            }
            if(param1 < 10 && sost == 1)
            {
               this.pers.damage(0,0,true);
            }
         }
         this.controlOff();
         World.w.gui.unshowSelector();
         if(sost < 3)
         {
            sost = 2;
         }
         if(param1 >= 10)
         {
            sost = 3;
         }
         isLaz = 0;
         levit = 0;
         isFly = false;
         this.t_port = 0;
         this.healhp = shithp = 0;
         if(this.work == "change")
         {
            this.changeWeaponNow(1);
            this.changeWeaponNow(2);
         }
         walk = 0;
         this.t_work = 205;
         this.work = "die";
         if(rconnectDeath != null && Boolean(rconnectDeath(this,param1)))
         {
            return;
         }
         if(this.pers.hardcore && param1 >= 0)
         {
            this.pers.dead = true;
            World.w.saveGame(-2);
            if(param1 == 10)
            {
               World.w.gui.messText("hardDie2",this.pers.persName,false,false,10000);
            }
            else
            {
               World.w.gui.messText("hardDie",this.pers.persName,false,false,10000);
            }
            Snd.playMusic("harddie",1);
         }
         else
         {
            World.w.t_die = 300;
         }
      }
      
      public function resurect() : *
      {
         this.lurked = false;
         sost = 1;
         this.sit(false);
         if(this.rad > maxhp - 40)
         {
            this.rad = maxhp - 40;
         }
         if(this.rad < 0)
         {
            this.rad = 0;
         }
         if(hp <= 0)
         {
            hp = 0;
            this.heal(Math.min(100,maxhp / 2));
            cut = poison = 0;
            this.pers.addPerk("dead");
         }
         if(this.pers.manaHP < 50)
         {
            this.pers.heal(Math.min(50,50 - this.pers.manaHP),6);
         }
         this.t_work = 100;
         this.t_nogas = 250;
         this.animOff = false;
         this.work = "res";
         mana = this.h2o = this.stam = 1000;
         this.drad2 = 0;
         this.possRun = true;
         if(this.pipOff > 0)
         {
            World.w.gui.allOn();
            this.pipOff = 0;
         }
         this.endAllEffect();
         this.setAddictions();
         this.pers.setParameters();
         if(Boolean(this.pet) && this.pet.sost == 4)
         {
            this.noPet = 0;
            if(this.pet.optAutores)
            {
               this.pet.resurrect();
            }
         }
         if(this.armorEffect)
         {
            this.armorEffect.unsetEff(true,false,true);
         }
         if(this.currentArmor)
         {
            this.currentArmor.abilActive = false;
         }
         vis.visible = true;
      }
      
      override public function setWeaponPos(param1:int = 0) : *
      {
         var p:Point = null;
         var tip:int = param1;
         if(weaponKrep == 0)
         {
            if(storona > 0 && celX > X2 || storona < 0 && celX < X1)
            {
               weaponX = X + scX * 1 * storona;
            }
            else
            {
               weaponX = X;
            }
            if(isLaz)
            {
               weaponX = X;
            }
            if(loc.getAbsTile(weaponX,weaponY).phis == 1 || loc.getAbsTile(weaponX + storona * 15,weaponY).phis == 1)
            {
               weaponX = X;
            }
            if(tip == 1)
            {
               weaponY = Y - scY * 0.4;
            }
            else
            {
               weaponY = Y - scY * 0.7;
            }
            if(stay && this.weapUp)
            {
               if(loc.getTile(Math.floor(weaponX / Tile.tileX),Math.floor((weaponY - 40) / Tile.tileY)).phis != 1)
               {
                  weaponY -= 40;
               }
            }
         }
         else
         {
            super.setWeaponPos(tip);
         }
         if(this.work == "change" && this.t_work > this.changeWeaponTime3 && tip != 5)
         {
            weaponX = X;
            weaponY = Y - scY * 0.5;
         }
         try
         {
            p = new Point(vis.osn.body.head.morda.konec.x,vis.osn.body.head.morda.konec.y);
            p = vis.osn.body.head.morda.localToGlobal(p);
            p = vis.parent.globalToLocal(p);
            magicX = p.x;
            magicY = p.y;
            if(loc.getAbsTile(magicX,magicY).phis == 1)
            {
               if(isSit)
               {
                  magicY = Y - 35;
               }
               else
               {
                  magicY = Y - 75;
               }
            }
         }
         catch(err:*)
         {
            magicX = X;
            magicY = Y - scY / 2;
         }
      }
      
      public function changeWeapon(param1:String, param2:Boolean = false) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"changeWeapon",[param1,param2])))
         {
            return;
         }
         var _loc3_:* = undefined;
         if(Boolean(this.sats) && this.sats.que.length > 0)
         {
            this.sats.clearAll();
         }
         if(param1 == "not")
         {
            _loc3_ = null;
         }
         else
         {
            if(param1 == null || param1 == "" || this.attackForever > 0 || this.atkPoss == 0)
            {
               return false;
            }
            if(Boolean(currentWeapon) && param1 == currentWeapon.id)
            {
               _loc3_ = null;
            }
            else
            {
               _loc3_ = this.invent.weapons[param1];
            }
         }
         if(_loc3_ is Weapon)
         {
            if(_loc3_.respect == 1 || Boolean(_loc3_.alicorn) && !World.w.alicorn)
            {
               if(_loc3_.tip == 5)
               {
                  World.w.gui.infoText("disSpell",null,null,false);
               }
               else
               {
                  World.w.gui.infoText("disWeapon",null,null,false);
               }
               return;
            }
            if(_loc3_.spell)
            {
               if(_loc3_.respect == 0)
               {
                  _loc3_.respect = 2;
               }
               this.invent.useItem(param1);
               return;
            }
            if(World.w.weaponsLevelsOff && _loc3_.lvl > this.pers.getWeapLevel(_loc3_.skill))
            {
               if(Boolean(_loc3_.lvlNoUse) || _loc3_.lvl - this.pers.getWeapLevel(_loc3_.skill) > 2)
               {
                  World.w.gui.infoText("weaponSkillLevel",null,null,false);
               }
            }
         }
         if(param2)
         {
            this.newWeapon = _loc3_;
            this.changeWeaponNow(1);
            this.changeWeaponNow(2);
         }
         else
         {
            this.work = "change";
            this.t_work = this.changeWeaponTime1;
            this.newWeapon = _loc3_;
         }
      }
      
      public function changePaintWeapon(param1:String, param2:uint, param3:String = null) : *
      {
         (this.paintWeapon as WPaint).setPaint(param1,param2,param3);
         if(Boolean(this.sats) && this.sats.que.length > 0)
         {
            this.sats.clearAll();
         }
         this.newWeapon = this.paintWeapon;
         this.work = "change";
         this.t_work = this.changeWeaponTime1;
      }
      
      private function changeWeaponNow(param1:int) : *
      {
         vision = 1;
         if(param1 == 1)
         {
            if(currentWeapon)
            {
               if(currentWeapon.tip != 5 || Boolean(this.newWeapon) && this.newWeapon.tip == 5)
               {
                  currentWeapon.remVisual();
               }
            }
            currentWeapon = null;
            childObjs[0] = null;
         }
         if(param1 == 2 && currentWeapon == null)
         {
            currentWeapon = this.newWeapon;
            childObjs[0] = currentWeapon;
            if(currentWeapon)
            {
               if(currentWeapon.respect == 0)
               {
                  currentWeapon.respect = 2;
               }
               if(currentWeapon.tip == 4 && this.invent.fav[29] == null)
               {
                  this.throwWeapon = currentWeapon;
               }
               if(currentWeapon.tip == 5 && this.invent.fav[30] == null)
               {
                  this.magicWeapon = currentWeapon;
               }
               currentWeapon.addVisual();
               currentWeapon.setNull();
               currentWeapon.setPers(this,this.pers);
               weaponLevit();
            }
         }
         if(currentWeapon)
         {
            vision = currentWeapon.visionMult;
         }
         World.w.gui.setWeapon();
      }
      
      public function getInvAmmo(param1:String, param2:int = 1, param3:int = 1, param4:Boolean = false) : int
      {
         if(this.invent == null)
         {
            return -1;
         }
         if(this.invent.items[param1].kol < param3)
         {
            return -1;
         }
         var _loc5_:int = 0;
         if(this.invent.items[param1].kol < param2)
         {
            _loc5_ = int(this.invent.items[param1].kol);
            if(param4)
            {
               this.invent.items[param1].kol = 0;
            }
         }
         else
         {
            _loc5_ = param2;
            if(param4)
            {
               this.invent.items[param1].kol -= param2;
            }
         }
         return _loc5_;
      }
      
      public function changeArmor(param1:String = "", param2:Boolean = false) : Boolean
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"changeArmor",[param1,param2])))
         {
            return false;
         }
         if(World.w.alicorn && param1 != "" && !param2)
         {
            World.w.gui.infoText("alicornNot",null,null,false);
            return false;
         }
         if(World.w.t_battle > 0 && param1 != "off")
         {
            World.w.gui.infoText("noChArmor",null,null,false);
            return false;
         }
         var _loc3_:* = 1;
         var _loc4_:* = 0;
         if(this.invent.armors[param1])
         {
            _loc3_ = this.invent.armors[param1].tip;
            _loc4_ = this.invent.armors[param1].clo;
         }
         if(World.w.hardInv && !param2 && param1 != "off" && !(loc && loc.base) && _loc3_ == 1)
         {
            if(_loc4_ == 0 && param1 != this.prevArmor)
            {
               World.w.gui.infoText("noChArmor2",null,null,false);
               return false;
            }
         }
         if(param1 == "off")
         {
            World.w.gui.infoText("brokenArmor");
            param1 = "";
         }
         if(_loc3_ == 1)
         {
            if(this.currentArmor)
            {
               this.currentArmor.active = false;
               if(this.armorEffect)
               {
                  this.armorEffect.unsetEff(true,false,true);
               }
               this.armorEffect = null;
               this.currentArmor.abilActive = false;
            }
            if(param1 == "" || Boolean(this.currentArmor) && this.currentArmor.id == this.invent.armors[param1].id)
            {
               this.currentArmor = null;
            }
            else if(this.invent.armors[param1])
            {
               if(this.invent.armors[param1].hp > 0)
               {
                  this.currentArmor = this.invent.armors[param1];
               }
               else
               {
                  World.w.gui.infoText("brokenArmor");
               }
            }
            if(this.currentArmor)
            {
               Appear.ggArmorId = this.currentArmor.id;
               Appear.hideMane = this.currentArmor.hideMane;
               this.currentArmor.owner = this;
               this.currentArmor.active = true;
               this.currentArmor.abilActive = false;
               this.currentArmor.mana = 0;
               if(this.currentArmor.clo == 0)
               {
                  this.prevArmor = this.currentArmor.id;
               }
            }
            else
            {
               Appear.ggArmorId = "";
               Appear.hideMane = 0;
            }
            this.refreshVis();
            isFly = false;
         }
         else if(_loc3_ == 3)
         {
            if(this.currentAmul)
            {
               this.currentAmul.active = false;
            }
            if(Boolean(this.currentAmul) && this.currentAmul.id == this.invent.armors[param1].id)
            {
               this.currentAmul = null;
            }
            else
            {
               this.currentAmul = this.invent.armors[param1];
            }
            if(this.currentAmul)
            {
               this.currentAmul.owner = this;
               this.currentAmul.active = true;
            }
         }
         this.pers.setParameters();
         return true;
      }
      
      public function changeSpell(param1:String = "", param2:Boolean = true) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"changeSpell",[param1,param2])))
         {
            return;
         }
         if(this.currentSpell == this.invent.spells[param1])
         {
            this.currentSpell = null;
         }
         else
         {
            this.currentSpell = this.invent.spells[param1];
         }
         if(param2 && Boolean(this.currentSpell))
         {
            World.w.gui.infoText("usedSpell",this.currentSpell.nazv);
         }
      }
      
      override public function setPunchWeaponPos(param1:WPunch) : *
      {
         param1.X = X + scX / 3 * (celX > X ? 1 : -1);
         param1.Y = Y - scY / 2;
         param1.rot = celX > X ? 0 : Math.PI;
      }
      
      public function armorAbil() : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"armorAbil",[])))
         {
            return;
         }
         if(this.currentArmor == null || this.currentArmor.abil == null)
         {
            return;
         }
         if(!this.currentArmor.abilActive)
         {
            if(this.currentArmor.dmana_act < this.currentArmor.mana)
            {
               this.currentArmor.mana -= this.currentArmor.dmana_act;
               this.armorEffect = addEffect(this.currentArmor.abil);
               this.currentArmor.abilActive = true;
            }
         }
         else
         {
            if(this.armorEffect)
            {
               this.armorEffect.unsetEff(true,false,true);
            }
            this.armorEffect = null;
            this.currentArmor.abilActive = false;
         }
      }
      
      private function rconnectCallPet() : void
      {
         var roster:Array = Location.rconnectPlayerStep == null || loc == null ? null : loc.units.concat();
         this.pet.call();
         if(roster != null)
         {
            if(roster.indexOf(this.pet) < 0)
            {
               roster.push(this.pet);
            }
            loc.units = roster;
         }
      }
      
      public function callPet(param1:String, param2:Boolean = false) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"callPet",[param1,param2])))
         {
            return;
         }
         if(this.noPet > 0 && !param2)
         {
            World.w.gui.infoText("petNot",null,null,false);
            return;
         }
         if(this.noPet2 > 0 && !param2 || !this.atkPoss || World.w.alicorn)
         {
            World.w.gui.infoText("petNot2",null,null,false);
            return;
         }
         if(param1 == "owl" && this.currentPet == "owl" && this.pets[param1] && this.pets[param1].hp <= 0 && !param2)
         {
            World.w.gui.infoText("petNot3",null,null,false);
            return;
         }
         this.noPet2 = 5 * 30;
         if(this.pet)
         {
            World.w.gui.infoText("petRecall",this.pet.nazv);
            this.pet.recall();
            this.pet = null;
            childObjs[2] = null;
         }
         this.retPet = "";
         if(this.currentPet == param1)
         {
            this.currentPet = "";
         }
         else if(!loc.petOn)
         {
            World.w.gui.infoText("noPetCall",null,null,false);
         }
         else
         {
            this.currentPet = param1;
            this.pet = this.pets[this.currentPet];
            childObjs[2] = this.pet;
            this.pet.X = X;
            this.pet.Y = Y - 20;
            this.pet.loc = loc;
            this.rconnectCallPet();
            World.w.gui.infoText("petCall",this.pet.nazv);
         }
         World.w.gui.setPet();
      }
      
      public function uncallPet(param1:Boolean = false) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"uncallPet",[param1])))
         {
            return;
         }
         if(this.pet)
         {
            if(param1 && this.currentPet != "moon")
            {
               this.retPet = this.currentPet;
            }
            World.w.gui.infoText("petRecall",this.pet.nazv);
            this.pet.recall();
            this.pet = null;
            childObjs[2] = null;
            this.currentPet = "";
         }
         World.w.gui.setPet();
      }
      
      public function alicornOn(param1:Boolean = true) : *
      {
         World.w.alicorn = true;
         if(this.armorEffect)
         {
            this.armorEffect.unsetEff(true,false,true);
         }
         this.changeArmor("",true);
         this.invent.addWeapon("a_melee");
         this.invent.addWeapon("a_fire");
         this.invent.addWeapon("a_energ");
         this.invent.addWeapon("a_expl");
         this.invent.addWeapon("a_magic");
         this.uncallPet();
         this.clearAddictions();
         this.endAllEffect();
         this.pers.healAll();
         this.rad = cut = poison = 0;
         this.pers.setParameters();
         if(param1)
         {
            newPart("redray",40);
            Snd.ps("al_armor",X,Y);
         }
         this.refreshVis();
      }
      
      public function alicornOff() : *
      {
         World.w.alicorn = false;
         isFly = false;
         this.changeWeapon("not",true);
         this.pers.setParameters();
         this.refreshVis();
      }
      
      public function ratOn() : *
      {
         this.unlurk();
         this.uncallPet(true);
         this.changeWeapon("not");
         isSit = false;
         isLaz = levit = 0;
         isFly = false;
         this.dropTeleObj();
         this.actionObj = null;
         scX = this.ratX;
         scY = this.ratY;
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         Y1 = Y - scY;
         vis.osn.visible = false;
         vis.rat.visible = true;
         newPart("black",30);
         this.rat = 1;
      }
      
      public function ratOff() : Boolean
      {
         scX = stayX;
         scY = stayY;
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         Y1 = Y - scY;
         if(collisionAll())
         {
            if(collisionAll(15))
            {
               if(collisionAll(-15))
               {
                  scX = this.ratX;
                  scY = this.ratY;
                  X1 = X - scX / 2;
                  X2 = X + scX / 2;
                  Y1 = Y - scY;
                  return false;
               }
               X -= 15;
               X1 = X - scX / 2;
               X2 = X + scX / 2;
            }
            else
            {
               X += 15;
               X1 = X - scX / 2;
               X2 = X + scX / 2;
            }
         }
         vis.osn.visible = true;
         vis.rat.visible = false;
         newPart("black",30);
         this.rat = 0;
         return true;
      }
      
      public function anim(param1:String = null, param2:Boolean = false) : *
      {
         if(param1 == null || param1 == "")
         {
            this.animOff = false;
            return;
         }
         vis.osn.gotoAndStop(param1);
         var _loc3_:* = vis.osn.body.totalFrames;
         if(param2)
         {
            this.animOff = true;
            vis.osn.body.gotoAndStop(_loc3_);
         }
         else
         {
            this.animOff = false;
            this.work = param1;
            this.t_work = _loc3_;
         }
         this.otherVisual();
      }
      
      internal function chSloy(param1:int) : *
      {
         if(sloy == param1)
         {
            return;
         }
         remVisual();
         sloy = param1;
         this.addVisual();
      }
      
      public function setFilters() : *
      {
         var _loc1_:Array = null;
         if(this.f_levit)
         {
            if(levit >= 1 && fracLevit != fraction && Boolean(this.levitFilter2))
            {
               _loc1_ = [this.levitFilter2];
            }
            else if(levit == 1 && fracLevit == fraction || this.dJump && levit < 2)
            {
               _loc1_ = [this.levitFilter1];
            }
            else
            {
               _loc1_ = [];
            }
         }
         else
         {
            _loc1_ = [];
         }
         if(this.f_die)
         {
            _loc1_.push(this.dieFilter);
         }
         if(this.f_shad)
         {
            _loc1_.push(this.shadowFilter);
         }
         if(this.f_dash)
         {
            _loc1_.push(this.dashFilter);
         }
         if(this.f_stealth)
         {
            _loc1_.push(this.stealthFilter);
         }
         if(this.f_stealth)
         {
            vis.alpha = 0.5;
         }
         else
         {
            vis.alpha = 1;
         }
         if(this.f_inv)
         {
            _loc1_.push(this.invulnerFilter1,this.invulnerFilter2);
         }
         vis.osn.filters = _loc1_;
      }
      
      override public function animate() : *
      {
         var _loc1_:int = 0;
         var _loc2_:int = 0;
         if(this.animOff)
         {
            return;
         }
         vis.osn.y = 0;
         vis.osn.rotation = 0;
         if(Boolean(this.t_work) && this.work == "die")
         {
            this.reloadbar.visible = false;
            if(!World.w.alicorn)
            {
               if(animState != "die")
               {
                  vis.osn.gotoAndStop("die");
                  animState = "die";
               }
               if(this.t_work < 170 && this.t_work > 120)
               {
                  this.dieFilter.alpha = 1 - (this.t_work - 120) / 50;
                  this.f_die = true;
                  this.dieTransform.redOffset = (170 - this.t_work) * 2;
                  this.dieTransform.blueOffset = (170 - this.t_work) * 3;
                  vis.osn.transform.colorTransform = this.dieTransform;
                  Emitter.emit("die_spark",loc,X + Math.random() * 120 - 60 + 20 * storona,Y);
               }
               else if(this.t_work < 120 && this.t_work > 70)
               {
                  vis.osn.alpha = (this.t_work - 70) / 50;
               }
            }
            else
            {
               if(animState != "die")
               {
                  vis.osn.gotoAndStop("dieali");
                  animState = "die";
               }
               if(this.t_work < 200 && this.t_work > 140)
               {
                  this.f_die = true;
                  this.dieTransform.redOffset = (200 - this.t_work) * 4;
                  this.dieTransform.blueOffset = 200 - this.t_work;
                  vis.osn.transform.colorTransform = this.dieTransform;
                  newPart("redray");
               }
               if(this.t_work == 140)
               {
                  newPart("bloodblast");
                  Snd.ps("bale_e");
                  vis.osn.alpha = 0;
               }
            }
            this.setFilters();
            this.otherVisual();
            return;
         }
         if(Boolean(this.t_work) && this.work == "lurk")
         {
            if(animState != "lurk")
            {
               vis.osn.gotoAndStop("lurk" + this.lurkTip);
               vis.osn.body.gotoAndPlay(1);
               animState = "lurk";
            }
            this.setFilters();
            this.otherVisual();
            return;
         }
         if(Boolean(this.t_work) && this.work == "unlurk")
         {
            if(animState != "unlurk")
            {
               try
               {
                  vis.osn.body.gotoAndPlay("un");
                  animState = "unlurk";
               }
               catch(err:*)
               {
               }
            }
            this.setFilters();
            this.otherVisual();
            return;
         }
         if(Boolean(this.t_work) && this.work == "res")
         {
            if(animState != "res")
            {
               vis.osn.gotoAndStop("res");
               animState = "res";
            }
            this.otherVisual();
            return;
         }
         if(this.lurked)
         {
            vis.osn.body.head.morda.eye.gotoAndStop(1);
            this.otherVisual();
            return;
         }
         if(this.klip > 0)
         {
            --this.klip;
         }
         else
         {
            this.klip = Math.random() * 200 + 50;
         }
         if(stay)
         {
            this.t_stay = 5;
         }
         else if(this.t_stay > 0)
         {
            --this.t_stay;
         }
         if(Boolean(this.t_work) && this.work == "punch")
         {
            this.freeAnim = 0;
         }
         if(Boolean(this.t_work) && this.work == "punch" && animState != "punch")
         {
            if(!this.ctr.keyRun)
            {
               vis.osn.gotoAndStop("punch");
            }
            else
            {
               vis.osn.gotoAndStop("kick");
            }
            animState = "punch";
         }
         if(this.t_work == 0 && animState == "punch")
         {
            animState = "";
         }
         if(stay || this.t_stay > 0)
         {
            if(!(animState == "punch" || animState == "kick"))
            {
               if(diagon == 0 && (dx <= 1 && dx >= -1 && walk != 0 || dx <= 4 && dx >= -4 && walk == 0 || shX1 > 0.5 && isSit || shX2 > 0.5 && isSit))
               {
                  this.t_walk = 0;
                  if(this.freeAnim == 0 || isSit)
                  {
                     this.freeAnim = 0;
                     if(vis.osn.currentFrameLabel != "stay")
                     {
                        if(vis.osn.currentFrameLabel == "jump" || vis.osn.currentFrameLabel == "levit")
                        {
                           vis.osn.gotoAndStop("stay");
                           vis.osn.body.gotoAndPlay("jump");
                        }
                        else
                        {
                           vis.osn.gotoAndStop("stay");
                        }
                     }
                     _loc1_ = this.getStayFrame();
                     if(isSit)
                     {
                        if(animState == "jump")
                        {
                           if(animState != "downjump")
                           {
                              animState = "downjump";
                              vis.osn.body.gotoAndPlay("downjump");
                           }
                        }
                        if(animState != "down" && animState != "downjump")
                        {
                           if(animState == "polz" || _loc1_ != 2)
                           {
                              vis.osn.body.gotoAndStop(_loc1_);
                           }
                           else if(animState != "roll")
                           {
                              vis.osn.body.gotoAndPlay("down");
                           }
                           else
                           {
                              vis.osn.body.gotoAndStop("sit");
                           }
                           animState = "down";
                        }
                     }
                     else
                     {
                        if(animState == "down")
                        {
                           vis.osn.body.gotoAndPlay("up");
                           animState = "up";
                        }
                        if(animState != "up" || _loc1_ != 1)
                        {
                           if(vis.osn.body.currentFrame < 70)
                           {
                              vis.osn.body.gotoAndStop(_loc1_);
                           }
                           animState = "";
                        }
                     }
                     if(vis.osn.body.currentFrame != _loc1_ && !(vis.osn.body.currentFrame >= 3 && vis.osn.body.currentFrame <= 26 || vis.osn.body.currentFrame > 70))
                     {
                        vis.osn.body.gotoAndStop(_loc1_);
                     }
                     if(vis.osn.currentFrameLabel == "stay" && _loc1_ == 1)
                     {
                        if(isrnd(0.01))
                        {
                           this.freeAnim = Math.floor(Math.random() * 3) + 1;
                           vis.osn.gotoAndStop("free" + this.freeAnim);
                           vis.osn.body.play();
                        }
                     }
                  }
                  else if(vis.osn.body.currentFrame >= 49)
                  {
                     this.freeAnim = 0;
                  }
               }
               else if(diagon != 0 && dx == 0)
               {
                  this.freeAnim = 0;
                  this.t_walk = 0;
                  if(diagon * storona > 0)
                  {
                     if(animState != "diag_up")
                     {
                        animState = "diag_up";
                        vis.osn.gotoAndStop("trot_up");
                        vis.osn.body.gotoAndStop(1);
                     }
                  }
                  else if(animState != "diag_down")
                  {
                     animState = "diag_down";
                     vis.osn.gotoAndStop("trot_down");
                     vis.osn.body.gotoAndStop(1);
                  }
               }
               else
               {
                  this.freeAnim = 0;
                  if(diagon != 0)
                  {
                     if(diagon * storona > 0)
                     {
                        if(animState != "trot_up")
                        {
                           animState = "trot_up";
                           vis.osn.gotoAndStop("trot_up");
                           vis.osn.body.play();
                        }
                     }
                     else if(animState != "trot_down")
                     {
                        animState = "trot_down";
                        vis.osn.gotoAndStop("trot_down");
                        vis.osn.body.play();
                     }
                     this.sndStep(this.t_walk,1);
                     ++this.t_walk;
                  }
                  else if(isSit)
                  {
                     if(animState == "roll" && vis.osn.body.currentFrame >= 15)
                     {
                        vis.osn.gotoAndStop("polz");
                        animState = "polz";
                     }
                     if(animState != "polz" && animState != "roll")
                     {
                        if(maxSpeed > walkSpeed * 1.6 && dx * storona > 0 && (Boolean(this.runForever) || this.ctr.keyRun && (this.ctr.keyLeft || this.ctr.keyRight)))
                        {
                           vis.osn.gotoAndStop("roll");
                           animState = "roll";
                        }
                        else
                        {
                           vis.osn.gotoAndStop("polz");
                           animState = "polz";
                        }
                        vis.osn.body.play();
                     }
                  }
                  else if(maxSpeed < 5)
                  {
                     this.sndStep(this.t_walk,4);
                     ++this.t_walk;
                     if(animState != "walk")
                     {
                        vis.osn.gotoAndStop("walk");
                        vis.osn.body.play();
                        animState = "walk";
                     }
                  }
                  else if(maxSpeed > walkSpeed * 1.6 && dx * storona > 0 && (Boolean(this.runForever) || this.ctr.keyRun && (this.ctr.keyLeft || this.ctr.keyRight)))
                  {
                     this.sndStep(this.t_walk,2);
                     ++this.t_walk;
                     if(animState != "run")
                     {
                        vis.osn.gotoAndStop("run");
                        vis.osn.body.play();
                        animState = "run";
                     }
                  }
                  else if(dx * storona > 0)
                  {
                     this.sndStep(this.t_walk,1);
                     ++this.t_walk;
                     if(animState != "trot")
                     {
                        vis.osn.gotoAndStop("trot");
                        vis.osn.body.play();
                        animState = "trot";
                     }
                  }
               }
            }
         }
         else if(isLaz)
         {
            this.freeAnim = 0;
            if(animState != "laz")
            {
               vis.osn.gotoAndStop("laz");
               animState = "laz";
            }
            if(dy == 0)
            {
               vis.osn.body.gotoAndStop(1);
            }
            else
            {
               _loc1_ = int(vis.osn.body.currentFrame);
               this.sndStep(_loc1_,3);
               if(dy < 0)
               {
                  if(_loc1_ <= 12)
                  {
                     vis.osn.body.gotoAndStop(_loc1_ + 1);
                  }
                  else
                  {
                     vis.osn.body.gotoAndStop(2);
                  }
               }
               else if(_loc1_ >= 3)
               {
                  vis.osn.body.gotoAndStop(_loc1_ - 1);
               }
               else
               {
                  vis.osn.body.gotoAndStop(13);
               }
            }
         }
         else if(isPlav)
         {
            this.freeAnim = 0;
            vis.osn.rotation = dy * 1.5;
            if(animState != "plav")
            {
               animState = "plav";
               vis.osn.gotoAndStop("plav");
            }
         }
         else
         {
            this.freeAnim = 0;
            if(animState != "jump" && animState != "levit")
            {
               if(this.aJump > 0)
               {
                  vis.osn.gotoAndStop("jump");
                  animState = "jump";
               }
               else
               {
                  vis.osn.gotoAndStop("pinok");
                  animState = "pinok";
               }
            }
            if(animState == "pinok" && isFly)
            {
               vis.osn.gotoAndStop("jump");
               animState = "jump";
            }
            if(levit == 1 && animState != "levit")
            {
               if(this.aJump > 0 && vis.osn.body.currentFrame >= 14 && vis.osn.body.currentFrame <= 18)
               {
                  animState = "levit";
                  vis.osn.gotoAndStop("levit");
               }
               if(this.aJump == 0 && vis.osn.body.currentFrame >= 10 && vis.osn.body.currentFrame <= 22)
               {
                  animState = "levit";
                  vis.osn.gotoAndStop("levit");
                  vis.osn.body.gotoAndPlay(51);
               }
            }
            if(levit == 0 && animState == "levit")
            {
               vis.osn.gotoAndStop("levit");
               if(vis.osn.body.currentFrame < 66)
               {
                  vis.osn.body.gotoAndPlay(67);
               }
            }
            if(levit == 1 && animState == "levit")
            {
               if(vis.osn.body.currentFrame > 66)
               {
                  vis.osn.body.gotoAndPlay(17);
               }
            }
            else if(animState != "levit")
            {
               if(this.aJump > 0)
               {
                  _loc1_ = Math.round(16 + dy);
                  if(_loc1_ > 32)
                  {
                     _loc1_ = 32;
                  }
                  if(_loc1_ < 1)
                  {
                     _loc1_ = 1;
                  }
               }
               else if(dy > 2 && dx > -6 && dx < 6)
               {
                  _loc1_ = Math.round(31 + dy);
                  if(_loc1_ < 33)
                  {
                     _loc1_ = 33;
                  }
                  if(_loc1_ > 42)
                  {
                     _loc1_ = 42;
                  }
               }
               else
               {
                  _loc1_ = Math.round(16 + dx * storona);
                  if(_loc1_ > 32)
                  {
                     _loc1_ = 32;
                  }
                  if(_loc1_ < 1)
                  {
                     _loc1_ = 1;
                  }
               }
               vis.osn.body.gotoAndStop(_loc1_);
            }
         }
         if(vis.osn.body.head.morda)
         {
            _loc2_ = 3;
            if(this.lurked)
            {
               this.headR = 25;
            }
            else if(this.headRO - weaponR <= 1 && this.headRO - weaponR >= -1)
            {
               --this.t_head;
               _loc2_ = 6;
               if(this.t_head <= 0)
               {
                  this.t_head = Math.floor(Math.random() * 100 + 10);
                  this.headR = Math.random() * 70 - 25;
               }
            }
            else
            {
               this.headR = weaponR;
               this.t_head = 100;
            }
            if(this.headRA - this.headR <= 1 && this.headRA - this.headR >= -1)
            {
               this.headRA = this.headR;
            }
            else
            {
               this.headRA += (this.headR - this.headRA) / _loc2_;
            }
            if(isNaN(this.headRA))
            {
               this.headRA = 0;
            }
            if(this.headRA > 55)
            {
               this.headRA = 55;
            }
            if(this.headRA < -35)
            {
               this.headRA = -35;
            }
            vis.osn.body.head.morda.rotation = this.headRA;
            this.headRO = weaponR;
         }
         if(levit > 0 && this.t_levitfilter <= 20)
         {
            this.t_levitfilter += 2;
         }
         if(this.dJump2 && this.t_levitfilter <= 20)
         {
            this.t_levitfilter += 10;
         }
         if(levit == 0 && !this.dJump2 && this.t_levitfilter >= 0)
         {
            --this.t_levitfilter;
         }
         if(this.t_levitfilter == 0)
         {
            this.f_levit = false;
            this.setFilters();
         }
         else if(this.t_levitfilter > 0 && this.t_levitfilter <= 20)
         {
            this.levitFilter1.alpha = this.t_levitfilter / 20;
            this.levitFilter1.blurX = this.levitFilter1.blurY = this.t_levitfilter / 4 + 2;
            this.f_levit = true;
            this.setFilters();
         }
         if(this.dash_t >= this.dash_maxt - 20)
         {
            this.dashFilter.blurX = Math.min(this.dash_t - this.dash_maxt + 20,10) / 2;
            this.setFilters();
         }
         else
         {
            this.dashFilter.blurX = 0;
         }
         this.otherVisual();
         if((shok > 0 || this.runForever > 0 || this.attackForever > 0) && vis.osn.body.head.morda.eye.currentFrame == 1)
         {
            vis.osn.body.head.morda.eye.gotoAndStop(2);
         }
         if(shok == 0 && this.runForever <= 0 && this.attackForever <= 0 && vis.osn.body.head.morda.eye.currentFrame == 2 || this.klip == 1)
         {
            vis.osn.body.head.morda.eye.gotoAndStop(1);
         }
         if(this.klip == 5 && vis.osn.body.head.morda.eye.currentFrame == 1)
         {
            vis.osn.body.head.morda.eye.gotoAndStop(3);
         }
         if(Boolean(vis.osn.body.head.morda.eye.eye) && this.klip % 10 == 3 && isrnd(0.2))
         {
            vis.osn.body.head.morda.eye.eye.zrak.x += Math.random() * 8 - 4;
            if(vis.osn.body.head.morda.eye.eye.zrak.x < -20)
            {
               vis.osn.body.head.morda.eye.eye.zrak.x = -20;
            }
            if(vis.osn.body.head.morda.eye.eye.zrak.x > -11)
            {
               vis.osn.body.head.morda.eye.eye.zrak.x = -11;
            }
            vis.osn.body.head.morda.eye.eye.zrak.y += Math.random() * 4 - 2;
         }
      }
      
      public function stopAnim() : *
      {
         vis.osn.body.stop();
      }
      
      internal function getStayFrame() : int
      {
         if(shX2 >= 1 && shX2 >= 1)
         {
            return isSit ? 2 : 1;
         }
         if(storona > 0)
         {
            if(isSit)
            {
               if(shX2 > 0)
               {
                  return 49 + Math.round(shX2 * 10);
               }
               if(shX1 > 0)
               {
                  return 49 + 11 + Math.round(shX1 * 10);
               }
            }
            else
            {
               if(shX2 > 0.3)
               {
                  return 27 + Math.round((shX2 - 0.3) * 13);
               }
               if(shX1 > 0.3)
               {
                  return 27 + 11 + Math.round((shX1 - 0.3) * 13);
               }
            }
         }
         else if(isSit)
         {
            if(shX1 > 0)
            {
               return 49 + Math.round(shX1 * 10);
            }
            if(shX2 > 0)
            {
               return 49 + 11 + Math.round(shX2 * 10);
            }
         }
         else
         {
            if(shX1 > 0.3)
            {
               return 27 + Math.round((shX1 - 0.3) * 13);
            }
            if(shX2 > 0.3)
            {
               return 27 + 11 + Math.round((shX2 - 0.3) * 13);
            }
         }
         return isSit ? 2 : 1;
      }
      
      internal function otherVisual() : *
      {
         if(levit != this.prev_levit)
         {
            this.setFilters();
         }
         this.prev_levit = levit;
         if(Boolean(currentWeapon) && currentWeapon.t_reload > 1)
         {
            if(!this.reloadbar.visible)
            {
               this.reloadbar.visible = true;
            }
            this.reloadbar.gotoAndStop(Math.floor(currentWeapon.t_reload / (currentWeapon.reload * currentWeapon.reloadMult) * 11) + 1);
            World.w.gui.setHolder();
         }
         else if(this.reloadbar.visible)
         {
            this.reloadbar.visible = false;
         }
         this.hair = vis.osn.body.head.morda.hair;
         if(this.hair)
         {
            if(this.hairY != -1000)
            {
               this.hairDY += (Y / 5 + vis.osn.body.head.y * 4 - vis.osn.body.head.morda.rotation - this.hairY) / 4;
               this.hairR += this.hairDY;
               this.hairDY -= this.hairR / 4;
               this.hairDY *= 0.8;
               if(this.hairR > 8)
               {
                  this.hairR = 8;
               }
               if(this.hairR < -8)
               {
                  this.hairR = -8;
               }
            }
            this.hairY = Y / 5 + vis.osn.body.head.y * 4 - vis.osn.body.head.morda.rotation;
            this.hair.rotation = this.hairR;
            this.tail = vis.osn.body.tail.h0;
            if(this.tail)
            {
               this.tail.rotation = -this.hairR;
            }
            this.tail = vis.osn.body.tail.h1;
            if(this.tail)
            {
               this.tail.rotation = -this.hairR;
            }
         }
         if(vis.scaleX > 0)
         {
            vis.osn.body.pip1.visible = true;
            vis.osn.body.pip2.visible = false;
            if(vis.osn.body.frleg3)
            {
               vis.osn.body.pip1.x = vis.osn.body.frleg3.x;
               vis.osn.body.pip1.y = vis.osn.body.frleg3.y;
               vis.osn.body.pip1.rotation = vis.osn.body.frleg3.rotation;
            }
         }
         else
         {
            vis.osn.body.pip2.visible = true;
            vis.osn.body.pip1.visible = false;
            if(vis.osn.body.flleg3)
            {
               vis.osn.body.pip2.x = vis.osn.body.flleg3.x;
               vis.osn.body.pip2.y = vis.osn.body.flleg3.y;
               vis.osn.body.pip2.rotation = vis.osn.body.flleg3.rotation;
            }
         }
         vis.osn.body.head.morda.magic.alpha = this.aMC / 100;
         vis.osn.body.head.morda.magic.visible = vis.osn.body.head.morda.magic.alpha > 0;
         if(this.pers.ableFly)
         {
            if(vis.osn.body.rwing)
            {
               vis.osn.body.rwing.visible = true;
            }
            if(vis.osn.body.lwing)
            {
               vis.osn.body.lwing.visible = true;
            }
            if(World.w.alicorn || Boolean(this.currentArmor) && Boolean(this.currentArmor.ableFly))
            {
               try
               {
                  if(vis.osn.body.rwing.currentFrame != 11)
                  {
                     vis.osn.body.rwing.gotoAndStop(11);
                  }
                  if(vis.osn.body.lwing.currentFrame != 11)
                  {
                     vis.osn.body.lwing.gotoAndStop(11);
                  }
                  vis.osn.body.rwing.wing.wing2.rotation = 50 - Math.abs(dx) * 1.6;
                  vis.osn.body.lwing.wing.wing2.rotation = 50 - Math.abs(dx) * 1.2;
               }
               catch(err:*)
               {
               }
            }
            else if(isFly && !stay && !isPlav && !isLaz)
            {
               if(Boolean(vis.osn.body.rwing) && vis.osn.body.rwing.currentFrame == 1)
               {
                  vis.osn.body.rwing.gotoAndPlay(2);
               }
               if(Boolean(vis.osn.body.lwing) && vis.osn.body.lwing.currentFrame == 1)
               {
                  vis.osn.body.lwing.gotoAndPlay(2);
               }
            }
            else
            {
               if(vis.osn.body.rwing)
               {
                  vis.osn.body.rwing.gotoAndStop(1);
               }
               if(vis.osn.body.lwing)
               {
                  vis.osn.body.lwing.gotoAndStop(1);
               }
            }
         }
         else
         {
            if(vis.osn.body.rwing)
            {
               vis.osn.body.rwing.visible = false;
            }
            if(vis.osn.body.lwing)
            {
               vis.osn.body.lwing.visible = false;
            }
         }
         if(Boolean(vis.shit) && !vis.shit.visible && shithp > 0)
         {
            vis.shit.visible = true;
            vis.shit.gotoAndPlay(1);
         }
         if(Boolean(vis.shit) && Boolean(vis.shit.visible) && shithp <= 0)
         {
            vis.shit.visible = false;
            vis.shit.gotoAndStop(1);
         }
         if(this.isFetter > 0)
         {
            this.dfx = this.fetX - X;
            this.dfy = this.fetY - Y + 30;
            this.rfetter = Math.sqrt(this.dfx * this.dfx + this.dfy * this.dfy);
            vis.fetter.visible = true;
            vis.fetter.scaleX = this.rfetter / 100;
            vis.fetter.rotation = Math.atan2(this.dfy,this.dfx * storona) / Math.PI * 180;
         }
         else
         {
            vis.fetter.visible = false;
         }
      }
      
      public function refreshVis() : *
      {
         var _loc1_:* = undefined;
         _loc1_ = vis.osn.currentFrameLabel;
         vis.osn.gotoAndStop("nope");
         vis.osn.gotoAndStop(_loc1_);
         teleColor = World.w.app.cMagic;
         this.levitFilter1.color = teleColor;
         teleFilter.color = teleColor;
      }
      
      override public function visDetails() : *
      {
         World.w.gui.setHp();
      }
      
      public function showElectroBlock() : *
      {
         var _loc1_:Tile = null;
         _loc1_ = loc.getAbsTile(X + Math.random() * 320 - 160,Y - scY / 2 + Math.random() * 320 - 160);
         if(Boolean(_loc1_) && _loc1_.mat == 1 && _loc1_.hp > 0)
         {
            Emitter.emit("electro",loc,(_loc1_.X + 0.5) * Tile.tileX,(_loc1_.Y + 0.5) * Tile.tileY);
         }
      }
      
      override public function replic(param1:String) : *
      {
         var _loc2_:String = null;
         if(sost != 1 || id_replic == "")
         {
            return;
         }
         if(t_replic > 0)
         {
            return;
         }
         t_replic = 75 + Math.random() * 30;
         _loc2_ = Res.repText(id_replic,param1,false);
         if(_loc2_ == this.prev_replic)
         {
            _loc2_ = Res.repText(id_replic,param1,false);
         }
         if(_loc2_ == this.prev_replic)
         {
            return;
         }
         this.prev_replic = _loc2_;
         if(_loc2_ != "" && _loc2_ != null)
         {
            Emitter.emit("replic2",loc,X,Y - 90,{
               "txt":_loc2_,
               "ry":20
            });
         }
      }
      
      override public function sndStep(param1:int, param2:int = 0) : *
      {
         if(this.rat > 0)
         {
            return;
         }
         super.sndStep(param1,param2);
      }
      
      override protected function sndFall() : *
      {
         if(this.rat > 0)
         {
            return;
         }
         super.sndFall();
      }
   }
}

