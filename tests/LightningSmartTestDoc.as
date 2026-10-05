package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.game.ProjectileVisuals;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Production M45/candidate + installed MSW, real Weapon.attack/step and TCP.
    * No NativeTestGun, direct shoot/run, lock injection or projectile simulation. */
   public class LightningSmartTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var baseX:Number,baseY:Number,ali:Object,blood:Object,gun:Object,msw:Object,step:LightningSmartStep;
      private var oldGun:Object,oldChildren:Object,receiver:MirrorHitUnit,beamClass:String="";
      private var serial:int=0,lastRender:int=-1,lastFrame:int=0,frames:int=0,visibleFrames:int=0,pixelFrames:int=0;
      private var visibleMs:Number=0,maxGap:Number=0,gap:Number=0,nativeResult:Object,peerResult:Object;
      private var shots:Dictionary=new Dictionary(),shotCount:int=0,locks:int=0,hudFrames:int=0,guided:int=0,turned:int=0;
      private var wireShots:int=0,wireSamples:int=0,wireEmpty:int=0,wireEnded:int=0,wireUnique:Object={};
      private var displayRecords:Dictionary=new Dictionary(),displayTrace:Array=[];
      private var longIssued:Boolean=false,longNative:Object,longResult:Object,longPeer:Object;
      private var longSourceSeen:Boolean=false,longJoinSeen:Boolean=false,longSourceClear:int=0,longJoinClear:int=0;
      private var initialHp:Number=0,metricsSent:Boolean=false;
      public function LightningSmartTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"lightning-smart "+s);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="lightning-smart-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function cls(name:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(name) as Class;}
      private function find(type:String):Object {for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&getQualifiedClassName(u)==type && Number(u.maxhp)==(type=="fe.unit::UnitAlicorn"?43210:43211))return u;return null;}
      private function getReceiver():MirrorHitUnit {for each(var u:Object in mod.game.loc.units)if(u is MirrorHitUnit&&MirrorHitUnit(u).body===blood)return u as MirrorHitUnit;return null;}
      private function state(s:String):void {
         phase=s;at=getTimer();frames=visibleFrames=pixelFrames=locks=hudFrames=guided=turned=0;
         visibleMs=maxGap=gap=0;lastFrame=0;metricsSent=false;shots=new Dictionary();shotCount=0;
         displayRecords=new Dictionary();displayTrace=[];
         Log.d("LIGHTNING SMART START "+s+" "+(host?"host":"join"));
      }
      private function setup():void {
         var b:Object=mod.game,g:Object=b.gg;
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.isTake=0;g.ggControl=true;g.anim("stay",true);
         b.loc.base=false;b.loc.black=false;b.world.black=false;
         g.setPos(baseX,baseY);g.setVisPos();
         // The room's incidental enemies are not smart-lock test targets.
         // Preserve genuine eligibility flags on the selected bloodwing only.
         for each(var u:Object in b.loc.units)if(u!==g){u.disabled=true;u.noAgro=true;}
         for(var x:int=Math.max(1,int(baseX/40)-2);x<=Math.min(b.loc.spaceX-2,int(baseX/40)+10);x++)
            for(var y:int=Math.max(1,int(baseY/40)-6);y<int(baseY/40);y++){var tile:Object=b.loc.space[x][y];tile.phis=0;tile.opac=0;tile.front="";}
         b.world.redrawLoc();
         if(host) {
            var c:Class=cls("fe.unit.UnitAlicorn");ali=new c("1",100,<unit tr="1"/>,null);
            ali.putLoc(b.loc,baseX+190,baseY);b.loc.addObj(ali);b.loc.units.push(ali);ali.disabled=true;ali.noAgro=true;ali.invulner=true;ali.xp=0;ali.hp=ali.maxhp=43210;
            gun=ali.currentWeapon;beamClass=""; // Count the actual Bullet.vis only, never the weapon's charge clip.
            c=cls("fe.unit.UnitBat");blood=new c("1",10,<unit/>,null);
            blood.putLoc(b.loc,baseX+360,baseY-80);b.loc.addObj(blood);b.loc.units.push(blood);
            blood.disabled=true;blood.xp=0;blood.invulner=false;blood.hp=blood.maxhp=43211;
            b.readUnitsSnapshot();
         }
         msw=LightningModAccess.instance(mod.main as MainFE);
         check(msw!=null && msw.smart!=null,"installed MSW loads its real smart controller");
         if(msw==null)throw new Error("MSW missing");
         msw.cfg.diagInit();
         msw.cfg.smartEnabled=false;
         step=new LightningSmartStep(nativeInput);Object(step).loc=b.loc;b.loc.addObj(step);
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function before(e:Event):void {
         serial++;if(phase=="done")return;
         var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();
         var smartInput:Boolean=!host && (phase=="smart" || phase=="multi" || phase=="excluded");
         g.disabled=!smartInput;g.invulner=true;g.dx=g.dy=0;g.ggControl=true;g.setPos(baseX,baseY);g.setVisPos();
         b.world.ctr.keyAttack=false;
         if(smartInput && blood!=null){
            b.world.celX=(blood.X1+blood.X2)/2;b.world.celY=(blood.Y1+blood.Y2)/2;
            b.world.cam.celX=b.world.celX*b.world.cam.scaleV+b.world.cam.vx;
            b.world.cam.celY=b.world.celY*b.world.cam.scaleV+b.world.cam.vy;
            g.celX=b.world.celX;g.celY=b.world.celY;g.storona=1;g.setWeaponPos(gun.tip);
            gun.findCel=false;gun.forceRot=Math.atan2(g.celY-g.weaponY,g.celX-g.weaponX)+0.08;
            b.world.ctr.keyAttack=phase=="smart" && msw.smart.lock.target===receiver && getTimer()-at>2200 && getTimer()-at<3900;
         }
         if(ali!=null)ali.disabled=true;if(blood!=null)blood.disabled=true;
         // noAgro prevents lock acquisition, not bullet collision. Both worlds
         // disable incidental colliders locally in this isolated fixture. The
         // selected bloodwing retains its native flags and defenses.
         if(blood!=null)for each(var incidental:Object in b.loc.units)
            if(!(incidental is MirrorHitUnit) && incidental!==g && incidental!==blood && (incidental!==ali || (phase!="lightning" && phase!="long")))incidental.trigDis=true;
         if(ali!=null && (phase=="lightning" || phase=="long"))ali.trigDis=false;
         mod.stage.invalidate();
      }
      private function nativeInput():void {
         var b:Object=mod.game,g:Object=b.gg;
         if(host && phase=="lightning" && getTimer()-at<6000) {
            ali.celX=baseX;ali.celY=baseY-g.scY/2;
            ali.setWeaponPos(gun.tip);gun.attack();gun.step();
            if(gun.b!=null && !shots[gun.b]) {
               shots[gun.b]={dx:gun.b.dx,dy:gun.b.dy,at:getTimer(),end:0};shotCount++;beamClass=getQualifiedClassName(gun.b.vis);
               if(shotCount==1){Log.d("LIGHTNING NATIVE "+JSON.stringify({cls:beamClass,bullet:getQualifiedClassName(gun.b),id:gun.id,spring:gun.b.spring,liv:gun.b.liv,laser:GameBridge.probe(gun.b.vis,"laser")!=null,x:gun.b.begx,y:gun.b.begy,dx:gun.b.dx,dy:gun.b.dy,vel:gun.b.vel}));send("beam-class",{cls:beamClass});}
            }
         }
         if(!host && (phase=="smart" || phase=="multi" || phase=="excluded") && blood!=null) {
            // Location.step executes gg.step BEFORE firstObj (the actual MSW
            // hook). Let native player control/Weapon.step fire via keyAttack;
            // a late test Pt cannot stand in for that ordering.
            if(phase=="smart" && gun.b!=null && !shots[gun.b]){shots[gun.b]={dx:gun.b.dx,dy:gun.b.dy,at:getTimer(),end:0};shotCount++;if(shotCount==1){check(!ProjectileVisuals.usesNativeFrames(gun.b),"ordinary LMG retains endpoint visual path");Log.d("SMART NATIVE SHOT "+JSON.stringify({x:gun.b.begx,y:gun.b.begy,dx:gun.b.dx,dy:gun.b.dy,damage:gun.b.damage,facing:g.storona,tx:g.celX,ty:g.celY}));}}
         }
         if(host && phase=="long") {
            ali.storona=-1;ali.setWeaponPos(gun.tip);ali.celX=40;ali.celY=ali.weaponY;
            gun.findCel=false;gun.forceRot=Math.PI;
            if(!longIssued && getTimer()-at>600)gun.attack();
            gun.step();
            if(!longIssued && gun.b!=null && gun.b.in_chain){longIssued=true;longNative=gun.b;shots[gun.b]={dx:gun.b.dx,dy:gun.b.dy,at:getTimer(),end:0};shotCount++;Log.d("LIGHTNING LONG BORN "+JSON.stringify({at:getTimer(),x:gun.b.X,y:gun.b.Y,dx:gun.b.dx,dy:gun.b.dy,liv:gun.b.liv}));}
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null)return;
         // Joining and random-map loading can take longer than an incidental fight.
         // Protect the isolated test player before the scenario begins, too.
         if(phase=="boot" && mod.game.gg!=null)mod.game.gg.invulner=true;
         if(mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         try {
            if(phase=="boot" && mod.game.readWorldInfo().curLandId!="random_mane")return;
            if(phase=="boot" && !host && getTimer()-readyAt>500 && (!mod.game.world.vblack.visible || mod.game.world.vblack.alpha<=0)){readyAt=getTimer();send("ready");}
            if(phase=="find") {ali=find("fe.unit::UnitAlicorn");blood=find("fe.unit::UnitBat");receiver=getReceiver();if(ali!=null&&blood!=null&&receiver!=null){send("prepared");state("wait");}}
            if(phase=="lightning" && getTimer()-at>7200 && !metricsSent) {
               metricsSent=true;var result:Object={frames:frames,visible:visibleFrames,pixels:pixelFrames,ms:visibleMs,gap:maxGap,shots:shotCount,wireShots:wireShots,wireSamples:wireSamples,wireEmpty:wireEmpty,wireEnded:wireEnded};
               Log.d("LIGHTNING METRIC "+(host?"native ":"join ")+JSON.stringify(result));
               Log.d("LIGHTNING DISPLAY FINAL "+JSON.stringify(displayTrace));
               if(!host)Log.d("LIGHTNING WIRE FINAL "+JSON.stringify(wireUnique));
               if(host){nativeResult=result;finishLightning();}else send("lightning-result",result);
            }
            if(!host && (phase=="smart" || phase=="multi" || phase=="excluded") && getTimer()-at>6500)finishSmart();
            if(phase=="long" && getTimer()-at>6000 && !metricsSent) {
               metricsSent=true;
               var duration:Number=host && longNative!=null?Number(shots[longNative].end)-Number(shots[longNative].at):0;
               var lr:Object={shots:shotCount,life:duration,ended:host && longNative!=null && !longNative.in_chain,pixels:pixelFrames,ms:visibleMs,count:mod.game.projectileVisualCount,wireShots:wireShots,wireEnded:wireEnded,sourceClear:longSourceClear,joinClear:longJoinClear};
               Log.d("LIGHTNING LONG FINAL "+(host?"native ":"join ")+JSON.stringify(lr));Log.d("LIGHTNING LONG DISPLAY "+JSON.stringify(displayTrace));
               if(host){longResult=lr;finishLong();}else{Log.d("LIGHTNING LONG WIRE "+JSON.stringify(wireUnique));send("long-result",lr);}
            }
            // Loading the native game and connecting are outside scenario time.
            if(phase!="done" && phase!="boot" && getTimer()-at>28000){check(false,"timeout "+phase);send("done");finish();}
         } catch(e:Error) {check(false,e.getStackTrace());send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(!host && p.units is Array)for each(var u:Object in p.units)if(u.cls=="fe.unit::UnitAlicorn" && Number(u.defense.maxhp)==43210)
            for each(var w:Object in u.weapons)for each(var event:Object in w.events) {
               var key:String=w.stream+":"+event.seq,record:Object=wireUnique[key],f:Object=event.flight;
               if(record==null){record=wireUnique[key]={updates:0,end:0,frames:0,first:0,last:0};wireShots++;}
               record.updates++;record.received=getTimer();record.sampleTime=w.sampleTime;
               if(f!=null){record.ended=f.ended;record.ex=f.ex;record.ey=f.ey;}
               if(f!=null && f.frames is Array){
                  if(record.updates==1){wireSamples+=f.frames.length;if(f.frames.length==0)wireEmpty++;}
                  if(f.end>0 && record.end==0){wireEnded++;record.end=f.end;record.endReceived=getTimer();Log.d("LIGHTNING WIRE END "+JSON.stringify({key:key,sourceEnd:f.end,received:record.endReceived}));}
                  record.frames=Math.max(record.frames,f.frames.length);
                  if(f.frames.length>0){var first:Object=f.frames[0],last:Object=f.frames[f.frames.length-1];record.first=first.at;record.last=last.at;record.x=last.x;record.y=last.y;record.a=last.a;}
               }
            }
         if(p.type!="lightning-smart-test")return;
         try {
            if(host && phase=="boot" && p.stage=="ready"){baseX=Math.max(160,Math.min(mod.game.gg.X,mod.game.loc.spaceX*40-500));baseY=mod.game.gg.Y;setup();state("wait");send("setup",{x:baseX,y:baseY});}
            else if(!host && phase=="boot" && p.stage=="setup"){baseX=p.x;baseY=p.y;setup();state("find");}
            else if(host && p.stage=="prepared"){state("lightning");send("lightning");}
            else if(!host && p.stage=="lightning")state("lightning");
            else if(!host && p.stage=="beam-class")beamClass=p.cls;
            else if(host && p.stage=="lightning-result"){peerResult=p;finishLightning();}
            else if(!host && p.stage=="smart"){startSmart("smart");}
            else if(host && p.stage=="smart-result"){
               check(Number(p.loss)>0 && Math.abs(initialHp-Number(blood.hp)-Number(p.loss))<0.001,"guided join shots settle exactly once on host localLoss="+p.loss+" hostLoss="+(initialHp-blood.hp));
               send("multi");state("multi");
            }
            else if(!host && p.stage=="multi")startSmart("multi");
            else if(host && p.stage=="multi-result"){send("excluded");state("excluded");}
            else if(!host && p.stage=="excluded")startSmart("excluded");
            else if(host && p.stage=="excluded-result"){startLong();send("long");}
            else if(!host && p.stage=="long")startLong();
            else if(host && p.stage=="long-result"){longPeer=p;finishLong();}
            else if(p.stage=="done")finish();
         } catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function startLong():void {
         state("long");msw.cfg.smartEnabled=false;wireShots=wireSamples=wireEmpty=wireEnded=0;wireUnique={};
         // A real native alilight flies horizontally through an open corridor.
         // Its original liv/velocity/collision remain unchanged. Removal beyond
         // the old 700ms birth window must still reach the receiver.
         var loc:Object=mod.game.loc;
         for(var x:int=1;x<loc.spaceX-1;x++)for(var y:int=Math.max(1,int(baseY/40)-6);y<=Math.min(loc.spaceY-2,int(baseY/40)+1);y++){var tile:Object=loc.space[x][y];tile.phis=0;tile.opac=0;tile.front="";tile.water=0;}
         mod.game.world.redrawLoc();
         if(host){ali.setPos(loc.spaceX*40-160,baseY);ali.setVisPos();}
      }
      private function finishLong():void {
         if(longResult==null || longPeer==null)return;
         check(longResult.shots==1 && longResult.ended && longResult.life>700,"real native long lightning ends beyond birth retention boundary life="+longResult.life);
         check(longResult.pixels>0 && longPeer.pixels>0,"long lightning produces actual native and join pixels");
         check(longPeer.wireShots==1 && longPeer.wireEnded==1,"late native removal is delivered as an end event");
         check(longPeer.count==0,"late native removal clears join visual records count="+longPeer.count);
         send("done");finish();
      }
      private function finishLightning():void {
         if(nativeResult==null || peerResult==null)return;
         check(nativeResult.shots>=3 && nativeResult.pixels>0,"real alicorn Weapon.attack/step emits visible native lightning");
         check(peerResult.pixels>0 && peerResult.visible>0,"native lightning has actual join pixels");
         check(peerResult.ms>=nativeResult.ms*.8 && peerResult.ms<=nativeResult.ms*1.3+100,"join preserves native lightning lifetime host="+nativeResult.ms+" join="+peerResult.ms);
         check(peerResult.gap<=nativeResult.gap+150,"join adds no long blank gap host="+nativeResult.gap+" join="+peerResult.gap);
         initialHp=blood.hp;state("smart");send("smart");
      }
      private function startSmart(mode:String):void {
         blood=find("fe.unit::UnitBat");receiver=getReceiver();if(receiver==null)throw new Error("missing receiver");
         if(oldGun==null) {
            var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs;
            var wc:Class=cls("fe.weapon.Weapon");gun=wc["create"](g,"lmg");gun.setPers(g,g.pers);
            gun.hold=90;gun.lvl=1;gun.perslvl=0;g.currentWeapon=gun;g.childObjs=[gun];
         }
         msw.cfg.smartEnabled=true;msw.cfg.smartMultiLock=mode=="multi";
         msw.cfg.smartExclusions=mode=="excluded"?{bloodwing:true}:{};
         state(mode);
         if(mode=="smart") {
            initialHp=blood.hp;
            check(msw.smart.targetAllowed(receiver,mod.game.world),"MSW accepts mirrored hostile receiver");
            check(msw.smart.visible(receiver,mod.game.world),"MSW sees native enemy visibility on receiver");
            check(blood.disabled && !Object(receiver).disabled,"original AI stays frozen while hit receiver remains active");
            var chained:Boolean=false;for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)if(o===receiver)chained=true;
            check(!chained,"receiver never runs native AI in step chain");
            var count:int=0;for each(var snapshot:Object in mod.game.readUnitsSnapshot())if(snapshot.cls=="fe.unit::UnitBat" && Number(snapshot.defense.maxhp)==43211)count++;
            check(count==1,"receiver does not duplicate the enemy's stable-key snapshot");
            Log.d("MSW TARGET DIAG "+JSON.stringify({id:Object(receiver).id,npc:Object(receiver).npc,noAgro:Object(receiver).noAgro,isVis:Object(receiver).isVis,bodyId:blood.id,bodyVis:blood.isVis,bodyNpc:blood.npc,enabled:msw.cfg.smartEnabled}));
         }
      }
      private function finishSmart():void {
         var hud:DisplayObject=DisplayObjectContainer(mod.main).getChildByName("MSWSmartHUD");
         if(phase=="smart") {
            var bullets:Array=[];
            for(var nativeBullet:Object in shots){var hits:Array=[];if(nativeBullet.parr is Array)for each(var collider:Object in nativeBullet.parr)hits.push({id:collider.id,cls:getQualifiedClassName(collider)});bullets.push({x:nativeBullet.X,y:nativeBullet.Y,babah:nativeBullet.babah,liv:nativeBullet.liv,off:nativeBullet.off,tip:nativeBullet.tipBullet,flame:nativeBullet.flame,brake:nativeBullet.brakeR,hits:hits});}
            Log.d("MSW SMART FINAL "+JSON.stringify({shots:shotCount,diag:msw.cfg.diag,bullets:bullets}));
            check(locks>10 && msw.smart.lock.target===receiver,"real MSW frame clock acquires and retains single lock frames="+locks);
            check(hudFrames>10,"real lock marker renders join pixels frames="+hudFrames);
            check(guided>0 && turned>0,"real MSW hooks guide native join bullets states="+guided+" turns="+turned);
         } else if(phase=="multi") {
            check(locks>10 && hudFrames>10,"real multi-lock acquires mirrored enemy and draws marker frames="+locks);
         } else {
            check(!msw.smart.targetAllowed(receiver,mod.game.world),"user bloodwing exclusion applies to mirrored target ID");
            check(locks==0 && (hud==null || !hud.visible),"excluded target loses lock and marker");
            eligibility();
         }
         var result:String=phase+"-result",loss:Number=initialHp-Number(blood.hp);state("wait");send(result,{loss:loss});
      }
      private function eligibility():void {
         msw.cfg.smartExclusions={};
         var fields:Array=["npc","noAgro","trigDis"];
         for each(var name:String in fields){var old:*=blood[name];blood[name]=true;receiver.syncMotion();check(!msw.smart.targetAllowed(receiver,mod.game.world),"native "+name+" remains un-lockable");blood[name]=old;}
         msw.cfg.smartExclusions={};
         var seen:*=blood.isVis,stealth:*=blood.invis;blood.isVis=false;blood.invis=true;receiver.syncMotion();
         check(!msw.smart.visible(receiver,mod.game.world),"concealed native target remains hidden from smart lock");blood.isVis=seen;blood.invis=stealth;receiver.syncMotion();
      }
      private function onScreen(v:DisplayObject):Boolean {
         if(v==null || v.stage==null)return false;
         for(var p:DisplayObject=v;p!=null;p=p.parent)if(!p.visible || p.alpha<=0)return false;
         var r:Rectangle=v.getBounds(mod.main as DisplayObject);return r.width>1 && r.height>1 && r.intersects(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
      }
      private function pixels(v:DisplayObject):int {
         if(!onScreen(v))return 0;
         var r:Rectangle=v.getBounds(mod.main as DisplayObject).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width*r.height>500000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone(),m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);
         a.draw(mod.main as DisplayObject,m);v.visible=false;b.draw(mod.main as DisplayObject,m);v.visible=true;
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),n:int=0;for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;a.dispose();b.dispose();return n;
      }
      private function displayDetails(v:DisplayObject,depth:int=2):Object {
         var r:Rectangle=v.getBounds(v),d:Object={cls:getQualifiedClassName(v),name:v.name,frame:v is MovieClip?MovieClip(v).currentFrame:0,total:v is MovieClip?MovieClip(v).totalFrames:0,visible:v.visible,a:v.alpha,w:r.width,h:r.height};
         if(depth>0 && v is DisplayObjectContainer){d.children=[];var c:DisplayObjectContainer=v as DisplayObjectContainer;for(var i:int=0;i<Math.min(8,c.numChildren);i++)d.children.push(displayDetails(c.getChildAt(i),depth-1));}
         return d;
      }
      private function render(e:Event):void {
         if(serial==lastRender || phase=="done")return;lastRender=serial;frames++;
         var now:int=getTimer(),dt:int=lastFrame>0?now-lastFrame:0;lastFrame=now;
         if(phase=="lightning" || phase=="long") {
            if(host)for(var bullet:Object in shots){var nativeShot:Object=shots[bullet];if(!bullet.in_chain && nativeShot.end==0){nativeShot.end=now;Log.d("LIGHTNING NATIVE END "+JSON.stringify({at:nativeShot.at,end:now,ms:now-nativeShot.at,x:bullet.X,y:bullet.Y,babah:bullet.babah}));}}
            if(phase=="long") {
               if(host){
                  var sourceHasEvent:Boolean=false;
                  for each(var unitState:Object in mod.game.readUnitsSnapshot())if(unitState.cls=="fe.unit::UnitAlicorn" && Number(unitState.defense.maxhp)==43210)
                     for each(var weaponState:Object in unitState.weapons)for each(var shot:Object in weaponState.events)if(shot.flight!=null && shot.flight.cls==beamClass)sourceHasEvent=true;
                  if(sourceHasEvent)longSourceSeen=true;
                  else if(longSourceSeen && longSourceClear==0){longSourceClear=now;Log.d("LIGHTNING SOURCE CLEAR "+JSON.stringify({at:now,nativeEnd:longNative==null?0:shots[longNative].end}));}
               } else {
                  if(mod.game.projectileVisualCount>0)longJoinSeen=true;
                  else if(longJoinSeen && longJoinClear==0){longJoinClear=now;Log.d("LIGHTNING JOIN CLEAR "+JSON.stringify({at:now,count:mod.game.projectileVisualCount}));}
               }
            }
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],visible:Boolean=false,pixel:Boolean=false;
            for(var i:int=0;i<layer.numChildren;i++){var v:DisplayObject=layer.getChildAt(i);if(getQualifiedClassName(v)==beamClass && onScreen(v)){
               visible=true;if(serial%7==0 && pixels(v)>0)pixel=true;
               var trace:Object=displayRecords[v];
               if(trace==null){trace=displayRecords[v]={first:now,last:now,ms:0,frames:0,x:v.x,y:v.y,source:"copy"};displayTrace.push(trace);if(displayTrace.length==1)Log.d("LIGHTNING DISPLAY TREE "+JSON.stringify(displayDetails(v)));if(host){trace.source="other";for(var original:Object in shots)if(original.vis===v){trace.source="bullet";trace.born=shots[original].at;break;}}}
               trace.last=now;trace.ms+=dt;trace.frames++;trace.ex=v.x;trace.ey=v.y;
            }}
            if(visible){visibleFrames++;visibleMs+=dt;gap=0;}else{gap+=dt;maxGap=Math.max(maxGap,gap);}
            if(pixel)pixelFrames++;
         } else if(!host && (phase=="smart" || phase=="multi" || phase=="excluded")) {
            if(phase=="multi"){for each(var lock:Object in msw.smart.multiLock.locks)if(lock.target===receiver)locks++;}
            else if(msw.smart.lock.target===receiver)locks++;
            var hud:DisplayObject=DisplayObjectContainer(mod.main).getChildByName("MSWSmartHUD");if(onScreen(hud) && pixels(hud)>0)hudFrames++;
            for(var b:Object in shots){var s:Object=msw.smart.snapshot(b);if(s!=null && s.target===receiver){guided++;var old:Object=shots[b];if(Math.abs(b.dx*old.dy-b.dy*old.dx)>0.01)turned++;}}
         }
      }
      private function finish():void {
         if(phase=="done")return;
         if(mod!=null && mod.game.gg!=null) {
            if(oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}
            if(step!=null && Object(step).in_chain)mod.game.loc.remObj(step);
            if(msw!=null)msw.cfg.smartEnabled=false;
         }
         state("done");timer.stop();Log.d("COOP EFFECTS DONE lightning-smart "+(host?"host":"join"));
      }
   }
}
