package fe.serv
{
   import fe.*;
   import fe.graph.Emitter;
   import fe.loc.*;
   import fe.unit.Unit;
   import fe.unit.UnitPlayer;
   import fe.weapon.Bullet;
   import flash.media.SoundChannel;
   
   public class Interact
   {
      
      public static var chanceUnlock:Array = [0.9,0.75,0.5,0.3,0.15,0.05,0.01];
      
      public static var chanceUnlock2:Array = [0.95,0.8,0.55,0.35,0.2,0.08,0.03];
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      internal var inited:Boolean = false;
      
      public var owner:Obj;
      
      public var loc:Location;
      
      public var X:Number;
      
      public var Y:Number;
      
      public var active:Boolean = true;
      
      public var action:int = 0;
      
      public var userAction:String;
      
      public var xml:XML;
      
      public var cont:String;
      
      public var door:int = 0;
      
      public var knop:int = 0;
      
      public var expl:int = 0;
      
      public var lock:int = 0;
      
      public var lockTip:int = 1;
      
      public var lockLevel:int = 0;
      
      public var lockAtt:int = -100;
      
      public var lockHP:Number = 10;
      
      public var noRuna:Boolean = false;
      
      public var low:Number = 0;
      
      public var mine:int = 0;
      
      public var mineTip:int = 3;
      
      public var damage:Number = 0;
      
      public var destroy:Number = 0;
      
      public var explRadius:Number = 260;
      
      public var damdis:Number = 50;
      
      public var at_once:int = 0;
      
      public var lockKey:String;
      
      public var cons:String;
      
      public var allDif:Number = -1;
      
      public var xp:int = 0;
      
      public var allact:String;
      
      public var allid:String;
      
      public var needSkill:String;
      
      public var needSkillLvl:int = 0;
      
      public var is_hack:Boolean = false;
      
      public var open:Boolean = false;
      
      public var prob:String = null;
      
      public var noBase:Boolean = false;
      
      public var prize:Boolean = false;
      
      public var is_act:Boolean = false;
      
      public var is_ready:Boolean = true;
      
      public var t_action:int = 0;
      
      public var unlock:int = 0;
      
      public var master:int = 0;
      
      public var stateText:* = "";
      
      public var actionText:* = "";
      
      public var sndAct:* = "";
      
      public var successUnlock:Function;
      
      public var fiascoUnlock:Function;
      
      public var successRemine:Function;
      
      public var fiascoRemine:Function;
      
      public var actFun:Function;
      
      public var area:Area;
      
      public var sign:int = 0;
      
      internal var t_sign:int = 0;
      
      public var isMove:Boolean = false;
      
      internal var begX:Number = 0;
      
      internal var begY:Number = 0;
      
      internal var endX:Number = 0;
      
      internal var endY:Number = 0;
      
      internal var endX2:Number = 0;
      
      internal var t_move:Number = 0;
      
      internal var dt_move:Number = 1;
      
      public var tStay:int = 10;
      
      public var tMove:int = 100;
      
      public var moveSt:int = 0;
      
      internal var moveP:Boolean = false;
      
      public var moveCh:SoundChannel;
      
      internal var lootBroken:Boolean = false;
      
      public var autoClose:int = 0;
      
      internal var t_autoClose:int = 0;
      
      internal var t_budilo:int = 0;
      
      public var scrAct:Script;
      
      public var scrOpen:Script;
      
      public var scrClose:Script;
      
      public var scrTouch:Script;
      
      internal var saveMine:int = 0;
      
      internal var saveLock:int = 0;
      
      public var saveLoot:int = 0;
      
      internal var saveOpen:int = 0;
      
      internal var saveExpl:int = 0;
      
      public const maxLockLvl:* = 24;
      
      public const maxMechLvl:* = 7;
      
      public function Interact(param1:Obj, param2:XML = null, param3:XML = null, param4:Object = null)
      {
         var _loc7_:Number = Number(NaN);
         super();
         this.owner = param1;
         this.loc = this.owner.loc;
         this.X = param1.X;
         this.Y = param1.Y;
         this.xml = param3;
         var _loc5_:* = true;
         if(Boolean(this.xml) && Boolean(this.xml.@set.length()))
         {
            _loc5_ = false;
         }
         if(Boolean(param2) && Boolean(param2.@locktip.length()))
         {
            this.lockTip = param2.@locktip;
         }
         if(Boolean(this.xml) && Boolean(this.xml.@locktip.length()))
         {
            this.lockTip = this.xml.@locktip;
         }
         if(param2)
         {
            if(param2.@cont.length())
            {
               this.cont = param2.@cont;
            }
            if(param2.@lock.length())
            {
               _loc7_ = Number(param2.@lock);
               if(_loc5_)
               {
                  if(param2.@lockch.length() == 0 || Math.random() < Number(param2.@lockch))
                  {
                     if(this.lockTip == 1 || this.lockTip == 2)
                     {
                        this.lock = Math.floor(_loc7_ + (0.3 + Math.random()) * this.loc.locksLevel);
                     }
                     else
                     {
                        this.lock = Math.floor(_loc7_ + Math.random() * this.loc.mechLevel);
                     }
                  }
                  if(Math.random() < _loc7_ - Math.floor(_loc7_))
                  {
                     this.lock += 1;
                  }
               }
               else
               {
                  this.lock = Math.floor(_loc7_);
               }
            }
            if(param2.@low.length())
            {
               this.low = param2.@low;
            }
            this.saveLock = this.lock;
            if(param2.@lockhp.length())
            {
               this.lockHP = param2.@lockhp;
            }
            if(param2.@mine.length())
            {
               if(_loc5_)
               {
                  if(param2.@minech.length())
                  {
                     if(Math.random() < Number(param2.@minech))
                     {
                        this.mine = Math.floor(Math.random() * (Number(param2.@mine) + Math.random() * this.loc.mechLevel + 1));
                     }
                  }
                  else
                  {
                     this.mine = Math.floor(Number(param2.@mine) + Math.random() * this.loc.mechLevel);
                  }
                  if(this.mine >= 2 && Math.random() < 0.25)
                  {
                     --this.mine;
                  }
               }
               else
               {
                  this.mine = param2.@mine;
               }
               if(param2.@minetip.length())
               {
                  this.mineTip = param2.@minetip;
               }
               else if(param2.@inter != "3" && Math.random() < 0.4)
               {
                  this.mineTip = 6;
               }
            }
            this.saveMine = this.mine;
            if(param2.@hack > 0)
            {
               this.is_hack = true;
            }
            if(param2.@allact.length())
            {
               this.allact = param2.@allact;
            }
            this.action = param2.@inter;
            if(param2.@xp.length())
            {
               this.xp = param2.@xp;
            }
            if(param2.@once.length())
            {
               this.at_once = param2.@once;
            }
            if(param2.@door.length())
            {
               this.door = param2.@door;
            }
            if(param2.@knop.length())
            {
               this.knop = param2.@knop;
            }
            if(param2.@time.length())
            {
               this.t_action = param2.@time;
            }
            if(param2.@expl.length())
            {
               this.expl = param2.@expl;
            }
            if(param2.@autoclose.length())
            {
               this.autoClose = param2.@autoclose;
            }
         }
         if(this.xml)
         {
            if(this.xml.@off.length())
            {
               this.active = false;
            }
            if(this.xml.@open.length())
            {
               this.setAct("open",1);
               this.update();
            }
            if(this.xml.@cont.length())
            {
               this.cont = this.xml.@cont;
            }
            if(this.xml.@lock.length())
            {
               this.lock = this.xml.@lock;
               this.saveLock = this.lock;
               this.low = 0;
               if(this.xml.@lock == "0")
               {
                  this.mine = this.saveMine = 0;
               }
            }
            if(this.xml.@locklevel.length())
            {
               this.lockLevel = this.xml.@locklevel;
            }
            if(this.xml.@key.length())
            {
               this.lockKey = this.xml.@key;
            }
            if(this.xml.@cons.length())
            {
               this.cons = this.xml.@cons;
            }
            if(this.xml.@lockhp.length())
            {
               this.lockHP = this.xml.@lockhp;
            }
            if(this.xml.@lockatt.length())
            {
               this.lockAtt = this.xml.@lockatt;
            }
            if(this.xml.@mine.length())
            {
               this.mine = this.xml.@mine;
               this.saveMine = this.mine;
            }
            if(this.xml.@minetip.length())
            {
               this.mineTip = this.xml.@minetip;
            }
            if(this.xml.@autoclose.length())
            {
               this.autoClose = this.xml.@autoclose;
            }
            if(this.xml.@hack.length())
            {
               this.is_hack = this.xml.@hack > 0;
            }
            if(this.xml.@allact.length())
            {
               this.allact = this.xml.@allact;
            }
            if(this.xml.@allid.length())
            {
               this.allid = this.xml.@allid;
            }
            if(this.xml.@prob.length())
            {
               this.prob = this.xml.@prob;
            }
            if(this.xml.@inter.length())
            {
               this.action = this.xml.@inter;
            }
            if(this.xml.@time.length())
            {
               this.t_action = this.xml.@time;
            }
            if(this.xml.@knop.length())
            {
               this.knop = this.xml.@knop;
            }
            if(this.xml.@damage.length())
            {
               this.damage = this.xml.@damage;
            }
            if(this.xml.@prize.length())
            {
               this.prize = true;
            }
            if(this.xml.@nobase.length())
            {
               this.noBase = true;
            }
            if(this.xml.@noruna.length())
            {
               this.noRuna = true;
            }
            if(this.xml.@sign.length())
            {
               this.sign = this.xml.@sign;
            }
            if(this.xml.move.length())
            {
               this.isMove = true;
               this.begX = this.X;
               this.begY = this.Y;
               if(this.xml.move.@dx.length())
               {
                  if(Boolean(this.loc) && this.loc.mirror)
                  {
                     this.endX = this.X - this.xml.move.@dx * World.tileX;
                  }
                  else
                  {
                     this.endX = this.X + this.xml.move.@dx * World.tileX;
                  }
               }
               else
               {
                  this.endX = this.endX2 = this.X;
               }
               if(this.xml.move.@dy.length())
               {
                  this.endY = this.Y + this.xml.move.@dy * World.tileY;
               }
               else
               {
                  this.endY = this.Y;
               }
               if(this.xml.move.@tstay.length())
               {
                  this.tStay = this.xml.move.@tstay;
               }
               if(this.xml.move.@tmove.length())
               {
                  this.tMove = this.xml.move.@tmove;
               }
               if(this.xml.move.@on.length())
               {
                  this.moveSt = 4;
               }
            }
         }
         if(this.loc && this.loc.base && this.cont != null && !this.noBase)
         {
            this.cont = null;
            this.lock = this.mine = this.saveMine = this.saveLock = 0;
            this.action = 0;
            this.active = false;
         }
         if(Boolean(this.loc) && this.loc.homeStable && !this.noBase)
         {
            this.lock = this.mine = this.saveMine = this.saveLock = 0;
         }
         if(Boolean(this.loc) && this.loc.homeAtk && !this.noBase)
         {
            this.lock = this.mine = this.saveMine = this.saveLock = 0;
            if(Boolean(this.cont) && param1 is Box)
            {
               this.setAct("loot",1);
            }
         }
         if(param4)
         {
            this.load(param4);
         }
         var _loc6_:Boolean = this.allDif >= 0;
         if(this.lock < 100)
         {
            if(this.lockTip == 1 || this.lockTip == 2)
            {
               if(this.low > 0 && Math.random() < this.low)
               {
                  this.lock = Math.ceil(this.lock * 0.5);
               }
               if(this.lock > this.maxLockLvl)
               {
                  this.lock = this.maxLockLvl;
               }
               if(this.lock > 0 && this.low <= 0 && param1 && param1.loc && param1.loc.land.rnd && param1.loc.prob == null && Math.random() < 0.2)
               {
                  this.lock += Math.floor(Math.random() * 2) + 2;
               }
               if(this.lock > 2 && this.lockLevel == 0)
               {
                  this.lockLevel = Math.round(Math.random() * (this.lock - 2) / 3.2);
                  if(this.lockLevel > 5)
                  {
                     this.lockLevel = 5;
                  }
               }
               if(!_loc6_)
               {
                  this.allDif = this.lock + this.lockLevel * 2;
               }
            }
            else
            {
               if(this.lock > this.maxMechLvl)
               {
                  this.lock = this.maxMechLvl;
               }
               if(!_loc6_)
               {
                  this.allDif = this.lock * 3;
               }
            }
         }
         if(this.mine > this.maxMechLvl)
         {
            this.mine = this.maxMechLvl;
         }
         if(this.mine > 0)
         {
            if(this.mineTip == 6)
            {
               this.fiascoRemine = this.alarm;
            }
            else
            {
               this.damage = this.mine * 50 * (0.8 + Math.random() * 0.4) * (1 + this.loc.locDifLevel * 0.1);
               this.fiascoRemine = this.explosion;
            }
            if(!_loc6_)
            {
               this.allDif += this.mine * 2;
            }
         }
         if(this.loc)
         {
            this.damdis = 30 + this.loc.mechLevel * 20;
         }
         if(this.expl > 0)
         {
            if(param2.@damage.length())
            {
               this.damage = param2.@damage;
            }
            if(param2.@destroy.length())
            {
               this.destroy = param2.@destroy;
            }
            if(param2.@radius.length())
            {
               this.explRadius = param2.@radius;
            }
         }
         if(this.allact == "robocell")
         {
            this.fiascoUnlock = this.robocellFail;
         }
         if(this.allact == "alarm")
         {
            this.fiascoRemine = this.alarm2;
            if(this.owner)
            {
               this.area = new Area(this.loc);
               this.owner.copy(this.area);
               this.area.tip = "raider";
               this.area.over = this.alarm2;
            }
         }
         if(this.prize)
         {
            this.mine = 0;
            this.lockTip = 0;
            this.lock = 1;
         }
         this.update();
         this.owner.prior += 1;
         this.inited = true;
      }
      
      public function rconnectSecurityActivate() : Boolean
      {
         return this.prob == null && this.allact == "hack_robot" && Unit.rconnectSecurityB != null
            && Unit.rconnectSecurityB("terminal",this,World.w.pers.security) === true;
      }
      
      public function rconnectSecurityState(state:Object = null) : Object
      {
         if(state != null)
         {
            var changed:Boolean = this.lock != int(state.lock);
            this.lock = int(state.lock);
            this.lockAtt = int(state.lockAtt);
            this.lockHP = Number(state.lockHP);
            this.saveLock = int(state.saveLock);
            this.is_act = Boolean(state.is_act);
            this.is_ready = Boolean(state.is_ready);
            this.unlock = int(state.unlock);
            this.master = int(state.master);
            if(changed) this.update();
         }
         return {lock:this.lock,lockAtt:this.lockAtt,lockHP:this.lockHP,saveLock:this.saveLock,
            is_act:this.is_act,is_ready:this.is_ready,unlock:this.unlock,master:this.master};
      }
      
      public function save(param1:Object) : *
      {
         param1.lock = this.saveLock;
         param1.lockLevel = this.lockLevel;
         param1.mine = this.saveMine;
         param1.loot = this.saveLoot;
         param1.open = this.saveOpen;
         param1.expl = this.saveExpl;
         param1.dif = this.allDif;
         param1.sign = this.sign;
      }
      
      public function step() : *
      {
         if(this.is_act)
         {
            this.act();
         }
         else
         {
            this.is_ready = true;
         }
         this.is_act = false;
         if(this.isMove)
         {
            this.move();
         }
         if(this.area)
         {
            this.area.step();
         }
         if(this.t_autoClose > 0)
         {
            --this.t_autoClose;
            if(this.t_autoClose == 1)
            {
               this.command("close");
            }
         }
         if(this.t_budilo > 0)
         {
            if(this.t_budilo % 30 == 0)
            {
               this.loc.budilo(this.owner.X,this.owner.Y,1500);
               Emitter.emit("laser2",this.loc,this.owner.X,this.owner.Y - this.owner.scY + 20);
               Snd.ps("alarm",this.X,this.Y);
            }
            --this.t_budilo;
         }
         if(this.sign > 0)
         {
            if(this.t_sign <= 0)
            {
               this.t_sign = 30;
               if(World.w.helpMess)
               {
                  Emitter.emit("sign" + this.sign,this.loc,this.owner.X,this.owner.Y - this.owner.scY / 2);
               }
            }
            --this.t_sign;
         }
      }
      
      public function update() : *
      {
         if(Boolean(this.userAction) && this.userAction != "")
         {
            this.actionText = Res.guiText(this.userAction);
         }
         else if(this.active && this.action > 0)
         {
            if(this.action == 1)
            {
               this.actionText = Res.guiText(!this.open ? "open" : "close");
            }
            if(this.action == 2)
            {
               this.actionText = Res.guiText("use");
            }
            if(this.action == 3)
            {
               this.actionText = Res.guiText("remine");
            }
            if(this.action == 4)
            {
               this.actionText = Res.guiText("press");
            }
            if(this.action == 5)
            {
               this.actionText = Res.guiText("shutoff");
            }
            if(this.action == 8)
            {
               this.actionText = Res.guiText("comein");
            }
            if(this.action == 9)
            {
               this.actionText = Res.guiText("exit");
            }
            if(this.action == 10)
            {
               this.actionText = Res.guiText("beginm");
            }
            if(this.action == 11)
            {
               this.actionText = Res.guiText("return");
            }
            if(this.action == 12)
            {
               this.actionText = Res.guiText("see");
            }
         }
         else
         {
            this.actionText = "";
         }
         if(this.mine > 0)
         {
            if(this.mineTip == 6)
            {
               this.stateText = "<span class = \'r2\'>" + Res.guiText("signal") + "</span>";
               this.actionText = Res.guiText("shutoff");
            }
            else
            {
               if(this.owner is Box)
               {
                  this.stateText = "<span class = \'warn\'>" + Res.guiText("mined") + "</span>";
               }
               this.actionText = Res.guiText("remine");
            }
            this.sndAct = "rem_act";
         }
         else if(this.lock > 0)
         {
            if(this.lockTip == 0)
            {
               this.stateText = "<span class = \'r2\'>" + Res.guiText("lock") + "</span>";
               this.actionText = "";
               this.sndAct = "lock_act";
            }
            if(this.lockTip == 1)
            {
               if(this.lock >= 100)
               {
                  this.stateText = "<span class = \'r3\'>" + Res.guiText("zhopa") + "</span>";
               }
               else
               {
                  this.stateText = "<span class = \'r2\'>" + Res.guiText("lock") + "</span>";
               }
               this.actionText = Res.guiText("unlock");
               this.sndAct = "lock_act";
            }
            if(this.lockTip == 2)
            {
               if(this.lock >= 100)
               {
                  this.stateText = "<span class = \'r3\'>" + Res.guiText("block") + "</span>";
               }
               else
               {
                  this.stateText = "<span class = \'r2\'>" + Res.guiText("termlock") + "</span>";
               }
               this.actionText = Res.guiText("termunlock");
               this.sndAct = "term_act";
            }
            if(this.lockTip == 4)
            {
               this.actionText = Res.guiText("shutoff");
               this.sndAct = "rem_act";
            }
            if(this.lockTip == 5)
            {
               this.actionText = Res.guiText("fixup");
               this.sndAct = "rem_act";
            }
         }
         else if(this.cont == "empty")
         {
            this.stateText = "<span class = \'r0\'>" + Res.guiText("empty") + "</span>";
         }
         else
         {
            this.stateText = "";
         }
      }
      
      public function setAct(param1:String, param2:int = 0) : *
      {
         if(param1 == "mine")
         {
            if(param2 < 100)
            {
               this.mine = param2;
               this.saveMine = this.mine;
            }
            if(param2 == 101)
            {
               this.mine = 0;
               this.saveMine = 101;
               this.owner.warn = 0;
            }
         }
         if(param1 == "lock")
         {
            if(param2 < 100)
            {
               this.lock = param2;
               this.saveLock = this.lock;
            }
            if(param2 == 101)
            {
               this.saveLock = 101;
               this.lock = 0;
               this.stateText = "";
            }
            if(param2 == 102)
            {
               this.saveLock = 102;
               this.lock = 100;
               if(this.lockTip == 1)
               {
                  this.stateText = "<span class = \'r3\'>" + Res.guiText("zhopa") + "</span>";
               }
               if(this.lockTip == 2)
               {
                  this.stateText = "<span class = \'r3\'>" + Res.guiText("block") + "</span>";
               }
               if(this.lockTip == 5)
               {
                  this.stateText = "<span class = \'r3\'>" + Res.guiText("broken") + "</span>";
               }
            }
         }
         if(param1 == "loot")
         {
            if(param2 > 0)
            {
               this.saveLoot = param2;
               this.active = false;
               this.cont = "empty";
               this.actionText = "";
               this.owner.setVisState("open");
            }
         }
         if(param1 == "open")
         {
            if(this.autoClose == 0)
            {
               this.saveOpen = param2;
            }
            this.open = param2 == 1;
            if(this.door)
            {
               this.setDoor();
            }
            if(this.knop)
            {
               if(this.open)
               {
                  this.owner.setVisState("open");
               }
               else
               {
                  this.owner.setVisState("close");
               }
            }
            if(this.open)
            {
               this.lock = this.mine = 0;
               this.update();
            }
            if(this.open && (this.allact == "robocell" || this.allact == "alarm"))
            {
               this.allact = "";
               this.active = false;
               this.owner.setVisState("open");
            }
            if(Boolean(this.loc) && Boolean(this.loc.prob) && this.loc.active)
            {
               this.loc.prob.check();
            }
         }
         if(param1 == "expl")
         {
            this.saveExpl = param2;
         }
      }
      
      public function act() : *
      {
         var _loc3_:Number = Number(NaN);
         var _loc4_:Number = Number(NaN);
         var _loc5_:Number = Number(NaN);
         var _loc6_:Boolean = false;
         var _loc1_:* = 0;
         var _loc2_:* = 0;
         if(this.action == 0)
         {
            return;
         }
         if(this.scrTouch)
         {
            this.scrTouch.start();
            this.scrTouch = null;
            return;
         }
         if(Boolean(this.needSkill) && this.needSkillLvl > this.unlock)
         {
            World.w.gui.infoText("needSkill",Res.txt("e",this.needSkill),this.needSkillLvl,false);
         }
         else if(this.mine > 0)
         {
            _loc1_ = 0;
            _loc2_ = 0;
            if(this.mine > this.unlock)
            {
               _loc1_ = (this.mine - this.unlock + 1) * 0.15;
            }
            _loc2_ = (this.mine - this.unlock + 2) * 0.2;
            if(Math.random() < _loc1_)
            {
               this.setAct("mine",101);
               if(this.mineTip == 6)
               {
                  World.w.gui.infoText("signalZhopa");
               }
               else
               {
                  World.w.gui.infoText("remineZhopa");
               }
               if(this.fiascoRemine != null)
               {
                  this.fiascoRemine();
               }
               if(this.at_once > 0)
               {
                  this.actOsn();
               }
               this.replic("zhopa");
               this.update();
            }
            else if(Math.random() < _loc2_)
            {
               if(this.mineTip == 6)
               {
                  World.w.gui.infoText("signalFail",null,null,false);
               }
               else
               {
                  World.w.gui.infoText("remineFail",null,null,false);
               }
               this.replic("fail");
            }
            else
            {
               this.setAct("mine",101);
               if(this.mineTip == 6)
               {
                  World.w.gui.infoText("signalOff");
               }
               else
               {
                  World.w.gui.infoText("remine");
               }
               if(this.successRemine != null)
               {
                  this.successRemine();
               }
               if(this.at_once > 0)
               {
                  this.actOsn();
               }
               this.replic("success");
               this.update();
            }
            World.w.gui.bulb(this.X,this.Y);
            this.unlock = 0;
            this.is_ready = false;
         }
         else if(this.lock > 0 && Boolean(this.lockKey) && World.w.invent.items[this.lockKey].kol > 0)
         {
            this.setAct("lock",101);
            if(this.lockTip == 1)
            {
               World.w.gui.infoText("unLockKey");
            }
            if(this.lockTip == 2)
            {
               World.w.gui.infoText("unTermLock");
            }
            if(this.lockTip == 4)
            {
               World.w.gui.infoText("unRepLock");
            }
            if(this.lockTip == 5)
            {
               World.w.gui.infoText("unFixPart");
            }
            this.update();
            if(this.successUnlock != null)
            {
               this.successUnlock();
            }
         }
         else if(this.lock < 100)
         {
            if(this.lock > 0)
            {
               if(this.unlock > -99)
               {
                  _loc3_ = 0;
                  _loc4_ = 2;
                  _loc2_ = 0;
                  if(this.lockTip == 1 || this.lockTip == 5)
                  {
                     _loc2_ = 1 - this.getChance(this.lock - this.unlock);
                     if(this.master < this.lockLevel)
                     {
                        _loc2_ = 1;
                     }
                     if(this.lock - this.unlock == 1)
                     {
                        _loc3_ = 1;
                        _loc4_ = 3;
                     }
                     else if(this.lock - this.unlock > 1)
                     {
                        _loc3_ = 2;
                        _loc4_ = 4;
                     }
                  }
                  else if(this.lockTip == 2)
                  {
                     _loc2_ = 1 - this.getChance(this.lock - this.unlock);
                     if(this.master < this.lockLevel)
                     {
                        _loc2_ = 1;
                     }
                  }
                  else if(this.lockTip == 4)
                  {
                     if(this.lock - this.unlock < 0)
                     {
                        _loc2_ = 0.1;
                     }
                     else if(this.lock - this.unlock == 0)
                     {
                        _loc2_ = 0.25;
                     }
                     else if(this.lock - this.unlock == 1)
                     {
                        _loc2_ = 0.6;
                     }
                     else if(this.lock - this.unlock == 2)
                     {
                        _loc2_ = 0.85;
                     }
                     else
                     {
                        _loc2_ = 1;
                     }
                     _loc3_ = 2;
                     _loc4_ = 4;
                  }
                  _loc5_ = _loc3_;
                  if(Math.random() < _loc2_)
                  {
                     if(this.lockTip == 1)
                     {
                        _loc6_ = false;
                        if(World.w.invent.pin.kol > 0)
                        {
                           if(World.w.pers.pinBreak >= 1 || Math.random() < World.w.pers.pinBreak)
                           {
                              World.w.invent.minusItem("pin");
                              _loc6_ = true;
                           }
                        }
                        else
                        {
                           _loc3_ += 2;
                        }
                        _loc5_ = (_loc3_ + Math.random() * _loc4_) * World.w.pers.lockAtt;
                        this.lockHP -= _loc5_;
                        if(this.lockHP <= 0)
                        {
                           this.setAct("lock",102);
                           World.w.gui.infoText("unLockZhopa");
                           if(this.fiascoUnlock != null)
                           {
                              this.fiascoUnlock();
                           }
                           this.replic("zhopa");
                        }
                        else if(_loc6_)
                        {
                           World.w.gui.infoText("unLockFailP",null,null,false);
                           this.replic("fail");
                        }
                        else if(this.lockHP > 100)
                        {
                           World.w.gui.infoText("unLockFailA",null,null,false);
                        }
                        else
                        {
                           World.w.gui.infoText("unLockFail",null,null,false);
                           this.replic("fail");
                        }
                     }
                     else if(this.lockTip == 2)
                     {
                        if(this.lockAtt == -100)
                        {
                           this.lockAtt = World.w.pers.hackAtt;
                        }
                        --this.lockAtt;
                        if(this.lockAtt > 10)
                        {
                           World.w.gui.infoText("unTermLockFail2",null,null,false);
                        }
                        else if(this.lockAtt > 1)
                        {
                           World.w.gui.infoText("unTermLockFail",this.lockAtt,null,false);
                           this.replic("fail");
                        }
                        else if(this.lockAtt == 1)
                        {
                           World.w.gui.infoText("unTermLockFail1",null,null,false);
                           this.replic("fail");
                        }
                        else
                        {
                           this.setAct("lock",102);
                           this.replic("zhopa");
                           World.w.gui.infoText("unLockBlock");
                           if(this.fiascoUnlock != null)
                           {
                              this.fiascoUnlock();
                           }
                        }
                     }
                     else if(this.lockTip == 4)
                     {
                        _loc5_ = _loc3_ + Math.random() * _loc4_;
                        this.lockHP -= _loc5_;
                        if(this.lockHP <= 0)
                        {
                           this.discharge();
                           World.w.gui.infoText("unRepZhopa",null,null,false);
                           this.replic("zhopa");
                           if(this.fiascoUnlock != null)
                           {
                              this.fiascoUnlock();
                           }
                        }
                        else
                        {
                           World.w.gui.infoText("unRepFail",null,null,false);
                           this.replic("fail");
                        }
                     }
                     else if(this.lockTip == 5)
                     {
                        _loc5_ = _loc3_ + Math.random() * _loc4_;
                        this.lockHP -= _loc5_;
                        if(this.lockHP <= 0)
                        {
                           this.setAct("lock",102);
                           World.w.gui.infoText("unFixZhopa");
                           this.replic("zhopa");
                           if(this.fiascoUnlock != null)
                           {
                              this.fiascoUnlock();
                           }
                        }
                        else
                        {
                           World.w.gui.infoText("unFixFail",null,null,false);
                           this.replic("fail");
                        }
                     }
                  }
                  else
                  {
                     this.setAct("lock",101);
                     if(this.lockTip == 1)
                     {
                        World.w.gui.infoText("unLock");
                        if(Math.random() < 0.8)
                        {
                           this.replic("success");
                        }
                        else
                        {
                           this.replic("unlock");
                        }
                     }
                     if(this.lockTip == 2)
                     {
                        World.w.gui.infoText("unTermLock");
                        if(Math.random() < 0.8)
                        {
                           this.replic("success");
                        }
                        else
                        {
                           this.replic("hack");
                        }
                     }
                     if(this.lockTip == 4)
                     {
                        World.w.gui.infoText("unRepLock");
                        this.replic("success");
                     }
                     if(this.lockTip == 5)
                     {
                        World.w.gui.infoText("unFixLock");
                        this.replic("success");
                     }
                     if(this.successUnlock != null)
                     {
                        this.successUnlock();
                     }
                     if(this.at_once > 0)
                     {
                        this.actOsn();
                     }
                     this.update();
                  }
                  World.w.gui.bulb(this.owner.X,this.owner.Y);
               }
               else
               {
                  World.w.gui.infoText("noPoss",null,null,false);
                  World.w.gui.bulb(this.owner.X,this.owner.Y);
               }
               this.unlock = 0;
               this.is_ready = false;
            }
            else if(this.is_ready)
            {
               this.actOsn();
            }
         }
         this.is_ready = false;
      }
      
      public function getChance(param1:int) : Number
      {
         if(param1 < -2)
         {
            return 1;
         }
         if(param1 > 4)
         {
            return 0;
         }
         if(World.w.pers.upChance > 0)
         {
            return chanceUnlock2[param1 + 2];
         }
         return chanceUnlock[param1 + 2];
      }
      
      public function actOsn() : *
      {
         if(this.cons)
         {
            if(!(Boolean(World.w.invent.items[this.cons]) && World.w.invent.items[this.cons].kol > 0))
            {
               World.w.gui.infoText("needCons",Res.txt("i",this.cons),null,false);
               return;
            }
            World.w.invent.minusItem(this.cons);
            World.w.gui.infoText("usedCons",Res.txt("i",this.cons));
            if(this.cons == "empbomb")
            {
               Emitter.emit("impexpl",this.loc,this.owner.X,this.owner.Y - this.owner.scY / 2);
            }
         }
         if(Boolean(this.actFun))
         {
            this.actFun();
         }
         if(this.cont != null)
         {
            this.loot();
         }
         this.sign = 0;
         if(this.expl)
         {
            this.owner.die();
         }
         if((this.door > 0 || this.knop > 0) && this.action > 0)
         {
            this.open = !this.open;
            this.setAct("open",this.open ? 1 : 0);
            if(this.open && Boolean(this.scrOpen))
            {
               this.scrOpen.start();
            }
            if(!this.open && Boolean(this.scrClose))
            {
               this.scrClose.start();
            }
            if(this.open)
            {
               this.t_autoClose = this.autoClose;
            }
            if(this.door > 0 && Boolean(World.w.pers.noiseDoorOpen))
            {
               World.w.gg.makeNoise(World.w.pers.noiseDoorOpen,true);
            }
         }
         if(Boolean(this.allact) || this.prob != null)
         {
            this.allAct();
         }
         if(Boolean(this.loc) && Boolean(this.loc.prob))
         {
            this.loc.prob.check();
         }
         if(this.scrAct)
         {
            this.scrAct.start();
         }
         this.update();
      }
      
      public function dieCont() : *
      {
         this.lootBroken = true;
         if(this.cont != null)
         {
            this.loot();
         }
         if(this.mine)
         {
            this.setAct("mine",101);
            World.w.gui.infoText("remineZhopa");
            if(this.fiascoRemine != null)
            {
               this.fiascoRemine();
            }
         }
         this.open = true;
         this.setAct("open",1);
         if(this.scrOpen)
         {
            this.scrOpen.start();
         }
         this.update();
      }
      
      public function load(param1:Object) : *
      {
         if(param1 == null)
         {
            return;
         }
         if(param1.lock != null)
         {
            this.setAct("lock",param1.lock);
         }
         if(param1.lockLevel != null)
         {
            this.lockLevel = param1.lockLevel;
         }
         if(param1.dif != null)
         {
            this.allDif = param1.dif;
         }
         if(param1.mine != null)
         {
            this.setAct("mine",param1.mine);
         }
         if(param1.loot != null)
         {
            if(param1.loot == 2)
            {
               this.loot(true);
            }
            this.setAct("loot",param1.loot);
         }
         if(param1.open != null)
         {
            this.setAct("open",param1.open);
         }
         if(param1.expl != null)
         {
            this.setAct("expl",param1.expl);
         }
         if(param1.sign != null)
         {
            this.sign = param1.sign;
         }
      }
      
      public function setDoor() : *
      {
         if(this.inited && !this.open && (this.owner as Box).attDoor())
         {
            this.open = true;
            if(this.t_autoClose <= 0)
            {
               World.w.gui.infoText("noClose",null,null,false);
            }
            return;
         }
         (this.owner as Box).setDoor(this.open);
      }
      
      public function explosion() : *
      {
         if(this.saveExpl)
         {
            return;
         }
         var _loc1_:Unit = new Unit();
         _loc1_.loc = this.loc;
         var _loc2_:Bullet = new Bullet(_loc1_,this.owner.X,this.owner.Y,null,false);
         _loc2_.iExpl(this.damage,this.destroy,this.explRadius);
         this.setAct("expl",1);
         if(this.expl)
         {
            this.owner.die();
         }
      }
      
      public function discharge() : *
      {
         World.w.gg.electroDamage(this.damdis * (Math.random() * 0.4 + 0.8),this.owner.X,this.owner.Y - this.owner.scY / 2);
         this.damdis += 50;
         if(this.damdis > 500)
         {
            this.damdis = 500;
         }
      }
      
      public function alarm() : *
      {
         if(this.saveExpl)
         {
            return;
         }
         this.t_budilo = 240;
         this.setAct("expl",1);
         this.loc.signal();
         this.loc.robocellActivate();
      }
      
      public function alarm2() : *
      {
         if(this.allact != "alarm")
         {
            return;
         }
         this.t_budilo = 240;
         this.loc.signal();
         this.area = null;
         this.active = false;
         this.allact = "";
         this.update();
         this.owner.setVisState("active");
      }
      
      public function robocellFail() : *
      {
         this.loc.robocellActivate();
      }
      
      public function genRobot() : *
      {
         if(this.allact != "robocell")
         {
            return;
         }
         this.loc.createUnit("robot",this.X,this.Y,true,null,null,30);
         this.allact = "";
         this.update();
         this.owner.setVisState("active");
      }
      
      public function needRuna(param1:UnitPlayer) : int
      {
         if(this.mineTip == 6 && this.mine > 0)
         {
            return 1;
         }
         if(this.noRuna || this.lock == 0)
         {
            return 0;
         }
         if(param1.invent == null || this.mine > 0)
         {
            return 0;
         }
         var _loc2_:* = param1.pers.getLockTip(this.lockTip);
         var _loc3_:* = param1.pers.getLockMaster(this.lockTip);
         if(this.lockTip == 1 && param1.invent.items["runa"].kol > 0 && (this.lock - _loc2_ > 1 || this.lockLevel > _loc3_))
         {
            return 1;
         }
         if(this.lockTip == 2 && param1.invent.items["reboot"].kol > 0 && (this.lock - _loc2_ > 1 || this.lockLevel > _loc3_))
         {
            return 1;
         }
         return 0;
      }
      
      public function useRuna(param1:UnitPlayer) : *
      {
         if(this.mineTip == 6 && this.mine > 0)
         {
            if(this.fiascoRemine != null)
            {
               this.fiascoRemine();
            }
            this.setAct("mine",101);
            if(this.at_once > 0)
            {
               this.actOsn();
            }
            this.update();
            return;
         }
         if(param1.invent == null)
         {
            return;
         }
         if(this.lockTip == 1 && this.lock > 0 && param1.invent.items["runa"].kol > 0)
         {
            this.command("unlock");
            param1.invent.minusItem("runa");
            World.w.gui.infoText("useRuna");
            World.w.gui.bulb(this.owner.X,this.owner.Y);
         }
         if(this.lockTip == 2 && this.lock > 0 && param1.invent.items["reboot"].kol > 0)
         {
            this.command("unlock");
            param1.invent.minusItem("reboot");
            World.w.gui.infoText("useReboot");
            World.w.gui.bulb(this.owner.X,this.owner.Y);
         }
      }
      
      public function off() : *
      {
         this.stateText = "";
         this.active = false;
         this.lock = 0;
      }
      
      public function allAct() : *
      {
         if(this.rconnectSecurityActivate()) return;
         var _loc1_:Unit = null;
         var _loc2_:Obj = null;
         if(this.prob != null)
         {
            if(World.w.possiblyOut() == 2)
            {
               World.w.gui.infoText("noOutLoc",null,null,false);
               return;
            }
            this.loc.land.gotoProb(this.prob,this.owner.X,this.owner.Y);
         }
         else if(this.allact == "probreturn")
         {
            if(this.loc.landProb != "")
            {
               if(World.w.possiblyOut() == 2)
               {
                  World.w.gui.infoText("noOutLoc",null,null,false);
                  return;
               }
               this.loc.land.gotoProb("",this.owner.X,this.owner.Y);
            }
         }
         else if(this.allact == "hack_robot")
         {
            World.w.gui.infoText("term1Act");
            World.w.gui.bulb(this.X,this.Y);
            for each(_loc1_ in this.owner.loc.units)
            {
               _loc1_.hack(World.w.pers.security);
            }
         }
         else if(this.allact == "hack_lock")
         {
            World.w.gui.infoText("term2Act");
            World.w.gui.bulb(this.X,this.Y);
            for each(_loc2_ in this.owner.loc.objs)
            {
               if(_loc2_.inter)
               {
                  _loc2_.inter.command("hack");
               }
            }
         }
         else if(this.allact == "prob_help")
         {
            if(this.loc.prob)
            {
               this.loc.prob.showHelp();
            }
         }
         else if(this.allact == "electro_check")
         {
            this.loc.electroCheck();
            if(this.loc.electroDam <= 0)
            {
               World.w.gui.infoText("electroOff",null,null,true);
            }
            else
            {
               World.w.gui.infoText("electroOn",null,null,true);
            }
         }
         else if(this.allact == "comein")
         {
            World.w.gg.outLoc(5,this.X,this.Y);
         }
         else if(this.allact == "bind")
         {
            World.w.gg.bindChain(this.X,this.Y - 20);
         }
         else if(this.allact == "work" || this.allact == "lab" || this.allact == "stove")
         {
            World.w.pip.workTip = this.allact;
            World.w.pip.onoff(7);
         }
         else if(this.allact == "app")
         {
            World.w.pip.onoff(8);
         }
         else if(this.allact == "map")
         {
            World.w.pip.travel = true;
            World.w.pip.onoff(3,3);
            World.w.pip.travel = true;
         }
         else if(this.allact == "stand")
         {
            World.w.stand.onoff(1);
         }
         else if(this.allact == "exit")
         {
            World.w.game.gotoNextLevel();
         }
         else if(this.allact == "robocell")
         {
            World.w.gui.infoText("robocellOff");
            this.setAct("open",1);
         }
         else if(this.allact == "alarm")
         {
            World.w.gui.infoText("alarmOff");
            this.setAct("open",1);
         }
         else if(this.allact == "vault")
         {
            World.w.pip.onoff(9);
         }
         else
         {
            this.owner.loc.allAct(this.owner,this.allact,this.allid);
         }
      }
      
      public function beginAct() : *
      {
         if(this.allact == "comein")
         {
            this.owner.setVisState("comein");
         }
      }
      
      public function shine() : *
      {
         Emitter.emit("unlock",this.loc,this.owner.X,this.owner.Y - this.owner.scY / 2,{
            "kol":10,
            "rx":this.owner.scX,
            "ry":this.owner.scY,
            "dframe":6
         });
      }
      
      public function signal(param1:String) : *
      {
         Emitter.emit(param1,this.loc,this.owner.X,this.owner.Y - this.owner.scY / 2,{
            "kol":6,
            "rx":this.owner.scX / 2,
            "ry":this.owner.scY * 0.8
         });
      }
      
      public function command(param1:String, param2:String = null) : *
      {
         if(param1 == "hack" && this.is_hack)
         {
            this.active = true;
            this.setAct("mine",101);
            this.setAct("lock",101);
            if(this.at_once > 0)
            {
               this.actOsn();
            }
            this.update();
            this.shine();
         }
         if(param1 == "unlock")
         {
            this.active = true;
            this.setAct("mine",101);
            this.setAct("lock",101);
            this.update();
            this.shine();
         }
         if(param1 == "open")
         {
            this.open = true;
            this.setAct("open",1);
            this.t_autoClose = this.autoClose;
            if(Boolean(this.allact) && param2 != "13")
            {
               this.allAct();
            }
         }
         if(param1 == "close")
         {
            this.open = false;
            this.setAct("open",0);
            if(this.open)
            {
               this.t_autoClose = 150;
            }
            if(Boolean(this.allact) && param2 != "13")
            {
               this.allAct();
            }
         }
         if(param1 == "dam")
         {
            if(this.expl)
            {
               this.explosion();
            }
            else if(Boolean(this.knop) && this.action == 0)
            {
               this.setAct("open",1);
               if(this.loc.prob)
               {
                  this.loc.prob.check();
               }
            }
            else
            {
               this.actOsn();
            }
         }
         if(param1 == "swap")
         {
            this.open = !this.open;
            this.setAct("open",this.open ? 1 : 0);
         }
         if(param1 == "sign")
         {
            this.sign = int(param2);
         }
         if(param1 == "off")
         {
            this.active = false;
         }
         if(this.isMove)
         {
            if(param1 == "stop")
            {
               this.moveSt = 0;
            }
            if(param1 == "move")
            {
               this.moveSt = 4;
            }
            if(param1 == "pop")
            {
               if(this.moveSt == 0)
               {
                  this.moveSt = 4;
               }
               else
               {
                  this.moveSt = 0;
               }
            }
            if(param1 == "move1")
            {
               this.moveTo(1);
            }
            if(param1 == "move2")
            {
               this.moveTo(2);
            }
            if(param1 == "move3")
            {
               this.moveTo(3);
            }
         }
         if(param1 == "red")
         {
            this.signal("red");
         }
         if(param1 == "green")
         {
            this.signal("green");
         }
      }
      
      public function move() : *
      {
         var _loc1_:Number = Number(NaN);
         var _loc2_:* = undefined;
         var _loc3_:Number = Number(NaN);
         var _loc4_:Number = Number(NaN);
         if(this.isMove && this.moveSt > 0)
         {
            _loc1_ = 0;
            _loc2_ = this.moveP;
            if(this.dt_move < 1)
            {
               this.dt_move += 0.1;
            }
            if(this.t_move >= 0 && this.t_move < this.tStay)
            {
               this.moveP = false;
               _loc1_ = 0;
               if(this.moveSt == 2 || this.moveSt == 3)
               {
                  this.moveSt = 0;
               }
            }
            if(this.t_move >= this.tStay && this.t_move < this.tStay + this.tMove)
            {
               this.moveP = true;
               _loc1_ = (this.t_move - this.tStay) / this.tMove;
            }
            else if(this.t_move >= this.tStay + this.tMove && this.t_move < this.tStay + this.tMove + this.tStay)
            {
               this.moveP = false;
               _loc1_ = 1;
               if(this.moveSt == 1 || this.moveSt == 3)
               {
                  this.moveSt = 0;
               }
            }
            else if(this.t_move >= this.tStay + this.tMove + this.tStay && this.t_move < (this.tStay + this.tMove) * 2)
            {
               this.moveP = true;
               _loc1_ = ((this.tStay + this.tMove) * 2 - this.t_move) / this.tMove;
            }
            else
            {
               this.moveP = false;
               _loc1_ = 0;
            }
            if(_loc2_ != this.moveP)
            {
               if(this.moveP)
               {
                  this.sound("move");
               }
               else
               {
                  this.sound("stop");
               }
            }
            _loc3_ = this.begX + (this.endX - this.begX) * _loc1_;
            _loc4_ = this.begY + (this.endY - this.begY) * _loc1_;
            this.owner.bindMove(_loc3_,_loc4_);
            this.X = _loc3_;
            this.Y = _loc4_;
            this.t_move += this.dt_move;
            if(this.t_move >= (this.tStay + this.tMove) * 2)
            {
               this.t_move = 0;
            }
         }
      }
      
      public function moveTo(param1:int) : *
      {
         this.moveSt = param1;
         if(param1 == 1)
         {
            if(this.t_move >= 0 && this.t_move < this.tStay)
            {
               this.t_move = this.tStay;
            }
            if(this.t_move >= this.tStay + this.tMove && this.t_move < this.tStay + this.tMove + this.tStay)
            {
               this.moveSt = 0;
            }
         }
         if(param1 == 2)
         {
            if(this.t_move >= 0 && this.t_move < this.tStay)
            {
               this.moveSt = 0;
            }
            if(this.t_move >= this.tStay + this.tMove && this.t_move < this.tStay + this.tMove + this.tStay)
            {
               this.t_move = this.tStay + this.tMove + this.tStay;
            }
         }
         if(param1 == 3)
         {
            if(this.t_move >= 0 && this.t_move < this.tStay)
            {
               this.t_move = this.tStay;
            }
            if(this.t_move >= this.tStay + this.tMove && this.t_move < this.tStay + this.tMove + this.tStay)
            {
               this.t_move = this.tStay + this.tMove + this.tStay;
            }
         }
      }
      
      public function sound(param1:String = null) : *
      {
         if(param1 == "move")
         {
            this.moveCh = Snd.ps("move",this.X,this.Y,0);
         }
         else if(param1 == "stop")
         {
            if(this.moveCh)
            {
               Snd.rconnectStopChannel(this.moveCh);
            }
            this.moveCh = Snd.ps("move",this.X,this.Y,5500);
         }
         else if(this.sndAct != "")
         {
            Snd.actionCh = Snd.ps(this.sndAct,this.X,this.Y);
         }
      }
      
      internal function replic(param1:String) : *
      {
         if(Math.random() < 0.25)
         {
            World.w.gg.replic(param1);
         }
      }
      
      public function receipt() : *
      {
         this.saveLoot = 1;
      }
      
      public function loot(param1:Boolean = false) : *
      {
         var _loc4_:*;
         var _loc5_:*;
         var lootEditorPrevious:Object;
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc6_:XML = null;
         if(this.loc == null || this.cont == "empty")
         {
            return;
         }
         this.X = this.owner.X;
         this.Y = this.owner.Y - this.owner.scY / 2;
         _loc4_ = false;
         _loc5_ = 1;
         if(Boolean(this.xml) && Boolean(this.xml.item.length()))
         {
            for each(_loc6_ in this.xml.item)
            {
               if(!(param1 && _loc6_.@imp.length() == 0))
               {
                  if(_loc6_.@kol.length())
                  {
                     _loc2_ = int(_loc6_.@kol);
                  }
                  else
                  {
                     _loc2_ = 1;
                  }
                  if(_loc6_.@imp.length())
                  {
                     _loc3_ = 2;
                     _loc5_ = 2;
                  }
                  else
                  {
                     _loc3_ = 1;
                  }
                  LootGen.lootId(this.loc,this.X,this.Y,_loc6_.@id,_loc2_,_loc3_,this,this.lootBroken);
                  _loc4_ = true;
               }
            }
         }
         if(param1)
         {
            return;
         }
         if(this.cont != "" && this.cont != "empty")
         {
            lootEditorPrevious = LootGen.lootEditorContext;
            LootGen.lootEditorContext = this;
            try
            {
               if(this.owner is Unit)
               {
                  _loc4_ = LootGen.lootDrop(this.loc,this.X,this.Y,this.cont,(this.owner as Unit).hero) || _loc4_;
               }
               else
               {
                  _loc4_ = LootGen.lootCont(this.loc,this.X,this.Y,this.cont,this.lootBroken,this.prize ? this.allDif : 50) || _loc4_;
                  if(!this.lootBroken && this.allDif > 0 && this.xp > 0)
                  {
                     this.loc.takeXP(Math.round(this.xp * (this.allDif + 1)),this.X,this.Y);
                  }
               }
            }
            finally
            {
               LootGen.lootEditorContext = lootEditorPrevious;
            }
         }
         if(!_loc4_ && this.owner is Box && !World.w.testLoot)
         {
            World.w.gui.infoText("itsEmpty");
         }
         this.setAct("loot",_loc5_);
      }
   }
}

