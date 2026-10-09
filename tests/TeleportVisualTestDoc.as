package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Drives native Q hold/release across actual TCP and samples real Part
    * objects/final visuals. Never emits an effect, calls Unit.teleport, invents
    * a success event or manually positions a receiving ghost. The relocation
    * negative uses plain setPos precisely to distinguish movement from a cast.
    */
   public class TeleportVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{kind:"short",distance:160,success:true},
         {kind:"long",distance:640,success:true},{kind:"return",distance:-160,success:true},
         {kind:"blocked",distance:160,success:false},{kind:"mana",distance:160,success:false},
         {kind:"short-press",distance:160,success:false},{kind:"relocate",distance:160,success:false},
         {kind:"cooldown",distance:160,success:false},{kind:"sats",distance:160,success:true},
         {kind:"rebuild",distance:160,success:true}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,spec:Object;
      private var source:Boolean=false,baseX:Number=160,baseY:Number,fromX:Number,toX:Number;
      private var prepared:Boolean=false,peerPrepared:Boolean=false,localReported:Boolean=false,peerReported:Boolean=false;
      private var fired:Boolean=false,releaseQ:Boolean=false,nativeFrames:int=0,maxCharge:int=0;
      private var firedAt:int=0,pauseAt:int=0,resumeAt:int=0,pauseRequested:Boolean=false;
      private var pausedFrame:int=-1,pausedLiv:int=-1,pauseWrong:int=0,pauseSamples:int=0,pausedPart:Object;
      private var parts:Dictionary=new Dictionary(true),initial:Dictionary=new Dictionary(true),oldPers:Object={};
      private var bursts:Dictionary=new Dictionary(true);
      private var arrivals:Array=[],ghostSamples:Array=[],frames:Object={},sparkData:BitmapData;
      private var pictures:Array=[];
      private var pixels:int=0,peakSpark:int=0,middle:int=0,pictureCount:int=0;
      private var firstLandingAt:int=0,alignWrong:int=0;
      private var rebuilt:Boolean=false;
      private var peerSource:Object,peerSourceAt:int=0,manaBefore:Number=0,manaAfter:Number=0,postX:Number=NaN;
      private var saved:Boolean=false,oldState:Object,oldWorld:Object,oldRoom:Object,oldPolicy:Object,tiles:Array=[];
      private var oldGun:Object,oldChildren:Object,gun:Object,unitState:Dictionary=new Dictionary(true);

      public function TeleportVisualTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"teleport-visual "+s+" case="+round);}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("TELEPORT PHASE "+(host?"host ":"join ")+s+" case="+round);}
      private function send(stage:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="teleport-visual-test";p.stage=stage;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean {return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();}
      private function setup():void {
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         if(loc.limX<1000 || loc.limY<320)throw new Error("native room too small for long teleport corridor "+loc.limX+"x"+loc.limY);
         baseY=Math.min(320,(int(loc.limY/40)-2)*40)-1;
         oldState={mana:g.mana,maxmana:g.maxmana,disabled:g.disabled,transp:g.transp,invulner:g.invulner,
            ggControl:g.ggControl,x:g.X,y:g.Y,culd:g.t_culd};
         oldWorld={alicorn:w.alicorn,black:w.black};oldRoom={base:loc.base,portOn:loc.portOn,black:loc.black};
         oldPolicy={sats:mod.session.pause.policySats,menu:mod.session.pause.policyMenus};
         oldGun=g.currentWeapon;oldChildren=g.childObjs;
         var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         gun=factory.create(g,"lmg",0);gun.setPers(g,g.pers);gun.hold=gun.holder;gun.lvl=0;gun.perslvl=0;
         if(oldGun!=null)oldGun.remVisual();g.currentWeapon=gun;g.childObjs=[gun,g.punchWeapon];gun.addVisual();
         for each(var k:String in ["portPoss","portTime","spellsPoss","portMana","portMagic","portDown","spellDown","allDManaMult"])
            oldPers[k]=g.pers[k];
         for(var x:int=1;x<=23;x++)for(var y:int=int(baseY/40)-4;y<=int(baseY/40)+1;y++) {
            var tile:Object=loc.space[x][y],fields:Object={};
            for each(k in ["phis","opac","front","water","visi","indestruct","phX1","phX2","phY1","phY2","zForm","diagon","stair","shelf"])
               fields[k]=tile[k];
            tiles.push({tile:tile,fields:fields,x:x,y:y});
         }
         sparkData=w.grafon.getSpriteList("sprBSpark",1);
         mod.config.setValue("followTeammate","0");
         if(host)mod.session.pause.setPolicy(true,true);
         saved=true;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function prepare(n:int):void {
         round=n;spec=CASES[int(n/2)];source=host==(n%2==0);
         fromX=baseX+(spec.kind=="return"?160:0);toX=fromX+Number(spec.distance);
         fired=releaseQ=prepared=peerPrepared=localReported=peerReported=false;
         nativeFrames=maxCharge=firedAt=pauseAt=resumeAt=pauseWrong=pauseSamples=0;
         pausedFrame=pausedLiv=-1;pausedPart=null;pauseRequested=false;
         parts=new Dictionary(true);bursts=new Dictionary(true);initial=new Dictionary(true);arrivals=[];ghostSamples=[];frames={};
         pixels=peakSpark=middle=pictureCount=0;peerSource=null;peerSourceAt=0;postX=NaN;
         firstLandingAt=alignWrong=0;
         rebuilt=false;
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         mod.game.forceCloseOverlays();loc.base=false;loc.portOn=true;loc.black=false;w.black=false;w.alicorn=false;
         for each(var r:Object in tiles) {
            var floor:Boolean=r.y==int(baseY/40)+1;
            var block:Boolean=spec.kind=="blocked" && r.x==int(toX/40) && r.y>=int(baseY/40)-2;
            r.tile.phis=floor||block?1:0;r.tile.opac=floor||block?1:0;r.tile.front="";
            r.tile.water=0;r.tile.visi=1;r.tile.indestruct=true;r.tile.zForm=r.tile.diagon=r.tile.stair=0;r.tile.shelf=false;
            r.tile.phX1=r.x*40;r.tile.phX2=(r.x+1)*40;r.tile.phY1=r.y*40;r.tile.phY2=(r.y+1)*40;
         }
         w.redrawLoc();
         g.pers.portPoss=1;g.pers.spellsPoss=1;g.pers.portTime=25;g.pers.portMana=25;g.pers.portMagic=950;
         g.pers.portDown=300;g.pers.spellDown=1;g.pers.allDManaMult=1;
         g.maxmana=10000;g.mana=spec.kind=="mana"?0:10000;manaBefore=g.mana;manaAfter=g.mana;
         g.t_culd=spec.kind=="cooldown"?10000:0;g.t_port=0;g.ggControl=true;g.isTake=0;
         if(g.teleObj!=null)g.dropTeleObj();
         g.setPos(source?fromX:baseX-80,baseY);g.setVisPos();g.dx=g.dy=0;
         for(var p:Object=loc.firstObj,guard:int=0;p!=null && guard++<16384;p=p.nobj)initial[p]=true;
         change("prepare");
      }
      private function before(e:Event):void {
         if(!saved || phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,ctr:Object=w.ctr;
         g.invulner=true;g.transp=true;g.disabled=!source;g.ggControl=true;g.isTake=0;g.dx=g.dy=0;
         for each(var u:Object in mod.game.loc.units)if(u!==g){
            if(unitState[u]==null)unitState[u]={disabled:u.disabled,invulner:u.invulner,trigDis:u.trigDis};
            u.disabled=true;u.invulner=true;u.trigDis=true;
         }
         ctr.active=true;ctr.keyLeft=ctr.keyRight=ctr.keyBeUp=ctr.keySit=ctr.keyJump=ctr.keyRun=false;
         ctr.keyAction=ctr.keyAttack=ctr.keyPunch=ctr.keyGrenad=ctr.keyMagic=ctr.keyReload=ctr.keyTele=ctr.keySats=false;
         g.celX=w.celX=toX;g.celY=w.celY=baseY-39;
         w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         if(phase=="prepare" || phase=="wait") {g.setPos(source?fromX:baseX-80,baseY);g.setVisPos();}
         if(phase=="run" && source && !fired) {
            if(spec.kind=="relocate") {g.setPos(toX,baseY);g.setVisPos();}
            else ctr.keyTele=!releaseQ;
            if(spec.kind=="mana")g.mana=0;
         }
         if(source && spec.kind=="sats" && fired && phase=="run") {
            if(!pauseRequested){ctr.keySats=true;pauseRequested=true;}
         }
         if(!source && spec.kind=="rebuild" && phase=="run" && !rebuilt &&
            arrivals.length==1 && arrivals[0].frames.length>=3) {
            // Exercise the actual "ghost lost from world" lifecycle. Leave the
            // network id, authentic snapshots and coordinates under production
            // control. A rebuilt body must not replay the buffered cast.
            var ghost:Object=mod.game.getRemoteGhost(host?1:0),units:Array=mod.game.loc.units as Array;
            if(ghost!=null && units!=null) {
               mod.game.loc.remObj(ghost);var index:int=units.indexOf(ghost);if(index>=0)units.splice(index,1);
               rebuilt=true;Log.d("TELEPORT GHOST REBUILD case="+round+" at="+getTimer());
            }
         }
         mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(!saved || phase!="run" || !source || fired)return;
         var g:Object=mod.game.gg;
         nativeFrames++;maxCharge=Math.max(maxCharge,int(g.t_port));
         if(spec.kind=="relocate" || (releaseQ && g.t_port==0)) {
            fired=true;firedAt=getTimer();postX=g.X;manaAfter=g.mana;
            Log.d("TELEPORT NATIVE RELEASE "+JSON.stringify({round:round,role:host?"host":"join",kind:spec.kind,
               nativeFrames:nativeFrames,maxCharge:maxCharge,fromX:fromX,requestedX:toX,postX:postX,
               y:g.Y,manaBefore:manaBefore,manaAfter:manaAfter,culd:g.t_culd}));
         } else if(spec.kind=="short-press"?maxCharge>=2:
            (spec.kind=="cooldown"?nativeFrames>=35:maxCharge>=25))releaseQ=true;
      }
      private function isArrival(p:Object):Boolean {
         return getQualifiedClassName(p)=="fe.graph::Part" && GameBridge.probe(p,"in_chain")===true &&
            getQualifiedClassName(GameBridge.probe(p,"vis"))=="visualTele";
      }
      private function render(e:Event):void {
         if(!saved || phase!="run")return;
         var frameAt:int=getTimer(),loc:Object=mod.game.loc,sparks:int=0;
         for(var p:Object=loc.firstObj,guard:int=0;p!=null && guard++<16384;p=p.nobj) {
            if(initial[p])continue;
            if(isArrival(p)) {
               if(!parts[p]) {
                  var r:Object={x:p.X,y:p.Y,at:frameAt,last:frameAt,frames:[],pixels:0};
                  parts[p]=r;arrivals.push(r);
                  if(!source) {
                     var peer:Object=mod.game.getRemoteGhost(host?1:0);
                     if(peer==null || Math.abs(Number(peer.vis.x)-toX)>1)alignWrong++;
                  }
               }
               r=parts[p];r.last=frameAt;r.frames.push(int(p.vis.currentFrame));frames[String(p.vis.currentFrame)]=true;
               r.pixels=Math.max(r.pixels,visiblePixels(p.vis as DisplayObject));pixels=Math.max(pixels,int(r.pixels));
               if(pictureCount==0 && r.pixels>0){picture("teleport-visual-"+round+"-arrival");pictureCount++;}
               if(!source && mod.session.pause.paused) {
                  if(pausedPart==null){pausedPart=p;pausedFrame=p.vis.currentFrame;pausedLiv=p.liv;}
                  if(p===pausedPart){pauseSamples++;if(p.vis.currentFrame!=pausedFrame || p.liv!=pausedLiv)pauseWrong++;}
               }
            } else if(GameBridge.probe(p,"blitData")===sparkData && GameBridge.probe(p,"in_chain")===true){sparks++;bursts[p]=true;}
         }
         peakSpark=Math.max(peakSpark,sparks);
         if(!source) {
            var ghost:Object=mod.game.getRemoteGhost(host?1:0);
            if(ghost!=null) {
               var point:Object={at:frameAt,x:ghost.vis.x,y:ghost.vis.y,paused:mod.session.pause.paused};
               ghostSamples.push(point);
               if(spec.success && firstLandingAt==0 && Math.abs(Number(point.x)-toX)<=1)firstLandingAt=frameAt;
               if(spec.success && Math.abs(Number(point.x)-fromX)>1 && Math.abs(Number(point.x)-toX)>1)middle++;
            }
         }
      }
      private function visiblePixels(v:DisplayObject):int {
         if(v==null || v.stage==null || !v.visible)return 0;
         var bmp:BitmapData=new BitmapData(160,160,true,0),m:Matrix=new Matrix();m.translate(80,80);bmp.draw(v,m);
         var count:int=0;
         for(var y:int=0;y<160;y++)for(var x:int=0;x<160;x++)if((bmp.getPixel32(x,y)>>>24)>0)count++;
         bmp.dispose();return count;
      }
      private function picture(name:String):void {
         var v:DisplayObject=mod.game.world.grafon.visual;
         var bmp:BitmapData=new BitmapData(1200,720,true,0);bmp.draw(v);
         // Retain the real sampled frame; encode after all timing assertions.
         pictures.push({name:name,bitmap:bmp});
      }
      private function report():void {
         if(localReported)return;
         var frameCount:int=0;for(var k:String in frames)frameCount++;
         var remaining:int=0;for(var p:Object in parts)if(GameBridge.probe(p,"in_chain")===true)remaining++;
         for(p in bursts)if(GameBridge.probe(p,"in_chain")===true)remaining++;
         var summary:Object={source:source,kind:spec.kind,success:spec.success,arrivals:arrivals,pixels:pixels,
            peakSpark:peakSpark,distinctFrames:frameCount,middle:middle,remaining:remaining,pictures:pictureCount,
            fromX:fromX,toX:toX,postX:postX,maxCharge:maxCharge,nativeFrames:nativeFrames,
            manaBefore:manaBefore,manaAfter:manaAfter,pauseSamples:pauseSamples,pauseWrong:pauseWrong,ghost:ghostSamples};
         summary.scY=mod.game.gg.scY;summary.firstLandingAt=firstLandingAt;summary.alignWrong=alignWrong;
         summary.rebuilt=rebuilt;
         if(source) {
            check(fired,"real control completed Q release/relocation");
            if(spec.success) {
               check(maxCharge>=25,"real native Q charging threshold reached frames="+maxCharge);
               check(Math.abs(postX-toX)<=1 && manaAfter<manaBefore,"native teleport reached destination and spent mana x="+postX+" mana="+manaBefore+"→"+manaAfter);
               check(arrivals.length==1 && pixels>0 && peakSpark>=10,"actual native landing clip and departure burst observed count="+arrivals.length+" pixels="+pixels+" sparks="+peakSpark);
            } else {
               check(arrivals.length==0 && peakSpark==0,"native failed cast/plain relocation creates no teleport effects count="+arrivals.length+" sparks="+peakSpark);
               check(Math.abs(postX-(spec.kind=="relocate"?toX:fromX))<=1,"native failure did not move player / plain relocation did x="+postX);
               if(spec.kind=="short-press")check(maxCharge>0 && maxCharge<25,"short Q actually held/released below native threshold "+maxCharge);
               if(spec.kind=="blocked")check(mod.game.loc.collisionUnit(toX,baseY,mod.game.gg.stayX,mod.game.gg.stayY),"requested destination actually blocked");
               if(spec.kind=="mana")check(manaAfter<mod.game.gg.pers.portMana,"insufficient mana actually present at release "+manaAfter);
               if(spec.kind=="cooldown")check(maxCharge==0,"native cooldown prevents charging");
            }
         } else {
            check(peerSource!=null,"source evidence received across TCP");
            if(spec.success) {
               check(peerSource!=null && peerSource.arrivals.length==1,"source was a real successful native teleport");
               check(arrivals.length==1,"exactly one peer landing effect despite repeated snapshots count="+arrivals.length);
               check(pixels>0 && peakSpark>=10 && frameCount>=2,"peer landing visible/animated and departure burst rendered pixels="+pixels+" sparks="+peakSpark+" frames="+frameCount);
               var delta:Number=arrivals.length==1 && peerSource!=null?Math.max(Math.abs(arrivals[0].x-toX),Math.abs(arrivals[0].y-(baseY-Number(peerSource.scY)/2))):NaN;
               check(isFinite(delta) && delta<=.01,"landing effect uses actual destination/height error="+delta);
               check(ghostSamples.length>=12 && middle==0,"peer body never interpolates through teleport gap wrong="+middle+" samples="+ghostSamples.length);
               var landed:Boolean=false;for each(var pos:Object in ghostSamples)if(Math.abs(pos.x-toX)<=1)landed=true;
               check(landed,"peer body really reached destination");
               check(alignWrong==0 && arrivals.length==1 && firstLandingAt>0 && Math.abs(firstLandingAt-int(arrivals[0].at))<=50,
                  "peer teleport body/effect arrive together wrong="+alignWrong+" gap="+(arrivals.length?firstLandingAt-int(arrivals[0].at):NaN));
               if(spec.kind=="sats")check(pauseSamples>=3 && pauseWrong==0,"peer effect freezes during shared SATS and resumes without a duplicate wrong="+pauseWrong+" samples="+pauseSamples);
               if(spec.kind=="rebuild") {
                  var rebuiltGhost:Object=mod.game.getRemoteGhost(host?1:0);
                  check(rebuilt && rebuiltGhost!=null && mod.game.loc.units.indexOf(rebuiltGhost)>=0,
                     "native lost ghost is actually rebuilt while duplicate snapshots continue");
               }
            } else check(arrivals.length==0 && peakSpark==0,"failed cast/plain relocation did not produce remote effects count="+arrivals.length+" sparks="+peakSpark);
         }
         check(remaining==0,"all landing/departure effects expire before next round remaining="+remaining);
         if(spec.success)check(pictureCount==1,"real final display screenshot retained");
         Log.d("TELEPORT METRIC "+JSON.stringify({role:host?"host":"join",round:round,local:summary,peer:peerSource}));
         localReported=true;send("report",{summary:summary});change("reported");advance();
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="teleport-visual-test")return;
         try {
            if(host && p.stage=="ready" && phase=="boot"){setup();send("setup");prepare(0);}
            else if(!host && p.stage=="setup" && phase=="boot"){setup();prepare(0);}
            else if(!host && p.stage=="round")prepare(int(p.round));
            else if(p.stage=="prepared" && int(p.round)==round)peerPrepared=true;
            else if(!host && p.stage=="run" && int(p.round)==round)change("run");
            else if(p.stage=="report" && int(p.round)==round) {
               peerReported=true;
               if(!source && p.summary.source===true){peerSource=p.summary;peerSourceAt=getTimer();}
               advance();
            } else if(p.stage=="done")finish();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function advance():void {
         if(!host || !localReported || !peerReported)return;
         if(round+1<CASES.length*2){var n:int=round+1;prepare(n);send("round",{round:n});}
         else {send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         var w:Object=mod.game.world;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase=="done")return;
         if(getTimer()-at>(phase=="boot"?90000:30000)){check(false,"timeout "+phase);send("done");finish();return;}
         if(!stable())return;
         try {
            if(phase=="boot" && !host && timer.currentCount>130 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="prepare" && getTimer()-at>900) {
               var ghost:Object=mod.game.getRemoteGhost(host?1:0),expected:Number=source?baseX-80:fromX;
               if(ghost==null || Math.abs(ghost.X-expected)>1)return;
               check(true,"remote starting position is settled before Q");prepared=true;send("prepared");change("wait");
            }
            if(host && phase=="wait" && prepared && peerPrepared){send("run");change("run");}
            if(phase=="run" && source && fired) {
               if(spec.kind=="sats" && resumeAt==0) {
                  if(w.sats.active && mod.session.pause.paused) {
                     if(pauseAt==0)pauseAt=getTimer();
                     if(getTimer()-pauseAt>800){check(true,"source entered real shared SATS");w.sats.onoff(-1);resumeAt=getTimer();}
                  }
                  return;
               }
               if(getTimer()-Math.max(firedAt,resumeAt)>3200)report();
            } else if(phase=="run" && !source && peerSource!=null && getTimer()-peerSourceAt>800)report();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null && saved)try {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            mod.game.forceCloseOverlays();
            var g:Object=mod.game.gg;
            if(gun!=null)gun.remVisual();g.currentWeapon=oldGun;g.childObjs=oldChildren;if(oldGun!=null)oldGun.addVisual();
            g.ctr.clearAll();for(var k:String in oldPers)g.pers[k]=oldPers[k];
            for(k in oldState)if(k!="x" && k!="y" && k!="culd")g[k]=oldState[k];
            g.t_culd=oldState.culd;g.setPos(oldState.x,oldState.y);g.setVisPos();
            for(k in oldWorld)mod.game.world[k]=oldWorld[k];for(k in oldRoom)mod.game.loc[k]=oldRoom[k];
            for each(var r:Object in tiles)for(k in r.fields)r.tile[k]=r.fields[k];
            for(var u:Object in unitState)for(k in unitState[u])u[k]=unitState[u][k];
            if(host)mod.session.pause.setPolicy(oldPolicy.menu,oldPolicy.sats);
         }catch(err:*){check(false,"fixture cleanup "+err);}
         for each(var picture:Object in pictures) {
            var bmp:BitmapData=picture.bitmap;
            var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath(picture.name+".png"),FileMode.WRITE);
            file.writeBytes(bmp.encode(bmp.rect,new PNGEncoderOptions()));file.close();bmp.dispose();
         }
         pictures=[];
         Log.d("COOP EFFECTS DONE teleport-visual "+(host?"host":"join"));
      }
   }
}
