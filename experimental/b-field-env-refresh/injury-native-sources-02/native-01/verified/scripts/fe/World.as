package fe
{
   import fe.graph.Emitter;
   import fe.graph.Grafon;
   import fe.inter.*;
   import fe.loc.*;
   import fe.rooms.Rooms;
   import fe.serv.LootGen;
   import fe.unit.Invent;
   import fe.unit.Pers;
   import fe.unit.Unit;
   import fe.unit.UnitPlayer;
   import fe.weapon.Weapon;
   import flash.desktop.Clipboard;
   import flash.desktop.ClipboardFormats;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.events.MouseEvent;
   import flash.net.SharedObject;
   import flash.net.URLLoader;
   import flash.net.URLRequest;
   import flash.system.Capabilities;
   import flash.system.System;
   import flash.ui.Mouse;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   
   public class World
   {
      
      public static var w:World;
      
      public static const tileX:* = 40;
      
      public static const tileY:* = 40;
      
      public static const cellsX:int = 48;
      
      public static const cellsY:int = 25;
      
      public static const fps:* = 30;
      
      public static const ddy:* = 1;
      
      public static const maxdy:* = 20;
      
      public static const maxwaterdy:* = 20;
      
      public static const maxdelta:* = 9;
      
      public static const oduplenie:* = 100;
      
      public static const battleNoOut:* = 120;
      
      public static const unitXPMult:Number = 2;
      
      public static const kolHK:* = 12;
      
      public static const kolQS:* = 4;
      
      public static const boxDamage:* = 0.2;
      
      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v12";
      
      public static var rconnectChangeWorld:Function = null;
      
      public static var rconnectSave:Function = null;
      
      public var playerMode:String;
      
      public var urle:String;
      
      public var main:Sprite;
      
      public var swfStage:Stage;
      
      public var vwait:MovieClip;
      
      public var vfon:MovieClip;
      
      public var visual:Sprite;
      
      public var vscene:MovieClip;
      
      public var vblack:MovieClip;
      
      public var vpip:MovieClip;
      
      public var vsats:MovieClip;
      
      public var vgui:MovieClip;
      
      public var vstand:MovieClip;
      
      public var verror:MovieClip;
      
      public var vconsol:MovieClip;
      
      public var mm:MainMenu;
      
      public var cam:Camera;
      
      public var ctr:Ctr;
      
      public var consol:Consol;
      
      public var game:Game;
      
      public var gg:UnitPlayer;
      
      public var pers:Pers;
      
      public var invent:Invent;
      
      public var gui:GUI;
      
      public var grafon:Grafon;
      
      public var pip:PipBuck;
      
      public var stand:Stand;
      
      public var sats:Sats;
      
      public var app:Appear;
      
      public var land:Land;
      
      public var loc:Location;
      
      public var rooms:Rooms;
      
      public var onConsol:Boolean = false;
      
      public var onPause:Boolean = false;
      
      public var allStat:int = 0;
      
      public var celX:Number;
      
      public var celY:Number;
      
      public var t_battle:int = 0;
      
      public var t_die:int = 0;
      
      public var t_exit:int = 0;
      
      public var gr_stage:int = 0;
      
      public var checkLoot:Boolean = false;
      
      public var calcMass:Boolean = false;
      
      public var calcMassW:Boolean = false;
      
      public var lastCom:String = null;
      
      public var armorWork:String = "";
      
      public var mmArmor:Boolean = false;
      
      public var catPause:Boolean = false;
      
      public var testLoot:Boolean = false;
      
      public var summxp:int = 0;
      
      internal var ccur:String;
      
      public var currentMusic:String = "";
      
      public var enemyAct:int = 3;
      
      public var roomsLoad:int = 1;
      
      internal var langLoad:* = 1;
      
      public var addCheckSP:Boolean = false;
      
      public var weaponsLevelsOff:Boolean = true;
      
      public var drawAllMap:Boolean = false;
      
      public var black:Boolean = true;
      
      public var testMode:Boolean = false;
      
      public var chitOn:Boolean = false;
      
      public var chit:String = "";
      
      public var chitX:String = null;
      
      public var showArea:Boolean = false;
      
      public var godMode:Boolean = false;
      
      public var showAddInfo:Boolean = false;
      
      public var testBattle:Boolean = false;
      
      public var testEff:Boolean = false;
      
      public var testDam:Boolean = false;
      
      public var hardInv:Boolean = false;
      
      public var alicorn:Boolean = false;
      
      public var maxParts:int = 100;
      
      public var zoom100:Boolean = false;
      
      public var dialOn:Boolean = true;
      
      public var showHit:int = 2;
      
      public var matFilter:Boolean = true;
      
      public var helpMess:Boolean = true;
      
      public var shineObjs:Boolean = false;
      
      public var sysCur:Boolean = false;
      
      public var hintKeys:Boolean = true;
      
      public var hintTele:Boolean = true;
      
      public var showFavs:Boolean = true;
      
      public var errorShow:Boolean = true;
      
      public var errorShowOpt:Boolean = true;
      
      public var quakeCam:Boolean = true;
      
      public var vsWeaponNew:Boolean = true;
      
      public var vsWeaponRep:Boolean = true;
      
      public var vsAmmoAll:Boolean = true;
      
      public var vsAmmoTek:Boolean = true;
      
      public var vsExplAll:Boolean = true;
      
      public var vsMedAll:Boolean = true;
      
      public var vsHimAll:Boolean = true;
      
      public var vsEqipAll:Boolean = true;
      
      public var vsStuffAll:Boolean = true;
      
      public var vsVal:Boolean = true;
      
      public var vsBook:Boolean = true;
      
      public var vsFood:Boolean = true;
      
      public var vsComp:Boolean = true;
      
      public var vsIngr:Boolean = true;
      
      public var actionDist:* = 40000;
      
      public var lang:String = "en";
      
      public var langDef:String = "ru";
      
      public var langs:Array;
      
      public var kolLangs:int = 0;
      
      public var tl:TextLoader;
      
      public var tld:TextLoader;
      
      public var textLoaded:Boolean = false;
      
      public var textLoadErr:Boolean = false;
      
      internal var loader_lang:URLLoader;
      
      internal var request_lang:URLRequest;
      
      public var langsXML:XML;
      
      public var textProgressLoad:Number = 0;
      
      public var soundPath:String;
      
      public var musicPath:String;
      
      public var textureURL:String;
      
      public var spriteURL:String;
      
      public var sprite1URL:String;
      
      public var musicKol:int = 0;
      
      public var musicLoaded:int = 0;
      
      public var langURL:String;
      
      public var configObj:SharedObject;
      
      internal var saveObj:SharedObject;
      
      internal var saveArr:Array;
      
      public var saveKol:int = 10;
      
      internal var savePath:String = null;
      
      internal var t_save:int = 0;
      
      public var loaddata:Object;
      
      public var nadv:int = 0;
      
      public var koladv:int = 10;
      
      public var load_log:String = "";
      
      public var landPath:String;
      
      public var fileVersion:int = 2;
      
      public var landData:Array;
      
      public var kolLands:int = 0;
      
      public var kolLandsLoaded:int = 0;
      
      public var allLandsLoaded:Boolean = false;
      
      public var comLoad:int = -1;
      
      public var clickReq:int = 0;
      
      public var ng_wait:int = 0;
      
      public var loadScreen:int = -1;
      
      public var autoSaveN:int = 0;
      
      public var log:String = "";
      
      public var tfc:Timer;
      
      internal var fc:int = 0;
      
      internal var d1:int;
      
      internal var d2:int;
      
      public var landError:Boolean = false;
      
      internal var ng:Boolean;
      
      internal var data:Object;
      
      internal var opt:Object;
      
      internal var newName:String;
      
      public function World(param1:Sprite, param2:Object)
      {
         var nmain:Sprite = param1;
         var paramObj:Object = param2;
         super();
         World.w = this;
         this.playerMode = Capabilities.playerType;
         this.soundPath = "";
         this.musicPath = "Music/";
         this.textureURL = "texture.swf";
         this.spriteURL = "sprite.swf";
         this.sprite1URL = "sprite1.swf";
         this.langURL = "lang.xml";
         this.landPath = "Rooms/";
         if(this.testMode)
         {
            this.fileVersion = Math.random() * 100000;
         }
         if(this.playerMode == "PlugIn")
         {
            this.musicPath = "http://foe.ucoz.org/Sound/music/";
            this.soundPath = "";
            this.langURL += "?u=" + Math.random().toFixed(5);
            this.textureURL += "?u=" + this.fileVersion;
            this.spriteURL += "?u=" + this.fileVersion;
         }
         this.main = nmain;
         this.swfStage = this.main.stage;
         this.swfStage.tabChildren = false;
         this.swfStage.addEventListener(Event.DEACTIVATE,this.onDeactivate);
         Tile.tileX = tileX;
         Tile.tileY = tileY;
         this.loader_lang = new URLLoader();
         this.request_lang = new URLRequest(this.langURL);
         this.loader_lang.load(this.request_lang);
         this.loader_lang.addEventListener(Event.COMPLETE,this.onCompleteLoadLang);
         this.loader_lang.addEventListener(IOErrorEvent.IO_ERROR,this.onErrorLoadLang);
         LootGen.init();
         Form.setForms();
         Emitter.init();
         if(this.roomsLoad == 0)
         {
         }
         this.vwait = new visualWait();
         this.vwait.cacheAsBitmap = true;
         this.app = new Appear();
         this.visual = new Sprite();
         this.vgui = new visualGUI();
         this.vfon = new MovieClip();
         this.vpip = new visPipBuck();
         this.vstand = new visualStand();
         this.vsats = new MovieClip();
         this.vscene = new visualScene();
         this.vblack = new visBlack();
         this.vblack.cacheAsBitmap = true;
         this.vconsol = new visConsol();
         this.verror = new visError();
         this.setLoadScreen();
         this.vgui.visible = this.vpip.visible = this.vconsol.visible = this.vfon.visible = this.visual.visible = this.vsats.visible = this.vwait.visible = this.vblack.visible = this.verror.visible = this.vscene.visible = false;
         this.vscene.stop();
         this.main.addChild(this.vwait);
         this.main.addChild(this.vfon);
         this.main.addChild(this.visual);
         this.main.addChild(this.vscene);
         this.main.addChild(this.vblack);
         this.main.addChild(this.vpip);
         this.main.addChild(this.vsats);
         this.main.addChild(this.vgui);
         this.main.addChild(this.vstand);
         this.main.addChild(this.verror);
         this.main.addChild(this.vconsol);
         this.verror.butCopy.addEventListener(MouseEvent.CLICK,function():*
         {
            Clipboard.generalClipboard.clear();
            Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT,verror.txt.text);
         });
         this.verror.butClose.addEventListener(MouseEvent.CLICK,function():*
         {
            verror.visible = false;
         });
         this.verror.butForever.addEventListener(MouseEvent.CLICK,function():*
         {
            errorShow = false;
            verror.visible = false;
         });
         this.vstand.visible = false;
         this.grafon = new Grafon(this.visual);
         this.cam = new Camera(this);
         this.load_log += "Stage 1 Ok\n";
         this.d1 = this.d2 = getTimer();
         this.configObj = SharedObject.getLocal("config",this.savePath);
         if(this.configObj.data.snd)
         {
            Snd.load(this.configObj.data.snd);
         }
      }
      
      internal function onCompleteLoadLang(param1:Event) : void
      {
         var event:Event = param1;
         try
         {
            this.langsXML = new XML(this.loader_lang.data);
            this.initLangs(false);
         }
         catch(err:*)
         {
            trace("ОШИБКА В ФАЙЛЕ ЯЗЫКОВ");
            load_log += "Lang file error: " + langURL + "\n";
            initLangs(true);
         }
         this.loader_lang.removeEventListener(Event.COMPLETE,this.onCompleteLoadLang);
         this.loader_lang.removeEventListener(IOErrorEvent.IO_ERROR,this.onErrorLoadLang);
         this.load_log += "Lang file loading: " + this.langURL + " Ok\n";
      }
      
      internal function onErrorLoadLang(param1:IOErrorEvent) : void
      {
         this.initLangs(true);
         this.loader_lang.removeEventListener(Event.COMPLETE,this.onCompleteLoadLang);
         this.loader_lang.removeEventListener(IOErrorEvent.IO_ERROR,this.onErrorLoadLang);
         this.load_log += "Load lang error " + this.langURL + "\n";
         trace("Нельзя загрузить список языков");
      }
      
      internal function initLangs(param1:Boolean = false) : *
      {
         var _loc2_:XML = null;
         var _loc3_:* = undefined;
         if(param1)
         {
            this.langsXML = <all>
				<lang id='ru' file='text_ru.xml'>Русский</lang>
				<lang id='en' file='text_en.xml'>English</lang>
			</all>;
         }
         this.lang = Capabilities.language;
         if(this.configObj.data.language != null)
         {
            this.lang = this.configObj.data.language;
         }
         if(Boolean(this.langsXML) && Boolean(this.langsXML.@§default§.length()))
         {
            this.langDef = this.langsXML.@§default§;
         }
         this.langs = new Array();
         for each(_loc2_ in this.langsXML.lang)
         {
            if(_loc2_.@off.length() == 0 || !_loc2_.@off > 0)
            {
               _loc3_ = {
                  "file":_loc2_.@file,
                  "nazv":_loc2_[0]
               };
               this.langs[_loc2_.@id] = _loc3_;
               ++this.kolLangs;
            }
         }
         if(this.langs[this.lang] == null)
         {
            this.lang = this.langDef;
         }
         this.tld = new TextLoader(this.langs[this.langDef].file,true);
         if(this.lang != this.langDef)
         {
            this.tl = new TextLoader(this.langs[this.lang].file);
         }
         else
         {
            this.tl = this.tld;
         }
      }
      
      public function textsLoadOk() : *
      {
         if(this.tl.loaded)
         {
            this.textLoaded = true;
            Res.d = this.tl.d;
         }
         if(this.tl.errLoad)
         {
            this.lang = this.langDef;
            if(this.tld.loaded)
            {
               this.textLoaded = true;
               Res.d = this.tld.d;
            }
            this.textLoadErr = true;
         }
      }
      
      public function defuxLang(param1:String) : *
      {
         this.lang = param1;
         this.textLoadErr = false;
         if(param1 != this.langDef)
         {
            this.textLoaded = false;
            this.tl = new TextLoader(this.langs[param1].file);
         }
         else
         {
            Res.d = Res.e;
            this.pip.updateLang();
         }
         this.saveConfig();
      }
      
      internal function init2() : *
      {
         var _loc1_:*;
         var _loc2_:* = undefined;
         var _loc3_:LandLoader = null;
         if(this.consol)
         {
            return;
         }
         if(this.configObj)
         {
            this.lastCom = this.configObj.data.lastCom;
         }
         this.consol = new Consol(this.vconsol,this.lastCom);
         this.saveArr = new Array();
         _loc1_ = 0;
         while(_loc1_ <= this.saveKol)
         {
            this.saveArr[_loc1_] = SharedObject.getLocal("PFEgame" + _loc1_,this.savePath);
            _loc1_++;
         }
         this.saveObj = this.saveArr[0];
         if(this.configObj.data.dialon != null)
         {
            this.dialOn = this.configObj.data.dialon;
         }
         if(this.configObj.data.zoom100 != null)
         {
            this.zoom100 = this.configObj.data.zoom100;
         }
         if(this.zoom100)
         {
            this.cam.isZoom = 0;
         }
         else
         {
            this.cam.isZoom = 2;
         }
         if(this.configObj.data.mat != null)
         {
            this.matFilter = this.configObj.data.mat;
         }
         if(this.configObj.data.help != null)
         {
            this.helpMess = this.configObj.data.help;
         }
         if(this.configObj.data.hit != null)
         {
            this.showHit = this.configObj.data.hit;
         }
         if(this.configObj.data.sysCur != null)
         {
            this.sysCur = this.configObj.data.sysCur;
         }
         if(this.configObj.data.hintTele != null)
         {
            this.hintTele = this.configObj.data.hintTele;
         }
         if(this.configObj.data.showFavs != null)
         {
            this.showFavs = this.configObj.data.showFavs;
         }
         if(this.configObj.data.quakeCam != null)
         {
            this.quakeCam = this.configObj.data.quakeCam;
         }
         if(this.configObj.data.errorShowOpt != null)
         {
            this.errorShowOpt = this.configObj.data.errorShowOpt;
         }
         if(this.configObj.data.app)
         {
            this.app.load(this.configObj.data.app);
            this.app.setTransforms();
         }
         try
         {
            this.koladv = Res.d.advice[0].a.length();
         }
         catch(err:*)
         {
         }
         if(this.configObj.data.nadv)
         {
            this.nadv = this.configObj.data.nadv;
            ++this.configObj.data.nadv;
            if(this.configObj.data.nadv >= this.koladv)
            {
               this.configObj.data.nadv = 0;
            }
         }
         else
         {
            this.configObj.data.nadv = 1;
         }
         if(this.configObj.data.chit > 0)
         {
            this.chitOn = true;
         }
         if(this.configObj.data.vsWeaponNew > 0)
         {
            this.vsWeaponNew = false;
         }
         if(this.configObj.data.vsWeaponRep > 0)
         {
            this.vsWeaponRep = false;
         }
         if(this.configObj.data.vsAmmoAll > 0)
         {
            this.vsAmmoAll = false;
         }
         if(this.configObj.data.vsAmmoTek > 0)
         {
            this.vsAmmoTek = false;
         }
         if(this.configObj.data.vsExplAll > 0)
         {
            this.vsExplAll = false;
         }
         if(this.configObj.data.vsMedAll > 0)
         {
            this.vsMedAll = false;
         }
         if(this.configObj.data.vsHimAll > 0)
         {
            this.vsHimAll = false;
         }
         if(this.configObj.data.vsEqipAll > 0)
         {
            this.vsEqipAll = false;
         }
         if(this.configObj.data.vsStuffAll > 0)
         {
            this.vsStuffAll = false;
         }
         if(this.configObj.data.vsVal > 0)
         {
            this.vsVal = false;
         }
         if(this.configObj.data.vsBook > 0)
         {
            this.vsBook = false;
         }
         if(this.configObj.data.vsFood > 0)
         {
            this.vsFood = false;
         }
         if(this.configObj.data.vsComp > 0)
         {
            this.vsComp = false;
         }
         if(this.configObj.data.vsIngr > 0)
         {
            this.vsIngr = false;
         }
         this.ctr = new Ctr(this.configObj.data.ctr);
         this.pip = new PipBuck(this.vpip);
         if(!this.sysCur)
         {
            Mouse.cursor = "arrow";
         }
         this.landData = new Array();
         for each(_loc2_ in GameData.d.land)
         {
            if(!(!this.testMode && _loc2_.@test > 0))
            {
               _loc3_ = new LandLoader(_loc2_.@id);
               if(_loc2_.@test <= 0)
               {
                  ++this.kolLands;
               }
               this.landData[_loc2_.@id] = _loc3_;
            }
         }
         this.load_log += "Stage 2 Ok\n";
         Snd.loadMusic();
      }
      
      public function roomsLoadOk() : *
      {
         if(!this.roomsLoad)
         {
            this.allLandsLoaded = true;
            return;
         }
         ++this.kolLandsLoaded;
         if(this.kolLands == this.kolLandsLoaded)
         {
            this.allLandsLoaded = true;
         }
      }
      
      public function onDeactivate(param1:Event) : void
      {
         if(this.allStat == 1)
         {
            this.pip.onoff(11);
            if(this.playerMode == "PlugIn")
            {
               this.ctr.active = false;
            }
         }
         if(this.allStat > 0 && !this.alicorn)
         {
            this.saveGame();
         }
      }
      
      public function resizeScreen() : *
      {
         if(this.allStat > 0)
         {
            this.cam.setLoc(this.loc);
         }
         if(this.gui)
         {
            this.gui.resizeScreen(this.swfStage.stageWidth,this.swfStage.stageHeight);
         }
         this.pip.resizeScreen(this.swfStage.stageWidth,this.swfStage.stageHeight);
         this.grafon.setFonSize(this.swfStage.stageWidth,this.swfStage.stageHeight);
         if(this.stand)
         {
            this.stand.resizeScreen(this.swfStage.stageWidth,this.swfStage.stageHeight);
         }
         this.vblack.width = this.swfStage.stageWidth;
         this.vblack.height = this.swfStage.stageHeight;
         if(this.loadScreen < 0)
         {
            this.vwait.x = this.swfStage.stageWidth / 2;
            this.vwait.y = this.swfStage.stageHeight / 2;
         }
         if(this.allStat == 1 && !this.testMode)
         {
            this.pip.onoff(11);
         }
      }
      
      public function consolOnOff() : *
      {
         this.onConsol = !this.onConsol;
         this.consol.vis.visible = this.onConsol;
         if(this.onConsol)
         {
            this.swfStage.focus = this.consol.vis.input;
         }
      }
      
      public function newGame(param1:int = -1, param2:String = "LP", param3:Object = null) : *
      {
         var nload:int;
         var nnewName:String;
         var nopt:Object;
         if(rconnectChangeWorld != null)
         {
            rconnectChangeWorld();
         }
         nload = param1;
         nnewName = param2;
         nopt = param3;
         if(this.testMode && !this.chitOn)
         {
            this.vwait.progres.text = "error";
            return;
         }
         try
         {
            this.time___metr();
            this.allStat = -1;
            this.opt = nopt;
            this.newName = nnewName;
            this.game = new Game();
            if(!this.roomsLoad)
            {
               this.allLandsLoaded = true;
            }
            this.ng = nload < 0;
            if(this.ng)
            {
               if(Boolean(this.opt) && Boolean(this.opt.autoSaveN))
               {
                  this.autoSaveN = this.opt.autoSaveN;
                  this.saveObj = this.saveArr[this.autoSaveN];
                  nload = this.autoSaveN;
               }
               else
               {
                  nload = 0;
               }
               this.saveObj.clear();
            }
            this.gui = new GUI(this.vgui);
            this.gui.resizeScreen(this.swfStage.stageWidth,this.swfStage.stageHeight);
            this.pip.toNormalMode();
            this.pip.resizeScreen(this.swfStage.stageWidth,this.swfStage.stageHeight);
            this.sats = new Sats(this.vsats);
            this.time___metr("Интерфейс");
            if(nload == 99)
            {
               this.data = this.loaddata;
            }
            else
            {
               this.data = this.saveArr[nload].data;
            }
            if(this.ng)
            {
               this.game.init(null,this.opt);
            }
            else
            {
               this.game.init(this.data.game);
            }
            this.ng_wait = 1;
            this.time___metr("Game init");
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function newGame1() : *
      {
         try
         {
            if(!this.ng)
            {
               this.app.load(this.data.app);
            }
            if(this.data.hardInv == true)
            {
               this.hardInv = true;
            }
            else
            {
               this.hardInv = false;
            }
            if(Boolean(this.opt) && Boolean(this.opt.hardinv))
            {
               this.hardInv = true;
            }
            this.pers = new Pers(this.data.pers,this.opt);
            if(this.ng)
            {
               this.pers.persName = this.newName;
            }
            this.gg = new UnitPlayer();
            this.gg.ctr = this.ctr;
            this.gg.sats = this.sats;
            this.sats.gg = this.gg;
            this.gui.gg = this.gg;
            this.invent = new Invent(this.gg,this.data.invent,this.opt);
            this.stand = new Stand(this.vstand,this.invent);
            this.gg.attach();
            this.time___metr("Персонаж");
            if(!this.ng)
            {
               if(this.data.n != null)
               {
                  this.autoSaveN = this.data.n;
               }
            }
            Unit.txtMiss = Res.guiText("miss");
            this.waitLoadClick();
            this.ng_wait = 2;
            this.time___metr("Местность");
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function newGame2() : *
      {
         try
         {
            this.resizeScreen();
            this.offLoadScreen();
            this.vgui.visible = this.vfon.visible = this.visual.visible = true;
            this.vblack.alpha = 1;
            this.cam.dblack = -10;
            this.pip.onoff(-1);
            this.game.enterToCurLand();
            this.game.beginGame();
            Snd.off = false;
            this.gui.setAll();
            if(World.w.playerMode == "PlugIn")
            {
               this.ctr.active = false;
            }
            this.allStat = 1;
            this.ng_wait = 0;
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function loadGame(param1:int = 0) : *
      {
         var data:Object;
         var nload:int;
         if(rconnectChangeWorld != null)
         {
            rconnectChangeWorld();
         }
         data = null;
         nload = param1;
         try
         {
            this.time___metr();
            this.comLoad = -1;
            if(this.loc)
            {
               this.loc.out();
            }
            this.land = null;
            this.loc = null;
            try
            {
               this.cur("arrow");
            }
            catch(err:*)
            {
            }
            if(nload == 99)
            {
               data = this.loaddata;
            }
            else
            {
               data = this.saveArr[nload].data;
            }
            Snd.off = true;
            this.cam.showOn = false;
            if(data.hardInv == true)
            {
               this.hardInv = true;
            }
            else
            {
               this.hardInv = false;
            }
            this.game = new Game();
            this.game.init(data.game);
            this.app.load(data.app);
            this.pers = new Pers(data.pers);
            this.gg = new UnitPlayer();
            this.gg.ctr = this.ctr;
            this.gg.sats = this.sats;
            this.sats.gg = this.gg;
            this.gui.gg = this.gg;
            this.invent = new Invent(this.gg,data.invent);
            if(this.stand)
            {
               this.stand.inv = this.invent;
            }
            else
            {
               this.stand = new Stand(this.vstand,this.invent);
            }
            this.gg.attach();
            if(data.n != null)
            {
               this.autoSaveN = data.n;
            }
            this.offLoadScreen();
            this.vgui.visible = this.vfon.visible = this.visual.visible = true;
            this.vblack.alpha = 1;
            this.cam.dblack = -10;
            this.pip.onoff(-1);
            this.gui.allOn();
            this.t_die = 0;
            this.t_battle = 0;
            this.time___metr("Персонаж");
            this.game.enterToCurLand();
            this.game.beginGame();
            this.log = "";
            Snd.off = false;
            this.gui.setAll();
            if(World.w.playerMode == "PlugIn")
            {
               this.ctr.active = false;
            }
            this.allStat = 1;
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function ativateLand(param1:Land) : *
      {
         var nland:Land = param1;
         try
         {
            this.land = nland;
            this.grafon.drawFon(this.vfon,this.land.act.fon);
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function ativateLoc(param1:Location) : *
      {
         var nloc:Location = param1;
         try
         {
            if(this.loc)
            {
               this.loc.out();
            }
            this.loc = nloc;
            this.grafon.drawLoc(this.loc);
            this.cam.setLoc(this.loc);
            this.grafon.setFonSize(this.swfStage.stageWidth,this.swfStage.stageHeight);
            this.gui.setAll();
            this.currentMusic = this.loc.sndMusic;
            Snd.playMusic(this.currentMusic);
            this.gui.hpBarBoss();
            if(this.t_die <= 0)
            {
               World.w.gg.controlOn();
            }
            this.gui.dialText();
            this.pers.invMassParam();
            this.gc();
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function redrawLoc() : *
      {
         try
         {
            this.grafon.drawLoc(this.loc);
            this.cam.setLoc(this.loc);
            this.gui.setAll();
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function exitLand(param1:Boolean = false) : *
      {
         if(this.t_exit > 0)
         {
            return;
         }
         this.gg.controlOff();
         this.pip.noAct = true;
         if(param1)
         {
            this.t_exit = 21;
         }
         else
         {
            this.t_exit = 100;
         }
      }
      
      internal function exitStep() : *
      {
         try
         {
            --this.t_exit;
            if(this.t_exit == 99)
            {
               this.cam.dblack = 1.5;
            }
            if(this.t_exit == 20)
            {
               this.vblack.alpha = 0;
               this.cam.dblack = 0;
               this.setLoadScreen(this.getLoadScreen());
               Snd.off = true;
            }
            if(this.t_exit == 19)
            {
               this.cur("arrow");
               this.game.enterToCurLand();
            }
            if(this.t_exit == 18 && this.clickReq > 0)
            {
               this.waitLoadClick();
            }
            if(this.t_exit == 16)
            {
               Mouse.show();
               Snd.off = false;
               this.offLoadScreen();
               this.vgui.visible = this.vfon.visible = this.visual.visible = true;
               this.vblack.alpha = 1;
               this.cam.dblack = -10;
               this.gg.controlOn();
               this.pip.noAct = false;
            }
            if(this.t_exit == 1)
            {
               this.gui.allOn();
            }
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      internal function ggDieStep() : *
      {
         try
         {
            --this.t_die;
            if(this.t_die == 200)
            {
               this.cam.dblack = 2.2;
            }
            if(this.t_die == 150)
            {
               if(this.alicorn)
               {
                  this.game.runScript("gameover");
                  this.t_die = 0;
               }
               else
               {
                  if(this.gg.sost == 3)
                  {
                     this.game.curLandId = this.game.baseId;
                     this.game.enterToCurLand();
                  }
                  else
                  {
                     this.land.gotoCheckPoint();
                  }
                  this.cam.dblack = -4;
                  this.gg.vis.visible = true;
               }
            }
            if(this.t_die == 100)
            {
               this.gg.resurect();
            }
            if(this.t_die == 1)
            {
               this.gg.controlOn();
            }
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function step() : *
      {
         try
         {
            if(this.verror.visible)
            {
               return;
            }
            this.ctr.step();
            Snd.step();
            if(this.ng_wait > 0)
            {
               if(this.ng_wait == 1)
               {
                  this.newGame1();
               }
               else if(this.ng_wait == 2)
               {
                  if(this.clickReq != 1)
                  {
                     this.newGame2();
                  }
               }
               return;
            }
            if(!this.onConsol && !this.pip.active)
            {
               this.swfStage.focus = this.swfStage;
            }
            if(this.allStat == 1 && !this.onPause)
            {
               if(this.t_exit > 0)
               {
                  if(!(this.t_exit == 17 && this.clickReq == 1))
                  {
                     this.exitStep();
                  }
               }
               Emitter.kol2 = Emitter.kol1;
               Emitter.kol1 = 0;
               if(this.t_exit != 17)
               {
                  if(this.pers != null && Land.rconnectRoomStep == null)
                  {
                     this.pers.piEvent("tick",1 / fps);
                  }
                  this.land.step();
                  if(this.pers != null && Land.rconnectRoomStep == null)
                  {
                     this.pers.piEvent("flush");
                  }
               }
               if(this.t_die > 0)
               {
                  this.ggDieStep();
               }
               if(this.t_battle > 0)
               {
                  --this.t_battle;
               }
               this.sats.step2();
               if(this.calcMass)
               {
                  this.invent.calcMass();
                  this.calcMass = false;
               }
               if(this.calcMassW)
               {
                  this.invent.calcWeaponMass();
                  this.calcMassW = false;
               }
               ++this.t_save;
               if(this.t_save > 5000 && !this.testMode && !this.alicorn)
               {
                  this.saveGame();
               }
               this.checkLoot = false;
            }
            if(this.comLoad >= 0)
            {
               if(this.comLoad >= 100)
               {
                  if(this.autoSaveN > 0)
                  {
                     this.saveGame();
                  }
                  this.loadGame(this.comLoad - 100);
               }
               else
               {
                  this.pip.onoff(-1);
                  this.comLoad += 100;
                  this.setLoadScreen();
               }
            }
            if(this.allStat >= 1)
            {
               this.cam.calc(this.gg);
               this.gui.step();
               this.pip.step();
               this.sats.step();
               if(this.ctr.keyPip)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff();
                  }
                  this.ctr.keyPip = false;
               }
               if(this.ctr.keyInvent)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(2);
                  }
                  this.ctr.keyInvent = false;
               }
               if(this.ctr.keyStatus)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,1);
                  }
                  this.ctr.keyStatus = false;
               }
               if(this.ctr.keySkills)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,2);
                  }
                  this.ctr.keySkills = false;
               }
               if(this.ctr.keyMed)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(1,5);
                  }
                  this.ctr.keyMed = false;
               }
               if(this.ctr.keyMap)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(3,1);
                  }
                  this.ctr.keyMap = false;
               }
               if(this.ctr.keyQuest)
               {
                  if(!this.sats.active)
                  {
                     this.pip.onoff(3,2);
                  }
                  this.ctr.keyQuest = false;
               }
               if(this.ctr.keySats)
               {
                  if(this.gg.ggControl && !this.pip.active && this.gg && this.gg.pipOff <= 0 && !this.catPause)
                  {
                     this.sats.onoff();
                  }
                  this.ctr.keySats = false;
               }
               this.allStat = this.pip.active || this.sats.active || this.stand.active || this.gui.guiPause ? 2 : 1;
               if(Boolean(this.consol) && Boolean(this.consol.visoff))
               {
                  this.onConsol = this.consol.vis.visible = this.consol.visoff = false;
               }
            }
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      public function cur(param1:String = "arrow") : *
      {
         if(this.sysCur)
         {
            return;
         }
         if(this.pip.active || this.stand.active || this.comLoad >= 0)
         {
            param1 = "arrow";
         }
         else if(this.t_battle > 0)
         {
            param1 = "combat";
         }
         if(param1 != this.ccur)
         {
            Mouse.cursor = param1;
            Mouse.show();
            this.ccur = param1;
         }
      }
      
      public function quake(param1:Number, param2:Number) : *
      {
         if(this.loc.sky)
         {
            return;
         }
         if(this.quakeCam)
         {
            this.cam.quakeX += param1;
            this.cam.quakeY += param2;
            if(this.cam.quakeX > 20)
            {
               this.cam.quakeX = 20;
            }
            if(this.cam.quakeX < -20)
            {
               this.cam.quakeX = -20;
            }
            if(this.cam.quakeY > 20)
            {
               this.cam.quakeY = 20;
            }
            if(this.cam.quakeY < -20)
            {
               this.cam.quakeY = -20;
            }
         }
      }
      
      public function possiblyOut() : int
      {
         if(this.t_battle > 0)
         {
            return 2;
         }
         if(Boolean(this.loc) && this.loc.t_alarm > 0)
         {
            return 2;
         }
         if(this.land.loc_t > 120)
         {
            return 1;
         }
         return 0;
      }
      
      public function showError(param1:Error, param2:String = null) : *
      {
         if(!this.errorShow || !this.errorShowOpt)
         {
            return;
         }
         try
         {
            this.verror.info.text = Res.pipText("error");
            this.verror.butClose.text.text = Res.pipText("err_close");
            this.verror.butForever.text.text = Res.pipText("err_dont_show");
            this.verror.butCopy.text.text = Res.pipText("err_copy_to_clipboard");
         }
         catch(e:*)
         {
         }
         this.verror.txt.text = param1.message + "\n" + param1.getStackTrace();
         this.verror.txt.text += "\n" + "gr_stage: " + this.gr_stage;
         if(param2 != null)
         {
            this.verror.txt.text += "\n" + param2;
         }
         this.verror.visible = true;
      }
      
      public function time___metr(param1:* = null) : *
      {
         this.d2 = getTimer();
         if(param1 != null)
         {
            trace(this.d2 - this.d1,param1);
         }
         this.d1 = this.d2;
      }
      
      public function gc() : *
      {
         System.pauseForGCIfCollectionImminent(0.25);
      }
      
      public function setLoadScreen(param1:int = -1) : *
      {
         this.loadScreen = param1;
         this.vwait.story.lmb.stop();
         this.vwait.story.lmb.visible = false;
         this.vgui.visible = this.vfon.visible = this.visual.visible = this.vscene.visible = false;
         this.vwait.visible = true;
         this.catPause = false;
         this.vwait.progres.text = Res.guiText("loading");
         if(param1 < 0)
         {
            this.vwait.x = this.swfStage.stageWidth / 2;
            this.vwait.y = this.swfStage.stageHeight / 2;
            this.vwait.skill.gotoAndStop(Math.floor(Math.random() * this.vwait.skill.totalFrames + 1));
            this.vwait.skill.visible = this.vwait.progres.visible = true;
            this.vwait.story.visible = false;
            this.clickReq = 0;
         }
         else
         {
            this.vwait.x = this.vwait.y = 0;
            this.vwait.story.visible = true;
            this.vwait.skill.visible = this.vwait.progres.visible = false;
            if(param1 == 0)
            {
               this.vwait.story.txt.htmlText = "<i>" + Res.guiText("story") + "</i>";
            }
            else
            {
               this.vwait.story.txt.htmlText = "<i>" + "История" + param1 + "</i>";
            }
            this.clickReq = 1;
         }
         this.vwait.cacheAsBitmap = false;
         this.vwait.cacheAsBitmap = true;
      }
      
      internal function getLoadScreen() : int
      {
         var _loc1_:* = undefined;
         return -1;
      }
      
      internal function waitLoadClick() : *
      {
         this.vwait.story.lmb.play();
         this.vwait.story.lmb.visible = true;
      }
      
      internal function offLoadScreen() : *
      {
         this.vwait.visible = false;
         this.vwait.story.visible = false;
         this.vwait.skill.visible = this.vwait.progres.visible = true;
         this.vwait.story.lmb.stop();
         this.vwait.story.lmb.visible = false;
         this.clickReq = 0;
      }
      
      public function showScene(param1:String, param2:int = 0) : *
      {
         var sc:String = param1;
         var n:int = param2;
         this.catPause = true;
         this.visual.visible = false;
         this.gui.allOff();
         this.gui.offCelObj();
         try
         {
            this.vscene.gotoAndStop(sc);
         }
         catch(err:*)
         {
            vscene.gotoAndStop(1);
         }
         try
         {
            if(n > 0)
            {
               this.vscene.sc.gotoAndPlay(n);
            }
            else
            {
               this.vscene.sc.gotoAndPlay(1);
            }
         }
         catch(err:*)
         {
         }
         this.vscene.visible = true;
      }
      
      public function unshowScene() : *
      {
         this.catPause = false;
         this.visual.visible = true;
         this.gui.allOn();
         this.vscene.gotoAndStop(1);
         this.vscene.visible = false;
      }
      
      public function endgame(param1:int = 0) : *
      {
         var _loc2_:String = null;
         this.vwait.visible = this.vfon.visible = false;
         if(param1 == 1)
         {
            this.showScene("gameover");
            _loc2_ = Res.lpName(Res.guiText("end_bad"));
         }
         else if(this.pers.rep >= this.pers.repGood)
         {
            this.showScene("endgame");
            _loc2_ = Res.lpName(Res.guiText("end_good"));
            Snd.playMusic("music_fall_2");
         }
         else
         {
            this.showScene("endgame");
            _loc2_ = Res.lpName(Res.guiText("end_norm"));
         }
         try
         {
            this.vscene.sc.txt.htmlText = _loc2_;
         }
         catch(err:*)
         {
         }
      }
      
      public function saveToObj(param1:Object) : *
      {
         var _loc2_:Date = new Date();
         param1.game = this.game.save();
         param1.pers = this.pers.save();
         param1.invent = this.invent.save();
         param1.app = this.app.save();
         param1.date = _loc2_.time;
         param1.n = this.autoSaveN;
         param1.hardInv = this.hardInv;
         param1.ver = this.mm.version;
         param1.est = 1;
      }
      
      public function saveGame(param1:int = -1) : *
      {
         if(rconnectSave != null && Boolean(rconnectSave(this,param1)))
         {
            return;
         }
         var _loc2_:* = undefined;
         var _loc3_:* = undefined;
         if(param1 == -2)
         {
            param1 = this.autoSaveN;
            _loc2_ = this.saveArr[param1];
            this.saveToObj(_loc2_.data);
            _loc2_.flush();
            trace("Конец");
            return;
         }
         if(this.t_save < 100 && param1 == -1 && !this.pers.hardcore)
         {
            return;
         }
         if(this.pip.noAct)
         {
            return;
         }
         if(param1 == -1)
         {
            param1 = this.autoSaveN;
         }
         _loc2_ = this.saveArr[param1];
         if(_loc2_ is SharedObject)
         {
            this.saveToObj(_loc2_.data);
            _loc3_ = _loc2_.flush();
            trace(_loc3_);
            if(param1 == 0)
            {
               this.t_save = 0;
            }
         }
      }
      
      public function getSave(param1:int) : Object
      {
         if(this.saveArr[param1] is SharedObject)
         {
            return this.saveArr[param1].data;
         }
         return null;
      }
      
      public function saveConfig() : *
      {
         try
         {
            this.configObj.data.ctr = this.ctr.save();
            this.configObj.data.snd = Snd.save();
            this.configObj.data.language = this.lang;
            this.configObj.data.chit = this.chitOn ? 1 : 0;
            this.configObj.data.dialon = this.dialOn;
            this.configObj.data.zoom100 = this.zoom100;
            this.configObj.data.help = this.helpMess;
            this.configObj.data.mat = this.matFilter;
            this.configObj.data.hit = this.showHit;
            this.configObj.data.sysCur = this.sysCur;
            this.configObj.data.hintTele = this.hintTele;
            this.configObj.data.showFavs = this.showFavs;
            this.configObj.data.quakeCam = this.quakeCam;
            this.configObj.data.errorShowOpt = this.errorShowOpt;
            this.configObj.data.app = this.app.save();
            if(this.lastCom != null)
            {
               this.configObj.data.lastCom = this.lastCom;
            }
            this.configObj.data.vsWeaponNew = this.vsWeaponNew ? 0 : 1;
            this.configObj.data.vsWeaponRep = this.vsWeaponRep ? 0 : 1;
            this.configObj.data.vsAmmoAll = this.vsAmmoAll ? 0 : 1;
            this.configObj.data.vsAmmoTek = this.vsAmmoTek ? 0 : 1;
            this.configObj.data.vsExplAll = this.vsExplAll ? 0 : 1;
            this.configObj.data.vsMedAll = this.vsMedAll ? 0 : 1;
            this.configObj.data.vsHimAll = this.vsHimAll ? 0 : 1;
            this.configObj.data.vsEqipAll = this.vsEqipAll ? 0 : 1;
            this.configObj.data.vsStuffAll = this.vsStuffAll ? 0 : 1;
            this.configObj.data.vsVal = this.vsVal ? 0 : 1;
            this.configObj.data.vsBook = this.vsBook ? 0 : 1;
            this.configObj.data.vsFood = this.vsFood ? 0 : 1;
            this.configObj.data.vsComp = this.vsComp ? 0 : 1;
            this.configObj.data.vsIngr = this.vsIngr ? 0 : 1;
            this.configObj.flush();
         }
         catch(err:*)
         {
            showError(err);
         }
      }
      
      internal function weaponWrite() : *
      {
         var w:* = undefined;
         var weap:Weapon = null;
         var un:Unit = new Unit();
         var s:String = "";
         for each(w in AllData.d.weapon.(@tip > 0))
         {
            weap = new Weapon(un,w.@id,0);
            s += weap.write() + "\n";
            if(Boolean(w.com.length()) && Boolean(w.com.@uniq.length()))
            {
               weap = new Weapon(un,w.@id,1);
               s += weap.write() + "\n";
            }
         }
         trace(s);
      }
   }
}

