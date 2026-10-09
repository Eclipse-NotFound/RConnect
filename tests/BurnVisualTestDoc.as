package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.BurnVisuals;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real native Effect/Bullet -> production snapshots -> visible native Part.
    * The source never calls the receiving visual helper or fabricates packets. */
   public class BurnVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100);
      private var links:Dictionary=new Dictionary(),seen:Dictionary=new Dictionary(true);
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1;
      private var baseX:Number=0,baseY:Number=0,floorY:int=0;
      private var enemy:Object,gun:Object,bullet:Object,oldGun:Object,oldChildren:Object;
      private var oldX:Number=0,oldY:Number=0,oldDisabled:Boolean=false,oldInvulner:Boolean=false;
      private var oldMolotovAmmo:Number=0,ammoPrepared:Boolean=false,oldLevels:Boolean=false;
      private var setupStarted:Boolean=false;
      private var changed:Array=[],flameClass:Class,fireBitmap:Object;
      private var sourceCount:int=0,mirrorCount:int=0,sourceStatus:Boolean=false;
      private var blast:Object=null,armed:Boolean=false,shot:Boolean=false,peerDone:Boolean=false,localDone:Boolean=false;
      private var firePoints:Array=[],fireParts:Array=[],damageProbe:Object,probeHP:Number=NaN;
      private var fireReady:Boolean=false,peerFireReady:Boolean=false,pauseSeen:Boolean=false,peerPauseSeen:Boolean=false;
      private var resumed:Boolean=false,peerResumed:Boolean=false,pauseOpened:Boolean=false,pauseClosed:Boolean=false;
      private var pauseAt:int=0,resumeAt:int=0,pauseFrames:int=0,pauseDrift:int=0,lifeRise:int=0;
      private var oldPauseMenus:Boolean=false,oldPauseSats:Boolean=false,pausePolicyChanged:Boolean=false;
      private var peerGroundResult:Object;
      private var clockPart:Object,resumeClock:int=0,pauseClock:int=0,probeFrames:int=0,probeReattached:int=0;
      private var legacyDeadlineRecorded:Boolean=false;

      private function nativeSteps():int {return resumed && clockPart!=null?resumeClock-int(clockPart.liv):0;}
      private function removeClock():void {
         if(clockPart!=null && clockPart.in_chain)clockPart.loc.remObj(clockPart);
         clockPart=null;
      }

      public function BurnVisualTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"burn-visual "+label+" round="+round+" role="+(host?"host":"join"));
      }
      private function send(stage:String,p:Object=null):void {
         p=p||{};p.type="burn-visual-test";p.stage=stage;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function onError(e:UncaughtErrorEvent):void {
         e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
      }
      private function fail(reason:String):void {check(false,reason);if(mod!=null)send("done");finish();}
      private function source():Boolean {return round==0 || round==1 || round==3 ? host : !host;}
      private function ground():Boolean {return round>=3;}
      private function playerX():Number {return baseX+(host?0:220);}
      private function groundX():Number {return baseX+(round==3?510:660);}
      private function removeDamageProbe():void {
         if(damageProbe==null||mod==null||mod.game==null)return;
         var room:Object=mod.game.loc;
         if(damageProbe.in_chain&&damageProbe.loc!=null)damageProbe.loc.remObj(damageProbe);
         var index:int=room.units.indexOf(damageProbe);if(index>=0)room.units.splice(index,1);
         damageProbe=null;probeHP=NaN;
      }
      /** A vulnerable receiver-only unit makes a cosmetic damage path observable.
       * The native test bullet has zero damage, so its source explosion cannot
       * legitimately reduce this unit's HP. */
      private function addDamageProbe():void {
         var room:Object=mod.game.loc,cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitBloat") as Class;
         damageProbe=new cls("1",100,<unit tr="1"/>,null);
         damageProbe.id="rconnect_burn_damage_probe_"+round+"_"+(host?"host":"join");
         damageProbe.putLoc(room,groundX(),floorY*40-70+Number(damageProbe.scY)/2);
         room.addObj(damageProbe);room.units.push(damageProbe);
         damageProbe.maxhp=damageProbe.hp=100000;
         damageProbe.xp=0;damageProbe.noAgro=true;damageProbe.doop=true;damageProbe.walk=0;
         damageProbe.invulner=false;damageProbe.disabled=false;damageProbe.trigDis=false;
         probeHP=Number(damageProbe.hp);
      }

      private function setup():void {
         var g:Object=mod.game.gg,room:Object=mod.game.loc,emit:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         oldX=g.X;oldY=g.Y;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         oldDisabled=g.disabled;oldInvulner=g.invulner;
         oldLevels=mod.game.world.weaponsLevelsOff;
         setupStarted=true;
         floorY=int(baseY/40);
         flameClass=emit.arr["flame"].visClass as Class;
         fireBitmap=mod.game.world.grafon.getSpriteList(emit.arr["fire"].blit,1);
         if(flameClass==null||fireBitmap==null)throw new Error("native fire/flame emitter unavailable");
         if(baseX+780>=Number(room.limX) || floorY<4 || floorY>=int(room.spaceY)-1)
            throw new Error("burn fixture needs 780px of floor and room margin");
         for(var tx:int=int((baseX+370)/40);tx<=int((baseX+770)/40);tx++) {
            for each(var ty:int in [floorY-1,floorY]) {
               var tile:Object=room.getTile(tx,ty),fields:Object={};
               for each(var k:String in ["phis","shelf","zForm","phY1","phY2","opac","water"])
                  fields[k]=tile[k];
               changed.push({tile:tile,fields:fields});
               tile.phis=ty==floorY?1:0;tile.shelf=false;tile.zForm=0;
               tile.phY1=ty*40;tile.phY2=(ty+1)*40;tile.water=0;
            }
         }
         if(host) {
            var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitBloat") as Class;
            enemy=new cls("1",100,<unit tr="1"/>,null);enemy.id="rconnect_burn_visual_enemy";
            enemy.putLoc(room,baseX+430,baseY-70);room.addObj(enemy);room.units.push(enemy);
            enemy.xp=0;enemy.noAgro=true;enemy.doop=true;enemy.invulner=true;
            enemy.walk=0;enemy.stay=true;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function findEnemy():Object {
         if(enemy!=null)return enemy;
         for each(var u:Object in mod.game.loc.units)
            if(GameBridge.probe(u,"id")=="rconnect_burn_visual_enemy")return enemy=u;
         return null;
      }
      private function clearStatus():void {
         if(mod!=null&&mod.game.gg!=null)mod.game.gg.remEffect("burning");
         if(host&&enemy!=null)enemy.remEffect("burning");
      }
      private function restoreGun():void {
         if(gun!=null){gun.remVisual();gun=null;}
         if(mod!=null&&mod.game.gg!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;
            if(oldGun!=null)oldGun.addVisual();}
      }
      private function start(n:int):void {
         clearStatus();restoreGun();removeClock();
         removeDamageProbe();
         round=n;phase="show";at=getTimer();seen=new Dictionary(true);
         sourceCount=mirrorCount=0;sourceStatus=false;blast=null;armed=shot=peerDone=localDone=false;bullet=null;
         firePoints=[];fireParts=[];fireReady=peerFireReady=pauseSeen=peerPauseSeen=false;
         resumeClock=pauseClock=probeFrames=probeReattached=0;legacyDeadlineRecorded=false;
         resumed=peerResumed=pauseOpened=pauseClosed=false;pauseAt=resumeAt=pauseFrames=pauseDrift=lifeRise=0;
         peerGroundResult=null;
         if(round==3&&host) {
            oldPauseMenus=mod.session.pause.policyMenus;oldPauseSats=mod.session.pause.policySats;
            pausePolicyChanged=mod.session.pause.setPolicy(true,false);
            check(pausePolicyChanged,"host enables native shared menu pause for fire lifetime test");
         }
         if(ground()) {
            // Empty native Part used only as an independent simulation clock.
            // It cannot damage, emit fire, or drive the tested Parts itself.
            var clockClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Part") as Class;
            clockPart=new clockClass();clockPart.vis=new MovieClip();clockPart.liv=clockPart.mliv=10000;
            clockPart.loc=mod.game.loc;mod.game.loc.addObj(clockPart);
            if(host)mod.game.world.pip.onoff(-1);
            // Old native fire from another effect must not count as this shot.
            var existing:Object=mod.game.loc.firstObj,guard:int=0;
            for(;existing!=null&&guard++<10000;existing=existing.nobj)
               if(getQualifiedClassName(existing)=="fe.graph::Part"
                  && GameBridge.probe(existing,"blitData")===fireBitmap)seen[existing]=true;
            if(!source())addDamageProbe();
         }
         if(round==0&&host)findEnemy().addEffect("burning",40);
         else if((round==1&&host)||(round==2&&!host))mod.game.gg.addEffect("burning",40);
         if(ground()&&source()) {
            var g:Object=mod.game.gg,factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            var ammo:Object=g.invent.items["molotov"];
            if(ammo==null)throw new Error("native molotov ammo slot unavailable");
            if(!ammoPrepared){oldMolotovAmmo=Number(ammo.kol);ammoPrepared=true;}
            ammo.kol=Math.max(Number(ammo.kol),10);
            mod.game.world.weaponsLevelsOff=false;
            gun=factory.create(g,"molotov",0);gun.setPers(g,g.pers);
            gun.lvl=gun.perslvl=0;gun.hold=999;gun.t_reload=gun.t_attack=0;
            if(oldGun!=null)oldGun.remVisual();g.currentWeapon=gun;g.childObjs=[gun];gun.addVisual();
         }
         Log.d("BURN VISUAL START "+JSON.stringify({round:round,source:source(),role:host?"host":"join"}));
      }
      private function before(e:Event):void {
         if(phase!="show")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.disabled=ground();g.invulner=true;g.dx=g.dy=0;g.isTake=0;g.ggControl=true;
         g.setPos(playerX(),baseY);g.setVisPos();
         w.ctr.keyAttack=w.ctr.keyGrenad=w.ctr.keyMagic=false;
         if(host&&enemy!=null&&round==0) {
            enemy.disabled=false;enemy.dx=enemy.dy=0;enemy.setPos(baseX+430,baseY-70);
            enemy.setVisPos();
         }
         if(ground()&&damageProbe!=null) {
            // Authoritative room checkpoints remove receiver-only fixture
            // units. Reinsert the same vulnerable probe without healing it.
            if(!damageProbe.in_chain){mod.game.loc.addObj(damageProbe);probeReattached++;}
            if(mod.game.loc.units.indexOf(damageProbe)<0)mod.game.loc.units.push(damageProbe);
            damageProbe.disabled=false;damageProbe.invulner=false;damageProbe.trigDis=false;
            damageProbe.dx=damageProbe.dy=0;
            damageProbe.setPos(groundX(),floorY*40-70+Number(damageProbe.scY)/2);
            damageProbe.setVisPos();
         }
         if(!ground()||!source()||gun==null)return;
         g.celX=w.celX=playerX()+350;g.celY=w.celY=baseY-60;
         gun.loc=mod.game.loc;gun.X=g.X;gun.Y=g.Y-50;gun.rot=0;
         if(!shot&&getTimer()-at>350){gun.attack();shot=true;}
         if(gun.b!=null&&bullet==null)bullet=gun.b;
         if(bullet!=null&&!armed) {
            armed=true;
            bullet.X=groundX();
            bullet.Y=floorY*40-70;bullet.dx=bullet.dy=0;
            // PhisBullet detonates as its native countdown reaches 3.
            bullet.liv=4;bullet.destroy=0;bullet.damage=bullet.damageExpl=0;bullet.otbros=0;
            check(int(bullet.tipDamage)==3&&Number(bullet.explRadius)>0
               && Number(bullet.damage)==0&&Number(bullet.damageExpl)==0,
               "real molotov Bullet armed with zero damage for native fire explosion");
         }
      }
      private function render(e:Event):void {
         if(phase!="show")return;
         var target:Object=null;
         if(round==0)target=findEnemy();
         else if(round<3)target=source()?mod.game.gg:mod.game.getRemoteGhost(host?1:0);
         if(!ground()&&source()&&target!=null&&BurnVisuals.capture(target))sourceStatus=true;
         if(ground()&&source()&&bullet!=null&&bullet.isExpl&&blast==null) {
            blast={x:bullet.X,y:bullet.Y};firePoints=BurnVisuals.captureGround(bullet);
            send("blast",{x:blast.x,y:blast.y,points:firePoints});
         }
         var o:Object=mod.game.loc.firstObj,guard:int=0;
         for(;o!=null&&guard++<10000;o=o.nobj) {
            if(getQualifiedClassName(o)!="fe.graph::Part"||seen[o])continue;
            var visual:DisplayObject=GameBridge.probe(o,"vis") as DisplayObject;
            if(visual==null||!visual.visible||visual.stage==null)continue;
            var match:Boolean=false;
            if(ground())match=GameBridge.probe(o,"blitData")===fireBitmap
               && Math.abs(Number(o.X)-groundX())<220
               && Math.abs(Number(o.Y)-(floorY*40-33))<1;
            else match=target!=null&&GameBridge.probe(o,"vClass")===flameClass
               && Math.abs(Number(o.X)-Number(target.X))<60
               && Math.abs(Number(o.Y)-(Number(target.Y)-Number(target.scY)/2))<65;
            if(match){
               seen[o]=true;if(source())sourceCount++;else mirrorCount++;
               if(ground())fireParts.push({part:o,vis:visual,x:Number(o.X),y:Number(o.Y),
                  born:getTimer(),initial:int(o.liv),maximum:int(o.mliv),last:int(o.liv),gone:0,orphan:false,
                  paused:-1,resume:-1,goneSteps:0});
            }
         }
         if(!ground())return;
         var now:int=getTimer(),paused:Boolean=mod.session.pause.paused;
         if(damageProbe!=null && damageProbe.in_chain && !damageProbe.invulner)probeFrames++;
         for each(var part:Object in fireParts) {
            var life:int=int(part.part.liv);
            if(life>int(part.last))lifeRise++;
            part.last=life;
            if(!part.part.in_chain&&int(part.gone)==0) {
               part.gone=now;
               part.goneSteps=nativeSteps();
               part.orphan=part.vis.stage!=null;
            }
         }
         if(firePoints.length>0&&fireParts.length>=firePoints.length&&!fireReady) {
            fireReady=true;if(!host)send("fire-ready",{count:fireParts.length});
         }
         if(paused&&fireReady) {
            if(!pauseSeen) {
               pauseSeen=true;
               pauseClock=int(clockPart.liv);
               for each(part in fireParts)part.paused=int(part.part.liv);
               if(!host)send("pause-seen");
            } else {
               pauseFrames++;
               if(int(clockPart.liv)!=pauseClock)pauseDrift++;
               for each(part in fireParts)
                  if(int(part.part.liv)!=int(part.paused)||!part.part.in_chain)pauseDrift++;
            }
         } else if(!paused&&pauseSeen&&!resumed) {
            resumed=true;resumeAt=now;resumeClock=int(clockPart.liv);
            for each(part in fireParts)part.resume=int(part.part.liv);
            if(!host)send("resumed");
         }
         if(resumed && !legacyDeadlineRecorded && now-resumeAt>=5700) {
            legacyDeadlineRecorded=true;var remaining:Array=[];
            for each(part in fireParts)remaining.push({liv:part.part.liv,inChain:part.part.in_chain});
            Log.d("BURN LEGACY DEADLINE "+JSON.stringify({round:round,steps:nativeSteps(),remaining:remaining}));
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type!="burn-visual-test"||phase=="done")return;
         try {
            if(host&&p.stage=="ready"&&phase=="boot") {
               var room:Object=mod.game.loc;
               baseX=Math.max(120,Math.min(Math.floor(mod.game.gg.X/40)*40,Number(room.limX)-900));
               baseY=mod.game.gg.Y;setup();phase="setup";at=getTimer();send("setup",{x:baseX,y:baseY});
            } else if(!host&&p.stage=="setup"&&phase=="boot") {
               baseX=Number(p.x);baseY=Number(p.y);setup();phase="setup";at=getTimer();send("setup-ready");
            } else if(host&&p.stage=="setup-ready"&&phase=="setup")nextRound();
            else if(!host&&p.stage=="begin")start(int(p.round));
            else if(p.stage=="blast"&&int(p.round)==round&&!source()) {
               blast={x:Number(p.x),y:Number(p.y)};firePoints=p.points is Array?(p.points as Array):[];
            }
            else if(host&&p.stage=="fire-ready"&&int(p.round)==round)peerFireReady=true;
            else if(host&&p.stage=="pause-seen"&&int(p.round)==round)peerPauseSeen=true;
            else if(host&&p.stage=="resumed"&&int(p.round)==round)peerResumed=true;
            else if(host&&p.stage=="result"&&int(p.round)==round){peerDone=true;peerGroundResult=p;advance();}
            else if(p.stage=="done")finish();
         } catch(error:*) {fail("message: "+error);}
      }
      private function nextRound():void {
         if(round>=4){send("done");finish();return;}
         start(round+1);send("begin");
      }
      private function complete():void {
         if(localDone)return;localDone=true;
         if(source()) {
            if(!ground())check(sourceStatus&&sourceCount>=3,"native burning status emits flame Parts count="+sourceCount);
            else check(blast!=null&&firePoints.length>=2,
               "real molotov produces expected floor points="+firePoints.length);
         } else if(!ground())check(mirrorCount>=2,"remote burning is visibly rendered count="+mirrorCount);
         var delay:int=0;
         if(ground())delay=checkGround();
         var audit:Array=[];
         for each(var record:Object in fireParts)if(audit.length<24)
            audit.push({x:record.x,y:record.y,initial:record.initial,max:record.maximum,
               pause:record.paused,resume:record.resume,gone:record.gone,goneSteps:record.goneSteps,last:record.last,orphan:record.orphan});
         Log.d("BURN VISUAL METRIC "+JSON.stringify({round:round,source:source(),role:host?"host":"join",
            native:sourceCount,remote:mirrorCount,blast:blast,status:sourceStatus,
            expected:firePoints.length,pauseFrames:pauseFrames,pauseDrift:pauseDrift,lifeRise:lifeRise,
            resumeAt:resumeAt,clearDelay:delay,probeHP:probeHP,probeAfter:damageProbe==null?null:damageProbe.hp,
            nativeSteps:nativeSteps(),probeFrames:probeFrames,probeReattached:probeReattached,
            points:firePoints.slice(0,24),parts:audit}));
         if(host)advance();else send("result",{native:sourceCount,remote:mirrorCount,delay:delay,steps:firePartsMaxSteps()});
      }
      private function checkGround():int {
         var matched:Array=[],good:Boolean=firePoints.length>0&&fireParts.length==firePoints.length;
         var maxDelay:int=0,allGone:Boolean=true,initialGood:Boolean=true,clean:Boolean=true,stepLifetime:Boolean=true;
         for each(var point:Object in firePoints) {
            var found:int=-1;
            for(var i:int=0;i<fireParts.length;i++)if(matched.indexOf(i)<0
               &&Math.abs(Number(fireParts[i].x)-Number(point.x))<=(source()?2.1:0.1)
               &&Math.abs(Number(fireParts[i].y)-Number(point.y))<=0.1) {found=i;break;}
            if(found<0)good=false;else matched.push(found);
         }
         for each(var rec:Object in fireParts) {
            if(int(rec.maximum)<100||int(rec.maximum)>129
               ||int(rec.initial)>int(rec.maximum)||int(rec.maximum)-int(rec.initial)>5)initialGood=false;
            if(rec.part.in_chain||int(rec.gone)==0)allGone=false;
            if(rec.orphan||rec.vis.stage!=null)clean=false;
            if(int(rec.goneSteps)<int(rec.resume)-1 || int(rec.goneSteps)>int(rec.resume)+1)stepLifetime=false;
            if(resumeAt>0&&int(rec.gone)>0)maxDelay=Math.max(maxDelay,int(rec.gone)-resumeAt);
         }
         check(good,"native fire count and per-tile coordinates expected="+firePoints.length+" actual="+fireParts.length);
         check(initialGood&&lifeRise==0,"native fire starts at 100..129 steps and lifetime never rises");
         check(fireReady&&pauseSeen&&resumed&&pauseFrames>=5&&pauseDrift==0,
            "shared pause freezes every fire Part on this side frames="+pauseFrames+" drift="+pauseDrift);
         check(allGone&&clean&&maxDelay>0&&stepLifetime,
            "all fire Parts expire at their native remaining step count and leave the display tree delay="+maxDelay+" steps="+firePartsMaxSteps());
         if(!source())check(damageProbe!=null&&probeFrames>=20&&Number(damageProbe.hp)==probeHP,
            "vulnerable receiver-only unit takes no damage from cosmetic fire hp="+(damageProbe==null?"missing":damageProbe.hp));
         return maxDelay;
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(ground())check(peerGroundResult!=null&&Math.abs(int(peerGroundResult.steps)-firePartsMaxSteps())<=35,
            "source and receiver fire clear within native 30-step random-life/display allowance");
         nextRound();
      }
      private function firePartsMaxDelay():int {
         var result:int=0;for each(var rec:Object in fireParts)
            if(int(rec.gone)>0&&resumeAt>0)result=Math.max(result,int(rec.gone)-resumeAt);
         return result;
      }
      private function firePartsMaxSteps():int {
         var result:int=0;for each(var rec:Object in fireParts)result=Math.max(result,int(rec.goneSteps));return result;
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null||mod.game==null||mod.game.gg==null||mod.session==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);
         else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done"&&getTimer()-at>60000){fail("timeout "+phase);return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&timer.currentCount>150&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="show") {
            if(ground()&&source()&&gun!=null&&!mod.session.pause.paused)gun.step();
            if(ground()) {
               if(getTimer()-at>18000){fail("ground phase timeout ready="+fireReady+" peer="+peerFireReady+" pause="+pauseSeen+" resume="+resumed);return;}
               if(host&&fireReady&&peerFireReady&&!pauseOpened) {
                  pauseOpened=true;pauseAt=getTimer();mod.game.world.pip.onoff(5);
               }
               if(host&&pauseOpened&&!pauseClosed&&pauseSeen&&peerPauseSeen&&getTimer()-pauseAt>=1200) {
                  pauseClosed=true;mod.game.world.pip.onoff(-1);
               }
               if(resumed&&nativeSteps()>=160&&(!host||peerResumed))complete();
            } else if(getTimer()-at>3400)complete();
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(setupStarted&&mod!=null&&mod.game!=null&&mod.game.gg!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);
            mod.stage.removeEventListener(Event.RENDER,render);
            if(host&&pauseOpened&&!pauseClosed)mod.game.world.pip.onoff(-1);
            if(host&&pausePolicyChanged)mod.session.pause.setPolicy(oldPauseMenus,oldPauseSats);
            clearStatus();restoreGun();removeClock();
            removeDamageProbe();
            var g:Object=mod.game.gg;g.disabled=oldDisabled;g.invulner=oldInvulner;
            g.setPos(oldX,oldY);g.setVisPos();
            if(ammoPrepared)g.invent.items["molotov"].kol=oldMolotovAmmo;
            mod.game.world.weaponsLevelsOff=oldLevels;
            if(host&&enemy!=null){var room:Object=mod.game.loc;room.remObj(enemy);
               var index:int=room.units.indexOf(enemy);if(index>=0)room.units.splice(index,1);}
            for each(var record:Object in changed)
               for(var key:String in record.fields)record.tile[key]=record.fields[key];
            mod.game.world.ctr.keyAttack=mod.game.world.ctr.keyGrenad=false;
            mod.game.world.redrawLoc();
         }
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         Log.d("COOP EFFECTS DONE burn-visual "+(host?"host":"join"));
      }
   }
}
