package fe.loc
{
   import fe.*;
   import fe.graph.*;
   import fe.serv.Item;
   import fe.serv.LootGen;
   import fe.unit.Unit;
   import fe.unit.UnitPet;
   import fe.unit.UnitPhoenix;
   import fe.unit.UnitPlayer;
   import fe.unit.UnitTransmitter;
   import fe.unit.UnitTurret;
   import fe.weapon.Bullet;
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   
   public class Location
   {
      
      public var land:Land;
      
      public var id:String;
      
      public var room:Room;
      
      public var prob:Probation;
      
      public var spaceX:int;
      
      public var spaceY:int;
      
      public var limX:int;
      
      public var limY:int;
      
      public var landX:int = 0;
      
      public var landY:int = 0;
      
      public var landZ:int = 0;
      
      public var landProb:String = "";
      
      public var bindLoc:Location;
      
      public var base:Boolean = false;
      
      public var train:Boolean = false;
      
      public var black:Boolean = true;
      
      public var grafon:Grafon;
      
      public var space:Array;
      
      public var otstoy:Tile;
      
      public var units:Array;
      
      public var ups:Array;
      
      public var objs:Array;
      
      public var bonuses:Array;
      
      public var areas:Array;
      
      public var acts:Array;
      
      public var saves:Array;
      
      public var backobjs:Array;
      
      public var grenades:Array;
      
      public var gg:UnitPlayer;
      
      public var celObj:Obj;
      
      public var celDist:Number = -1;
      
      public var unitCoord:*;
      
      public var spawnPoints:Array;
      
      public var enspawn:Array;
      
      public var doors:Array;
      
      public var signposts:Array;
      
      public var sign_vis:Boolean = true;
      
      public var nAct:int = 0;
      
      public var active:Boolean = false;
      
      public var visited:Boolean = false;
      
      public var cp:CheckPoint;
      
      public var pass_r:Array;
      
      public var pass_d:Array;
      
      public var objsT:Array;
      
      public var recalcTiles:Array;
      
      public var firstObj:Pt;
      
      public var nextObj:Pt;
      
      public var lastObj:Pt;
      
      public var isRebuild:Boolean = false;
      
      public var isRecalc:Boolean = false;
      
      public var isRelight:Boolean = false;
      
      public var relight_t:int;
      
      public var warning:int = 0;
      
      public var t_gwall:int = 0;
      
      public var lDist1:int = 300;
      
      public var lDist2:int = 1000;
      
      public var quake:int = 0;
      
      public var broom:Boolean = false;
      
      public var isCheck:Boolean = false;
      
      public var noHolesPlace:Boolean = true;
      
      public var ramka:int = 0;
      
      public var bezdna:Boolean = false;
      
      public var mirror:Boolean = false;
      
      public var endLand:Boolean = false;
      
      public var sky:Boolean = false;
      
      public var zoom:Number = 1;
      
      public var gas:int = 0;
      
      public var maxdy:Number = 20;
      
      public var rad:Number = 0;
      
      public var wrad:Number = 1;
      
      public var wdam:Number = 0;
      
      public var wtipdam:int = 7;
      
      public var tipWater:int = 0;
      
      public var opacWater:Number = 0;
      
      public var waterLevel:int = 100;
      
      public var backwall:String = "";
      
      public var backform:int = 0;
      
      public var transpFon:Boolean = false;
      
      public var cTransform:ColorTransform;
      
      public var cTransformFon:ColorTransform;
      
      public var color:String;
      
      public var colorfon:String;
      
      public var sndMusic:String = "music_0";
      
      public var postMusic:Boolean = false;
      
      public var homeStable:Boolean = false;
      
      public var homeAtk:Boolean = false;
      
      public var visMult:Number = 1;
      
      public var noMap:Boolean = false;
      
      public var darkness:int = 0;
      
      public var lightOn:int = 0;
      
      public var retDark:Boolean = false;
      
      public var levitOn:Boolean = true;
      
      public var portOn:Boolean = true;
      
      public var petOn:Boolean = true;
      
      public var destroyOn:Boolean = true;
      
      public var itemsTip:String;
      
      public var electroDam:Number = 0;
      
      public var trus:Number = 0;
      
      public var tipEnemy:int = -1;
      
      public var kolEn:Array = [0,6,4,6,4,6];
      
      internal var tipEn:Array = ["","enl1","enl2","enf1","enc1","lov"];
      
      public var tipSpawn:String = "enl2";
      
      public var kolEnSpawn:int = 0;
      
      public var tileSpawn:Number = 0;
      
      public var kolEnHid:int = 3;
      
      public var kol_phoenix:int = 0;
      
      public var detecting:Boolean = false;
      
      public var t_alarm:int = 0;
      
      public var t_alarmsp:int = 0;
      
      public var kolXp:int = 0;
      
      public var maxXp:int = 0;
      
      public var unXp:int = 100;
      
      public var summXp:int = 0;
      
      public var locDifLevel:Number = 0;
      
      public var biom:int = 0;
      
      public var locksLevel:Number = 0;
      
      public var mechLevel:Number = 0;
      
      public var weaponLevel:Number = 0;
      
      public var enemyLevel:int = 0;
      
      public var earMult:Number = 1;
      
      public function Location(param1:Land, param2:XML, param3:Boolean, param4:Object = null)
      {
         super();
         this.land = param1;
         this.spaceX = World.cellsX;
         this.spaceY = World.cellsY;
         if(param2.@sceneWidth.length() || param2.@sceneHeight.length())
         {
            this.spaceX = int(param2.@sceneWidth);
            this.spaceY = int(param2.@sceneHeight);
            if(this.spaceX < 48 || this.spaceY < 25 || this.spaceX > 512 || this.spaceY > 256)
            {
               throw new Error("ContinuousScene dimensions out of bounds (48..512 by 25..256)");
            }
         }
         this.limX = this.spaceX * World.tileX;
         this.limY = this.spaceY * World.tileY;
         this.otstoy = new Tile(-1,-1);
         this.units = new Array();
         this.ups = new Array();
         this.objs = new Array();
         this.acts = new Array();
         this.areas = new Array();
         this.saves = new Array();
         this.enspawn = new Array();
         this.backobjs = new Array();
         this.space = new Array();
         this.signposts = new Array();
         this.recalcTiles = new Array();
         this.spawnPoints = new Array();
         this.grenades = new Array();
         this.bonuses = new Array();
         this.maxdy = World.maxdy;
         if(param3)
         {
            this.ramka = 1;
         }
         if(param4)
         {
            if(param4.prob)
            {
               this.ramka = 0;
            }
            if(param4.mirror)
            {
               this.mirror = true;
            }
            if(param4.water != null)
            {
               this.waterLevel = param4.water;
            }
            if(param4.ramka != null)
            {
               this.ramka = param4.ramka;
            }
            if(this.ramka == 5)
            {
               this.backform = 1;
            }
            if(this.ramka == 6)
            {
               this.backform = 2;
            }
            if(param4.backform)
            {
               this.backform = param4.backform;
            }
            if(param4.transpFon)
            {
               this.transpFon = param4.transpFon;
            }
            if(param4.home)
            {
               this.homeStable = true;
            }
            if(param4.atk)
            {
               this.homeAtk = true;
            }
         }
         var _loc5_:* = 0;
         while(_loc5_ < this.kolEn.length)
         {
            this.ups[_loc5_] = new Array();
            _loc5_++;
         }
         this.noHolesPlace = param3;
         this.buildLoc(param2);
         World.w.grafon.sceneTrack(this,String(param2.@sceneRevision));
         World.w.grafon.sceneSetRegions(this,param2);
      }
      
      public function addPlayer(param1:UnitPlayer) : *
      {
         this.gg = param1;
         this.units.push(param1);
         this.units.push(param1.defpet);
      }
      
      public function buildLoc(param1:XML) : *
      {
         var obj:XML = null;
         var j:* = undefined;
         var js:String = null;
         var arri:Array = null;
         var jis:String = null;
         var s:String = null;
         var d:* = undefined;
         var xmll:XML = null;
         var size:int = 0;
         var nx:int = 0;
         var ny:int = 0;
         var n:int = 0;
         var nroom:XML = param1;
         var i:* = 0;
         while(i < this.spaceX)
         {
            this.space[i] = new Array();
            j = 0;
            while(j < this.spaceY)
            {
               this.space[i][j] = new Tile(i,j);
               j++;
            }
            i++;
         }
         this.backwall = this.land.act.backwall;
         this.sndMusic = this.land.act.sndMusic;
         this.postMusic = this.land.act.postMusic;
         this.rad = this.land.act.rad;
         this.wrad = this.land.act.wrad;
         this.wdam = this.land.act.wdam;
         this.wtipdam = this.land.act.wtipdam;
         this.tipWater = this.land.act.tipWater;
         this.color = this.land.act.color;
         this.visMult = this.land.act.visMult;
         this.opacWater = this.land.act.opacWater;
         this.darkness = this.land.act.darkness;
         if(nroom.options.length())
         {
            if(nroom.options.@backwall.length())
            {
               this.backwall = nroom.options.@backwall;
            }
            if(nroom.options.@backform.length())
            {
               this.backform = nroom.options.@backform;
            }
            if(nroom.options.@transpfon.length())
            {
               this.transpFon = true;
            }
            if(nroom.options.@music.length())
            {
               this.sndMusic = nroom.options.@music;
            }
            if(nroom.options.@rad.length())
            {
               this.rad = nroom.options.@rad;
            }
            if(nroom.options.@wrad.length())
            {
               this.wrad = nroom.options.@wrad;
            }
            if(nroom.options.@wtip.length())
            {
               this.tipWater = nroom.options.@wtip;
            }
            if(nroom.options.@wopac.length())
            {
               this.opacWater = nroom.options.@wopac;
            }
            if(nroom.options.@wdam.length())
            {
               this.wdam = nroom.options.@wdam;
            }
            if(nroom.options.@wtipdam.length())
            {
               this.wtipdam = nroom.options.@wtipdam;
            }
            if(nroom.options.@bezdna.length())
            {
               this.bezdna = true;
            }
            if(nroom.options.@wlevel.length())
            {
               this.waterLevel = nroom.options.@wlevel;
            }
            if(nroom.options.@base.length())
            {
               this.base = true;
            }
            if(nroom.options.@noblack.length())
            {
               this.black = false;
            }
            if(nroom.options.@train.length())
            {
               this.train = true;
            }
            if(nroom.options.@color.length())
            {
               this.color = nroom.options.@color;
            }
            if(nroom.options.@colorfon.length())
            {
               this.colorfon = nroom.options.@colorfon;
            }
            if(nroom.options.@vis.length())
            {
               this.visMult = nroom.options.@vis;
            }
            if(nroom.options.@nomap.length())
            {
               this.noMap = true;
            }
            if(nroom.options.@entip.length())
            {
               this.tipEnemy = nroom.options.@entip;
            }
            if(nroom.options.@lon.length())
            {
               this.lightOn = nroom.options.@lon;
            }
            if(nroom.options.@dark.length())
            {
               this.darkness = nroom.options.@dark;
            }
            if(nroom.options.@retdark.length())
            {
               this.retDark = true;
            }
            if(nroom.options.@levitoff.length())
            {
               this.levitOn = false;
            }
            if(nroom.options.@portoff.length())
            {
               this.portOn = false;
            }
            if(nroom.options.@desoff.length())
            {
               this.destroyOn = false;
            }
            if(nroom.options.@petoff.length())
            {
               this.petOn = false;
            }
            if(nroom.options.@spawn.length())
            {
               this.tipSpawn = nroom.options.@spawn;
            }
            if(nroom.options.@kolspawn.length())
            {
               this.kolEnSpawn = nroom.options.@kolspawn;
            }
            if(nroom.options.@tilespawn.length())
            {
               this.tileSpawn = nroom.options.@tilespawn;
            }
            if(nroom.options.@items.length())
            {
               this.itemsTip = nroom.options.@items;
            }
            if(nroom.options.@maxdy.length())
            {
               this.maxdy = nroom.options.@maxdy;
            }
            if(nroom.options.@sky.length())
            {
               this.sky = true;
            }
            if(nroom.options.@zoom.length())
            {
               this.zoom = nroom.options.@zoom;
            }
            if(nroom.options.@trus.length())
            {
               this.trus = nroom.options.@trus;
            }
            if(!this.black)
            {
               i = 0;
               while(i < this.spaceX)
               {
                  j = 0;
                  while(j < this.spaceY)
                  {
                     (this.space[i][j] as Tile).visi = 1;
                     j++;
                  }
                  i++;
               }
            }
         }
         if(this.homeStable)
         {
            this.color = "yellow";
            this.lightOn = 1;
            this.base = true;
         }
         if(this.homeAtk)
         {
            this.color = "fire";
            this.lightOn = 1;
         }
         j = 0;
         while(j < this.spaceY)
         {
            js = "";
            js = nroom.a[j];
            arri = js.split(".");
            i = 0;
            while(i < this.spaceX)
            {
               if(this.mirror)
               {
                  jis = arri[this.spaceX - i - 1];
               }
               else
               {
                  jis = arri[i];
               }
               if(jis == null)
               {
                  jis = "";
               }
               this.space[i][j].dec(jis,this.mirror);
               if(this.space[i][j].stair != 0)
               {
                  if(j > 0 && this.space[i][j].phis == 0 && !this.space[i][j].shelf && this.space[i][j].stair != this.space[i][j - 1].stair)
                  {
                     this.space[i][j].shelf = true;
                     ++this.space[i][j].vid;
                  }
               }
               if(j >= this.waterLevel)
               {
                  this.space[i][j].water = 1;
               }
               if(i == 0 || i == this.spaceX - 1 || j == 0 || j == this.spaceY - 1)
               {
                  if(this.ramka == 1 || (this.ramka == 2 || this.ramka == 4) && (i == 0 || i == this.spaceX - 1) || (this.ramka == 3 || this.ramka == 4) && j == this.spaceY - 1 || this.ramka == 5 && (i <= 10 || i >= 37) || this.ramka == 6 && j >= 16 || this.ramka == 7 && (i <= 10 || i >= 37) && j >= 16 || this.ramka == 8 && i == this.spaceX - 1)
                  {
                     this.space[i][j].phis = 1;
                  }
                  else if(this.space[i][j].phis >= 1)
                  {
                     this.space[i][j].indestruct = true;
                  }
               }
               i++;
            }
            j++;
         }
         if(nroom.doors.length() > 0)
         {
            s = nroom.doors[0];
            this.doors = s.split(".");
            if(this.mirror)
            {
               d = this.doors[6];
               this.doors[6] = this.doors[10];
               this.doors[10] = d;
               d = this.doors[7];
               this.doors[7] = this.doors[9];
               this.doors[9] = d;
               d = this.doors[17];
               this.doors[17] = this.doors[21];
               this.doors[21] = d;
               d = this.doors[18];
               this.doors[18] = this.doors[20];
               this.doors[20] = d;
               i = 0;
               while(i <= 5)
               {
                  d = this.doors[i];
                  this.doors[i] = this.doors[i + 11];
                  this.doors[i + 11] = d;
                  i++;
               }
            }
         }
         else
         {
            this.doors = new Array();
            i = 0;
            while(i < 22)
            {
               this.doors[i] = 2;
               i++;
            }
         }
         this.lDist1 *= this.visMult;
         this.lDist2 *= this.visMult;
         if(isNaN(this.lDist1))
         {
            this.lDist1 = 300;
            this.lDist2 = 1000;
         }
         this.cTransform = this.colorFilter(this.color);
         if(this.colorfon)
         {
            this.cTransformFon = this.colorFilter(this.colorfon);
         }
         this.objsT = new Array();
         for each(obj in nroom.obj)
         {
            xmll = AllData.d.obj.(@id == obj.@id)[0];
            size = int(xmll.@size);
            if(size <= 0)
            {
               size = 1;
            }
            nx = int(obj.@x);
            ny = int(obj.@y);
            if(this.mirror)
            {
               nx = this.spaceX - nx - size;
            }
            if(xmll.@tip == "spawnpoint")
            {
               this.spawnPoints.push({
                  "x":nx,
                  "y":ny
               });
            }
            else if(xmll.@tip == "enspawn")
            {
               this.addEnSpawn(nx,ny,xmll);
            }
            else if(xmll.@tip == "up")
            {
               n = int(xmll.@tipn);
               this.ups[n].push({
                  "x":nx,
                  "y":ny,
                  "xml":obj
               });
            }
            else
            {
               this.objsT.push({
                  "id":obj.@id,
                  "tip":xmll.@tip,
                  "rem":xmll.@rem,
                  "x":nx,
                  "y":ny,
                  "xml":obj
               });
            }
         }
         for each(obj in nroom.back)
         {
            this.backobjs.push(new BackObj(this,obj.@id,obj.@x * Tile.tileX,obj.@y * Tile.tileY,obj));
         }
         if(this.zoom > 1)
         {
            this.limX *= this.zoom;
            this.limY *= this.zoom;
         }
      }
      
      public function colorFilter(param1:String = "") : ColorTransform
      {
         var _loc2_:* = new ColorTransform();
         if(param1 == "green")
         {
            _loc2_.blueMultiplier = _loc2_.redMultiplier = 0.8;
            _loc2_.greenMultiplier = 1.16;
         }
         else if(param1 == "red")
         {
            _loc2_.blueMultiplier = 0.7;
            _loc2_.greenMultiplier = 0.9;
            _loc2_.redMultiplier = 1.1;
         }
         else if(param1 == "fire")
         {
            _loc2_.blueMultiplier = 0.5;
            _loc2_.greenMultiplier = 0.7;
            _loc2_.redMultiplier = 1.1;
         }
         else if(param1 == "lab")
         {
            _loc2_.blueMultiplier = 0.7;
            _loc2_.greenMultiplier = 1.1;
            _loc2_.redMultiplier = 0.9;
         }
         else if(param1 == "black")
         {
            _loc2_.blueMultiplier = 0.7;
            _loc2_.greenMultiplier = 0.6;
            _loc2_.redMultiplier = 0.5;
         }
         else if(param1 == "blue")
         {
            _loc2_.blueMultiplier = 1.16;
            _loc2_.greenMultiplier = _loc2_.redMultiplier = 0.8;
         }
         else if(param1 == "sky")
         {
            _loc2_.blueMultiplier = _loc2_.greenMultiplier = 1.12;
            _loc2_.redMultiplier = 0.85;
         }
         else if(param1 == "yellow")
         {
            _loc2_.blueMultiplier = 0.9;
            _loc2_.greenMultiplier = 1.2;
            _loc2_.redMultiplier = 1.25;
         }
         else if(param1 == "purple")
         {
            _loc2_.blueMultiplier = 1.12;
            _loc2_.greenMultiplier = 0.8;
            _loc2_.redMultiplier = 1.08;
         }
         else if(param1 == "pink")
         {
            _loc2_.blueMultiplier = 1;
            _loc2_.greenMultiplier = 0.9;
            _loc2_.redMultiplier = 1.1;
         }
         else if(param1 == "blood")
         {
            _loc2_.blueMultiplier = 0.6;
            _loc2_.greenMultiplier = 0.6;
            _loc2_.redMultiplier = 1.08;
         }
         else if(param1 == "blood2")
         {
            _loc2_.blueMultiplier = 0.1;
            _loc2_.greenMultiplier = 0.1;
            _loc2_.redMultiplier = 1;
         }
         else if(param1 == "dark")
         {
            _loc2_.blueMultiplier = 0;
            _loc2_.greenMultiplier = 0;
            _loc2_.redMultiplier = 0;
         }
         else if(param1 == "mf")
         {
            _loc2_.redMultiplier = 0.5;
            _loc2_.greenMultiplier = 0.5;
            _loc2_.blueMultiplier = 1.08;
         }
         return _loc2_;
      }
      
      public function setDoor(param1:int, param2:int = 2) : *
      {
         var _loc3_:int = 0;
         if(param2 < 2)
         {
            return;
         }
         var _loc4_:Boolean = false;
         if(param1 > 21)
         {
            return;
         }
         if(param1 >= 17)
         {
            _loc3_ = (param1 - 17) * 9 + 4;
            _loc4_ = Boolean(this.space[_loc3_ + 1][0].hole()) || _loc4_;
            _loc4_ = Boolean(this.space[_loc3_ + 2][0].hole()) || _loc4_;
            this.space[_loc3_ + 1][1].hole();
            this.space[_loc3_ + 2][1].hole();
            this.setNoObj(_loc3_ + 1,0,0,2);
            this.setNoObj(_loc3_ + 2,0,0,2);
            if(param2 > 2)
            {
               _loc4_ = Boolean(this.space[_loc3_][0].hole()) || _loc4_;
               _loc4_ = Boolean(this.space[_loc3_ + 3][0].hole()) || _loc4_;
               this.space[_loc3_][1].hole();
               this.space[_loc3_ + 3][1].hole();
               this.setNoObj(_loc3_,0,0,2);
               this.setNoObj(_loc3_ + 3,0,0,2);
            }
            if(_loc4_)
            {
               this.addSignPost(_loc3_ + 2,0,-90);
            }
         }
         else if(param1 >= 11)
         {
            _loc3_ = (param1 - 11) * 4 + 3;
            _loc4_ = Boolean(this.space[0][_loc3_].hole()) || _loc4_;
            _loc4_ = Boolean(this.space[0][_loc3_ - 1].hole()) || _loc4_;
            this.space[1][_loc3_].hole();
            this.space[1][_loc3_ - 1].hole();
            this.setNoObj(0,_loc3_,5,0);
            this.setNoObj(0,_loc3_ - 1,5,0);
            if(param2 > 2)
            {
               _loc4_ = Boolean(this.space[0][_loc3_ - 2].hole()) || _loc4_;
               this.space[1][_loc3_ - 2].hole();
            }
            if(_loc4_)
            {
               this.addSignPost(0,_loc3_,180);
            }
            this.addEnSpawn(Tile.tileX,(_loc3_ + 1) * Tile.tileY - 1);
         }
         else if(param1 >= 6)
         {
            _loc3_ = (param1 - 6) * 9 + 4;
            _loc4_ = Boolean(this.space[_loc3_ + 1][this.spaceY - 1].hole()) || _loc4_;
            _loc4_ = Boolean(this.space[_loc3_ + 2][this.spaceY - 1].hole()) || _loc4_;
            this.space[_loc3_ + 1][this.spaceY - 2].hole();
            this.space[_loc3_ + 2][this.spaceY - 2].hole();
            this.setNoObj(_loc3_ + 1,this.spaceY - 1,0,-2);
            this.setNoObj(_loc3_ + 2,this.spaceY - 1,0,-2);
            if(param2 > 2)
            {
               _loc4_ = Boolean(this.space[_loc3_][this.spaceY - 1].hole()) || _loc4_;
               _loc4_ = Boolean(this.space[_loc3_ + 3][this.spaceY - 1].hole()) || _loc4_;
               this.space[_loc3_][this.spaceY - 2].hole();
               this.space[_loc3_ + 3][this.spaceY - 2].hole();
               this.setNoObj(_loc3_,this.spaceY - 1,0,-2);
               this.setNoObj(_loc3_ + 3,this.spaceY - 1,0,-2);
            }
            if(_loc4_)
            {
               this.addSignPost(_loc3_ + 2,this.spaceY,90);
            }
         }
         else
         {
            if(param1 < 0)
            {
               return;
            }
            _loc3_ = param1 * 4 + 3;
            _loc4_ = Boolean(this.space[this.spaceX - 1][_loc3_].hole()) || _loc4_;
            _loc4_ = Boolean(this.space[this.spaceX - 1][_loc3_ - 1].hole()) || _loc4_;
            this.space[this.spaceX - 2][_loc3_].hole();
            this.space[this.spaceX - 2][_loc3_ - 1].hole();
            this.setNoObj(this.spaceX - 1,_loc3_,-5,0);
            this.setNoObj(this.spaceX - 1,_loc3_ - 1,-5,0);
            if(param2 > 2)
            {
               _loc4_ = Boolean(this.space[this.spaceX - 1][_loc3_ - 2].hole()) || _loc4_;
               this.space[this.spaceX - 2][_loc3_ - 2].hole();
            }
            if(_loc4_)
            {
               this.addSignPost(this.spaceX,_loc3_,0);
            }
            this.addEnSpawn((this.spaceX - 1) * Tile.tileX,(_loc3_ + 1) * Tile.tileY - 1);
         }
      }
      
      private function addSignPost(param1:int, param2:int, param3:int) : *
      {
         var _loc4_:MovieClip = null;
         _loc4_ = new signPost();
         _loc4_.x = param1 * Tile.tileX;
         _loc4_.y = param2 * Tile.tileY;
         _loc4_.rotation = param3;
         this.signposts.push(_loc4_);
      }
      
      private function addEnSpawn(param1:Number, param2:Number, param3:XML = null) : *
      {
         var _loc5_:int = 0;
         var _loc4_:Object = new Object();
         if(param3)
         {
            _loc5_ = int(param3.@size);
            if(_loc5_ <= 0)
            {
               _loc5_ = 1;
            }
            _loc4_.x = (param1 + 0.5 * _loc5_) * Tile.tileX;
            _loc4_.y = (param2 + 1) * Tile.tileY - 1;
         }
         else
         {
            _loc4_.x = param1;
            _loc4_.y = param2;
         }
         this.enspawn.push(_loc4_);
      }
      
      private function setNoObj(param1:int, param2:int, param3:int, param4:int) : *
      {
         var _loc5_:int = 0;
         if(param3 > 0)
         {
            _loc5_ = param1;
            while(_loc5_ <= param1 + param3)
            {
               this.space[_loc5_][param2].place = false;
               _loc5_++;
            }
         }
         if(param3 < 0)
         {
            _loc5_ = param1 + param3;
            while(_loc5_ <= param1)
            {
               this.space[_loc5_][param2].place = false;
               _loc5_++;
            }
         }
         if(param4 > 0)
         {
            _loc5_ = param2;
            while(_loc5_ <= param2 + param4)
            {
               this.space[param1][_loc5_].place = false;
               _loc5_++;
            }
         }
         if(param4 < 0)
         {
            _loc5_ = param2 + param4;
            while(_loc5_ <= param2)
            {
               this.space[param1][_loc5_].place = false;
               _loc5_++;
            }
         }
      }
      
      public function mainFrame() : *
      {
         var _loc1_:String = "A";
         if(Boolean(this.land) && Boolean(this.land.act))
         {
            _loc1_ = this.land.act.border;
         }
         var _loc2_:* = 0;
         while(_loc2_ < this.spaceX)
         {
            if(this.space[_loc2_][0].phis >= 1)
            {
               this.space[_loc2_][0].mainFrame(_loc1_);
            }
            if(this.space[_loc2_][this.spaceY - 1].phis >= 1)
            {
               this.space[_loc2_][this.spaceY - 1].mainFrame(_loc1_);
            }
            _loc2_++;
         }
         _loc2_ = 0;
         while(_loc2_ < this.spaceY)
         {
            if(this.space[0][_loc2_].phis >= 1)
            {
               this.space[0][_loc2_].mainFrame(_loc1_);
            }
            if(this.space[this.spaceX - 1][_loc2_].phis >= 1)
            {
               this.space[this.spaceX - 1][_loc2_].mainFrame(_loc1_);
            }
            _loc2_++;
         }
      }
      
      public function setObjects() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in this.objsT)
         {
            if(!(this.noHolesPlace && _loc1_.rem > 0 && !this.space[_loc1_.x][_loc1_.y].place))
            {
               if(_loc1_.tip == "unit")
               {
                  this.createUnit(_loc1_.id,_loc1_.x,_loc1_.y,false,_loc1_.xml);
               }
               else
               {
                  this.createObj(_loc1_.id,_loc1_.tip,_loc1_.x,_loc1_.y,_loc1_.xml);
               }
            }
         }
         this.objsT = null;
         this.setRandomUnits();
         if(this.land.rnd && World.w.pers.modMetal > 0 && Math.random() < World.w.pers.modMetal)
         {
            this.putRandomLoot();
         }
      }
      
      public function setKolEn(param1:int, param2:int, param3:int, param4:int = 0) : *
      {
         if(param1 == -1)
         {
            this.kolEnSpawn = param2 + Math.floor(Math.random() * (param3 - param2 + 1));
         }
         else
         {
            this.kolEn[param1] = param2 + Math.floor(Math.random() * (param3 - param2 + 1));
            if(param4 > 0 && Math.random() < 0.2)
            {
               this.kolEn[param1] += param4;
            }
         }
      }
      
      public function setRandomUnits() : *
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         var _loc1_:* = 1;
         while(_loc1_ < this.kolEn.length)
         {
            if(this.kolEn[_loc1_] > 0 && Boolean(this.ups[_loc1_].length))
            {
               if(this.noHolesPlace)
               {
                  _loc2_ = 0;
                  while(_loc2_ < this.ups[_loc1_].length)
                  {
                     if(!this.space[this.ups[_loc1_][_loc2_].x][this.ups[_loc1_][_loc2_].y].place)
                     {
                        this.ups[_loc1_].splice(_loc2_,1);
                        _loc2_--;
                     }
                     _loc2_++;
                  }
               }
               if(this.ups[_loc1_].length > 0)
               {
                  _loc2_ = 0;
                  while(_loc2_ < this.kolEn[_loc1_])
                  {
                     _loc3_ = Math.floor(Math.random() * this.ups[_loc1_].length);
                     this.createUnit(this.tipEn[_loc1_],this.ups[_loc1_][_loc3_].x,this.ups[_loc1_][_loc3_].y,false,this.ups[_loc1_][_loc3_].xml);
                     if(this.ups[_loc1_].length <= 1)
                     {
                        this.ups[_loc1_] = [];
                        break;
                     }
                     this.ups[_loc1_].splice(_loc3_,1);
                     _loc2_++;
                  }
               }
            }
            _loc1_++;
         }
         if(this.kolEnHid > 0 && this.ups[2].length > 0)
         {
            _loc2_ = 0;
            while(_loc2_ < this.kolEnHid)
            {
               _loc3_ = Math.floor(Math.random() * this.ups[2].length);
               this.createHidden(this.ups[2][_loc3_].x,this.ups[2][_loc3_].y);
               if(this.ups[2].length <= 1)
               {
                  break;
               }
               this.ups[2].splice(_loc3_,1);
               _loc2_++;
            }
         }
      }
      
      public function putRandomLoot() : *
      {
         var _loc1_:int = Math.floor(Math.random() * (this.spaceX - 2) + 1);
         var _loc2_:int = Math.floor(Math.random() * (this.spaceY - 2) + 1);
         if(this.space[_loc1_][_loc2_].phis == 0)
         {
            LootGen.lootCont(this,(_loc1_ + 0.5) * Tile.tileX,(_loc2_ + 0.8) * Tile.tileY,"metal");
         }
      }
      
      public function createUnit(param1:String, param2:int, param3:int, param4:Boolean = false, param5:XML = null, param6:String = null, param7:int = 0) : Unit
      {
         var _loc9_:Unit = null;
         var _loc10_:String = null;
         var _loc14_:* = undefined;
         var _loc15_:* = undefined;
         if(param1 == "mines")
         {
            this.createUnit("mine",param2,param3);
            this.createUnit("mine",param2 + 2,param3);
            this.createUnit("mine",param2 + 4,param3);
            return null;
         }
         if(this.land.rnd && param1 == "transm")
         {
            if((param5 == null || param5.@on.length() == 0) && Math.random() < 0.5)
            {
               return null;
            }
         }
         if(Boolean(param5) && Boolean(param5.@trigger.length()) && World.w.game.triggers[param5.@trigger] == "1")
         {
            return null;
         }
         var _loc8_:Object = null;
         if(Boolean(param5) && Boolean(param5.@code.length()) && World.w.game.objs.hasOwnProperty(param5.@code))
         {
            _loc8_ = World.w.game.objs[param5.@code];
         }
         if(Boolean(_loc8_) && Boolean(_loc8_.dead > 0) && _loc8_.loot != 2)
         {
            return null;
         }
         var _loc11_:int = 0;
         var _loc12_:Boolean = false;
         if((this.biom == 1 || this.biom == 5) && param4 == false)
         {
            _loc12_ = this.getTile(param2,param3).water > 0;
         }
         var _loc13_:String = this.randomUnit(param1,_loc12_);
         if(_loc13_ != "")
         {
            if(param6)
            {
               _loc10_ = param6;
            }
            else
            {
               _loc10_ = this.randomCid(_loc13_);
            }
            if(_loc13_ == "slmine")
            {
               _loc13_ = "slime";
            }
            _loc9_ = Unit.create(_loc13_,this.locDifLevel,param5,_loc8_,_loc10_);
         }
         if(_loc13_ == "" && !this.homeStable || _loc9_ == null)
         {
            if(param6)
            {
               _loc10_ = param6;
            }
            else
            {
               _loc10_ = this.randomCid(param1);
            }
            _loc9_ = Unit.create(param1,this.locDifLevel,param5,_loc8_,_loc10_);
         }
         if(_loc9_ != null)
         {
            _loc14_ = this.enemyLevel;
            if(this.land.rnd && this.landProb == "")
            {
               if(Math.random() < Math.min(0.05,this.locDifLevel / 100 + 0.02))
               {
                  _loc11_ = Math.floor(Math.random() * 4 + 1);
               }
            }
            if(_loc11_ == 0 && _loc9_.boss == false)
            {
               _loc14_ = Math.round(_loc14_ * (1.1 - Math.random() * 0.4));
            }
            _loc9_.setLevel(_loc14_);
            _loc9_.setHero(_loc11_);
            if(param4)
            {
               _loc9_.putLoc(this,param2,param3);
            }
            else
            {
               _loc15_ = Math.floor((_loc9_.scX - 1) / 40) + 1;
               _loc9_.putLoc(this,(param2 + 0.5 * _loc15_) * Tile.tileX,(param3 + 1) * Tile.tileY - 1);
            }
            if(this.active)
            {
               _loc9_.xp = 0;
            }
            else
            {
               this.summXp += _loc9_.xp;
            }
            this.addObj(_loc9_);
            this.units.push(_loc9_);
            if(this.homeStable)
            {
               _loc9_.fraction = Unit.F_PLAYER;
               _loc9_.warn = 0;
            }
            if(this.homeAtk)
            {
               if(_loc9_ is UnitTurret)
               {
                  (_loc9_ as UnitTurret).hack(2);
               }
               else if(Math.random() < 0.5)
               {
                  this.backobjs.push(new BackObj(this,"blood1",param2 * Tile.tileX,(param3 - Math.random() * 4) * Tile.tileY));
               }
            }
            if(Boolean(param5) && Boolean(param5.@code.length()))
            {
               this.saves.push(_loc9_);
            }
            if(Boolean(param5) && Boolean(param5.@uid.length()))
            {
               _loc9_.uid = param5.@uid;
               this.land.uidObjs[_loc9_.uid] = _loc9_;
            }
            if(param7 > 0)
            {
               _loc9_.emergence(param7);
            }
            _loc9_.step();
         }
         return _loc9_;
      }
      
      internal function createPhoenix(param1:Box) : Boolean
      {
         if(Boolean(param1.wall) || !param1.shelf)
         {
            return false;
         }
         if(this.collisionUnit(param1.X,param1.Y1 - 1,38,38))
         {
            return false;
         }
         var _loc2_:Unit = new UnitPhoenix();
         _loc2_.putLoc(this,param1.X,param1.Y1 - 1);
         this.addObj(_loc2_);
         this.units.push(_loc2_);
         ++this.kol_phoenix;
         ++this.land.kol_phoenix;
         return true;
      }
      
      internal function createTransmitter(param1:Box) : Boolean
      {
         if(Boolean(param1.wall) || !param1.shelf)
         {
            return false;
         }
         if(this.land.rnd && Math.random() < 0.5)
         {
            return false;
         }
         if(this.collisionUnit(param1.X,param1.Y1 - 1,30,20))
         {
            return false;
         }
         var _loc2_:Unit = new UnitTransmitter("box");
         _loc2_.setLevel(this.enemyLevel);
         _loc2_.putLoc(this,param1.X,param1.Y1 - 1);
         this.addObj(_loc2_);
         this.units.push(_loc2_);
         return true;
      }
      
      internal function createSur(param1:Box, param2:String = null) : *
      {
         if(param2 == null)
         {
            if(Math.random() > 0.25)
            {
               return;
            }
            if(this.biom == 0)
            {
               param2 = "fan";
            }
            if(this.biom == 2)
            {
               param2 = "lamp";
            }
            if(this.biom == 3)
            {
               param2 = "kofe";
            }
            if(param2 == null)
            {
               return;
            }
         }
         var _loc3_:Item = new Item(null,param2,1);
         var _loc4_:Loot = new Loot(this,_loc3_,param1.X,param1.Y - param1.scY - 3,false,false,false);
         if(this.base)
         {
            _loc4_.inter.active = false;
            _loc4_.levitPoss = false;
         }
      }
      
      public function createHidden(param1:int, param2:int) : *
      {
         if(this.biom == 10 || this.biom == 11)
         {
            return;
         }
         if(this.tipEnemy == 0)
         {
            this.createUnit("zombie",param1,param2,false,<unit dig='2'/>);
         }
         else if(this.tipEnemy == 2)
         {
            this.createObj("robocell","box",param1,param2);
         }
         else if(this.tipEnemy == 1 || this.tipEnemy == 3)
         {
            this.createObj("alarm","box",param1,param2);
         }
         else if(this.tipEnemy == 6)
         {
            this.createUnit("lov",param1,param2);
         }
      }
      
      public function createClouds(param1:int, param2:String = null) : *
      {
         var _loc3_:int = 0;
         var _loc4_:* = undefined;
         var _loc5_:int = 0;
         var _loc6_:int = 0;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         if(param2 == null)
         {
            if(this.biom == 1)
            {
               param2 = "tcloud1";
               if(param1 >= 2)
               {
                  return;
               }
            }
            if(this.biom == 5)
            {
               param2 = "pcloud1";
            }
         }
         if(param2 != null)
         {
            _loc3_ = 1;
            if(this.biom == 1)
            {
               _loc3_ = Math.random() * 5;
            }
            if(this.biom == 5)
            {
               if(param1 == 0)
               {
                  _loc3_ = Math.random() * 2;
               }
               else
               {
                  _loc3_ = Math.random() * 3;
               }
            }
            _loc4_ = 0;
            for(; _loc4_ < _loc3_; _loc4_++)
            {
               _loc5_ = Math.floor(Math.random() * (this.spaceX - 4) + 2);
               _loc6_ = Math.floor(Math.random() * (this.spaceY - 4) + 2);
               if(this.cp)
               {
                  _loc7_ = this.cp.X - (_loc5_ * World.tileX + 20);
                  _loc8_ = this.cp.Y - (_loc6_ * World.tileY + 40);
                  if(_loc7_ * _loc7_ + _loc8_ * _loc8_ < 80 * 80)
                  {
                     continue;
                  }
               }
               if(this.biom == 1 && param1 == 1 && _loc6_ > 15)
               {
                  _loc6_ = 15;
               }
               if(this.biom == 5 && param1 == 0)
               {
                  _loc6_ = Math.floor(Math.random() * 15 + 9);
               }
               this.createObj(param2,"box",_loc5_,_loc6_);
            }
         }
      }
      
      public function randomUnit(param1:String, param2:Boolean = false) : String
      {
         var _loc3_:String = "";
         switch(param1)
         {
            case "enl2":
               if(this.biom == 10)
               {
                  _loc3_ = "stabpon";
               }
               else if(this.tipEnemy == 0)
               {
                  _loc3_ = "zombie";
               }
               else if(this.tipEnemy == 2)
               {
                  if(this.biom == 2 && this.locDifLevel >= 12 && Math.random() < Math.min(this.locDifLevel / 100,0.15))
                  {
                     _loc3_ = "eqd";
                  }
                  else if(this.locDifLevel >= 5 && Math.random() < 0.1)
                  {
                     _loc3_ = "landturret";
                  }
                  else if(this.locDifLevel >= 6 && Math.random() < Math.min(this.locDifLevel / 40,0.3))
                  {
                     _loc3_ = "gutsy";
                  }
                  else if(this.locDifLevel >= 2 && Math.random() < Math.min(this.locDifLevel / 10,0.5))
                  {
                     _loc3_ = "protect";
                  }
                  else
                  {
                     _loc3_ = "robot";
                  }
               }
               else if(this.tipEnemy == 3)
               {
                  _loc3_ = "slaver";
               }
               else if(this.tipEnemy == 4)
               {
                  _loc3_ = "merc";
               }
               else if(this.tipEnemy == 5)
               {
                  _loc3_ = "alicorn";
               }
               else if(this.tipEnemy == 6)
               {
                  _loc3_ = "zebra";
               }
               else if(this.tipEnemy == 7)
               {
                  if(Math.random() < 0.4)
                  {
                     if(Math.random() < 0.5)
                     {
                        _loc3_ = "gutsy";
                     }
                     else
                     {
                        _loc3_ = "protect";
                     }
                  }
                  else
                  {
                     _loc3_ = "ranger";
                  }
               }
               else if(this.tipEnemy == 8)
               {
                  if(Math.random() < 0.75)
                  {
                     _loc3_ = "zombie";
                  }
                  else
                  {
                     _loc3_ = "necros";
                  }
               }
               else if(this.tipEnemy == 9)
               {
                  if(Math.random() < 0.1)
                  {
                     _loc3_ = "hellhound";
                  }
                  else if(Math.random() < 0.07)
                  {
                     _loc3_ = "landturret";
                  }
                  else
                  {
                     _loc3_ = "encl";
                  }
               }
               else if(this.tipEnemy == 10)
               {
                  _loc3_ = "hellhound";
               }
               else if(this.tipEnemy == 11)
               {
                  if(Math.random() < 0.3)
                  {
                     _loc3_ = "hellhound";
                  }
                  else
                  {
                     _loc3_ = "encl";
                  }
               }
               else
               {
                  _loc3_ = "raider";
               }
               break;
            case "enl1":
               if(this.biom == 10 || this.biom == 11)
               {
                  return "";
               }
               if((this.biom == 1 || this.biom == 5) && param2)
               {
                  _loc3_ = "fish";
               }
               else if(this.biom == 5)
               {
                  if(Math.random() < 0.3)
                  {
                     _loc3_ = "scorp3";
                  }
                  else
                  {
                     _loc3_ = "slime";
                  }
               }
               else if(this.biom == 6)
               {
                  _loc3_ = "roller";
               }
               else if(this.tipEnemy == 2 && this.locDifLevel >= 4 || this.tipEnemy == 7 || this.tipEnemy == 9 || this.tipEnemy == 10)
               {
                  if((this.landX + this.landY) % 2 == 0)
                  {
                     _loc3_ = "roller";
                  }
                  else
                  {
                     _loc3_ = "msp";
                  }
               }
               else if(this.tipEnemy == 0 || this.tipEnemy == 5 || this.tipEnemy == 6)
               {
                  if(this.locDifLevel >= 2 && Math.random() < Math.min(this.locDifLevel / 30,0.5))
                  {
                     _loc3_ = "scorp";
                  }
                  else if((this.landX + this.landY) % 2 == 0)
                  {
                     _loc3_ = "slime";
                  }
                  else
                  {
                     _loc3_ = "ant";
                  }
                  if(this.biom == 1 && Math.random() < 0.25)
                  {
                     _loc3_ = "rat";
                  }
               }
               else if(this.locDifLevel >= 2 && Math.random() < Math.min(this.locDifLevel / 30,0.5))
               {
                  _loc3_ = "molerat";
               }
               else if(Math.random() < 0.6)
               {
                  _loc3_ = "tarakan";
               }
               else
               {
                  _loc3_ = "rat";
               }
               break;
            case "enc1":
               if(this.biom == 10)
               {
                  _loc3_ = "turret";
               }
               else if((this.biom == 1 || this.biom == 5) && param2)
               {
                  _loc3_ = "fish";
               }
               else if(this.biom == 5)
               {
                  if((this.landX + this.landY) % 2 == 0)
                  {
                     _loc3_ = "bloodwing";
                  }
                  else
                  {
                     _loc3_ = "slime";
                  }
               }
               else if(this.biom == 6 || this.biom == 4)
               {
                  _loc3_ = "cturret";
               }
               else if(this.tipEnemy == 0 || this.tipEnemy == 5 || this.tipEnemy == 6)
               {
                  if(this.biom == 1 && Math.random() < 0.6)
                  {
                     _loc3_ = "slime";
                  }
                  else
                  {
                     _loc3_ = "bloodwing";
                  }
               }
               else
               {
                  _loc3_ = "turret";
               }
               break;
            case "enf1":
               if(this.biom == 10)
               {
                  return "";
               }
               if((this.biom == 1 || this.biom == 5) && param2)
               {
                  _loc3_ = "fish";
               }
               else if(this.biom == 5)
               {
                  _loc3_ = "bloat";
               }
               else if(this.tipEnemy == 0 || this.tipEnemy == 5)
               {
                  _loc3_ = "bloat";
               }
               else if((this.tipEnemy == 1 || this.tipEnemy == 3 || this.tipEnemy == 4 || this.tipEnemy == 6) && this.locDifLevel >= 3)
               {
                  _loc3_ = "vortex";
               }
               else if(this.tipEnemy == 2 && this.locDifLevel >= 3)
               {
                  _loc3_ = "spritebot";
               }
               else if(this.tipEnemy == 11 || this.tipEnemy == 7 || this.tipEnemy == 9 || this.tipEnemy == 10 || this.tipEnemy == 2 && this.locDifLevel > 10 && Math.random() < Math.min(this.locDifLevel / 40,0.5))
               {
                  _loc3_ = "dron";
               }
               break;
            case "lov":
               if(this.biom == 10 || this.biom == 11)
               {
                  return "";
               }
               if(this.biom == 5)
               {
                  _loc3_ = "slmine";
               }
               else if(this.tipEnemy == 0)
               {
                  if((this.landX + this.landY) % 2 == 0)
                  {
                     _loc3_ = "slmine";
                  }
                  else
                  {
                     _loc3_ = "trap";
                  }
               }
               else if((this.tipEnemy == 1 || this.tipEnemy == 3 || this.tipEnemy == 4 || this.tipEnemy == 6) && (this.landX + this.landY) % 2 == 0)
               {
                  if(this.locDifLevel >= 10 && Math.random() < 0.5)
                  {
                     _loc3_ = "trridge";
                  }
                  else if(Math.random() < 0.5)
                  {
                     _loc3_ = "trplate";
                  }
                  else
                  {
                     _loc3_ = "trcans";
                  }
               }
               else if((this.biom == 2 && this.tipEnemy == 2 || this.tipEnemy == 7 || this.tipEnemy == 9) && (this.landX + this.landY) % 2 == 0)
               {
                  _loc3_ = "trlaser";
               }
               else
               {
                  _loc3_ = "mine";
               }
         }
         return _loc3_;
      }
      
      public function randomCid(param1:String) : String
      {
         var _loc2_:int = 0;
         switch(param1)
         {
            case "raider":
               if(this.locDifLevel >= 5)
               {
                  _loc2_ = Math.floor(Math.random() * 9 + 1);
               }
               else if(this.locDifLevel >= 2)
               {
                  _loc2_ = Math.floor(Math.random() * 5 + 1);
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               return _loc2_.toString();
            case "slaver":
               if(this.locDifLevel >= 18)
               {
                  _loc2_ = Math.floor(Math.random() * 6 + 1);
               }
               else if(this.locDifLevel >= 15)
               {
                  _loc2_ = Math.floor(Math.random() * 5 + 1);
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 4 + 1);
               }
               return _loc2_.toString();
            case "zebra":
               if(this.locDifLevel >= 15)
               {
                  _loc2_ = Math.floor(Math.random() * 4 + 1);
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               if(this.locDifLevel >= 25 && Math.random() < 0.1)
               {
                  _loc2_ = 5;
               }
               return _loc2_.toString();
            case "ranger":
               if(this.land.act.conf == 7)
               {
                  _loc2_ = Math.floor(Math.random() * 3 + 1);
               }
               else if(this.landY == 0)
               {
                  _loc2_ = 1;
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               return _loc2_.toString();
            case "merc":
               if(this.locDifLevel >= 19)
               {
                  _loc2_ = Math.floor(Math.random() * 5 + 1);
               }
               else if(this.locDifLevel >= 15 && Math.random() > 0.5)
               {
                  _loc2_ = Math.floor(Math.random() * 4 + 1);
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               return _loc2_.toString();
            case "encl":
               _loc2_ = Math.floor(Math.random() * 4 + 1);
               return _loc2_.toString();
            case "protect":
               if(this.tipEnemy == 7)
               {
                  _loc2_ = 1;
               }
               return _loc2_.toString();
            case "gutsy":
               if(this.tipEnemy == 7)
               {
                  _loc2_ = 1;
               }
               return _loc2_.toString();
            case "dron":
               if(this.tipEnemy == 9)
               {
                  _loc2_ = Math.floor(Math.random() * 4 + 1);
                  if(_loc2_ > 3)
                  {
                     _loc2_ = 3;
                  }
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               return _loc2_.toString();
            case "roller":
               if(this.biom == 6)
               {
                  _loc2_ = 2;
               }
               else
               {
                  _loc2_ = 1;
               }
               return _loc2_.toString();
            case "zombie":
               if(this.biom == 5)
               {
                  if(this.locDifLevel >= 20 && Math.random() < 0.1)
                  {
                     _loc2_ = 9;
                  }
                  else
                  {
                     _loc2_ = Math.floor(Math.random() * 4 + 5);
                  }
               }
               else if(this.biom >= 1 && this.locDifLevel >= 8)
               {
                  _loc2_ = Math.floor(Math.random() * 7);
               }
               else if(this.locDifLevel >= 5)
               {
                  _loc2_ = Math.floor(Math.random() * 5);
               }
               else if(this.locDifLevel >= 2)
               {
                  _loc2_ = Math.floor(Math.random() * 4);
               }
               else
               {
                  _loc2_ = 0;
               }
               return _loc2_.toString();
            case "alicorn":
               _loc2_ = Math.floor(Math.random() * 3 + 1);
               return _loc2_.toString();
            case "hellhound":
               _loc2_ = 1;
               return _loc2_.toString();
            case "bloat":
               if(this.biom == 5)
               {
                  _loc2_ = Math.floor(Math.random() * 3 + 4);
               }
               else if(this.locDifLevel >= 10)
               {
                  _loc2_ = Math.floor(Math.random() * 5);
               }
               else if(this.locDifLevel >= 4)
               {
                  _loc2_ = Math.floor(Math.random() * 4);
               }
               else if(this.locDifLevel >= 2)
               {
                  _loc2_ = Math.floor(Math.random() * 3);
               }
               else
               {
                  _loc2_ = 0;
               }
               return _loc2_.toString();
            case "ant":
               if(this.biom >= 1 && this.locDifLevel >= 6)
               {
                  _loc2_ = Math.floor(Math.random() * 3 + 1);
               }
               else if(this.locDifLevel >= 3)
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               else
               {
                  _loc2_ = 1;
               }
               return _loc2_.toString();
            case "fish":
               if(this.biom == 5)
               {
                  _loc2_ = 3;
               }
               else
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               return _loc2_.toString();
            case "slime":
               if(this.biom == 5)
               {
                  _loc2_ = 2;
               }
               else
               {
                  _loc2_ = 0;
               }
               return _loc2_.toString();
            case "slmine":
               if(this.biom == 5)
               {
                  _loc2_ = 12;
               }
               else
               {
                  _loc2_ = 10;
               }
               return _loc2_.toString();
            case "bloodwing":
               if(this.biom == 5)
               {
                  _loc2_ = 2;
               }
               else
               {
                  _loc2_ = 1;
               }
               return _loc2_.toString();
            case "scorp":
               if(this.locDifLevel >= 5)
               {
                  _loc2_ = Math.floor(Math.random() * 2 + 1);
               }
               else
               {
                  _loc2_ = 1;
               }
               return "scorp" + _loc2_;
            case "mine":
               if(this.biom == 4)
               {
                  return "plamine";
               }
               if(this.biom == 2 && Math.random() < Math.min(this.locDifLevel / 20,0.4))
               {
                  return "plamine";
               }
               if(Math.random() < Math.min(this.locDifLevel / 20,0.75))
               {
                  return "mine";
               }
               return "hmine";
               break;
            default:
               return null;
         }
      }
      
      public function createObj(param1:String, param2:String, param3:int, param4:int, param5:XML = null) : Obj
      {
         var obj:Obj = null;
         var size:int = 0;
         var loadObj:Object = null;
         var id:String = param1;
         var tip:String = param2;
         var nx:int = param3;
         var ny:int = param4;
         var xml:XML = param5;
         size = int(AllData.d.obj.(@id == id).@size);
         if(size <= 0)
         {
            size = 1;
         }
         loadObj = null;
         if(Boolean(xml) && Boolean(xml.@code.length()) && World.w.game.objs.hasOwnProperty(xml.@code))
         {
            loadObj = World.w.game.objs[xml.@code];
         }
         if(tip == "box" || tip == "door")
         {
            obj = new Box(this,id,(nx + 0.5 * size) * Tile.tileX,(ny + 1) * Tile.tileY - 1,xml,loadObj);
            this.objs.push(obj);
            if(obj is Box && Boolean((obj as Box).un))
            {
               this.units.push((obj as Box).un);
            }
            if(Boolean(xml) && Boolean(xml.@ph == "1") && !World.w.game.triggers["pet_phoenix"])
            {
               this.createPhoenix(obj as Box);
            }
            if(Boolean(xml) && xml.@transm == "1")
            {
               this.createTransmitter(obj as Box);
            }
            if(this.land.rnd && this.land.act.biom == 0 && !World.w.game.triggers["pet_phoenix"] && this.kol_phoenix == 0 && this.land.kol_phoenix < 3 && Math.random() < 0.02)
            {
               this.createPhoenix(obj as Box);
            }
            if(Boolean(obj is Box) && Boolean((obj as Box).sur) && this.land.rnd)
            {
               this.createSur(obj as Box);
            }
            if(Boolean(!this.land.rnd) && Boolean(xml) && Boolean(xml.@sur.length()))
            {
               this.createSur(obj as Box,xml.@sur);
            }
            if(obj is Box && (obj as Box).electroDam > this.electroDam && !obj.inter.open)
            {
               this.electroDam = (obj as Box).electroDam;
            }
         }
         else if(tip == "trap")
         {
            obj = new Trap(this,id,(nx + 0.5 * size) * Tile.tileX,(ny + 1) * Tile.tileY - 1);
         }
         else if(tip == "checkpoint")
         {
            obj = new CheckPoint(this,id,(nx + 0.5 * size) * Tile.tileX,(ny + 1) * Tile.tileY - 1,xml,loadObj);
            if(World.w.game.globalDif <= 1 || this.land.rnd && World.w.game.globalDif == 2 && Math.random() < 0.33)
            {
               (obj as CheckPoint).teleOn = true;
            }
            this.acts.push(obj);
         }
         else if(tip == "area")
         {
            obj = new Area(this,xml,loadObj,this.mirror);
            this.areas.push(obj);
         }
         else if(tip == "bonus")
         {
            obj = new Bonus(this,id,(nx + 0.5) * Tile.tileX,(ny + 0.5) * Tile.tileY,xml,loadObj);
            this.bonuses.push(obj);
         }
         if(Boolean(xml) && Boolean(xml.@code.length()))
         {
            this.saves.push(obj);
            obj.code = xml.@code;
            if(tip == "checkpoint" && !this.land.rnd)
            {
               if(World.w.pers.currentCPCode != null && obj.code == World.w.pers.currentCPCode || World.w.pers.prevCPCode != null && obj.code == World.w.pers.prevCPCode || this.land.act.lastCpCode == obj.code)
               {
                  this.land.currentCP = obj as CheckPoint;
               }
            }
         }
         if(Boolean(xml) && Boolean(xml.@uid.length()))
         {
            obj.uid = xml.@uid;
            this.land.uidObjs[obj.uid] = obj;
         }
         if(Boolean(xml) && Boolean(xml.@nazv.length()))
         {
            obj.nazv = xml.@nazv;
         }
         if(Boolean(this.landProb == "") && Boolean(xml) && Boolean(xml.@prob.length()) && xml.@prob != "")
         {
            this.land.probIds.push(xml.@prob);
         }
         this.addObj(obj);
         return obj;
      }
      
      public function createCheck(param1:Boolean = false) : *
      {
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         if(this.spawnPoints.length > 0)
         {
            _loc2_ = this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)];
            _loc3_ = "checkpoint";
            if(!param1 && this.land.rnd && Math.random() < 0.5)
            {
               _loc3_ += Math.floor(Math.random() * 5 + 1);
            }
            this.cp = this.createObj(_loc3_,"checkpoint",_loc2_.x,_loc2_.y) as CheckPoint;
            if(this.land.act.landStage == 0 && param1)
            {
               this.cp.teleOn = true;
            }
            if(param1)
            {
               this.cp.activate(true);
            }
            this.isCheck = true;
         }
      }
      
      public function createExit(param1:String = "") : *
      {
         var _loc2_:* = undefined;
         if(this.spawnPoints.length > 0)
         {
            _loc2_ = this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)];
            this.createObj("exit","box",_loc2_.x,_loc2_.y,<obj name='exit' prob={this.land.act.exitProb + param1} time='20' inter='8' sign='1'/>);
            this.isCheck = true;
         }
      }
      
      public function createDoorProb(param1:String, param2:String) : Boolean
      {
         var _loc3_:* = undefined;
         if(this.spawnPoints.length > 0)
         {
            _loc3_ = this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)];
            this.createObj(param1,"box",_loc3_.x,_loc3_.y,<obj prob={param2} nazv={Res.txt("m",param2)} time='20' inter='8'/>);
            this.isCheck = true;
            return true;
         }
         return false;
      }
      
      public function createXpBonuses(param1:int = 5) : *
      {
         var _loc2_:int = 0;
         var _loc3_:int = 0;
         var _loc4_:int = 0;
         var _loc5_:int = 0;
         var _loc6_:int = 0;
         var _loc7_:int = 0;
         if(this.homeStable || this.homeAtk)
         {
            return;
         }
         var _loc8_:* = 4;
         var _loc9_:int = 5;
         this.maxXp = param1;
         var _loc10_:* = 1;
         while(_loc10_ <= 100)
         {
            _loc4_ = 2;
            _loc6_ = 2;
            _loc5_ = this.spaceX - 2;
            _loc7_ = this.spaceY - 2;
            if(_loc8_ == 4)
            {
               _loc5_ = this.spaceX / 2;
               _loc7_ = this.spaceY / 2;
            }
            else if(_loc8_ == 3)
            {
               _loc4_ = this.spaceX / 2;
               _loc7_ = this.spaceY / 2;
            }
            else if(_loc8_ == 2)
            {
               _loc5_ = this.spaceX / 2;
               _loc6_ = this.spaceY / 2;
            }
            else if(_loc8_ == 1)
            {
               _loc4_ = this.spaceX / 2;
               _loc6_ = this.spaceY / 2;
            }
            _loc2_ = Math.floor(_loc4_ + Math.random() * (_loc5_ - _loc4_));
            _loc3_ = Math.floor(_loc6_ + Math.random() * (_loc7_ - _loc6_));
            if(this.getTile(_loc2_,_loc3_).phis == 0 && (this.getTile(_loc2_ - 1,_loc3_).phis == 0 || this.getTile(_loc2_ + 1,_loc3_).phis == 0))
            {
               this.createObj("xp","bonus",_loc2_,_loc3_);
               ++this.kolXp;
               if(_loc8_ > 0)
               {
                  _loc8_--;
               }
               if(this.kolXp >= param1)
               {
                  return;
               }
            }
            else if(--_loc9_ <= 0)
            {
               _loc9_ = 5;
               if(_loc8_ > 0)
               {
                  _loc8_--;
               }
            }
            _loc10_++;
         }
      }
      
      public function preStep() : *
      {
         var _loc1_:* = 0;
         while(_loc1_ < 30)
         {
            this.stepInvis();
            _loc1_++;
         }
      }
      
      public function reactivate(param1:int = 0) : *
      {
         var _loc2_:Pt = this.firstObj;
         while(_loc2_)
         {
            this.nextObj = _loc2_.nobj;
            _loc2_.setNull(param1 - this.nAct > 2 || param1 == 0 || Boolean(this.prob) && !this.prob.closed);
            _loc2_ = this.nextObj;
         }
         this.resetUnits();
         if(param1 > 0)
         {
            this.nAct = param1;
         }
         this.showSign(false);
         this.active = true;
         this.visited = true;
         this.warning = 0;
         if(this.prob)
         {
            this.prob.over();
         }
         Snd.resetShum();
      }
      
      public function resetUnits() : *
      {
         this.units = this.units.filter(this.isAct);
      }
      
      private function isAct(param1:*, param2:int, param3:Array) : Boolean
      {
         if(param1 == null)
         {
            return false;
         }
         if(param1 is UnitPet)
         {
            return true;
         }
         return param1.sost < 4;
      }
      
      public function out() : *
      {
         var _loc1_:Unit = null;
         this.active = false;
         for each(_loc1_ in this.units)
         {
            _loc1_.locout();
         }
         if(this.prob)
         {
            this.prob.out();
         }
      }
      
      public function addObj(param1:Pt) : *
      {
         if(param1.in_chain)
         {
            return;
         }
         if(!this.firstObj)
         {
            this.firstObj = param1;
         }
         else
         {
            this.lastObj.nobj = param1;
            param1.pobj = this.lastObj;
         }
         param1.nobj = null;
         this.lastObj = param1;
         param1.in_chain = true;
         if(this.active)
         {
            param1.addVisual();
         }
      }
      
      public function remObj(param1:Pt) : *
      {
         if(!param1.in_chain)
         {
            return;
         }
         if(param1.nobj)
         {
            param1.nobj.pobj = param1.pobj;
         }
         else
         {
            this.lastObj = param1.pobj;
         }
         if(param1.pobj)
         {
            param1.pobj.nobj = param1.nobj;
         }
         else
         {
            this.firstObj = param1.nobj;
         }
         param1.in_chain = false;
         param1.nobj = param1.pobj = null;
         param1.remVisual();
      }
      
      public function getTile(param1:int, param2:int) : Tile
      {
         if(param1 < 0 || param1 >= this.spaceX || param2 < 0 || param2 >= this.spaceY)
         {
            return this.otstoy;
         }
         return this.space[param1][param2] as Tile;
      }
      
      public function getAbsTile(param1:int, param2:int) : Tile
      {
         if(param1 < 0 || param1 >= this.spaceX * Tile.tileX || param2 < 0 || param2 >= this.spaceY * Tile.tileY)
         {
            return this.otstoy;
         }
         return this.space[Math.floor(param1 / Tile.tileX)][Math.floor(param2 / Tile.tileY)] as Tile;
      }
      
      public function collisionUnit(param1:Number, param2:Number, param3:Number = 0, param4:Number = 0) : Boolean
      {
         var _loc9_:* = undefined;
         var _loc5_:* = param1 - param3 / 2;
         var _loc6_:* = param1 + param3 / 2;
         var _loc7_:* = param2 - param4;
         var _loc8_:* = Math.floor(_loc5_ / Tile.tileX);
         while(_loc8_ <= Math.floor(_loc6_ / Tile.tileX))
         {
            _loc9_ = Math.floor(_loc7_ / Tile.tileY);
            while(_loc9_ <= Math.floor(param2 / Tile.tileY))
            {
               if(!(_loc8_ < 0 || _loc8_ >= this.spaceX || _loc9_ < 0 || _loc9_ >= this.spaceY))
               {
                  if(this.space[_loc8_][_loc9_].phis > 0)
                  {
                     return true;
                  }
               }
               _loc9_++;
            }
            _loc8_++;
         }
         return false;
      }
      
      public function isLine(param1:Number, param2:Number, param3:Number, param4:Number, param5:Obj = null) : Boolean
      {
         var _loc10_:Tile = null;
         var _loc6_:* = param3 - param1;
         var _loc7_:* = param4 - param2;
         var _loc8_:* = Math.floor(Math.max(Math.abs(_loc6_),Math.abs(_loc7_)) / World.maxdelta) + 1;
         var _loc9_:* = 1;
         while(_loc9_ < _loc8_)
         {
            _loc10_ = World.w.loc.getAbsTile(Math.floor(param1 + _loc6_ * _loc9_ / _loc8_),Math.floor(param2 + _loc7_ * _loc9_ / _loc8_));
            if(_loc10_.phis == 1 && param1 + _loc6_ * _loc9_ / _loc8_ >= _loc10_.phX1 && param1 + _loc6_ * _loc9_ / _loc8_ <= _loc10_.phX2 && param2 + _loc7_ * _loc9_ / _loc8_ >= _loc10_.phY1 && param2 + _loc7_ * _loc9_ / _loc8_ <= _loc10_.phY2)
            {
               if(param5 == null || _loc10_.door != param5)
               {
                  return false;
               }
            }
            _loc9_++;
         }
         return true;
      }
      
      public function tileKontur(param1:int, param2:int, param3:Tile) : *
      {
         var _loc4_:Boolean = false;
         var _loc5_:Boolean = false;
         var _loc6_:Boolean = false;
         var _loc7_:Boolean = false;
         var _loc8_:Boolean = false;
         var _loc9_:Boolean = false;
         var _loc10_:Boolean = false;
         var _loc11_:Boolean = false;
         var _loc12_:String = null;
         var _loc13_:Boolean = false;
         if(param3.phis == 1)
         {
            _loc4_ = this.uslKontur(param1 - 1,param2 - 1);
            _loc5_ = this.uslKontur(param1,param2 - 1);
            _loc6_ = this.uslKontur(param1 + 1,param2 - 1);
            _loc7_ = this.uslKontur(param1 + 1,param2);
            _loc8_ = this.uslKontur(param1 + 1,param2 + 1);
            _loc9_ = this.uslKontur(param1,param2 + 1);
            _loc10_ = this.uslKontur(param1 - 1,param2 + 1);
            _loc11_ = this.uslKontur(param1 - 1,param2);
            param3.kont1 = this.insKontur(_loc5_,_loc11_,_loc4_);
            param3.kont2 = this.insKontur(_loc5_,_loc7_,_loc6_);
            param3.kont3 = this.insKontur(_loc9_,_loc11_,_loc10_);
            param3.kont4 = this.insKontur(_loc9_,_loc7_,_loc8_);
            if(_loc12_ != "")
            {
               if(!_loc5_)
               {
                  _loc5_ = this.uslPontur(param1,param2 - 1);
               }
               if(!_loc7_)
               {
                  _loc7_ = this.uslPontur(param1 + 1,param2);
               }
               if(!_loc9_)
               {
                  _loc9_ = this.uslPontur(param1,param2 + 1);
               }
               if(!_loc11_)
               {
                  _loc11_ = this.uslPontur(param1 - 1,param2);
               }
               param3.pont1 = this.insKontur(_loc5_,_loc11_,_loc4_);
               param3.pont2 = this.insKontur(_loc5_,_loc7_,_loc6_);
               param3.pont3 = this.insKontur(_loc9_,_loc11_,_loc10_);
               param3.pont4 = this.insKontur(_loc9_,_loc7_,_loc8_);
            }
         }
         else
         {
            _loc12_ = param3.back;
            _loc13_ = this.backwall == "sky";
            _loc4_ = this.uslBontur(param1 - 1,param2 - 1,_loc12_,_loc13_);
            _loc5_ = this.uslBontur(param1,param2 - 1,_loc12_,_loc13_);
            _loc6_ = this.uslBontur(param1 + 1,param2 - 1,_loc12_,_loc13_);
            _loc7_ = this.uslBontur(param1 + 1,param2,_loc12_,_loc13_);
            _loc8_ = this.uslBontur(param1 + 1,param2 + 1,_loc12_,_loc13_);
            _loc9_ = this.uslBontur(param1,param2 + 1,_loc12_,_loc13_);
            _loc10_ = this.uslBontur(param1 - 1,param2 + 1,_loc12_,_loc13_);
            _loc11_ = this.uslBontur(param1 - 1,param2,_loc12_,_loc13_);
            param3.pont1 = this.insKontur(_loc5_,_loc11_,_loc4_);
            param3.pont2 = this.insKontur(_loc5_,_loc7_,_loc6_);
            param3.pont3 = this.insKontur(_loc9_,_loc11_,_loc10_);
            param3.pont4 = this.insKontur(_loc9_,_loc7_,_loc8_);
         }
      }
      
      private function insKontur(param1:Boolean, param2:Boolean, param3:Boolean) : int
      {
         if(param1 && param2)
         {
            return param3 ? 0 : 1;
         }
         if(!param1 && param2)
         {
            return 2;
         }
         if(param1 && !param2)
         {
            return 3;
         }
         return 4;
      }
      
      private function uslKontur(param1:int, param2:int) : Boolean
      {
         if(param1 < 0 || param1 >= this.spaceX || param2 < 0 || param2 >= this.spaceY)
         {
            return true;
         }
         return this.space[param1][param2].phis == 1 || this.space[param1][param2].door != null;
      }
      
      private function uslPontur(param1:int, param2:int) : Boolean
      {
         if(param1 < 0 || param1 >= this.spaceX || param2 < 0 || param2 >= this.spaceY)
         {
            return true;
         }
         return this.space[param1][param2].back != "" || this.space[param1][param2].shelf > 0;
      }
      
      private function uslBontur(param1:int, param2:int, param3:String = "", param4:Boolean = false) : Boolean
      {
         if(param1 < 0 || param1 >= this.spaceX || param2 < 0 || param2 >= this.spaceY)
         {
            return true;
         }
         return this.space[param1][param2].back == param3 || param4 && this.space[param1][param2].back != "" || this.space[param1][param2].phis == 1 || this.space[param1][param2].shelf > 0;
      }
      
      public function hitTile(param1:Tile, param2:int, param3:int, param4:int, param5:int = 9) : *
      {
         if(param5 == 100 && param2 <= 50 && (param1.thre > 0 || param1.indestruct))
         {
            return;
         }
         if(param5 == 100)
         {
            param5 = 4;
         }
         if(!this.destroyOn && param1.hp > 500)
         {
            if(this.active && param1.phis == 1)
            {
               this.grafon.dyrka(param3,param4,param5,param1.mat,true,param2 / param1.hp);
            }
            return;
         }
         if(param1.udar(param2))
         {
            if(param1.hp <= 0)
            {
               if(param1.phis >= 1)
               {
                  this.isRebuild = true;
                  if(param1.Y < this.waterLevel)
                  {
                     this.recalcTiles.push(param1);
                     this.isRecalc = true;
                  }
               }
               if(param1.door)
               {
                  param1.door.die(param5);
               }
               else if(param1.phis >= 1)
               {
                  var ordinaryPrepared:Object = Grafon.rconnectOrdinaryPrepare(this,param1);
                  param1.die();
                  try
                  {
                     if(this.tileSpawn > 0 && Math.random() < this.tileSpawn)
                     {
                        this.enemySpawn(true,true);
                     }
                  }
                  catch(err:*)
                  {
                  }
                  if(this.active)
                  {
                     this.grafon.tileDie(param1,param5,ordinaryPrepared);
                  }
                  else Grafon.rconnectOrdinaryPending(this,param1,ordinaryPrepared);
               }
            }
            else if(param1.phis >= 1)
            {
               if(this.active)
               {
                  this.grafon.dyrka(param3,param4,param5,param1.mat,false,param2 / param1.hp);
               }
            }
         }
         else if(param1.phis >= 1)
         {
            if(this.active)
            {
               this.grafon.dyrka(param3,param4,param5,param1.mat,true,param2 / param1.hp);
            }
         }
      }
      
      public function dieTile(param1:Tile) : *
      {
         if(param1.indestruct)
         {
            return;
         }
         if(param1.phis == 1)
         {
            if(param1.door)
            {
               param1.door.die(4);
            }
            this.isRebuild = true;
            if(param1.Y < this.waterLevel)
            {
               this.recalcTiles.push(param1);
               this.isRecalc = true;
            }
         }
         if(param1.phis >= 1)
         {
            var ordinaryPrepared:Object = Grafon.rconnectOrdinaryPrepare(this,param1);
            param1.die();
            if(this.active)
            {
               this.grafon.tileDie(param1,4,ordinaryPrepared);
            }
            else Grafon.rconnectOrdinaryPending(this,param1,ordinaryPrepared);
         }
      }
      
      private function rebuild() : *
      {
         this.recalcWater();
         this.isRebuild = false;
      }
      
      private function recalcWater() : *
      {
         var _loc2_:Tile = null;
         var _loc3_:Tile = null;
         var _loc4_:Tile = null;
         var _loc5_:Tile = null;
         var _loc6_:Tile = null;
         var _loc7_:* = undefined;
         var _loc8_:Pt = null;
         var _loc1_:Array = this.recalcTiles;
         this.recalcTiles = new Array();
         this.isRecalc = false;
         for(_loc7_ in _loc1_)
         {
            _loc2_ = _loc1_[_loc7_];
            if(_loc2_.Y < this.waterLevel)
            {
               if(_loc2_.phis != 1)
               {
                  _loc3_ = this.getTile(_loc2_.X - 1,_loc2_.Y);
                  _loc4_ = this.getTile(_loc2_.X + 1,_loc2_.Y);
                  _loc5_ = this.getTile(_loc2_.X,_loc2_.Y - 1);
                  _loc6_ = this.getTile(_loc2_.X,_loc2_.Y + 1);
                  if((_loc6_.phis == 1 || _loc6_.water == 1) && (_loc4_.phis == 1 || _loc4_.water == 1) && (_loc3_.phis == 1 || _loc3_.water == 1) && (_loc3_.water == 1 || _loc4_.water == 1 || _loc5_.water == 1))
                  {
                     _loc2_.water = 1;
                     if(this.active)
                     {
                        this.grafon.drawWater(_loc2_);
                     }
                  }
                  else
                  {
                     if(_loc3_.water > 0 && _loc2_.phis != 1)
                     {
                        _loc3_.water = 0;
                        this.recalcTiles.push(_loc3_);
                        if(this.active)
                        {
                           this.grafon.drawWater(_loc3_);
                        }
                        this.isRecalc = true;
                     }
                     if(_loc4_.water > 0 && _loc2_.phis != 1)
                     {
                        _loc4_.water = 0;
                        this.recalcTiles.push(_loc4_);
                        if(this.active)
                        {
                           this.grafon.drawWater(_loc4_);
                        }
                        this.isRecalc = true;
                     }
                     if(_loc5_.water > 0 && _loc2_.phis != 1)
                     {
                        _loc5_.water = 0;
                        this.recalcTiles.push(_loc5_);
                        if(this.active)
                        {
                           this.grafon.drawWater(_loc5_);
                        }
                        this.isRecalc = true;
                     }
                  }
                  _loc2_.recalc = false;
               }
            }
         }
         _loc8_ = this.firstObj;
         while(_loc8_)
         {
            if(_loc8_ is Obj)
            {
               (_loc8_ as Obj).checkStay();
            }
            _loc8_ = _loc8_.nobj;
         }
      }
      
      public function testTile(param1:Tile) : Boolean
      {
         var _loc2_:* = undefined;
         if(param1.phis > 0 || param1.stair != 0 || param1.water != 0 || Boolean(param1.door))
         {
            return false;
         }
         for each(_loc2_ in this.units)
         {
            if(!(_loc2_ == null || (_loc2_ as Unit).sost == 4))
            {
               if(!_loc2_.transT)
               {
                  if(!(_loc2_.X1 >= (param1.X + 1) * Tile.tileX || _loc2_.X2 <= param1.X * Tile.tileX || _loc2_.Y1 >= (param1.Y + 1) * Tile.tileY || _loc2_.Y2 <= param1.Y * Tile.tileY))
                  {
                     return false;
                  }
               }
            }
         }
         return true;
      }
      
      public function drawMap(param1:BitmapData) : *
      {
         var _loc4_:Obj = null;
         var _loc5_:* = undefined;
         var _loc6_:uint = 0;
         var _loc7_:Tile = null;
         var _loc2_:Number = 1;
         var _loc3_:* = 0;
         while(_loc3_ < this.spaceX)
         {
            _loc5_ = 0;
            while(_loc5_ < this.spaceY)
            {
               _loc6_ = 13091;
               _loc7_ = this.space[_loc3_][_loc5_];
               if(_loc7_.water)
               {
                  _loc6_ = 26367;
               }
               if(_loc7_.shelf || _loc7_.diagon != 0)
               {
                  _loc6_ = 8079407;
               }
               if(_loc7_.stair != 0)
               {
                  _loc6_ = 6710886;
               }
               if(_loc7_.phis == 1)
               {
                  if(_loc7_.indestruct)
                  {
                     _loc6_ = 16777215;
                  }
                  else if(_loc7_.door)
                  {
                     _loc6_ = 6525188;
                  }
                  else if(_loc7_.hp < 100)
                  {
                     _loc6_ = 104794;
                  }
                  else
                  {
                     _loc6_ = 65433;
                  }
               }
               if(_loc7_.phis == 2)
               {
                  _loc6_ = 104794;
               }
               if(!World.w.drawAllMap)
               {
                  _loc2_ = Number(this.space[_loc3_][_loc5_].visi);
                  if(_loc3_ < this.spaceX - 1)
                  {
                     if(this.space[_loc3_ + 1][_loc5_].visi > _loc2_)
                     {
                        _loc2_ = Number(this.space[_loc3_ + 1][_loc5_].visi);
                     }
                     if(_loc5_ < this.spaceY - 1)
                     {
                        if(this.space[_loc3_ + 1][_loc5_ + 1].visi > _loc2_)
                        {
                           _loc2_ = Number(this.space[_loc3_ + 1][_loc5_ + 1].visi);
                        }
                     }
                  }
                  if(_loc5_ < this.spaceY - 1)
                  {
                     if(this.space[_loc3_][_loc5_ + 1].visi > _loc2_)
                     {
                        _loc2_ = Number(this.space[_loc3_][_loc5_ + 1].visi);
                     }
                  }
               }
               _loc6_ += Math.floor(_loc2_ * 255) * 16777216;
               param1.setPixel32((this.landX - this.land.minLocX) * World.cellsX + _loc3_,(this.landY - this.land.minLocY) * World.cellsY + _loc5_,_loc6_);
               _loc5_++;
            }
            _loc3_++;
         }
         for each(_loc4_ in this.objs)
         {
            if(Boolean(_loc4_.inter) && Boolean(_loc4_.inter.cont != "") && _loc4_.inter.active)
            {
               this.drawMapObj(param1,_loc4_,16763904);
            }
            if(Boolean(_loc4_.inter) && Boolean(_loc4_.inter.prob != "") && _loc4_.inter.prob != null)
            {
               this.drawMapObj(param1,_loc4_,16711799);
            }
         }
         for each(_loc4_ in this.acts)
         {
            if(_loc4_ is CheckPoint)
            {
               this.drawMapObj(param1,_loc4_,16711935);
            }
         }
         for each(_loc4_ in this.units)
         {
            if((_loc4_ as Unit).npc)
            {
               this.drawMapObj(param1,_loc4_,5570815);
            }
         }
      }
      
      internal function drawMapObj(param1:*, param2:Obj, param3:uint) : *
      {
         var _loc5_:* = undefined;
         var _loc4_:* = (this.landX - this.land.minLocX) * World.cellsX + Math.floor(param2.X1 / World.tileX + 0.5);
         while(_loc4_ <= (this.landX - this.land.minLocX) * World.cellsX + Math.floor(param2.X2 / World.tileX - 0.5))
         {
            _loc5_ = (this.landY - this.land.minLocY) * World.cellsY + Math.floor(param2.Y1 / World.tileY + 0.4);
            while(_loc5_ <= (this.landY - this.land.minLocY) * World.cellsY + Math.floor(param2.Y2 / World.tileY - 0.5))
            {
               param1.setPixel(_loc4_,_loc5_,param3);
               _loc5_++;
            }
            _loc4_++;
         }
      }
      
      public function allAct(param1:Obj, param2:String, param3:String = "") : *
      {
         var _loc4_:Obj = null;
         for each(_loc4_ in this.objs)
         {
            if(Boolean(_loc4_ != param1) && Boolean(_loc4_.inter) && (param3 == "" || param3 == null || _loc4_.inter.allid == param3))
            {
               _loc4_.command(param2,"13");
            }
         }
         for each(_loc4_ in this.areas)
         {
            if(_loc4_ != param1 && param3 == "" || param3 == null || (_loc4_ as Area).allid == param3)
            {
               _loc4_.command(param2);
            }
         }
         for each(_loc4_ in this.units)
         {
            if(Boolean(_loc4_ != param1) && Boolean(_loc4_.inter) && (param3 == "" || param3 == null || _loc4_.inter.allid == param3))
            {
               _loc4_.command(param2);
            }
         }
      }
      
      public function budilo(param1:Number, param2:Number, param3:Number = 1000, param4:Unit = null) : *
      {
         var _loc6_:* = undefined;
         var _loc7_:* = undefined;
         var _loc8_:* = undefined;
         var _loc9_:* = undefined;
         var _loc5_:Number = param3 * param3 * this.earMult * this.earMult;
         for each(_loc6_ in this.units)
         {
            if(Boolean(_loc6_ && _loc6_ != param4) && Boolean(_loc6_.sost == 1) && !_loc6_.unres)
            {
               _loc7_ = _loc6_.X - param1;
               _loc8_ = _loc6_.Y - param2;
               _loc9_ = param3 / 2;
               if(_loc9_ > 400)
               {
                  _loc9_ = 400;
               }
               if(_loc7_ * _loc7_ + _loc8_ * _loc8_ < _loc5_ * _loc6_.ear * _loc6_.ear)
               {
                  _loc6_.alarma(param1 + (Math.random() - 0.5) * _loc9_,param2 + (Math.random() - 0.5) * _loc9_);
               }
            }
         }
      }
      
      public function electroCheck() : *
      {
         var _loc1_:* = undefined;
         this.electroDam = 0;
         for each(_loc1_ in this.objs)
         {
            if(_loc1_ is Box && (_loc1_ as Box).electroDam > this.electroDam && !_loc1_.inter.open)
            {
               this.electroDam = (_loc1_ as Box).electroDam;
            }
         }
      }
      
      public function robocellActivate() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in this.objs)
         {
            if(Boolean(_loc1_.inter) && _loc1_.inter.allact == "robocell")
            {
               _loc1_.inter.genRobot();
            }
         }
      }
      
      public function signal(param1:int = 300) : *
      {
         this.t_alarm = param1;
         this.t_alarmsp = Math.floor(param1 * Math.random() * 0.25 + 0.25);
         if(Boolean(this.prob) && Boolean(this.prob.alarmScript))
         {
            this.prob.alarmScript.start();
         }
      }
      
      public function allon() : *
      {
         var _loc1_:* = undefined;
         this.color = "yellow";
         this.cTransform = this.colorFilter(this.color);
         this.lightOn = 1;
         this.darkness = -20;
         this.gg.inLoc(this);
         for each(_loc1_ in this.units)
         {
            _loc1_.cTransform = this.cTransform;
         }
         for each(_loc1_ in this.objs)
         {
            _loc1_.cTransform = this.cTransform;
            if(_loc1_.inter)
            {
               if(_loc1_.inter.lockTip == "4")
               {
                  _loc1_.inter.setAct("open",0);
               }
               _loc1_.inter.active = true;
               _loc1_.inter.update();
            }
         }
         for each(_loc1_ in this.backobjs)
         {
            _loc1_.onoff(1);
         }
         World.w.redrawLoc();
      }
      
      public function alloff() : *
      {
         var _loc1_:* = undefined;
         this.color = "black";
         this.cTransform = this.colorFilter(this.color);
         this.lightOn = -1;
         this.darkness = 20;
         this.gg.inLoc(this);
         for each(_loc1_ in this.units)
         {
            _loc1_.cTransform = this.cTransform;
         }
         for each(_loc1_ in this.objs)
         {
            _loc1_.cTransform = this.cTransform;
         }
         for each(_loc1_ in this.backobjs)
         {
            _loc1_.onoff(-1);
         }
         World.w.redrawLoc();
      }
      
      public function enemySpawn(param1:Boolean = false, param2:Boolean = false, param3:String = null) : *
      {
         if(this.kolEnSpawn <= 0 || this.enspawn == null || this.enspawn.length == 0)
         {
            return;
         }
         --this.kolEnSpawn;
         if(!param1)
         {
            this.t_alarmsp = Math.floor(Math.random() * 30);
         }
         var _loc4_:Object = this.enspawn[Math.floor(Math.random() * this.enspawn.length)];
         var _loc5_:Unit = this.createUnit(param3 == null ? this.tipSpawn : param3,_loc4_.x,_loc4_.y,true,null,null,30);
         if(param2)
         {
            _loc5_.alarma(this.gg.X,this.gg.Y);
         }
         else
         {
            _loc5_.alarma();
         }
      }
      
      public function waveSpawn(param1:XML, param2:int = 0, param3:String = null) : Unit
      {
         if(param1 == null)
         {
            return null;
         }
         if(this.enspawn.length == 0)
         {
            return null;
         }
         var _loc4_:Object = this.enspawn[param2];
         if(_loc4_ == null)
         {
            _loc4_ = this.enspawn[Math.floor(Math.random() * this.enspawn.length)];
         }
         var _loc5_:Unit = this.createUnit(param1.@id,_loc4_.x,_loc4_.y,true,param1,param1.@cid,30);
         if(param3 != null)
         {
            Emitter.emit(param3,this,_loc4_.x,_loc4_.y);
         }
         if(_loc5_)
         {
            _loc5_.trup = false;
            _loc5_.isRes = false;
            _loc5_.fraction = 1;
            _loc5_.wave = 1;
            _loc5_.alarma();
            return _loc5_;
         }
         return null;
      }
      
      public function earthQuake(param1:int) : *
      {
         if(this.quake < param1)
         {
            this.quake = param1;
            World.w.quake(param1,param1 / 4);
         }
      }
      
      public function createHealBonus(param1:Number, param2:Number) : *
      {
         if(World.w.pers.bonusHeal <= 0)
         {
            return;
         }
         var _loc3_:Bonus = new Bonus(this,"heal",param1,param2);
         _loc3_.liv = 300;
         _loc3_.val = World.w.pers.bonusHeal * World.w.pers.bonusHealMult;
         if(this.active)
         {
            _loc3_.addVisual();
         }
         this.addObj(_loc3_);
      }
      
      internal function gwalls() : *
      {
         var _loc2_:Tile = null;
         var _loc4_:* = undefined;
         var _loc1_:* = false;
         var _loc3_:* = 0;
         while(_loc3_ < this.spaceX)
         {
            _loc4_ = 0;
            while(_loc4_ < this.spaceY)
            {
               _loc2_ = this.space[_loc3_][_loc4_];
               if(_loc2_.phis == 3)
               {
                  if(this.active)
                  {
                     --_loc2_.t_ghost;
                     _loc1_ = true;
                     if(_loc2_.t_ghost <= 0)
                     {
                        this.dieTile(_loc2_);
                     }
                  }
                  else
                  {
                     _loc2_.t_ghost = 0;
                     this.dieTile(_loc2_);
                  }
               }
               _loc4_++;
            }
            _loc3_++;
         }
         if(_loc1_)
         {
            this.t_gwall = World.fps + 1;
         }
      }
      
      public function lightAll() : *
      {
         var _loc1_:* = undefined;
         for each(_loc1_ in this.objs)
         {
            if(_loc1_.light)
            {
               this.lighting(_loc1_.X - 10,_loc1_.Y - _loc1_.scY / 2);
               this.lighting(_loc1_.X,_loc1_.Y - _loc1_.scY / 2);
               this.lighting(_loc1_.X + 10,_loc1_.Y - _loc1_.scY / 2);
            }
         }
      }
      
      public function lighting(param1:int = -10000, param2:int = -10000, param3:int = -1, param4:int = -1) : *
      {
         var typedControl:Object = World.w.main.getChildByName("ContinuousSceneCarrier");
         if(typedControl != null && typedControl["nativeAPI"] != null && typedControl["nativeAPI"]["fogTypedEnabled"] === false)
         {
            var old_loc5_:Number = Number(NaN);
            var old_loc6_:Number = Number(NaN);
            var old_loc8_:* = undefined;
            var old_loc9_:int = 0;
            var old_loc10_:int = 0;
            var old_loc11_:* = undefined;
            var old_loc12_:* = undefined;
            var old_loc13_:Number = Number(NaN);
            var old_loc14_:Number = Number(NaN);
            var old_loc15_:int = 0;
            var old_loc16_:* = undefined;
            var old_loc17_:Tile = null;
            var old_loc18_:Number = Number(NaN);
            if(!this.active)
            {
               return;
            }
            if(param3 < 0)
            {
               param3 = this.lDist1;
            }
            if(param4 < 0)
            {
               param4 = this.lDist2;
            }
            if(param1 == -10000)
            {
               param1 = this.gg.X + this.gg.storona * 12;
               param2 = this.gg.Y1 + this.gg.stayY * 0.247;
            }
            this.relight_t = 10;
            var old_bounded:Boolean = (this.spaceX > 48 || this.spaceY > 25) && !this.retDark;
            if(old_bounded)
            {
               var old_control:Object = World.w.main.getChildByName("ContinuousSceneCarrier");
               if(old_control != null && old_control["nativeAPI"] != null && old_control["nativeAPI"]["fogBoundsEnabled"] === false)
               {
                  old_bounded = false;
               }
            }
            var old_interiorRay:Boolean = old_bounded && param1 >= 0 && param2 >= 0 && param1 < this.spaceX * Tile.tileX && param2 < this.spaceY * Tile.tileY;
            var old_raySpace:Array = this.space;
            var old_firstX:int = old_bounded ? Math.max(1,Math.ceil((param1 - param4) / Tile.tileX)) : 1;
            var old_firstY:int = old_bounded ? Math.max(1,Math.ceil((param2 - param4) / Tile.tileY)) : 1;
            var old_lastX:int = old_bounded ? Math.min(this.spaceX,Math.floor((param1 + param4) / Tile.tileX) + 1) : this.spaceX;
            var old_lastY:int = old_bounded ? Math.min(this.spaceY,Math.floor((param2 + param4) / Tile.tileY) + 1) : this.spaceY;
            var old_loc7_:* = old_firstX;
            while(old_loc7_ < old_lastX)
            {
               old_loc8_ = old_firstY;
               while(old_loc8_ < old_lastY)
               {
                  old_loc5_ = Number(this.space[old_loc7_][old_loc8_].visi);
                  if(!(!this.retDark && old_loc5_ >= 1))
                  {
                     old_loc9_ = old_loc7_ * Tile.tileX - param1;
                     old_loc10_ = old_loc8_ * Tile.tileY - param2;
                     old_loc11_ = old_loc9_ * old_loc9_ + old_loc10_ * old_loc10_;
                     if(old_loc11_ >= param4 * param4)
                     {
                        if(this.retDark && this.space[old_loc7_][old_loc8_].t_visi > 0)
                        {
                           this.space[old_loc7_][old_loc8_].t_visi -= 0.025;
                           if(this.space[old_loc7_][old_loc8_].t_visi < 0)
                           {
                              this.space[old_loc7_][old_loc8_].t_visi = 0;
                           }
                           this.grafon.lightBmp.setPixel32(old_loc7_,old_loc8_ + 1,Math.floor((1 - this.space[old_loc7_][old_loc8_].updVisi()) * 255) * 16777216);
                        }
                     }
                     else
                     {
                        old_loc12_ = Math.sqrt(old_loc11_);
                        if(old_loc12_ <= param3)
                        {
                           old_loc6_ = 1;
                        }
                        else
                        {
                           old_loc6_ = (param4 - old_loc12_) / (param4 - param3);
                        }
                        if(old_loc11_ <= param4 * param4 && (!old_bounded || old_loc6_ > old_loc5_ + 0.01))
                        {
                           if(Math.abs(old_loc9_) == Math.abs(old_loc10_))
                           {
                              old_loc10_++;
                           }
                           if(Math.abs(old_loc9_) >= Math.abs(old_loc10_))
                           {
                              if(old_loc9_ > 0)
                              {
                                 old_loc13_ = Tile.tileX;
                                 old_loc14_ = old_loc10_ / old_loc9_ * Tile.tileY;
                              }
                              else
                              {
                                 old_loc13_ = -Tile.tileX;
                                 old_loc14_ = -old_loc10_ / old_loc9_ * Tile.tileY;
                              }
                              old_loc15_ = old_loc9_ / old_loc13_;
                           }
                           else
                           {
                              if(old_loc10_ > 0)
                              {
                                 old_loc14_ = Tile.tileY;
                                 old_loc13_ = old_loc9_ / old_loc10_ * Tile.tileX;
                              }
                              else
                              {
                                 old_loc14_ = -Tile.tileY;
                                 old_loc13_ = -old_loc9_ / old_loc10_ * Tile.tileX;
                              }
                              old_loc15_ = old_loc10_ / old_loc14_;
                           }
                           old_loc16_ = 1;
                           while(old_loc16_ <= old_loc15_)
                           {
                              old_loc17_ = old_interiorRay ? old_raySpace[int((int(param1 + old_loc16_ * old_loc13_)) / Tile.tileX)][int((int(param2 + old_loc16_ * old_loc14_)) / Tile.tileY)] as Tile : this.getAbsTile(param1 + old_loc16_ * old_loc13_,param2 + old_loc16_ * old_loc14_);
                              old_loc18_ = old_loc17_.opac;
                              if(this.opacWater > 0 && old_loc17_.water > 0 && this.opacWater > old_loc18_)
                              {
                                 old_loc18_ = this.opacWater;
                              }
                              if(old_loc18_ > 0)
                              {
                                 old_loc6_ -= old_loc18_;
                                 if(old_loc6_ <= 0)
                                 {
                                    old_loc6_ = 0;
                                    break;
                                 }
                                 if(old_bounded && old_loc6_ <= old_loc5_ + 0.01)
                                 {
                                    break;
                                 }
                              }
                              old_loc16_++;
                           }
                        }
                        if(old_loc6_ > 1)
                        {
                           old_loc6_ = 1;
                        }
                        if(old_loc6_ > old_loc5_ + 0.01)
                        {
                           this.space[old_loc7_][old_loc8_].t_visi = old_loc6_;
                           this.grafon.lightBmp.setPixel32(old_loc7_,old_loc8_ + 1,Math.floor((1 - this.space[old_loc7_][old_loc8_].updVisi()) * 255) * 16777216);
                        }
                        else if(this.retDark && old_loc6_ < old_loc5_ - 0.01)
                        {
                           this.space[old_loc7_][old_loc8_].t_visi -= 0.025;
                           if(this.space[old_loc7_][old_loc8_].t_visi < old_loc6_)
                           {
                              this.space[old_loc7_][old_loc8_].t_visi = old_loc6_;
                           }
                           this.grafon.lightBmp.setPixel32(old_loc7_,old_loc8_ + 1,Math.floor((1 - this.space[old_loc7_][old_loc8_].updVisi()) * 255) * 16777216);
                        }
                     }
                  }
                  old_loc8_++;
               }
               old_loc7_++;
            }
            return;
         }
         var _loc5_:Number = Number(NaN);
         var _loc6_:Number = Number(NaN);
         var _loc8_:int = 0;
         var _loc9_:int = 0;
         var _loc10_:int = 0;
         var _loc11_:Number = Number(NaN);
         var _loc12_:Number = Number(NaN);
         var _loc13_:Number = Number(NaN);
         var _loc14_:Number = Number(NaN);
         var _loc15_:int = 0;
         var _loc16_:int = 0;
         var _loc17_:Tile = null;
         var _loc18_:Number = Number(NaN);
         if(!this.active)
         {
            return;
         }
         if(param3 < 0)
         {
            param3 = this.lDist1;
         }
         if(param4 < 0)
         {
            param4 = this.lDist2;
         }
         if(param1 == -10000)
         {
            param1 = this.gg.X + this.gg.storona * 12;
            param2 = this.gg.Y1 + this.gg.stayY * 0.247;
         }
         this.relight_t = 10;
         var bounded:Boolean = (this.spaceX > 48 || this.spaceY > 25) && !this.retDark;
         if(bounded)
         {
            var control:Object = World.w.main.getChildByName("ContinuousSceneCarrier");
            if(control != null && control["nativeAPI"] != null && control["nativeAPI"]["fogBoundsEnabled"] === false)
            {
               bounded = false;
            }
         }
         var interiorRay:Boolean = bounded && param1 >= 0 && param2 >= 0 && param1 < this.spaceX * Tile.tileX && param2 < this.spaceY * Tile.tileY;
         var raySpace:Array = this.space;
         var firstX:int = bounded ? Math.max(1,Math.ceil((param1 - param4) / Tile.tileX)) : 1;
         var firstY:int = bounded ? Math.max(1,Math.ceil((param2 - param4) / Tile.tileY)) : 1;
         var lastX:int = bounded ? Math.min(this.spaceX,Math.floor((param1 + param4) / Tile.tileX) + 1) : this.spaceX;
         var lastY:int = bounded ? Math.min(this.spaceY,Math.floor((param2 + param4) / Tile.tileY) + 1) : this.spaceY;
         var _loc7_:int = firstX;
         while(_loc7_ < lastX)
         {
            var currentColumn:Array = raySpace[_loc7_] as Array;
            _loc8_ = firstY;
            while(_loc8_ < lastY)
            {
               var currentTile:Tile = currentColumn[_loc8_] as Tile;
               _loc5_ = currentTile.visi;
               if(!(!this.retDark && _loc5_ >= 1))
               {
                  _loc9_ = _loc7_ * Tile.tileX - param1;
                  _loc10_ = _loc8_ * Tile.tileY - param2;
                  _loc11_ = _loc9_ * _loc9_ + _loc10_ * _loc10_;
                  if(_loc11_ >= param4 * param4)
                  {
                     if(this.retDark && currentTile.t_visi > 0)
                     {
                        currentTile.t_visi -= 0.025;
                        if(currentTile.t_visi < 0)
                        {
                           currentTile.t_visi = 0;
                        }
                        this.grafon.lightBmp.setPixel32(_loc7_,_loc8_ + 1,Math.floor((1 - currentTile.updVisi()) * 255) * 16777216);
                     }
                  }
                  else
                  {
                     _loc12_ = Math.sqrt(_loc11_);
                     if(_loc12_ <= param3)
                     {
                        _loc6_ = 1;
                     }
                     else
                     {
                        _loc6_ = (param4 - _loc12_) / (param4 - param3);
                     }
                     if(_loc11_ <= param4 * param4 && (!bounded || _loc6_ > _loc5_ + 0.01))
                     {
                        if(Math.abs(_loc9_) == Math.abs(_loc10_))
                        {
                           _loc10_++;
                        }
                        if(Math.abs(_loc9_) >= Math.abs(_loc10_))
                        {
                           if(_loc9_ > 0)
                           {
                              _loc13_ = Tile.tileX;
                              _loc14_ = _loc10_ / _loc9_ * Tile.tileY;
                           }
                           else
                           {
                              _loc13_ = -Tile.tileX;
                              _loc14_ = -_loc10_ / _loc9_ * Tile.tileY;
                           }
                           _loc15_ = _loc9_ / _loc13_;
                        }
                        else
                        {
                           if(_loc10_ > 0)
                           {
                              _loc14_ = Tile.tileY;
                              _loc13_ = _loc9_ / _loc10_ * Tile.tileX;
                           }
                           else
                           {
                              _loc14_ = -Tile.tileY;
                              _loc13_ = -_loc9_ / _loc10_ * Tile.tileX;
                           }
                           _loc15_ = _loc10_ / _loc14_;
                        }
                        _loc16_ = 1;
                        while(_loc16_ <= _loc15_)
                        {
                           _loc17_ = interiorRay ? raySpace[int((int(param1 + _loc16_ * _loc13_)) / Tile.tileX)][int((int(param2 + _loc16_ * _loc14_)) / Tile.tileY)] as Tile : this.getAbsTile(param1 + _loc16_ * _loc13_,param2 + _loc16_ * _loc14_);
                           _loc18_ = _loc17_.opac;
                           if(this.opacWater > 0 && _loc17_.water > 0 && this.opacWater > _loc18_)
                           {
                              _loc18_ = this.opacWater;
                           }
                           if(_loc18_ > 0)
                           {
                              _loc6_ -= _loc18_;
                              if(_loc6_ <= 0)
                              {
                                 _loc6_ = 0;
                                 break;
                              }
                              if(bounded && _loc6_ <= _loc5_ + 0.01)
                              {
                                 break;
                              }
                           }
                           _loc16_++;
                        }
                     }
                     if(_loc6_ > 1)
                     {
                        _loc6_ = 1;
                     }
                     if(_loc6_ > _loc5_ + 0.01)
                     {
                        currentTile.t_visi = _loc6_;
                        this.grafon.lightBmp.setPixel32(_loc7_,_loc8_ + 1,Math.floor((1 - currentTile.updVisi()) * 255) * 16777216);
                     }
                     else if(this.retDark && _loc6_ < _loc5_ - 0.01)
                     {
                        currentTile.t_visi -= 0.025;
                        if(currentTile.t_visi < _loc6_)
                        {
                           currentTile.t_visi = _loc6_;
                        }
                        this.grafon.lightBmp.setPixel32(_loc7_,_loc8_ + 1,Math.floor((1 - currentTile.updVisi()) * 255) * 16777216);
                     }
                  }
               }
               _loc8_++;
            }
            _loc7_++;
         }
      }
      
      public function lighting2() : *
      {
         var _loc2_:* = undefined;
         if(!this.active)
         {
            return;
         }
         --this.relight_t;
         var _loc1_:* = 1;
         while(_loc1_ < this.spaceX)
         {
            _loc2_ = 1;
            while(_loc2_ < this.spaceY)
            {
               if(this.space[_loc1_][_loc2_].visi != this.space[_loc1_][_loc2_].t_visi)
               {
                  this.grafon.lightBmp.setPixel32(_loc1_,_loc2_ + 1,Math.floor((1 - this.space[_loc1_][_loc2_].updVisi()) * 255) * 16777216);
               }
               _loc2_++;
            }
            _loc1_++;
         }
      }
      
      public function takeXP(param1:int, param2:Number = -1, param3:Number = -1, param4:Boolean = false) : *
      {
         if(param4)
         {
            if(param1 > this.summXp)
            {
               param1 = this.summXp;
               this.summXp = 0;
            }
            else
            {
               this.summXp -= param1;
            }
            this.land.summXp += param1;
         }
         if(param1 > 0)
         {
            World.w.pers.expa(param1,param2,param3);
         }
      }
      
      public function stepInvis() : *
      {
         var obj:Pt = null;
         var numb:* = 0;
         obj = this.firstObj;
         if(this.warning > 0)
         {
            --this.warning;
         }
         while(obj)
         {
            this.nextObj = obj.nobj;
            try
            {
               obj.step();
            }
            catch(err:*)
            {
               World.w.showError(err,obj.err());
            }
            obj = this.nextObj;
            numb++;
            if(numb > 10000)
            {
               trace("alarma");
               break;
            }
         }
         if(this.isRebuild)
         {
            this.rebuild();
         }
         if(this.isRecalc)
         {
            this.recalcWater();
         }
         if(this.t_gwall == 1)
         {
            this.gwalls();
         }
         if(this.t_gwall > 0)
         {
            --this.t_gwall;
         }
      }
      
      public function step() : *
      {
         var numb:*;
         var sceneSleeping:Object;
         var obj:Pt = null;
         World.w.grafon.sceneNativeEnvironment(this,this.gg.X,this.gg.Y);
         this.gg.step();
         sceneSleeping = World.w.grafon.sceneLarge ? World.w.grafon.sceneNativeCall("activity",[this]) : null;
         if(this.prob)
         {
            this.prob.step();
         }
         numb = 0;
         obj = this.firstObj;
         if(this.warning > 0)
         {
            --this.warning;
         }
         while(obj)
         {
            this.nextObj = obj.nobj;
            try
            {
               World.w.grafon.sceneNativeEnvironment(this,obj.X,obj.Y);
               if(sceneSleeping == null || !sceneSleeping[obj])
               {
                  obj.step();
               }
               if(obj is Obj && (obj as Obj).onCursor > 0 && obj != this.gg && (this.celObj == null || (obj as Obj).onCursor >= this.celObj.onCursor))
               {
                  this.celObj = obj as Obj;
               }
            }
            catch(err:*)
            {
               World.w.showError(err,obj.err());
            }
            obj = this.nextObj;
            numb++;
            if(numb > 10000)
            {
               trace("alarma");
               break;
            }
         }
         World.w.grafon.sceneNativeEnvironment(this,this.gg.X,this.gg.Y);
         if(Boolean(this.unitCoord) && Boolean(this.unitCoord.step))
         {
            this.unitCoord.step();
         }
         if(Boolean(this.celObj) && this.celObj.onCursor <= 0)
         {
            this.celObj = null;
         }
         if(this.black)
         {
            if(this.gg.dx + this.gg.osndx > 0.5 || this.gg.dy + this.gg.osndy > 0.5 || this.gg.dx + this.gg.osndx < -0.5 || this.gg.dy + this.gg.osndy < -0.5 || this.isRelight || this.isRebuild)
            {
               this.lighting();
            }
            else if(this.relight_t > 0)
            {
               this.lighting2();
            }
         }
         this.isRelight = false;
         this.getDist();
         if(this.isRebuild)
         {
            this.rebuild();
         }
         if(this.isRecalc)
         {
            this.recalcWater();
         }
         if(this.t_gwall == 1)
         {
            this.gwalls();
         }
         if(this.t_gwall > 0)
         {
            --this.t_gwall;
         }
         if(this.sign_vis && Boolean(World.w.possiblyOut()) || !this.sign_vis && !World.w.possiblyOut())
         {
            this.showSign(!this.sign_vis);
         }
         if(this.t_alarm > 0)
         {
            --this.t_alarm;
         }
         if(this.t_alarmsp > 0)
         {
            --this.t_alarmsp;
            if(this.t_alarmsp == 0)
            {
               this.enemySpawn();
            }
         }
         if(this.quake > 0)
         {
            --this.quake;
         }
         if(this.trus > 0)
         {
            World.w.quake(this.trus / 2,this.trus);
         }
      }
      
      public function getAll() : int
      {
         var _loc1_:Unit = null;
         var _loc2_:Box = null;
         World.w.summxp = 0;
         World.w.pers.expa(this.unXp * 9);
         for each(_loc1_ in this.units)
         {
            if(_loc1_.fraction != Unit.F_PLAYER && _loc1_.xp > 0)
            {
               _loc1_.damage(100000,Unit.D_INSIDE);
            }
         }
         for each(_loc2_ in this.objs)
         {
            if(Boolean(_loc2_.inter) && Boolean(_loc2_.inter.cont))
            {
               _loc2_.inter.loot();
            }
         }
         return World.w.summxp;
      }
      
      public function openAllPrize() : *
      {
         var _loc1_:Box = null;
         for each(_loc1_ in this.objs)
         {
            if(Boolean(_loc1_.inter) && Boolean(_loc1_.inter.cont) && _loc1_.inter.prize)
            {
               _loc1_.inter.loot();
            }
         }
      }
      
      private function getDist() : *
      {
         if(this.getTile(Math.round(World.w.celX / Tile.tileX),Math.round(World.w.celY / Tile.tileY)).visi < 0.1)
         {
            this.celObj = null;
         }
         if(this.celObj)
         {
            this.celDist = (this.gg.X - this.celObj.X) * (this.gg.X - this.celObj.X) + (this.gg.Y - this.celObj.Y) * (this.gg.Y - this.celObj.Y);
         }
         else
         {
            this.celDist = -1;
         }
      }
      
      private function showSign(param1:Boolean) : *
      {
         var _loc2_:* = undefined;
         for each(_loc2_ in this.signposts)
         {
            _loc2_.visible = param1;
         }
         this.sign_vis = param1;
      }
      
      public function newGrenade(param1:Bullet) : *
      {
         var _loc2_:* = undefined;
         if(this.grenades[0] == null)
         {
            this.grenades[0] = param1;
         }
         else
         {
            _loc2_ = 1;
            while(_loc2_ < 10)
            {
               if(this.grenades[_loc2_] == null)
               {
                  this.grenades[_loc2_] = param1;
               }
               _loc2_++;
            }
         }
      }
      
      public function remGrenade(param1:Bullet) : *
      {
         var _loc2_:* = undefined;
         if(this.grenades[0] == param1)
         {
            this.grenades[0] = null;
         }
         else
         {
            _loc2_ = 1;
            while(_loc2_ < 10)
            {
               if(this.grenades[_loc2_] == param1)
               {
                  this.grenades[_loc2_] = null;
               }
               _loc2_++;
            }
         }
      }
      
      public function saveObjs(param1:Array) : *
      {
         var _loc2_:Obj = null;
         for each(_loc2_ in this.saves)
         {
            if(_loc2_.code)
            {
               param1[_loc2_.code] = _loc2_.save();
            }
         }
      }
   }
}

