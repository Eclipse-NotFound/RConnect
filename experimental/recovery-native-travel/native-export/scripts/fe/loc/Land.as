package fe.loc
{
   import fe.*;
   import fe.serv.Script;
   import fe.unit.UnitPlayer;
   import flash.display.BitmapData;
   
   public class Land
   {
      
      internal static var locN:int = 0;
      
      internal static var _rndSeed:uint = 0;
      
      public static var rconnectSeedSource:Function = null;
      
      public var rconnectLayoutSeed:uint = 0;
      
      public var act:LandAct;
      
      public var rnd:Boolean = false;
      
      public var loc:Location;
      
      private var prevloc:Location;
      
      public var locs:Array;
      
      public var probs:Array;
      
      public var listLocs:Array;
      
      public var locX:int;
      
      public var locY:int;
      
      public var locZ:int = 0;
      
      public var retLocX:int = 0;
      
      public var retLocY:int = 0;
      
      public var retLocZ:int = 0;
      
      public var retX:Number = 0;
      
      public var retY:Number = 0;
      
      public var prob:String = "";
      
      public var minLocX:int = 0;
      
      public var minLocY:int = 0;
      
      public var minLocZ:int = 0;
      
      public var maxLocX:int = 4;
      
      public var maxLocY:int = 6;
      
      public var maxLocZ:int = 2;
      
      public var loc_t:int = 0;
      
      public var gg:UnitPlayer;
      
      public var ggX:Number = 0;
      
      public var ggY:Number = 0;
      
      public var currentCP:CheckPoint;
      
      public var art_t:int = 200;
      
      public var map:BitmapData;
      
      public var landDifLevel:Number = 0;
      
      public var gameStage:int = 0;
      
      public var lootLimit:Number = 0;
      
      public var allXp:int = 0;
      
      public var summXp:int = 0;
      
      public var isRefill:Boolean = false;
      
      internal var allRoom:Array;
      
      internal var rndRoom:Array;
      
      public var kolAll:Array;
      
      public var uidObjs:Array;
      
      public var scripts:Array;
      
      public var itemScripts:Array;
      
      public var kol_phoenix:int = 0;
      
      public var aliAlarm:Boolean = false;
      
      public var probIds:Array;
      
      internal var impProb:int = -1;
      
      public function Land(param1:UnitPlayer, param2:LandAct, param3:int)
      {
         var _loc4_:* = undefined;
         var _loc5_:Script = null;
         super();
         this.gg = param1;
         this.act = param2;
         this.rnd = this.act.rnd;
         this.uidObjs = new Array();
         this.scripts = new Array();
         this.kolAll = new Array();
         this.listLocs = new Array();
         this.probIds = new Array();
         this.probs = new Array();
         this.prepareRooms();
         if(this.rnd)
         {
            this.landDifLevel = param3;
            if(this.landDifLevel < this.act.dif)
            {
               this.landDifLevel = this.act.dif;
            }
            this.maxLocX = this.act.mLocX;
            this.maxLocY = this.act.mLocY;
            this.rconnectLayoutSeed = rconnectSeedSource == null ? uint(1 + Math.floor(Math.random() * 4294967295)) : uint(rconnectSeedSource(this));
            rndDeterm(this.rconnectLayoutSeed);
            this.rconnectLayoutSeed = _rndSeed;
            trace("RConnectRndSeed ",this.act.id,_rndSeed);
            this.buildRandomLand();
         }
         else
         {
            this.landDifLevel = this.act.dif;
            if(this.act.autoLevel)
            {
               this.landDifLevel = param3;
            }
            this.maxLocX = this.maxLocY = 1;
            this.buildSpecifLand();
         }
         this.lootLimit = param3 + 3;
         this.gameStage = this.act.gameStage;
         this.itemScripts = new Array();
         for each(_loc4_ in this.act.xmlland.scr)
         {
            if(_loc4_.@eve == "take" && Boolean(_loc4_.@item.length()))
            {
               _loc5_ = new Script(_loc4_,this);
               this.itemScripts[_loc4_.@item] = _loc5_;
            }
         }
         this.createMap();
      }
      
      internal static function rndDeterm(param1:uint) : *
      {
         _rndSeed = param1 | 0;
         if(_rndSeed == 0)
         {
            _rndSeed = 2166136261;
         }
      }
      
      internal static function rndSeedFor(param1:String) : uint
      {
         var _loc2_:uint = 2166136261;
         var _loc3_:int = 0;
         while(_loc3_ < param1.length)
         {
            _loc2_ ^= param1.charCodeAt(_loc3_);
            _loc2_ *= 16777619;
            _loc3_++;
         }
         return _loc2_;
      }
      
      internal static function rndNext() : Number
      {
         _rndSeed = _rndSeed * 1664525 + 1013904223;
         return (_rndSeed >>> 8) / 16777216;
      }
      
      public function prepareRooms() : *
      {
         var _loc1_:* = undefined;
         this.allRoom = new Array();
         for each(_loc1_ in this.act.allroom.room)
         {
            this.allRoom.push(new Room(_loc1_));
         }
      }
      
      public function buildRandomLand() : *
      {
         var _loc1_:Location = null;
         var _loc2_:Location = null;
         var _loc4_:* = undefined;
         var _loc5_:* = undefined;
         var _loc6_:Room = null;
         var _loc7_:* = undefined;
         var _loc8_:int = 0;
         var _loc9_:* = undefined;
         var _loc10_:* = undefined;
         if(World.w.landError)
         {
            this.locs = null;
            this.locs[0];
         }
         this.locs = new Array();
         if(this.act.conf == 0 && this.act.landStage <= 0)
         {
            this.maxLocY = 3;
         }
         var _loc3_:Object = new Object();
         _loc4_ = this.minLocX;
         while(_loc4_ < this.maxLocX)
         {
            this.locs[_loc4_] = new Array();
            _loc5_ = this.minLocY;
            while(_loc5_ < this.maxLocY)
            {
               _loc3_.mirror = rndNext() < 0.5;
               _loc3_.water = null;
               _loc3_.ramka = null;
               _loc3_.backform = 0;
               _loc3_.transpFon = false;
               if(this.act.conf == 2)
               {
                  if(_loc5_ == 1)
                  {
                     _loc3_.water = 17;
                  }
                  if(_loc5_ > 1)
                  {
                     _loc3_.water = 0;
                  }
               }
               if(this.act.conf == 5)
               {
                  if(_loc5_ == 2)
                  {
                     _loc3_.water = 21;
                  }
                  if(_loc5_ > 2)
                  {
                     _loc3_.water = 0;
                  }
               }
               if(this.act.conf == 3)
               {
               }
               this.locs[_loc4_][_loc5_] = new Array();
               if(this.act.conf == 0 && _loc5_ == 0 && !this.act.visited)
               {
                  _loc3_.mirror = false;
                  _loc1_ = this.newTipLoc("beg" + _loc4_,_loc4_,_loc5_,_loc3_);
               }
               else if((this.act.conf == 2 || this.act.conf == 1 || this.act.conf == 5) && _loc5_ == 0 && _loc4_ == 0 && !this.act.visited)
               {
                  _loc3_.mirror = false;
                  if(this.act.conf == 5)
                  {
                     _loc3_.ramka = 3;
                     _loc3_.backform = 3;
                     _loc3_.transpFon = true;
                  }
                  _loc1_ = this.newTipLoc("beg0",_loc4_,_loc5_,_loc3_);
               }
               else if(this.act.conf == 3)
               {
                  _loc3_.transpFon = true;
                  if(_loc4_ == 2)
                  {
                     if(_loc5_ == 0)
                     {
                        _loc3_.ramka = 7;
                        _loc1_ = this.newTipLoc("passroof",_loc4_,_loc5_,_loc3_);
                     }
                     else
                     {
                        _loc3_.ramka = 5;
                        _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_,"pass");
                     }
                     _loc1_.bezdna = true;
                  }
                  else if(_loc5_ == 0)
                  {
                     _loc3_.ramka = 6;
                     _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_,"roof");
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_);
                     if(_loc4_ > 2 && _loc1_.backwall == "tWindows")
                     {
                        _loc1_.backwall = "tWindows2";
                     }
                  }
               }
               else if(this.act.conf == 4)
               {
                  if(_loc4_ == 0)
                  {
                     if(_loc5_ == 0)
                     {
                        if(World.w.game.triggers["mbase_visited"] <= 0)
                        {
                           _loc3_.mirror = false;
                           _loc3_.ramka = 8;
                           _loc1_ = this.newTipLoc("beg0",_loc4_,_loc5_,_loc3_);
                        }
                        else
                        {
                           _loc1_ = this.newRandomLoc(0,_loc4_,_loc5_,_loc3_);
                        }
                     }
                     else
                     {
                        _loc1_ = this.newRandomLoc(0,_loc4_,_loc5_,_loc3_,"vert");
                     }
                  }
                  else if(_loc4_ == this.maxLocX - 1)
                  {
                     if(_loc5_ == this.maxLocY - 1)
                     {
                        _loc3_.mirror = false;
                        _loc1_ = this.newTipLoc("end",_loc4_,_loc5_,_loc3_);
                     }
                     else
                     {
                        _loc1_ = this.newRandomLoc(0,_loc4_,_loc5_,_loc3_,"vert");
                     }
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(0,_loc4_,_loc5_,_loc3_);
                  }
               }
               else if(this.act.conf == 7)
               {
                  if(_loc4_ == 0)
                  {
                     if(_loc5_ == 0)
                     {
                        _loc3_.mirror = false;
                        _loc1_ = this.newTipLoc("beg1",_loc4_,_loc5_,_loc3_);
                     }
                     else
                     {
                        _loc1_ = this.newRandomLoc(1,_loc4_,_loc5_,_loc3_,"vert");
                     }
                  }
                  else if(_loc4_ == this.maxLocX - 1)
                  {
                     if(_loc5_ == this.maxLocY - 1)
                     {
                        _loc3_.mirror = false;
                        _loc1_ = this.newTipLoc("end1",_loc4_,_loc5_,_loc3_);
                     }
                     else
                     {
                        _loc1_ = this.newRandomLoc(1,_loc4_,_loc5_,_loc3_,"vert");
                     }
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(1,_loc4_,_loc5_,_loc3_);
                  }
               }
               else if(this.act.conf == 5)
               {
                  if(_loc5_ == 0)
                  {
                     _loc3_.ramka = 3;
                     _loc3_.backform = 3;
                     _loc3_.transpFon = true;
                     _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_,"surf");
                     _loc1_.visMult = 2;
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_);
                  }
                  _loc1_.gas = 1;
               }
               else if(this.act.conf == 10)
               {
                  _loc3_.home = true;
                  if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY)
                  {
                     _loc3_.mirror = false;
                     _loc1_ = this.newTipLoc("beg0",_loc4_,_loc5_,_loc3_);
                  }
                  else if(_loc4_ == 1 && _loc5_ == 1)
                  {
                     _loc3_.mirror = false;
                     _loc1_ = this.newTipLoc("roof",_loc4_,_loc5_,_loc3_);
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(10,_loc4_,_loc5_,_loc3_);
                  }
               }
               else if(this.act.conf == 11)
               {
                  _loc3_.atk = true;
                  if(_loc4_ == 5 && _loc5_ == 0)
                  {
                     _loc3_.mirror = false;
                     _loc1_ = this.newTipLoc("pass",_loc4_,_loc5_,_loc3_);
                  }
                  else
                  {
                     _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_);
                  }
               }
               else
               {
                  _loc1_ = this.newRandomLoc(this.act.landStage,_loc4_,_loc5_,_loc3_);
               }
               this.locs[_loc4_][_loc5_][0] = _loc1_;
               if(_loc1_.room.back != null)
               {
                  _loc2_ = null;
                  for each(_loc6_ in this.allRoom)
                  {
                     if(_loc6_.id == _loc1_.room.back)
                     {
                        _loc2_ = this.newLoc(_loc6_,_loc4_,_loc5_,1,_loc3_);
                        _loc2_.tipEnemy = _loc1_.tipEnemy;
                        this.locs[_loc4_][_loc5_][1] = _loc2_;
                        _loc2_.noMap = true;
                        break;
                     }
                  }
               }
               _loc5_++;
            }
            _loc4_++;
         }
         _loc4_ = this.minLocX;
         while(_loc4_ < this.maxLocX)
         {
            _loc5_ = this.minLocY;
            while(_loc5_ < this.maxLocY)
            {
               _loc1_ = this.locs[_loc4_][_loc5_][0];
               _loc1_.pass_r = new Array();
               _loc1_.pass_d = new Array();
               if(_loc4_ < this.maxLocX - 1)
               {
                  _loc2_ = this.locs[_loc4_ + 1][_loc5_][0];
                  _loc7_ = 0;
                  while(_loc7_ <= 5)
                  {
                     _loc8_ = Math.min(_loc1_.doors[_loc7_],_loc2_.doors[_loc7_ + 11]);
                     if(_loc8_ >= 2)
                     {
                        _loc1_.pass_r.push({
                           "n":_loc7_,
                           "fak":_loc8_
                        });
                     }
                     _loc7_++;
                  }
               }
               if(_loc5_ < this.maxLocY - 1)
               {
                  _loc2_ = this.locs[_loc4_][_loc5_ + 1][0];
                  _loc7_ = 6;
                  while(_loc7_ <= 11)
                  {
                     _loc8_ = Math.min(_loc1_.doors[_loc7_],_loc2_.doors[_loc7_ + 11]);
                     if(_loc8_ >= 2)
                     {
                        _loc1_.pass_d.push({
                           "n":_loc7_,
                           "fak":_loc8_
                        });
                     }
                     _loc7_++;
                  }
               }
               _loc5_++;
            }
            _loc4_++;
         }
         _loc4_ = this.minLocX;
         while(_loc4_ < this.maxLocX)
         {
            _loc5_ = this.minLocY;
            while(_loc5_ < this.maxLocY)
            {
               _loc1_ = this.locs[_loc4_][_loc5_][0];
               if(_loc4_ < this.maxLocX - 1)
               {
                  if(_loc1_.pass_r.length)
                  {
                     _loc2_ = this.locs[_loc4_ + 1][_loc5_][0];
                     _loc7_ = 0;
                     while(_loc7_ <= 2)
                     {
                        _loc9_ = Math.floor(rndNext() * _loc1_.pass_r.length);
                        _loc1_.setDoor(_loc1_.pass_r[_loc9_].n,_loc1_.pass_r[_loc9_].fak);
                        _loc2_.setDoor(_loc1_.pass_r[_loc9_].n + 11,_loc1_.pass_r[_loc9_].fak);
                        _loc7_++;
                     }
                  }
               }
               if(_loc5_ < this.maxLocY - 1)
               {
                  if(_loc1_.pass_d.length)
                  {
                     _loc2_ = this.locs[_loc4_][_loc5_ + 1][0];
                     _loc9_ = Math.floor(rndNext() * _loc1_.pass_d.length);
                     _loc1_.setDoor(_loc1_.pass_d[_loc9_].n,_loc1_.pass_d[_loc9_].fak);
                     _loc2_.setDoor(_loc1_.pass_d[_loc9_].n + 11,_loc1_.pass_d[_loc9_].fak);
                  }
               }
               _loc1_.mainFrame();
               _loc5_++;
            }
            _loc4_++;
         }
         if(this.act.conf == 2)
         {
            this.newRandomProb(this.locs[3][0][0],this.act.landStage,true);
         }
         if(this.act.conf == 3 && this.act.landStage >= 1)
         {
            this.newRandomProb(this.locs[1][4][0],this.act.landStage,true);
         }
         _loc5_ = this.maxLocY - 1;
         while(_loc5_ >= this.minLocY)
         {
            _loc4_ = this.minLocX;
            while(_loc4_ < this.maxLocX)
            {
               _loc10_ = true;
               this.locs[_loc4_][_loc5_][0].setObjects();
               if(this.act.conf == 0 || this.act.conf == 1)
               {
                  if((_loc4_ + _loc5_) % 2 == 0)
                  {
                     if(_loc5_ == this.maxLocY - 1)
                     {
                        if(this.act.conf == 0 && this.act.landStage >= 2 || this.act.conf == 1 && this.act.landStage >= 1)
                        {
                           this.locs[_loc4_][_loc5_][0].createExit("1");
                        }
                        else
                        {
                           this.locs[_loc4_][_loc5_][0].createExit();
                        }
                     }
                     else
                     {
                        this.locs[_loc4_][_loc5_][0].createCheck(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY);
                     }
                  }
                  else if(_loc5_ == this.maxLocY - 1)
                  {
                     this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,true);
                  }
                  else if(Math.random() < 0.3)
                  {
                     this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,false);
                  }
               }
               if(this.act.conf == 2 || this.act.conf == 5)
               {
                  if(_loc4_ != 0 || _loc5_ != 0)
                  {
                     this.locs[_loc4_][_loc5_][0].createClouds(_loc5_);
                  }
                  if(this.act.conf == 2 && _loc4_ == this.maxLocX - 1)
                  {
                     this.locs[_loc4_][_loc5_][0].createExit();
                  }
                  if(this.act.conf == 5 && _loc4_ == this.maxLocX - 1 && _loc5_ == 0)
                  {
                     if(this.act.landStage >= 1)
                     {
                        this.locs[_loc4_][_loc5_][0].createExit("1");
                     }
                     else
                     {
                        this.locs[_loc4_][_loc5_][0].createExit();
                     }
                  }
                  else if((_loc4_ + _loc5_) % 2 == 0)
                  {
                     if(this.act.conf == 2 && _loc5_ < 2 && _loc4_ < this.maxLocX - 1 || this.act.conf == 5 && (_loc4_ == 0 || _loc5_ > 0))
                     {
                        this.locs[_loc4_][_loc5_][0].createCheck(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY);
                     }
                  }
                  if(this.act.conf == 2 && _loc5_ > 1)
                  {
                     this.locs[_loc4_][_loc5_][0].petOn = false;
                  }
                  if(_loc5_ > 1 && _loc4_ < this.maxLocX - 1 || this.act.conf == 2 && _loc4_ < this.maxLocX - 1 && Math.random() < 0.25)
                  {
                     if((_loc4_ + _loc5_) % 2 == 1)
                     {
                        this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,false);
                     }
                  }
               }
               if(this.act.conf == 3 && _loc4_ != 2)
               {
                  if((_loc4_ + _loc5_) % 2 == 0)
                  {
                     if(_loc5_ == 0)
                     {
                        if(this.act.landStage >= 1)
                        {
                           this.locs[_loc4_][_loc5_][0].createExit("1");
                        }
                        else
                        {
                           this.locs[_loc4_][_loc5_][0].createExit();
                        }
                     }
                     else
                     {
                        this.locs[_loc4_][_loc5_][0].createCheck(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY);
                     }
                  }
                  else if(_loc5_ == 0)
                  {
                     this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,true);
                  }
                  else if(_loc5_ != 4 && Math.random() < 0.25)
                  {
                     this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,false);
                  }
               }
               if(this.act.conf == 4)
               {
                  if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY || _loc4_ == 3)
                  {
                     this.locs[_loc4_][_loc5_][0].createCheck(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY);
                     if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY)
                     {
                        _loc10_ = false;
                     }
                  }
               }
               if(this.act.conf == 7)
               {
                  if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY)
                  {
                     this.locs[_loc4_][_loc5_][0].createCheck(true);
                     _loc10_ = false;
                  }
               }
               if(this.act.conf == 6)
               {
                  _loc3_.transpFon = true;
                  if(_loc5_ == 0)
                  {
                     if(_loc4_ == 0 || _loc4_ == 2)
                     {
                        if(this.act.landStage >= 1)
                        {
                           this.locs[_loc4_][_loc5_][0].createExit("1");
                        }
                        else
                        {
                           this.locs[_loc4_][_loc5_][0].createExit();
                        }
                     }
                     if(_loc4_ == 1)
                     {
                        this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,true);
                     }
                  }
                  else if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY || _loc4_ == (7 - _loc5_) % 3)
                  {
                     this.locs[_loc4_][_loc5_][0].createCheck(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY);
                  }
                  else if(Math.random() < 0.25)
                  {
                     this.newRandomProb(this.locs[_loc4_][_loc5_][0],this.act.landStage,false);
                  }
               }
               if(this.act.conf == 10 || this.act.conf == 11)
               {
                  if(_loc4_ == this.act.begLocX && _loc5_ == this.act.begLocY)
                  {
                     this.locs[_loc4_][_loc5_][0].createCheck(true);
                  }
               }
               this.locs[_loc4_][_loc5_][0].preStep();
               if(this.locs[_loc4_][_loc5_][1])
               {
                  this.locs[_loc4_][_loc5_][1].mainFrame();
                  this.locs[_loc4_][_loc5_][1].setObjects();
                  this.locs[_loc4_][_loc5_][1].preStep();
               }
               if(_loc10_)
               {
                  this.locs[_loc4_][_loc5_][0].createXpBonuses(5);
               }
               this.allXp += this.locs[_loc4_][_loc5_][0].summXp;
               _loc4_++;
            }
            _loc5_--;
         }
         this.buildProbs();
      }
      
      public function buildSpecifLand() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc4_:Location = null;
         var _loc5_:Location = null;
         var _loc6_:Room = null;
         for each(_loc6_ in this.allRoom)
         {
            if(_loc6_.rx < this.minLocX)
            {
               this.minLocX = _loc6_.rx;
            }
            if(_loc6_.ry < this.minLocY)
            {
               this.minLocY = _loc6_.ry;
            }
            if(_loc6_.rx + 1 > this.maxLocX)
            {
               this.maxLocX = _loc6_.rx + 1;
            }
            if(_loc6_.ry + 1 > this.maxLocY)
            {
               this.maxLocY = _loc6_.ry + 1;
            }
         }
         this.locs = new Array();
         _loc1_ = this.minLocX;
         while(_loc1_ < this.maxLocX)
         {
            this.locs[_loc1_] = new Array();
            _loc2_ = this.minLocY;
            while(_loc2_ < this.maxLocY)
            {
               this.locs[_loc1_][_loc2_] = new Array();
               _loc2_++;
            }
            _loc1_++;
         }
         for each(_loc6_ in this.allRoom)
         {
            _loc4_ = this.newLoc(_loc6_,_loc6_.rx,_loc6_.ry,_loc6_.rz);
            this.locs[_loc6_.rx][_loc6_.ry][_loc6_.rz] = _loc4_;
         }
         _loc1_ = this.minLocX;
         while(_loc1_ < this.maxLocX)
         {
            _loc2_ = this.minLocY;
            while(_loc2_ < this.maxLocY)
            {
               _loc3_ = this.minLocZ;
               while(_loc3_ < this.maxLocZ)
               {
                  if(this.locs[_loc1_][_loc2_][_loc3_] != null)
                  {
                     this.locs[_loc1_][_loc2_][_loc3_].setObjects();
                     this.locs[_loc1_][_loc2_][_loc3_].preStep();
                  }
                  _loc3_++;
               }
               _loc2_++;
            }
            _loc1_++;
         }
         this.buildProbs();
      }
      
      public function buildProbs() : *
      {
         var _loc1_:* = undefined;
         var _loc2_:* = undefined;
         for each(_loc1_ in this.probIds)
         {
            this.buildProb(_loc1_);
         }
         for each(_loc2_ in this.listLocs)
         {
            _loc2_.setObjects();
            _loc2_.preStep();
            if(_loc2_.prob)
            {
               _loc2_.prob.prepare();
            }
         }
      }
      
      public function buildProb(param1:String) : Boolean
      {
         var arrr:XML;
         var xml:* = undefined;
         var room:Room = null;
         var loc:Location = null;
         var xmll:* = undefined;
         var nprob:String = param1;
         if(this.probs[nprob] != null)
         {
            return false;
         }
         arrr = World.w.game.probs["prob"].allroom;
         for each(xml in arrr.room)
         {
            if(xml.@name == nprob)
            {
               room = new Room(xml);
               loc = this.newLoc(room,0,0,0,{"prob":nprob});
               loc.landProb = nprob;
               loc.noMap = true;
               xmll = GameData.d.land.prob.(@id == nprob);
               if(xmll.length())
               {
                  loc.prob = new Probation(xmll[0],loc);
               }
               if(loc.spawnPoints.length)
               {
                  loc.createObj("doorout","box",loc.spawnPoints[0].x,loc.spawnPoints[0].y,<obj prob='' uid='begin'/>);
               }
               this.probs[nprob] = [[[loc]]];
               this.listLocs.push(loc);
               break;
            }
         }
         return true;
      }
      
      public function newRandomProb(param1:Location, param2:int = 100, param3:Boolean = false) : Boolean
      {
         var did:String;
         var impProb:* = undefined;
         var xml:* = undefined;
         var pid:String = null;
         var nloc:Location = param1;
         var maxlevel:int = param2;
         var imp:Boolean = param3;
         this.rndRoom = new Array();
         for each(xml in this.act.xmlland.prob)
         {
            if(this.probs[xml.@id] == null && World.w.game.triggers["prob_" + xml.@id] == null && (xml.@level.length == 0 || xml.@level <= maxlevel))
            {
               this.rndRoom.push(xml.@id);
               if(xml.@imp.length())
               {
                  impProb = xml.@id;
               }
            }
         }
         if(this.rndRoom.length == 0)
         {
            return false;
         }
         did = "doorprob";
         if(imp && Boolean(impProb))
         {
            pid = impProb;
         }
         else if(this.rndRoom.length == 1)
         {
            pid = this.rndRoom[0];
         }
         else
         {
            pid = this.rndRoom[Math.floor(Math.random() * this.rndRoom.length)];
         }
         try
         {
            if(this.act.xmlland.prob.(@id == pid).@tip == "2")
            {
               did = "doorboss";
            }
         }
         catch(err:*)
         {
         }
         if(!nloc.createDoorProb(did,pid))
         {
            return false;
         }
         this.buildProb(pid);
         return true;
      }
      
      public function newTipLoc(param1:String, param2:int, param3:int, param4:Object = null) : Location
      {
         var _loc5_:* = undefined;
         this.rndRoom = new Array();
         for each(_loc5_ in this.allRoom)
         {
            if(_loc5_.tip == param1)
            {
               this.rndRoom.push(_loc5_);
            }
         }
         if(this.rndRoom.length > 0)
         {
            _loc5_ = this.rndRoom[Math.floor(rndNext() * this.rndRoom.length)];
         }
         else
         {
            _loc5_ = this.allRoom[Math.floor(rndNext() * this.allRoom.length)];
            trace("нет локации " + param1);
         }
         --_loc5_.kol;
         return this.newLoc(_loc5_,param2,param3,0,param4);
      }
      
      public function newRandomLoc(param1:int, param2:int, param3:int, param4:Object = null, param5:String = null) : Location
      {
         var _loc6_:Room = null;
         var _loc7_:Room = null;
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc10_:* = undefined;
         this.rndRoom = new Array();
         if(param2 > this.minLocX)
         {
            _loc6_ = this.locs[param2 - 1][param3][0].room;
         }
         if(param3 > this.minLocY)
         {
            _loc7_ = this.locs[param2][param3 - 1][0].room;
         }
         for each(_loc8_ in this.allRoom)
         {
            if(_loc8_.lvl <= param1 && _loc8_.kol > 0 && _loc8_ != _loc6_ && _loc8_ != _loc7_ && (param5 == null && _loc8_.rnd || _loc8_.tip == param5))
            {
               _loc9_ = _loc8_.kol * _loc8_.kol;
               if(_loc9_ == 4 && _loc8_.lvl == 0 && param1 > 1)
               {
                  _loc9_ = 2;
               }
               _loc10_ = 0;
               while(_loc10_ < _loc9_)
               {
                  this.rndRoom.push(_loc8_);
                  _loc10_++;
               }
            }
         }
         if(this.rndRoom.length > 0)
         {
            _loc8_ = this.rndRoom[Math.floor(rndNext() * this.rndRoom.length)];
         }
         else
         {
            for each(_loc8_ in this.allRoom)
            {
               if(_loc8_.rnd)
               {
                  this.rndRoom.push(_loc8_);
               }
            }
            _loc8_ = this.rndRoom[Math.floor(rndNext() * this.rndRoom.length)];
         }
         --_loc8_.kol;
         if(this.act.conf == 4)
         {
            _loc8_.kol = 0;
         }
         return this.newLoc(_loc8_,param2,param3,0,param4);
      }
      
      public function newLoc(param1:Room, param2:int, param3:int, param4:int = 0, param5:Object = null) : Location
      {
         var _loc6_:Location = new Location(this,param1.xml,this.rnd,param5);
         _loc6_.biom = this.act.biom;
         _loc6_.room = param1;
         _loc6_.landX = param2;
         _loc6_.landY = param3;
         _loc6_.landZ = param4;
         _loc6_.id = "loc" + param2 + "_" + param3;
         if(param4 > 0)
         {
            _loc6_.id += "_" + param4;
         }
         _loc6_.unXp = this.act.xp;
         var _loc7_:Number = 0;
         if(this.rnd)
         {
            if(this.act.conf == 0)
            {
               _loc7_ = param3 / 2;
            }
            if(this.act.conf == 1)
            {
               _loc7_ = param3;
            }
            if(this.act.conf == 2)
            {
               _loc7_ = param3 * 2.5;
            }
         }
         this.setLocDif(_loc6_,_loc7_);
         _loc6_.addPlayer(this.gg);
         return _loc6_;
      }
      
      internal function setLocDif(param1:Location, param2:Number) : *
      {
         var _loc3_:Number = this.landDifLevel + param2;
         param1.locDifLevel = _loc3_;
         param1.locksLevel = _loc3_ * 0.7;
         param1.mechLevel = _loc3_ / 4;
         param1.weaponLevel = 1 + _loc3_ / 4;
         param1.enemyLevel = _loc3_;
         if(World.w.game.globalDif < 2)
         {
            param1.earMult *= 0.5;
         }
         if(World.w.game.globalDif > 2)
         {
            param1.enemyLevel += (World.w.game.globalDif - 2) * 2;
         }
         if(this.act.biom == 0 && Math.random() < 0.25)
         {
            param1.tipEnemy = 1;
         }
         if(param1.tipEnemy < 0)
         {
            param1.tipEnemy = Math.floor(Math.random() * 3);
         }
         if(this.act.biom == 1)
         {
            param1.tipEnemy = 0;
         }
         if(this.act.biom == 2 && param1.tipEnemy == 1 && Math.random() < _loc3_ / 20)
         {
            param1.tipEnemy = 3;
         }
         if(this.act.biom == 3)
         {
            param1.tipEnemy = Math.floor(Math.random() * 3) + 3;
         }
         if(_loc3_ > 12 && (this.act.biom == 0 || this.act.biom == 2 || this.act.biom == 3) && Math.random() < 0.1)
         {
            param1.tipEnemy = 6;
         }
         if(this.act.biom == 4)
         {
            param1.tipEnemy = 7;
         }
         if(this.act.biom == 5)
         {
            if(Math.random() < 0.3)
            {
               param1.tipEnemy = 5;
            }
            else
            {
               param1.tipEnemy = 8;
            }
         }
         if(this.act.biom == 6)
         {
            if(Math.random() > 0.3)
            {
               param1.tipEnemy = 9;
            }
            else
            {
               param1.tipEnemy = 10;
            }
         }
         if(this.act.biom == 11)
         {
            param1.tipEnemy = 11;
         }
         if(_loc3_ < 4)
         {
            param1.setKolEn(1,3,5,2);
            param1.setKolEn(2,2,4,0);
            param1.setKolEn(3,3,4,2);
            param1.setKolEn(4,1,2,0);
            param1.setKolEn(5,1,4,2);
            if(param1.tipEnemy == 6)
            {
               param1.setKolEn(2,1,3,0);
            }
            if(param1.kolEnSpawn == 0)
            {
               if(param1.tipEnemy != 5)
               {
                  param1.setKolEn(-1,1,2);
               }
            }
            param1.kolEnHid = 0;
         }
         else if(_loc3_ < 10)
         {
            param1.setKolEn(1,3,6,2);
            if(Math.random() < 0.15)
            {
               param1.setKolEn(2,1,1,0);
            }
            else if(param1.tipEnemy == 6)
            {
               param1.setKolEn(2,2,3,0);
            }
            else
            {
               param1.setKolEn(2,2,5,0);
            }
            param1.setKolEn(3,3,5,2);
            param1.setKolEn(4,2,3,1);
            param1.setKolEn(5,2,4,2);
            if(param1.kolEnSpawn == 0)
            {
               if(param1.tipEnemy != 5)
               {
                  param1.setKolEn(-1,2,3);
               }
            }
            param1.kolEnHid = Math.floor(Math.random() * 3);
         }
         else
         {
            param1.setKolEn(1,4,6,2);
            if(Math.random() < 0.15)
            {
               param1.setKolEn(2,1,2,0);
            }
            else if(param1.tipEnemy == 6)
            {
               param1.setKolEn(2,3,4,0);
            }
            else
            {
               param1.setKolEn(2,3,6,0);
            }
            param1.setKolEn(3,4,7,2);
            param1.setKolEn(4,2,4,1);
            param1.setKolEn(5,3,6,2);
            if(param1.kolEnSpawn == 0)
            {
               if(param1.tipEnemy != 5)
               {
                  param1.setKolEn(-1,2,4);
               }
               else if(Math.random() > 0.4)
               {
                  param1.setKolEn(-1,1,3);
               }
            }
            param1.kolEnHid = Math.floor(Math.random() * 4);
         }
         if(param1.tipEnemy == 5 || param1.tipEnemy == 10)
         {
            param1.setKolEn(2,1,3,1);
         }
         if(this.act.biom == 11)
         {
            param1.setKolEn(2,5,8,0);
         }
      }
      
      public function createMap() : *
      {
         var mapWidth:int = World.cellsX * (this.maxLocX - this.minLocX);
         var mapHeight:int = World.cellsY * (this.maxLocY - this.minLocY);
         var mapX:int = this.minLocX;
         while(mapX < this.maxLocX)
         {
            var mapY:int = this.minLocY;
            while(mapY < this.maxLocY)
            {
               var mapLoc:Location = this.locs[mapX][mapY][0];
               if(mapLoc != null)
               {
                  mapWidth = Math.max(mapWidth,(mapLoc.landX - this.minLocX) * World.cellsX + mapLoc.spaceX);
                  mapHeight = Math.max(mapHeight,(mapLoc.landY - this.minLocY) * World.cellsY + mapLoc.spaceY);
               }
               mapY++;
            }
            mapX++;
         }
         this.map = new BitmapData(mapWidth,mapHeight,true,0);
      }
      
      public function enterLand(param1:Boolean = false, param2:String = null) : *
      {
         var _loc3_:Array = null;
         this.act.visited = true;
         this.loc = null;
         if(param2 != null)
         {
            _loc3_ = param2.split(":");
            if(_loc3_.length >= 1)
            {
               this.locX = _loc3_[0];
            }
            else
            {
               this.locX = 0;
            }
            if(_loc3_.length >= 2)
            {
               this.locY = _loc3_[1];
            }
            else
            {
               this.locY = 0;
            }
            this.locZ = 0;
            this.prob = "";
            this.ativateLoc();
            this.setGGToSpawnPoint();
         }
         else if(Boolean(this.currentCP) && !param1)
         {
            World.w.pers.currentCP = this.currentCP;
            this.gotoCheckPoint();
            this.currentCP.activate();
         }
         else
         {
            this.locX = this.act.begLocX;
            this.locY = this.act.begLocY;
            this.locZ = 0;
            this.prob = "";
            this.ativateLoc();
            this.setGGToSpawnPoint();
         }
      }
      
      public function saveObjs(param1:Array) : *
      {
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         if(this.rnd)
         {
            return;
         }
         var _loc2_:* = this.minLocX;
         while(_loc2_ < this.maxLocX)
         {
            _loc3_ = this.minLocY;
            while(_loc3_ < this.maxLocY)
            {
               _loc4_ = this.minLocZ;
               while(_loc4_ < this.maxLocZ)
               {
                  if(this.locs[_loc2_][_loc3_][_loc4_] != null)
                  {
                     this.locs[_loc2_][_loc3_][_loc4_].saveObjs(param1);
                  }
                  _loc4_++;
               }
               _loc3_++;
            }
            _loc2_++;
         }
      }
      
      public function setGGToSpawnPoint() : *
      {
         if(World.w.grafon.sceneNativeCall("spawn",[this]))
         {
            return;
         }
         var _loc3_:* = undefined;
         var _loc1_:int = 3;
         var _loc2_:int = 3;
         if(this.loc.spawnPoints.length > 0)
         {
            _loc3_ = Math.floor(Math.random() * this.loc.spawnPoints.length);
            _loc1_ = int(this.loc.spawnPoints[_loc3_].x);
            _loc2_ = int(this.loc.spawnPoints[_loc3_].y);
         }
         this.gg.setLocPos((_loc1_ + 1) * Tile.tileX,(_loc2_ + 1) * Tile.tileY - 1);
         this.gg.dx = 3;
         this.loc.lighting(this.gg.X,this.gg.Y - 75);
      }
      
      public function ativateLoc() : Boolean
      {
         var nloc:Location = null;
         if(this.prob != "" && this.probs[this.prob] == null)
         {
            return false;
         }
         try
         {
            if(this.prob != "")
            {
               nloc = this.probs[this.prob][this.locX][this.locY][this.locZ];
            }
            else
            {
               nloc = this.locs[this.locX][this.locY][this.locZ];
            }
         }
         catch(err:*)
         {
            trace("локация не найдена",act.id,locX,locY,locZ);
            nloc = locs[0][0][0];
         }
         if(this.loc == nloc)
         {
            return false;
         }
         ++locN;
         this.prevloc = this.loc;
         this.loc = nloc;
         this.gg.inLoc(this.loc);
         this.loc.reactivate(locN);
         World.w.ativateLoc(this.loc);
         if(this.loc.sky)
         {
            this.gg.isFly = true;
            this.gg.stay = false;
            World.w.cam.setZoom(2);
         }
         this.loc.lightAll();
         return true;
      }
      
      public function gotoXY(param1:int, param2:int) : *
      {
         if(param1 < this.minLocX)
         {
            param1 = this.minLocX;
         }
         if(param1 >= this.maxLocX)
         {
            param1 = this.maxLocX - 1;
         }
         if(param2 < this.minLocY)
         {
            param2 = this.minLocY;
         }
         if(param2 >= this.maxLocY)
         {
            param2 = this.maxLocY - 1;
         }
         this.locX = param1;
         this.locY = param2;
         this.locZ = 0;
         this.ativateLoc();
         this.setGGToSpawnPoint();
      }
      
      public function gotoLoc(param1:int, param2:Number = -1, param3:Number = -1) : Object
      {
         var sceneDoor:Object = World.w.grafon.sceneNativeCall("door",[this,param1,param2,param3]);
         if(sceneDoor != null)
         {
            return sceneDoor.result;
         }
         var _loc4_:Number = this.gg.X;
         var _loc5_:Number = this.gg.Y;
         var _loc6_:Number = this.gg.scX;
         var _loc7_:Number = this.gg.scY;
         var _loc8_:* = this.locX;
         var _loc9_:* = this.locY;
         var _loc10_:int = this.locZ;
         if(param1 == 1)
         {
            _loc8_--;
         }
         else if(param1 == 2)
         {
            _loc8_++;
         }
         else if(param1 == 3)
         {
            _loc9_++;
         }
         else if(param1 == 4)
         {
            _loc9_--;
         }
         else
         {
            if(param1 != 5)
            {
               return null;
            }
            _loc10_ = 1 - _loc10_;
         }
         if(this.prob == "" && (this.locs[_loc8_] == null || this.locs[_loc8_][_loc9_] == null || this.locs[_loc8_][_loc9_][_loc10_] == null))
         {
            if(param1 == 3)
            {
               return {"die":true};
            }
            return null;
         }
         if(this.prob != "" && (this.probs[this.prob][_loc8_] == null || this.probs[this.prob][_loc8_][_loc9_] == null || this.probs[this.prob][_loc8_][_loc9_][_loc10_] == null))
         {
            if(param1 == 3)
            {
               return {"die":true};
            }
            return null;
         }
         var _loc11_:Location = this.locs[_loc8_][_loc9_][_loc10_];
         var _loc12_:Object = new Object();
         if(param1 == 1)
         {
            _loc12_.x = _loc11_.limX - _loc6_ / 2 - 9;
            _loc12_.y = _loc5_ - 1;
         }
         else if(param1 == 2)
         {
            _loc12_.x = 0 + _loc6_ / 2 + 9;
            _loc12_.y = _loc5_ - 1;
         }
         else if(param1 == 3)
         {
            _loc12_.x = _loc4_;
            _loc12_.y = 0 + _loc7_ + 10;
         }
         else if(param1 == 4)
         {
            _loc12_.x = _loc4_;
            _loc12_.y = _loc11_.limY - 10;
         }
         else if(param1 == 5)
         {
            _loc12_.x = param2;
            _loc12_.y = param3;
         }
         if(_loc11_.collisionUnit(_loc12_.x,_loc12_.y,_loc6_ - 4,_loc7_))
         {
            return null;
         }
         this.loc_t = 150;
         this.locX = _loc8_;
         this.locY = _loc9_;
         this.locZ = _loc10_;
         this.ativateLoc();
         this.gg.setLocPos(_loc12_.x,_loc12_.y);
         return _loc12_;
      }
      
      public function gotoProb(param1:String = "", param2:Number = -1, param3:Number = -1) : *
      {
         World.w.grafon.sceneNativeCall("coordinates",[this]);
         if(param1 == "")
         {
            this.prob = "";
            this.locX = this.retLocX;
            this.locY = this.retLocY;
            this.locZ = this.retLocZ;
            this.ativateLoc();
            if(this.retX == 0 && this.retY == 0)
            {
               this.setGGToSpawnPoint();
            }
            else
            {
               this.gg.setLocPos(this.retX,this.retY);
            }
         }
         else
         {
            this.retLocX = this.locX;
            this.retLocY = this.locY;
            this.retLocZ = this.locZ;
            if(param2 < 0 || param3 < 0)
            {
               this.retX = this.gg.X;
               this.retY = this.gg.Y;
            }
            else
            {
               this.retX = param2;
               this.retY = param3;
            }
            this.prob = param1;
            this.locX = this.locY = this.locZ = 0;
            if(this.ativateLoc())
            {
               this.setGGToSpawnPoint();
            }
            else
            {
               this.prob = "";
               this.locX = this.retLocX;
               this.locY = this.retLocY;
               this.locZ = this.retLocZ;
            }
         }
      }
      
      public function gotoCheckPoint() : *
      {
         var _loc1_:CheckPoint = World.w.pers.currentCP;
         if(_loc1_ == null)
         {
            this.gg.setNull();
            return;
         }
         if(_loc1_.loc.land != this && Boolean(this.currentCP))
         {
            _loc1_ = this.currentCP;
            World.w.pers.currentCP = this.currentCP;
            this.currentCP.activate();
         }
         if(_loc1_.loc.land != this)
         {
            this.locX = this.act.begLocX;
            this.locY = this.act.begLocY;
            this.locZ = 0;
            this.prob = "";
            if(!this.ativateLoc())
            {
               this.loc.reactivate();
            }
            this.setGGToSpawnPoint();
         }
         else
         {
            this.locX = _loc1_.loc.landX;
            this.locY = _loc1_.loc.landY;
            this.locZ = _loc1_.loc.landZ;
            this.prob = _loc1_.loc.landProb;
            if(!this.ativateLoc())
            {
               this.loc.reactivate();
            }
            this.gg.setLocPos(_loc1_.X,_loc1_.Y);
         }
         this.gg.dx = 3;
      }
      
      public function refill() : *
      {
         if(this.isRefill)
         {
            return;
         }
         if(this.summXp * 10 > this.allXp || !this.rnd)
         {
            World.w.game.refillVendors();
            this.isRefill = true;
         }
         else
         {
            trace("опыта получено: ",this.summXp,this.allXp);
         }
      }
      
      public function artBabah() : *
      {
         Snd.ps("artfire");
         World.w.quake(10,3);
      }
      
      public function artStep() : *
      {
         --this.art_t;
         if(this.art_t <= 0)
         {
            this.art_t = Math.floor(Math.random() * 1000 + 20);
            if(this.act.artFire != null && World.w.game.triggers[this.act.artFire] != 1)
            {
               this.artBabah();
            }
         }
      }
      
      public function drawMap() : BitmapData
      {
         var _loc2_:* = undefined;
         this.map.fillRect(this.map.rect,0);
         var _loc1_:* = this.minLocX;
         while(_loc1_ < this.maxLocX)
         {
            _loc2_ = this.minLocY;
            while(_loc2_ < this.maxLocY)
            {
               if(this.locs[_loc1_][_loc2_][0] != null && (World.w.drawAllMap || Boolean(this.locs[_loc1_][_loc2_][0].visited)))
               {
                  this.locs[_loc1_][_loc2_][0].drawMap(this.map);
               }
               _loc2_++;
            }
            _loc1_++;
         }
         this.ggX = (this.loc.landX - this.minLocX) * World.cellsX * World.tileX + this.gg.X;
         this.ggY = (this.loc.landY - this.minLocY) * World.cellsY * World.tileY + this.gg.Y - this.gg.scY / 2;
         return this.map;
      }
      
      public function getAll() : int
      {
         var _loc3_:* = undefined;
         var _loc4_:* = undefined;
         var _loc1_:int = 0;
         var _loc2_:* = this.minLocX;
         while(_loc2_ < this.maxLocX)
         {
            _loc3_ = this.minLocY;
            while(_loc3_ < this.maxLocY)
            {
               _loc4_ = this.minLocZ;
               while(_loc4_ < this.maxLocZ)
               {
                  if(this.locs[_loc2_][_loc3_][_loc4_] != null)
                  {
                     _loc1_ += this.locs[_loc2_][_loc3_][_loc4_].getAll();
                  }
                  _loc4_++;
               }
               _loc3_++;
            }
            _loc2_++;
         }
         return _loc1_;
      }
      
      public function step() : *
      {
         var _loc1_:Script = null;
         if(!World.w.catPause)
         {
            this.loc.step();
            if(this.loc_t > 0)
            {
               --this.loc_t;
               if(Boolean(this.prevloc) && this.loc != this.prevloc)
               {
                  this.prevloc.stepInvis();
               }
            }
            this.artStep();
         }
         if(this.scripts.length)
         {
            for each(_loc1_ in this.scripts)
            {
               if(_loc1_.running)
               {
                  _loc1_.step();
               }
            }
         }
      }
   }
}

