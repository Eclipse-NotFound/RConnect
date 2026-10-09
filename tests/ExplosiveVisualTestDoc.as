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

   /** Native player input -> real Bullet/PhisBullet -> production TCP -> pixels.
    * This driver never calls shoot, Bullet.step/run/explosion, cosmetic receive
    * or the production explosion recipe. It also runs against the old SWF.
    * Each weapon fires once in each direction; the receiver never fires it. */
   public class ExplosiveVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"dinamit",quick:true,water:false,part:"expl",extended:true},
         {id:"grenade",quick:true,water:false,part:"expl"},
         {id:"aglau",quick:false,water:false,part:"expl"},
         {id:"bfg",quick:false,water:false,part:"plaexpl"},
         {id:"spgren",quick:true,water:false,part:"sparkleexpl"},
         {id:"grenade",quick:true,water:true,part:"explw"},
         {id:"grenade",quick:true,water:false,part:"expl",swap:true}
      ];
      private var mod:RConnectMod,host:Boolean,source:Boolean,t:Timer=new Timer(100);
      private var links:Dictionary=new Dictionary(),phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var round:int=-1,spec:Object,baseX:Number,baseY:Number,wallX:int,floorY:int;
      private var oldGun:Object,oldChildren:Object,oldThrow:Object,standby:Object,gun:Object;
      private var oldAmmo:Number=0,ammo:String="",oldGrenader:*,oldSky:Boolean,oldLevels:Boolean;
      private var saved:Boolean=false,tiles:Array=[],nativeBullet:Object,nativeClass:String="";
      private var nativeBirth:int=0,nativeEnd:int=0,nativeExplosion:Object,peerExplosion:Object;
      private var peerEnd:int=0,sourceShots:int=0,lastFrame:int=0,flightFrames:int=0,flightMs:Number=0;
      private var flightLate:int=0,flightPeak:int=0,flightClear:int=0,bounces:int=0,lastDY:Number=0;
      private var rotations:int=0,lastRotation:Number=NaN,flightPositions:Array=[];
      private var explosionParts:int=0,explosionPixels:int=0,explosionPositions:Array=[];
      private var parts:Dictionary=new Dictionary(),nativeShots:Dictionary=new Dictionary();
      private var unexpected:Dictionary=new Dictionary(),unexpectedBullets:int=0;
      private var effectClass:Class,effectBitmap:BitmapData,localResult:Object,peerResult:Object;
      private var swapInventory:Object,swapRequested:int=0,swapDetached:int=0,swapPeerAt:int=0;
      private var swapLive:Boolean=false,swapFlightFrames:int=0,swapLmgFrames:int=0;

      public function ExplosiveVisualTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"explosive-visual "+s+" round="+round);
      }
      private function send(stage:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="explosive-visual-test";p.stage=stage;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null && !links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function setPhase(s:String):void {phase=s;at=getTimer();}
      private function setup():void {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         oldGun=g.currentWeapon;oldChildren=g.childObjs;oldThrow=g.throwWeapon;
         oldGrenader=g.pers.grenader;oldSky=mod.game.loc.sky;oldLevels=w.weaponsLevelsOff;saved=true;
         var wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         standby=wc.create(g,"lmg",0);standby.setPers(g,g.pers);standby.addVisual();
         if(oldGun!=null)oldGun.remVisual();
         g.currentWeapon=standby;g.childObjs=[standby,g.punchWeapon];g.throwWeapon=null;
         // Isolated fixture only: disable the proximity perk, keep the native
         // weapon's fuse/velocity/gravity/bounce and the whole simulation intact.
         g.pers.grenader=0;mod.game.loc.sky=false;w.weaponsLevelsOff=false;
         mod.game.loc.base=false;mod.game.loc.black=false;w.black=false;
         if(g.teleObj!=null)g.dropTeleObj();
         floorY=int(baseY/40);wallX=int(baseX/40)+8;
         saveTiles();
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
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
         restoreWeapon();round=n;spec=CASES[int(n/2)];source=host==(n%2==0);
         nativeBullet=null;nativeClass="";nativeBirth=nativeEnd=peerEnd=sourceShots=0;
         nativeExplosion=peerExplosion=localResult=peerResult=null;
         flightFrames=flightLate=flightPeak=flightClear=bounces=rotations=explosionParts=explosionPixels=0;
         flightMs=0;lastFrame=0;lastDY=0;lastRotation=NaN;unexpectedBullets=0;
         swapRequested=swapDetached=swapPeerAt=swapFlightFrames=swapLmgFrames=0;swapLive=false;
         flightPositions=[];explosionPositions=[];parts=new Dictionary();nativeShots=new Dictionary();unexpected=new Dictionary();
         for each(var r:Object in tiles) {
            var tile:Object=r.tile,solid:Boolean=r.y==floorY || r.x==wallX || r.x==int(baseX/40)-2;
            tile.phis=solid?1:0;tile.opac=solid?1:0;tile.front="";tile.indestruct=true;
            tile.water=spec.water && !solid?1:0;tile.zForm=tile.diagon=tile.stair=0;tile.shelf=false;
            tile.phX1=r.x*40;tile.phX2=(r.x+1)*40;tile.phY1=r.y*40;tile.phY2=(r.y+1)*40;
         }
         mod.game.world.redrawLoc();
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr[spec.part];
         if(emitter==null)throw new Error("Missing native emitter "+spec.part);
         effectClass=emitter.visClass as Class;effectBitmap=emitter.blit?mod.game.world.grafon.getSpriteList(emitter.blit,1):null;
         if(source) {
            var g:Object=mod.game.gg,wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=wc.create(g,spec.id,0);gun.setPers(g,g.pers);gun.lvl=0;gun.perslvl=0;
            ammo=String(gun.ammo);oldAmmo=Number(g.invent.items[ammo].kol);g.invent.items[ammo].kol=Math.max(oldAmmo,50);
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
            } else if(spec.quick) {
               g.throwWeapon=gun;gun.loc=mod.game.loc;gun.setNull();
               check(g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,"quick throw uses native throwWeapon outside currentWeapon/childObjs id="+spec.id);
            } else {
               standby.remVisual();g.currentWeapon=gun;g.childObjs=[gun,g.punchWeapon];gun.addVisual();gun.hold=gun.holder;
            }
         }
         Log.d("EXPLOSIVE PREPARE "+JSON.stringify({round:round,id:spec.id,water:spec.water,source:source,role:host?"host":"join"}));
         setPhase("prepared");
      }
      private function before(e:Event):void {
         if(!saved || phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,ctr:Object=w.ctr;
         mod.game.forceCloseOverlays();g.invulner=true;g.disabled=!source;g.ggControl=true;g.isTake=0;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=1;g.setVisPos();
         for each(var u:Object in mod.game.loc.units)if(u!==g){u.disabled=true;u.invulner=true;u.trigDis=true;}
         ctr.keyLeft=ctr.keyRight=ctr.keyBeUp=ctr.keySit=ctr.keyJump=ctr.keyTele=ctr.keyAction=false;
         ctr.keyRun=ctr.keyPunch=ctr.keyReload=false;
         ctr.keyAttack=ctr.keyGrenad=ctr.keyMagic=false;
         g.celX=w.celX=baseX+210;g.celY=w.celY=baseY-45;
         w.cam.celX=w.celX*w.cam.scaleV+w.cam.vx;w.cam.celY=w.celY*w.cam.scaleV+w.cam.vy;
         if(phase=="run" && source && gun!=null && gun.b==null) {
            if(spec.quick)ctr.keyGrenad=true;else ctr.keyAttack=true;
         }
         mod.stage.invalidate();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         var w:Object=mod.game.world;mod.game.gg.invulner=true;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase=="done")return;
         if(getTimer()-at>(phase=="boot"?70000:26000)){fail("timeout "+phase);return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         try {
            if(phase=="boot" && !host && t.currentCount>130 && getTimer()-readyAt>500 && (!w.vblack.visible || w.vblack.alpha<=0)) {
               readyAt=getTimer();send("ready");
            }
            if(phase=="run") {
               if(source && nativeEnd>0 && getTimer()-nativeEnd>=2100)complete();
               else if(!source && peerEnd>0 && getTimer()-peerEnd>=2100)complete();
            }
         } catch(err:Error){fail(err.getStackTrace());}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="explosive-visual-test" || phase=="done")return;
         try {
            if(host && p.stage=="ready" && phase=="boot") {
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
         if(round+1>=CASES.length*2){send("done");finish();return;}
         prepare(round+1);send("prepare");
      }
      private function render(e:Event):void {
         if(phase!="run")return;
         try {
            var now:int=getTimer(),dt:int=lastFrame==0?0:now-lastFrame;lastFrame=now;
            if(source && gun!=null && gun.b!=null && !nativeShots[gun.b]) {
               nativeShots[gun.b]=true;sourceShots++;
               if(nativeBullet==null) {
                  nativeBullet=gun.b;nativeBirth=now;nativeClass=getQualifiedClassName(nativeBullet.vis);
                  send("native-born",{cls:nativeClass});
                  check(Number(nativeBullet.explRadius)>0 && (spec.quick?getQualifiedClassName(nativeBullet)=="fe.weapon::PhisBullet":true),
                     "native input fired the requested explosive id="+spec.id+" bullet="+getQualifiedClassName(nativeBullet));
                  Log.d("EXPLOSIVE NATIVE BORN "+JSON.stringify({round:round,cls:nativeClass,liv:nativeBullet.liv,dx:nativeBullet.dx,dy:nativeBullet.dy,damage:nativeBullet.damage,damageExpl:nativeBullet.damageExpl}));
                  if(spec.swap) {
                     // Native favourite-toggle clears the old quick slot;
                     // changeWeapon(false) performs the normal timed switch.
                     // Do not touch the flying Bullet or force its end/pose.
                     swapRequested=now;
                     mod.game.gg.invent.favItem(spec.id,29);
                     mod.game.gg.changeWeapon("lmg");
                  }
               }
            }
            var visible:Boolean=false;
            if(source && nativeBullet!=null) {
               if(spec.swap && swapDetached==0 && mod.game.gg.currentWeapon===standby
                  && mod.game.gg.throwWeapon!==gun && mod.game.gg.childObjs.indexOf(gun)<0) {
                  swapDetached=now;swapLive=nativeBullet.in_chain && !nativeBullet.isExpl;
                  send("native-swap",{live:swapLive});
                  Log.d("EXPLOSIVE NATIVE SWAP "+JSON.stringify({round:round,requested:swapRequested,born:nativeBirth,detached:now,
                     live:swapLive,weapon:mod.game.gg.currentWeapon.id,remaining:nativeBullet.liv}));
               }
               if(nativeBullet.isExpl && nativeExplosion==null) {
                  nativeExplosion={x:nativeBullet.X,y:nativeBullet.Y,at:now,water:Number(nativeBullet.inWater)>0,life:now-nativeBirth};
                  send("native-explosion",{value:nativeExplosion});
               }
               if(!nativeBullet.in_chain && nativeEnd==0){nativeEnd=now;send("native-end");}
               if(lastDY>0.5 && Number(nativeBullet.dy)<-0.5)bounces++;
               lastDY=Number(nativeBullet.dy);
               // Bullet.step can keep its native clip visible for the final
               // post-impact frames. Compare actual pixels on both sides;
               // isExpl alone is not the native display's removal boundary.
               if(nativeBullet.in_chain)visible=sampleFlight(nativeBullet.vis as DisplayObject,now,dt);
            } else if(!source && nativeClass!="") {
               var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],copies:int=0;
               for(var i:int=0;i<layer.numChildren;i++) {
                  var v:DisplayObject=layer.getChildAt(i);
                  // An equipped WThrow uses the same display class as its
                  // projectile. The new swap case must not count the held
                  // grenade as a second flying grenade before LMG arrives.
                  if(spec.swap) {
                     var peer:Object=mod.game.getRemoteGhost(host?1:0);
                     if(peer!=null && peer.currentWeapon!=null && peer.currentWeapon.vis===v)continue;
                  }
                  if(getQualifiedClassName(v)==nativeClass && sampleFlight(v,now,dt)){copies++;visible=true;}
               }
               flightPeak=Math.max(flightPeak,copies);
               if(peerEnd>0 && now-peerEnd>1500)flightClear=Math.max(flightClear,copies);
            }
            if(visible){flightFrames++;flightMs+=dt;if(now-at>3300)flightLate++;}
            if(spec.swap && (source?swapDetached>0:swapPeerAt>0)) {
               if(visible)swapFlightFrames++;
               var shown:Object=source?mod.game.gg:mod.game.getRemoteGhost(host?1:0);
               if(shown!=null && shown.currentWeapon!=null && shown.currentWeapon.id=="lmg")swapLmgFrames++;
            }
            // Native Part identity discriminates a real explosion from gun
            // flashes, UI blips and Bullet hit particles. Blitted explosions
            // share MovieClip's class, so compare the native sprite sheet too.
            var guard:int=0;
            for(var o:Object=mod.game.loc.firstObj;o!=null && guard++<10000;o=o.nobj) {
               var cname:String=getQualifiedClassName(o);
               if(cname=="fe.graph::Part" && ((effectClass!=null && o.vClass===effectClass) || (effectBitmap!=null && o.blitData===effectBitmap))) {
                  if(!parts[o]){parts[o]=true;explosionParts++;explosionPositions.push({x:o.X,y:o.Y,at:now});}
                  if(pixels(o.vis as DisplayObject)>0)explosionPixels++;
               }
               if(!source && (cname=="fe.weapon::Bullet" || cname=="fe.weapon::PhisBullet") && o.weap!=null && String(o.weap.id)==spec.id && !unexpected[o]) {
                  unexpected[o]=true;unexpectedBullets++;
               }
            }
         } catch(err:Error){fail(err.getStackTrace());}
      }
      private function sampleFlight(v:DisplayObject,now:int,dt:int):Boolean {
         if(v==null || pixels(v)==0)return false;
         if(!isNaN(lastRotation) && Math.abs(v.rotation-lastRotation)>.1)rotations++;
         lastRotation=v.rotation;
         if(flightPositions.length<300)flightPositions.push({at:now,x:v.x,y:v.y,r:v.rotation});
         return true;
      }
      private function pixels(v:DisplayObject):int {
         if(v==null || !v.visible || v.stage==null || v.alpha<=0)return 0;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);
         r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>500000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         var m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),was:Boolean=v.visible,n:int=0;
         try {
            a.draw(root,m);v.visible=false;b.draw(root,m);
            var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect);
            for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;
         } finally {v.visible=was;a.dispose();b.dispose();}
         return n;
      }
      private function complete():void {
         var endpoint:Object=source?nativeExplosion:peerExplosion;
         localResult={source:source,id:spec.id,water:spec.water,shots:sourceShots,flight:flightFrames,ms:flightMs,late:flightLate,
            peak:flightPeak,clear:flightClear,bounces:bounces,rotations:rotations,parts:explosionParts,pixels:explosionPixels,
            unexpected:unexpectedBullets,explosion:endpoint,positions:explosionPositions,
            swap:spec.swap===true,swapRequested:swapRequested,swapDetached:swapDetached,swapLive:swapLive,
            swapFlight:swapFlightFrames,swapLmg:swapLmgFrames};
         Log.d("EXPLOSIVE RESULT "+JSON.stringify(localResult));
         Log.d("EXPLOSIVE FLIGHT "+JSON.stringify({round:round,role:source?"native":"remote",points:flightPositions}));
         check(flightFrames>0,"actual "+(source?"native":"remote")+" flight pixels id="+spec.id+" frames="+flightFrames);
         check(endpoint!=null,"source reached native isExpl before removal id="+spec.id);
         check(explosionParts==1 && explosionPixels>0,"one native explosion effect has actual pixels id="+spec.id+" effects="+explosionParts+" frames="+explosionPixels);
         if(endpoint!=null) {
            check(Boolean(endpoint.water)==Boolean(spec.water),"native detonation uses requested water branch");
            var positionOK:Boolean=explosionPositions.length==1;
            if(positionOK)positionOK=Math.abs(explosionPositions[0].x-endpoint.x)<=1 && Math.abs(explosionPositions[0].y-endpoint.y)<=1;
            check(positionOK,"effect uses actual native detonation position");
         }
         if(source) {
            check(sourceShots==1,"one real source shot, no direct bullet simulation");
            if(spec.quick && !spec.water)check(bounces>0 && rotations>0,"native thrown explosive really bounces and rotates");
         } else {
            check(flightPeak<=1 && flightClear==0,"repeated snapshots neither duplicate nor strand the projectile peak="+flightPeak+" afterEnd="+flightClear);
            check(unexpectedBullets==0,"receiver produces no native damaging projectile for the cosmetic replay");
            if(spec.quick && !spec.water)check(rotations>0,"remote thrown explosive preserves native rotation");
         }
         if(spec.extended)check(flightLate>0 && endpoint!=null && endpoint.life>3300,"long native fuse stays visible beyond old 2.5 second cutoff");
         if(spec.swap) {
            if(source)check(swapRequested==nativeBirth && swapDetached>0 && swapLive,
               "native LMG switch requested on birth frame removes old weapon while grenade is still live");
            else check(swapPeerAt>0 && swapLive,"peer confirms old weapon really left equipment and quick slot before detonation");
            check(swapFlightFrames>0 && swapLmgFrames>0,"in-flight grenade remains visible after LMG switch frames="+swapFlightFrames);
         }
         setPhase("result");
         if(host)advance();else send("result",{value:localResult});
      }
      private function advance():void {
         if(!host || localResult==null || peerResult==null)return;
         var origin:Object=localResult.source?localResult:peerResult,remote:Object=localResult.source?peerResult:localResult;
         check(origin.ms>0 && remote.ms>=origin.ms*.75-100 && remote.ms<=origin.ms*1.35+200,
            "remote preserves native visible flight duration native="+origin.ms+" remote="+remote.ms+" id="+spec.id);
         nextRound();
      }
      private function restoreWeapon():void {
         if(!saved)return;
         var g:Object=mod.game.gg;
         if(gun!=null){gun.remVisual();gun=null;}
         if(ammo!=""){g.invent.items[ammo].kol=oldAmmo;ammo="";}
         if(swapInventory!=null) {
            g.invent.weapons=swapInventory.weapons;g.invent.fav=swapInventory.fav;g.invent.favIds=swapInventory.favIds;
            swapInventory=null;
         }
         g.currentWeapon=standby;g.childObjs=[standby,g.punchWeapon];g.throwWeapon=null;
         if(standby!=null)standby.addVisual();
      }
      private function copyArray(value:Array):Array {
         // Array.concat loses the string-keyed weapon and favourite entries.
         var result:Array=[];for(var key:String in value)result[key]=value[key];return result;
      }
      private function onError(e:UncaughtErrorEvent):void {
         e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
      }
      private function fail(s:String):void {check(false,s);send("done");finish();}
      private function finish():void {
         if(phase=="done")return;setPhase("done");t.stop();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);
            if(saved && mod.game.gg!=null) {
               restoreWeapon();var g:Object=mod.game.gg,w:Object=mod.game.world;
               if(standby!=null)standby.remVisual();
               g.currentWeapon=oldGun;g.childObjs=oldChildren;g.throwWeapon=oldThrow;g.pers.grenader=oldGrenader;
               mod.game.loc.sky=oldSky;w.weaponsLevelsOff=oldLevels;
               w.ctr.keyAttack=w.ctr.keyGrenad=w.ctr.keyMagic=false;
               if(oldGun!=null)oldGun.addVisual();
               for each(var r:Object in tiles)for(var key:String in r.fields)r.tile[key]=r.fields[key];
               w.redrawLoc();
            }
         }
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         Log.d("COOP EFFECTS DONE explosive-visual "+(host?"host":"join"));
      }
   }
}
