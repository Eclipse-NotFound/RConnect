package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
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

   /** Unrun native fixture. Real controller input -> installed MSW -> actual
    * no-vis Bullet.isExpl -> production TCP -> native Part pixels, both ways.
    * No direct shoot/explosion/explRun/step or presentation.receive calls.
    * It temporarily sets only the isolated MSW instance's wallHits=1 in memory. */
   public class MSWNoVisualExplosionTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,source:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1;
      private var baseX:Number,baseY:Number,floorY:int,wallX:int,tiles:Array=[];
      private var saved:Boolean=false,old:Object,msw:Object,oldWallHits:int,gun:Object,standby:Object,ammo:String="",oldAmmo:Number;
      private var primary:Object,dummy:Object,sourceShots:int=0,sourceExplosion:Object,peerExplosion:Object,endAt:int=0;
      private var sourceSeen:Dictionary=new Dictionary(),partSeen:Dictionary=new Dictionary(),unexpected:Dictionary=new Dictionary();
      private var partCount:int=0,partPixels:int=0,positions:Array=[],unexpectedCount:int=0,dummyCount:int=0;
      private var effectClass:Class,effectBitmap:BitmapData,localResult:Object,peerResult:Object;
      private var wireSeen:Object={},wireEvents:Array=[],failed:int=0;

      public function MSWNoVisualExplosionTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {
         if(!ok)failed++;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"msw-no-visual "+s+" round="+round);
      }
      private function setPhase(value:String):void {phase=value;at=getTimer();}
      private function send(step:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="msw-no-visual-test";p.step=step;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function copyArray(value:Array):Array {var out:Array=[];for(var key:String in value)out[key]=value[key];return out;}
      private function setup():void {
         var ad:Object=RConnectModDomains.find(mod.main,"MoreSkillsWeaponsMod");
         if(ad==null)throw new Error("Installed MSW sibling loader missing");
         msw=ad.getDefinition("MoreSkillsWeaponsMod").testInstance();
         if(msw==null||msw.cfg==null)throw new Error("Installed MSW isolated testInstance unavailable");
         oldWallHits=int(msw.cfg.wallHits);msw.cfg.wallHits=1;
         var g:Object=mod.game.gg,w:Object=mod.game.world;g.anim();
         old={weapon:g.currentWeapon,children:g.childObjs.concat(),thrown:g.throwWeapon,magic:g.magicWeapon,
            grenader:g.pers.grenader,sky:mod.game.loc.sky,levels:w.weaponsLevelsOff,
            weapons:g.invent.weapons,fav:g.invent.fav,favIds:g.invent.favIds};saved=true;
         g.invent.weapons=copyArray(g.invent.weapons);g.invent.fav=copyArray(g.invent.fav);g.invent.favIds=copyArray(g.invent.favIds);
         g.changeWeapon("not",true);g.invent.weapons.lmg=null;standby=g.invent.addWeapon("lmg");g.changeWeapon("lmg",true);
         g.throwWeapon=g.magicWeapon=null;g.pers.grenader=0;mod.game.loc.sky=false;w.weaponsLevelsOff=false;
         mod.game.loc.base=mod.game.loc.black=w.black=false;if(g.teleObj!=null)g.dropTeleObj();
         check(g.currentWeapon===standby&&g.invent.weapons.lmg===standby,"native owned inventory standby");
         floorY=int(baseY/40);wallX=int(baseX/40)+8;
         for(var x:int=int(baseX/40)-2;x<=wallX;x++)for(var y:int=floorY-6;y<=floorY;y++) {
            var tile:Object=mod.game.loc.space[x][y],fields:Object={};
            for each(var key:String in ["phis","opac","front","water","indestruct","phX1","phX2","phY1","phY2","zForm","diagon","stair","shelf"])fields[key]=tile[key];
            tiles.push({tile:tile,fields:fields,x:x,y:y});
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function restoreWeapon():void {
         if(!saved)return;var g:Object=mod.game.gg;
         if(gun!=null){gun.remVisual();gun=null;}
         if(ammo!=""){g.invent.items[ammo].kol=oldAmmo;ammo="";}
         if(g.currentWeapon!==standby)g.changeWeapon("lmg",true);
         g.throwWeapon=g.magicWeapon=null;standby.addVisual();
      }
      private function prepare(n:int):void {
         restoreWeapon();round=n;source=host==(n==0);
         primary=dummy=sourceExplosion=peerExplosion=localResult=peerResult=null;
         sourceShots=partCount=partPixels=unexpectedCount=dummyCount=endAt=0;
         sourceSeen=new Dictionary();partSeen=new Dictionary();unexpected=new Dictionary();positions=[];wireSeen={};wireEvents=[];
         for each(var r:Object in tiles) {
            var tile:Object=r.tile,solid:Boolean=r.y==floorY||r.x==wallX||r.x==int(baseX/40)-2;
            tile.phis=solid?1:0;tile.opac=solid?1:0;tile.front="";tile.water=0;tile.indestruct=true;
            tile.zForm=tile.diagon=tile.stair=0;tile.shelf=false;
            tile.phX1=r.x*40;tile.phX2=(r.x+1)*40;tile.phY1=r.y*40;tile.phY2=(r.y+1)*40;
         }
         mod.game.world.redrawLoc();
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr.expl;
         if(emitter==null)throw new Error("Native explosion resource missing");
         effectClass=emitter.visClass as Class;effectBitmap=emitter.blit?mod.game.world.grafon.getSpriteList(emitter.blit,1):null;
         // Exclude particles that already existed before this round. Never
         // remove them or count their pixels as evidence of the new explosion.
         var existingGuard:int=0;
         for(var existing:Object=mod.game.loc.firstObj;existing!=null&&existingGuard++<10000;existing=existing.nobj)
            if(getQualifiedClassName(existing)=="fe.graph::Part")partSeen[existing]="preexisting";
         if(source) {
            var g:Object=mod.game.gg;g.invent.weapons.mswglau=null;gun=g.invent.addWeapon("mswglau");
            if(gun==null)throw new Error("Installed MSW did not inject mswglau");
            gun.setPers(g,g.pers);gun.lvl=gun.perslvl=0;
            ammo=String(gun.ammo);oldAmmo=Number(g.invent.items[ammo].kol);g.invent.items[ammo].kol=Math.max(oldAmmo,50);
            g.changeWeapon("mswglau",true);gun.hold=gun.holder;
            check(g.currentWeapon===gun&&g.invent.weapons.mswglau===gun,"native owned MSW weapon equipped");
         }
         Log.d("MSW NO VIS PREPARE "+JSON.stringify({round:round,source:source,wallHits:msw.cfg.wallHits}));setPhase("prepared");
      }
      private function before(e:Event):void {
         if(!saved||phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,ctr:Object=w.ctr;
         mod.game.forceCloseOverlays();g.invulner=true;g.disabled=!source;g.ggControl=true;g.isTake=0;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=1;g.setVisPos();
         for each(var u:Object in mod.game.loc.units)if(u!==g){u.disabled=true;u.invulner=true;u.trigDis=true;}
         ctr.keyLeft=ctr.keyRight=ctr.keyBeUp=ctr.keySit=ctr.keyJump=ctr.keyTele=ctr.keyAction=false;
         ctr.keyRun=ctr.keyPunch=ctr.keyReload=ctr.keyGrenad=ctr.keyMagic=ctr.keyAttack=false;
         g.celX=w.celX=baseX+210;g.celY=w.celY=baseY-45;
         w.cam.celX=w.celX*w.cam.scaleV+w.cam.vx;w.cam.celY=w.celY*w.cam.scaleV+w.cam.vy;
         if(phase=="run"&&source&&gun!=null&&gun.b==null)ctr.keyAttack=true;
         mod.stage.invalidate();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host)for each(var l:TcpLink in mod.session.server.clients)watch(l);else watch(mod.session.link);
         if(phase=="done")return;var w:Object=mod.game.world;mod.game.gg.invulner=true;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>(phase=="boot"?180000:30000)){fail("timeout "+phase);return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&t.currentCount>130&&getTimer()-readyAt>500&&(!w.vblack.visible||w.vblack.alpha<=0)) {
            readyAt=getTimer();send("ready");
         }
         if(phase=="run"&&endAt>0&&getTimer()-endAt>=2500)complete();
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(phase=="run"&&!source) {
            if(p.snap!=null)wire(p.snap);
            if(p.players is Array)for each(var player:Object in p.players)if(int(player.id)==0)wire(player.snap);
         }
         if(p.type!="msw-no-visual-test"||phase=="done")return;
         try {
            if(host&&p.step=="ready"&&phase=="boot") {
               if(mod.game.loc.spaceX<15||mod.game.loc.spaceY<10)throw new Error("Fixture requires room at least 15x10");
               baseX=Math.max(160,Math.min(Math.floor(mod.game.gg.X/40)*40,mod.game.loc.spaceX*40-440));
               baseY=Math.max(280,Math.min(Math.floor(mod.game.gg.Y/40)*40,(mod.game.loc.spaceY-2)*40));
               setup();setPhase("setup");send("setup",{x:baseX,y:baseY});
            } else if(!host&&p.step=="setup"&&phase=="boot") {baseX=p.x;baseY=p.y;setup();setPhase("setup");send("setup-ready");}
            else if(host&&p.step=="setup-ready"&&phase=="setup")next();
            else if(!host&&p.step=="prepare"){prepare(int(p.round));send("prepared");}
            else if(host&&p.step=="prepared"&&int(p.round)==round&&phase=="prepared"){setPhase("run");send("go");}
            else if(!host&&p.step=="go"&&int(p.round)==round&&phase=="prepared")setPhase("run");
            else if(!source&&p.step=="explosion"&&int(p.round)==round){peerExplosion=p.value;endAt=getTimer();}
            else if(host&&p.step=="result"&&int(p.round)==round){peerResult=p.value;advance();}
            else if(p.step=="done")finish();
         }catch(err:Error){fail(err.getStackTrace());}
      }
      private function wire(snap:Object):void {
         if(snap==null||!(snap.weapons is Array))return;
         for each(var w:Object in snap.weapons)if(w.id=="mswglau")for each(var e:Object in w.events)
            if(e.flight==null&&e.explosion!=null) {
               var key:String=w.stream+":"+e.seq;if(wireSeen[key])continue;wireSeen[key]=true;
               wireEvents.push({stream:w.stream,seq:e.seq,explosion:e.explosion,received:getTimer()});
               Log.d("MSW NO VIS WIRE "+JSON.stringify(wireEvents[wireEvents.length-1]));
            }
      }
      private function render(e:Event):void {
         if(phase!="run")return;
         try {
            if(source&&gun.b!=null&&!sourceSeen[gun.b]) {
               sourceSeen[gun.b]=true;sourceShots++;primary=gun.b;
               check(getQualifiedClassName(primary)=="fe.weapon::Bullet"&&primary.vis!=null&&Number(primary.explRadius)==0
                  &&Number(primary.damageExpl)>0&&int(msw.cfg.wallHits)==1,"real input fired MSW manual-detonation branch");
            }
            var guard:int=0;
            for(var o:Object=mod.game.loc.firstObj;o!=null&&guard++<10000;o=o.nobj) {
               var cls:String=getQualifiedClassName(o);
               if(source&&cls=="fe.weapon::Bullet"&&o.owner===mod.game.gg&&o.weap===gun&&o.vis==null&&o.isExpl===true
                  &&Number(o.explRadius)>0&&!sourceSeen[o]) {
                  sourceSeen[o]=true;dummyCount++;dummy=o;
                  sourceExplosion={x:o.X,y:o.Y,at:getTimer(),water:Number(o.inWater)>0,liv:o.liv,cls:cls};
                  check(o!==primary&&int(o.liv)==1,"actual independent no-vis native dummy observed after MSW frame");
                  endAt=getTimer();send("explosion",{value:sourceExplosion});
                  Log.d("MSW NO VIS NATIVE "+JSON.stringify(sourceExplosion));
               }
               if(cls=="fe.graph::Part"&&((effectClass!=null&&o.vClass===effectClass)||(effectBitmap!=null&&o.blitData===effectBitmap))) {
                  if(partSeen[o]==="preexisting")continue;
                  if(!partSeen[o]){partSeen[o]=true;partCount++;positions.push({x:o.X,y:o.Y,at:getTimer()});}
                  if(partPixels==0&&pixels(o.vis as DisplayObject)>0)partPixels++;
               }
               if(!source&&(cls=="fe.weapon::Bullet"||cls=="fe.weapon::PhisBullet")&&o.weap!=null&&o.weap.id=="mswglau"&&!unexpected[o]) {
                  unexpected[o]=true;unexpectedCount++;
               }
            }
         }catch(err:Error){fail(err.getStackTrace());}
      }
      private function pixels(v:DisplayObject):int {
         if(v==null||!v.visible||v.stage==null||v.alpha<=0)return 0;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1||r.height<1||r.width*r.height>500000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),was:Boolean=v.visible,n:int=0;
         try {a.draw(root,matrix);v.visible=false;b.draw(root,matrix);
            var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect);
            for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;
         }finally{v.visible=was;a.dispose();b.dispose();}return n;
      }
      private function complete():void {
         var actual:Object=source?sourceExplosion:peerExplosion;
         check(actual!=null&&!actual.water,"source confirms a dry actual no-vis native explosion");
         check(partCount==1&&partPixels>0,"exactly one native explosion Part has real stage pixels count="+partCount);
         var aligned:Boolean=actual!=null&&positions.length==1;
         for each(var p:Object in positions)aligned=aligned&&Math.abs(p.x-actual.x)<=1&&Math.abs(p.y-actual.y)<=1;
         check(aligned,"native Part is at observed dummy position");
         if(source)check(sourceShots==1&&dummyCount==1,"one native controller shot produced exactly one independent dummy");
         else {
            check(wireEvents.length==1,"one standalone explosion identity arrived through actual TCP");
            var matched:Boolean=wireEvents.length==1&&actual!=null;
            if(matched)matched=Math.abs(wireEvents[0].explosion.x-actual.x)<=1&&Math.abs(wireEvents[0].explosion.y-actual.y)<=1;
            check(matched,"standalone wire event matches actual source dummy");
            check(unexpectedCount==0,"cosmetic receiver creates no native MSW damaging Bullet");
         }
         localResult={source:source,round:round,shots:sourceShots,dummies:dummyCount,parts:partCount,pixels:partPixels,
            positions:positions,wire:wireEvents,unexpected:unexpectedCount,explosion:actual,failed:failed};
         Log.d("MSW NO VIS RESULT "+JSON.stringify(localResult));setPhase("result");
         if(host)advance();else send("result",{value:localResult});
      }
      private function advance():void {
         if(!host||localResult==null||peerResult==null)return;
         check(localResult.parts==1&&peerResult.parts==1,"source and receiver each render exactly one actual explosion");next();
      }
      private function next():void {if(round>=1){send("done");finish();}else {prepare(round+1);send("prepare");}}
      private function onError(e:UncaughtErrorEvent):void {e.preventDefault();fail(e.error is Error?Error(e.error).getStackTrace():String(e.error));}
      private function fail(text:String):void {check(false,text);send("done");finish();}
      private function finish():void {
         if(phase=="done")return;setPhase("done");t.stop();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);
            if(msw!=null)msw.cfg.wallHits=oldWallHits;
            if(saved&&mod.game.gg!=null) {
               restoreWeapon();var g:Object=mod.game.gg,w:Object=mod.game.world;g.changeWeapon("not",true);
               g.invent.weapons=old.weapons;g.invent.fav=old.fav;g.invent.favIds=old.favIds;
               g.currentWeapon=old.weapon;g.childObjs=old.children;g.throwWeapon=old.thrown;g.magicWeapon=old.magic;g.pers.grenader=old.grenader;
               mod.game.loc.sky=old.sky;w.weaponsLevelsOff=old.levels;w.ctr.keyAttack=w.ctr.keyGrenad=w.ctr.keyMagic=false;
               if(old.weapon!=null)old.weapon.addVisual();for each(var r:Object in tiles)for(var key:String in r.fields)r.tile[key]=r.fields[key];w.redrawLoc();
            }
         }
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         Log.d("COOP EFFECTS DONE msw-no-visual "+(host?"host":"join")+" rounds="+(round+1)+" failed="+failed);
      }
   }
}
