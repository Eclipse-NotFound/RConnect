package fe.weapon
{
   import fe.*;
   import fe.graph.Emitter;
   import fe.unit.Pers;
   import fe.unit.Unit;
   import fe.unit.UnitPlayer;
   import flash.display.Graphics;
   import flash.geom.Point;
   import flash.media.SoundChannel;
   import flash.utils.*;
   
   public class Weapon extends Obj
   {
      
      public static var weaponPerks:Array = ["pistol","shot","commando","rifle","perf","laser","plasma","pyro","acute","stunning"];
      
      public static var variant2:* = " - II";
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectIntent:Function = null;
      
      public var b:Bullet;
      
      public var trasser:Trasser;
      
      public var owner:Unit;
      
      public var rot:Number;
      
      public var bulX:Number = 0;
      
      public var bulY:Number = 0;
      
      public var svis:String;
      
      public var svisv:String;
      
      public var vWeapon:Class;
      
      public var visbul:String;
      
      public var vBullet:Class;
      
      public var flare:String;
      
      public var visexpl:String;
      
      internal var is_attack:Boolean = false;
      
      internal var is_pattack:Boolean = false;
      
      public var t_attack:int = 0;
      
      public var t_prep:int = 0;
      
      public var t_reload:int = 0;
      
      public var t_rech:int = 0;
      
      public var t_rel:int = 0;
      
      public var t_shoot:int = 0;
      
      public var t_auto:int = 0;
      
      public var pow:int = 0;
      
      public var skillConf:Number = 1;
      
      public var skillPlusDam:Number = 1;
      
      public var weaponSkill:Number = 1;
      
      internal var t_ret:int = 0;
      
      internal var rotUp:Number = 0;
      
      public var jammed:Boolean = false;
      
      public var kol_shoot:int = 0;
      
      public var ready:Boolean = false;
      
      public var is_shoot:Boolean = false;
      
      protected var animated:Boolean = false;
      
      public var krep:int = 0;
      
      public var hold:int = 0;
      
      public var findCel:Boolean = true;
      
      public var forceRot:Number = 0;
      
      public var fixRot:int = 0;
      
      public var checkLine:Boolean = false;
      
      public var id:String;
      
      public var uniq:Number = -1;
      
      public var variant:int = 0;
      
      public var tip:int = 0;
      
      public var cat:int = 0;
      
      public var respect:int = 0;
      
      public var skill:int = 0;
      
      public var lvl:int = 0;
      
      public var lvlNoUse:Boolean = false;
      
      public var perslvl:int = 0;
      
      public var spell:Boolean = false;
      
      public var alicorn:Boolean = false;
      
      public var rep_eff:Number = 1;
      
      public var auto:Boolean = false;
      
      public var rapid:int = 5;
      
      public var speed:Number = 100;
      
      public var volna:Boolean = false;
      
      public var deviation:Number = 0;
      
      public var precision:Number = 0;
      
      public var antiprec:Number = 0;
      
      public var dlina:int = 50;
      
      public var mindlina:int = 50;
      
      public var mass:int = 1;
      
      public var drot:Number = 0;
      
      public var drot2:Number = 0;
      
      public var prep:int = 0;
      
      public var explRadius:Number = 0;
      
      public var explTip:int = 1;
      
      public var explKol:int = 0;
      
      public var destroy:Number = 10;
      
      public var damage:Number = 0;
      
      public var damageExpl:Number = 0;
      
      public var tipDamage:int = 0;
      
      public var pier:Number = 0;
      
      public var critCh:Number = 0.1;
      
      public var critM:Number = 0;
      
      public var critDamPlus:Number = 0;
      
      public var distExpl:Boolean = false;
      
      public var navod:Number = 0;
      
      public var otbros:Number = 0;
      
      public var kol:Number = 1;
      
      public var dkol:Number = 0;
      
      public var rashod:Number = 1;
      
      public var opt:Object;
      
      public var recoil:int = 0;
      
      public var recoilUp:int = 0;
      
      public var recoilMult:int = 1;
      
      public var desintegr:Number = 0;
      
      public var holder:int = 0;
      
      public var ammoBase:String = "";
      
      public var ammo:String = "";
      
      public var ammoTarg:String = "";
      
      public var reload:int = 0;
      
      public var recharg:int = 0;
      
      public var magic:Number = 100;
      
      public var dmagic:Number = 100;
      
      public var mana:Number = 100;
      
      public var dmana:Number = 100;
      
      public var noise:int = 0;
      
      public var shine:int = 500;
      
      public var tipDecal:int = 0;
      
      public var bulAnim:Boolean = false;
      
      public var spring:int = 1;
      
      public var flame:int = 0;
      
      public var grav:Number = 0;
      
      public var accel:Number = 0;
      
      public var shell:Boolean = false;
      
      public var fromWall:Boolean = false;
      
      public var bulBlend:String = "screen";
      
      internal var emitShell:Emitter = Emitter.arr["gilza"];
      
      public var dopEffect:String;
      
      public var dopDamage:Number = 0;
      
      public var dopCh:Number = 1;
      
      public var probiv:Number = 0;
      
      public var visionMult:Number = 1;
      
      public var drotMult:Number = 1;
      
      public var reloadMult:Number = 1;
      
      public var precMult:Number = 1;
      
      public var consMult:Number = 1;
      
      public var damMult:Number = 1;
      
      public var damAdd:Number = 0;
      
      public var pierAdd:Number = 0;
      
      public var critchAdd:Number = 0;
      
      public var speedMult:Number = 1;
      
      public var otbrosMult:Number = 1;
      
      public var explRadMult:Number = 1;
      
      public var devMult:Number = 1;
      
      public var absPierRnd:Number = 0;
      
      public var ammoPier:Number = 0;
      
      public var ammoArmor:Number = 1;
      
      public var ammoDamage:Number = 1;
      
      public var ammoProbiv:Number = 0;
      
      public var ammoOtbros:Number = 1;
      
      public var ammoPrec:Number = 1;
      
      public var ammoHP:int = 0;
      
      public var ammoFire:Number = 0;
      
      public var ammoMod:int = -1;
      
      public var satsQue:int = 1;
      
      public var satsCons:Number = 10;
      
      public var noSats:Boolean = false;
      
      public var noPerc:Boolean = false;
      
      public var noTrass:Boolean = false;
      
      public var satsMelee:Boolean = false;
      
      public var sndShoot:String = "";
      
      public var sndShoot_n:int = 1;
      
      public var sndReload:String = "";
      
      public var sndPrep:String = "";
      
      public var sndHit:String = "";
      
      public var snd_t_prep1:int = 0;
      
      public var snd_t_prep2:int = 0;
      
      internal var sndCh:SoundChannel;
      
      public var hp:int;
      
      public var maxhp:int = 100;
      
      public var price:int = 0;
      
      internal var breaking:Number = 0;
      
      public function Weapon(param1:Unit, param2:String, param3:int = 0)
      {
         super();
         sloy = 2;
         this.owner = param1;
         this.id = param2;
         this.variant = param3;
         this.opt = new Object();
         this.trasser = new Trasser();
         this.getXmlParam();
         this.setNull();
         if(!param1.player)
         {
            this.auto = true;
         }
      }
      
      private static function rconnectXmlFind(nodes:XMLList, key:String, expected:*) : XMLList
      {
         var result:XMLList = new XMLList();
         for each(var node in nodes)
         {
            if(node.attribute(key) == expected)
            {
               result += node;
            }
         }
         return result;
      }
      
      public static function create(param1:Unit, param2:String, param3:int = 0) : Weapon
      {
         var node:* = undefined;
         var w:Weapon = null;
         var owner:Unit = param1;
         var id:String = param2;
         var nvar:int = param3;
         if(id.charAt(id.length - 2) == "^")
         {
            id = id.substr(0,id.length - 2);
            nvar = 1;
         }
         var xl:XMLList = rconnectXmlFind(AllData.d.weapon,"id",id);
         if(xl.length() == 0)
         {
            return null;
         }
         node = rconnectXmlFind(AllData.d.weapon,"id",id);
         if(node.length() == 0)
         {
            return null;
         }
         node = node[0];
         if(node.@tip == 1)
         {
            w = new WClub(owner,id,nvar);
         }
         else if(node.@tip == 12)
         {
            w = new WPaint(owner,id,nvar);
         }
         else if(node.@tip == 4)
         {
            w = new WThrow(owner,id,nvar);
         }
         else if(node.@tip == 5)
         {
            w = new WMagic(owner,id,nvar);
         }
         else if(node.@punch > 0)
         {
            w = new WPunch(owner,id,nvar);
         }
         else
         {
            w = new Weapon(owner,id,nvar);
         }
         return w;
      }
      
      override public function err() : String
      {
         return "Error weapon " + nazv + ":" + (this.owner ? this.owner.nazv : "????");
      }
      
      public function getXmlParam() : *
      {
         var node:XML = null;
         var ammoNode:* = undefined;
         node = rconnectXmlFind(AllData.d.weapon,"id",id)[0];
         if(node.@tip.length())
         {
            this.tip = node.@tip;
         }
         if(this.variant == 0)
         {
            nazv = Res.txt("w",this.id);
         }
         else if(Res.istxt("w",this.id + "^" + this.variant))
         {
            nazv = Res.txt("w",this.id + "^" + this.variant);
         }
         else
         {
            nazv = Res.txt("w",this.id) + variant2;
         }
         this.cat = node.@cat;
         this.skill = node.@skill;
         if(node.@perk.length())
         {
            this.opt.perk = node.@perk;
            this.opt[node.@perk] = true;
         }
         this.lvl = node.@lvl;
         this.perslvl = node.@perslvl;
         if(node.@alicorn > 0)
         {
            this.alicorn = true;
         }
         if(node.sats.length())
         {
            if(node.sats[0].@que.length())
            {
               this.satsQue = node.sats[0].@que;
            }
            if(node.sats[0].@cons.length())
            {
               this.satsCons = node.sats[0].@cons;
            }
            if(node.sats[0].@no.length())
            {
               this.noSats = true;
            }
            if(node.sats[0].@noperc.length())
            {
               this.noPerc = true;
            }
         }
         if(node.com.length())
         {
            if(node.com[0].@rep.length())
            {
               this.rep_eff = node.com[0].@rep;
            }
            if(node.com[0].@price.length())
            {
               this.price = node.com[0].@price;
            }
            if(node.com[0].@uniq.length())
            {
               this.uniq = node.com[0].@uniq;
            }
            if(this.variant > 0 && Boolean(node.com[this.variant]) && Boolean(node.com[this.variant].@price.length()))
            {
               this.price = node.com[this.variant].@price;
            }
         }
         this.svis = "vis" + this.id;
         if(this.tip == 0)
         {
            this.svisv = null;
         }
         else if(this.variant > 0)
         {
            this.svisv = this.svis + "_" + this.variant;
         }
         else
         {
            this.svisv = this.svis;
         }
         if(node.vis.length())
         {
            this.getVisParam(node.vis[0]);
            if(this.variant > 0)
            {
               this.getVisParam(node.vis[this.variant]);
            }
         }
         if(this.tip > 0 || Boolean(this.svisv))
         {
            this.vWeapon = Res.getClass(this.svisv,this.svis,visp10mm);
            vis = new this.vWeapon();
         }
         if(Boolean(this.owner) && this.owner.weaponKrep > 0)
         {
            this.krep = this.owner.weaponKrep;
         }
         if(Boolean(vis) && vis.totalFrames > 1)
         {
            this.animated = true;
         }
         if(this.flare == null)
         {
            this.flare = this.visbul;
         }
         if(this.visbul)
         {
            try
            {
               this.vBullet = getDefinitionByName("visbul" + this.visbul) as Class;
            }
            catch(err:ReferenceError)
            {
               vBullet = visualBullet;
            }
         }
         else
         {
            this.vBullet = visualBullet;
         }
         if(node.snd.length())
         {
            this.getSndParam(node.snd[0]);
            if(this.variant > 0)
            {
               this.getSndParam(node.snd[this.variant]);
            }
         }
         if(node.phis.length())
         {
            this.getPhisParam(node.phis[0]);
            if(this.variant > 0)
            {
               this.getPhisParam(node.phis[this.variant]);
            }
         }
         if(node.ammo.length())
         {
            this.getAmmoParam(node.ammo[0]);
            if(this.variant > 0)
            {
               this.getAmmoParam(node.ammo[this.variant]);
            }
         }
         if(node.dop.length())
         {
            this.getDopParam(node.dop[0]);
            if(this.variant > 0)
            {
               this.getDopParam(node.dop[this.variant]);
            }
         }
         if(node.a.length())
         {
            this.ammo = this.ammoBase = node.a[0];
            ammoNode = rconnectXmlFind(AllData.d.item,"id",ammo)[0];
            this.setAmmo(this.ammo,ammoNode);
         }
         this.getCharParam(node.char[0]);
         if(this.variant > 0)
         {
            this.getCharParam(node.char[this.variant]);
         }
         this.recoilUp = this.recoil / 2;
         if(Boolean(this.owner) && !this.owner.player)
         {
            this.recoilUp *= 0.2;
         }
         this.t_rech = this.recharg;
         if(this.recharg)
         {
            this.hold = this.holder;
         }
         this.hp = this.maxhp;
         if(Boolean(this.owner) && this.owner.player)
         {
            if(this.tipDamage == Unit.D_BUL)
            {
               this.critDamPlus += 0.2;
            }
            if(this.tipDamage == Unit.D_PLASMA)
            {
               this.critDamPlus -= 0.2;
            }
         }
      }
      
      internal function getVisParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@vweap.length() > 0)
         {
            this.svisv = param1.@vweap;
         }
         if(param1.@tipdec.length())
         {
            this.tipDecal = param1.@tipdec;
         }
         if(param1.@shell.length())
         {
            this.shell = true;
         }
         if(param1.@spring.length())
         {
            this.spring = param1.@spring;
         }
         if(param1.@bulanim.length())
         {
            this.bulAnim = true;
         }
         if(param1.@phisbul.length())
         {
            this.bulBlend = "normal";
         }
         if(param1.@visexpl.length())
         {
            this.visexpl = param1.@visexpl;
         }
         if(param1.@shine.length())
         {
            this.shine = param1.@shine;
         }
         if(param1.@vbul.length())
         {
            this.visbul = param1.@vbul;
         }
         if(param1.@flare.length())
         {
            this.flare = param1.@flare;
         }
      }
      
      internal function getSndParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@shoot.length())
         {
            this.sndShoot = param1.@shoot;
         }
         if(param1.@shoot_n.length())
         {
            this.sndShoot_n = param1.@shoot_n;
         }
         if(param1.@reload.length())
         {
            this.sndReload = param1.@reload;
         }
         if(param1.@hit.length())
         {
            this.sndHit = param1.@hit;
         }
         if(param1.@prep.length())
         {
            this.sndPrep = param1.@prep;
         }
         if(param1.@t1.length())
         {
            this.snd_t_prep1 = param1.@t1;
         }
         if(param1.@t2.length())
         {
            this.snd_t_prep2 = param1.@t2;
         }
         if(param1.@noise.length())
         {
            this.noise = param1.@noise;
         }
      }
      
      internal function getDopParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@vision.length())
         {
            this.visionMult = param1.@vision;
         }
         if(param1.@effect.length())
         {
            this.dopEffect = param1.@effect;
         }
         if(param1.@damage.length())
         {
            this.dopDamage = param1.@damage;
         }
         if(param1.@ch.length())
         {
            this.dopCh = param1.@ch;
         }
         if(param1.@probiv.length())
         {
            this.probiv = param1.@probiv;
         }
      }
      
      internal function getPhisParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@massa > 0)
         {
            massa = param1.@massa / 50;
         }
         else
         {
            massa = 0;
         }
         if(param1.@m.length())
         {
            this.mass = param1.@m;
         }
         if(param1.@drot.length())
         {
            this.drot = param1.@drot * Math.PI / 180;
         }
         if(param1.@drot2.length())
         {
            this.drot2 = param1.@drot2 * Math.PI / 180;
         }
         if(param1.@recoil.length())
         {
            this.recoil = param1.@recoil;
         }
         if(param1.@speed.length())
         {
            this.speed = param1.@speed;
         }
         if(param1.@deviation.length())
         {
            this.deviation = param1.@deviation;
         }
         if(param1.@flame.length())
         {
            this.flame = param1.@flame;
         }
         if(param1.@grav.length())
         {
            this.grav = param1.@grav;
         }
         if(Boolean(this.owner) && this.owner.fraction != Unit.F_PLAYER && Boolean(param1.@grav2.length()))
         {
            this.grav = param1.@grav2;
         }
         if(param1.@accel.length())
         {
            this.accel = param1.@accel;
         }
         if(param1.@navod.length())
         {
            this.navod = param1.@navod;
         }
         if(param1.@distexpl.length())
         {
            this.distExpl = true;
         }
         if(param1.@volna.length())
         {
            this.volna = true;
         }
      }
      
      internal function getCharParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@maxhp.length())
         {
            this.maxhp = param1.@maxhp;
         }
         if(param1.@damage.length())
         {
            this.damage = param1.@damage;
         }
         if(param1.@damexpl.length())
         {
            this.damageExpl = param1.@damexpl;
         }
         if(param1.@rapid.length())
         {
            this.rapid = param1.@rapid;
         }
         if(param1.@pier.length())
         {
            this.pier = param1.@pier;
         }
         if(param1.@crit.length())
         {
            this.critM = param1.@crit - 1;
            this.critCh = 0.1 * param1.@crit;
         }
         if(param1.@critdam.length())
         {
            this.critDamPlus = param1.@critdam;
         }
         if(param1.@knock.length())
         {
            this.otbros = param1.@knock;
         }
         if(param1.@tipdam.length())
         {
            this.tipDamage = param1.@tipdam;
         }
         if(param1.@prec.length())
         {
            this.precision = param1.@prec * 40;
         }
         if(param1.@antiprec.length())
         {
            this.antiprec = param1.@antiprec * 40;
         }
         if(param1.@destroy.length())
         {
            this.destroy = param1.@destroy;
         }
         if(param1.@kol.length())
         {
            this.kol = param1.@kol;
         }
         if(param1.@dkol.length())
         {
            this.dkol = param1.@dkol;
         }
         if(param1.@expl.length())
         {
            this.explRadius = param1.@expl;
         }
         if(param1.@expltip.length())
         {
            this.explTip = param1.@expltip;
         }
         if(param1.@explkol.length())
         {
            this.explKol = param1.@explkol;
         }
         if(param1.@prep.length())
         {
            this.prep = param1.@prep;
         }
         this.auto = this.rapid <= 6;
         if(param1.@auto.length())
         {
            this.auto = param1.@auto != "0";
         }
      }
      
      internal function getAmmoParam(param1:XML) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.@holder.length())
         {
            this.holder = param1.@holder;
         }
         if(param1.@rashod.length())
         {
            this.rashod = param1.@rashod;
         }
         if(param1.@reload.length())
         {
            this.reload = param1.@reload;
         }
         if(param1.@recharg.length())
         {
            this.recharg = param1.@recharg;
         }
         if(param1.@mana.length())
         {
            this.mana = this.dmana = param1.@mana;
         }
         if(param1.@magic.length())
         {
            this.magic = this.dmagic = param1.@magic;
         }
      }
      
      public function updVariant(param1:int) : *
      {
         if(this.uniq < 0)
         {
            return;
         }
         this.variant = param1;
         if(this.owner.player && World.w.gg.currentWeapon == this)
         {
            remVisual();
         }
         this.getXmlParam();
         if(this.owner.player && World.w.gg.currentWeapon == this)
         {
            this.addVisual();
            World.w.gg.weaponLevit();
         }
      }
      
      override public function step() : *
      {
         this.actions();
         if(this.owner)
         {
            this.owner.setWeaponPos(this.tip);
         }
         if(vis)
         {
            this.animate();
         }
      }
      
      override public function addVisual() : *
      {
         if(this.owner)
         {
            loc = this.owner.loc;
         }
         else
         {
            loc = World.w.loc;
         }
         super.addVisual();
         if(Boolean(this.owner) && this.tip != 5 && Boolean(this.owner.cTransform))
         {
            vis.transform.colorTransform = this.owner.cTransform;
         }
      }
      
      public function addVisual2() : *
      {
         if(this.tip == 5 && Boolean(vis))
         {
            World.w.grafon.visObjs[sloy].addChild(vis);
         }
      }
      
      override public function setNull(param1:Boolean = false) : *
      {
         this.t_attack = this.t_reload = 0;
         if(this.owner)
         {
            X = this.owner.weaponX;
            Y = this.owner.weaponY;
            this.animate();
         }
      }
      
      public function setPers(param1:UnitPlayer, param2:Pers) : *
      {
         var _loc4_:* = undefined;
         this.weaponSkill = param2.weaponSkills[this.skill];
         if(param2.desintegr > 0)
         {
            this.desintegr = param2.desintegr;
         }
         if(this.tip != 5)
         {
            this.drotMult = param2.drotMult;
         }
         this.reloadMult = param2.reloadMult;
         this.precMult = param2.allPrecMult;
         this.recoilMult = param2.recoilMult;
         this.consMult = 1;
         this.damMult = param2.allDamMult;
         if(this.skill == 2 || this.skill == 3 || this.skill == 4)
         {
            this.damMult *= param2.gunsDamMult;
         }
         var _loc3_:* = this.lvl - param2.getWeapLevel(this.skill);
         if(_loc3_ < 0)
         {
            this.skillPlusDam = 1 - _loc3_ * 0.1;
         }
         else
         {
            this.skillPlusDam = 1;
         }
         this.speedMult = 1;
         this.damAdd = 0;
         this.pierAdd = 0;
         this.critchAdd = 0;
         this.otbrosMult = 1;
         this.devMult = 1;
         for each(_loc4_ in weaponPerks)
         {
            if(this.opt[_loc4_])
            {
               if(param2.hasOwnProperty(_loc4_ + "Prec"))
               {
                  this.precMult *= param2[_loc4_ + "Prec"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Cons"))
               {
                  this.consMult *= param2[_loc4_ + "Cons"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Dam"))
               {
                  this.damMult *= param2[_loc4_ + "Dam"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Speed"))
               {
                  this.speedMult *= param2[_loc4_ + "Speed"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Det"))
               {
                  this.damAdd += param2[_loc4_ + "Det"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Pier"))
               {
                  this.pierAdd += param2[_loc4_ + "Pier"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Critch"))
               {
                  this.critchAdd += param2[_loc4_ + "Critch"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Knock"))
               {
                  this.otbrosMult *= param2[_loc4_ + "Knock"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Dev"))
               {
                  this.devMult *= param2[_loc4_ + "Dev"];
               }
               if(param2.hasOwnProperty(_loc4_ + "Stun"))
               {
                  this.dopEffect = "stun";
                  this.dopDamage = param2[_loc4_ + "Stun"];
                  this.dopCh = 1;
               }
            }
         }
         this.absPierRnd = param2.modTarget;
         this.explRadMult = param2.explRadMult;
      }
      
      public function actions() : *
      {
         var rdrot:Number;
         var rot2:Number = Number(NaN);
         if(this.owner == null)
         {
            return;
         }
         if(X < this.owner.celX)
         {
            storona = 1;
         }
         else
         {
            storona = -1;
         }
         if(this.findCel)
         {
            if(this.tip == 5)
            {
               X = this.owner.magicX;
               Y = this.owner.magicY;
               rot2 = Math.atan2(this.owner.celY - Y,this.owner.celX - X);
            }
            else if(this.krep > 0 || !X)
            {
               X = this.owner.weaponX;
               Y = this.owner.weaponY;
               rot2 = Math.atan2(this.owner.celY - Y,Math.abs(this.owner.celX - X) * this.owner.storona);
            }
            else
            {
               X += (this.owner.weaponX - X) / 5;
               Y += (this.owner.weaponY - Y) / 5;
               rot2 = Math.atan2(this.owner.celY - Y,this.owner.celX - X);
            }
         }
         else
         {
            X = this.owner.weaponX;
            Y = this.owner.weaponY;
            rot2 = this.forceRot;
         }
         this.ready = false;
         rdrot = this.drot;
         if(this.drot2 > 0 && (this.t_prep > 0 || this.t_attack > 0))
         {
            rdrot = this.drot2;
         }
         if(rdrot == 0)
         {
            this.rot = rot2;
            this.ready = true;
         }
         else
         {
            if(Math.abs(this.rot - rot2) > Math.PI)
            {
               if(Math.abs(this.rot - rot2) > Math.PI * 2 - rdrot * this.drotMult)
               {
                  this.rot = rot2;
                  this.ready = true;
               }
               else if(this.rot > rot2)
               {
                  this.rot += rdrot * this.drotMult;
               }
               else
               {
                  this.rot -= rdrot * this.drotMult;
               }
            }
            else if(rot2 - this.rot > rdrot * this.drotMult)
            {
               this.rot += rdrot * this.drotMult;
            }
            else if(rot2 - this.rot < -rdrot * this.drotMult)
            {
               this.rot -= rdrot * this.drotMult;
            }
            else
            {
               this.rot = rot2;
               this.ready = true;
            }
            if(this.rot > Math.PI)
            {
               this.rot -= Math.PI * 2;
            }
            if(this.rot < -Math.PI)
            {
               this.rot += Math.PI * 2;
            }
         }
         if(this.fixRot == 1)
         {
            if(this.rot < -Math.PI / 6 && this.rot > -Math.PI / 2)
            {
               this.rot = -Math.PI / 6;
            }
            if(this.rot > -Math.PI * 5 / 6 && this.rot <= -Math.PI / 2)
            {
               this.rot = -Math.PI * 5 / 6;
            }
         }
         if(this.fixRot == 2)
         {
            if(this.rot < -Math.PI / 6)
            {
               this.rot = -Math.PI / 6;
            }
            if(this.rot > Math.PI / 6)
            {
               this.rot = Math.PI / 6;
            }
         }
         if(this.fixRot == 3)
         {
            if(this.rot > 0 && this.rot < Math.PI * 5 / 6)
            {
               this.rot = Math.PI * 5 / 6;
            }
            if(this.rot <= 0 && this.rot > -Math.PI * 5 / 6)
            {
               this.rot = -Math.PI * 5 / 6;
            }
         }
         try
         {
            if(this.dkol <= 0 && this.t_attack == this.rapid)
            {
               this.shoot();
            }
            if(this.dkol > 0 && this.t_attack > this.rapid && this.t_attack % this.rapid == 0)
            {
               this.shoot();
            }
         }
         catch(err:*)
         {
            trace("err shoot",owner.nazv);
         }
         if(this.t_attack > 0)
         {
            --this.t_attack;
         }
         if(this.t_rel > 0)
         {
            --this.t_rel;
         }
         if(this.t_ret > 0)
         {
            --this.t_ret;
         }
         if(this.rotUp > 5)
         {
            this.rotUp *= 0.9;
         }
         else if(this.rotUp > 0.5)
         {
            this.rotUp -= 0.5;
         }
         else
         {
            this.rotUp = 0;
         }
         if(this.t_prep > 0)
         {
            --this.t_prep;
         }
         else
         {
            this.kol_shoot = 0;
         }
         if(this.t_auto > 0)
         {
            --this.t_auto;
         }
         else
         {
            this.pow = 0;
         }
         if(this.t_shoot > 0)
         {
            --this.t_shoot;
         }
         if(this.sndPrep != "")
         {
            if(!this.is_pattack && this.is_attack)
            {
               this.sndCh = Snd.ps(this.sndPrep,X,Y,this.t_prep * 30);
            }
            if(this.snd_t_prep1 > 0 && this.is_attack && this.sndCh != null && this.sndCh.position > this.snd_t_prep2 - 300)
            {
               Snd.rconnectStopChannel(this.sndCh);
               this.sndCh = Snd.ps(this.sndPrep,X,Y,this.snd_t_prep1 + 200);
            }
            if(this.snd_t_prep2 > 0 && this.is_pattack && !this.is_attack && this.t_prep > 0 && this.sndCh != null && this.sndCh.position < this.snd_t_prep2 - 400)
            {
               Snd.rconnectStopChannel(this.sndCh);
               this.sndCh = Snd.ps(this.sndPrep,X,Y,this.snd_t_prep2 + 100);
            }
         }
         if(Boolean(this.recharg) && this.hold < this.holder && this.t_attack == 0)
         {
            --this.t_rech;
            if(this.t_rech <= 0)
            {
               ++this.hold;
               this.t_rech = this.recharg;
               if(this.owner.player)
               {
                  World.w.gui.setWeapon();
               }
            }
         }
         if(this.t_attack == 0 && this.t_reload > 0)
         {
            --this.t_reload;
         }
         if(this.t_reload == Math.round(10 * this.reloadMult))
         {
            this.reloadWeapon();
         }
         this.is_pattack = this.is_attack;
         this.is_attack = false;
      }
      
      public function attack(param1:Boolean = false) : Boolean
      {
         if(param1 && !this.ready)
         {
            return false;
         }
         if(this.hp <= 0 && this.owner == World.w.gg)
         {
            World.w.gui.infoText("brokenWeapon",nazv,null,false);
            World.w.gui.bulb(X,Y);
            return false;
         }
         if(this.owner.player && (this.respect == 1 || this.alicorn && !World.w.alicorn))
         {
            World.w.gui.infoText("disWeapon",null,null,false);
            return false;
         }
         if(!param1 && !World.w.alicorn && !this.auto && this.t_auto > 0)
         {
            this.t_auto = 3;
            ++this.pow;
            return true;
         }
         this.skillConf = 1;
         if(this.owner.player)
         {
            if(!this.checkAvail())
            {
               return false;
            }
         }
         if(this.holder > 0 && this.hold < this.rashod)
         {
            this.initReload();
            return false;
         }
         this.weaponAttack();
         this.is_attack = true;
         if(this.t_prep < this.prep + 10)
         {
            this.t_prep += 2;
         }
         if(this.t_prep >= this.prep && this.t_attack <= 0 && this.t_reload <= 0)
         {
            if(this.dkol <= 0)
            {
               this.t_attack = this.rapid;
            }
            else
            {
               this.t_attack = this.rapid * (this.dkol + 1);
            }
            if(this.holder == 1)
            {
               this.initReload();
            }
         }
         return true;
      }
      
      protected function weaponAttack() : *
      {
         if(this.jammed)
         {
            if(this.tipDamage == Unit.D_LASER || this.tipDamage == Unit.D_PLASMA || this.tipDamage == Unit.D_EMP || this.tipDamage == Unit.D_SPARK)
            {
               World.w.gui.infoText("weaponCircuit",null,null,false);
            }
            else
            {
               World.w.gui.infoText("weaponJammed",null,null,false);
            }
            Snd.ps("no_ammo",X,Y);
            this.initReload();
            return false;
         }
         if(this.hp < this.maxhp / 2)
         {
            this.breaking = (this.maxhp - this.hp) / this.maxhp * 2 - 1;
         }
         else
         {
            this.breaking = 0;
         }
      }
      
      protected function checkAvail() : Boolean
      {
         var _loc1_:* = this.lvl - (this.owner as UnitPlayer).pers.getWeapLevel(this.skill);
         if(_loc1_ == 1)
         {
            this.skillConf = 0.8;
         }
         else if(_loc1_ == 2)
         {
            this.skillConf = 0.6;
         }
         else if(_loc1_ > 2)
         {
            World.w.gui.infoText("weaponSkillLevel",null,null,false);
            return false;
         }
         if(Boolean(this.perslvl) && (this.owner as UnitPlayer).pers.level < this.perslvl)
         {
            World.w.gui.infoText("persLevel",null,null,false);
            return false;
         }
         return true;
      }
      
      public function attackPos() : Boolean
      {
         return this.t_attack <= 0 && this.t_reload <= 0;
      }
      
      public function getBulXY() : *
      {
         var p:Point = null;
         var p1:Point = null;
         try
         {
            if(Boolean(vis) && Boolean(vis.emit) && Boolean(vis.parent))
            {
               p = new Point(vis.emit.x,vis.emit.y);
               p1 = vis.localToGlobal(p);
               p1 = vis.parent.globalToLocal(p1);
               this.bulX = p1.x;
               this.bulY = p1.y;
            }
            else
            {
               this.bulX = X;
               this.bulY = Y;
            }
         }
         catch(err:*)
         {
            bulX = X;
            bulY = Y;
         }
      }
      
      protected function shoot() : Bullet
      {
         var _loc1_:*;
         var _loc2_:*;
         var _loc3_:*;
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         if(this.breaking > 0 && Boolean(this.owner) && this.owner.player)
         {
            _loc4_ = Math.random();
            _loc5_ = (this.owner as UnitPlayer).pers.jammedMult;
            if(_loc4_ < this.breaking / Math.max(20,this.holder) * _loc5_)
            {
               this.t_ret = 2;
               this.jammed = true;
               return null;
            }
            if(_loc4_ < this.breaking / 5 * _loc5_)
            {
               this.t_ret = 2;
               if(this.rapid > 5)
               {
                  World.w.gui.infoText("misfire",null,null,false);
               }
               Snd.ps("no_ammo",X,Y);
               return null;
            }
         }
         if(this.holder > 0 && this.hold < this.rashod)
         {
            return null;
         }
         _loc1_ = 1;
         if(this.owner)
         {
            _loc1_ = this.owner.weaponSkill;
            if(this.owner.player)
            {
               _loc1_ = this.weaponSkill;
            }
         }
         _loc2_ = (Math.random() - 0.5) * (this.deviation * (1 + this.breaking * 2) / this.skillConf / (_loc1_ + 0.01) + this.owner.mazil) * 3.1415 / 180 * this.devMult;
         this.getBulXY();
         _loc3_ = 0;
         while(_loc3_ < this.kol)
         {
            if(this.navod)
            {
               this.b = new SmartBullet(this.owner,this.bulX,this.bulY,this.vBullet);
               (this.b as SmartBullet).setCel(World.w.gg,this.navod);
            }
            else
            {
               this.b = new Bullet(this.owner,this.bulX,this.bulY,this.vBullet);
            }
            this.b.weap = this;
            if(this.b.vis)
            {
               this.b.vis.blendMode = this.bulBlend;
            }
            if(this.fromWall)
            {
               try
               {
                  if(loc.getAbsTile(this.bulX,this.bulY).phis)
                  {
                     this.b.inWall = true;
                  }
               }
               catch(err:*)
               {
               }
            }
            if(Boolean(this.b.vis) && this.spring == 3)
            {
               this.b.vis.gotoAndStop(_loc3_ + 1);
            }
            this.b.rot = this.rot - this.rotUp * storona / 50 + _loc2_ + (_loc3_ - (this.kol - 1) / 2) * this.deviation * 3.1415 / 360;
            if(this.grav > 0 || this.volna)
            {
               this.b.vel = this.speed * this.speedMult;
            }
            else
            {
               this.b.vel = this.speed * this.speedMult * (Math.random() * 0.4 + 0.8);
            }
            this.b.dx = Math.cos(this.b.rot) * this.b.vel;
            this.b.dy = Math.sin(this.b.rot) * this.b.vel;
            this.b.knockx = this.b.dx / this.b.vel;
            this.b.knocky = this.b.dy / this.b.vel;
            if(Boolean(this.owner) && this.distExpl)
            {
               this.b.celX = this.owner.celX;
               this.b.celY = this.owner.celY;
            }
            if(this.damage > 0)
            {
               this.b.damage = this.resultDamage(this.damage,_loc1_) * this.ammoDamage;
            }
            if(this.damageExpl > 0)
            {
               this.b.damageExpl = this.resultDamage(this.damageExpl,_loc1_);
            }
            this.setBullet(this.b);
            this.b.miss = 1 - this.skillConf;
            this.b.ddy = this.b.ddx = 0;
            if(this.desintegr)
            {
               this.b.desintegr = this.desintegr;
            }
            if(this.owner)
            {
               this.b.precision = this.resultPrec(this.owner.precMult,_loc1_);
               this.b.antiprec = this.antiprec;
            }
            if(this.accel)
            {
               this.b.ddx += Math.cos(this.b.rot) * this.accel;
               this.b.ddy += Math.sin(this.b.rot) * this.accel;
               this.b.accel = this.accel;
            }
            if(this.flame > 0)
            {
               this.b.flame = this.flame;
               if(this.flame == 1)
               {
                  this.b.ddy += -0.8 - Math.random() * 0.2;
                  this.b.brakeR = 180 + Math.random() * 40;
                  this.b.liv = this.b.brakeR / 7;
               }
               else if(this.flame == 2)
               {
                  this.b.ddy += -0.2 - Math.random() * 0.2;
                  this.b.brakeR = 100 + Math.random() * 40;
                  this.b.liv = this.b.brakeR / 7;
               }
            }
            if(this.grav)
            {
               this.b.ddy += World.ddy * this.grav;
               this.b.vRot = true;
            }
            if(this.bulAnim)
            {
               this.b.vis.play();
            }
            _loc3_++;
         }
         if(this.shell)
         {
            this.emitShell.cast(loc,X,Y,{
               "dx":-10 * vis.scaleX,
               "dy":-10,
               "dr":-15 * vis.scaleX
            });
         }
         if(this.owner.demask < this.shine)
         {
            this.owner.demask = this.shine;
         }
         if(this.noise > 0)
         {
            this.owner.makeNoise(this.noise,true);
         }
         this.owner.isShoot = true;
         if(this.holder > 0 && this.hold > 0)
         {
            if(!(this.owner.player && (this.owner as UnitPlayer).pers.recyc > 0 && (this.ammo == "batt" || this.ammo == "energ" || this.ammo == "crystal") && Math.random() < (this.owner as UnitPlayer).pers.recyc))
            {
               this.hold -= this.rashod;
               if(this.owner.player && loc.train && this.ammo != "recharg" && this.ammo != "not")
               {
                  World.w.invent.items[this.ammo].kol += this.rashod;
                  World.w.invent.mass[2] += World.w.invent.items[this.ammo].mass * this.rashod;
               }
            }
         }
         if(this.owner.player && this.tip < 4 && this.tip != 0 && !(loc.train || World.w.alicorn))
         {
            this.hp -= 1 + this.ammoHP;
         }
         if(this.animated && this.t_shoot <= 1)
         {
            try
            {
               vis.gotoAndPlay("shoot");
            }
            catch(err:*)
            {
            }
            this.t_shoot = 3;
         }
         ++this.kol_shoot;
         this.t_ret = Math.round(this.recoil * this.recoilMult);
         if(this.recoil > 3 && this.t_ret < 3)
         {
            this.t_ret = 3;
         }
         this.rotUp += this.recoilUp * this.recoilMult;
         this.is_shoot = true;
         if(this.sndShoot != "" && this.kol_shoot % this.sndShoot_n == 0)
         {
            Snd.ps(this.sndShoot,X,Y);
         }
         this.t_auto = 3;
         return this.b;
      }
      
      public function resultDamage(param1:Number, param2:Number = 1) : Number
      {
         return (param1 + this.damAdd) * this.damMult * param2 * this.skillPlusDam * (1 - this.breaking * 0.3);
      }
      
      public function resultPrec(param1:Number = 1, param2:Number = 1) : Number
      {
         return this.precision * this.precMult * (1 + (param2 - 1) * 0.5) * param1 * this.owner.precMultCont;
      }
      
      public function resultRapid(param1:Number, param2:Number = 1) : Number
      {
         return param1;
      }
      
      public function setTrass(param1:Graphics) : *
      {
         var _loc2_:* = Math.atan2(World.w.celY - Y,World.w.celX - X);
         this.trasser.loc = this.owner.loc;
         this.trasser.X = this.trasser.begx = X;
         this.trasser.Y = this.trasser.begy = Y;
         this.trasser.dx = this.trasser.begdx = Math.cos(_loc2_) * this.speed * this.speedMult;
         this.trasser.dy = this.trasser.begdy = Math.sin(_loc2_) * this.speed * this.speedMult;
         this.trasser.ddy = this.trasser.ddx = 0;
         if(this.grav)
         {
            this.trasser.ddy += World.ddy;
         }
         this.trasser.trass(param1);
      }
      
      public function isLine(param1:Number, param2:Number) : Boolean
      {
         if(this.checkLine)
         {
            return this.owner.loc.isLine(X,Y,param1,param2);
         }
         return true;
      }
      
      protected function setBullet(param1:Bullet) : *
      {
         param1.tipDamage = this.tipDamage;
         param1.tipDecal = this.tipDecal;
         param1.otbros = this.otbros * this.otbrosMult * this.ammoOtbros;
         param1.pier = this.pier + this.pierAdd + this.ammoPier;
         param1.armorMult = this.ammoArmor;
         param1.destroy = this.destroy;
         param1.precision = this.precision * this.ammoPrec;
         param1.explTip = this.explTip;
         param1.explRadius = this.explRadius * this.explRadMult;
         param1.explKol = this.explKol;
         param1.spring = this.spring;
         param1.flare = this.flare;
         param1.probiv = this.probiv + this.ammoProbiv;
         if(param1.probiv > 1)
         {
            param1.probiv = 1;
         }
         if(this.ammoMod >= 0)
         {
            param1.tipDamage = this.ammoMod;
            if(this.ammoMod == 8)
            {
               param1.destroy = param1.otbros = 0;
            }
         }
         if(this.owner)
         {
            param1.critCh = this.critCh + this.owner.critCh + this.critchAdd;
            param1.critInvis = this.owner.critInvis;
            param1.critDamMult = this.owner.critDamMult + this.critDamPlus;
            param1.critM = this.critM;
         }
         if(this.absPierRnd > 0 && Math.random() < this.absPierRnd * this.critCh)
         {
            param1.pier = 1000;
         }
      }
      
      public function reloadWeapon() : *
      {
         var _loc1_:int = 0;
         this.jammed = false;
         if(this.ammo == "recharg")
         {
            return;
         }
         if(Boolean(this.owner) && this.owner.player && this.ammo != "not")
         {
            if(this.ammoTarg != this.ammo)
            {
               if(this.hold > 0)
               {
                  World.w.invent.items[this.ammo].kol += this.hold;
                  World.w.invent.mass[2] += World.w.invent.items[this.ammo].mass * this.hold;
                  this.hold = 0;
               }
               this.setAmmo(this.ammoTarg);
            }
            _loc1_ = int(World.w.invent.items[this.ammo].kol);
            if(_loc1_ > this.holder - this.hold)
            {
               _loc1_ = this.holder - this.hold;
            }
            this.hold += _loc1_;
            World.w.invent.items[this.ammo].kol -= _loc1_;
            World.w.invent.mass[2] -= World.w.invent.items[this.ammo].mass * _loc1_;
         }
         else
         {
            if(this.ammoTarg != this.ammo)
            {
               this.setAmmo(this.ammoTarg);
            }
            this.hold = this.holder;
         }
      }
      
      public function setAmmo(param1:String = null, param2:XML = null) : *
      {
         if(param1 != null)
         {
            this.ammo = param1;
         }
         if(param2 == null)
         {
            param2 = World.w.invent.items[this.ammo].xml;
            if(Boolean(this.owner) && this.owner.player && Boolean(World.w.gui))
            {
               World.w.gui.setWeapon();
            }
         }
         if(param2 == null)
         {
            trace("Неправильный патрон",this.ammo);
            return;
         }
         this.ammoPier = 0;
         this.ammoArmor = 1;
         this.ammoDamage = 1;
         this.ammoProbiv = 0;
         this.ammoOtbros = 1;
         this.ammoPrec = 1;
         this.ammoHP = 0;
         this.ammoFire = 0;
         this.ammoMod = -1;
         if(param2.@pier.length())
         {
            this.ammoPier = param2.@pier;
         }
         if(param2.@armor.length())
         {
            this.ammoArmor = param2.@armor;
         }
         if(param2.@damage.length())
         {
            this.ammoDamage = param2.@damage;
         }
         if(param2.@probiv.length())
         {
            this.ammoProbiv = param2.@probiv;
         }
         if(param2.@knock.length())
         {
            this.ammoOtbros = param2.@knock;
         }
         if(param2.@prec.length())
         {
            this.ammoPrec = param2.@prec;
         }
         if(param2.@det.length())
         {
            this.ammoHP = param2.@det;
         }
         if(param2.@fire.length())
         {
            this.ammoFire = param2.@fire;
         }
         if(param2.@tipdam.length())
         {
            this.ammoMod = param2.@tipdam;
         }
      }
      
      public function unloadWeapon() : *
      {
         if(this.owner && this.owner.player && this.holder && this.hold && this.ammo != "" && this.ammo != "recharg" && this.ammo != "not")
         {
            World.w.gui.infoText("unloadWeapon",nazv,null,false);
            (this.owner as UnitPlayer).invent.items[this.ammo].kol += this.hold;
            World.w.invent.mass[2] += World.w.invent.items[this.ammo].mass * this.hold;
            this.hold = 0;
            if(this.sndReload != "")
            {
               Snd.ps(this.sndReload,X,Y);
            }
         }
      }
      
      public function status() : int
      {
         if(this.hp <= 0)
         {
            return 5;
         }
         if(this.jammed)
         {
            return 2;
         }
         if(this.ammo != "recharg" && this.ammo != "not" && this.holder > 0 && this.hold < this.rashod)
         {
            if(World.w.invent.items[this.ammo].kol < this.rashod)
            {
               return 4;
            }
            return 2;
         }
         if(this.dmagic > this.owner.mana && this.owner.mana < this.owner.maxmana * 0.99)
         {
            return 6;
         }
         if(this.t_attack > 0)
         {
            return 1;
         }
         if(this.t_reload > 0)
         {
            return 3;
         }
         return 0;
      }
      
      public function avail() : int
      {
         if(this.hp <= 0)
         {
            return -2;
         }
         if(Boolean(this.perslvl) && (this.owner as UnitPlayer).pers.level < this.perslvl)
         {
            return -1;
         }
         var _loc1_:* = this.lvl - (this.owner as UnitPlayer).pers.getWeapLevel(this.skill);
         if(World.w.weaponsLevelsOff && (_loc1_ > 2 || this.lvlNoUse && _loc1_ > 0))
         {
            return -1;
         }
         if(this.ammo != "recharg" && this.ammo != "not" && this.holder > 0 && World.w.invent.items[this.ammo].kol < this.rashod)
         {
            return 0;
         }
         return 1;
      }
      
      public function repair(param1:int) : *
      {
         this.hp += param1;
         if(this.hp > this.maxhp)
         {
            this.hp = this.maxhp;
         }
      }
      
      public function crash(param1:int = 1) : *
      {
      }
      
      public function initReload(param1:String = "") : *
      {
         var am:*;
         var nammo:String;
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"initReload",[param1])))
         {
            return;
         }
         am = undefined;
         nammo = param1;
         if(!this.jammed && (this.holder <= 0 || this.hold == this.holder && nammo == "" || this.recharg > 0))
         {
            return;
         }
         if(nammo == "")
         {
            this.ammoTarg = this.ammo;
         }
         if(this.owner.player)
         {
            if(nammo != "" && nammo != this.ammo)
            {
               am = rconnectXmlFind(AllData.d.item,"id",nammo);
               if(am.length() == 0)
               {
                  return;
               }
               if(am.@base != this.ammoBase)
               {
                  World.w.gui.infoText("imprAmmo",World.w.invent.items[nammo].nazv,null,false);
                  World.w.gui.bulb(X,Y);
                  return;
               }
               this.ammoTarg = nammo;
            }
            if(nammo != "" && nammo == this.ammo)
            {
               this.ammoTarg = nammo;
            }
            if(!this.jammed && this.ammo != "not" && World.w.invent.items[this.ammoTarg].kol < this.rashod)
            {
               World.w.gui.infoText("noAmmo",World.w.invent.items[this.ammoTarg].nazv,null,false);
               World.w.gui.bulb(X,Y);
               return;
            }
         }
         if(this.t_reload <= 0 || this.reload == 0)
         {
            if(this.reload > 0)
            {
               this.t_reload = Math.round(this.reload * this.reloadMult);
               if(this.animated)
               {
                  try
                  {
                     vis.gotoAndPlay("reload");
                  }
                  catch(err:*)
                  {
                  }
               }
               if(this.sndReload != "")
               {
                  Snd.ps(this.sndReload,X,Y);
               }
            }
            else
            {
               this.reloadWeapon();
            }
         }
      }
      
      public function detonator() : Boolean
      {
         return false;
      }
      
      public function animate() : *
      {
         if(!vis)
         {
            return;
         }
         vis.x = X - this.t_ret * vis.scaleX * 2;
         vis.y = Y;
         if(Boolean(this.prep) && this.t_shoot <= 0)
         {
            if(this.t_prep < this.prep && this.t_prep > 1)
            {
               vis.gotoAndStop(this.t_prep);
            }
            if(this.t_prep >= this.prep)
            {
               try
               {
                  vis.gotoAndStop("ready");
               }
               catch(err:*)
               {
               }
            }
            if(this.t_prep <= 1 && this.t_reload == 0)
            {
               vis.gotoAndStop(1);
            }
         }
         if(this.krep == 0)
         {
            if(X > this.owner.celX)
            {
               vis.scaleX = -1;
               vis.rotation = this.rot * 180 / Math.PI + 180 + this.rotUp;
            }
            if(X < this.owner.celX)
            {
               vis.scaleX = 1;
               vis.rotation = this.rot * 180 / Math.PI - this.rotUp;
            }
         }
         else
         {
            vis.scaleX = this.owner.storona;
            vis.rotation = this.rot * 180 / Math.PI + 90 * (1 - this.owner.storona) - this.rotUp * storona;
         }
      }
      
      public function write() : String
      {
         var s:String = "";
         s += this.id;
         if(this.variant > 0)
         {
            s += "^" + this.variant;
         }
         s += "\t";
         s += nazv + "\t";
         s += this.skill + "\t";
         if(this.lvl > 0)
         {
            s += this.lvl + "\t";
         }
         else if(this.tip == 5 && this.variant > 0)
         {
            s += this.perslvl + 7 + "\t";
         }
         else
         {
            s += this.perslvl + "\t";
         }
         if(this.damage > 0)
         {
            s += this.damage;
         }
         if(this.kol > 1)
         {
            s += " [x" + this.kol + "]";
         }
         if(this.damageExpl > 0)
         {
            s += "(" + this.damageExpl + " взр) ";
         }
         s += "\t";
         s += (30 / this.rapid).toFixed(1) + "\t";
         s += ((this.damage + this.damageExpl) * this.kol * 30 / this.rapid).toFixed(1) + "\t";
         s += Res.pipText("tipdam" + this.tipDamage) + "\t";
         s += Math.round(this.critCh * 100) + "%\t";
         s += Math.round(this.precision / 40) + "\t";
         s += this.pier + "\t";
         if(this.tip == 5)
         {
            s += "магия\t" + this.mana + "\t";
         }
         else
         {
            if(this.ammo != "")
            {
               s += Res.txt("i",this.ammo) + "\t";
            }
            else
            {
               s += "\t";
            }
            if(this.holder > 0)
            {
               s += this.holder;
               if(this.rashod > 1)
               {
                  s += " (-" + this.rashod + ")";
               }
            }
            s += "\t";
         }
         s += this.satsCons;
         if(this.satsQue > 1)
         {
            s += " [x" + this.satsQue + "]";
         }
         s += "\t";
         if(Boolean(this.opt) && Boolean(this.opt.perk))
         {
            s += Res.txt("e",this.opt.perk);
         }
         s += "\t";
         if(this.tip < 4)
         {
            s += this.maxhp + "\t";
         }
         else
         {
            s += "\t";
         }
         if(this.tip == 4)
         {
            s += rconnectXmlFind(AllData.d.item,"id",id).@price + "\t";
         }
         else if(this.tip != 5 && this.variant > 0)
         {
            s += this.price * 3 + "\t";
         }
         else
         {
            s += this.price + "\t";
         }
         return s;
      }
   }
}

