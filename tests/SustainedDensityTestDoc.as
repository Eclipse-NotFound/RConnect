package {
   import flash.desktop.NativeApplication;

   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import flash.sampler.*;
   import fe.unit.Unit;
   import fe.unit.CombatStateProbe;
   import flash.system.System;
   import flash.system.ApplicationDomain;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.Protocol;
   import rconnect.net.NetMessageEvent;
   public class SustainedDensityTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,enemy:Object,bat:Object,turret:Object,shot:Object;
      private var expected:Number=0,startHp:Number=0,index:int=0,frames:int=0,prevFrame:int=0,maxFrame:int=0,ghoulLoss:Number=0;
      private var intervals:Array=[],poses:Object={},samples:Object={},lastPacket:int=0,maxPacket:int=0,packets:int=0;
      private var turretKinds:Array=[1,2,3,4,5],fireStart:int=0;
      private var baselineActive:Boolean=false,baselineAt:int=0,baselinePrev:int=0,baselineFrames:int=0;
      private var baselineIntervals:Array=[];
      private var densityProbe:int=0;
      private var frameAt:int=0,cpuMs:int=0,cpuMax:int=0,netAt:int=0,netMs:int=0,netMax:int=0;
      private var projectileLoad:Boolean=false,loadGuns:Array=[],projectileEvents:int=0,projectileSamples:int=0;
      private var loadActors:Array=[];
      private var enemyKey:String="",batKey:String="",aimKey:String="";
      private var endedSamples:int=0;
      private var trajectoryEvents:int=0,renderedProjectiles:int=0,movingProjectiles:int=0;
      private var projectileClasses:Object={},projectilePositions:Dictionary=new Dictionary(true);
      private var setupStage:Boolean=false;
      private var seedClass:Object,originalSeed:Function;
      private var diagEnabled:Boolean=false,diagSampling:Boolean=false,diagNumber:int=0,diagAt:int=0,diagAfter:int=0;
      private var diagRows:Array=[];
      private var diagPacket:Object;
      private function encodingProbe():void {
         var packet:Object=host?{type:"unitsync",units:mod.game.readUnitsSnapshot(),snap:mod.game.readSnapshot()}:diagPacket;
         if(packet==null)return;
         var encoded:String=JSON.stringify(packet),plain:Object=JSON.parse(encoded);
         var rows:Array=[];
         // The exact installed-version control predates this optional codec.
         // Resolve it only for this post-scenario diagnostic, never require it
         // merely to compile or run the shared native projectile scenario.
         var checkedCodec:Object=null;
         if(ApplicationDomain.currentDomain.hasDefinition("rconnect.net.BinaryMessageCodec"))
            checkedCodec=ApplicationDomain.currentDomain.getDefinition("rconnect.net.BinaryMessageCodec");
         // A post-scenario microbenchmark, not part of any measured frame window.
         // Normalize once to the existing JSON data model, then compare codecs
         // on the same native snapshot. Production negotiates the checked codec.
         for(var pass:int=0;pass<4;pass++) {
            var start:int=getTimer(),body:ByteArray,decoded:Object,i:int;
            for(i=0;i<30;i++){body=new ByteArray();body.writeUTFBytes(JSON.stringify(plain));body.position=0;decoded=JSON.parse(body.readUTFBytes(body.length));}
            var jsonMs:int=getTimer()-start,jsonBytes:int=body.length;
            start=getTimer();
            for(i=0;i<30;i++){body=new ByteArray();body.writeObject(plain);body.position=0;decoded=body.readObject();}
            var binaryMs:int=getTimer()-start,binaryBytes:int=body.length;
            start=getTimer();
            if(checkedCodec!=null)
               for(i=0;i<30;i++){body=checkedCodec.pack(plain);decoded=checkedCodec.unpack(body);}
            rows.push({jsonMs:jsonMs,binaryMs:binaryMs,jsonBytes:jsonBytes,binaryBytes:binaryBytes,
               checkedMs:checkedCodec==null?-1:getTimer()-start,checkedBytes:checkedCodec==null?0:body.length,decoded:decoded!=null});
         }
         Log.d("PACKET CODEC PROBE "+JSON.stringify({role:host?"host":"join",rows:rows}));
      }
      private function diagBegin(e:Event):void {
         if(phase!="load")return;diagAt=getTimer();diagAfter=0;diagNumber++;
         if((densityProbe<=1 || densityProbe>=5) && diagNumber%5==1 && diagNumber<30) {
            clearSamples();sampleInternalAllocs(false);startSampling();diagSampling=true;
         }
      }
      private function diagAfterFrame(e:Event):void {if(diagAt>0)diagAfter=getTimer();}
      private function diagEnd(e:Event):void {
         if(diagAt==0)return;
         var end:int=getTimer(),total:int=0,cpu:int=0,stacks:Object={};
         if(diagSampling) {
            pauseSampling();total=getSampleCount();
            for each(var sample:Sample in getSamples()) {
               if(sample is NewObjectSample || sample is DeleteObjectSample)continue;
               cpu++;var names:Array=[];
               if(sample.stack!=null)for each(var frame:StackFrame in sample.stack)
                  names.push(frame.name+"@"+frame.file+":"+frame.line);
               var key:String=names.join(" <- ");stacks[key]=int(stacks[key])+1;
            }
            stopSampling();diagSampling=false;
         }
         diagRows.push({phase:densityProbe,at:diagAt,after:diagAfter,end:end,samples:total,cpu:cpu,stacks:stacks});
         diagAt=0;
      }
      public function SustainedDensityTestDoc(withProjectiles:Boolean=false,profile:Boolean=false) {
         projectileLoad=withProjectiles;
         diagEnabled=profile;
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void{
            check(false,"uncaught "+e.error);e.preventDefault();finish();});
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();addEventListener(Event.ENTER_FRAME,frame);
      }
      private function check(ok:Boolean,label:String):void{Log.d("COOP "+(ok?"PASS ":"FAIL ")+"network-state "+label);}
      private function setPhase(s:String):void {phase=s;at=getTimer();}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="combat-network-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,message);
         l.addEventListener(TcpLink.MESSAGE,function(e:NetMessageEvent):void{if(phase=="load")netAt=getTimer();},false,100000);
         l.addEventListener(TcpLink.MESSAGE,function(e:NetMessageEvent):void{if(phase=="load"){var n:int=getTimer()-netAt;netMs+=n;netMax=Math.max(netMax,n);}},false,-100000);
      }}
      private function finish():void {
         if(phase=="done")return;
         if(diagEnabled){diagEnd(null);encodingProbe();Log.d("PROJECTILE PROFILE "+JSON.stringify({role:host?"host":"join",frames:diagRows}));}
         if(setupStage)mod.stage.removeEventListener(Event.RENDER,renderProjectiles);
         if(seedClass!=null)seedClass.rconnectSeedSource=originalSeed;
         phase="done";timer.stop();Log.d("COOP EFFECTS DONE network-state "+(host?"host":"join"));
      }
      private function renderProjectiles(e:Event):void {
         if(host || phase!="load" || !projectileLoad || densityProbe==0)return;
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i);
            if(!projectileClasses[getQualifiedClassName(v)] || !v.visible || v.alpha<=0 || v.stage==null)continue;
            var shown:Boolean=true,parent:DisplayObject=v.parent;
            while(parent!=null){shown=shown&&parent.visible&&parent.alpha>0;parent=parent.parent;}
            if(!shown)continue;
            renderedProjectiles++;
            var old:Object=projectilePositions[v];
            if(old!=null && Math.abs(v.x-old.x)+Math.abs(v.y-old.y)>.1)movingProjectiles++;
            projectilePositions[v]={x:v.x,y:v.y};
         }
      }
      private function find(id:String):Object {for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit) && u.id==id)return u;return null;}
      private function spawn(name:String,id:String,map:XML,x:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new c(id,100,map,null);u.putLoc(mod.game.loc,x,mod.game.gg.Y);
         mod.game.loc.addObj(u);mod.game.loc.units.push(u);u.disabled=true;u.hp=u.maxhp=2000;u.xp=0;u.doop=true;
         loadActors.push(u);
         return u;
      }
      private function message(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="combat-network-test" && p.stage=="next-phase"){
            Log.d("COOP PROBE host-window phase="+densityProbe+" frames="+frames+" elapsedMs="+(getTimer()-at));
            frames=prevFrame=0;nextPhase();setPhase("load");return;
         }
         if(!host && p.type=="unitsync" && phase=="load"){
            if(diagEnabled)diagPacket=p;
            var now:int=getTimer();if(lastPacket>0)maxPacket=Math.max(maxPacket,now-lastPacket);lastPacket=now;packets++;
            if(projectileLoad && p.units is Array)for each(var unit:Object in p.units)
               if(unit.weapons is Array)for each(var weapon:Object in unit.weapons)
                  if(weapon.events is Array)for each(var event:Object in weapon.events) {
                     projectileEvents++;if(event.flight!=null && event.flight.frames is Array)projectileSamples+=event.flight.frames.length;
                     // Installed A also uses native birth/velocity/endpoints for
                     // ordinary NPC bullets. Require usable trajectory data and
                     // actual moving display objects, not a newer wire format.
                     var flight:Object=event.flight;
                     if(flight!=null && flight.cls!=null && isFinite(Number(flight.x)) && isFinite(Number(flight.y))
                        && isFinite(Number(flight.dx)) && isFinite(Number(flight.dy))
                        && Math.abs(Number(flight.dx))+Math.abs(Number(flight.dy))>0) {
                        trajectoryEvents++;projectileClasses[String(flight.cls)]=true;
                     }
                     if(event.flight!=null && Number(event.flight.end)>0 && event.flight.frames is Array)
                        for each(var point:Object in event.flight.frames)
                           if(Number(point.at)>Number(event.flight.end))endedSamples++;
                  }
         }
         if(p.type!="combat-network-test")return;
         if(p.stage=="done"){finish();return;}
         if(host){
            if(p.stage=="ready"){
               enemy=spawn("UnitZombie","1",<unit tr="1" dig="0"/>,mod.game.gg.X+90);
               var gun:NativeTestGun=new NativeTestGun(mod.game.gg as Unit),gw:Object=gun;
               gw.setPers(mod.game.gg,mod.game.gg.pers);gw.damage=60;gw.critCh=0;
               enemy.disabled=false;gun.fireAt(enemy,true);expected=2000-enemy.hp;enemy.hp=2000;enemy.disabled=true;
               check(expected>0,"native ghoul damage reference="+expected);
               bat=spawn("UnitBat","1",<unit tr="1"/>,mod.game.gg.X+170);
               CombatStateProbe.ai(bat as Unit,3);bat.animate();
               mod.game.readUnitsSnapshot();
               setPhase("ghoul");send("ghoul",{expected:expected,enemyKey:mod.game.unitKey(enemy),batKey:mod.game.unitKey(bat)});
            } else if(p.stage=="ghoul-shot"){ghoulLoss=Number(p.loss);setPhase("ghoul-settle");}
            else if(p.stage=="turret-ready")fireTurret();
            else if(p.stage=="turret-checked"){index++;prepareTurret();}
            else if(p.stage=="load-ready"){setPhase("load");}
            else if(p.stage=="load-checked"){
               Log.d("COOP PROBE host-final frames="+frames+" elapsedMs="+(getTimer()-at)+" memory="+System.totalMemory);
               send("done");finish();
            }
         } else {
            if(p.stage=="ghoul"){expected=Number(p.expected);enemyKey=String(p.enemyKey);batKey=String(p.batKey);setPhase("ghoul");}
            else if(p.stage=="prepare-turret"){
               index=int(p.index);mod.game.gg.pers.begHP=5000;mod.game.gg.maxhp=5000;mod.game.gg.hp=5000;mod.game.gg.invulner=false;
               if(index==0){baselineActive=true;baselineAt=getTimer();baselineFrames=baselinePrev=0;baselineIntervals=[];}
               // Keep the native wound calculation below random trauma thresholds:
               // otherwise this oracle hit plus the real hit can rescale max HP.
               mod.game.gg.pers.inMaxHP=100000;mod.game.gg.pers.healAll();
               mod.game.gg.healhp=0;mod.game.gg.rad=0;mod.game.gg.shithp=0;mod.game.gg.currentArmor=null;
               mod.game.gg.skin=8;mod.game.gg.armor_qual=0;mod.game.gg.dexter=0;mod.game.gg.dodge=0;
               mod.game.gg.vulner[0]=1;mod.game.gg.vulner[5]=0.5;mod.game.gg.vulner[6]=0.25;
               setPhase("turret-ready");
            } else if(p.stage=="turret-shot"){
               // Independent native oracle: same bullet damage and modifiers, on
               // the real local UnitPlayer, before the production hit packet arrives.
               var g:Object=mod.game.gg,c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
               var owner:Object=find("turret1");
               var b:Object=new c(owner,g.X,g.Y-g.scY/2,null,false);
               for(var k:String in p.b)b[k]=p.b[k];
               startHp=g.hp;g.damage(b.damage,b.tipDamage,b,false);expected=startHp-g.hp;g.hp=startHp;
               setPhase("turret-settle");
            } else if(p.stage=="load"){
               aimKey=String(p.aimKey);
               baselineActive=false;baselineIntervals.sort(Array.NUMERIC);
               Log.d("COOP METRIC baseline-state frames="+baselineFrames+" elapsedMs="+(getTimer()-baselineAt)
                  +" p95ms="+(baselineIntervals.length?baselineIntervals[int(baselineIntervals.length*.95)]:-1));
               frames=prevFrame=maxFrame=lastPacket=maxPacket=packets=0;intervals=[];samples={};setPhase("load-wait");
            }
         }
      }
      private function prepareTurret():void {
         if(turret!=null){mod.game.loc.remObj(turret);mod.game.loc.units.splice(mod.game.loc.units.indexOf(turret),1);}
         if(index>=turretKinds.length){
            for(var i:int=0;i<78;i++){
               var u:Object=spawn(i%2==0?"UnitBat":"UnitSlaver",i%2==0?"1":"slaver2",<unit tr="2"/>,mod.game.gg.X+160);
               CombatStateProbe.ai(u as Unit,3);u.dx=3;u.stay=true;u.animate();
               if(projectileLoad && i%2==1) {
                  if(u.currentWeapon!=null)u.currentWeapon.remVisual();
                  var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
                  var firing:Boolean=loadGuns.length<12;
                  // Match the workload across builds instead of comparing two
                  // randomly armed crowds. Twelve LMGs fire; the rest only aim.
                  var gun:Object=factory.create(u,firing?"lmg":"p308c",0);u.currentWeapon=gun;u.childObjs=[gun];gun.addVisual();
                  gun.hold=10000;gun.damage=1;gun.destroy=0;gun.damageExpl=0;gun.precision=0;gun.deviation=0;gun.critCh=0;
                  if(firing)loadGuns.push(gun);
               }
            }
            mod.game.readUnitsSnapshot();
            for each(var actor:Object in loadActors)if(actor.id=="slaver2"){aimKey=mod.game.unitKey(actor);break;}
            send("load",{aimKey:aimKey});setPhase("wait-load");return;
         }
         var xml:XML=<unit vis="right"/>;xml.@tr=turretKinds[index];
         turret=spawn("UnitTurret","land",xml,mod.game.gg.X+230);
         turret.alarma();turret.animate();send("prepare-turret",{index:index});setPhase("wait-turret");
      }
      private function fireTurret():void {
         var ghost:Object=mod.game.getRemoteGhost(2);if(ghost==null)ghost=mod.game.getRemoteGhost(1);
         check(ghost!=null,"turret "+index+" has remote target");
         turret.doop=false;turret.disabled=false;turret.storona=-1;turret.overLook=true;
         // The two players may enter the same room through different doors.
         // Test native turret perception near its actual remote target rather
         // than inadvertently placing it beside the other player's doorway.
         turret.setPos(ghost.X+45,ghost.Y);
         turret.eyeX=turret.X;turret.eyeY=turret.Y-30;turret.vAngle=Math.PI;
         Log.d("COOP PROBE turret sight="+turret.look(ghost,true)+" meet="+turret.isMeet(ghost)+" visibility="+ghost.visibility+" demask="+ghost.demask);
         mod.game.redirectNearbyAggro();
         check(turret.findCel(true) && turret.celUnit===ghost,"turret "+index+" native perception selects joiner");
         turret.disabled=true;
         var w:Object=turret.currentWeapon;w.X=ghost.X-45;w.Y=ghost.Y-ghost.scY/2;w.rot=w.forceRot=0;
         w.findCel=false;w.precision=0;w.deviation=0;w.critCh=0;w.t_attack=w.t_reload=0;w.hold=100;
         w.damage=60;w.damageExpl=0;w.dopCh=0;w.kol=1;
         w.attack();for(var i:int=0;i<30 && w.b==null;i++)w.step();
         shot=w.b;check(shot!=null,"turret "+index+" native weapon creates projectile");
         shot.desintegr=0;shot.probiv=0;
         var data:Object={};for each(var key:String in ["damage","tipDamage","armorMult","pier","critCh","critDamMult","critInvis","desintegr","probiv","dx","dy","vel"])
            data[key]=shot[key];
         shot.precision=0;shot.miss=0;shot.critCh=data.critCh=0;shot.critInvis=data.critInvis=0;
         send("turret-shot",{b:data});
         // Native Bullet.run still owns collision and dispatches the typed event.
         shot.X=ghost.X;shot.Y=ghost.Y-ghost.scY/2;shot.dx=shot.dy=0;shot.run();
         check(shot.parr.indexOf(ghost)>=0,"turret "+index+" native projectile hits remote collision body");
         mod.game.loc.remObj(shot);setPhase("wait-turret");
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null)return;
         if(seedClass==null) {
            seedClass=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
            originalSeed=seedClass.rconnectSeedSource;
            var fallback:Function=originalSeed;
            seedClass.rconnectSeedSource=function(land:Object):uint {
               return String(land.act.id)=="random_mane"?uint(719355926):uint(fallback(land));
            };
         }
         // Protect only the isolated fixture's actors during connection/travel.
         // Waiting 25 seconds before doing so allowed the test player to die.
         if(phase=="boot" && mod.game.gg!=null)mod.game.gg.invulner=true;
         if(mod.game.gg==null||mod.game.loc==null||!mod.session.rooms.ready||mod.session.rooms.busy)return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(timer.currentCount<250)return;
         try {
            if(phase=="boot"){
               check(Number(GameBridge.probe(mod.game.world.land,"rconnectLayoutSeed"))==719355926,"fixture uses recorded native map seed");
               check(mod.game.gg.sost==1 && mod.game.gg.hp>0,"fixture enters with a living player");
               if(mod.game.gg.sost!=1 || mod.game.gg.hp<=0){send("done");finish();return;}
               mod.stage.nativeWindow.visible=true;
               check(mod.stage.nativeWindow.visible,"fixture window is visible");
               mod.stage.addEventListener(Event.RENDER,renderProjectiles,false,-30000);
               setupStage=true;
               if(diagEnabled) {
                  mod.stage.addEventListener(Event.ENTER_FRAME,diagBegin,false,1000000);
                  mod.stage.addEventListener(Event.ENTER_FRAME,diagAfterFrame,false,-1000000);
                  mod.stage.addEventListener(Event.RENDER,diagEnd,false,-1000000);
               }
               if(!host){
                  mod.stage.addEventListener(Event.ENTER_FRAME,function(e:Event):void{frameAt=getTimer();},false,200000);
                  mod.stage.addEventListener(Event.ENTER_FRAME,function(e:Event):void{if(phase=="load"){var n:int=getTimer()-frameAt;cpuMs+=n;cpuMax=Math.max(cpuMax,n);}},false,-200000);
               }
               mod.game.world.testDam=true;mod.game.gg.disabled=true;mod.game.gg.invulner=host;mod.game.gg.pers.begHP=5000;mod.game.gg.hp=5000;mod.game.gg.maxhp=5000;
               mod.game.gg.healhp=0;mod.game.gg.demask=1000;
               if(!host){send("ready");setPhase("wait");}else setPhase("wait");
            }
            if(!host&&phase=="ghoul"&&getTimer()-at>1200){
               enemy=mod.game.unitForKey(enemyKey);bat=mod.game.unitForKey(batKey);
               check(enemy!=null,"TCP ghoul appears");var hp:Number=enemy.hp;
               var gun:NativeTestGun=new NativeTestGun(mod.game.gg as Unit);var gw:Object=gun;gw.setPers(mod.game.gg,mod.game.gg.pers);gw.damage=60;gw.critCh=0;
               var projectile:Object=gun.fireAt(enemy,true);check(expected>0 && Math.abs(hp-enemy.hp-expected)<0.001,"TCP join LMG matches native ghoul damage expected="+expected+" actual="+(hp-enemy.hp)+" height="+enemy.scY);
               var receiver:Object;for each(var hit:Object in mod.game.loc.units)if(hit is MirrorHitUnit && MirrorHitUnit(hit).body===enemy)receiver=hit;
               Log.d("COOP PROBE ghoul body="+[enemy.fraction,enemy.hp,enemy.scY,enemy.invulner,enemy.sost,enemy.trigDis]
                  +" receiver="+(receiver==null?"null":[receiver.fraction,receiver.hp,receiver.scY,receiver.invulner,receiver.disabled,receiver.trigDis,receiver.X1,receiver.X2,receiver.Y1,receiver.Y2])
                  +" bullet="+[projectile.damage,projectile.off,projectile.babah,projectile.X,projectile.Y,projectile.parr,projectile.tipDamage,mod.game.gg.pers.damZombie]);
               Log.d("COOP PROBE ghoul defenses="+[receiver.skin,receiver.armor,receiver.armor_qual,receiver.shithp,receiver.shitArmor,receiver.allVulnerMult,receiver.vulner,projectile.miss,projectile.critCh,projectile.owner===receiver.loc.gg,projectile.precision]);
               check(bat!=null&&bat.vis.osn.currentLabel=="fly","TCP bloodwing displays flying pose");
               send("ghoul-shot",{loss:hp-enemy.hp});setPhase("wait");
            }
            if(host&&phase=="ghoul-settle"&&getTimer()-at>700){check(ghoulLoss>0&&Math.abs(enemy.hp-(2000-ghoulLoss))<0.001,"TCP host settles exactly one LMG hit loss="+ghoulLoss+" hp="+enemy.hp);prepareTurret();}
            if(!host&&phase=="turret-ready"&&getTimer()-at>800){send("turret-ready");setPhase("wait");}
            if(!host&&phase=="turret-settle"&&getTimer()-at>600){
               var actual:Number=startHp-mod.game.gg.hp;
               check(expected>0&&Math.abs(actual-expected)<0.001,"turret "+index+" TCP damage equals native player calculation expected="+expected+" actual="+actual);
               send("turret-checked");setPhase("wait");
            }
            if(!host&&phase=="load-wait"&&getTimer()-at>1500){
               Log.d("COOP PROBE window phase=0 visible="+mod.stage.nativeWindow.visible+" frameRate="+mod.stage.frameRate+" quality="+mod.stage.quality);
               send("load-ready");frames=prevFrame=maxFrame=0;intervals=[];setPhase("load");
               var timingBridge:Object=mod.game;if("presentationTiming" in timingBridge)timingBridge.presentationTiming={viewMs:0,viewCalls:0,motionMs:0,motionCalls:0};
            }
            if(host&&phase=="load"){
               // Drive only this fixture's native actors, never a third-party
               // lamp/scene hit proxy merely because its fraction is below 100.
               for each(var u:Object in loadActors)if(u.in_chain&&u.loc===mod.game.loc&&u.sost<3){u.dx=3;u.setPos(u.X+((timer.currentCount%20<10)?2:-2),u.Y);if(u.currentWeapon!=null)u.currentWeapon.rot=Math.sin(getTimer()/400);}
            }
            if(!host&&phase=="load"&&getTimer()-at>8000){
               intervals.sort(Array.NUMERIC);var p95:int=intervals.length?intervals[int(intervals.length*.95)]:9999;
               var count:int=0;for(var s:String in samples)count++;
               Log.d("COOP METRIC network-state frames="+frames+" p95ms="+p95+" maxms="+maxFrame+" packets="+packets+" maxPacketMs="+maxPacket+" aimSamples="+count);
               Log.d("COOP METRIC event-cost cpuMs="+cpuMs+" cpuMax="+cpuMax+" netMs="+netMs+" netMax="+netMax);
               var bridge:Object=mod.game;if("presentationTiming" in bridge)Log.d("COOP METRIC timing "+JSON.stringify(bridge.presentationTiming));
               check(frames>=80&&p95<200,"80 enemies keep stage frames progressing");
               check(packets>=20&&maxPacket<900,"80 enemies keep current world snapshots arriving");
               check(count>packets,"weapon aim advances between snapshots");
               if(projectileLoad && densityProbe>0) {
                  check(projectileEvents>0 && trajectoryEvents>0,"dense firing transports native trajectories events="+projectileEvents+" trajectories="+trajectoryEvents+" recordedFrames="+projectileSamples);
                  check(renderedProjectiles>0 && movingProjectiles>0,"dense firing renders moving projectile displays visible="+renderedProjectiles+" moving="+movingProjectiles);
                  check(endedSamples==0,"ended projectiles stop adding hidden poses samples="+endedSamples);
               }
               Log.d("COOP PROBE steady phase="+densityProbe+" utcMs="+(new Date()).time+" memory="+System.totalMemory);
               if(densityProbe<6) {
                  nextPhase();send("next-phase");
                  frames=prevFrame=maxFrame=lastPacket=maxPacket=packets=0;intervals=[];samples={};setPhase("load");
               } else {send("load-checked");finish();}
            }
         }catch(err:*){check(false,"error "+err+" "+(err is Error?Error(err).getStackTrace():""));send("done");finish();}
      }
      private function nextPhase():void {
         densityProbe++;
         diagNumber=0;
         projectileEvents=projectileSamples=endedSamples=0;
         trajectoryEvents=renderedProjectiles=movingProjectiles=0;projectilePositions=new Dictionary(true);
         var weapons:Object={};
         for each(var u:Object in mod.game.loc.units)if(u.currentWeapon!=null)weapons[u.currentWeapon.id]=int(weapons[u.currentWeapon.id])+1;
         Log.d("COOP PROBE steady-start phase="+densityProbe+" utcMs="+(new Date()).time+" weapons="+JSON.stringify(weapons));
      }
      private function frame(e:Event):void {
         if(mod==null)return;
         if(host){
            if(phase=="load") {
               frames++;
               if(projectileLoad && densityProbe>0)for(var i:int=0;i<loadGuns.length;i++) {
                  var gun:Object=loadGuns[i],owner:Object=gun.owner;
                  gun.X=owner.X;gun.Y=owner.Y-owner.scY/2;
                  gun.rot=gun.forceRot=-Math.PI/3+Math.sin(getTimer()/400)*.2;
                  if(frames%12==i%12)gun.attack();gun.step();
               }
            }
            return;
         }
         if(baselineActive){
            var sampleAt:int=getTimer();baselineFrames++;
            if(baselinePrev>0)baselineIntervals.push(sampleAt-baselinePrev);baselinePrev=sampleAt;
         }
         if(phase!="load")return;
         var now:int=getTimer();frames++;if(prevFrame>0){intervals.push(now-prevFrame);maxFrame=Math.max(maxFrame,now-prevFrame);}prevFrame=now;
         var u:Object=mod.game.unitForKey(aimKey);if(u!=null&&u.currentWeapon!=null)samples[Number(u.currentWeapon.rot).toFixed(4)]=true;
      }
   }
}
