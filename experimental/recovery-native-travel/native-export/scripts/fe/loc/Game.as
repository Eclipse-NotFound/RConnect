package fe.loc
{
   import fe.*;
   import fe.serv.NPC;
   import fe.serv.Script;
   import fe.serv.Vendor;
   
   public class Game
   {
      
      public var lands:Array;
      
      public var probs:Array;
      
      public var vendors:Array;
      
      public var npcs:Array;
      
      public var curLandId:String = "test";
      
      public var curCoord:String = null;
      
      public var curLand:LandAct;
      
      public var triggers:Array;
      
      public var notes:Array;
      
      public var limits:Array;
      
      public var quests:Array;
      
      public var names:Array;
      
      public var dBeg:Date;
      
      public var t_proshlo:Number;
      
      public var t_save:Number = 0;
      
      public var globalDif:int = 2;
      
      public var baseId:String = "";
      
      public var missionId:String = "";
      
      public var crea:Boolean = false;
      
      public var mReturn:Boolean = true;
      
      internal var objs:Array;
      
      public function Game()
      {
         var _loc1_:* = undefined;
         var _loc2_:LandAct = null;
         super();
         this.lands = new Array();
         this.probs = new Array();
         this.notes = new Array();
         this.vendors = new Array();
         this.npcs = new Array();
         this.triggers = new Array();
         this.limits = new Array();
         this.quests = new Array();
         this.names = new Array();
         for each(_loc1_ in GameData.d.land)
         {
            _loc2_ = new LandAct(_loc1_);
            if(Boolean(World.w.landData[_loc1_.@id]) && Boolean(World.w.landData[_loc1_.@id].allroom))
            {
               _loc2_.allroom = World.w.landData[_loc1_.@id].allroom;
               _loc2_.loaded = true;
            }
            if(_loc2_.prob == 0)
            {
               this.lands[_loc2_.id] = _loc2_;
            }
            else
            {
               this.probs[_loc2_.id] = _loc2_;
            }
         }
      }
      
      public function save() : Object
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc4_:Date = null;
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc10_:Object = null;
         var _loc11_:* = undefined;
         World.w.grafon.sceneSave(this);
         var _loc1_:Object = new Object();
         _loc1_.dif = this.globalDif;
         _loc1_.land = this.curLandId;
         World.w.land.saveObjs(this.objs);
         _loc1_.objs = new Array();
         for(_loc2_ in this.objs)
         {
            _loc5_ = this.objs[_loc2_];
            _loc6_ = new Object();
            for(_loc7_ in _loc5_)
            {
               _loc6_[_loc7_] = _loc5_[_loc7_];
            }
            _loc1_.objs[_loc2_] = _loc6_;
         }
         _loc1_.vendors = new Array();
         _loc1_.npcs = new Array();
         _loc1_.notes = new Array();
         _loc1_.quests = new Array();
         _loc1_.lands = new Array();
         _loc1_.triggers = new Array();
         for(_loc3_ in this.vendors)
         {
            _loc8_ = this.vendors[_loc3_].save();
            if(_loc8_ != null)
            {
               _loc1_.vendors[_loc3_] = _loc8_;
            }
         }
         for(_loc3_ in this.npcs)
         {
            _loc9_ = this.npcs[_loc3_].save();
            if(_loc9_ != null)
            {
               _loc1_.npcs[_loc3_] = _loc9_;
            }
         }
         for(_loc3_ in this.triggers)
         {
            _loc1_.triggers[_loc3_] = this.triggers[_loc3_];
         }
         for(_loc3_ in this.notes)
         {
            _loc1_.notes[_loc3_] = this.notes[_loc3_];
         }
         for(_loc3_ in this.quests)
         {
            _loc10_ = this.quests[_loc3_].save();
            if(_loc10_ != null)
            {
               _loc1_.quests[_loc3_] = _loc10_;
            }
         }
         for(_loc3_ in this.lands)
         {
            _loc11_ = this.lands[_loc3_].save();
            if(_loc11_ != null)
            {
               _loc1_.lands[_loc3_] = _loc11_;
            }
         }
         _loc4_ = new Date();
         this.t_proshlo = _loc4_.getTime() - this.dBeg.getTime();
         _loc1_.t_save = this.t_save + this.t_proshlo;
         return _loc1_;
      }
      
      public function init(param1:Object = null, param2:Object = null) : *
      {
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc10_:Vendor = null;
         var _loc11_:* = undefined;
         var _loc12_:NPC = null;
         var _loc13_:* = undefined;
         var _loc14_:* = undefined;
         if(param1)
         {
            if(param1.dif != null)
            {
               this.globalDif = param1.dif;
            }
            else
            {
               this.globalDif = 2;
            }
            if(param1.t_save)
            {
               this.t_save = param1.t_save;
            }
         }
         else
         {
            if(Boolean(param2) && param2.dif != null)
            {
               this.globalDif = param2.dif;
            }
            else
            {
               this.globalDif = 2;
            }
            this.triggers["noreturn"] = 1;
         }
         this.objs = new Array();
         if(Boolean(param1) && Boolean(param1.objs))
         {
            for(_loc5_ in param1.objs)
            {
               _loc6_ = param1.objs[_loc5_];
               _loc7_ = new Object();
               for(_loc8_ in _loc6_)
               {
                  _loc7_[_loc8_] = _loc6_[_loc8_];
               }
               this.objs[_loc5_] = _loc7_;
            }
         }
         for each(_loc3_ in GameData.d.vendor)
         {
            _loc9_ = null;
            if(Boolean(param1) && Boolean(param1.vendors) && Boolean(param1.vendors[_loc3_.@id]))
            {
               _loc9_ = param1.vendors[_loc3_.@id];
            }
            _loc10_ = new Vendor(0,_loc3_,_loc9_);
            this.vendors[_loc10_.id] = _loc10_;
         }
         for each(_loc3_ in GameData.d.npc)
         {
            _loc11_ = null;
            if(Boolean(param1) && Boolean(param1.npcs) && Boolean(param1.npcs[_loc3_.@id]))
            {
               _loc11_ = param1.npcs[_loc3_.@id];
            }
            _loc12_ = new NPC(_loc3_,_loc11_);
            this.npcs[_loc12_.id] = _loc12_;
         }
         if(param1)
         {
            for(_loc13_ in param1.triggers)
            {
               this.triggers[_loc13_] = param1.triggers[_loc13_];
            }
            for(_loc13_ in param1.notes)
            {
               this.notes[_loc13_] = param1.notes[_loc13_];
            }
            for(_loc13_ in param1.quests)
            {
               this.addQuest(_loc13_,param1.quests[_loc13_]);
            }
            for(_loc13_ in param1.lands)
            {
               if(this.lands[_loc13_])
               {
                  this.lands[_loc13_].load(param1.lands[_loc13_]);
               }
            }
            if(this.triggers["noreturn"] > 0)
            {
               this.mReturn = false;
            }
            else
            {
               this.mReturn = true;
            }
         }
         this.baseId = this.curLandId = "rbl";
         if(param1)
         {
            this.curLandId = param1.land;
            if(this.curLandId != "rbl")
            {
               this.missionId = param1.land;
            }
         }
         else if(Boolean(param2) && param2.propusk == true)
         {
            this.triggers["dial_dialCalam2"] = 1;
         }
         else
         {
            this.curLandId = "begin";
         }
         for each(_loc4_ in this.quests)
         {
            if(_loc4_ != null && _loc4_.state == 2 && Boolean(_loc4_.xml.next.length()))
            {
               for each(_loc14_ in _loc4_.xml.next)
               {
                  this.addQuest(_loc14_.@id);
               }
            }
         }
         if(this.lands[this.curLandId] == null || Boolean(this.lands[this.curLandId].rnd))
         {
            this.curLandId = "rbl";
         }
         this.addNote("helpControl");
         this.addNote("helpGl1");
         this.addNote("helpGl2");
         this.dBeg = new Date();
         if(param1 == null)
         {
            this.triggers["nomed"] = 1;
         }
      }
      
      public function changeDif(param1:*) : Boolean
      {
         if(param1 == this.globalDif)
         {
            return false;
         }
         this.globalDif = param1;
         if(this.globalDif < 0)
         {
            this.globalDif = 0;
         }
         if(this.globalDif > 4)
         {
            this.globalDif = 4;
         }
         World.w.pers.setGlobalDif(this.globalDif);
         World.w.pers.setParameters();
         return true;
      }
      
      public function enterToCurLand() : *
      {
         var _loc2_:int = 0;
         Land.locN += 5;
         World.w.time___metr();
         if(Boolean(World.w.land) && Boolean(this.objs))
         {
            World.w.land.saveObjs(this.objs);
         }
         this.Encounter();
         this.curLand = this.lands[this.curLandId];
         if(this.curLand == null)
         {
            this.curLand = this.lands["rbl"];
         }
         var _loc1_:* = false;
         if(!this.curLand.rnd && !this.curLand.visited)
         {
            _loc1_ = true;
         }
         if(this.curLand.land == null || this.crea)
         {
            _loc2_ = 0;
            if(this.triggers["firstroom"] > 0)
            {
               _loc2_ = 1;
               if(World.w.pers.level > 1)
               {
                  _loc2_ = World.w.pers.level - 1;
               }
            }
            if(this.crea)
            {
               World.w.grafon.sceneResetGeneration(this.curLand.id);
            }
            this.curLand.land = new Land(World.w.gg,this.curLand,_loc2_);
            World.w.grafon.sceneNativeCall("prepare",[this.curLand.land]);
         }
         World.w.time___metr("Создание местности");
         if(!_loc1_)
         {
            this.triggers["firstroom"] = 1;
         }
         this.crea = false;
         World.w.ativateLand(this.curLand.land);
         World.w.land.enterLand(_loc1_,this.curCoord);
         this.curCoord = null;
         if(this.curLand.id == "rbl")
         {
            this.triggers["noreturn"] = 0;
            this.triggers["nomed"] = 0;
            this.triggers["rbl_visited"] = 1;
         }
         else if(this.curLand.tip != "base")
         {
            this.missionId = this.curLand.id;
            trace(this.curLand.tip == "base");
         }
         World.w.gg.remEffect("potion_fly");
         World.w.gui.messText("",Res.txt("m",this.curLand.id) + (this.curLand.rnd ? " - " + (this.curLand.landStage + 1) : ""),World.w.gg.Y < 300);
         if(!this.curLand.rnd)
         {
            this.curLand.visited = true;
         }
         if(this.triggers["noreturn"] > 0)
         {
            this.mReturn = false;
         }
         else
         {
            this.mReturn = true;
         }
         if(this.curLand.upStage)
         {
            this.curLand.upStage = false;
         }
         World.w.time___metr("Вход в местность");
      }
      
      internal function Encounter() : *
      {
         if(this.curLandId == "random_canter" && this.triggers["encounter_way"] <= 0)
         {
            this.curLandId = "way";
         }
         if(this.curLandId == "random_encl" && this.triggers["encounter_post"] <= 0)
         {
            this.curLandId = "post";
         }
         if(this.curLandId == "stable_pi" && this.triggers["storm"] == 4)
         {
            this.curLandId = "stable_pi_atk";
         }
         if(this.curLandId == "stable_pi" && this.triggers["storm"] == 5)
         {
            this.curLandId = "stable_pi_surf";
         }
      }
      
      public function gotoLand(param1:String, param2:String = null, param3:Boolean = false) : *
      {
         if(param1 != this.baseId && !World.w.pers.dopusk())
         {
            World.w.gui.messText("nocont");
         }
         else if(param1 != this.baseId && World.w.pers.speedShtr >= 3)
         {
            World.w.gui.messText("nocont2");
         }
         else
         {
            this.curLandId = param1;
            this.curCoord = param2;
            World.w.exitLand(param3);
         }
      }
      
      public function beginGame() : *
      {
      }
      
      public function beginMission(param1:String = null) : *
      {
         if(param1 == this.curLandId)
         {
            return;
         }
         if(Boolean(param1) && Boolean(this.lands[param1]))
         {
            if(this.lands[param1].tip != "base")
            {
               this.missionId = param1;
               this.crea = true;
            }
         }
         this.gotoLand(param1);
      }
      
      public function gotoNextLevel() : *
      {
         World.w.pers.prevCPCode = null;
         World.w.pers.currentCPCode = null;
         this.curLand.land.currentCP = null;
         this.crea = true;
         this.curLand.land.refill();
         this.gotoLand(this.missionId);
      }
      
      public function upLandLevel() : *
      {
         if(!this.curLand.upStage)
         {
            ++this.curLand.landStage;
         }
         this.curLand.upStage = true;
      }
      
      public function checkTravel(param1:*) : Boolean
      {
         if(this.curLandId == "grave")
         {
            return false;
         }
         if(!this.triggers["fin"] > 0)
         {
            return true;
         }
         if(this.triggers["fin"] == 1)
         {
            return this.lands[param1].fin == 0 || this.lands[param1].fin == 1;
         }
         if(this.triggers["fin"] == 2)
         {
            return this.lands[param1].fin == 0 || this.lands[param1].fin == 2;
         }
         if(this.triggers["fin"] == 3)
         {
            return this.lands[param1].fin == 2;
         }
         return true;
      }
      
      public function refillVendors() : *
      {
         var _loc1_:Vendor = null;
         var _loc2_:* = undefined;
         for each(_loc1_ in this.vendors)
         {
            _loc1_.refill();
         }
         for(_loc2_ in this.triggers)
         {
            if(this.triggers[_loc2_] == "wait")
            {
               this.triggers[_loc2_] = 1;
            }
         }
         World.w.invent.good.kol = World.w.pers.goodHp;
         World.w.gui.infoText("refill");
      }
      
      public function addQuest(param1:String, param2:Object = null, param3:Boolean = false, param4:Boolean = true, param5:Boolean = true) : Quest
      {
         var xlq:XMLList = null;
         var xq:XML = null;
         var q:Quest = null;
         var id:String = param1;
         var loadObj:Object = param2;
         var noVis:Boolean = param3;
         var snd:Boolean = param4;
         var showDial:Boolean = param5;
         if(this.quests[id])
         {
            if(this.quests[id].state == 0)
            {
               this.quests[id].state = 1;
               World.w.gui.infoText("addTask",this.quests[id].nazv);
               Snd.ps("quest");
               this.quests[id].isClosed();
               this.quests[id].deposit();
               if(this.quests[id].state == 2)
               {
                  World.w.gui.infoText("doneTask",this.quests[id].nazv);
               }
            }
            return this.quests[id];
         }
         xlq = GameData.d.quest.(@id == id);
         if(xlq.length() == 0)
         {
            trace("не найден квест",id);
            return null;
         }
         xq = xlq[0];
         q = new Quest(xq,loadObj);
         this.quests[q.id] = q;
         if(noVis && !q.auto)
         {
            q.state = 0;
         }
         if(loadObj == null && q.state > 0)
         {
            World.w.gui.infoText("addTask",q.nazv);
            this.quests[id].deposit();
            if(snd)
            {
               Snd.ps("quest");
            }
         }
         if(Boolean(loadObj == null && showDial && q.begDial) && Boolean(World.w.dialOn) && World.w.loc.prob == null)
         {
            World.w.pip.onoff(-1);
            World.w.gui.dialog(q.begDial);
         }
         return q;
      }
      
      public function showQuest(param1:String, param2:String) : *
      {
         var _loc4_:* = undefined;
         var _loc3_:Quest = this.quests[param1];
         if(_loc3_ == null)
         {
            _loc3_ = this.addQuest(param1,null,true);
         }
         if(_loc3_ == null || _loc3_.state == 2)
         {
            return;
         }
         _loc3_.showSub(param2);
         try
         {
            for each(_loc4_ in _loc3_.subs)
            {
               if(_loc4_.id == param2)
               {
                  World.w.gui.infoText("addTask2",_loc4_.nazv);
                  Snd.ps("quest");
                  break;
               }
            }
         }
         catch(err:*)
         {
         }
      }
      
      public function closeQuest(param1:String, param2:String = null) : *
      {
         var _loc3_:Quest = this.quests[param1];
         if(_loc3_ == null)
         {
            _loc3_ = this.addQuest(param1,null,true);
         }
         if(_loc3_ == null || _loc3_.state == 2)
         {
            return;
         }
         if(param2 == null || param2 == "" || int(param2) < 0)
         {
            _loc3_.close();
         }
         else
         {
            _loc3_.closeSub(param2);
         }
      }
      
      public function checkQuests(param1:String) : String
      {
         var _loc2_:* = undefined;
         var _loc3_:String = null;
         var _loc4_:Quest = null;
         for each(_loc4_ in this.quests)
         {
            if(_loc4_.state == 1 && _loc4_.isCheck)
            {
               _loc3_ = _loc4_.check(param1);
               if(_loc3_ != null)
               {
                  _loc2_ = _loc3_;
               }
            }
         }
         return _loc2_;
      }
      
      public function incQuests(param1:String, param2:int = 1) : *
      {
         var _loc3_:Quest = null;
         for each(_loc3_ in this.quests)
         {
            if(_loc3_.state == 1 && _loc3_.isCheck)
            {
               _loc3_.inc(param1,param2);
               _loc3_.check(param1);
            }
         }
      }
      
      public function addNote(param1:String) : *
      {
         if(this.triggers["note_" + param1])
         {
            return;
         }
         this.triggers["note_" + param1] = 1;
         this.notes.push(param1);
      }
      
      public function setTrigger(param1:String, param2:* = 1) : *
      {
         this.triggers[param1] = param2;
      }
      
      public function getLimit(param1:String) : int
      {
         if(this.limits[param1])
         {
            return this.limits[param1];
         }
         if(this.triggers[param1])
         {
            this.limits[param1] = this.triggers[param1];
            return this.limits[param1];
         }
         this.limits[param1] = 0;
         return 0;
      }
      
      public function addLimit(param1:String, param2:int) : *
      {
         if(param2 == 1)
         {
            if(this.limits[param1])
            {
               ++this.limits[param1];
            }
            else
            {
               this.limits[param1] = 1;
            }
         }
         if(param2 == 2)
         {
            if(this.triggers[param1])
            {
               ++this.triggers[param1];
            }
            else
            {
               this.triggers[param1] = 1;
            }
         }
      }
      
      public function runScript(param1:String, param2:Obj = null) : Boolean
      {
         var xml1:* = undefined;
         var runScr:Script = null;
         var scr:String = param1;
         var own:Obj = param2;
         xml1 = GameData.d.scr.(@id == scr);
         if(xml1.length())
         {
            xml1 = xml1[0];
            runScr = new Script(xml1,World.w.land,own);
            runScr.start();
            return true;
         }
         return false;
      }
      
      public function getScript(param1:String, param2:Obj = null) : Script
      {
         var xml1:* = undefined;
         var scr:String = param1;
         var own:Obj = param2;
         xml1 = GameData.d.scr.(@id == scr);
         if(xml1.length())
         {
            xml1 = xml1[0];
            return new Script(xml1,own == null ? World.w.land : own.loc.land,own);
         }
         return null;
      }
      
      public function gameTime(param1:Number = 0) : String
      {
         var _loc2_:Date = null;
         if(param1 == 0)
         {
            _loc2_ = new Date();
            this.t_proshlo = _loc2_.getTime() - this.dBeg.getTime();
            param1 = this.t_save + this.t_proshlo;
         }
         return Res.gameTime(param1);
      }
   }
}

