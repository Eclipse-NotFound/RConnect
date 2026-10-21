package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Four real G trials: one/double gas grenade, each direction.
    * Source oracle is actual Part objects, not configured explosion count.
    * Production wire/display are read-only observations; no clock injection. */
   public class GasPulseNativeTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"gasgr",quick:true,water:false,part:"gas",shots:1},
         {id:"gasgr",quick:true,water:false,part:"gas",shots:2}
      ];
      private var cases:Array=CASES;
      private var mod:RConnectMod,host:Boolean,source:Boolean,t:Timer=new Timer(100);
      private var links:Dictionary=new Dictionary(),phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var round:int=-1,spec:Object,baseX:Number,baseY:Number,wallX:int,floorY:int;
      private var oldGun:Object,oldChildren:Object,oldThrow:Object,oldMagic:Object,standby:Object,gun:Object;
      private var oldAmmo:Number=0,ammo:String="",oldGrenader:*,oldSky:Boolean,oldLevels:Boolean;
      private var saved:Boolean=false,tiles:Array=[],nativeBullet:Object,nativeClass:String="";
      private var nativeBirth:int=0,nativeEnd:int=0,nativeExplosion:Object,peerExplosion:Object;
      private var peerEnd:int=0,sourceShots:int=0,lastFrame:int=0,flightFrames:int=0,flightMs:Number=0;
      private var flightPixelSeen:Dictionary=new Dictionary(true);
      private var flightLate:int=0,flightPeak:int=0,flightClear:int=0,bounces:int=0,lastDY:Number=0;
      private var rotations:int=0,lastRotation:Number=NaN,flightPositions:Array=[];
      private var explosionParts:int=0,explosionPixels:int=0,explosionPositions:Array=[];
      private var parts:Dictionary=new Dictionary(),nativeShots:Dictionary=new Dictionary();
      private var unexpected:Dictionary=new Dictionary(),unexpectedBullets:int=0;
      private var effectClass:Class,effectBitmap:BitmapData,localResult:Object,peerResult:Object;
      private var swapInventory:Object,swapRequested:int=0,swapDetached:int=0,swapPeerAt:int=0;
      private var swapLive:Boolean=false,swapFlightFrames:int=0,swapLmgFrames:int=0;
      private var groundCount:int=0,sprayCount:int=0,groundPixels:int=0,aux:Dictionary=new Dictionary();
      private var diagnosticAt:int=0,observedFrames:int=0;
      private var ground:GasPulseProbe,gameFrame:int=0,inputReleased:int=0,issued:Boolean=false;
      private var bootActor:Object,bootRoom:Object,bootFrames:int=0,bootWatching:Boolean=false,bootLogged:Boolean=false;
      private var originalInventory:Object;
      private var gasBullets:Array=[],lastShotFrame:int=-100,gasOverlap:Boolean=false,gasDone:Boolean=false;
      private var releasePending:Boolean=false,throwGates:Array=[];

      public function GasPulseNativeTestDoc(scenarios:Array=null) {
         if(scenarios!=null)cases=scenarios;
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(!/^pfe-modsettings-rconnect-coop-(host|join)-[a-f0-9]{10}$/.test(app))return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"gas-pulse-native "+s+" round="+round);
      }
      private function send(stage:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="gas-pulse-native-test";p.stage=stage;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null && !links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function setPhase(s:String):void {phase=s;at=getTimer();}
      private function setup():void {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.anim();
         oldGun=g.currentWeapon;oldChildren=g.childObjs;oldThrow=g.throwWeapon;oldMagic=g.magicWeapon;
         oldGrenader=g.pers.grenader;oldSky=mod.game.loc.sky;oldLevels=w.weaponsLevelsOff;saved=true;
         originalInventory={weapons:g.invent.weapons,fav:g.invent.fav,favIds:g.invent.favIds};
         g.invent.weapons=copyArray(g.invent.weapons);g.invent.fav=copyArray(g.invent.fav);g.invent.favIds=copyArray(g.invent.favIds);
         g.childObjs=g.childObjs.concat();g.changeWeapon("not",true);
         g.invent.weapons.lmg=null;standby=g.invent.addWeapon("lmg");g.changeWeapon("lmg",true);
         g.throwWeapon=null;
         check(g.currentWeapon===standby && g.invent.weapons.lmg===standby && g.childObjs.indexOf(standby)>=0,
            "standby uses native owned inventory and equipment path");
         // Isolated fixture only: disable the proximity perk, keep the native
         // weapon's fuse/velocity/gravity/bounce and the whole simulation intact.
         g.pers.grenader=0;mod.game.loc.sky=false;w.weaponsLevelsOff=false;
         mod.game.loc.base=false;mod.game.loc.black=false;w.black=false;
         if(g.teleObj!=null)g.dropTeleObj();
         floorY=int(baseY/40);wallX=int(baseX/40)+8;
         saveTiles();
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,clockBefore,false,90001);
         mod.stage.addEventListener(Event.ENTER_FRAME,clockAfter,false,89999);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function saveTiles():void {
         var loc:Object=mod.game.loc;
         for(var x:int=int(baseX/40)-2;x<=wallX;x++)for(var y:int=floorY-6;y<=floorY;y++) {
            var tile:Object=loc.space[x][y],fields:Object={};
            for each(var key:String in ["phis","opac","front","water","indestruct","phX1","phX2","phY1","phY2","zForm","diagon","stair","shelf"])
               fields[key]=tile[key];
            tiles.push({tile:tile,fields:fields,x:x,y:y});
         }
      }
      private function prepare(n:int):void {
         if(ground!=null)ground.dispose();
         restoreWeapon();round=n;spec=cases[int(n/2)];source=host==(n%2==0);
         gameFrame=inputReleased=0;issued=false;
         nativeBullet=null;nativeClass="";nativeBirth=nativeEnd=peerEnd=sourceShots=0;
         gasBullets=[];lastShotFrame=-100;gasOverlap=false;gasDone=false;releasePending=false;throwGates=[];
         nativeExplosion=peerExplosion=localResult=peerResult=null;
         flightFrames=flightLate=flightPeak=flightClear=bounces=rotations=explosionParts=explosionPixels=0;
         flightMs=0;lastFrame=0;lastDY=0;lastRotation=NaN;unexpectedBullets=0;
         flightPixelSeen=new Dictionary(true);
         swapRequested=swapDetached=swapPeerAt=swapFlightFrames=swapLmgFrames=0;swapLive=false;
         flightPositions=[];explosionPositions=[];parts=new Dictionary();nativeShots=new Dictionary();unexpected=new Dictionary();
         groundCount=sprayCount=groundPixels=observedFrames=0;aux=new Dictionary();
         for each(var r:Object in tiles) {
            var tile:Object=r.tile,solid:Boolean=r.y==floorY || r.x==wallX || r.x==int(baseX/40)-2;
            tile.phis=solid?1:0;tile.opac=solid?1:0;tile.front="";tile.indestruct=true;
            tile.water=spec.water && !solid?1:0;tile.zForm=tile.diagon=tile.stair=0;tile.shelf=false;
            tile.phX1=r.x*40;tile.phX2=(r.x+1)*40;tile.phY1=r.y*40;tile.phY2=(r.y+1)*40;
         }
         mod.game.world.redrawLoc();
         ground=new GasPulseProbe(mod,source,round);
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr[spec.part];
         if(emitter==null)throw new Error("Missing native emitter "+spec.part);
         effectClass=emitter.visClass as Class;effectBitmap=emitter.blit?mod.game.world.grafon.getSpriteList(emitter.blit,1):null;
         if(source) {
            var g:Object=mod.game.gg;
            g.invent.weapons[spec.id]=null;gun=g.invent.addWeapon(spec.id);
            gun.setPers(g,g.pers);gun.lvl=0;gun.perslvl=0;
            if(spec.magic===true) {
               g.mana=10000;g.pers.manaHP=10000;g.pers.spellsPoss=1;
            } else {
               ammo=String(gun.ammo);oldAmmo=Number(g.invent.items[ammo].kol);g.invent.items[ammo].kol=Math.max(oldAmmo,50);
            }
            if(spec.swap) {
               // Equip the grenade through the native inventory, then throw
               // with G. Both sources use temporary inventory arrays; leave
               // the original 12 scenarios and profile entries untouched.
               swapInventory={weapons:g.invent.weapons,fav:g.invent.fav,favIds:g.invent.favIds};
               g.invent.weapons=copyArray(g.invent.weapons);g.invent.fav=copyArray(g.invent.fav);g.invent.favIds=copyArray(g.invent.favIds);
               g.invent.weapons[spec.id]=gun;g.invent.weapons.lmg=standby;
               g.invent.fav[29]=spec.id;g.invent.favIds[spec.id]=29;g.throwWeapon=gun;
               g.changeWeapon(spec.id,true);
               check(g.currentWeapon===gun && g.childObjs.indexOf(gun)>=0 && g.throwWeapon===gun,
                  "swap fixture equips native grenade and its quick-throw slot before real G input");
            } else if(spec.magic===true) {
               g.magicWeapon=gun;gun.loc=mod.game.loc;gun.setNull();gun.addVisual2();
               check(g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,"quick magic uses native magicWeapon outside equipment id="+spec.id);
            } else if(spec.quick) {
               g.invent.favItem(spec.id,29);
               check(g.invent.weapons[spec.id]===gun && g.throwWeapon===gun && g.invent.fav[29]==spec.id
                  && g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,
                  "quick throw uses native owned inventory/favourite outside currentWeapon/childObjs id="+spec.id);
            } else {
               standby.remVisual();g.currentWeapon=gun;g.childObjs=[gun,g.punchWeapon];gun.addVisual();gun.hold=gun.holder;
            }
         }
         Log.d("EXPLOSIVE PREPARE "+JSON.stringify({round:round,id:spec.id,water:spec.water,source:source,role:host?"host":"join"}));
         setPhase("prepared");
      }
      private function clockBefore(e:Event):void {if(ground!=null)ground.beginFrame(true);}
      private function clockAfter(e:Event):void {if(ground!=null)ground.beginFrame(false);}
      private function before(e:Event):void {
         if(!saved || phase=="done")return;gameFrame++;
         var g:Object=mod.game.gg,w:Object=mod.game.world,ctr:Object=w.ctr;
         mod.game.forceCloseOverlays();g.invulner=true;g.disabled=!source;g.ggControl=true;g.isTake=0;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=1;g.setVisPos();
         for each(var u:Object in mod.game.loc.units)if(u!==g){u.disabled=true;u.invulner=true;u.trigDis=true;}
         ctr.keyLeft=ctr.keyRight=ctr.keyBeUp=ctr.keySit=ctr.keyJump=ctr.keyTele=ctr.keyAction=false;
         ctr.keyRun=ctr.keyPunch=ctr.keyReload=false;
         ctr.keyAttack=ctr.keyGrenad=ctr.keyMagic=false;
         g.celX=w.celX=baseX+210;g.celY=w.celY=baseY-45;
         w.cam.celX=w.celX*w.cam.scaleV+w.cam.vx;w.cam.celY=w.celY*w.cam.scaleV+w.cam.vy;
         if(phase=="run" && source && sourceShots<int(spec.shots) && gun!=null) {
            // Native WThrow sets t_auto=3; pressing too early renews that latch.
            // Leave G released until native actions (not this driver) clear it.
            if(releasePending && gameFrame>lastShotFrame && int(gun.t_auto)==0 && gun.attackPos()) {
               throwGates.push({afterShot:sourceShots,afterFrame:lastShotFrame,frame:gameFrame,at:getTimer(),
                  tAuto:int(gun.t_auto),tAttack:int(gun.t_attack),tReload:int(gun.t_reload),attackPos:gun.attackPos()});
               releasePending=false;
            }
            if(!releasePending) {
               if(spec.magic===true)ctr.keyMagic=true;else if(spec.quick)ctr.keyGrenad=true;else ctr.keyAttack=true;
            }
         }
         if(source && issued && !ctr.keyGrenad && inputReleased==0)inputReleased=gameFrame;
         mod.stage.invalidate();
      }
      private function bootState():Object {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         return {role:host?"host":"join",at:getTimer(),timerTicks:t.currentCount,frames:bootFrames,
            ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,transition:mod.game.isTransitioning(),
            hp:Number(g.hp),sost:int(g.sost),dead:g.pers.dead,animOff:g.animOff,control:g.ggControl,
            disabled:g.disabled,work:g.work,t_work:g.t_work,t_die:w.t_die,t_exit:w.t_exit,comLoad:w.comLoad,
            clickReq:w.clickReq,onPause:w.onPause,allStat:w.allStat,roomActive:mod.game.loc!=null?mod.game.loc.active:null,
            blackVisible:w.vblack.visible,blackAlpha:w.vblack.alpha,
            label:g.vis!=null && g.vis.osn!=null?g.vis.osn.currentLabel:null};
      }
      private function bootWorldReady():Boolean {
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning()
            && loc!=null && loc.active && g.loc===loc && int(g.sost)==1 && Number(g.hp)>0 && !g.pers.dead
            && !w.onPause && int(w.allStat)==1 && int(w.clickReq)==0
            && (!w.vblack.visible || Number(w.vblack.alpha)<=0) && g.vis!=null && g.vis.stage!=null;
      }
      private function bootFrame(e:Event):void {
         if(phase!="boot" || bootActor==null)return;
         var g:Object=mod.game.gg;
         if(g===bootActor && mod.game.loc===bootRoom && bootWorldReady()
            && !g.animOff && g.ggControl && !g.disabled && g.work!="die" && g.work!="res"
            && g.vis.osn.currentLabel!="die")bootFrames++;
         else bootFrames=0;
      }
      private function prepareBootActor():void {
         if(!bootWorldReady())return;
         var g:Object=mod.game.gg;
         if(bootActor!==g || bootRoom!==mod.game.loc) {
            // A living character can retain the prologue's stopped artwork.
            // Clear it through native methods only after room/loading gates.
            // Actual deaths are rejected above; never heal or set sost/t_die.
            Log.d("GAS BOOT PREPARE "+JSON.stringify(bootState()));
            bootActor=g;bootRoom=mod.game.loc;bootFrames=0;bootLogged=false;
            g.anim();g.controlOn();g.invulner=true;
         }
         if(bootFrames>=2 && !bootLogged) {
            bootLogged=true;Log.d("GAS BOOT READY "+JSON.stringify(bootState()));
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         var w:Object=mod.game.world;mod.game.gg.invulner=true;
         if(!bootWatching){bootWatching=true;mod.stage.addEventListener(Event.ENTER_FRAME,bootFrame,false,-2147483647);}
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase=="done")return;
         if(getTimer()-at>(phase=="boot"?180000:26000)) {
            if(phase=="boot")Log.d("GAS BOOT TIMEOUT "+JSON.stringify(bootState()));
            fail("timeout "+phase);return;
         }
         if(phase=="boot")prepareBootActor();
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         try {
            if(phase=="boot" && !host && bootFrames>=2 && bootWorldReady() && getTimer()-readyAt>500) {
               readyAt=getTimer();send("ready");
            }
            if(phase=="run") {
               if(source && nativeBullet!=null && getTimer()-diagnosticAt>1000) {
                  diagnosticAt=getTimer();
                  Log.d("EXPLOSIVE PROGRESS "+JSON.stringify({round:round,elapsed:getTimer()-at,liv:nativeBullet.liv,
                     chain:nativeBullet.in_chain,expl:nativeBullet.isExpl,x:nativeBullet.X,y:nativeBullet.Y,
                     phase:phase,pause:w.onPause,black:w.vblack.visible,allStat:w.allStat,animOff:mod.game.gg.animOff,
                     effects:explosionParts,ground:groundCount,frames:flightFrames,worldFrames:observedFrames}));
               }
               var ended:int=source?nativeEnd:peerEnd;
               if(ended>0 && ((ground.allEnded && getTimer()-ground.lastActivity>=500)
                  || (ground.count==0 && getTimer()-ended>=6000)))complete();
            }
         } catch(err:Error){fail(err.getStackTrace());}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(phase=="run" && ground!=null)ground.observePacket(p);
         if(p.type!="gas-pulse-native-test" || phase=="done")return;
         try {
            if(host && p.stage=="ready" && phase=="boot" && bootFrames>=2 && bootWorldReady()) {
               var loc:Object=mod.game.loc;
               if(loc.spaceX<15 || loc.spaceY<10)throw new Error("Fixture requires a 15x10 or larger room");
               baseX=Math.max(160,Math.min(Math.floor(mod.game.gg.X/40)*40,loc.spaceX*40-440));
               baseY=Math.max(280,Math.min(Math.floor(mod.game.gg.Y/40)*40,(loc.spaceY-2)*40));
               setup();setPhase("setup");send("setup",{x:baseX,y:baseY});
            } else if(!host && p.stage=="setup" && phase=="boot") {
               baseX=p.x;baseY=p.y;setup();setPhase("setup");send("setup-ready");
            } else if(host && p.stage=="setup-ready" && phase=="setup")nextRound();
            else if(!host && p.stage=="prepare"){prepare(int(p.round));send("prepared");}
            else if(host && p.stage=="prepared" && int(p.round)==round && phase=="prepared") {
               setPhase("run");send("go");
            } else if(!host && p.stage=="go" && int(p.round)==round && phase=="prepared")setPhase("run");
            else if(int(p.round)==round && p.stage=="native-born" && !source)nativeClass=String(p.cls);
            else if(int(p.round)==round && p.stage=="native-explosion" && !source)peerExplosion=p.value;
            else if(int(p.round)==round && p.stage=="native-end" && !source)peerEnd=getTimer();
            else if(int(p.round)==round && p.stage=="native-swap" && !source){swapPeerAt=getTimer();swapLive=p.live===true;}
            else if(host && int(p.round)==round && p.stage=="result"){peerResult=p.value;advance();}
            else if(p.stage=="done")finish();
         } catch(err:Error){fail(err.getStackTrace());}
      }
      private function nextRound():void {
         if(round+1>=cases.length*2){send("done");finish();return;}
         prepare(round+1);send("prepare");
      }
      private function render(e:Event):void {
         if(phase!="run")return;
         try {
            var now:int=getTimer();observedFrames++;
            if(source && gun!=null && gun.b!=null && !nativeShots[gun.b]) {
               var bullet:Object=gun.b;
               nativeShots[bullet]=true;sourceShots++;issued=true;lastShotFrame=gameFrame;releasePending=true;
               if(gasBullets.length>0 && gasBullets[0].bullet.in_chain)gasOverlap=true;
               gasBullets.push({bullet:bullet,born:now,bornWall:new Date().time,exploded:0,end:0});
               if(nativeBullet==null){nativeBullet=bullet;nativeBirth=now;nativeClass=getQualifiedClassName(bullet.vis);}
               check(getQualifiedClassName(bullet)=="fe.weapon::PhisBullet" && Number(bullet.explRadius)>0
                  && int(bullet.tipDamage)==7,"native G creates actual toxic PhisBullet shot="+sourceShots);
               send("native-born",{cls:nativeClass});
            }
            if(source) {
               var ended:Boolean=sourceShots==int(spec.shots);
               for each(var record:Object in gasBullets) {
                  bullet=record.bullet;
                  if(bullet.isExpl && record.exploded==0)record.exploded=now;
                  if(!bullet.in_chain && record.end==0)record.end=now;
                  ended=ended && record.end>0;
               }
               if(ended && !gasDone){gasDone=true;nativeEnd=now;send("native-end");}
            } else {
               var guard:int=0;
               for(var o:Object=mod.game.loc.firstObj;o!=null && guard++<20000;o=o.nobj) {
                  var cname:String=getQualifiedClassName(o);
                  if((cname=="fe.weapon::Bullet" || cname=="fe.weapon::PhisBullet") && o.weap!=null
                     && String(o.weap.id)==spec.id && !unexpected[o]){unexpected[o]=true;unexpectedBullets++;}
               }
               if(guard>=20000)throw new Error("Native object chain exceeds fixture bound");
            }
            ground.scan(gameFrame);groundCount=ground.count;
         } catch(err:Error){fail(err.getStackTrace());}
      }
      private function sampleFlight(v:DisplayObject,now:int,dt:int):Boolean {
         if(v==null || !v.visible || v.stage==null || v.alpha<=0)return false;
         var bounds:Rectangle=v.getBounds(mod.main as DisplayObject).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(bounds.width<1 || bounds.height<1)return false;
         // Establish native artwork in the final game once per projectile.
         // Re-drawing a whole room twice on every post-impact frame amplified
         // fireball's many flame Parts and distorted the source flight clock.
         // Presence, visibility, bounds, pose and end remain sampled each frame.
         if(flightPixelSeen[v]!==true) {
            flightPixelSeen[v]=true;
         }
         if(!isNaN(lastRotation) && Math.abs(v.rotation-lastRotation)>.1)rotations++;
         lastRotation=v.rotation;
         if(flightPositions.length<300)flightPositions.push({at:now,x:v.x,y:v.y,r:v.rotation});
         return true;
      }

      private function complete():void {
         // Stop action sampling before any bitmap readback or PNG encoding.
         setPhase("result");var proof:Object=ground.result(),shots:Array=[];
         for each(var record:Object in gasBullets)shots.push({born:record.born,bornWall:record.bornWall,
            exploded:record.exploded,end:record.end});
         localResult={source:source,id:spec.id,requested:int(spec.shots),shots:sourceShots,shotRows:shots,
            overlap:gasOverlap,unexpected:unexpectedBullets,inputReleased:inputReleased,throwGates:throwGates,proof:proof};
         Log.d("GAS PULSE RESULT "+JSON.stringify({round:round,role:host?"host":"join",value:localResult}));
         check(!proof.overflow && proof.visualRows.length>0,"bounded actual gas visuals exist");
         check(proof.pixel!=null && proof.pixel.pixels>0,"real gas contributes final-stage pixels; encoding follows sampling");
         check(proof.allEnded,"every observed gas visual reaches its real end");
         if(source) {
            check(sourceShots==int(spec.shots) && inputReleased>0,"requested actual G throws and input release");
            var released:Boolean=throwGates.length==Math.max(0,int(spec.shots)-1);
            for each(var gate:Object in throwGates)released=released && gate.tAuto==0 && gate.attackPos===true
               && gate.tAttack<=0 && gate.tReload<=0 && gate.frame>gate.afterFrame;
            check(released,"each repeated G waits for native release latch and attack readiness without writes");
            check(proof.nativeRows.length>0 && proof.visualRows.length==proof.nativeRows.length,
               "source actual Part identities correspond to artwork, without expected twelve assumption");
            check(int(spec.shots)==1 || gasOverlap,"double trial has two simultaneously live native projectiles");
         } else {
            check(unexpectedBullets==0 && proof.nativeRows.length==0,"receiver creates no native gas Part or damaging projectile");
            check(proof.wireRows.length>0 && proof.wireRows.length==proof.visualRows.length,
               "actual unique production gas records each appear once in display tree");
            var terminal:Boolean=proof.wireRows.length>0;
            for each(var row:Object in proof.wireRows)terminal=terminal && row.end>0 && row.strictEnd===true;
            check(terminal,"every actually received gas record has source ending and strict native lifetime");
         }
         if(host)advance();else send("result",{value:localResult});
      }
      private function advance():void {
         if(!host || localResult==null || peerResult==null)return;
         var origin:Object=localResult.source?localResult:peerResult,remote:Object=localResult.source?peerResult:localResult;
         check(origin.proof.nativeRows.length>0 && origin.proof.nativeRows.length==remote.proof.wireRows.length
            && origin.proof.nativeRows.length==remote.proof.visualRows.length,
            "actual source Part count equals distinct wire and remote visual counts; source="+origin.proof.nativeRows.length
            +" wire="+remote.proof.wireRows.length+" visual="+remote.proof.visualRows.length);
         nextRound();
      }
      private function restoreWeapon():void {
         if(!saved)return;
         var g:Object=mod.game.gg;
         if(gun!=null){if(g.throwWeapon===gun)g.invent.favItem(gun.id,29);gun.remVisual();gun=null;}
         if(ammo!=""){g.invent.items[ammo].kol=oldAmmo;ammo="";}
         if(swapInventory!=null) {
            g.invent.weapons=swapInventory.weapons;g.invent.fav=swapInventory.fav;g.invent.favIds=swapInventory.favIds;
            swapInventory=null;
         }
         if(g.currentWeapon!==standby)g.changeWeapon("lmg",true);g.throwWeapon=null;g.magicWeapon=null;
         if(standby!=null)standby.addVisual();
      }
      private function copyArray(value:Array):Array {
         // Array.concat loses the string-keyed weapon and favourite entries.
         var result:Array=[];for(var key:String in value)result[key]=value[key];return result;
      }
      private function onError(e:UncaughtErrorEvent):void {
         e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
      }
      private function fail(s:String):void {
         if(gun!=null)Log.d("GAS INPUT DIAGNOSTIC "+JSON.stringify({round:round,phase:phase,shots:sourceShots,
            requested:spec==null?0:int(spec.shots),pending:releasePending,frame:gameFrame,lastShotFrame:lastShotFrame,
            tAuto:int(gun.t_auto),tAttack:int(gun.t_attack),tReload:int(gun.t_reload),attackPos:gun.attackPos(),gates:throwGates}));
         check(false,s);send("done");finish();
      }
      private function finish():void {
         if(phase=="done")return;setPhase("done");t.stop();if(ground!=null)ground.dispose();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,bootFrame);
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);
            mod.stage.removeEventListener(Event.ENTER_FRAME,clockBefore);mod.stage.removeEventListener(Event.ENTER_FRAME,clockAfter);
            if(saved && mod.game.gg!=null) {
               restoreWeapon();var g:Object=mod.game.gg,w:Object=mod.game.world;
               g.changeWeapon("not",true);
               g.invent.weapons=originalInventory.weapons;g.invent.fav=originalInventory.fav;g.invent.favIds=originalInventory.favIds;
               g.childObjs=oldChildren;if(oldGun!=null)g.changeWeapon(oldGun.id,true);
               g.throwWeapon=oldThrow;g.magicWeapon=oldMagic;g.pers.grenader=oldGrenader;
               check(g.currentWeapon===oldGun && g.invent.weapons===originalInventory.weapons
                  && g.invent.fav===originalInventory.fav && g.invent.favIds===originalInventory.favIds,
                  "original owned inventory and equipped weapon restored");
               mod.game.loc.sky=oldSky;w.weaponsLevelsOff=oldLevels;
               w.ctr.keyAttack=w.ctr.keyGrenad=w.ctr.keyMagic=false;
               if(oldGun!=null)oldGun.addVisual();
               for each(var r:Object in tiles)for(var key:String in r.fields)r.tile[key]=r.fields[key];
               w.redrawLoc();
            }
         }
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         Log.d("COOP EFFECTS DONE gas-pulse-native "+(host?"host":"join"));
      }
   }
}
