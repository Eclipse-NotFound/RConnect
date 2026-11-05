package fe.unit
{
   import fe.*;
   import fe.loc.CheckPoint;
   import fe.serv.LootGen;
   import flash.display.MovieClip;
   
   public dynamic class Pers
   {
      
      public static var maxSkLvl:int = 20;
      
      public static var maxPostSkLvl:int = 100;
      
      public static var levelSkAdd:int = 5;
      
      public static var postPersLevel:int = 20;
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectIntent:Function = null;
      
      public var gg:UnitPlayer;
      
      public var persName:String = "LP";
      
      public var skills:Array;
      
      public var skill_ids:Array;
      
      public var perks:Array;
      
      public var addictions:Array;
      
      public var xpCur:int = 0;
      
      public var xpPrev:int = 0;
      
      public var xpNext:int = 5000;
      
      public var xpDelta:int = 5000;
      
      public var xpVer:int = 0;
      
      public var xpCurVer:int = 1;
      
      public var level:int = 1;
      
      public var skillPoint:int = 0;
      
      public var dopPoint:int = 0;
      
      public var perkPoint:int = 0;
      
      public var perkPointExtra:int = 0;
      
      public var xpCPadd:int = 300;
      
      public var rep:int = 0;
      
      internal var rep1:int = 10;
      
      internal var rep2:int = 20;
      
      internal var rep3:int = 35;
      
      internal var rep4:int = 50;
      
      public var repGood:int = 70;
      
      public var owlhp:Number = 0;
      
      public var owlhpProc:Number = 1;
      
      public var hardcore:Boolean = false;
      
      public var dead:Boolean = false;
      
      public var rndpump:Boolean = false;
      
      public var begHP:int = 70;
      
      public var lvlHP:int = 15;
      
      public var organMult:Number = 1;
      
      public var dieDamage:Number = 0.25;
      
      public var critHeal:Number = 0.2;
      
      public var teleMana:Number = 1;
      
      public var difCapsMult:Number = 1;
      
      public var priceHP:Number = 0.5;
      
      public var priceBlood:Number = 0.5;
      
      public var priceRad:Number = 1;
      
      public var priceMana:Number = 1;
      
      public var priceOrgan:Number = 0.5;
      
      public var priceCut:Number = 4;
      
      public var pricePoison:Number = 4;
      
      public var priceRepArmor:Number = 0.5;
      
      public var headHP:Number;
      
      public var torsHP:Number;
      
      public var legsHP:Number;
      
      public var bloodHP:Number;
      
      public var headSt:int = 0;
      
      public var torsSt:int = 0;
      
      public var legsSt:int = 0;
      
      public var bloodSt:int = 0;
      
      public var headMin:Number = 0;
      
      public var torsMin:Number = 0;
      
      public var legsMin:Number = 0;
      
      public var bloodMin:Number = 0;
      
      internal var xml_head:XML;
      
      internal var xml_tors:XML;
      
      internal var xml_legs:XML;
      
      internal var xml_blood:XML;
      
      internal var xml_mana:XML;
      
      public var manaHP:Number;
      
      public var manaSt:int = 0;
      
      public var manaMin:Number = 0;
      
      public var manahpMult:Number = 0.02;
      
      public var manaCPres:Number = 50;
      
      public var manaHPRes:Number = 0.1;
      
      public var inMaxHP:Number = 200;
      
      public var inMaxMana:Number = 400;
      
      public var lvlOrganHp:Number = 40;
      
      public var h2oPlav:Number = 1;
      
      public var stamRun:Number = 1;
      
      public var stamRes:Number = 2;
      
      public var stamDash:* = 40;
      
      public var stamJump:* = 20;
      
      public var weaponSkills:Array;
      
      public var meleeR:Number = 100;
      
      public var meleeS:Number = 40;
      
      public var meleeRun:Number = 10;
      
      public var meleeSpdMult:Number = 1;
      
      public var meleeDamMult:Number = 1;
      
      public var gunsDamMult:Number = 1;
      
      public var bigGunsSlow:Number = 1;
      
      public var drotMult:Number = 1;
      
      public var reloadMult:Number = 1;
      
      public var runPenalty:Number = 0.5;
      
      public var jumpPenalty:Number = 0.3;
      
      public var backPenalty:Number = 0.4;
      
      public var stayBonus:Number = 0.3;
      
      public var recoilMult:Number = 1;
      
      public var desintegr:Number = 0;
      
      public var recyc:Number = 0;
      
      public var remine:int = 0;
      
      public var visiTrap:Number;
      
      public var grenader:int = 0;
      
      public var explRadMult:Number = 1;
      
      public var sapper:Number = 1;
      
      public var autoExpl:Number = 1;
      
      public var teleManaMult:Number = 0.04;
      
      public var telePorog:Number = 0;
      
      public var maxTeleMassa:Number = 1;
      
      public var teleMult:Number = 1;
      
      public var levitDMana:Number = 0;
      
      public var levitDManaUp:Number = 0;
      
      public var allDManaMult:Number = 1;
      
      public var recManaMin:Number = 0;
      
      public var recMana:Number = 0.012;
      
      public var telemaster:int = 0;
      
      public var teleDist:int = 360000;
      
      public var throwForce:Number = 0;
      
      public var throwDmagic:Number = 200;
      
      public var throwDmanaMult:Number = 0.05;
      
      public var unitLevitMult:Number = 1;
      
      public var teleEnemy:int = 60;
      
      public var telePower:Number = 1;
      
      public var repairMult:Number = 0.25;
      
      public var jammedMult:Number = 1;
      
      public var maxArmorLvl:int = 0;
      
      public var barahlo:int = 0;
      
      public var repair:int = 0;
      
      public var armorVulner:Number = 1;
      
      public var medic:int = 0;
      
      public var healMult:Number = 1;
      
      public var metaMult:Number = 1;
      
      public var himLevel:int = 1;
      
      public var himTimeMult:Number = 1;
      
      public var himBadMult:Number = 1;
      
      public var himBadDif:Number = 1;
      
      public var possLockPick:int = 0;
      
      public var lockPick:int = 0;
      
      public var lockPickTime:int = 30;
      
      public var unlockMaster:int = 0;
      
      public var capsMult:Number = 1;
      
      public var bitsMult:Number = 1;
      
      public var lockAtt:Number = 1;
      
      public var pinBreak:Number = 1;
      
      public var upChance:int = 0;
      
      public var freel:int = 0;
      
      public var hacker:int = 0;
      
      public var hackerMaster:int = 0;
      
      public var hackAtt:int = 3;
      
      public var satsMult:Number = 1;
      
      public var security:int = 0;
      
      public var visiMult:Number = 1;
      
      public var signal:int = 0;
      
      public var noiseDoorOpen:int = 300;
      
      public var sneakLurk:Number = 5;
      
      public var barterMult:Number = 1;
      
      public var barterLvl:int = 0;
      
      public var limitBuys:Number = 1;
      
      public var eco:int = 0;
      
      public var healManaMult:Number = 1;
      
      public var warlockDManaMult:Number = 1;
      
      public var potmaster:int = 0;
      
      public var radChild:Number = 0;
      
      public var maxOd:int = 75;
      
      public var hpM:int;
      
      public var punchDamMult:Number = 1;
      
      public var kickDestroy:Number = 30;
      
      public var damPony:Number = 1;
      
      public var damZombie:Number = 1;
      
      public var damRobot:Number = 1;
      
      public var damInsect:Number = 1;
      
      public var damMonster:Number = 1;
      
      public var damAlicorn:Number = 1;
      
      public var isDJ:int = 0;
      
      public var allSpeedMult:Number = 1;
      
      public var runSpeedMult:Number = 1;
      
      public var ableFly:int = 0;
      
      public var speedPlavMult:Number = 1;
      
      public var speedShtr:int = 0;
      
      public var maxSpeed:Number = 100;
      
      public var accelMult:Number = 1;
      
      public var jumpMult:Number = 1;
      
      public var shtrManaRes:Number = 1;
      
      public var allPrecMult:Number = 1;
      
      public var mazilAdd:Number = 0;
      
      public var allDamMult:Number = 1;
      
      public var dexterNoArmor:Number = 0.25;
      
      public var regenFew:Number = 0;
      
      public var regenMax:Number = 0;
      
      public var neujazMax:int = 30;
      
      public var bonusHeal:Number = 0;
      
      public var bonusHealMult:Number = 1;
      
      public var goodHp:int = 1000;
      
      public var socks:Boolean = false;
      
      public var potShad:int = 0;
      
      public var infravis:int = 0;
      
      public var pipEmpVulner:Number = 3;
      
      public var dropTre:Number = 0;
      
      public var sitDexterPlus:Number = 0.3;
      
      public var lurkDexterPlus:Number = 2;
      
      public var lastCh:Number = 0;
      
      public var modMetal:Number = 0;
      
      public var modAnalis:int = 0;
      
      public var modTarget:Number = 0;
      
      public var reanimHp:Number = 0;
      
      public var currentCP:CheckPoint;
      
      public var currentCPCode:String;
      
      public var prevCPCode:String;
      
      public var currentPet:String;
      
      public var organMultPot:Number = 1;
      
      public var spellsPoss:int = 1;
      
      public var spellsDamMult:Number = 1;
      
      public var spellDown:Number = 1;
      
      public var portDown:int = 300;
      
      public var portPoss:int = 0;
      
      public var portTime:int = 25;
      
      public var portMagic:Number = 950;
      
      public var portMana:Number = 25;
      
      public var petHP:Number = 50;
      
      public var petDam:Number = 2;
      
      public var petSkin:Number = 0;
      
      public var petVulner:Number = 1;
      
      public var petRes:int = 30;
      
      public var owlHP:Number = 200;
      
      public var owlDam:Number = 3;
      
      public var owlSkin:Number = 5;
      
      public var owlVulner:Number = 1;
      
      public var moonHP:Number = 70;
      
      public var moonDam:Number = 15;
      
      public var alicornHeal:Number = 2;
      
      public var alicornManaHeal:Number = 0.1;
      
      public var alicornPortMana:Number = 500;
      
      public var alicornShitHP:Number = 2000;
      
      public var alicornRunMana:Number = 2;
      
      public var alicornFlyMult:Number = 1;
      
      public var alicornSkin:Number = 5;
      
      public var alicornDexter:Number = 0;
      
      public var alicornVulner:Number = 0.7;
      
      public var maxmW:int;
      
      public var maxmM:int;
      
      public var maxm1:Number;
      
      public var maxm2:Number;
      
      public var maxm3:Number;
      
      public var ad1:int = 100;
      
      public var ad2:int = 250;
      
      public var ad3:int = 500;
      
      public var admax:int = 750;
      
      public var factor:Array;
      
      public var postSkTab:Array;
      
      public function Pers(param1:Object = null, param2:Object = null)
      {
         var sk:* = undefined;
         var param:* = undefined;
         var ad:* = undefined;
         var pid:* = undefined;
         var loadObj:Object = param1;
         var opt:Object = param2;
         this.weaponSkills = [1,1,1,1,1,1,1,1];
         this.postSkTab = [5,11,18,26,35,45,56,68,82,100];
         super();
         this.skill_ids = new Array();
         this.skills = new Array();
         this.addictions = new Array();
         var ndif:int = 2;
         ndif = World.w.game.globalDif;
         for each(sk in AllData.d.skill)
         {
            this.skill_ids.push({
               "id":sk.@id,
               "sort":sk.@sort,
               "post":sk.@post
            });
            if(loadObj == null || loadObj.skills[sk.@id] == null)
            {
               this.skills[sk.@id] = 0;
            }
            else
            {
               this.skills[sk.@id] = loadObj.skills[sk.@id];
            }
         }
         this.setGlobalDif(ndif);
         this.skill_ids.sortOn("sort",Array.NUMERIC);
         this.headHP = this.inMaxHP;
         this.torsHP = this.inMaxHP;
         this.legsHP = this.inMaxHP;
         this.bloodHP = this.inMaxHP;
         this.manaHP = this.inMaxMana;
         if(loadObj)
         {
            if(loadObj.dead)
            {
               this.dead = true;
            }
            this.skillPoint = loadObj.skillPoint;
            this.perkPoint = loadObj.perkPoint;
            if(loadObj.perkPointExtra > 0)
            {
               this.perkPointExtra = loadObj.perkPointExtra;
            }
            this.level = loadObj.level;
            if(loadObj.xpDelta != null)
            {
               this.xpDelta = loadObj.xpDelta;
            }
            if(loadObj.levelSkAdd != null)
            {
               levelSkAdd = loadObj.levelSkAdd;
            }
            if(loadObj.xp)
            {
               this.xpCur = loadObj.xp;
            }
            else
            {
               this.setForcLevel(Math.floor(this.level / 5) + 1);
               this.xpVer = this.xpCurVer;
            }
            if(loadObj.xpVer)
            {
               this.xpVer = loadObj.xpVer;
            }
            if(this.xpVer != this.xpCurVer)
            {
               this.recalcXP();
            }
            this.xpPrev = this.xpProgress(this.level - 1);
            this.xpNext = this.xpProgress(this.level);
            if(loadObj.hardcore)
            {
               this.hardcore = true;
            }
            if(loadObj.rndpump)
            {
               this.rndpump = true;
            }
            if(loadObj.cp)
            {
               this.currentCPCode = loadObj.cp;
            }
            if(loadObj.prevcp)
            {
               this.prevCPCode = loadObj.prevcp;
            }
            if(loadObj.hasOwnProperty("headHP"))
            {
               this.headHP = loadObj.headHP * this.inMaxHP;
            }
            if(loadObj.hasOwnProperty("torsHP"))
            {
               this.torsHP = loadObj.torsHP * this.inMaxHP;
            }
            if(loadObj.hasOwnProperty("legsHP"))
            {
               this.legsHP = loadObj.legsHP * this.inMaxHP;
            }
            if(loadObj.hasOwnProperty("bloodHP"))
            {
               this.bloodHP = loadObj.bloodHP * this.inMaxHP;
            }
            if(loadObj.hasOwnProperty("manaHP"))
            {
               this.manaHP = loadObj.manaHP * this.inMaxMana;
            }
            if(loadObj.hasOwnProperty("owlhp"))
            {
               this.owlhpProc = loadObj.owlhp;
            }
            if(this.headHP > this.inMaxHP)
            {
               this.headHP = this.inMaxHP;
            }
            if(this.torsHP > this.inMaxHP)
            {
               this.torsHP = this.inMaxHP;
            }
            if(this.legsHP > this.inMaxHP)
            {
               this.legsHP = this.inMaxHP;
            }
            if(this.bloodHP > this.inMaxHP)
            {
               this.bloodHP = this.inMaxHP;
            }
            if(this.manaHP > this.inMaxMana)
            {
               this.manaHP = this.inMaxMana;
            }
            this.currentPet = loadObj.pet;
            if(loadObj.addictions)
            {
               for(ad in loadObj.addictions)
               {
                  this.addictions[ad] = loadObj.addictions[ad];
               }
            }
            if(loadObj.rep)
            {
               this.rep = loadObj.rep;
            }
            World.w.alicorn = false;
            if(loadObj.alicorn)
            {
               World.w.alicorn = loadObj.alicorn;
            }
         }
         else if(opt)
         {
            if(opt.hardcore)
            {
               this.hardcore = true;
            }
            if(opt.fastxp)
            {
               this.xpDelta = 3000;
            }
            if(opt.rndpump)
            {
               this.rndpump = true;
            }
            if(opt.hardskills)
            {
               levelSkAdd = 3;
            }
            this.xpNext = this.xpDelta;
         }
         this.setAllSt();
         this.perks = new Array();
         if(Boolean(loadObj) && Boolean(loadObj.perks))
         {
            for(pid in loadObj.perks)
            {
               this.perks[pid] = loadObj.perks[pid];
            }
         }
         if(Boolean(loadObj) && Boolean(loadObj.persName))
         {
            this.persName = loadObj.persName;
         }
         if(loadObj == null && Boolean(opt) && Boolean(opt.propusk))
         {
            this.perks["levitation"] = 1;
         }
         this.xml_head = rconnectXmlFind(AllData.d.perk,"id","trauma_head")[0];
         this.xml_tors = rconnectXmlFind(AllData.d.perk,"id","trauma_tors")[0];
         this.xml_legs = rconnectXmlFind(AllData.d.perk,"id","trauma_legs")[0];
         this.xml_blood = rconnectXmlFind(AllData.d.perk,"id","trauma_blood")[0];
         this.xml_mana = rconnectXmlFind(AllData.d.perk,"id","trauma_mana")[0];
         this.factor = new Array();
         for each(param in AllData.d.param)
         {
            if(param.@f > 0 && Boolean(param.@v.length()) && param.@v != "")
            {
               this.factor[param.@v] = new Array();
            }
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
      
      public function save() : Object
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         var _loc1_:Object = new Object();
         _loc1_.skills = new Array();
         _loc1_.perks = new Array();
         _loc1_.addictions = new Array();
         for(_loc2_ in this.skills)
         {
            _loc1_.skills[_loc2_] = this.skills[_loc2_];
         }
         for(_loc3_ in this.perks)
         {
            _loc1_.perks[_loc3_] = this.perks[_loc3_];
         }
         for(_loc4_ in this.addictions)
         {
            _loc1_.addictions[_loc4_] = this.addictions[_loc4_];
         }
         _loc1_.dead = this.dead;
         _loc1_.level = this.level;
         _loc1_.xp = this.xpCur;
         _loc1_.xpVer = this.xpCurVer;
         _loc1_.xpDelta = this.xpDelta;
         _loc1_.levelSkAdd = levelSkAdd;
         _loc1_.skillPoint = this.skillPoint;
         _loc1_.perkPoint = this.perkPoint;
         _loc1_.perkPointExtra = this.perkPointExtra;
         _loc1_.rndpump = this.rndpump;
         _loc1_.hardcore = this.hardcore;
         _loc1_.headHP = this.headHP / this.inMaxHP;
         _loc1_.torsHP = this.torsHP / this.inMaxHP;
         _loc1_.legsHP = this.legsHP / this.inMaxHP;
         _loc1_.bloodHP = this.bloodHP / this.inMaxHP;
         _loc1_.manaHP = this.manaHP / this.inMaxMana;
         _loc1_.persName = this.persName;
         _loc1_.cp = this.currentCPCode;
         _loc1_.prevcp = this.prevCPCode;
         _loc1_.rep = this.rep;
         _loc1_.alicorn = World.w.alicorn;
         _loc1_.pet = this.gg.currentPet;
         this.setRoboowl();
         _loc1_.owlhp = this.owlhpProc;
         return _loc1_;
      }
      
      public function setGlobalDif(param1:int = 2) : *
      {
         if(param1 == 0)
         {
            this.begHP = 200;
            this.lvlHP = 25;
            this.organMult = 0.2;
            this.dieDamage = 0;
            this.critHeal = 0.2;
            this.teleMana = 0;
            this.priceBlood = this.priceOrgan = 0.5;
            this.priceRad = 1;
            this.pricePoison = this.priceCut = 4;
            this.difCapsMult = 1;
            this.himBadDif = 1;
            this.petRes = 20;
         }
         else if(param1 == 1)
         {
            this.begHP = 150;
            this.lvlHP = 25;
            this.organMult = 0.5;
            this.dieDamage = 0;
            this.critHeal = 0.2;
            this.teleMana = 0;
            this.priceBlood = this.priceOrgan = 0.5;
            this.priceRad = 1;
            this.pricePoison = this.priceCut = 4;
            this.difCapsMult = 1;
            this.himBadDif = 1;
            this.petRes = 20;
         }
         else if(param1 == 2)
         {
            this.begHP = 100;
            this.lvlHP = 20;
            this.organMult = 1;
            this.dieDamage = 0.15;
            this.critHeal = 0.2;
            this.teleMana = 0.5;
            this.priceBlood = this.priceOrgan = 0.5;
            this.priceRad = 1;
            this.pricePoison = this.priceCut = 4;
            this.difCapsMult = 1;
            this.himBadDif = 1.3;
            this.petRes = 30;
         }
         else if(param1 == 3)
         {
            this.begHP = 70;
            this.lvlHP = 15;
            this.organMult = 1;
            this.dieDamage = 0.25;
            this.critHeal = 0.1;
            this.teleMana = 1;
            this.priceBlood = this.priceOrgan = 1;
            this.priceRad = 1.5;
            this.pricePoison = this.priceCut = 6;
            this.difCapsMult = 1;
            this.himBadDif = 2;
            this.petRes = 60;
            this.neujazMax = 20;
            this.bonusHealMult = 0.75;
         }
         else if(param1 == 4)
         {
            this.begHP = 40;
            this.lvlHP = 10;
            this.organMult = 1;
            this.dieDamage = 0.35;
            this.critHeal = 0.1;
            this.teleMana = 1;
            this.priceBlood = this.priceOrgan = 1;
            this.priceRad = 1.5;
            this.pricePoison = this.priceCut = 6;
            this.difCapsMult = 0.5;
            this.himBadDif = 2.5;
            this.petRes = 90;
            this.neujazMax = 15;
            this.bonusHealMult = 0.5;
         }
      }
      
      public function defaultParams() : *
      {
         var _loc1_:* = undefined;
         this.gg.maxhp = this.begHP;
         this.gg.critHeal = this.critHeal;
         this.inMaxHP = 200;
         this.inMaxMana = 400;
         this.gg.jumpdy = 12;
         this.gg.djumpdy = 6;
         this.gg.maxdjumpp = 10;
         this.maxOd = 75;
         this.kickDestroy = 30;
         this.stamRes = 2;
         this.recMana = 0.025;
         this.levitDMana = 5;
         this.levitDManaUp = 20;
         this.runSpeedMult = 2;
         this.petHP = 50;
         this.petDam = 2;
         this.petRes = 30;
         this.petSkin = 0;
         this.petVulner = 1;
         this.owlHP = 200;
         this.owlDam = 3;
         this.owlSkin = 5;
         this.owlVulner = 1;
         this.maxmW = 7;
         this.maxmM = 3;
         this.maxm1 = 40;
         this.maxm2 = 1000;
         this.maxm3 = 500;
         this.gg.radX = 1;
         this.gg.dexter = 1;
         this.gg.dodgePlus = 0;
         this.gg.armor = 0;
         this.gg.marmor = 0;
         this.gg.skin = 0;
         this.gg.critCh = 0;
         this.gg.critDamMult = 2;
         this.gg.knocked = 1;
         this.gg.shitArmor = 20;
         this.gg.tormoz = 1;
         this.gg.stealthMult = 1;
         this.gg.allVulnerMult = 1;
         this.gg.precMultCont = 1;
         this.gg.rapidMultCont = 1;
         this.gg.levitOn = 0;
         this.gg.atkPoss = 1;
         this.gg.runForever = 0;
         this.gg.attackForever = 0;
         this.gg.zaput = 0;
         this.gg.activateTrap = 2;
         this.gg.mordaN = 1;
         this.gg.ddyPlav = 1;
         this.gg.relat = 0;
         this.gg.eyeMind = 0;
         this.gg.isFetter = 0;
         this.allSpeedMult = 1;
         this.allPrecMult = 1;
         this.allDamMult = 1;
         this.allDManaMult = 1;
         this.warlockDManaMult = 1;
         this.meleeSpdMult = 1;
         this.meleeDamMult = 1;
         this.gunsDamMult = 1;
         this.spellsDamMult = 1;
         this.visiMult = 1;
         this.h2oPlav = 1;
         this.speedPlavMult = 1;
         this.punchDamMult = 1;
         this.metaMult = 1;
         this.reloadMult = 1;
         this.recoilMult = 1;
         this.healMult = 0.4;
         this.stamRun = 1;
         this.pipEmpVulner = 3;
         this.damPony = 1;
         this.damZombie = 1;
         this.damRobot = 1;
         this.damInsect = 1;
         this.damMonster = 1;
         this.damAlicorn = 1;
         this.manaMin = 0;
         this.recManaMin = 0;
         this.reanimHp = 0;
         this.mazilAdd = 0;
         this.regenFew = this.regenMax = 0;
         this.bonusHeal = 0;
         this.lockPick = this.hacker = 0;
         this.possLockPick = 0;
         this.spellsPoss = 1;
         this.infravis = 0;
         this.lastCh = 0;
         this.freel = 0;
         this.telemaster = 0;
         this.dropTre = 0;
         this.modAnalis = 0;
         this.modTarget = 0;
         this.modMetal = 0;
         this.upChance = 0;
         this.ableFly = 0;
         this.socks = false;
         this.potShad = 0;
         this.alicornRunMana = 5;
         for(_loc1_ in this.gg.vulner)
         {
            this.gg.vulner[_loc1_] = 1;
         }
         this.gg.vulner[Unit.D_EMP] = 0;
         for(_loc1_ in this.weaponSkills)
         {
            this.weaponSkills[_loc1_] = 1;
         }
         for(_loc1_ in this.factor)
         {
            this.factor[_loc1_] = new Array();
         }
      }
      
      public function expa(param1:int, param2:Number = -1, param3:Number = -1) : *
      {
         if(param1 <= 0)
         {
            return;
         }
         this.xpCur += param1;
         if(param2 < 0 || param3 < 0)
         {
            param2 = this.gg.X;
            param3 = this.gg.Y - this.gg.scY;
         }
         if(World.w.testLoot)
         {
            World.w.summxp += param1;
         }
         else
         {
            this.gg.numbEmit.cast(this.gg.loc,param2,param3,{
               "txt":"+" + param1 + "xp",
               "frame":8,
               "rx":20,
               "ry":20,
               "alpha":0.5,
               "scale":1.5
            });
         }
         if(this.xpCur >= this.xpNext)
         {
            this.upLevel();
         }
         World.w.gui.setXp();
      }
      
      public function getSkLevel(param1:int) : int
      {
         if(param1 >= 20)
         {
            return 5;
         }
         if(param1 >= 14)
         {
            return 4;
         }
         if(param1 >= 9)
         {
            return 3;
         }
         if(param1 >= 5)
         {
            return 2;
         }
         if(param1 >= 2)
         {
            return 1;
         }
         return 0;
      }
      
      public function getSkBonus(param1:int) : int
      {
         if(param1 == 20)
         {
            return 5;
         }
         if(param1 == 14)
         {
            return 4;
         }
         if(param1 == 9)
         {
            return 3;
         }
         if(param1 == 5)
         {
            return 2;
         }
         if(param1 == 2)
         {
            return 1;
         }
         return 0;
      }
      
      public function skillIsPost(param1:String) : Boolean
      {
         if(param1 == "attack" || param1 == "defense" || param1 == "knowl")
         {
            return true;
         }
         return false;
      }
      
      public function getPostSkLevel(param1:int) : int
      {
         if(param1 < this.postSkTab[0])
         {
            return 0;
         }
         var _loc2_:* = 0;
         var _loc3_:* = 0;
         while(_loc3_ < this.postSkTab.length)
         {
            if(param1 >= this.postSkTab[_loc3_])
            {
               _loc2_ = _loc3_ + 1;
            }
            _loc3_++;
         }
         return _loc2_;
      }
      
      public function getWeapLevel(param1:int) : int
      {
         if(param1 == 1)
         {
            return this.getSkLevel(this.skills["melee"]);
         }
         if(param1 == 2)
         {
            return this.getSkLevel(this.skills["smallguns"]);
         }
         if(param1 == 3)
         {
            return this.getSkLevel(this.skills["repair"]);
         }
         if(param1 == 4)
         {
            return this.getSkLevel(this.skills["energy"]);
         }
         if(param1 == 5)
         {
            return this.getSkLevel(this.skills["explosives"]);
         }
         if(param1 == 6)
         {
            return this.getSkLevel(this.skills["magic"]);
         }
         if(param1 == 7)
         {
            return this.getSkLevel(this.skills["tele"]);
         }
         return 100;
      }
      
      public function getSkillLevel(param1:String) : int
      {
         if(this.skills[param1] == undefined)
         {
            return 0;
         }
         return this.getSkLevel(this.skills[param1]);
      }
      
      public function setForcLevel(param1:int) : *
      {
         trace("Установлен уровень",param1);
         this.level = param1;
         this.xpPrev = this.xpCur = this.xpProgress(param1 - 1);
         this.xpNext = this.xpProgress(param1);
      }
      
      public function upLevel() : *
      {
         this.xpPrev = this.xpProgress(this.level);
         ++this.level;
         World.w.gui.messText("levelUp"," " + this.level);
         this.xpNext = this.xpProgress(this.level);
         this.addSkillPoint(levelSkAdd,false,false);
         ++this.perkPoint;
         if(this.rndpump)
         {
            this.autoPump();
         }
         if(this.gg.pet)
         {
            this.gg.pet.setLevel(this.level);
         }
         World.w.gui.infoText("perkPoint");
         Snd.ps("levelup");
         this.gg.newPart("gold_spark",25);
      }
      
      public function xpProgress(param1:int) : int
      {
         var _loc2_:Number = 1;
         if(param1 > 10)
         {
            _loc2_ = (param1 - 10) / 30 + 1;
         }
         return Math.round(this.xpDelta * param1 * (param1 + 1) / 2 * _loc2_ * _loc2_ / 1000) * 1000;
      }
      
      public function xpProgress06(param1:int) : int
      {
         return this.xpDelta * param1 * (param1 + 1) / 2;
      }
      
      public function recalcXP() : *
      {
         var _loc1_:int = 0;
         if(this.xpVer == 0)
         {
            _loc1_ = this.xpProgress(this.level - 1) - this.xpProgress06(this.level - 1);
            trace("Формулы расчёта опыта разных версий, разница:",_loc1_);
            this.xpCur += _loc1_;
         }
      }
      
      public function addSkillPoint(param1:int = 1, param2:Boolean = false, param3:Boolean = true) : *
      {
         this.skillPoint += param1;
         if(param1 == 1)
         {
            World.w.gui.infoText("skillPoint");
         }
         else
         {
            World.w.gui.infoText("skillPoints",param1);
         }
         if(param3)
         {
            Snd.ps("skill");
         }
         if(this.rndpump)
         {
            this.autoPump();
         }
      }
      
      public function addSkill(param1:String, param2:int, param3:Boolean = false) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"addSkill",[param1,param2,param3])))
         {
            return;
         }
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         if(param3 && param2 > this.skillPoint)
         {
            param2 = this.skillPoint;
         }
         if(param2 <= 0)
         {
            return;
         }
         var _loc4_:* = this.skills[param1];
         this.skills[param1] += param2;
         var _loc5_:* = this.skills[param1];
         if(!this.skillIsPost(param1))
         {
            _loc6_ = _loc4_ + 1;
            while(_loc6_ <= _loc5_)
            {
               _loc7_ = this.getSkBonus(_loc6_);
               if(_loc7_ > 0)
               {
                  World.w.gui.infoText("skill",Res.txt("e",param1) + "-" + _loc7_);
               }
               _loc6_++;
            }
         }
         else if(param1 == "knowl")
         {
            _loc8_ = this.getPostSkLevel(this.skills[param1]);
            if(_loc8_ > this.perkPointExtra)
            {
               this.perkPoint += _loc8_ - this.perkPointExtra;
               this.perkPointExtra = _loc8_;
               World.w.gui.infoText("perkPoint");
            }
         }
         if(param3)
         {
            this.skillPoint -= param2;
         }
      }
      
      public function upSkill(param1:String) : Boolean
      {
         var _loc2_:* = undefined;
         if(this.skills[param1] < maxSkLvl)
         {
            World.w.gui.infoText("skillUp",Res.txt("e",param1));
            Snd.ps("skill");
            this.addSkill(param1,1);
            this.setParameters();
            World.w.gui.setAll();
            return true;
         }
         _loc2_ = Math.floor(Math.random() * 3);
         if(_loc2_ == 0)
         {
            param1 = "attack";
         }
         else if(_loc2_ == 1)
         {
            param1 = "defense";
         }
         else
         {
            param1 = "knowl";
         }
         if(this.skills[param1] < maxPostSkLvl)
         {
            World.w.gui.infoText("skillUp",Res.txt("e",param1));
            Snd.ps("skill");
            this.addSkill(param1,1);
            this.setParameters();
            World.w.gui.setAll();
            return true;
         }
         World.w.gui.infoText("noSkill");
         return false;
      }
      
      public function setSkill(param1:String, param2:int) : *
      {
         if(param2 < 0)
         {
            param2 = 0;
         }
         if(param2 > maxSkLvl)
         {
            param2 = maxSkLvl;
         }
         if(this.skills[param1])
         {
            this.skills[param1] = param2;
         }
         this.setParameters();
         World.w.gui.setAll();
      }
      
      public function addPerk(param1:String, param2:Boolean = false) : *
      {
         if(rconnectIntent != null && Boolean(rconnectIntent(this,"addPerk",[param1,param2])))
         {
            return;
         }
         var maxlvl:* = undefined;
         var id:String = param1;
         var minus:Boolean = param2;
         maxlvl = rconnectXmlFind(AllData.d.perk,"id",id).@lvl;
         if(maxlvl <= 0)
         {
            maxlvl = 1;
         }
         if(this.perks[id])
         {
            if(this.perks[id] >= maxlvl)
            {
               World.w.gui.infoText("noPerk");
               return;
            }
            ++this.perks[id];
            World.w.gui.infoText("perk",Res.txt("e",id) + "-" + this.perks[id]);
            Snd.ps("skill");
         }
         else
         {
            this.perks[id] = 1;
            World.w.gui.infoText("perk",Res.txt("e",id));
            Snd.ps("skill");
         }
         if(minus)
         {
            --this.perkPoint;
         }
         this.setParameters();
      }
      
      internal function autoPump() : *
      {
         var _loc2_:Array = null;
         var _loc3_:* = undefined;
         var _loc4_:int = 0;
         var _loc5_:XML = null;
         var _loc6_:int = 0;
         var _loc1_:* = 1000;
         while(this.skillPoint > 0 && _loc1_ > 0)
         {
            _loc2_ = new Array();
            for(_loc3_ in this.skills)
            {
               if(this.skills[_loc3_] < maxSkLvl && !this.skillIsPost(_loc3_))
               {
                  _loc2_.push(_loc3_);
               }
            }
            if(_loc2_.length == 0 || this.level >= postPersLevel && Math.random() < 0.2)
            {
               for(_loc3_ in this.skills)
               {
                  if(this.skillIsPost(_loc3_) && this.skills[_loc3_] < maxPostSkLvl)
                  {
                     _loc2_.push(_loc3_);
                  }
               }
               if(_loc2_.length == 0)
               {
                  break;
               }
            }
            _loc3_ = _loc2_[Math.floor(Math.random() * _loc2_.length)];
            _loc4_ = Math.random() < 0.5 ? 2 : 1;
            if(Math.random() < 0.15)
            {
               _loc4_ = 3;
            }
            if(this.skillIsPost(_loc3_))
            {
               _loc4_ = Math.min(this.skillPoint,_loc4_,maxPostSkLvl - this.skills[_loc3_]);
            }
            else
            {
               _loc4_ = Math.min(this.skillPoint,_loc4_,maxSkLvl - this.skills[_loc3_]);
            }
            this.addSkill(_loc3_,_loc4_,true);
            _loc1_--;
         }
         _loc1_ = 100;
         while(this.perkPoint > 0 && _loc1_ > 0)
         {
            _loc2_ = new Array();
            for each(_loc5_ in AllData.d.perk)
            {
               if(_loc5_.@tip == 1)
               {
                  _loc6_ = this.perkPoss(_loc5_.@id,_loc5_);
                  if(_loc6_ == 1)
                  {
                     _loc2_.push(_loc5_.@id);
                  }
               }
            }
            if(_loc2_.length == 0)
            {
               break;
            }
            _loc3_ = _loc2_[Math.floor(Math.random() * _loc2_.length)];
            this.addPerk(_loc3_,true);
            _loc1_--;
         }
      }
      
      public function perkPoss(param1:String, param2:XML = null) : int
      {
         var req:* = undefined;
         var reqlevel:int = 0;
         var nid:String = param1;
         var dp:XML = param2;
         if(dp == null)
         {
            dp = rconnectXmlFind(AllData.d.perk,"id",nid)[0];
         }
         if(dp == null)
         {
            return -1;
         }
         var numb:* = this.perks[nid];
         if(numb == null)
         {
            numb = 0;
         }
         var maxlvl:* = 1;
         if(dp.@lvl.length())
         {
            maxlvl = dp.@lvl;
         }
         if(numb >= maxlvl)
         {
            return -1;
         }
         var ok:int = 1;
         if(dp.req.length())
         {
            for each(req in dp.req)
            {
               reqlevel = 1;
               if(req.@lvl.length())
               {
                  reqlevel = int(req.@lvl);
               }
               if(numb > 0 && Boolean(req.@dlvl.length()))
               {
                  reqlevel += numb * req.@dlvl;
               }
               if(req.@id == "level")
               {
                  if(this.level < reqlevel)
                  {
                     ok = 0;
                  }
               }
               else if(req.@id == "guns")
               {
                  if(this.getSkLevel(this.skills["smallguns"]) < reqlevel && this.getSkLevel(this.skills["energy"]) < reqlevel)
                  {
                     ok = 0;
                  }
               }
               else if(this.getSkLevel(this.skills[req.@id]) < reqlevel)
               {
                  ok = 0;
               }
            }
         }
         return ok;
      }
      
      internal function setSkillParam(param1:XML, param2:int, param3:int = 0) : *
      {
         var _loc4_:* = undefined;
         var _loc5_:Number = Number(NaN);
         var _loc6_:int = 0;
         var _loc7_:Number = Number(NaN);
         for each(_loc4_ in param1.sk)
         {
            _loc7_ = 0;
            if(_loc4_.@dop.length())
            {
               _loc6_ = param3;
            }
            else
            {
               _loc6_ = param2;
            }
            if(_loc4_.@v0.length())
            {
               _loc7_ = Number(_loc4_.@v0);
            }
            else if(_loc4_.@ref == "add" || _loc4_.@tip == "res")
            {
               _loc7_ = 0;
            }
            else if(_loc4_.@ref == "mult")
            {
               _loc7_ = 1;
            }
            if(_loc6_ == 0)
            {
               _loc5_ = _loc7_;
            }
            else if(_loc4_.@vd.length())
            {
               _loc5_ = _loc7_ + _loc6_ * Number(_loc4_.@vd);
            }
            else if(_loc4_.attribute("v" + _loc6_).length())
            {
               _loc5_ = Number(_loc4_.attribute("v" + _loc6_));
            }
            else
            {
               _loc5_ = Number(_loc4_.@v1);
            }
            if(_loc4_.@tip == "weap")
            {
               this.weaponSkills[_loc4_.@id] = _loc5_;
            }
            else if(_loc4_.@tip == "res")
            {
               this.gg.vulner[_loc4_.@id] -= _loc5_;
               this.setFactor(_loc4_.@id,param1.@id,"min",_loc5_,this.gg.vulner[_loc4_.@id]);
            }
            else if(_loc4_.@tip == "m")
            {
               this[_loc4_.@id] += _loc5_;
            }
            else if(this.gg.hasOwnProperty(_loc4_.@id))
            {
               this.setBegFactor(_loc4_.@id,this.gg[_loc4_.@id]);
               if(_loc4_.@ref == "add")
               {
                  this.gg[_loc4_.@id] += _loc5_;
               }
               else if(_loc4_.@ref == "mult")
               {
                  this.gg[_loc4_.@id] *= _loc5_;
               }
               else
               {
                  this.gg[_loc4_.@id] = _loc5_;
               }
               this.setFactor(_loc4_.@id,param1.@id,_loc4_.@ref,_loc5_,this.gg[_loc4_.@id]);
            }
            else if(this.hasOwnProperty(_loc4_.@id))
            {
               this.setBegFactor(_loc4_.@id,this[_loc4_.@id]);
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
               this.setFactor(_loc4_.@id,param1.@id,_loc4_.@ref,_loc5_,this[_loc4_.@id]);
            }
            else if(_loc4_.@ref == "add")
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
      
      internal function setBegFactor(param1:String, param2:*) : *
      {
         if(this.factor[param1] is Array && this.factor[param1].length == 0)
         {
            this.factor[param1].push({
               "id":"beg",
               "res":param2
            });
         }
      }
      
      internal function setFactor(param1:String, param2:String, param3:String, param4:*, param5:*, param6:* = null) : *
      {
         if(param3 == "add" && param4 == 0 || param3 == "mult" && param4 == 1)
         {
            return;
         }
         if(this.factor[param1] is Array)
         {
            this.factor[param1].push({
               "id":param2,
               "ref":param3,
               "val":param4,
               "res":param5,
               "tip":param6
            });
         }
      }
      
      internal function setAllSt() : *
      {
         this.headSt = 4 - Math.ceil(this.headHP / this.inMaxHP * 4);
         this.torsSt = 4 - Math.ceil(this.torsHP / this.inMaxHP * 4);
         this.legsSt = 4 - Math.ceil(this.legsHP / this.inMaxHP * 4);
         this.bloodSt = 4 - Math.ceil(this.bloodHP / this.inMaxHP * 4);
         this.manaSt = 4 - Math.ceil(this.manaHP / this.inMaxMana * 4);
      }
      
      public function setPonpon(param1:MovieClip) : *
      {
         var _loc2_:* = undefined;
         param1.tors.gotoAndStop(this.torsSt + 1);
         param1.head.gotoAndStop(this.headSt + 1);
         param1.legs.gotoAndStop(this.legsSt + 1);
         param1.magic.gotoAndStop(this.manaSt + 1);
         param1.blood.gotoAndStop(this.bloodSt + 1);
         param1.armor.gotoAndStop(1);
         if(this.gg.currentArmor)
         {
            _loc2_ = 4 - Math.ceil(this.gg.currentArmor.hp / this.gg.currentArmor.maxhp * 4);
            param1.armor.gotoAndStop(_loc2_ + 1);
         }
      }
      
      internal function trauma(param1:int, param2:int) : *
      {
         if(param1 > 4)
         {
            param1 = 4;
         }
         if(param2 == 3 && param1 == 4)
         {
            param1 = 3;
         }
         if(param2 == 4)
         {
            if(param1 > 0)
            {
               World.w.gui.infoText("blood" + param1,this.persName);
            }
         }
         else if(param2 == 5)
         {
            if(param1 > 1)
            {
               World.w.gui.infoText("tmana" + param1);
            }
         }
         else if(param1 > 0)
         {
            World.w.gui.infoText("trauma" + param1,this.persName);
         }
      }
      
      public function damage(param1:Number, param2:int, param3:Boolean = false) : *
      {
         var _loc5_:int = 0;
         if(param3)
         {
            param1 = this.dieDamage * this.inMaxHP;
         }
         if(param1 <= 0 || param2 == Unit.D_INSIDE || param2 == Unit.D_BLEED)
         {
            return;
         }
         if(param2 == Unit.D_NECRO)
         {
            param1 *= 0.1;
         }
         param1 *= this.organMult;
         param1 *= this.organMultPot;
         if(this.radChild > 0)
         {
            param1 *= (this.gg.maxhp - this.gg.rad) / this.gg.maxhp;
         }
         var _loc4_:* = Math.random();
         if(_loc4_ < 0.2)
         {
            if(!param3)
            {
               param1 *= 2;
            }
            _loc5_ = 4 - Math.ceil(this.headHP / this.inMaxHP * 4);
            this.headHP -= param1;
            if(this.headHP < this.headMin)
            {
               this.headHP = this.headMin;
            }
            if(this.headHP <= 0)
            {
               this.headHP = 1;
               this.die();
            }
            this.headSt = 4 - Math.ceil(this.headHP / this.inMaxHP * 4);
            if(_loc5_ != this.headSt)
            {
               this.setParameters();
            }
            if(this.headSt > _loc5_)
            {
               this.trauma(this.headSt,1);
            }
         }
         else if(_loc4_ < 0.6 || param2 == Unit.D_POISON || param2 == Unit.D_VENOM)
         {
            _loc5_ = 4 - Math.ceil(this.torsHP / this.inMaxHP * 4);
            this.torsHP -= param1;
            if(this.torsHP < this.torsMin)
            {
               this.torsHP = this.torsMin;
            }
            if(this.torsHP <= 0)
            {
               this.torsHP = 1;
               this.die();
            }
            this.torsSt = 4 - Math.ceil(this.torsHP / this.inMaxHP * 4);
            if(_loc5_ != this.torsSt)
            {
               this.setParameters();
            }
            if(this.torsSt > _loc5_)
            {
               this.trauma(this.torsSt,2);
            }
         }
         else
         {
            _loc5_ = 4 - Math.ceil(this.legsHP / this.inMaxHP * 4);
            this.legsHP -= param1;
            if(this.legsHP < this.legsMin)
            {
               this.legsHP = this.legsMin;
            }
            if(this.legsHP <= 0)
            {
               this.legsHP = 1;
               this.die();
            }
            this.legsSt = 4 - Math.ceil(this.legsHP / this.inMaxHP * 4);
            if(_loc5_ != this.legsSt)
            {
               this.setParameters();
            }
            if(this.legsSt > _loc5_)
            {
               this.trauma(this.legsSt,3);
            }
         }
      }
      
      public function die() : *
      {
         this.gg.poison = 0;
         this.gg.cut = 0;
         World.w.gui.messText("gameover");
         if(this.gg.sost == 1)
         {
            this.gg.die(10);
         }
         else
         {
            this.gg.sost = 3;
         }
      }
      
      public function bloodDamage(param1:Number, param2:int) : *
      {
         var _loc3_:int = 0;
         if(param1 <= 0)
         {
            return;
         }
         param1 *= 3;
         if(param2 == Unit.D_BLEED || param2 == Unit.D_BLADE || param2 == Unit.D_BUL || param2 == Unit.D_FANG)
         {
            param1 *= this.organMult;
            param1 = Math.random() * param1;
            if(param2 == Unit.D_BUL || param2 == Unit.D_FANG)
            {
               param1 *= 0.5;
            }
            _loc3_ = 4 - Math.ceil(this.bloodHP / this.inMaxHP * 4);
            this.bloodHP -= param1;
            if(this.bloodHP < this.bloodMin)
            {
               this.bloodHP = this.bloodMin;
            }
            if(this.bloodHP <= 0)
            {
               this.bloodHP = 1;
               this.die();
            }
            this.bloodSt = 4 - Math.ceil(this.bloodHP / this.inMaxHP * 4);
            if(_loc3_ != this.bloodSt)
            {
               this.setParameters();
            }
            if(this.bloodSt > _loc3_)
            {
               this.trauma(this.bloodSt,4);
            }
         }
      }
      
      public function manaDamage(param1:Number) : *
      {
         if(param1 <= 0)
         {
            return;
         }
         if(this.gg.loc.train)
         {
            return;
         }
         var _loc2_:int = 4 - Math.ceil(this.manaHP / this.inMaxMana * 4);
         this.manaHP -= param1;
         if(this.manaMin > 0 && this.manaHP < 1)
         {
            this.manaHP = 1;
         }
         if(this.manaHP < 0)
         {
            this.manaHP = 0;
         }
         this.manaSt = 4 - Math.ceil(this.manaHP / this.inMaxMana * 4);
         if(_loc2_ != this.manaSt)
         {
            this.setParameters();
         }
         if(this.manaSt > _loc2_)
         {
            this.trauma(this.manaSt,5);
         }
      }
      
      public function heal(param1:Number, param2:int) : *
      {
         var _loc3_:int = 0;
         if(param1 == 0)
         {
            return;
         }
         if(param2 == 0)
         {
            if(this.legsHP < this.headHP && this.legsHP < this.torsHP)
            {
               param2 = 3;
            }
            else if(this.headHP < this.torsHP)
            {
               param2 = 1;
            }
            else
            {
               param2 = 2;
            }
         }
         if(param2 == 1 || param2 == 4)
         {
            _loc3_ = 4 - Math.ceil(this.headHP / this.inMaxHP * 4);
            this.headHP += param1;
            if(this.headHP > this.inMaxHP)
            {
               this.headHP = this.inMaxHP;
            }
            this.headSt = 4 - Math.ceil(this.headHP / this.inMaxHP * 4);
            if(_loc3_ != this.headSt)
            {
               this.setParameters();
            }
         }
         if(param2 == 2 || param2 == 4)
         {
            _loc3_ = 4 - Math.ceil(this.torsHP / this.inMaxHP * 4);
            this.torsHP += param1;
            if(this.torsHP > this.inMaxHP)
            {
               this.torsHP = this.inMaxHP;
            }
            this.torsSt = 4 - Math.ceil(this.torsHP / this.inMaxHP * 4);
            if(_loc3_ != this.torsSt)
            {
               this.setParameters();
            }
         }
         if(param2 == 3 || param2 == 4)
         {
            _loc3_ = 4 - Math.ceil(this.legsHP / this.inMaxHP * 4);
            this.legsHP += param1;
            if(this.legsHP > this.inMaxHP)
            {
               this.legsHP = this.inMaxHP;
            }
            this.legsSt = 4 - Math.ceil(this.legsHP / this.inMaxHP * 4);
            if(_loc3_ != this.legsSt)
            {
               this.setParameters();
            }
         }
         if(param2 == 5)
         {
            _loc3_ = 4 - Math.ceil(this.bloodHP / this.inMaxHP * 4);
            this.bloodHP += param1;
            if(this.bloodHP > this.inMaxHP)
            {
               this.bloodHP = this.inMaxHP;
            }
            this.bloodSt = 4 - Math.ceil(this.bloodHP / this.inMaxHP * 4);
            if(_loc3_ != this.bloodSt)
            {
               this.setParameters();
            }
         }
         if(param2 == 6)
         {
            if(this.manaHP < this.inMaxMana && param1 > 5)
            {
               this.gg.numbEmit.cast(this.gg.loc,this.gg.X,this.gg.Y - this.gg.scY / 2,{
                  "txt":"+" + Math.round(param1),
                  "frame":6,
                  "rx":20,
                  "ry":20
               });
            }
            _loc3_ = 4 - Math.ceil(this.manaHP / this.inMaxMana * 4);
            this.manaHP += param1;
            if(this.manaHP > this.inMaxMana)
            {
               this.manaHP = this.inMaxMana;
            }
            this.manaSt = 4 - Math.ceil(this.manaHP / this.inMaxMana * 4);
            if(_loc3_ != this.manaSt)
            {
               this.setParameters();
            }
            World.w.gui.setMana();
         }
      }
      
      public function healAll() : *
      {
         this.headHP = this.inMaxHP;
         this.torsHP = this.inMaxHP;
         this.legsHP = this.inMaxHP;
         this.bloodHP = this.inMaxHP;
         this.manaHP = this.inMaxMana;
      }
      
      public function checkHP() : *
      {
         if(this.headHP > this.inMaxHP)
         {
            this.headHP = this.inMaxHP;
         }
         if(this.torsHP > this.inMaxHP)
         {
            this.torsHP = this.inMaxHP;
         }
         if(this.legsHP > this.inMaxHP)
         {
            this.legsHP = this.inMaxHP;
         }
         if(this.bloodHP > this.inMaxHP)
         {
            this.bloodHP = this.inMaxHP;
         }
         if(this.manaHP > this.inMaxMana)
         {
            this.manaHP = this.inMaxMana;
         }
      }
      
      internal function traumaParameters() : *
      {
         if(this.headSt > 0)
         {
            this.setSkillParam(this.xml_head,Math.min(this.headSt,3));
         }
         if(this.torsSt > 0)
         {
            this.setSkillParam(this.xml_tors,Math.min(this.torsSt,3));
         }
         if(this.legsSt > 0)
         {
            this.setSkillParam(this.xml_legs,Math.min(this.legsSt,3));
         }
         if(this.bloodSt > 0)
         {
            this.setSkillParam(this.xml_blood,Math.min(this.bloodSt,3));
         }
         if(this.manaSt > 0)
         {
            this.setSkillParam(this.xml_mana,this.manaSt);
         }
         if(this.manaSt >= 4)
         {
            if(this.teleMana > 0)
            {
               this.gg.levitOn = 0;
            }
            this.isDJ = 0;
            this.spellsPoss = 0;
         }
      }
      
      public function armorParameters(param1:Armor) : *
      {
         if(param1.dexter != 0)
         {
            this.setBegFactor("dexter",this.gg.dexter);
            this.gg.dexter += param1.dexter;
            this.gg.dodgePlus += param1.dexter;
            this.setFactor("dexter",param1.id,"add",param1.dexter,this.gg.dexter,"a");
         }
         if(param1.crit != 0)
         {
            this.gg.critCh += param1.crit;
         }
         this.gg.showObsInd = this.gg.showObsInd || param1.showObsInd;
         if(param1.sneak != 1)
         {
            this.setBegFactor("visiMult",this.visiMult);
            this.visiMult *= 1 - param1.sneak;
            this.setFactor("visiMult",param1.id,"mult",1 - param1.sneak,this.visiMult,"a");
         }
         if(param1.radVul != 1)
         {
            this.setBegFactor("radX",this.gg.radX);
            this.gg.radX *= param1.radVul;
            this.setFactor("radX",param1.id,"mult",param1.radVul,this.gg.radX,"a");
         }
         this.h2oPlav *= param1.h2oMult;
         if(param1.meleeMult != 1)
         {
            this.setBegFactor("meleeDamMult",this.meleeDamMult);
            this.meleeDamMult *= param1.meleeMult;
            this.setFactor("meleeDamMult",param1.id,"mult",param1.meleeMult,this.meleeDamMult,"a");
         }
         if(param1.gunsMult != 1)
         {
            this.setBegFactor("gunsDamMult",this.gunsDamMult);
            this.gunsDamMult *= param1.gunsMult;
            this.setFactor("gunsDamMult",param1.id,"mult",param1.gunsMult,this.gunsDamMult,"a");
         }
         if(param1.magicMult != 1)
         {
            this.setBegFactor("throwForce",this.throwForce);
            this.setBegFactor("spellsDamMult",this.spellsDamMult);
            this.throwForce *= param1.magicMult;
            this.spellsDamMult *= param1.magicMult;
            this.setFactor("throwForce",param1.id,"mult",param1.magicMult,this.throwForce,"a");
            this.setFactor("spellsDamMult",param1.id,"mult",param1.magicMult,this.spellsDamMult,"a");
         }
         this.dropTre += param1.tre;
         if(param1.ableFly)
         {
            this.ableFly = 1;
         }
         var _loc2_:* = 0;
         while(_loc2_ < Unit.kolVulners)
         {
            this.gg.vulner[_loc2_] *= 1 - param1.resist[_loc2_];
            this.setFactor(_loc2_,param1.id,"mult",1 - param1.resist[_loc2_],this.gg.vulner[_loc2_],"a");
            _loc2_++;
         }
         if(param1.id == "socks")
         {
            this.socks = true;
         }
      }
      
      public function invMassParam() : *
      {
         var _loc1_:Invent = World.w.invent;
         this.maxSpeed = 100;
         this.accelMult = 1;
         this.speedShtr = 0;
         this.jumpMult = 1;
         this.shtrManaRes = 1;
         this.gg.noStairs = false;
         if(!World.w.hardInv)
         {
            return;
         }
         if(_loc1_.massW > this.maxmW)
         {
            ++this.speedShtr;
         }
         if(_loc1_.massW > this.maxmW + 2)
         {
            ++this.speedShtr;
         }
         if(_loc1_.massW > this.maxmW + 4)
         {
            ++this.speedShtr;
         }
         if(_loc1_.mass[2] > this.maxm2)
         {
            ++this.speedShtr;
         }
         if(_loc1_.mass[2] > this.maxm2 * 1.2)
         {
            ++this.speedShtr;
         }
         if(_loc1_.mass[3] > this.maxm3)
         {
            ++this.speedShtr;
         }
         if(_loc1_.mass[3] > this.maxm3 * 1.2)
         {
            ++this.speedShtr;
         }
         if(World.w.loc && !World.w.loc.base && !World.w.loc.train && !World.w.alicorn)
         {
            if(this.speedShtr >= 3)
            {
               this.maxSpeed = 0;
               this.accelMult = 0.1;
               this.jumpMult = 0;
               this.gg.noStairs = true;
               World.w.gui.infoText("overMass");
               World.w.gui.bulb(this.gg.X,this.gg.Y - 100);
            }
            else if(this.speedShtr == 2)
            {
               this.maxSpeed = 3.5;
               this.accelMult = 0.5;
               this.jumpMult = 0.5;
            }
            else if(this.speedShtr == 1)
            {
               this.maxSpeed = 7;
               this.accelMult = 0.7;
            }
         }
         if(_loc1_.massM > this.maxmM && !World.w.alicorn)
         {
            this.shtrManaRes -= 0.25 * (_loc1_.massM - this.maxmM);
         }
         if(this.shtrManaRes < 0)
         {
            this.shtrManaRes = 0;
         }
         this.gg.setSpeeds();
      }
      
      public function setParameters() : *
      {
         var xml:XML = null;
         var id:* = undefined;
         var eff:Effect = null;
         var lvl:* = undefined;
         var procHP:* = this.gg.hp / this.gg.maxhp;
         var procHead:* = this.headHP / this.inMaxHP;
         var procTors:* = this.torsHP / this.inMaxHP;
         var procLegs:* = this.legsHP / this.inMaxHP;
         var procBlood:* = this.bloodHP / this.inMaxHP;
         var procMana:* = this.manaHP / this.inMaxMana;
         this.defaultParams();
         this.gg.maxhp += (this.level - 1) * this.lvlHP;
         this.inMaxHP += (this.level - 1) * this.lvlOrganHp;
         for(id in this.skills)
         {
            lvl = 0;
            if(this.skillIsPost(id))
            {
               lvl = this.getPostSkLevel(this.skills[id]);
            }
            else
            {
               lvl = this.getSkLevel(this.skills[id]);
            }
            xml = rconnectXmlFind(AllData.d.skill,"id",id)[0];
            this.setSkillParam(xml,lvl,this.skills[id]);
         }
         for(id in this.perks)
         {
            xml = rconnectXmlFind(AllData.d.perk,"id",id)[0];
            this.setSkillParam(xml,this.perks[id]);
         }
         this.headHP = procHead * this.inMaxHP;
         this.torsHP = procTors * this.inMaxHP;
         this.legsHP = procLegs * this.inMaxHP;
         this.bloodHP = procBlood * this.inMaxHP;
         this.manaHP = procMana * this.inMaxMana;
         if(!World.w.alicorn)
         {
            this.traumaParameters();
         }
         this.gg.showObsInd = false;
         for each(eff in this.gg.effects)
         {
            id = eff.id;
            if(!eff.vse)
            {
               xml = rconnectXmlFind(AllData.d.eff,"id",id)[0];
               this.setSkillParam(xml,eff.vse ? 0 : eff.lvl);
            }
         }
         if(this.gg.rat <= 0)
         {
            if(!World.w.alicorn)
            {
               if(this.gg.currentArmor)
               {
                  this.gg.currentArmor.setArmor();
                  this.armorParameters(this.gg.currentArmor);
               }
               else
               {
                  this.setBegFactor("dexter",this.gg.dexter);
                  this.gg.dexter += this.dexterNoArmor;
                  this.gg.dodgePlus += this.dexterNoArmor;
                  this.setFactor("dexter","noArmor","add",this.dexterNoArmor,this.gg.dexter,"e");
               }
               if(this.gg.currentAmul)
               {
                  this.armorParameters(this.gg.currentAmul);
               }
               if(this.gg.invent)
               {
                  this.setInvParameters(this.gg.invent);
               }
            }
            else
            {
               xml = rconnectXmlFind(AllData.d.eff,"id","alicorn")[0];
               this.setSkillParam(xml,1);
               this.setBegFactor("skin",this.gg.skin);
               this.gg.skin += this.alicornSkin;
               this.setFactor("skin","alicorn","add",this.alicornSkin,this.gg.skin,"e");
               this.setBegFactor("dexter",this.gg.dexter);
               this.gg.dexter += this.alicornDexter;
               this.setFactor("dexter","alicorn","add",this.alicornDexter,this.gg.dexter,"e");
               this.setBegFactor("allVulnerMult",this.gg.allVulnerMult);
               this.gg.allVulnerMult *= this.alicornVulner;
               this.setFactor("allVulnerMult","alicorn","mult",this.alicornVulner,this.gg.allVulnerMult,"e");
            }
         }
         this.gg.hp = this.gg.maxhp * procHP;
         if(this.gg.rad > this.gg.maxhp - 1)
         {
            this.gg.rad = this.gg.maxhp - 1;
         }
         this.gg.setSpeeds();
         if(this.gg.currentWeapon)
         {
            this.gg.currentWeapon.setPers(this.gg,this);
         }
         if(this.gg.magicWeapon)
         {
            this.gg.magicWeapon.setPers(this.gg,this);
         }
         if(this.gg.throwWeapon)
         {
            this.gg.throwWeapon.setPers(this.gg,this);
         }
         World.w.gui.setHp();
         if(World.w.game.triggers["nomed"])
         {
            this.organMult = 0.5;
            this.headMin = 156;
            this.torsMin = 86;
            this.legsMin = 167;
            this.bloodMin = 113;
            this.manaMin = 56;
         }
         else
         {
            this.headMin = this.torsMin = this.legsMin = this.bloodMin = -1;
         }
         if(this.gg.pet)
         {
            this.gg.pet.setLevel(this.level);
         }
         World.w.game.triggers["eco"] = this.eco;
         this.invMassParam();
      }
      
      public function setInvParameters(param1:Invent) : *
      {
         var w:* = undefined;
         var xml:* = undefined;
         var inv:Invent = param1;
         if(inv == null)
         {
            return;
         }
         for each(w in LootGen.arr["pers"])
         {
            if(inv.items[w].kol > 0)
            {
               if(Boolean(inv.items[w].xml) && Boolean(inv.items[w].xml.sk.length()))
               {
                  this.setSkillParam(inv.items[w].xml,1);
               }
               else
               {
                  xml = rconnectXmlFind(AllData.d.eff,"id",w);
                  if(xml.length())
                  {
                     this.setSkillParam(xml[0],1);
                  }
               }
            }
         }
      }
      
      public function getLockTip(param1:int) : int
      {
         if(param1 == 1)
         {
            if(this.possLockPick > 0)
            {
               return this.lockPick;
            }
            return -100;
         }
         if(param1 == 2)
         {
            return this.hacker;
         }
         if(param1 == 3)
         {
            return this.remine;
         }
         if(param1 == 4)
         {
            return this.repair;
         }
         if(param1 == 5)
         {
            return this.repair;
         }
         if(param1 == 6)
         {
            return this.signal;
         }
         return 0;
      }
      
      public function dopusk() : Boolean
      {
         if(this.headHP <= 1 || this.torsHP <= 1 || this.legsHP <= 1 || this.bloodHP <= 1)
         {
            return false;
         }
         return true;
      }
      
      public function getLockMaster(param1:int) : int
      {
         if(param1 == 1)
         {
            return this.unlockMaster;
         }
         if(param1 == 2)
         {
            return this.hackerMaster;
         }
         return 100;
      }
      
      public function setRoboowl() : *
      {
         this.owlhp = 0;
         this.owlhpProc = 1;
         if(this.gg.pets["owl"])
         {
            this.gg.pets["owl"].setLevel(this.level);
            this.owlhp = this.gg.pets["owl"].maxhp;
            this.owlhpProc = this.gg.pets["owl"].hp / this.gg.pets["owl"].maxhp;
         }
      }
      
      public function getLockPickTime(param1:int, param2:int) : int
      {
         var _loc3_:* = this.getLockTip(param2);
         if(param1 < _loc3_)
         {
            return this.lockPickTime * 0.6;
         }
         return this.lockPickTime;
      }
      
      public function repTex() : String
      {
         if(this.rep >= this.repGood)
         {
            return Res.pipText("reputmax");
         }
         if(this.rep >= this.rep4)
         {
            return Res.pipText("reput4");
         }
         if(this.rep >= this.rep3)
         {
            return Res.pipText("reput3");
         }
         if(this.rep >= this.rep2)
         {
            return Res.pipText("reput2");
         }
         if(this.rep >= this.rep1)
         {
            return Res.pipText("reput1");
         }
         return Res.pipText("reput0");
      }
   }
}

