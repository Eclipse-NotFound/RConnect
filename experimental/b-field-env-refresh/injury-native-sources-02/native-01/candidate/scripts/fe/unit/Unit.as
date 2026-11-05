package fe.unit
{
   // PI_HOOK_V1: PermanentInjury optional exact-event bridge.
   import fe.*;
   import fe.graph.Emitter;
   import fe.graph.Part;
   import fe.loc.*;
   import fe.serv.*;
   import fe.weapon.*;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.media.SoundChannel;
   import flash.utils.*;
   
   public class Unit extends Obj
   {
      
      public static var txtMiss:String;
      
      public static var arrIcos:Array;
      
      public static const RCONNECT_SECURITY_B:String = "b-security-v1";
      
      public static var rconnectSecurityB:Function;
      
      public static const D_BUL:* = 0;
      
      public static const D_BLADE:* = 1;
      
      public static const D_PHIS:* = 2;
      
      public static const D_FIRE:* = 3;
      
      public static const D_EXPL:* = 4;
      
      public static const D_LASER:* = 5;
      
      public static const D_PLASMA:* = 6;
      
      public static const D_VENOM:* = 7;
      
      public static const D_EMP:* = 8;
      
      public static const D_SPARK:* = 9;
      
      public static const D_ACID:* = 10;
      
      public static const D_CRIO:* = 11;
      
      public static const D_POISON:* = 12;
      
      public static const D_BLEED:* = 13;
      
      public static const D_FANG:* = 14;
      
      public static const D_BALE:* = 15;
      
      public static const D_NECRO:* = 16;
      
      public static const D_PSY:* = 17;
      
      public static const D_ASTRO:* = 18;
      
      public static const D_PINK:* = 19;
      
      public static const D_INSIDE:* = 100;
      
      public static const D_FRIEND:* = 101;
      
      public static var begvulners:Array = new Array();
      
      public static const kolVulners:* = 20;
      
      public static var opts:Array = new Array();
      
      public static const F_PLAYER:* = 100;
      
      public static const F_MONSTER:* = 1;
      
      public static const F_RAIDER:* = 2;
      
      public static const F_ZOMBIE:* = 3;
      
      public static const F_ROBOT:* = 4;
      
      public static var heroTransforms:* = [new ColorTransform(1,0.8,0.8,1,64,0,0,0),new ColorTransform(0.8,1,1,1,0,32,64,0),new ColorTransform(1,0.8,1,1,32,0,64,0),new ColorTransform(0.8,1,0.8,1,0,64,0,0)];
      
      internal static var ppp:Point = new Point();
      
      internal static const robotKZ:* = 75;
      
      internal static const damWallStun:* = 45;
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectFindTarget:Function = null;
      
      public static var rconnectDeferDamage:Function = null;
      
      public static var rconnectHitPolicy:Function = null;
      
      public static var rconnectTeleported:Function = null;
      
      private static var rconnectFinding:Boolean = false;
      
      public var id:String;
      
      internal var mapxml:XML;
      
      internal var uniqName:Boolean = false;
      
      public var sitY:Number = 40;
      
      public var stayY:Number = 40;
      
      public var sitX:Number = 40;
      
      public var stayX:Number = 40;
      
      public var begX:Number = -1;
      
      public var begY:Number = -1;
      
      public var rasst:Number = 0;
      
      public var level:int = 0;
      
      public var hero:int = 0;
      
      public var boss:Boolean = false;
      
      public var maxhp:Number = 100;
      
      public var hpmult:Number = 1;
      
      public var hp:Number = 100;
      
      public var cut:Number = 0;
      
      public var poison:Number = 0;
      
      public var critHeal:Number = 0.2;
      
      public var shithp:Number = 0;
      
      internal var t_hp:int;
      
      public var mana:Number = 1000;
      
      public var maxmana:Number = 1000;
      
      public var dmana:Number = 1;
      
      public var invulner:Boolean = false;
      
      public var allVulnerMult:Number = 1;
      
      public var skin:Number = 0;
      
      public var armor:Number = 0;
      
      public var marmor:Number = 0;
      
      public var armor_hp:Number = 0;
      
      public var armor_maxhp:Number = 0;
      
      public var armor_qual:Number = 0;
      
      public var shitArmor:Number = 20;
      
      public var vulner:Array;
      
      public var begvulner:Array;
      
      public var dexter:Number = 1;
      
      public var dexterPlus:Number = 0;
      
      public var dodge:Number = 0;
      
      public var undodge:Number = 0;
      
      public var transp:Boolean = false;
      
      public var damWall:Number = 0;
      
      public var damWallSpeed:Number = 12;
      
      public var dopTestOn:Boolean = false;
      
      public var friendlyExpl:Number = 0.25;
      
      public var dam:Number = 0;
      
      public var tipDamage:int = 2;
      
      public var radDamage:Number = 0;
      
      public var retDamage:Boolean = false;
      
      public var relat:Number = 0;
      
      public var destroy:Number = -1;
      
      public var collisionTip:int = 1;
      
      public var dieWeap:String;
      
      public var levitAttack:Number = 1;
      
      public var noAgro:Boolean = false;
      
      public var fixed:Boolean = false;
      
      public var bind:Obj;
      
      public var mater:Boolean = true;
      
      public var massaFix:Number = 1;
      
      public var massaMove:Number = 1;
      
      public var walk:int;
      
      public var maxSpeed:Number = 10;
      
      public var walkSpeed:Number = 5;
      
      public var runSpeed:Number = 10;
      
      public var sitSpeed:Number = 3;
      
      public var lazSpeed:Number = 5;
      
      public var plavSpeed:Number = 5;
      
      public var accel:Number = 5;
      
      public var brake:Number = 1;
      
      public var levitaccel:Number = 1.6;
      
      public var knocked:Number = 1;
      
      public var jumpdy:Number = 15;
      
      public var plavdy:Number = 1;
      
      public var levidy:Number = 1;
      
      public var elast:Number = 0;
      
      public var jumpBall:Number = 0;
      
      public var ddyPlav:Number = 1;
      
      public var osndx:Number = 0;
      
      public var osndy:Number = 0;
      
      public var levit_max:* = 0;
      
      public var levit_r:int = 0;
      
      public var grav:Number = 1;
      
      public var slow:int = 0;
      
      public var tormoz:Number = 1;
      
      public var t_throw:int = 0;
      
      public var stayPhis:int;
      
      public var stayOsn:Box = null;
      
      public var stayMat:int;
      
      public var tykMat:int;
      
      protected var shX1:Number;
      
      protected var shX2:Number;
      
      protected var diagon:int = 0;
      
      public var porog:Number = 10;
      
      public var porog_jump:Number = 4;
      
      public var isSit:Boolean = false;
      
      public var isFly:Boolean = false;
      
      public var isRun:Boolean = false;
      
      public var isPlav:Boolean = false;
      
      public var isLaz:int = 0;
      
      public var inWater:Boolean = false;
      
      public var isUp:Boolean = false;
      
      public var throu:Boolean = false;
      
      public var isJump:Boolean = false;
      
      public var turnX:int = 0;
      
      public var turnY:int = 0;
      
      public var kray:Boolean = false;
      
      public var pumpObj:Interact;
      
      private var namok_t:int = 0;
      
      internal var visDamDY:int = 0;
      
      public var currentWeapon:Weapon;
      
      public var weaponSkill:Number = 1;
      
      public var spellPower:Number = 1;
      
      public var mazil:int = 0;
      
      public var critCh:Number = 0;
      
      public var critInvis:Number = 0;
      
      public var critDamMult:Number = 2;
      
      public var precMult:Number = 1;
      
      public var precMultCont:Number = 1;
      
      public var rapidMultCont:Number = 1;
      
      public var weaponKrep:int = 1;
      
      public var weaponX:Number;
      
      public var weaponY:Number;
      
      public var weaponR:Number = 0;
      
      public var magicX:Number;
      
      public var magicY:Number;
      
      public var childObjs:Array;
      
      public var isShoot:Boolean = false;
      
      internal var aiNapr:int = 1;
      
      internal var aiVNapr:int = 0;
      
      internal var aiTTurn:int = 10;
      
      internal var aiPlav:int = 0;
      
      internal var aiState:int = 0;
      
      internal var aiTCh:int = Math.floor(Math.random() * 10);
      
      internal var aiSpok:int = 0;
      
      internal var maxSpok:int = 30;
      
      public var celX:Number = 0;
      
      public var celY:Number = 0;
      
      public var celDX:Number = 0;
      
      public var celDY:Number = 0;
      
      public var acelX:Number = 0;
      
      public var acelY:Number = 0;
      
      public var celUnit:Unit;
      
      public var priorUnit:Unit;
      
      public var eyeX:Number = -1000;
      
      public var eyeY:Number = -1000;
      
      public var sost:int = 1;
      
      public var shok:int = 0;
      
      public var maxShok:int = 30;
      
      public var stun:int = 0;
      
      public var neujaz:int = 0;
      
      public var neujazMax:int = 20;
      
      public var disabled:Boolean = false;
      
      public var noAct:Boolean = false;
      
      public var oduplenie:int = 100;
      
      public var lootIsDrop:* = false;
      
      public var aiTip:String;
      
      public var t_emerg:int = 0;
      
      public var max_emerg:int = 0;
      
      public var wave:int = 0;
      
      public var transT:Boolean = false;
      
      public var postDie:Boolean = false;
      
      public var blood:int = 0;
      
      public var mat:int = 0;
      
      public var acidDey:Number = 0;
      
      public var trup:Boolean = true;
      
      public var overLook:Boolean = true;
      
      public var plav:Boolean = true;
      
      public var showNumbs:Boolean = true;
      
      public var activateTrap:int = 2;
      
      public var isSats:Boolean = true;
      
      public var msex:Boolean = true;
      
      public var doop:Boolean = false;
      
      public var plaKap:Boolean = true;
      
      public var noBox:Boolean = false;
      
      public var areaTestTip:String;
      
      public var mHero:Boolean = false;
      
      public var isRes:Boolean = false;
      
      public var mech:Boolean = false;
      
      public var noDestr:Boolean = false;
      
      public var opt:Object;
      
      public var fraction:int = 0;
      
      public var player:Boolean = false;
      
      public var npc:Boolean = false;
      
      public var visibility:int = 1000;
      
      public var stealthMult:Number = 1;
      
      public var detecting:int = 80;
      
      public var demask:Number = 0;
      
      public var invis:Boolean = false;
      
      public var noise:int = 0;
      
      public var noiseRun:int = 200;
      
      public var noise_t:int = 30;
      
      public var isVis:Boolean = true;
      
      public var volMinus:Number = 0;
      
      public var light:Boolean = false;
      
      public var observ:Number = 0;
      
      public var vision:Number = 1;
      
      public var ear:Number = 1;
      
      public var unres:Boolean = false;
      
      public var vAngle:Number = 0;
      
      public var vKonus:Number = 0;
      
      public var effects:Array;
      
      public var id_name:String;
      
      public var t_replic:int = Math.random() * 100 - 50;
      
      public var id_replic:String = "";
      
      internal var blitId:String;
      
      public var animState:String = "";
      
      public var animState2:String = "";
      
      public var blitData:BitmapData;
      
      internal var blitX:int = 120;
      
      internal var blitY:int = 120;
      
      internal var blitDX:int = -1;
      
      internal var blitDY:int = -1;
      
      internal var blitRect:Rectangle;
      
      internal var blitPoint:Point;
      
      internal var visData:BitmapData;
      
      internal var visBmp:Bitmap;
      
      internal var anims:Array;
      
      internal var ctrans:Boolean = true;
      
      public var hpbar:MovieClip;
      
      internal var timerDie:int = 0;
      
      internal var burn:Desintegr;
      
      internal var bloodEmit:Emitter;
      
      internal var numbEmit:Emitter;
      
      internal var hitPart:Part;
      
      internal var t_hitPart:int = 0;
      
      internal var hitSumm:Number = 0;
      
      internal var t_mess:int = 0;
      
      public var sndMusic:String;
      
      internal var sndMusicPrior:int = 0;
      
      public var sndDie:String;
      
      public var sndRun:String;
      
      public var sndRunDist:Number = 800;
      
      public var sndRunOn:Boolean = false;
      
      internal var sndVolkoef:Number = 1;
      
      internal var mother:Unit;
      
      internal var kolChild:int = 0;
      
      public var scrDie:Script;
      
      public var scrAlarm:Script;
      
      public var questId:String;
      
      public var trig:String;
      
      public var trigDis:Boolean = false;
      
      public var xp:int = 0;
      
      public function Unit(param1:String = null, param2:Number = 100, param3:XML = null, param4:Object = null)
      {
         super();
         this.vulner = new Array();
         inter = new Interact(this,null,param3,param4);
         inter.active = false;
         var _loc5_:* = 0;
         while(_loc5_ < kolVulners)
         {
            this.vulner[_loc5_] = 1;
            _loc5_++;
         }
         this.vulner[D_EMP] = 0;
         this.effects = new Array();
         sloy = 2;
         prior = 1;
         warn = 1;
         this.numbEmit = Emitter.arr["numb"];
         if(param3)
         {
            if(param3.@turn.length())
            {
               if(param3.@turn > 0)
               {
                  storona = 1;
               }
               if(param3.@turn < 0)
               {
                  storona = -1;
               }
            }
            else
            {
               storona = this.isrnd() ? 1 : -1;
               this.aiNapr = storona;
            }
            if(param3.@name.length())
            {
               this.uniqName = true;
               nazv = Res.txt("u",param3.@name);
            }
            if(param3.@ai.length())
            {
               this.aiTip = param3.@ai;
            }
            if(param3.@hpmult.length())
            {
               this.hpmult = param3.@hpmult;
            }
            if(param3.@multhp.length())
            {
               this.hpmult = param3.@multhp;
            }
            if(param3.@unres.length())
            {
               this.unres = true;
            }
            if(param3.@qid.length())
            {
               this.questId = param3.@qid;
            }
            if(param3.@trig.length())
            {
               this.trig = param3.@trig;
            }
            if(param3.@hero.length())
            {
               this.hero = param3.@hero;
            }
            if(param3.@observ.length())
            {
               this.observ = param3.@observ;
            }
            if(param3.@light.length())
            {
               this.light = true;
            }
            if(param3.@noagro.length())
            {
               this.noAgro = true;
            }
            if(param3.@dis.length())
            {
               this.noAct = true;
               this.disabled = true;
            }
            if(param3.@die.length())
            {
               this.postDie = true;
            }
         }
         if(Boolean(param4) && Boolean(param4.dead) && !this.postDie)
         {
            this.sost = 4;
            this.disabled = true;
            trace(this,nazv);
         }
         this.mapxml = param3;
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
      
      public static function create(param1:String, param2:int, param3:XML = null, param4:Object = null, param5:String = null) : Unit
      {
         var node:XML = null;
         var uc:Class = null;
         var cn:String = null;
         var cid:String = null;
         var un:Unit = null;
         var id:String = param1;
         var dif:int = param2;
         var xml:XML = param3;
         var loadObj:Object = param4;
         var ncid:String = param5;
         if(id == "mwall")
         {
            return new UnitMWall(null,0,null,null);
         }
         if(id == "scythe")
         {
            return new UnitScythe(null,0,null,null);
         }
         if(id == "ttur")
         {
            return new UnitThunderTurret(ncid,0,null,null);
         }
         node = rconnectXmlFind(AllData.d.obj,"id",id)[0];
         if(node == null)
         {
            trace("Не найден юнит",id);
            return null;
         }
         cn = node.@cl;
         switch(cn)
         {
            case "Mine":
               uc = Mine;
               break;
            case "UnitTrap":
               uc = UnitTrap;
               break;
            case "UnitTrigger":
               uc = UnitTrigger;
               break;
            case "UnitDamager":
               uc = UnitDamager;
               break;
            case "UnitRaider":
               uc = UnitRaider;
               break;
            case "UnitSlaver":
               uc = UnitSlaver;
               break;
            case "UnitZebra":
               uc = UnitZebra;
               break;
            case "UnitRanger":
               uc = UnitRanger;
               break;
            case "UnitEncl":
               uc = UnitEncl;
               break;
            case "UnitMerc":
               uc = UnitMerc;
               break;
            case "UnitZombie":
               uc = UnitZombie;
               break;
            case "UnitAlicorn":
               uc = UnitAlicorn;
               break;
            case "UnitHellhound":
               uc = UnitHellhound;
               break;
            case "UnitRobobrain":
               uc = UnitRobobrain;
               break;
            case "UnitProtect":
               uc = UnitProtect;
               break;
            case "UnitGutsy":
               uc = UnitGutsy;
               break;
            case "UnitEqd":
               uc = UnitEqd;
               break;
            case "UnitSentinel":
               uc = UnitSentinel;
               break;
            case "UnitTurret":
               uc = UnitTurret;
               break;
            case "UnitBat":
               uc = UnitBat;
               break;
            case "UnitFish":
               uc = UnitFish;
               break;
            case "UnitBloat":
               uc = UnitBloat;
               break;
            case "UnitBloatEmitter":
               uc = UnitBloatEmitter;
               break;
            case "UnitSpriteBot":
               uc = UnitSpriteBot;
               break;
            case "UnitDron":
               uc = UnitDron;
               break;
            case "UnitVortex":
               uc = UnitVortex;
               break;
            case "UnitMonstrik":
               uc = UnitMonstrik;
               break;
            case "UnitAnt":
               uc = UnitAnt;
               break;
            case "UnitSlime":
               uc = UnitSlime;
               break;
            case "UnitRoller":
               uc = UnitRoller;
               break;
            case "UnitNPC":
               uc = UnitNPC;
               break;
            case "UnitCaptive":
               uc = UnitCaptive;
               break;
            case "UnitPonPon":
               uc = UnitPonPon;
               break;
            case "UnitTrain":
               uc = UnitTrain;
               break;
            case "UnitMsp":
               uc = UnitMsp;
               break;
            case "UnitTransmitter":
               uc = UnitTransmitter;
               break;
            case "UnitNecros":
               uc = UnitNecros;
               break;
            case "UnitSpectre":
               uc = UnitSpectre;
               break;
            case "UnitBossRaider":
               uc = UnitBossRaider;
               break;
            case "UnitBossAlicorn":
               uc = UnitBossAlicorn;
               break;
            case "UnitBossUltra":
               uc = UnitBossUltra;
               break;
            case "UnitBossNecr":
               uc = UnitBossNecr;
               break;
            case "UnitBossDron":
               uc = UnitBossDron;
               break;
            case "UnitBossEncl":
               uc = UnitBossEncl;
               break;
            case "UnitThunderHead":
               uc = UnitThunderHead;
               break;
            case "UnitDestr":
               uc = UnitDestr;
         }
         if(uc == null)
         {
            return null;
         }
         cid = null;
         if(node.@cid.length())
         {
            cid = node.@cid;
         }
         if(ncid != null)
         {
            cid = ncid;
         }
         un = new uc(cid,dif,xml,loadObj);
         if(Boolean(xml) && Boolean(xml.@code.length()))
         {
            un.code = xml.@code;
         }
         return un;
      }
      
      public static function initIcos() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:BitmapData = null;
         var _loc3_:Boolean = false;
         var _loc4_:MovieClip = null;
         var _loc5_:int = 0;
         var _loc6_:int = 0;
         var _loc7_:Matrix = null;
         var _loc8_:Bitmap = null;
         arrIcos = new Array();
         for each(_loc1_ in AllData.d.unit)
         {
            if(_loc1_.@cat == "3")
            {
               _loc3_ = false;
               if(!(Boolean(_loc1_.vis.length()) && Boolean(_loc1_.vis.@blit.length())))
               {
                  if(Boolean(_loc1_.vis.length()) && Boolean(_loc1_.vis.@vclass.length()))
                  {
                     _loc4_ = Res.getVis(_loc1_.vis.@vclass);
                     _loc5_ = _loc4_.width + 2;
                     _loc6_ = _loc4_.height + 2;
                     _loc2_ = new BitmapData(_loc5_,_loc6_,true,0);
                     _loc7_ = new Matrix();
                     _loc7_.tx = -_loc4_.getRect(_loc4_).left;
                     _loc7_.ty = -_loc4_.getRect(_loc4_).top;
                     _loc2_.draw(_loc4_,_loc7_);
                     _loc3_ = true;
                  }
               }
               if(_loc3_)
               {
                  _loc8_ = new Bitmap(_loc2_);
                  arrIcos[_loc1_.@id] = _loc8_;
               }
            }
         }
      }
      
      public static function initIco(param1:String) : *
      {
         var bmpd:BitmapData = null;
         var data:BitmapData = null;
         var sprX:int = 0;
         var sprY:int = 0;
         var begSprX:int = 0;
         var begSprY:int = 0;
         var rect:Rectangle = null;
         var bmp:Bitmap = null;
         var nid:String = param1;
         if(arrIcos == null)
         {
            arrIcos = new Array();
         }
         if(arrIcos[nid])
         {
            return;
         }
         var xml:* = rconnectXmlFind(AllData.d.unit,"id",nid);
         if(Boolean(xml.vis.length()) && Boolean(xml.vis.@blit.length()))
         {
            data = World.w.grafon.getSpriteList(xml.vis.@blit);
            if(data == null)
            {
               return;
            }
            sprX = int(xml.vis.@sprX);
            sprY = xml.vis.@sprY > 0 ? int(xml.vis.@sprY) : sprX;
            begSprX = xml.vis.@icoX > 0 ? int(xml.vis.@icoX) : 0;
            begSprY = xml.vis.@icoY > 0 ? int(xml.vis.@icoY) : 0;
            rect = new Rectangle(begSprX * sprX,begSprY * sprY,(begSprX + 1) * sprX,(begSprY + 1) * sprY);
            bmpd = new BitmapData(sprX,sprY);
            bmpd.copyPixels(data,rect,new Point(0,0));
            bmp = new Bitmap(bmpd);
            arrIcos[nid] = bmp;
         }
      }
      
      public static function rconnectAllowed(source:Unit, target:Unit, nativeAllowed:Boolean, kind:String = "impact") : Boolean
      {
         return rconnectHitPolicy == null ? nativeAllowed : Boolean(rconnectHitPolicy(source,target,nativeAllowed,kind));
      }
      
      override public function save() : Object
      {
         var _loc1_:Object = new Object();
         if(this.sost >= 3 && !this.postDie)
         {
            _loc1_.dead = true;
         }
         if(inter)
         {
            inter.save(_loc1_);
         }
         return _loc1_;
      }
      
      public function getXmlParam(param1:String = null) : *
      {
         var setOpts:Boolean = false;
         var node:XML = null;
         var xbl:XML = null;
         var i:* = undefined;
         var mid:String = param1;
         setOpts = false;
         if(opts[this.id])
         {
            this.opt = opts[this.id];
            this.begvulner = begvulners[this.id];
         }
         else
         {
            this.opt = new Object();
            opts[this.id] = this.opt;
            this.begvulner = new Array();
            begvulners[this.id] = this.begvulner;
            setOpts = true;
         }
         var isHero:Boolean = false;
         if(mid == null)
         {
            if(this.hero > 0)
            {
               isHero = true;
            }
            mid = this.id;
         }
         var node0:XML = rconnectXmlFind(AllData.d.unit,"id",mid)[0];
         if(Boolean(mid) && !this.uniqName)
         {
            nazv = Res.txt("u",mid);
         }
         if(node0.@fraction.length())
         {
            this.fraction = node0.@fraction;
         }
         inter.cont = mid;
         if(Boolean(node0.@cont.length()) && Boolean(inter))
         {
            inter.cont = node0.@cont;
         }
         if(this.fraction == F_PLAYER)
         {
            warn = 0;
         }
         if(node0.@xp.length())
         {
            this.xp = node0.@xp * World.unitXPMult;
         }
         if(node0.phis.length())
         {
            node = node0.phis[0];
            if(node.@sX.length())
            {
               this.stayX = scX = node.@sX;
            }
            if(node.@sY.length())
            {
               this.stayY = scY = node.@sY;
            }
            if(node.@sitX.length())
            {
               this.sitX = node.@sitX;
            }
            else
            {
               this.sitX = this.stayX;
            }
            if(node.@sitY.length())
            {
               this.sitY = node.@sitY;
            }
            else
            {
               this.sitY = this.stayY / 2;
            }
            if(node.@massa.length())
            {
               this.massaMove = node.@massa / 50;
            }
            if(node.@massafix.length())
            {
               this.massaFix = node.@massafix / 50;
            }
            else
            {
               this.massaFix = this.massaMove;
            }
         }
         massa = this.massaFix;
         if(massa >= 1)
         {
            this.destroy = 0;
         }
         if(node0.move.length())
         {
            node = node0.move[0];
            if(node.@speed.length())
            {
               this.maxSpeed = node.@speed;
            }
            if(node.@run.length())
            {
               this.runSpeed = node.@run;
            }
            if(node.@accel.length())
            {
               this.accel = node.@accel;
            }
            if(node.@jump.length())
            {
               this.jumpdy = node.@jump;
            }
            if(node.@knocked.length())
            {
               this.knocked = node.@knocked;
            }
            if(node.@plav.length())
            {
               this.plav = node.@plav > 0;
            }
            if(node.@brake.length())
            {
               this.brake = node.@brake;
            }
            if(node.@levit.length())
            {
               levitPoss = node.@levit > 0;
            }
            if(node.@levit_max.length())
            {
               this.levit_max = node.@levit_max;
            }
            if(node.@levitaccel.length())
            {
               this.levitaccel = node.@levitaccel;
            }
            if(node.@float.length())
            {
               this.ddyPlav = node.@float;
            }
            if(node.@porog.length())
            {
               this.porog = node.@porog;
            }
            if(node.@fixed.length())
            {
               this.fixed = node.@fixed > 0;
            }
            if(node.@damwall.length())
            {
               this.damWall = node.@damwall;
            }
         }
         if(node0.comb.length())
         {
            node = node0.comb[0];
            if(node.@hp.length())
            {
               this.hp = this.maxhp = node.@hp * this.hpmult;
            }
            if(this.fraction != F_PLAYER && World.w.game.globalDif <= 1)
            {
               if(World.w.game.globalDif == 0)
               {
                  this.maxhp *= 0.4;
               }
               if(World.w.game.globalDif == 1)
               {
                  this.maxhp *= 0.7;
               }
               this.hp = this.maxhp;
            }
            if(node.@skin.length())
            {
               this.skin = node.@skin;
            }
            if(node.@armor.length())
            {
               this.armor = node.@armor;
            }
            if(node.@marmor.length())
            {
               this.marmor = node.@marmor;
            }
            if(node.@aqual.length())
            {
               this.armor_qual = node.@aqual;
            }
            if(node.@armorhp.length())
            {
               this.armor_hp = this.armor_maxhp = node.@armorhp * this.hpmult;
            }
            else
            {
               this.armor_hp = this.armor_maxhp = this.hp;
            }
            if(node.@krep.length())
            {
               this.weaponKrep = node.@krep;
            }
            if(node.@dexter.length())
            {
               this.dexter = node.@dexter;
            }
            if(node.@damage.length())
            {
               this.dam = node.@damage;
            }
            if(node.@tipdam.length())
            {
               this.tipDamage = node.@tipdam;
            }
            if(node.@skill.length())
            {
               this.weaponSkill = node.@skill;
            }
            if(node.@raddamage.length())
            {
               this.radDamage = node.@raddamage;
            }
            if(node.@vision.length())
            {
               this.vision = node.@vision;
            }
            if(node.@observ.length())
            {
               this.observ += node.@observ;
            }
            if(node.@ear.length())
            {
               this.ear = node.@ear;
            }
            if(node.@levitatk.length())
            {
               this.levitAttack = node.@levitatk;
            }
         }
         if(node0.vulner.length())
         {
            node = node0.vulner[0];
            if(node.@bul.length())
            {
               this.vulner[D_BUL] = node.@bul;
            }
            if(node.@blade.length())
            {
               this.vulner[D_BLADE] = node.@blade;
            }
            if(node.@phis.length())
            {
               this.vulner[D_PHIS] = node.@phis;
            }
            if(node.@fire.length())
            {
               this.vulner[D_FIRE] = node.@fire;
            }
            if(node.@expl.length())
            {
               this.vulner[D_EXPL] = node.@expl;
            }
            if(node.@laser.length())
            {
               this.vulner[D_LASER] = node.@laser;
            }
            if(node.@plasma.length())
            {
               this.vulner[D_PLASMA] = node.@plasma;
            }
            if(node.@venom.length())
            {
               this.vulner[D_VENOM] = node.@venom;
            }
            if(node.@emp.length())
            {
               this.vulner[D_EMP] = node.@emp;
            }
            if(node.@spark.length())
            {
               this.vulner[D_SPARK] = node.@spark;
            }
            if(node.@acid.length())
            {
               this.vulner[D_ACID] = node.@acid;
            }
            if(node.@cryo.length())
            {
               this.vulner[D_CRIO] = node.@cryo;
            }
            if(node.@poison.length())
            {
               this.vulner[D_POISON] = node.@poison;
            }
            if(node.@bleed.length())
            {
               this.vulner[D_BLEED] = node.@bleed;
            }
            if(node.@fang.length())
            {
               this.vulner[D_FANG] = node.@fang;
            }
            if(node.@pink.length())
            {
               this.vulner[D_PINK] = node.@pink;
            }
         }
         if(node0.vis.length())
         {
            node = node0.vis[0];
            if(node.@sex == "w")
            {
               this.msex = false;
            }
            if(node.@blit.length())
            {
               this.blitId = node.@blit;
               if(node.@sprX > 0)
               {
                  this.blitX = node.@sprX;
               }
               if(node.@sprY > 0)
               {
                  this.blitY = node.@sprY;
               }
               else
               {
                  this.blitY = node.@sprX;
               }
               if(node.@sprDX.length())
               {
                  this.blitDX = node.@sprDX;
               }
               if(node.@sprDY.length())
               {
                  this.blitDY = node.@sprDY;
               }
            }
            if(node.@replic.length())
            {
               this.id_replic = node.@replic;
            }
            if(node.@noise.length())
            {
               this.noiseRun = node.@noise;
            }
         }
         if(node0.snd.length())
         {
            node = node0.snd[0];
            if(node.@music.length())
            {
               this.sndMusic = node.@music;
               this.sndMusicPrior = 1;
            }
            if(node.@musicp.length())
            {
               this.sndMusicPrior = node.@musicp;
            }
            if(node.@die.length())
            {
               this.sndDie = node.@die;
            }
            if(node.@run.length())
            {
               this.sndRun = node.@run;
            }
         }
         if(node0.param.length())
         {
            node = node0.param[0];
            if(node.@invulner.length())
            {
               this.invulner = node.@invulner > 0;
            }
            if(node.@overlook.length())
            {
               this.overLook = node.@overlook > 0;
            }
            if(node.@sats.length())
            {
               this.isSats = node.@sats > 0;
            }
            if(node.@acttrap.length())
            {
               this.activateTrap = node.@acttrap;
            }
            if(node.@npc.length())
            {
               this.npc = node.@npc > 0;
            }
            if(node.@trup.length())
            {
               this.trup = node.@trup > 0;
            }
            if(node.@blood.length())
            {
               this.blood = node.@blood;
            }
            if(node.@retdam.length())
            {
               this.retDamage = node.@retdam > 0;
            }
            if(node.@hero.length())
            {
               this.mHero = true;
               this.id_name = node.@hero;
            }
            if(setOpts)
            {
               if(node.@pony.length())
               {
                  this.opt.pony = true;
               }
               if(node.@zombie.length())
               {
                  this.opt.zombie = true;
               }
               if(node.@robot.length())
               {
                  this.opt.robot = true;
               }
               if(node.@insect.length())
               {
                  this.opt.insect = true;
               }
               if(node.@monster.length())
               {
                  this.opt.monster = true;
               }
               if(node.@alicorn.length())
               {
                  this.opt.alicorn = true;
               }
               if(node.@mech.length())
               {
                  this.opt.mech = true;
                  this.mech = true;
               }
               if(node.@hbonus.length())
               {
                  this.opt.hbonus = true;
               }
               if(node.@izvrat.length())
               {
                  this.opt.izvrat = true;
               }
            }
         }
         if(this.blood == 0)
         {
            this.vulner[D_BLEED] = 0;
         }
         if(this.opt)
         {
            if(Boolean(this.opt.robot) || Boolean(this.opt.mech))
            {
               this.vulner[D_NECRO] = this.vulner[D_BLEED] = this.vulner[D_VENOM] = this.vulner[D_POISON] = 0;
            }
         }
         if(node0.blit.length())
         {
            if(this.anims == null)
            {
               this.anims = new Array();
            }
            for each(xbl in node0.blit)
            {
               this.anims[xbl.@id] = new BlitAnim(xbl);
            }
         }
         if(setOpts)
         {
            i = 0;
            while(i < kolVulners)
            {
               this.begvulner[i] = this.vulner[i];
               i++;
            }
         }
      }
      
      public function getXmlWeapon(param1:int) : Weapon
      {
         var node0:XML = null;
         var weap:Weapon = null;
         var n:XML = null;
         var dif:int = param1;
         node0 = rconnectXmlFind(AllData.d.unit,"id",id)[0];
         for each(n in node0.w)
         {
            if(!n.@f.length())
            {
               if(!(Boolean(n.@dif.length()) && n.@dif > dif))
               {
                  if(n.@ch.length() == 0 || this.isrnd(n.@ch))
                  {
                     weap = Weapon.create(this,n.@id);
                     if(weap)
                     {
                        return weap;
                     }
                  }
               }
            }
         }
         return null;
      }
      
      public function getName() : String
      {
         if(World.w.game == null || this.id_name == null)
         {
            return "";
         }
         var _loc1_:Array = World.w.game.names[this.id_name];
         if(_loc1_ == null || _loc1_.length == 0)
         {
            _loc1_ = Res.namesArr(this.id_name);
         }
         if(_loc1_ == null || _loc1_.length == 0)
         {
            return "";
         }
         World.w.game.names[this.id_name] = _loc1_;
         var _loc2_:* = Math.floor(Math.random() * _loc1_.length);
         var _loc3_:* = _loc1_[_loc2_];
         _loc1_.splice(_loc2_,1);
         return _loc3_;
      }
      
      public function checkTrig() : Boolean
      {
         if(this.trig)
         {
            if(this.trig == "eco" && (World.w.pers == null || World.w.pers.eco == 0))
            {
               return false;
            }
            if(World.w.game.triggers[this.trig] != 1)
            {
               return false;
            }
         }
         return true;
      }
      
      public function putLoc(param1:Location, param2:Number, param3:Number) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:Script = null;
         if(loc != null)
         {
            return;
         }
         loc = param1;
         if(loc.mirror)
         {
            storona = -storona;
            this.aiNapr = storona;
         }
         this.setPos(param2,param3);
         if(this.collisionAll())
         {
            if(!this.collisionAll(-Tile.tileX))
            {
               this.setPos(param2 - Tile.tileX,param3);
            }
         }
         if(inter)
         {
            inter.loc = param1;
         }
         if(Boolean(inter) && inter.saveLoot == 2)
         {
            inter.loot(true);
         }
         if(this.sost >= 3)
         {
            return;
         }
         this.begX = X;
         this.begY = Y;
         if(this.hero == 0)
         {
            cTransform = loc.cTransform;
         }
         else
         {
            cTransform = heroTransforms[this.hero - 1];
         }
         if(loc.biom == 5)
         {
            this.vulner[D_PINK] = 0;
         }
         if(this.mapxml)
         {
            if(this.mapxml.scr.length())
            {
               for each(_loc4_ in this.mapxml.scr)
               {
                  _loc5_ = new Script(_loc4_,loc.land,this);
                  if(_loc5_.eve == "die" || _loc5_.eve == null)
                  {
                     this.scrDie = _loc5_;
                  }
                  if(_loc5_.eve == "alarm")
                  {
                     this.scrAlarm = _loc5_;
                  }
               }
            }
            if(this.mapxml.@scr.length())
            {
               this.scrDie = World.w.game.getScript(this.mapxml.@scr,this);
            }
            if(this.mapxml.@alarm.length())
            {
               this.scrAlarm = World.w.game.getScript(this.mapxml.@alarm,this);
            }
         }
         if(this.postDie)
         {
            this.sost = 3;
            this.setCel(null,X + storona * 100,Y + 50);
            this.lootIsDrop = true;
            this.die();
         }
      }
      
      public function setLevel(param1:int = 0) : *
      {
         this.level += param1;
         if(this.level < 0)
         {
            this.level = 0;
         }
         this.hp = this.maxhp = this.hp * (1 + this.level * 0.11);
         this.dam *= 1 + this.level * 0.07;
         this.radDamage *= 1 + this.level * 0.1;
         this.critCh = this.level * 0.01;
         this.armor *= 1 + this.level * 0.05;
         this.marmor *= 1 + this.level * 0.05;
         this.skin *= 1 + this.level * 0.05;
         this.armor_hp = this.armor_maxhp = this.armor_hp * (1 + this.level * 0.1);
         this.observ += Math.min(param1 * 0.6,15) * (0.9 + Math.random() * 0.2);
         if(Boolean(this.currentWeapon) && this.currentWeapon.tip == 0)
         {
            this.currentWeapon.damage *= 1 + this.level * 0.07;
         }
         else
         {
            this.weaponSkill *= 1 + this.level * 0.035;
         }
         this.damWall *= 1 + this.level * 0.04;
      }
      
      public function setHero(param1:int = 1) : *
      {
         var _loc2_:* = undefined;
         if(!this.mHero)
         {
            return;
         }
         if(this.hero == 0)
         {
            this.hero = param1;
         }
         if(this.hero > 0)
         {
            if(!this.uniqName)
            {
               _loc2_ = this.getName();
               if(_loc2_ != null && _loc2_ != "")
               {
                  nazv = _loc2_;
               }
            }
            this.xp *= 5;
         }
         if(this.hero == 1)
         {
            this.hp = this.maxhp = this.maxhp * 2.5;
            this.dam *= 1.8;
            if(this.currentWeapon)
            {
               this.currentWeapon.damage *= 1.5;
            }
         }
         else if(this.hero == 2 || this.hero == 3)
         {
            this.hp = this.maxhp = this.maxhp * 3;
            this.dam *= 1.2;
         }
         else if(this.hero == 4)
         {
            this.hp = this.maxhp = this.maxhp * 2;
            this.dam *= 1.4;
            this.observ += 8;
            this.walkSpeed *= 1.4;
            this.sitSpeed *= 1.4;
            this.runSpeed *= 1.25;
         }
         this.setHeroVulners();
      }
      
      public function setHeroVulners() : *
      {
         this.vulner[D_EMP] *= 0.8;
         this.vulner[D_BALE] *= 0.7;
         this.vulner[D_NECRO] *= 0.7;
         this.vulner[D_ASTRO] *= 0.7;
         if(this.hero == 2)
         {
            this.vulner[D_BUL] *= 0.5;
            this.vulner[D_PHIS] *= 0.65;
            this.vulner[D_BLADE] *= 0.65;
            this.vulner[D_EXPL] *= 0.75;
         }
         if(this.hero == 3)
         {
            this.vulner[D_LASER] *= 0.6;
            this.vulner[D_PLASMA] *= 0.5;
            this.vulner[D_EMP] *= 0.75;
            this.vulner[D_SPARK] *= 0.7;
            this.vulner[D_FIRE] *= 0.7;
         }
      }
      
      override public function setNull(param1:Boolean = false) : *
      {
         var _loc2_:* = undefined;
         if(this.boss && this.isNoResBoss())
         {
            param1 = false;
         }
         if(this.sost == 1)
         {
            if(param1)
            {
               if(this.effects.length > 0)
               {
                  for each(_loc2_ in this.effects)
                  {
                     _loc2_.unsetEff();
                  }
                  this.effects = new Array();
               }
               this.stun = this.cut = this.poison = 0;
               this.oduplenie = Math.round(World.oduplenie * (Math.random() * 0.2 + 0.9));
               if(!this.noAct)
               {
                  this.disabled = false;
               }
               this.hp = this.maxhp;
               this.armor_hp = this.armor_maxhp;
               if(this.hpbar)
               {
                  this.visDetails();
               }
               if(this.begX > 0 && this.begY > 0)
               {
                  this.setPos(this.begX,this.begY);
               }
               dx = dy = 0;
               this.setWeaponPos();
            }
            if(this.currentWeapon)
            {
               this.currentWeapon.setNull();
            }
         }
         levit = 0;
      }
      
      public function isNoResBoss() : Boolean
      {
         var _loc1_:* = false;
         try
         {
            _loc1_ = World.w.game.globalDif <= 3 && loc && loc.land.act.tip != "base";
         }
         catch(err:*)
         {
         }
         return _loc1_;
      }
      
      override public function err() : String
      {
         return "Error unit " + nazv;
      }
      
      override public function step() : *
      {
         var tf:* = undefined;
         var div:* = undefined;
         var i:* = undefined;
         if(this.disabled || this.trigDis)
         {
            return;
         }
         if(this.t_emerg > 0)
         {
            --this.t_emerg;
            this.setVisPos();
            if(vis)
            {
               if(this.t_emerg > 0)
               {
                  tf = this.t_emerg / (this.max_emerg + 1);
                  vis.filters = [new GlowFilter(11197951,tf,tf * 20,tf * 20,1,3)];
                  vis.alpha = 1 - tf;
               }
               else
               {
                  vis.filters = [];
                  vis.alpha = 1;
               }
            }
            return;
         }
         if(this.sost == 2)
         {
            --this.timerDie;
            if(this.timerDie <= 0)
            {
               this.die();
            }
         }
         if(inter)
         {
            inter.step();
         }
         getRasst2();
         if(radioactiv)
         {
            ggModum();
         }
         this.forces();
         this.control();
         if(!this.fixed)
         {
            if(Boolean(this.bind) || Math.abs(dx + this.osndx) < World.maxdelta && Math.abs(dy + this.osndy) < World.maxdelta)
            {
               this.run();
            }
            else
            {
               div = Math.floor(Math.max(Math.abs(dx + this.osndx),Math.abs(dy + this.osndy)) / World.maxdelta) + 1;
               i = 0;
               while(i < div)
               {
                  this.run(div);
                  i++;
               }
            }
         }
         this.checkWater();
         this.actions();
         this.setVisPos();
         if(this.hpbar)
         {
            this.setHpbarPos();
         }
         if(this.burn == null)
         {
            this.animate();
         }
         else
         {
            this.burn.step();
            if(this.burn.vse)
            {
               this.exterminate();
            }
         }
         onCursor = this.isVis && !this.disabled && this.sost < 4 && X1 < World.w.celX && X2 > World.w.celX && Y1 < World.w.celY && Y2 > World.w.celY ? prior : 0;
         for(i in this.childObjs)
         {
            if(this.childObjs[i])
            {
               try
               {
                  this.childObjs[i].step();
               }
               catch(err:*)
               {
                  childObjs[i].err();
               }
            }
         }
         this.visDamDY = 0;
         if(this.sndRunOn && this.sndRun && Boolean(loc) && loc.active)
         {
            this.sndRunPlay();
         }
      }
      
      public function control() : *
      {
      }
      
      public function setPos(param1:Number, param2:Number) : *
      {
         X = param1;
         Y = param2;
         Y1 = Y - scY;
         Y2 = Y;
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         this.setCel();
      }
      
      public function outLoc(param1:int, param2:Number = -1, param3:Number = -1) : Boolean
      {
         if(this.isFly || Boolean(levit))
         {
            return false;
         }
         if(param1 == 3)
         {
            if(loc.bezdna || this.jumpdy <= 0 || this.sost == 3)
            {
               this.disabled = true;
               dy = 0;
               if(this.sost == 3)
               {
                  this.sost = 4;
                  loc.remObj(this);
               }
               this.remVisual();
            }
            else
            {
               dy = -this.jumpdy;
               dx = storona * this.maxSpeed;
            }
         }
         return false;
      }
      
      public function emergence(param1:int = 30) : *
      {
         this.t_emerg = this.max_emerg = param1;
      }
      
      public function forces() : *
      {
         var _loc1_:Tile = null;
         var _loc2_:Number = Number(NaN);
         if(levit)
         {
            dy *= 0.8;
            dx *= 0.8;
            this.isLaz = 0;
         }
         if(this.isPlav)
         {
            if(!levit)
            {
               dy += World.ddy * this.ddyPlav;
            }
            dy *= 0.8;
            dx *= 0.8;
         }
         else if(this.isFly)
         {
            if(this.t_throw <= 0)
            {
               if(dx * dx + dy * dy > this.maxSpeed * this.maxSpeed)
               {
                  dx *= 0.7;
                  dy *= 0.7;
               }
               if(dx > -this.brake && dx < this.brake)
               {
                  dx = 0;
               }
               if(dy > -this.brake && dy < this.brake)
               {
                  dy = 0;
               }
            }
         }
         else
         {
            if(this.inWater)
            {
               dx *= 0.5;
            }
            if(!levit && this.isLaz == 0)
            {
               _loc1_ = loc.getAbsTile(X,Y - scY / 4);
               if(_loc1_.grav > 0 && dy < World.maxdy * _loc1_.grav || _loc1_.grav < 0 && dy > World.maxdy * _loc1_.grav)
               {
                  dy += World.ddy * _loc1_.grav * this.grav;
               }
            }
            if(stay)
            {
               dx *= this.tormoz;
               if(this.walk < 0)
               {
                  if(dx < -this.maxSpeed)
                  {
                     dx += this.brake;
                  }
               }
               else if(this.walk > 0)
               {
                  if(dx > this.maxSpeed)
                  {
                     dx -= this.brake;
                  }
               }
               else if(dx > -this.brake && dx < this.brake)
               {
                  dx = 0;
               }
               else if(dx > 0)
               {
                  dx -= this.brake;
               }
               else if(dx < 0)
               {
                  dx += this.brake;
               }
               if(Boolean(loc.quake) && massa <= 2 && this.sost == 1)
               {
                  _loc2_ = (1 + (2 - massa) / 2) * loc.quake;
                  if(_loc2_ > 10)
                  {
                     _loc2_ = 10;
                  }
                  dy = -_loc2_ * Math.random();
                  dx += _loc2_ * (Math.random() * 2 - 1);
               }
            }
         }
         if(this.slow > 0)
         {
            dx *= 0.75;
            dy *= 0.75;
         }
         this.osndx = this.osndy = 0;
         if(this.stayOsn)
         {
            if(this.stayOsn.cdx > 10 || this.stayOsn.cdx < -10 || this.stayOsn.cdy > 10 || this.stayOsn.cdy < -10)
            {
               stay = false;
            }
            else
            {
               this.osndx = this.stayOsn.cdx;
               this.osndy = this.stayOsn.cdy;
            }
         }
         this.stayOsn = null;
      }
      
      public function run(param1:int = 1) : *
      {
         var _loc2_:Tile = null;
         var _loc3_:Tile = null;
         var _loc4_:int = 0;
         if(loc.sky)
         {
            this.run2(param1);
            return;
         }
         var _loc5_:Number = 0;
         var _loc6_:Boolean = false;
         if(!this.throu && stay && this.diagon != 0 && dy >= 0)
         {
            if(!this.collisionAll(dx / param1,-dx / param1 * this.diagon))
            {
               X += dx / param1;
               Y -= dx / param1 * this.diagon;
               Y1 = Y - scY;
               Y2 = Y;
               X1 = X - scX / 2;
               X2 = X + scX / 2;
               dy = 0;
               this.checkDiagon(0);
            }
            else if(-dx / param1 * this.diagon > 0 && !this.collisionAll(dx / param1,0))
            {
               this.diagon = 0;
            }
            return;
         }
         this.diagon = 0;
         if(!this.isLaz)
         {
            X += (dx + this.osndx) / param1;
            if(X - scX / 2 < 0)
            {
               if(!this.outLoc(1))
               {
                  X = scX / 2;
                  dx = Math.abs(dx) * this.elast;
                  this.turnX = 1;
                  this.kray = true;
               }
            }
            if(X + scX / 2 >= loc.limX)
            {
               if(!this.outLoc(2))
               {
                  X = loc.limX - 1 - scX / 2;
                  dx = -Math.abs(dx) * this.elast;
                  this.turnX = -1;
                  this.kray = true;
               }
            }
            X1 = X - scX / 2;
            X2 = X + scX / 2;
            if(dx + this.osndx < 0)
            {
               if(!this.player && stay && this.shX1 > 0.5)
               {
                  _loc5_ = this.checkDiagon(-5);
                  if(_loc5_ > 0)
                  {
                     Y = _loc5_;
                     Y1 = Y - scY;
                     Y2 = Y;
                  }
               }
               if(this.player && !this.isSit && !this.isFly && !this.isPlav && !levit && (!stay || this.isUp || this.shX1 > 0.5))
               {
                  _loc5_ = this.checkDiagon(-2,-1);
                  if(_loc5_ > 0)
                  {
                     Y = _loc5_;
                     Y1 = Y - scY;
                     Y2 = Y;
                  }
               }
               if(this.player && this.isUp && stay && !this.isSit)
               {
                  _loc2_ = loc.space[Math.floor(X1 / Tile.tileX)][Math.floor(Y1 / Tile.tileY)];
                  _loc3_ = loc.space[Math.floor(X1 / Tile.tileX)][Math.floor(Y1 / Tile.tileY) + 1];
                  if((_loc2_.phis == 0 || _loc2_.phis == 3) && !(_loc3_.phis == 0 || _loc3_.phis == 3) && _loc3_.zForm == 0)
                  {
                     Y = Y2 = _loc3_.phY1;
                     this.sit(true);
                     _loc6_ = true;
                  }
               }
               if(this.mater)
               {
                  _loc4_ = Math.floor(Y1 / Tile.tileY);
                  while(_loc4_ <= Math.floor(Y2 / Tile.tileY))
                  {
                     _loc2_ = loc.space[Math.floor(X1 / Tile.tileX)][_loc4_];
                     if(this.collisionTile(_loc2_))
                     {
                        if(Boolean(_loc2_.door) && Boolean(_loc2_.door.inter))
                        {
                           this.pumpObj = _loc2_.door.inter;
                        }
                        if(Y2 - _loc2_.phY1 <= (stay ? this.porog : this.porog_jump) && !this.collisionAll(-20,_loc2_.phY1 - Y2))
                        {
                           Y = _loc2_.phY1;
                        }
                        else
                        {
                           X = _loc2_.phX2 + scX / 2;
                           if(this.t_throw > 0 && dx < -this.damWallSpeed && Boolean(this.damWall))
                           {
                              this.damageWall(2);
                           }
                           if(this.destroy > 0 && this.destroyWall(_loc2_,1))
                           {
                              dx *= 0.75;
                           }
                           else
                           {
                              dx = Math.abs(dx) * this.elast;
                              this.turnX = 1;
                              if(_loc2_.mat == 1)
                              {
                                 this.tykMat = 1;
                              }
                              X1 = X - scX / 2;
                              X2 = X + scX / 2;
                           }
                        }
                     }
                     _loc4_++;
                  }
               }
            }
            if(dx + this.osndx > 0)
            {
               if(!this.player && stay && this.shX2 > 0.5)
               {
                  _loc5_ = this.checkDiagon(-5);
                  if(_loc5_ > 0)
                  {
                     Y = _loc5_;
                     Y1 = Y - scY;
                     Y2 = Y;
                  }
               }
               if(this.player && !this.isSit && !this.isFly && !this.isPlav && !levit && (!stay || this.isUp || this.shX2 > 0.5))
               {
                  _loc5_ = this.checkDiagon(-2,1);
                  if(_loc5_ > 0)
                  {
                     Y = _loc5_;
                     Y1 = Y - scY;
                     Y2 = Y;
                  }
               }
               if(this.player && this.isUp && stay && !this.isSit)
               {
                  _loc2_ = loc.space[Math.floor(X2 / Tile.tileX)][Math.floor(Y1 / Tile.tileY)];
                  _loc3_ = loc.space[Math.floor(X2 / Tile.tileX)][Math.floor(Y1 / Tile.tileY) + 1];
                  if((_loc2_.phis == 0 || _loc2_.phis == 3) && !(_loc3_.phis == 0 || _loc3_.phis == 3) && _loc3_.zForm == 0)
                  {
                     Y = Y2 = _loc3_.phY1;
                     this.sit(true);
                     _loc6_ = true;
                  }
               }
               if(this.mater)
               {
                  _loc4_ = Math.floor(Y1 / Tile.tileY);
                  while(_loc4_ <= Math.floor(Y2 / Tile.tileY))
                  {
                     _loc2_ = loc.space[Math.floor(X2 / Tile.tileX)][_loc4_];
                     if(this.collisionTile(_loc2_))
                     {
                        if(Boolean(_loc2_.door) && Boolean(_loc2_.door.inter))
                        {
                           this.pumpObj = _loc2_.door.inter;
                        }
                        if(Y2 - _loc2_.phY1 <= (stay ? this.porog : this.porog_jump) && !this.collisionAll(20,_loc2_.phY1 - Y2))
                        {
                           Y = _loc2_.phY1;
                        }
                        else
                        {
                           X = _loc2_.phX1 - scX / 2;
                           if(this.t_throw > 0 && dx > this.damWallSpeed && Boolean(this.damWall))
                           {
                              this.damageWall(1);
                           }
                           if(this.destroy > 0 && this.destroyWall(_loc2_,2))
                           {
                              dx *= 0.75;
                           }
                           else
                           {
                              dx = -Math.abs(dx) * this.elast;
                              this.turnX = -1;
                              if(_loc2_.mat == 1)
                              {
                                 this.tykMat = 1;
                              }
                              X1 = X - scX / 2;
                              X2 = X + scX / 2;
                           }
                        }
                     }
                     _loc4_++;
                  }
               }
            }
            Y1 = Y - scY;
            Y2 = Y;
         }
         _loc5_ = 0;
         if(dy + this.osndy > 0)
         {
            if(dy > 0)
            {
               stay = false;
               this.stayPhis = this.stayMat = 0;
            }
            this.shX1 = this.shX2 = 1;
            if(Boolean(levit) || this.plav && this.isPlav || this.isFly)
            {
               this.diagon = 0;
               Y += (dy + this.osndy) / param1;
               if(Y > loc.limY)
               {
                  if(!this.outLoc(3))
                  {
                     Y = loc.limY - 1;
                     dy = 0;
                     this.turnY = -1;
                  }
               }
               Y1 = Y - scY;
               Y2 = Y;
               if(this.mater)
               {
                  _loc4_ = Math.floor(X1 / Tile.tileX);
                  while(_loc4_ <= Math.floor(X2 / Tile.tileX))
                  {
                     _loc2_ = loc.space[_loc4_][Math.floor(Y2 / Tile.tileY)];
                     if(this.collisionTile(_loc2_))
                     {
                        Y = _loc2_.phY1;
                        Y1 = Y - scY;
                        Y2 = Y;
                        dy = 0;
                        this.turnY = -1;
                        if(_loc2_.mat == 1)
                        {
                           this.tykMat = 1;
                        }
                     }
                     _loc4_++;
                  }
               }
            }
            else
            {
               if(this.mater)
               {
                  _loc4_ = Math.floor(X1 / Tile.tileX);
                  while(_loc4_ <= Math.floor(X2 / Tile.tileX))
                  {
                     _loc2_ = loc.space[_loc4_][Math.floor((Y2 + dy / param1) / Tile.tileY)];
                     if(this.collisionTile(_loc2_,0,dy / param1))
                     {
                        if(-(X1 - _loc2_.phX1) / scX < this.shX1)
                        {
                           this.shX1 = -(X1 - _loc2_.phX1) / scX;
                        }
                        if((X2 - _loc2_.phX2) / scX < this.shX2)
                        {
                           this.shX2 = (X2 - _loc2_.phX2) / scX;
                        }
                        _loc5_ = _loc2_.phY1;
                        if(_loc2_.mat > 0)
                        {
                           this.stayMat = _loc2_.mat;
                        }
                        if(_loc2_.phis >= 1 && !(this.transT && _loc2_.phis == 3))
                        {
                           this.stayPhis = 1;
                           if(this.t_throw > 0 && dy > this.damWallSpeed && Boolean(this.damWall))
                           {
                              this.damageWall(3);
                           }
                           if(this.destroy > 0 || massa >= 1)
                           {
                              this.destroyWall(_loc2_,3);
                           }
                        }
                        else if(_loc2_.shelf && this.stayPhis == 0)
                        {
                           this.stayPhis = 2;
                           this.stayMat = _loc2_.mat;
                        }
                        this.diagon = 0;
                     }
                     _loc4_++;
                  }
               }
               if(_loc5_ == 0 && !this.throu)
               {
                  _loc5_ = this.checkDiagon(dy / param1);
               }
               if(_loc5_ == 0 && !this.throu)
               {
                  _loc5_ = this.checkShelf(dy / param1,this.osndy / param1);
               }
               if(_loc5_)
               {
                  Y1 = _loc5_ - scY;
                  _loc4_ = Math.floor(X1 / Tile.tileX);
                  while(_loc4_ <= Math.floor(X2 / Tile.tileX))
                  {
                     _loc2_ = loc.space[_loc4_][Math.floor((_loc5_ - scY) / Tile.tileY)];
                     if(this.collisionTile(_loc2_))
                     {
                        _loc5_ = 0;
                     }
                     _loc4_++;
                  }
               }
               if(_loc5_)
               {
                  Y = _loc5_;
                  Y1 = Y - scY;
                  Y2 = Y;
                  if(dy > 16)
                  {
                     this.makeNoise(this.noiseRun,true);
                  }
                  else if(dy > 9)
                  {
                     this.makeNoise(this.noiseRun / 2,true);
                  }
                  if(dy > 5)
                  {
                     this.sndFall();
                  }
                  if(this.jumpBall > 0 && dy > 3)
                  {
                     dy = -dy * this.jumpBall;
                     this.turnY = -1;
                  }
                  else
                  {
                     dy = 0;
                  }
                  stay = true;
                  fracLevit = 0;
                  this.isLaz = 0;
               }
               else
               {
                  Y += dy / param1;
                  Y1 = Y - scY;
                  Y2 = Y;
               }
               if(Y > loc.limY)
               {
                  if(!this.outLoc(3))
                  {
                     Y = loc.limY - 1;
                     this.turnY = -1;
                     Y1 = Y - scY;
                     Y2 = Y;
                  }
               }
            }
         }
         if(dy + this.osndy < 0)
         {
            if(dy < 0)
            {
               stay = false;
               this.diagon = 0;
            }
            if(Y - scY < 0)
            {
               if(!this.outLoc(4))
               {
                  Y = scY - 0.1;
                  dy = 0;
                  this.turnY = 1;
               }
            }
            if(dy > 0)
            {
               _loc5_ = this.checkShelf(dy / param1,this.osndy / param1);
               if(_loc5_)
               {
                  Y = _loc5_;
                  Y1 = Y - scY;
                  Y2 = Y;
                  dy = 0;
                  stay = true;
               }
            }
            else
            {
               Y += (dy + this.osndy) / param1;
               Y1 = Y - scY;
               Y2 = Y;
            }
            if(this.mater)
            {
               _loc4_ = Math.floor(X1 / Tile.tileX);
               while(_loc4_ <= Math.floor(X2 / Tile.tileX))
               {
                  _loc2_ = loc.space[_loc4_][Math.floor(Y1 / Tile.tileY)];
                  if(this.collisionTile(_loc2_))
                  {
                     if(this.t_throw > 0 && dy < -this.damWallSpeed && Boolean(this.damWall))
                     {
                        this.damageWall(4);
                     }
                     if(this.destroy > 0)
                     {
                        this.destroyWall(_loc2_,4);
                     }
                     Y = _loc2_.phY2 + scY;
                     Y1 = Y - scY;
                     Y2 = Y;
                     dy = 0;
                     this.turnY = 1;
                     if(_loc2_.mat == 1)
                     {
                        this.tykMat = 1;
                     }
                     stay = false;
                  }
                  _loc4_++;
               }
            }
         }
         if(_loc6_)
         {
            _loc6_ = false;
            this.unsit();
         }
      }
      
      public function run2(param1:int = 1) : *
      {
         X += dx / param1;
         Y += dy / param1;
         if(X - scX / 2 < 0)
         {
            X = scX / 2;
            dx = Math.abs(dx) * this.elast;
            this.turnX = 1;
         }
         if(X + scX / 2 >= loc.limX)
         {
            X = loc.limX - 1 - scX / 2;
            dx = -Math.abs(dx) * this.elast;
            this.turnX = -1;
         }
         if(Y - scY < 0)
         {
            Y = scY - 0.1;
            dy = 0;
            this.turnY = 1;
         }
         if(Y > loc.limY)
         {
            Y = loc.limY - 1;
            dy = 0;
            this.turnY = -1;
         }
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         Y1 = Y - scY;
         Y2 = Y;
      }
      
      public function sit(param1:Boolean) : *
      {
         if(this.isSit == param1)
         {
            return;
         }
         this.isSit = param1;
         if(this.isSit)
         {
            scX = this.sitX;
            scY = this.sitY;
         }
         else
         {
            scX = this.stayX;
            scY = this.stayY;
         }
         X1 = X - scX / 2;
         X2 = X + scX / 2;
         Y1 = Y - scY;
      }
      
      public function unsit() : *
      {
         this.sit(false);
         if(this.collisionAll())
         {
            this.sit(true);
         }
      }
      
      public function collisionAll(param1:Number = 0, param2:Number = 0) : Boolean
      {
         var _loc4_:* = undefined;
         if(loc.sky)
         {
            return false;
         }
         var _loc3_:* = Math.floor((X1 + param1) / Tile.tileX);
         while(_loc3_ <= Math.floor((X2 + param1) / Tile.tileX))
         {
            _loc4_ = Math.floor((Y1 + param2) / Tile.tileY);
            while(_loc4_ <= Math.floor((Y2 + param2) / Tile.tileY))
            {
               if(!(_loc3_ < 0 || _loc3_ >= loc.spaceX || _loc4_ < 0 || _loc4_ >= loc.spaceY))
               {
                  if(this.collisionTile(loc.space[_loc3_][_loc4_],param1,param2))
                  {
                     return true;
                  }
               }
               _loc4_++;
            }
            _loc3_++;
         }
         return false;
      }
      
      public function collisionTile(param1:Tile, param2:Number = 0, param3:Number = 0) : int
      {
         if(!param1 || (param1.phis == 0 || this.transT && param1.phis == 3) && !param1.shelf)
         {
            return 0;
         }
         if(X2 + param2 <= param1.phX1 || X1 + param2 >= param1.phX2 || Y2 + param3 <= param1.phY1 || Y1 + param3 >= param1.phY2)
         {
            return 0;
         }
         if((param1.phis == 0 || this.transT && param1.phis == 3) && param1.shelf && (Y2 - (stay ? this.porog : this.porog_jump) > param1.phY1 || this.throu || this.t_throw > 0 || levit || this.isFly || this.diagon != 0))
         {
            return 0;
         }
         return 1;
      }
      
      public function checkStairs(param1:int = -1, param2:int = 0) : Boolean
      {
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         try
         {
            _loc3_ = Math.floor((X + param2) / Tile.tileX);
            _loc4_ = Math.floor((Y + param1) / Tile.tileY);
            if(_loc4_ >= loc.spaceY)
            {
               _loc4_ = loc.spaceY - 1;
            }
            if(loc.space[_loc3_][_loc4_].phis >= 1 && !(this.transT && loc.space[_loc3_][_loc4_].phis == 3))
            {
               this.isLaz = 0;
               return false;
            }
            if((loc.space[_loc3_][_loc4_] as Tile).stair)
            {
               this.isLaz = storona = (loc.space[_loc3_][_loc4_] as Tile).stair;
               if(this.isLaz == -1)
               {
                  X = (loc.space[_loc3_][_loc4_] as Tile).phX1 + scX / 2;
               }
               else
               {
                  X = (loc.space[_loc3_][_loc4_] as Tile).phX2 - scX / 2;
               }
               X1 = X - scX / 2;
               X2 = X + scX / 2;
               stay = false;
               this.sit(false);
               return true;
            }
         }
         catch(err:*)
         {
         }
         this.isLaz = 0;
         return false;
      }
      
      public function checkWater() : Boolean
      {
         var pla:* = this.inWater;
         try
         {
            if((loc.space[Math.floor(X / Tile.tileX)][Math.floor((Y - scY * 0.75) / Tile.tileY)] as Tile).water > 0)
            {
               this.isPlav = true;
               this.inWater = true;
               if(this.plav)
               {
                  stay = false;
                  this.sit(false);
               }
            }
            else
            {
               this.isPlav = false;
               if(scY <= Tile.tileY)
               {
                  this.inWater = false;
               }
               else if((loc.space[Math.floor(X / Tile.tileX)][Math.floor((Y - scY * 0.25) / Tile.tileY)] as Tile).water > 0)
               {
                  this.inWater = true;
               }
               else
               {
                  this.inWater = false;
               }
            }
         }
         catch(err:*)
         {
            isPlav = inWater = false;
         }
         if(pla != this.inWater && (dy > 8 || dy < -8 || this.plaKap))
         {
            Emitter.emit("kap",loc,X,Y - scY * 0.25 + dy,{
               "dy":-Math.abs(dy) * (Math.random() * 0.3 + 0.3),
               "kol":Math.floor(Math.abs(dy * massa * 2) + 1)
            });
         }
         if(pla != this.inWater && dy > 5)
         {
            if(massa > 2)
            {
               this.sound("fall_water0",0,dy / 10);
            }
            else if(massa > 0.4)
            {
               this.sound("fall_water1",0,dy / 10);
            }
            else if(massa > 0.2)
            {
               this.sound("fall_water2",0,dy / 10);
            }
            else
            {
               this.sound("fall_item_water",0,dy / 10);
            }
         }
         if(pla != this.inWater && dy < -5 && massa > 0.4)
         {
            this.sound("fall_water2",0,-dy / 10);
         }
         if(this.inWater && !this.isPlav && (dx > 3 || dx < -3))
         {
            Emitter.emit("kap",loc,X,Y - scY * 0.25,{"rx":scX});
         }
         if(this.isPlav)
         {
            ++this.namok_t;
            if(this.namok_t >= 100)
            {
               this.namok_t = 0;
               this.addEffect("namok");
            }
         }
         else if(this.namok_t > 0)
         {
            --this.namok_t;
         }
         return this.isPlav;
      }
      
      public function checkShelf(param1:Number, param2:Number = 0) : Number
      {
         var _loc3_:* = undefined;
         var _loc4_:Box = null;
         for(_loc3_ in loc.objs)
         {
            _loc4_ = loc.objs[_loc3_] as Box;
            if(!_loc4_.invis && _loc4_.shelf && !_loc4_.levit && !(X2 < _loc4_.X1 || X1 > _loc4_.X2) && Y2 + param2 <= _loc4_.Y1 && Y2 + param1 + param2 > _loc4_.Y1)
            {
               this.shX1 = this.shX2 = 1;
               if(-(X1 - _loc4_.X1) / scX < this.shX1)
               {
                  this.shX1 = -(X1 - _loc4_.X1) / scX;
               }
               if((X2 - _loc4_.X2) / scX < this.shX2)
               {
                  this.shX2 = (X2 - _loc4_.X2) / scX;
               }
               this.stayMat = _loc4_.mat;
               this.stayPhis = 2;
               this.stayOsn = _loc4_;
               if(!_loc4_.stay)
               {
                  _loc4_.dy += dy * massa / (massa + _loc4_.massa);
                  _loc4_.fixPlav = false;
               }
               return _loc4_.Y1;
            }
         }
         return 0;
      }
      
      public function checkDiagon(param1:Number, param2:int = 0) : Number
      {
         var _loc3_:Number = Number(NaN);
         var _loc4_:Number = 0;
         var _loc5_:Tile = loc.getAbsTile(X,Y + param1);
         if(this.diagon == 0)
         {
            if(_loc5_.diagon != 0 && (param2 == 0 || _loc5_.diagon == param2))
            {
               _loc3_ = _loc5_.getMaxY(X);
               if(_loc3_ < Y + param1)
               {
                  this.diagon = _loc5_.diagon;
                  _loc4_ = _loc3_;
               }
            }
            else
            {
               _loc5_ = loc.getAbsTile(X,Y + 40);
               if(_loc5_.diagon != 0 && (param2 == 0 || _loc5_.diagon == param2))
               {
                  _loc3_ = _loc5_.getMaxY(X);
                  if(_loc3_ < Y + param1)
                  {
                     this.diagon = _loc5_.diagon;
                     _loc4_ = _loc3_;
                  }
               }
            }
         }
         else if(_loc5_.diagon != 0 && (param2 == 0 || _loc5_.diagon == param2))
         {
            _loc3_ = _loc5_.getMaxY(X);
            this.diagon = _loc5_.diagon;
            _loc4_ = _loc3_;
         }
         else
         {
            _loc5_ = loc.getAbsTile(X,Y - 40);
            if(_loc5_.diagon != 0 && (param2 == 0 || _loc5_.diagon == param2))
            {
               _loc3_ = _loc5_.getMaxY(X);
               this.diagon = _loc5_.diagon;
               _loc4_ = _loc3_;
            }
            else
            {
               this.diagon = 0;
            }
         }
         if(this.diagon != 0 && (param2 == 0 || _loc5_.diagon == param2))
         {
            this.shX1 = this.shX2 = 0;
            this.stayPhis = 2;
            this.stayMat = _loc5_.mat;
         }
         return _loc4_;
      }
      
      public function teleport(param1:Number, param2:Number, param3:int = 0) : *
      {
         if(param3 > 0)
         {
            Emitter.emit("tele",loc,X,Y - scY / 2,{
               "rx":scX,
               "ry":scY,
               "kol":30
            });
         }
         this.setPos(param1,param2);
         if(this.currentWeapon)
         {
            this.setWeaponPos(this.currentWeapon.tip);
            this.currentWeapon.setNull();
         }
         this.isLaz = 0;
         levit = 0;
         if(param3 > 0)
         {
            Emitter.emit("teleport",loc,X,Y - scY / 2);
         }
         if(rconnectTeleported != null)
         {
            rconnectTeleported(this);
         }
      }
      
      public function otryv() : *
      {
         this.fixed = false;
      }
      
      public function initBlit() : *
      {
         this.blitData = World.w.grafon.getSpriteList(this.blitId);
         this.blitRect = new Rectangle(0,0,this.blitX,this.blitY);
         this.blitPoint = new Point(0,0);
         vis = new MovieClip();
         var _loc1_:* = new Sprite();
         this.visData = new BitmapData(this.blitX,this.blitY,true,0);
         this.visBmp = new Bitmap(this.visData);
         vis.addChild(_loc1_);
         _loc1_.addChild(this.visBmp);
         if(this.blitDX >= 0)
         {
            this.visBmp.x = -this.blitDX;
         }
         else
         {
            this.visBmp.x = -this.blitX / 2;
         }
         if(this.blitDY >= 0)
         {
            this.visBmp.y = -this.blitDY;
         }
         else
         {
            this.visBmp.y = -this.blitY + 10;
         }
         this.animState = "stay";
      }
      
      public function blit(param1:int, param2:int) : *
      {
         this.blitRect.x = param2 * this.blitX;
         this.blitRect.y = param1 * this.blitY;
         this.visData.copyPixels(this.blitData,this.blitRect,this.blitPoint);
      }
      
      override public function addVisual() : *
      {
         var _loc1_:* = undefined;
         if(this.disabled)
         {
            return;
         }
         this.trigDis = !this.checkTrig();
         if(this.trigDis)
         {
            return;
         }
         super.addVisual();
         if(!this.player && !this.hpbar && Boolean(vis))
         {
            this.hpbar = new hpBar();
            if(this.hero <= 0)
            {
               this.hpbar.goldstar.visible = false;
            }
            if(this.invis)
            {
               this.hpbar.visible = false;
            }
            this.visDetails();
         }
         if(Boolean(this.hpbar) && Boolean(loc) && loc.active)
         {
            World.w.grafon.visObjs[3].addChild(this.hpbar);
         }
         if(Boolean(cTransform) && this.ctrans)
         {
            vis.transform.colorTransform = cTransform;
         }
         if(this.childObjs)
         {
            for(_loc1_ in this.childObjs)
            {
               if(this.childObjs[_loc1_] != null && Boolean(this.childObjs[_loc1_].vis))
               {
                  this.childObjs[_loc1_].addVisual();
               }
            }
         }
      }
      
      override public function remVisual() : *
      {
         var _loc1_:* = undefined;
         super.remVisual();
         if(Boolean(this.hpbar) && Boolean(this.hpbar.parent))
         {
            this.hpbar.parent.removeChild(this.hpbar);
         }
         if(this.childObjs)
         {
            for(_loc1_ in this.childObjs)
            {
               if(this.childObjs[_loc1_])
               {
                  this.childObjs[_loc1_].remVisual();
               }
            }
         }
      }
      
      public function animate() : *
      {
      }
      
      protected function sndFall() : *
      {
      }
      
      internal function sndRunPlay() : *
      {
         if(rasst2 < this.sndRunDist * this.sndRunDist)
         {
            this.sndVolkoef = (this.sndRunDist - Math.sqrt(rasst2)) / this.sndRunDist;
            if(this.sndVolkoef < 0.5)
            {
               this.sndVolkoef *= 2;
            }
            else
            {
               this.sndVolkoef = 1;
            }
            Snd.pshum(this.sndRun,this.sndVolkoef);
         }
      }
      
      internal function newPart(param1:String, param2:int = 1, param3:int = 0) : *
      {
         Emitter.emit(param1,loc,X,Y - scY / 2,{
            "kol":param2,
            "frame":param3
         });
      }
      
      public function setVisPos() : *
      {
         if(vis)
         {
            vis.x = X;
            vis.y = Y;
            vis.scaleX = storona;
         }
      }
      
      public function visDetails() : *
      {
         if(this.hpbar == null)
         {
            return;
         }
         if((this.hp < this.maxhp || this.armor_qual > 0 && this.armor_hp < this.armor_maxhp || this.hero > 0) && this.hp > 0 && !this.invis || this.boss)
         {
            if(this.boss)
            {
               World.w.gui.hpBarBoss(this.hp / this.maxhp);
               this.hpbar.visible = false;
            }
            else
            {
               this.hpbar.visible = true;
               if(this.hp < this.maxhp)
               {
                  this.hpbar.bar.visible = true;
                  this.hpbar.bar.gotoAndStop(Math.floor((1 - this.hp / this.maxhp) * 20 + 1));
               }
               else
               {
                  this.hpbar.bar.visible = false;
               }
               if(this.armor_qual > 0)
               {
                  this.hpbar.armor.visible = true;
                  this.hpbar.armor.gotoAndStop(Math.floor((1 - this.armor_hp / this.armor_maxhp) * 20 + 1));
               }
               else
               {
                  this.hpbar.armor.visible = false;
               }
            }
         }
         else
         {
            this.hpbar.visible = false;
         }
      }
      
      public function setHpbarPos() : *
      {
         if(this.boss)
         {
            this.hpbar.y = 60;
            this.hpbar.x = World.w.cam.screenX / 2;
         }
         else
         {
            this.hpbar.y = Y - this.stayY - 20;
            if(this.hpbar.y < 20)
            {
               this.hpbar.y = 20;
            }
            this.hpbar.x = X;
            if(Boolean(loc) && loc.zoom != 1)
            {
               this.hpbar.scaleX = this.hpbar.scaleY = loc.zoom;
            }
         }
      }
      
      public function sound(param1:String, param2:Number = 0, param3:Number = 1) : SoundChannel
      {
         return Snd.ps(param1,X,Y,param2,param3);
      }
      
      public function actions() : *
      {
         var _loc1_:* = undefined;
         if(isNaN(dx))
         {
            trace(nazv,"dx!!!");
            dx = 0;
         }
         if(isNaN(dy))
         {
            trace(nazv,"dy!!!");
            dy = 0;
         }
         if(this.neujaz > 0)
         {
            --this.neujaz;
         }
         if(this.shok > 0)
         {
            --this.shok;
         }
         if(this.oduplenie > 0)
         {
            if(!(this.opt && this.opt.izvrat && World.w.pers.socks || this.noAgro))
            {
               --this.oduplenie;
            }
         }
         if(this.noise > 0)
         {
            this.noise -= 20;
         }
         if(this.noise_t > 0)
         {
            --this.noise_t;
         }
         if(stay && (dx > 12 || dx < -12))
         {
            this.makeNoise(this.noiseRun);
         }
         else if(stay && (dx > 7 || dx < -7))
         {
            this.makeNoise(this.noiseRun / 2);
         }
         else if(stay && (dx > 3 || dx < -3))
         {
            this.makeNoise(this.noiseRun / 4);
         }
         if(this.isFly && (dx > 3 || dx < -3 || dy > 3 || dy < -3))
         {
            this.makeNoise(this.noiseRun / 2);
         }
         this.eyeX = X + scX * 0.25 * storona;
         this.eyeY = Y - scY * 0.75;
         if(this.sost == 1)
         {
            if(levit)
            {
               ++this.levit_r;
            }
            else
            {
               if(this.levit_r == 1)
               {
                  levitPoss = true;
               }
               if(this.levit_r > 60)
               {
                  this.levit_r = 60;
               }
               if(this.levit_r > 0)
               {
                  --this.levit_r;
               }
            }
         }
         if(levit)
         {
            if(!this.fixed && massa != this.massaMove)
            {
               this.otryv();
            }
            if(this.fixed)
            {
               if(this.levit_r > 75)
               {
                  this.otryv();
               }
            }
            massa = this.massaMove;
         }
         if(this.demask > 0)
         {
            this.demask -= 5;
         }
         if(this.effects.length > 0)
         {
            _loc1_ = 0;
            while(_loc1_ < this.effects.length)
            {
               if(!(this.effects[_loc1_] as Effect).vse)
               {
                  (this.effects[_loc1_] as Effect).step();
               }
               else
               {
                  this.effects.splice(_loc1_,1);
                  _loc1_--;
               }
               _loc1_++;
            }
         }
         if(this.cut > 0 || this.poison > 0 || this.inWater && loc.wdam > 0)
         {
            if(this.t_hp <= 0)
            {
               this.t_hp = 30;
               if(this.cut > 0)
               {
                  this.damage(Math.sqrt(this.cut),D_BLEED,null,true);
                  this.cut -= this.critHeal * (this == World.w.gg ? World.w.pers.piFactor("bleedDecay") : 1);
                  if(this.cut < 0)
                  {
                     this.cut = 0;
                  }
               }
               if(this.poison > 0)
               {
                  this.damage(Math.sqrt(this.poison),D_POISON,null,true);
                  this.poison -= this.critHeal;
                  if(this.poison < 0)
                  {
                     this.poison = 0;
                  }
                  Emitter.emit("poison",loc,X,Y - scY * 0.5);
               }
               if(this.inWater && loc.wdam > 0)
               {
                  this.damage(loc.wdam,loc.wtipdam,null,true);
               }
            }
         }
         if(this.stun > 0)
         {
            --this.stun;
            if(this.stun % 10 == 0)
            {
               if(Boolean(this.opt) && Boolean(this.opt.robot))
               {
                  Emitter.emit("discharge",loc,X,Y - scY * 0.5);
                  Emitter.emit("iskr",loc,X,Y - scY * 0.5,{"kol":5});
               }
               else if(!this.mech)
               {
                  Emitter.emit("stun",loc,X,Y - scY * 0.75);
               }
            }
         }
         if(this.t_hp > 0)
         {
            --this.t_hp;
         }
         if(this.slow > 0)
         {
            --this.slow;
            if(!this.fixed && this.slow % 10 == 0 && vis && vis.visible && (dx > 3 || dx < -3 || dy > 5 || dy < -5))
            {
               Emitter.emit("slow",loc,X,Y - scY * 0.25);
            }
         }
         if(this.t_throw > 0)
         {
            --this.t_throw;
         }
         if(World.w.showHit == 2)
         {
            if(this.t_hitPart > 0)
            {
               --this.t_hitPart;
            }
            else
            {
               this.hitSumm = 0;
               this.hitPart = null;
            }
         }
         if(this.t_mess > 0)
         {
            --this.t_mess;
         }
      }
      
      public function makeNoise(param1:int, param2:Boolean = false) : *
      {
         if(param1 <= 0)
         {
            return;
         }
         if(this.noise < param1)
         {
            this.noise = param1;
         }
         if(this.noise_t == 0 || param2 && this.noise_t <= 20)
         {
            this.noise_t = 30;
            if(Boolean(loc) && loc.active && !this.getTileVisi())
            {
               if(!this.player)
               {
                  Emitter.emit("noise",loc,X,Y,{
                     "rx":40,
                     "ry":40,
                     "alpha":Math.min(1,param1 / 500)
                  });
               }
            }
         }
      }
      
      public function attKorp(param1:Unit, param2:Number = 1) : Boolean
      {
         if(this.sost > 1 || param1 == null || param1.loc != loc || this.burn != null)
         {
            return false;
         }
         if(param1.X1 > X2 || param1.X2 < X1 || param1.Y1 > Y2 || param1.Y2 < Y1 || param1.neujaz > 0)
         {
            return false;
         }
         return param1.udarUnit(this,param2);
      }
      
      public function crash(param1:Bullet) : *
      {
         if(param1.weap)
         {
            this.makeNoise(param1.weap.noise,true);
         }
      }
      
      public function setWeaponPos(param1:int = 0) : *
      {
         this.weaponX = X;
         this.weaponY = Y - scY * 0.5;
         this.magicX = X;
         this.magicY = Y - scY * 0.5;
      }
      
      public function setPunchWeaponPos(param1:WPunch) : *
      {
         param1.X = X + scX / 3 * storona;
         param1.Y = Y - scY * 0.75;
         param1.rot = storona > 0 ? 0 : Math.PI;
      }
      
      public function destroyWall(param1:Tile, param2:int = 0) : Boolean
      {
         if(this.isPlav || Boolean(levit) || this.sost != 1)
         {
            return false;
         }
         if(param2 == 3 && dy > 15 && this.destroy < 50 && massa >= 1)
         {
            loc.hitTile(param1,50,(param1.X + 0.5) * Tile.tileX,(param1.Y + 0.5) * Tile.tileY,100);
            if(param1.phis == 0)
            {
               return true;
            }
         }
         if(this.destroy > 0 && (dx > 10 && param2 == 2 || dx < -10 && param2 == 1 || dy < -10 && param2 == 4 || dy > 10 && param2 == 3))
         {
            loc.hitTile(param1,this.destroy,(param1.X + 0.5) * Tile.tileX,(param1.Y + 0.5) * Tile.tileY,param2 == 3 ? 100 : 9);
         }
         if(param1.phis == 0)
         {
            return true;
         }
         return false;
      }
      
      public function explosion(param1:Number, param2:int = 4, param3:Number = 200, param4:int = 0, param5:Number = 0, param6:Number = 0, param7:int = 0) : *
      {
         var _loc8_:Bullet = new Bullet(this,X,Y - 3,null,param4 > 1);
         _loc8_.weapId = this.id;
         _loc8_.damageExpl = param1;
         _loc8_.tipDamage = param2;
         _loc8_.explKol = param4;
         if(param4 > 1)
         {
            _loc8_.explTip = 2;
         }
         else if(param2 == 10)
         {
            _loc8_.explTip = 3;
         }
         _loc8_.explRadius = param3;
         _loc8_.tipDecal = param7;
         _loc8_.otbros = param5;
         _loc8_.destroy = param6;
         _loc8_.explosion();
         _loc8_.babah = true;
      }
      
      public function addEffect(param1:String, param2:Number = 0, param3:int = 0, param4:Boolean = true) : Effect
      {
         var _loc6_:* = undefined;
         if(param1 == null || param1 == "")
         {
            return null;
         }
         var _loc5_:Effect = new Effect(param1,this,param2);
         if(param3 > 0)
         {
            _loc5_.t = param3 * World.fps;
         }
         for(_loc6_ in this.effects)
         {
            if(_loc5_.tip == 3 && this.effects[_loc6_].tip == 3)
            {
               this.effects[_loc6_] = _loc5_;
               _loc5_.setEff();
               return _loc5_;
            }
            if(this.effects[_loc6_].id == param1 || this.effects[_loc6_].id == _loc5_.post)
            {
               if(this.effects[_loc6_].val > _loc5_.val)
               {
                  _loc5_.val = this.effects[_loc6_].val;
               }
               if(_loc5_.add)
               {
                  _loc5_.t += this.effects[_loc6_].t;
                  if(_loc5_.t > 30000)
                  {
                     _loc5_.t = 30000;
                  }
                  _loc5_.checkT();
               }
               this.effects[_loc6_] = _loc5_;
               _loc5_.setEff();
               return _loc5_;
            }
         }
         _loc5_.se = param4;
         this.effects.push(_loc5_);
         if(this.player && param4)
         {
            World.w.gui.infoEffText(param1);
         }
         _loc5_.setEff();
         return _loc5_;
      }
      
      public function remEffect(param1:String) : *
      {
         var _loc2_:* = undefined;
         for each(_loc2_ in this.effects)
         {
            if(_loc2_ != null && _loc2_.id == param1)
            {
               _loc2_.unsetEff();
            }
         }
      }
      
      internal function setSkillParam(param1:XML, param2:int, param3:int = 0) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:Number = Number(NaN);
         var _loc6_:int = 0;
         if(param1 == null)
         {
            return;
         }
         for each(_loc4_ in param1.sk)
         {
            if(_loc4_.@dop.length())
            {
               _loc6_ = param3;
            }
            else
            {
               _loc6_ = param2;
            }
            if(_loc4_.@vd.length())
            {
               _loc5_ = Number(_loc4_.@v0) + _loc6_ * Number(_loc4_.@vd);
            }
            else if(_loc4_.attribute("v" + _loc6_).length())
            {
               _loc5_ = Number(_loc4_.attribute("v" + _loc6_));
            }
            else
            {
               _loc5_ = Number(_loc4_.@v0);
            }
            if(_loc4_.@tip == "res")
            {
               this.vulner[_loc4_.@id] -= _loc5_;
            }
            else if(hasOwnProperty(_loc4_.@id))
            {
               if(_loc4_.@ref == "add")
               {
                  this[_loc4_.@id] += _loc5_;
               }
               else if(_loc4_.@ref == "mult")
               {
                  this[_loc4_.@id] *= _loc5_;
               }
               else
               {
                  this[_loc4_.@id] = _loc5_;
               }
            }
         }
      }
      
      public function setEffParams() : *
      {
         var i:* = undefined;
         var eff:Effect = null;
         var effid:* = undefined;
         var sk:* = undefined;
         try
         {
            this.tormoz = 1;
            this.precMultCont = 1;
            this.rapidMultCont = 1;
            if(this.begvulner == null)
            {
               return;
            }
            i = 0;
            while(i < kolVulners)
            {
               this.vulner[i] = this.begvulner[i];
               i++;
            }
            if(!this.player && loc.biom == 5)
            {
               this.vulner[D_PINK] = 0;
            }
            for each(eff in this.effects)
            {
               effid = eff.id;
               sk = rconnectXmlFind(AllData.d.eff,"id",effid)[0];
               this.setSkillParam(sk,eff.vse ? 0 : 1);
            }
            this.setHeroVulners();
         }
         catch(err:*)
         {
            trace("ошибка эффектов",nazv);
         }
      }
      
      public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number
      {
         if(Unit.rconnectDeferDamage != null && Boolean(Unit.rconnectDeferDamage(this,param1,param2,param3,param4)))
         {
            return 0;
         }
         var _loc5_:int = 0;
         var _loc6_:Boolean = false;
         var _loc7_:String = null;
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc10_:int = 0;
         var _loc11_:* = undefined;
         var _loc12_:* = undefined;
         var _loc13_:int = 0;
         var _loc14_:int = 0;
         var _loc15_:Number = Number(NaN);
         var _loc16_:Number = Number(NaN);
         if(this.invulner)
         {
            return 0;
         }
         if(this.sost == 1)
         {
            this.dieWeap = null;
         }
         if(param2 < kolVulners)
         {
            param1 *= this.vulner[param2];
         }
         _loc5_ = 0;
         _loc6_ = false;
         if(param3)
         {
            if(Boolean(param3.owner) && param3.owner.player && Boolean(this.opt))
            {
               if(this.opt.pony)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damPony;
               }
               if(this.opt.zombie)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damZombie;
               }
               if(this.opt.robot)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damRobot;
               }
               if(this.opt.insect)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damInsect;
               }
               if(this.opt.monster)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damMonster;
               }
               if(this.opt.alicorn)
               {
                  param1 *= (param3.owner as UnitPlayer).pers.damAlicorn;
               }
            }
         }
         if(param1 == 0)
         {
            return 0;
         }
         if(param2 == D_SPARK)
         {
            if(!stay && !this.inWater && this.isLaz == 0)
            {
               param1 *= 0.5;
            }
         }
         if(param2 == D_VENOM && this.sost != 1)
         {
            return 0;
         }
         if(!this.player && this.armor_hp > 0 && (this.shithp <= 0 || param1 > this.shitArmor) && (this.armor > 0 || this.marmor > 0) && (param2 <= D_BALE && param2 != D_EMP && param2 != D_POISON && param2 != D_BLEED || param2 == D_ASTRO))
         {
            _loc9_ = param1;
            if(this.shithp > 0)
            {
               _loc9_ -= this.shitArmor;
            }
            if(Boolean(param3) && param3.armorMult > 1)
            {
               _loc9_ /= param3.armorMult;
            }
            if(param2 == D_ACID)
            {
               _loc9_ *= 4;
            }
            else if(param2 == D_EXPL)
            {
               _loc9_ *= 2;
            }
            this.armor_hp -= _loc9_;
            if(this.armor_hp <= 0)
            {
               this.armor_hp = 0;
               this.armor_qual = 0;
               _loc7_ = Res.guiText("abr");
            }
         }
         if(param1 < 0)
         {
            this.heal(-param1);
            return 0;
         }
         _loc8_ = 0;
         if(!param4)
         {
            if(param2 == D_BUL || param2 == D_BLADE || param2 == D_EXPL || param2 == D_PHIS || param2 == D_FANG || param2 == D_ACID)
            {
               _loc8_ = this.skin;
               if(this.armor_qual > 0 && this.isrnd(this.armor_qual))
               {
                  _loc8_ += this.armor;
               }
            }
            if(param2 == D_FIRE || param2 == D_LASER || param2 == D_PLASMA || param2 == D_SPARK || param2 == D_CRIO || param2 == D_ASTRO)
            {
               _loc8_ = this.skin;
               if(this.armor_qual > 0 && this.isrnd(this.armor_qual))
               {
                  _loc8_ += this.marmor;
               }
            }
            if(this.shithp > 0)
            {
               this.shithp -= param1;
               if(this.shithp < 0)
               {
                  this.shithp = 0;
               }
               _loc8_ += this.shitArmor;
            }
            if(param3)
            {
               _loc8_ *= param3.armorMult;
               _loc8_ -= param3.pier;
            }
            if(_loc8_ > 0)
            {
               param1 -= _loc8_;
               if(Boolean(param3) && param3.probiv > 0)
               {
                  param3.damage -= _loc8_ / param3.probiv;
               }
            }
         }
         if(param3)
         {
            if(Math.random() < param3.critCh)
            {
               param1 *= param3.critDamMult;
               _loc5_ = 1;
            }
            if(!this.doop && this.celUnit != param3.owner && param3.critInvis > 0)
            {
               if(Math.random() < param3.critInvis)
               {
                  param1 *= 2;
                  _loc5_ += 2;
               }
            }
         }
         if(param1 > 0)
         {
            _loc10_ = 0;
            if(Boolean(param3) && Boolean(param3.desintegr) && (param2 == D_LASER || param2 == D_PLASMA))
            {
               if(this.hp <= param1 * 10 && this.isrnd(param3.desintegr))
               {
                  _loc10_ = 1;
                  param1 *= 12;
               }
            }
            if(param2 != D_POISON && param2 != D_BLEED && param2 != D_INSIDE)
            {
               param1 *= this.allVulnerMult;
            }
            _loc6_ = (this.sost == 1 || this.sost == 2) && this.showNumbs && param1 > 0.5;
            if(Boolean(param3) && param3.probiv > 0)
            {
               if(this.maxhp > param1 * 20)
               {
                  param3.damage = 0;
               }
               else if(this.maxhp > param1)
               {
                  param3.damage *= param3.probiv;
               }
               else
               {
                  param3.damage *= 1 - (1 - param3.probiv) * this.maxhp / param1;
               }
            }
            this.hp -= param1;
            _loc11_ = Math.round((Math.random() * 0.8 + 0.2) * this.maxShok * 4 * param1 / this.maxhp);
            if(_loc11_ > this.maxShok)
            {
               _loc11_ = this.maxShok;
            }
            if(param4 || _loc11_ < 5)
            {
               _loc11_ = 0;
            }
            if(this.shok < _loc11_)
            {
               this.shok = _loc11_;
            }
            if(this.hp <= 0)
            {
               if(Boolean(param3) && Boolean(param3.weap))
               {
                  this.dieWeap = param3.weap.id;
               }
               if(Boolean(param3) && Boolean(param3.weapId))
               {
                  this.dieWeap = param3.weapId;
               }
               if(param2 == D_FIRE && (this.hp <= -this.maxhp * 3 || !this.trup))
               {
                  _loc10_ = 1;
               }
               if(param2 == D_LASER && (this.hp <= -this.maxhp * 3 || !this.trup || this.isrnd()))
               {
                  _loc10_ = 1;
               }
               if(param2 == D_PLASMA || param2 == D_ACID)
               {
                  _loc10_ = 2;
               }
               if(param2 == D_ASTRO || param2 == D_FRIEND)
               {
                  _loc10_ = 3;
               }
               if(param2 == D_CRIO)
               {
                  _loc10_ = 4;
               }
               if(this.timerDie <= 0)
               {
                  this.die(_loc10_);
               }
               else
               {
                  this.sost = 2;
               }
            }
            if((param2 == D_SPARK || param2 == D_EMP) && this.opt && this.opt.robot && this.sost == 1 && Math.random() < param1 / this.maxhp)
            {
               _loc7_ = Res.guiText("kz");
               if(this.stun < robotKZ)
               {
                  this.stun = robotKZ;
               }
            }
            if(param2 == D_EXPL && this.opt && !this.opt.robot && !this.mech && !this.doop && this.sost == 1 && Math.random() < param1 / this.maxhp)
            {
               _loc7_ = Res.txt("e","contusion");
               this.addEffect("contusion");
            }
            if(!param4 && this.demask < 200)
            {
               this.demask = 200;
            }
            if(Boolean(param3) && Boolean(param3.weap))
            {
               if(param3.weap.dopEffect != null && param3.weap.dopCh > 0 && (param3.weap.dopCh >= 1 || Math.random() < param3.weap.dopCh))
               {
                  if(param3.weap.dopEffect == "igni" && this.vulner[D_FIRE] > 0.1)
                  {
                     this.addEffect("burning",param3.weap.dopDamage);
                     _loc7_ = Res.txt("e","burning");
                  }
                  if(param3.weap.dopEffect == "ice" && this.vulner[D_CRIO] > 0.1 && !this.mech)
                  {
                     _loc7_ = Res.txt("e","freezing");
                     this.addEffect("freezing");
                  }
                  if(param3.weap.dopEffect == "blind" && this.vulner[D_LASER] > 0.1 && !this.mech && !this.doop)
                  {
                     _loc7_ = Res.txt("e","blindness");
                     this.addEffect("blindness");
                  }
                  if(param3.weap.dopEffect == "acid" && this.vulner[D_ACID] > 0.1)
                  {
                     _loc7_ = Res.txt("e","chemburn");
                     this.addEffect("chemburn",param3.weap.dopDamage);
                  }
                  if(param3.weap.dopEffect == "pink" && this.vulner[D_PINK] > 0.1)
                  {
                     _loc7_ = Res.txt("e","pinkcloud");
                     this.addEffect("pinkcloud",param3.weap.dopDamage);
                  }
                  if(param3.weap.dopEffect == "poison" && this.vulner[D_POISON] > 0.1)
                  {
                     if(this.player && this.poison <= 0)
                     {
                        World.w.gui.infoText("poison");
                     }
                     this.poison += param3.weap.dopDamage;
                  }
                  if(param3.weap.dopEffect == "cut" && this.vulner[D_BLEED] > 0.1 && !this.mech)
                  {
                     if(this.player && this.cut <= 0)
                     {
                        World.w.gui.infoText("cut");
                     }
                     this.cut += param3.weap.dopDamage;
                  }
                  if(param3.weap.dopEffect == "stun")
                  {
                     if(!this.mech && this.opt && !this.opt.robot && Math.random() < param1 / this.maxhp && this.sost == 1)
                     {
                        this.stun = param3.weap.dopDamage;
                        if(this.player && this.stun <= 0)
                        {
                           World.w.gui.infoText("stun");
                        }
                        if(this.stun > 1)
                        {
                           _loc7_ = Res.guiText("stun");
                        }
                     }
                  }
               }
               if(param3.weap.ammoFire)
               {
                  this.addEffect("burning",param3.weap.ammoFire);
                  _loc7_ = Res.txt("e","burning");
               }
            }
            if(Boolean(param3) && Boolean(param3.owner) && param3.owner.relat > 0)
            {
               param3.owner.damage(param1 * param3.owner.relat,D_INSIDE);
            }
            if(param2 == D_INSIDE && param1 < 5)
            {
               _loc6_ = false;
            }
            if(this.blood > 0 && (param2 == D_BUL || param2 == D_BLADE || param2 == D_PHIS || param2 == D_BLEED || param2 == D_FANG))
            {
               if(this.bloodEmit == null)
               {
                  if(this.blood == 1)
                  {
                     this.bloodEmit = Emitter.arr["blood"];
                  }
                  if(this.blood == 2)
                  {
                     this.bloodEmit = Emitter.arr["gblood"];
                  }
                  if(this.blood == 3)
                  {
                     this.bloodEmit = Emitter.arr["pblood"];
                  }
               }
               if(!(this.player && World.w.alicorn))
               {
                  if(param3)
                  {
                     this.bloodEmit.cast(loc,param3.X,param3.Y,{
                        "dx":param3.dx / param3.vel * 5,
                        "dy":param3.dy / param3.vel * 5,
                        "kol":Math.floor(Math.random() * 5 + param1 / 5)
                     });
                  }
                  else
                  {
                     this.bloodEmit.cast(loc,X,Y - scY / 2,{"kol":Math.floor(param1 / 3)});
                  }
                  if(this.blood == 1 && param2 != D_BLEED && massa > 0.2)
                  {
                     _loc12_ = Math.random();
                     if(param2 == D_BLADE)
                     {
                        _loc12_ *= _loc12_;
                     }
                     if(_loc5_ > 0)
                     {
                        _loc12_ *= 0.3;
                     }
                     if(param1 / 1000 > _loc12_)
                     {
                        _loc13_ = 1;
                        if(Boolean(param3) && param3.dx < 0)
                        {
                           _loc13_ = -1;
                        }
                        if(param3 == null && Math.random() < 0.5)
                        {
                           _loc13_ = -1;
                        }
                        Emitter.emit("bloodexpl" + Math.floor(Math.random() * 3 + 1),loc,X + 80 * _loc13_ + (Math.random() - 0.5) * scX * 0.5,Y - Math.random() * scY * 0.5 - 40,{"mirr":(_loc13_ < 0 ? 1 : 0)});
                     }
                  }
               }
            }
            if(this.mat == 10 && Boolean(param3))
            {
               Emitter.emit("pole2",loc,param3.X,param3.Y);
            }
            if(_loc6_)
            {
               _loc14_ = 1;
               _loc15_ = X;
               _loc16_ = Y - scY / 2;
               if(param3)
               {
                  _loc15_ = param3.X;
                  _loc16_ = param3.Y;
               }
               if(this.player || _loc5_ >= 2)
               {
                  _loc14_ = 2;
               }
               if(param4)
               {
                  _loc14_ = 3;
               }
               if(this.player && param4 && param2 == D_PINK)
               {
                  _loc14_ = 11;
               }
               if(World.w.showHit == 1 || param4)
               {
                  this.visDamDY -= 15;
                  this.numbEmit.cast(loc,_loc15_,_loc16_ + this.visDamDY,{
                     "txt":Math.round(param1).toString(),
                     "frame":_loc14_,
                     "rx":40,
                     "scale":(_loc5_ == 1 || _loc5_ == 3 ? 1.6 : 1)
                  });
               }
               else if(World.w.showHit == 2)
               {
                  this.hitSumm += param1;
                  if(this.hitPart == null)
                  {
                     this.hitPart = this.numbEmit.cast(loc,_loc15_,_loc16_ + this.visDamDY,{
                        "txt":Math.round(param1).toString(),
                        "frame":_loc14_,
                        "rx":40,
                        "scale":(_loc5_ == 1 || _loc5_ == 3 ? 1.6 : 1)
                     });
                  }
                  else
                  {
                     if(_loc5_ == 1 || _loc5_ == 3)
                     {
                        this.hitPart.vis.scaleX = this.hitPart.vis.scaleY = 1.6 / World.w.cam.scaleV;
                     }
                     this.hitPart.vis.numb.text = Math.round(this.hitSumm);
                     this.hitPart.liv = 60;
                  }
                  this.t_hitPart = 10;
               }
            }
            if(this.hp > 0 && !this.player && this.isrnd())
            {
               this.replic("dam");
            }
         }
         else if(World.w.showHit == 2)
         {
            this.t_hitPart = 10;
         }
         this.visDetails();
         if(World.w.showHit >= 1 && this.t_mess <= 0)
         {
            if(this.hp > 0 && Boolean(_loc7_))
            {
               this.numbEmit.cast(loc,X,Y - scY / 2,{
                  "txt":_loc7_,
                  "frame":5,
                  "rx":20,
                  "ry":20
               });
               this.t_mess = 45;
            }
         }
         if(!param4)
         {
            this.alarma();
         }
         return param1;
      }
      
      public function damageWall(param1:int = 0) : *
      {
         var _loc2_:* = undefined;
         var _loc3_:Number = Number(NaN);
         var _loc4_:Number = Number(NaN);
         this.t_throw = 0;
         if(this.damWall > 0)
         {
            _loc2_ = Math.sqrt(dx * dx + dy * dy) / this.damWallSpeed * this.damWall;
            this.damage(_loc2_,D_PHIS);
            if(Math.random() < _loc2_ / this.maxhp)
            {
               this.stun = damWallStun;
            }
            if(param1 > 0)
            {
               _loc3_ = X;
               _loc4_ = Y - scY / 2;
               if(param1 == 1)
               {
                  _loc3_ = X + scX / 2;
               }
               if(param1 == 2)
               {
                  _loc3_ = X - scX / 2;
               }
               if(param1 == 3)
               {
                  _loc4_ = Y;
               }
               if(param1 == 4)
               {
                  _loc4_ = Y - scY;
               }
               Emitter.emit("bum",loc,_loc3_,_loc4_);
               Snd.ps("hit_flesh",X,Y);
            }
         }
      }
      
      public function heal(param1:Number, param2:int = 0, param3:Boolean = true) : *
      {
         if(this.hp == this.maxhp)
         {
            return;
         }
         if(param1 > this.maxhp - this.hp)
         {
            param1 = this.maxhp - this.hp;
            this.hp = this.maxhp;
         }
         else
         {
            this.hp += param1;
         }
         this.visDetails();
         if(World.w.showHit >= 1)
         {
            if((this.sost == 1 || this.sost == 2) && this.showNumbs && param1 > 0.5)
            {
               this.numbEmit.cast(loc,X,Y - scY / 2,{
                  "txt":"+" + Math.round(param1),
                  "frame":4,
                  "rx":20,
                  "ry":20
               });
            }
         }
      }
      
      public function dopTest(param1:Bullet) : Boolean
      {
         return true;
      }
      
      override public function udarBullet(param1:Bullet, param2:int = 0) : int
      {
         var _loc3_:Number = Number(NaN);
         var _loc4_:* = undefined;
         _loc3_ = param1.accuracy();
         if((param1.miss <= 0 || Math.random() > param1.miss) && (this.dexter <= 0 || param1.precision <= 0 && param1.tipBullet == 0 || param1.tipBullet == 0 && Math.random() < _loc3_ / (this.dexter + this.dexterPlus + 0.05) || param1.tipBullet == 1 && this.dodge < 1 && (this.dodge <= 0 || Math.random() > this.dodge)))
         {
            _loc4_ = 0;
            if(this.transp && (this.vulner[param1.tipDamage] <= 0 || this.invulner))
            {
               return -1;
            }
            if(param1.damage > 0)
            {
               if(this.retDamage && param1.retDam && Boolean(param1.owner))
               {
                  param1.owner.udarUnit(this);
               }
               _loc4_ = param1.damage * (Math.random() * 0.6 + 0.7);
               if(World.w.testDam)
               {
                  _loc4_ = param1.damage;
               }
               _loc4_ = this.damage(_loc4_,param1.tipDamage,param1);
               this.otbros(param1);
               if(Boolean(param1.owner) && param1.owner.fraction != 0)
               {
                  this.priorUnit = param1.owner;
               }
               if(!this.invulner && _loc4_ <= 0 || this.mat == 1)
               {
                  return 1;
               }
               if(this.mat == 12)
               {
                  return 12;
               }
               return 10;
            }
            return 0;
         }
         if(World.w.showHit == 1 || World.w.showHit == 2 && this.t_hitPart == 0)
         {
            this.visDamDY -= 15;
            this.t_hitPart = 10;
            if(this.sost < 3 && this.isVis && !this.invulner && param1.flame == 0)
            {
               this.numbEmit.cast(loc,X,Y - scY / 2 + this.visDamDY,{
                  "txt":txtMiss,
                  "frame":10,
                  "rx":40,
                  "alpha":0.5
               });
            }
         }
         return -1;
      }
      
      public function udarUnit(param1:Unit, param2:Number = 1) : Boolean
      {
         var _loc3_:* = undefined;
         var _loc4_:Number = Number(NaN);
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         if(this.neujaz > 0)
         {
            return false;
         }
         this.neujaz = this.neujazMax;
         if(this.dodge - param1.undodge > 0 && this.isrnd(this.dodge - param1.undodge))
         {
            if(World.w.showHit >= 1)
            {
               this.numbEmit.cast(loc,X,Y - scY / 2,{
                  "txt":txtMiss,
                  "frame":10,
                  "rx":20,
                  "ry":20,
                  "alpha":0.5
               });
            }
            return false;
         }
         _loc3_ = Math.random() * 0.4 + 0.8;
         if(param1.collisionTip == 1)
         {
            _loc5_ = (param1.dx * param1.massa + dx * massa) / (param1.massa + massa);
            _loc6_ = (param1.dy * param1.massa + dy * massa) / (param1.massa + massa);
            dx = (-dx + _loc5_) * this.knocked + _loc5_;
            dy = (-dy + _loc6_) * this.knocked + _loc6_;
            param1.dx = (-param1.dx + _loc5_) * param1.knocked + _loc5_;
            param1.dy = (-param1.dy + _loc6_) * param1.knocked + _loc6_;
         }
         if(Boolean(param1.currentWeapon) && param1.currentWeapon.tip == 1)
         {
            this.damage((param1.currentWeapon.damage * 0.5 + param1.dam) * _loc3_ * param2,param1.currentWeapon.tipDamage);
         }
         else
         {
            this.damage(param1.dam * _loc3_ * param2,param1.tipDamage);
         }
         _loc4_ = param1.dam * _loc3_ * param2 / 20;
         if(_loc4_ < 0.5)
         {
            _loc4_ = 0.5;
         }
         if(_loc4_ > 3)
         {
            _loc4_ = 3;
         }
         if(param1.tipDamage == Unit.D_SPARK)
         {
            Emitter.emit("moln",loc,X,Y - scY / 2,{
               "celx":param1.X,
               "cely":param1.Y - param1.scY / 2
            });
            Snd.ps("electro",X,Y);
         }
         else if(param1.tipDamage == Unit.D_ACID)
         {
            Emitter.emit("buma",loc,(X + param1.X) / 2,(Y - scY / 2 + param1.Y - param1.scY / 2) / 2,{"scale":_loc4_});
            Snd.ps("acid",X,Y);
         }
         else if(param1.tipDamage == Unit.D_NECRO)
         {
            Emitter.emit("bumn",loc,(X + param1.X) / 2,(Y - scY / 2 + param1.Y - param1.scY / 2) / 2,{"scale":_loc4_});
            Snd.ps("hit_necr",X,Y);
         }
         else if(param1.tipDamage == Unit.D_FANG)
         {
            Emitter.emit("bum",loc,(X + param1.X) / 2,(Y - scY / 2 + param1.Y - param1.scY / 2) / 2,{"scale":_loc4_});
            Snd.ps("fang_hit",X,Y);
         }
         else
         {
            Emitter.emit("bum",loc,(X + param1.X) / 2,(Y - scY / 2 + param1.Y - param1.scY / 2) / 2,{"scale":_loc4_});
            Snd.ps("hit_flesh",X,Y);
         }
         this.priorUnit = param1;
         return true;
      }
      
      public function udarBox(param1:Box) : int
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         if(this.neujaz > 0 || this.noBox || param1.loc != loc)
         {
            return 0;
         }
         if(param1.molnDam > 0)
         {
            this.damage(param1.molnDam,D_SPARK);
            return 1;
         }
         this.neujaz = this.neujazMax;
         if(!this.fixed)
         {
            _loc2_ = (param1.dx * param1.massa + dx * massa) / (param1.massa + massa);
            _loc3_ = (param1.dy * param1.massa + dy * massa) / (param1.massa + massa);
            dx = (-dx + _loc2_) * this.knocked + _loc2_;
            dy = (-dy + _loc3_) * this.knocked + _loc3_;
            param1.dx = (-param1.dx + _loc2_) * 0.25 + _loc2_;
            param1.dy = (-param1.dy + _loc3_) * 0.25 + _loc3_;
         }
         else
         {
            param1.dx *= 0.5;
            param1.dy *= 0.5;
         }
         this.damage(param1.massa * (param1.vel2 - 50) * World.boxDamage,D_PHIS);
         this.priorUnit = null;
         return 2;
      }
      
      public function otbros(param1:Bullet) : *
      {
         var _loc2_:* = undefined;
         if(this.invulner)
         {
            return;
         }
         _loc2_ = Math.random() * 0.4 + 0.8;
         _loc2_ *= this.knocked / massa;
         if(_loc2_ > 3)
         {
            _loc2_ = 3;
         }
         dx += param1.knockx * param1.otbros * _loc2_;
         dy += param1.knocky * param1.otbros * _loc2_;
         if(param1.explRadius > 0)
         {
         }
      }
      
      public function alarma(param1:Number = -1, param2:Number = -1) : *
      {
         this.oduplenie = 0;
         if(param1 > 0 && param2 > 0 && this.celUnit == null)
         {
            this.setCel(null,param1,param2);
         }
      }
      
      public function budilo(param1:Number = 500) : *
      {
         var _loc2_:Unit = null;
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         this.makeNoise(this.noiseRun * 1.2);
         for each(_loc2_ in loc.units)
         {
            if(_loc2_ && _loc2_ != this && _loc2_.fraction == this.fraction && _loc2_.sost == 1 && !_loc2_.unres)
            {
               _loc3_ = _loc2_.X - X;
               _loc4_ = _loc2_.Y - Y;
               if(this.opt && this.opt.robot && Boolean(_loc2_.opt) && Boolean(_loc2_.opt.robot))
               {
                  if(_loc3_ * _loc3_ + _loc4_ * _loc4_ < param1 * param1)
                  {
                     _loc2_.alarma(this.celX,this.celY);
                  }
               }
               else if(_loc3_ * _loc3_ + _loc4_ * _loc4_ < param1 * param1 * _loc2_.ear * _loc2_.ear)
               {
                  _loc2_.alarma(X + (Math.random() - 0.5) * 250,Y + (Math.random() - 0.5) * 250);
               }
            }
         }
      }
      
      public function hack(param1:int = 0) : *
      {
      }
      
      override public function die(param1:int = 0) : *
      {
         if(LootGen.lootEditorBridge != null)
         {
            try
            {
               LootGen.lootEditorBridge.capture(this);
            }
            catch(lootEditorCaptureError:*)
            {
            }
         }
         if(this.hpbar)
         {
            this.hpbar.visible = false;
         }
         if(this.boss)
         {
            World.w.gui.hpBarBoss();
            if(this.sndMusic)
            {
               Snd.combatMusic(this.sndMusic,this.sndMusicPrior,90);
            }
         }
         if(param1 == 0 && this.sost == 1 && Boolean(this.sndDie))
         {
            this.sound(this.sndDie);
         }
         if(this.noDestr)
         {
            this.sost = 3;
         }
         else if(param1 > 0)
         {
            this.isFly = false;
            this.initBurn(param1);
            this.dexter = 100;
            this.fraction = 0;
            this.throu = false;
            this.sost = 3;
         }
         else if(this.trup && this.hp > -this.maxhp * 2)
         {
            this.replic("die");
            this.isFly = false;
            scX = this.sitX;
            scY = this.sitY;
            X1 = X - scX / 2;
            X2 = X + scX / 2;
            Y1 = Y - scY;
            this.fraction = 0;
            this.throu = false;
            this.porog = 0;
            this.sost = 3;
         }
         else if(this.trup && this.blood > 0)
         {
            if(this.burn == null)
            {
               this.sound("trup");
            }
            this.initBurn(4 + this.blood);
            this.isFly = false;
            this.fraction = 0;
            this.throu = false;
            this.porog = 0;
            this.sost = 3;
         }
         else if(this.burn == null)
         {
            if(this.trup && this.blood > 0)
            {
               this.sound("trup");
            }
            this.expl();
            this.exterminate();
         }
         this.shithp = 0;
         this.walk = 0;
         this.elast = 0;
         this.isLaz = 0;
         this.stun = 0;
         this.transT = true;
         this.sndRunOn = false;
         this.plaKap = false;
         if(!this.doop && World.w.t_battle > 30)
         {
            World.w.t_battle = 30;
         }
         if(!this.lootIsDrop && (!this.isRes || this.sost == 4 || Boolean(this.burn)))
         {
            this.lootIsDrop = true;
            if(this.mother)
            {
               --this.mother.kolChild;
            }
            if(this.hero > 0)
            {
               World.w.gui.infoText("killHero",nazv);
            }
            this.runScript();
            this.dropLoot();
            if(LootGen.lootEditorBridge != null)
            {
               try
               {
                  LootGen.lootEditorBridge.death(this);
               }
               catch(lootEditorDeathError:*)
               {
               }
            }
            this.incStat();
            if(this.xp > 0)
            {
               loc.takeXP(this.xp,X,Y,true);
               this.xp = 0;
            }
            if(loc.prob)
            {
               loc.prob.check();
            }
            if(Boolean(this.opt) && Boolean(this.opt.hbonus))
            {
               loc.createHealBonus(X,Y - scY / 2);
            }
         }
      }
      
      public function exterminate() : *
      {
         radioactiv = 0;
         levitPoss = false;
         if(this.sost != 4)
         {
            loc.remObj(this);
         }
         this.sost = 4;
         this.disabled = true;
      }
      
      public function expl() : *
      {
         if(this.blood)
         {
            if(this.bloodEmit == null)
            {
               if(this.blood == 1)
               {
                  this.bloodEmit = Emitter.arr["blood"];
               }
               if(this.blood == 2)
               {
                  this.bloodEmit = Emitter.arr["gblood"];
               }
               if(this.blood == 3)
               {
                  this.bloodEmit = Emitter.arr["pblood"];
               }
            }
            this.bloodEmit.cast(loc,X,Y,{
               "kol":massa * 50,
               "rx":scX / 2,
               "ry":scY / 2
            });
         }
      }
      
      public function dropLoot() : *
      {
         if(inter)
         {
            inter.loot();
         }
         if(this.hero > 0 && this.opt.robot != true && this.isrnd(0.75))
         {
            LootGen.lootId(loc,X,Y - scY / 2,"essence");
         }
         if(Boolean(World.w.pers) && World.w.pers.dropTre > 0 && this.xp > 0)
         {
            if(Math.random() < World.w.pers.dropTre * this.xp / 4000)
            {
               LootGen.lootId(loc,X,Y - scY / 2,"gem" + Math.floor(Math.random() * 3 + 1));
            }
         }
      }
      
      public function initBurn(param1:int) : *
      {
         if(this.burn != null)
         {
            return;
         }
         this.remVisual();
         this.burn = new Desintegr(this,param1);
         this.childObjs = [];
         this.addVisual();
         levitPoss = false;
         this.setVisPos();
      }
      
      public function runScript() : *
      {
         if(this.scrDie)
         {
            this.scrDie.start();
         }
         if(this.questId)
         {
            if(loc.land.itemScripts[this.questId])
            {
               loc.land.itemScripts[this.questId].start();
            }
            World.w.game.incQuests(this.questId);
         }
         if(Boolean(this.wave) && Boolean(loc.prob))
         {
            loc.prob.checkWave(true);
         }
         if(this.dieWeap != null && World.w.game.triggers["look_" + this.dieWeap] > 0 && this.xp > 0)
         {
            World.w.game.incQuests("kill_" + this.dieWeap);
         }
      }
      
      public function incStat(param1:int = 0) : *
      {
         if(World.w.game)
         {
            if(World.w.game.triggers["frag_" + this.id] > 0)
            {
               ++World.w.game.triggers["frag_" + this.id];
            }
            else
            {
               World.w.game.triggers["frag_" + this.id] = 1;
            }
         }
      }
      
      public function isMeet(param1:Unit) : Boolean
      {
         return param1 != null && loc == param1.loc && !param1.disabled && !param1.trigDis && param1.sost != 4 && param1 != this;
      }
      
      public function getTileVisi(param1:Number = 0.3) : Boolean
      {
         return loc.getAbsTile(X,Y - scY / 2).visi > param1;
      }
      
      public function listen(param1:Unit) : Number
      {
         var _loc2_:* = undefined;
         var _loc3_:Number = Number(NaN);
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         _loc2_ = param1.noise * this.ear * loc.earMult;
         if(_loc2_ <= 0)
         {
            return 0;
         }
         if(param1.player)
         {
            _loc3_ = rasst2;
         }
         else
         {
            _loc4_ = param1.X - X;
            _loc5_ = param1.Y - param1.scY / 2 - Y + scY / 2;
            _loc3_ = _loc4_ * _loc4_ + _loc5_ * _loc5_;
         }
         if(_loc2_ * _loc2_ > _loc3_)
         {
            return (1 - _loc3_ / (_loc2_ * _loc2_)) * 4;
         }
         return 0;
      }
      
      public function look(param1:Unit, param2:Boolean = true, param3:Number = 0, param4:Number = 0) : Number
      {
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:Number = Number(NaN);
         var _loc9_:* = undefined;
         var _loc10_:* = undefined;
         var _loc11_:Number = Number(NaN);
         var _loc12_:Number = Number(NaN);
         var _loc13_:* = undefined;
         var _loc14_:* = undefined;
         var _loc15_:Tile = null;
         if(param1 == null || param4 <= 0 && param3 <= 0 && this.vision <= 0)
         {
            return 0;
         }
         _loc5_ = param1.X - this.eyeX;
         _loc6_ = param1.Y - param1.scY * 0.6 - this.eyeY;
         if(this.eyeX == -1000 || this.eyeY == -1000)
         {
            this.eyeX = X;
            this.eyeY = Y - 30;
         }
         _loc7_ = param4;
         if(param4 <= 0)
         {
            _loc7_ = (param1.visibility * param1.stealthMult * loc.visMult + param1.demask) * (param3 ? param3 : this.vision);
         }
         if(this.vKonus == 0 && !param2 && _loc6_ * _loc6_ > _loc5_ * _loc5_ && _loc6_ > 0)
         {
            _loc7_ *= 0.5 + 0.5 * Math.abs(_loc5_ / _loc6_);
         }
         _loc8_ = _loc5_ * _loc5_ + _loc6_ * _loc6_;
         if(_loc8_ > _loc7_ * _loc7_ * 16)
         {
            return 0;
         }
         if(this.vKonus == 0 && !param2 && _loc5_ * storona < 0 && _loc8_ > this.detecting * this.detecting)
         {
            return 0;
         }
         if(this.vKonus > 0)
         {
            _loc11_ = Math.atan2(_loc6_,_loc5_);
            _loc12_ = this.vAngle - _loc11_;
            if(_loc12_ > Math.PI)
            {
               _loc12_ -= Math.PI * 2;
            }
            if(_loc12_ < -Math.PI)
            {
               _loc12_ += Math.PI * 2;
            }
            if(Math.abs(_loc12_) > this.vKonus / 2)
            {
               return 0;
            }
         }
         _loc9_ = Math.floor(Math.max(Math.abs(_loc5_),Math.abs(_loc6_)) / World.maxdelta) + 1;
         _loc10_ = this.mater ? 1 : 4;
         while(_loc10_ < _loc9_)
         {
            _loc13_ = X + scX * 0.25 * storona + _loc5_ * _loc10_ / _loc9_;
            _loc14_ = Y - scY * 0.75 + _loc6_ * _loc10_ / _loc9_;
            _loc15_ = World.w.loc.getTile(Math.floor(_loc13_ / Tile.tileX),Math.floor(_loc14_ / Tile.tileY));
            if(_loc15_.phis == 1 && _loc13_ >= _loc15_.phX1 && _loc13_ <= _loc15_.phX2 && _loc14_ >= _loc15_.phY1 && _loc14_ <= _loc15_.phY2)
            {
               return 0;
            }
            _loc10_++;
         }
         if(_loc8_ < param1.detecting * param1.detecting)
         {
            return 20;
         }
         if(_loc8_ < _loc7_ * _loc7_)
         {
            return 4;
         }
         return _loc7_ * _loc7_ / _loc8_ * 4;
      }
      
      public function findCel(param1:Boolean = false) : Boolean
      {
         var _loc2_:Unit;
         var _loc3_:Number;
         var _loc4_:Number;
         if(rconnectFindTarget != null && !rconnectFinding)
         {
            rconnectFinding = true;
            try
            {
               return Boolean(rconnectFindTarget(this,param1));
            }
            finally
            {
               rconnectFinding = false;
            }
         }
         _loc2_ = null;
         _loc3_ = Number(NaN);
         _loc4_ = Number(NaN);
         if(this.oduplenie > 0)
         {
            return false;
         }
         if(this.priorUnit && this.isMeet(this.priorUnit) && this.priorUnit.fraction != this.fraction && this.priorUnit.sost < 3 && this.priorUnit.hp > -this.priorUnit.maxhp && (!this.priorUnit.doop || Boolean(this.priorUnit.levit)))
         {
            _loc2_ = this.priorUnit;
         }
         else
         {
            if(!(this.isMeet(loc.gg) && !loc.gg.invulner && this.fraction != F_PLAYER))
            {
               return false;
            }
            _loc2_ = loc.gg;
         }
         if(_loc2_.player)
         {
            _loc3_ = this.listen(_loc2_);
            if(_loc3_)
            {
               (_loc2_ as UnitPlayer).observation(_loc3_);
            }
            _loc4_ = this.look(_loc2_,this.overLook || param1);
            if(_loc4_ > 0)
            {
               (_loc2_ as UnitPlayer).observation(_loc4_,this.observ);
               if((_loc2_ as UnitPlayer).obs >= (_loc2_ as UnitPlayer).maxObs)
               {
                  this.setCel(_loc2_);
                  return true;
               }
            }
            else if(_loc3_ > 0)
            {
               if((_loc2_ as UnitPlayer).obs >= (_loc2_ as UnitPlayer).maxObs)
               {
                  this.setCel(null,_loc2_.X + (Math.random() - 0.5) * 200,_loc2_.Y + (Math.random() - 0.5) * 200);
               }
               if(_loc3_ > 1)
               {
                  return true;
               }
            }
         }
         else if(this.look(_loc2_,this.overLook || param1) > 0.5)
         {
            this.setCel(_loc2_);
            return true;
         }
         this.celUnit = null;
         this.priorUnit = null;
         return false;
      }
      
      public function setCel(param1:Unit = null, param2:Number = -10000, param3:Number = -10000) : *
      {
         if(Boolean(param1) && this.isMeet(param1))
         {
            this.celX = param1.X + param1.scX / 4 * param1.storona;
            this.celY = param1.Y - param1.scY / 2;
            this.celUnit = param1;
            if(param1.player)
            {
               World.w.t_battle = World.battleNoOut;
               World.w.cur();
               loc.detecting = true;
               if(Boolean(this.sndMusic) && !loc.postMusic)
               {
                  Snd.combatMusic(this.sndMusic,this.sndMusicPrior,this.boss ? 10000 : 150);
               }
            }
         }
         else if(param2 > -10000 && param3 > -10000)
         {
            this.celX = param2;
            this.celY = param3;
            this.celUnit = null;
         }
         else
         {
            this.celX = X;
            this.celY = Y - scY / 2;
            this.celUnit = null;
         }
         this.celDX = this.celX - X;
         this.celDY = this.celY - Y + scY;
      }
      
      public function findGrenades() : Boolean
      {
         var _loc1_:* = undefined;
         var _loc2_:Number = Number(NaN);
         var _loc3_:Number = Number(NaN);
         _loc1_ = 0;
         while(_loc1_ < 10)
         {
            if(loc.grenades[_loc1_] != null)
            {
               _loc2_ = loc.grenades[_loc1_].X - X;
               _loc3_ = loc.grenades[_loc1_].Y - Y + scY / 2;
               if(_loc2_ * _loc2_ + _loc3_ * _loc3_ < 400 * 400)
               {
                  if(loc.isLine(X,Y - scY * 0.75,loc.grenades[_loc1_].X,loc.grenades[_loc1_].Y))
                  {
                     this.acelX = loc.grenades[_loc1_].X;
                     this.acelY = loc.grenades[_loc1_].Y;
                     return true;
                  }
               }
            }
            _loc1_++;
         }
         return false;
      }
      
      public function findLevit() : *
      {
         var _loc1_:Number = Number(NaN);
         var _loc2_:Number = Number(NaN);
         if(this.isMeet(loc.gg) && Boolean(loc.gg.teleObj))
         {
            _loc1_ = loc.gg.teleObj.X - X;
            if(!this.overLook && _loc1_ * storona < 0)
            {
               return false;
            }
            _loc2_ = loc.gg.teleObj.Y - loc.gg.teleObj.scY / 2 - Y + scY / 2;
            if(_loc1_ * _loc1_ + _loc2_ * _loc2_ < this.vision * this.vision * 1000 * 1000 && loc.isLine(X,Y - scY * 0.75,loc.gg.teleObj.X,loc.gg.teleObj.Y - loc.gg.teleObj.scY / 2))
            {
               return true;
            }
         }
         return false;
      }
      
      override public function command(param1:String, param2:String = null) : *
      {
         super.command(param1,param2);
         if(param1 == "activate")
         {
            this.noAct = false;
            this.disabled = false;
            this.setNull(true);
            this.addVisual();
            Emitter.emit("tele",loc,X,Y - scY / 2,{
               "rx":scX,
               "ry":scY,
               "kol":30
            });
         }
         if(param1 == "fraction")
         {
            this.fraction = int(param2);
            if(this.fraction == F_PLAYER)
            {
               warn = 0;
            }
            else
            {
               warn = 1;
            }
         }
      }
      
      public function replic(param1:String) : *
      {
         var _loc2_:String = null;
         if(this.sost != 1 || this.id_replic == "" || !loc.active)
         {
            return;
         }
         if(param1 == "dam")
         {
            if(this.isrnd(0.05))
            {
               this.t_replic = 0;
            }
         }
         if(param1 == "die")
         {
            if(this.isrnd())
            {
               this.t_replic = 0;
            }
         }
         if(this.t_replic <= 0)
         {
            if(param1 == "attack")
            {
               this.t_replic = 50 + Math.random() * 100;
            }
            else
            {
               this.t_replic = 110 + Math.random() * 150;
            }
            _loc2_ = Res.repText(this.id_replic,param1,this.msex);
            if(_loc2_ != "" && _loc2_ != null)
            {
               Emitter.emit("replic",loc,X,Y - 110,{
                  "txt":_loc2_,
                  "ry":50
               });
            }
         }
      }
      
      protected function isrnd(param1:Number = 0.5) : Boolean
      {
         return Math.random() < param1;
      }
   }
}

