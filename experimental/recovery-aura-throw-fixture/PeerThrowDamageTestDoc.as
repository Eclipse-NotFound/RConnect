package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.EnemyGrabProbe;
   import rconnect.core.Config;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real Q grab / E action / owner physics / native wall impact over TCP.
    * The arena wall and hostile takeover fields are isolated test fixtures.
    * No direct PeerThrowDamage.arm/damageWall calls replace the gameplay path. */
   public class PeerThrowDamageTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=["off","on","off-existing","on-existing","revoke","enable","drop","foreign","reset","pause-on"];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,remoteReady:Boolean=false;
      private var localReady:Boolean=false,peerReady:Boolean=false,localLifted:Boolean=false,peerLifted:Boolean=false;
      private var localDone:Boolean=false,peerDone:Boolean=false,baseX:Number,baseY:Number,wallX:Number;
      private var held:int=0,minY:Number,maxX:Number,flightFrames:int=0,armed:int=0,sawThrow:Boolean=false;
      private var requestAction:Boolean=false,enemyChecked:Boolean=false,baselineHp:Number,original:Number=0;
      private var foreignWritten:Boolean=false,pauseAt:int=0,pauseCounter:int=-1,pausedSamples:int=0,pauseStable:Boolean=true;
      private var lastRelease:Object,replayAt:int=0,replayBefore:Object;
      private var healthMaxHp:Number=NaN,baselineMaxHp:Number=NaN,healthMaxChanged:Boolean=false,healthChanges:int=0;
      private function healthState():Object {
         var g:Object=mod.game.gg,p:Object=g.pers;
         return {hp:g.hp,maxhp:g.maxhp,begHP:p.begHP,level:p.level,inMaxHP:p.inMaxHP,inMaxMana:p.inMaxMana,
            headHP:p.headHP,torsHP:p.torsHP,legsHP:p.legsHP,bloodHP:p.bloodHP,manaHP:p.manaHP,
            headSt:p.headSt,torsSt:p.torsSt,legsSt:p.legsSt,bloodSt:p.bloodSt,manaSt:p.manaSt,
            organMult:p.organMult,organMultPot:p.organMultPot,healhp:g.healhp,regenFew:p.regenFew,
            godMode:mod.game.world.godMode,invulner:g.invulner};
      }
      private function prepareHealth():void {
         var g:Object=mod.game.gg,p:Object=g.pers;
         // Retain the old fixture's base HP, but let native level/perk inputs
         // derive both maxima. healAll alone leaves the previous trauma grades.
         p.begHP=10000;p.setParameters();
         p.heal(Number(p.inMaxHP),4);p.heal(Number(p.inMaxHP),5);p.heal(Number(p.inMaxMana),6);
         p.setParameters();g.hp=g.maxhp;
         healthMaxHp=Number(g.maxhp);baselineMaxHp=healthMaxHp;healthMaxChanged=false;healthChanges=0;
         // A second native recalculation must not change this round's premise.
         p.setParameters();
         var ready:Boolean=isFinite(healthMaxHp)&&healthMaxHp>0&&g.maxhp==healthMaxHp&&g.hp==healthMaxHp
            &&p.headSt==0&&p.torsSt==0&&p.legsSt==0&&p.bloodSt==0&&p.manaSt==0
            &&p.headHP==p.inMaxHP&&p.torsHP==p.inMaxHP&&p.legsHP==p.inMaxHP&&p.bloodHP==p.inMaxHP
            &&p.manaHP==p.inMaxMana&&!g.invulner&&!mod.game.world.godMode;
         Log.d("PEER THROW HEALTH prepared "+JSON.stringify({round:round,kind:kind(),health:healthState()}));
         check(ready,"native health and trauma state agree before each round");
         if(!ready)throw new Error("Native throw fixture health does not survive setParameters");
      }
      private function observeHealth(label:String):void {
         if(phase=="boot"||phase=="waiting"||phase=="done"||!isFinite(healthMaxHp))return;
         if(Number(mod.game.gg.maxhp)==healthMaxHp)return;
         healthMaxChanged=true;
         if(healthChanges++<4)Log.d("PEER THROW HEALTH changed "+JSON.stringify({round:round,kind:kind(),label:label,
            expectedMax:healthMaxHp,baselineHp:baselineHp,baselineMaxHp:baselineMaxHp,health:healthState()}));
      }
      // Diagnostic only: reset per round; never retry Q or alter a test barrier.
      private var diagWire:Object={},diagBefore:int=0,diagAfter:int=0,diagWaiting:int=0,diagNextWait:int=250;
      private function diagnosticState(label:String,packet:Object=null):void {
         try {
            var g:Object=mod.game.gg,t:Object=ghost(),raw:Object=GameBridge.probe(g,"teleObj");
            var ability:Object=g==null?null:PeerAuraFixture.casterState(g);
            var row:Object={label:label,round:round,kind:kind(),role:host?"host":"join",phase:phase,
               at:getTimer(),wall:new Date().time,caster:caster(),held:held,minY:minY,baseY:baseY,
               localLifted:localLifted,peerLifted:peerLifted,ability:ability,health:healthState(),
               player:{sost:GameBridge.probe(g,"sost"),hp:GameBridge.probe(g,"hp"),work:GameBridge.probe(g,"work"),
                  ggControl:GameBridge.probe(g,"ggControl"),levit:GameBridge.probe(g,"levit"),
                  t_die:GameBridge.probe(mod.game.world,"t_die"),dead:mod.game.isPlayerDead(),
                  x:GameBridge.probe(g,"X"),y:GameBridge.probe(g,"Y"),mass:GameBridge.probe(g,"massa"),
                  dx:GameBridge.probe(g,"dx"),dy:GameBridge.probe(g,"dy"),mana:GameBridge.probe(g,"mana"),
                  teleObj:raw==null?null:String(GameBridge.probe(raw,"id")),teleObjIsPeer:raw!=null&&raw===t,
                  disabled:GameBridge.probe(g,"disabled"),anim:GameBridge.probe(g,"animState")},
               peer:t==null?null:{id:GameBridge.probe(t,"id"),x:GameBridge.probe(t,"X"),y:GameBridge.probe(t,"Y"),
                  sost:GameBridge.probe(t,"sost"),hp:GameBridge.probe(t,"hp"),mass:GameBridge.probe(t,"massa"),
                  levit:GameBridge.probe(t,"levit"),levitPoss:GameBridge.probe(t,"levitPoss"),
                  inChain:GameBridge.probe(t,"in_chain"),sameRoom:GameBridge.probe(t,"loc")===mod.game.loc},
               consent:{allowed:mod.peerGrip.allowed,held:mod.peerGrip.heldByTeammate,throwActive:mod.peerGrip.throwDamageActive},
               rooms:{ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,hold:mod.game.roomHold,
                  transition:mod.game.isTransitioning(),key:mod.game.roomKey(),epoch:mod.session.rooms.epoch,term:mod.session.rooms.term},
               world:{paused:mod.session.pause.paused,requested:mod.session.pause.requested,
                  onPause:GameBridge.probe(mod.game.world,"onPause"),allStat:GameBridge.probe(mod.game.world,"allStat"),
                  portOn:GameBridge.probe(mod.game.loc,"portOn")}};
            if(packet!=null) {
               var dx:Number=t==null?NaN:Number(g.X)-Number(t.X),dy:Number=t==null?NaN:Number(g.Y)-Number(t.Y);
               row.packet={op:packet.op,token:packet.token,accept:packet.accept,reason:packet.reason,input:packet.input,
                  roomKey:packet.roomKey,roomEpoch:packet.roomEpoch,roomTerm:packet.roomTerm};
               row.receiveEligibility={distanceSquared:dx*dx+dy*dy,
                  line:t==null?null:mod.game.loc.isLine(t.X,t.Y-t.scY*.75,g.X,g.Y-g.scY/2),
                  targetLevit:GameBridge.probe(g,"levit"),targetMass:GameBridge.probe(g,"massa"),
                  targetAlive:g!=null&&g.sost==1&&g.hp>0&&!mod.game.isPlayerDead()};
            }
            Log.d("PEER THROW DIAG "+JSON.stringify(row));
         }catch(err:Error) {
            // Observation failure is visible but cannot change gameplay/test flow.
            Log.d("PEER THROW DIAG ERROR "+label+" "+err.getStackTrace());
         }
      }
      private function observeGripPacket(p:Object):void {
         if(phase=="done"||p==null||p.type!="peer-grip"||(p.op!="hold"&&p.op!="ack"&&p.op!="release"))return;
         var key:String=String(p.op);if(diagWire[key])return;diagWire[key]=true;
         diagnosticState("received-first-"+key,p);
      }

      public function PeerThrowDamageTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function kind():String {return CASES[round%CASES.length];}
      private function caster():Boolean {return round<CASES.length?host:!host;}
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"peer-throw-damage "+s+" round="+round+" kind="+kind());}
      private function change(p:String):void {phase=p;at=getTimer();Log.d("PEER THROW PHASE "+(host?"host ":"join ")+p+" round="+round);}
      private function send(op:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="peer-throw-damage-test";p.op=op;p.round=round;
         if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);
      }
      private function raw(p:Object):void {if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {
         if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);l.addEventListener(TcpLink.MESSAGE,wireAfter,false,-10000);}
      }
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function ghost():Object {return mod.game.getRemoteGhost(host?1:0);}
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=280;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-400;x+=40) {
            var clear:Boolean=true;for(var ix:int=-20;ix<=360&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=240;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }if(clear){baseX=x;baseY=y;return;}
         }throw new Error("no native floored peer throw corridor");
      }
      private function install():void {
         check(mod.game.readWorldInfo().layoutSeed==PeerAuraFixture.SEED,"same native corridor layout in both exact-byte runs");
         check(mod.config.getValue("peerThrowDamage")=="0"&&!mod.peerGrip.throwDamageAllowed,"personal default off");
         mod.game.forceCloseOverlays();mod.config.setValue("followTeammate","0");
         PeerAuraFixture.prepareCaster(mod.game.gg);
         var l:Object=mod.game.loc;wallX=baseX+320;
         for each(var o:Object in l.objs.concat())if(o.X2>baseX-20&&o.X1<wallX+40&&o.Y2>baseY-250&&o.Y1<baseY+20) {
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);if(l.celObj===o)l.celObj=null;
         }
         for(var row:int=0;row<6;row++) {
            var tile:Object=l.getAbsTile(wallX+5,baseY-20-row*40);
            tile.phis=1;tile.shelf=false;tile.zForm=0;tile.diagon=0;tile.indestruct=true;
            tile.phX1=tile.X*40;tile.phX2=tile.phX1+40;tile.phY1=tile.Y*40;tile.phY2=tile.phY1+40;
         }
         mod.game.world.godMode=false;mod.game.world.testDam=true;mod.game.world.showHit=0;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
         mod.stage.addEventListener(Event.ENTER_FRAME,damageProbe,false,97000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-9500);
      }
      private function start(n:int):void {
         round=n;mod.peerGrip.reset();mod.game.forceCloseOverlays();var g:Object=mod.game.gg;
         g.currentArmor=null;g.armor_qual=0;g.skin=0;g.marmor=0;g.allVulnerMult=1;g.shithp=0;
         g.healhp=0;g.rad=0;g.invulner=false;g.neujaz=0;g.cut=g.poison=0;g.pinok=0;g.stun=0;g.cryst=false;
         prepareHealth();
         for(var i:int=0;i<g.vulner.length;i++)g.vulner[i]=1;
         g.t_throw=0;original=kind().indexOf("existing")>=0?61:0;g.damWall=original;
         g.mana=g.maxmana=10000;
         mod.peerGrip.setPreferences(!caster(),false);
         mod.peerGrip.setThrowDamageAllowed(!caster()&&(kind()=="on"||kind()=="on-existing"||kind()=="revoke"||kind()=="drop"||kind()=="pause-on"));
         check(new Config().getValue("peerThrowDamage")==mod.config.getValue("peerThrowDamage"),"own preference persists");
         if(host)mod.session.pause.setPolicy(kind()=="pause-on",false);
         localReady=peerReady=localLifted=peerLifted=localDone=peerDone=false;
         held=flightFrames=armed=0;sawThrow=requestAction=enemyChecked=foreignWritten=false;
         minY=baseY;maxX=baseX+160;pauseAt=pausedSamples=0;pauseCounter=-1;pauseStable=true;
         diagWire={};diagBefore=diagAfter=diagWaiting=0;diagNextWait=250;
         lastRelease=null;baselineHp=g.hp;change("settle");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p==null||p.type!="peer-throw-damage-test")return;
         try {
            if(host&&p.op=="ready")remoteReady=true;
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;install();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){start(0);send("round");}
            else if(!host&&p.op=="round")start(p.round);
            else if(p.round!=round)return;
            else if(p.op=="settled"){peerReady=true;if(host&&localReady)beginGrab();}
            else if(!host&&p.op=="grab")beginGrab();
            else if(p.op=="lifted"){peerLifted=true;if(host&&localLifted)beginAction();}
            else if(!host&&p.op=="action")beginAction();
            else if(p.op=="replay-request"&&caster())raw(p.payload);
            else if(p.op=="sampled"){peerDone=true;if(host&&localDone)nextRound();}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function beginGrab():void {
         observeHealth("before-q");
         check(!healthMaxChanged&&mod.game.gg.hp==healthMaxHp,"native health remains stable through settle before Q");
         if(healthMaxChanged||mod.game.gg.hp!=healthMaxHp)throw new Error("Native throw health changed before Q");
         if(host)send("grab");change("holding");if(!caster())return;
         var g:Object=mod.game.gg,t:Object=ghost();
         var dx:Number=g.X-t.X,dy:Number=g.Y-t.Y;
         var capable:Boolean=PeerAuraFixture.canLift(g,Number(t.massa),dx*dx+dy*dy)&&g.mana>=200;
         check(capable,"persistent native caster supports first Q without retries");
         if(!capable)throw new Error("Native throw fixture cannot lift teammate at Q boundary");
         t.onCursor=1;mod.game.loc.celObj=t;mod.game.loc.celDist=0;
         diagnosticState("q-before");
         EnemyGrabProbe.grab(g);
         diagnosticState("q-after");
         check(g.teleObj===t,"native Q takes permitted peer");
      }
      private function beginAction():void {
         if(host)send("action");change("flying");requestAction=caster();
      }
      private function wireAfter(e:NetMessageEvent):void {
         observeGripPacket(e.data);
         var p:Object=e.data;if(caster()||phase!="flying"||p==null||p.type!="peer-grip"||p.op!="release"||p.kick==null)return;
         var g:Object=mod.game.gg;
         if(!mod.peerGrip.throwDamageActive)return;
         armed++;sawThrow=true;lastRelease=JSON.parse(JSON.stringify(p));
         check(g.t_throw==45&&g.levit==0,"real E arms player-owned native throw once");
         if(kind()=="revoke"||kind()=="enable") {
            mod.peerGrip.setThrowDamageAllowed(kind()=="enable");
            check(new Config().getValue("peerThrowDamage")== (kind()=="enable"?"1":"0"),"mid-flight consent persists");
         }
         if(kind()=="reset")mod.peerGrip.reset();
         if(kind()=="pause-on"){mod.game.world.pip.onoff(5);pauseAt=getTimer();}
      }
      private function before(e:Event):void {
         if(phase=="boot"||phase=="waiting"||phase=="done")return;
         observeHealth("before-native");
         if(phase=="holding"&&diagBefore<3)diagnosticState("before-fixture-"+diagBefore);
         var g:Object=mod.game.gg,w:Object=mod.game.world;g.transp=true;g.disabled=false;g.isTake=0;w.ctr.active=true;
         // Native skill/perk inputs survive recalculation; do not rewrite their outputs.
         g.maxmana=10000;if(phase=="settle")g.mana=10000;
         if(phase=="holding"&&diagBefore<3){diagnosticState("after-fixture-"+diagBefore);diagBefore++;}
         g.cut=g.poison=0;g.healhp=0;mod.game.loc.base=false;mod.game.loc.portOn=true;
         for each(var u:Object in mod.game.loc.units)if(u!==g&&String(u.id).indexOf("rconnect_")!=0&&Number(u.fraction)<100)u.disabled=true;
         w.ctr.keyAction=false;w.ctr.keyLeft=w.ctr.keyRight=w.ctr.keyBeUp=w.ctr.keySit=false;
         if(phase=="settle"||caster()){g.dx=g.dy=0;g.setPos(baseX+(caster()?40:160),baseY);g.setVisPos();}
         if(caster()) {
            var ax:Number=baseX+160,ay:Number=phase=="settle"?baseY-35:baseY-85;
            g.celX=w.celX=ax;g.celY=w.celY=ay;w.cam.celX=int(ax*w.cam.scaleV+w.cam.vx);w.cam.celY=int(ay*w.cam.scaleV+w.cam.vy);
            if(requestAction){requestAction=false;if(kind()=="drop")g.dropTeleObj();else w.ctr.keyAction=true;}
         }
      }
      private function damageProbe(e:Event):void {
         if(caster()||phase!="flying"||!sawThrow||enemyChecked||mod.session.pause.paused||mod.game.world.onPause)return;
         var g:Object=mod.game.gg,ad:Object=mod.main.loaderInfo.applicationDomain;
         var U:Class=ad.getDefinition("fe.unit.Unit") as Class,B:Class=ad.getDefinition("fe.weapon.Bullet") as Class;
         var enemy:Object=new U();enemy.loc=g.loc;enemy.fraction=1;
         var bullet:Object=new B(enemy,g.X,g.Y-g.scY/2,null,false);bullet.tipDamage=0;
         observeHealth("before-enemy-probe");
         check(!healthMaxChanged&&g.hp==healthMaxHp,"health baseline is unchanged before real enemy damage");
         var hp:Number=g.hp;g.damage(40,0,bullet);
         check(hp-g.hp>0,"enemy damage still reaches thrown player");baselineHp=g.hp;enemyChecked=true;
         baselineMaxHp=Number(g.maxhp);observeHealth("after-enemy-probe");
         check(!healthMaxChanged,"enemy control preserves health maximum before wall impact");
         Log.d("PEER THROW HEALTH enemy-baseline "+JSON.stringify({round:round,kind:kind(),beforeHp:hp,
            baselineHp:baselineHp,baselineMaxHp:baselineMaxHp,health:healthState()}));
         if(kind()=="foreign") {
            // Native alicorn/Boss contract: a different throw sets 30 and dam/2.
            // Controlled takeover fields, not a claim of running that enemy AI.
            g.t_throw=30;g.damWall=37;foreignWritten=true;
         }
      }
      private function after(e:Event):void {
         observeHealth("after-native");
         if(phase!="holding"&&phase!="flying")return;var t:Object=caster()?ghost():mod.game.gg;if(t==null)return;
         minY=Math.min(minY,t.Y);maxX=Math.max(maxX,t.X);
         if(caster()?mod.game.gg.teleObj===t:t.levit==2)held++;
         if(!caster()&&phase=="flying"&&t.t_throw>0)flightFrames++;
         if(phase=="holding"&&diagAfter<3){diagnosticState("after-native-and-peergrip-"+diagAfter);diagAfter++;}
         if(!caster()&&pauseAt>0&&mod.session.pause.paused) {
            if(pauseCounter<0)pauseCounter=int(t.t_throw);
            pauseStable=pauseStable&&int(t.t_throw)==pauseCounter&&t.damWall==original&&mod.peerGrip.throwDamageActive;pausedSamples++;
         }
      }
      private function sample():void {
         var g:Object=mod.game.gg;
         check(held>=3&&minY<baseY-20,"player genuinely lifted before release");
         if(!caster()) {
            var hurt:Boolean=kind()=="on"||kind()=="on-existing"||kind()=="enable"||kind()=="foreign"||kind()=="pause-on";
            observeHealth("sample");
            // Keep the original absolute-HP oracle. Positive wall damage may
            // legitimately cause trauma; no-hurt cases must retain their cap.
            if(!hurt)check(!healthMaxChanged&&g.maxhp==baselineMaxHp,"no-hurt round keeps the same health maximum");
            if(kind()=="drop")check(armed==0&&!sawThrow&&Math.abs(g.hp-baselineHp)<.01,"ordinary release creates no throw damage");
            else {
               check(armed==1&&sawThrow&&flightFrames>0,"one actual peer impulse reaches native physics");
               check(enemyChecked,"enemy hit control ran during actual flight");
               check(maxX>baseX+200,"throw travels into native wall");
               check(hurt?g.hp<baselineHp:Math.abs(g.hp-baselineHp)<.01,"impact follows personal consent hp="+g.hp+" baseline="+baselineHp);
            }
            check(!mod.peerGrip.throwDamageActive,"native impact/reset retires throw attribution");
            check(g.damWall==(kind()=="foreign"?37:original),"temporary coefficient restored without overwriting native takeover");
            if(kind()=="foreign")check(foreignWritten,"foreign throw control applied");
            if(kind()=="pause-on")check(pausedSamples>=3&&pauseStable&&!mod.session.pause.paused,"shared pause preserves consent flight and restores coefficient");
            if(lastRelease!=null) {
               replayBefore={x:g.dx,y:g.dy,t:g.t_throw,hp:g.hp,maxhp:g.maxhp};send("replay-request",{payload:lastRelease});replayAt=getTimer();change("replay");return;
            }
         }completeSample();
      }
      private function completeSample():void {
         Log.d("PEER THROW SAMPLE "+JSON.stringify({round:round,caster:caster(),kind:kind(),held:held,armed:armed,frames:flightFrames,
            rise:baseY-minY,maxX:maxX,hp:mod.game.gg.hp,baseline:baselineHp,coefficient:mod.game.gg.damWall,
            baselineMaxHp:baselineMaxHp,maxChanged:healthMaxChanged,health:healthState()}));
         localDone=true;send("sampled");change("sampled");if(host&&peerDone)nextRound();
      }
      private function nextRound():void {
         if(round<CASES.length*2-1){start(round+1);send("round");}else{send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null)return;
         try {PeerAuraFixture.prepare(mod,host);}catch(setupError:Error){check(false,setupError.getStackTrace());finish();return;}
         if(mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(phase=="done")return;if(getTimer()-at>(phase=="boot"?180000:90000)){
               if(phase=="holding"&&diagWaiting<8){diagnosticState("holding-timeout");diagWaiting++;}
               check(false,"timeout "+phase);send("done");finish();return;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&remoteReady){arena();install();send("setup",{x:baseX,y:baseY});change("setup");}else if(!host)send("ready");
            }
            var g:Object=mod.game.gg,elapsed:int=getTimer()-at;
            if(phase=="holding"&&diagWaiting<7&&elapsed>=diagNextWait){
               diagnosticState("holding-wait-"+diagWaiting);diagWaiting++;diagNextWait*=2;
            }
            if(phase=="settle"&&!localReady&&elapsed>1600&&stable()&&ghost()!=null&&g.ggControl&&g.sost==1&&g.work!="res") {
               localReady=true;send("settled");if(host&&peerReady)beginGrab();
            }else if(phase=="holding"&&!localLifted&&held>=3&&minY<baseY-20) {
               localLifted=true;send("lifted");if(host&&peerLifted)beginAction();
            }else if(phase=="flying") {
               if(!caster()&&pauseAt>0&&getTimer()-pauseAt>2000)mod.game.world.pip.onoff(-1);
               if(elapsed>4000&&!mod.session.pause.paused&&(caster()||(g.levit==0&&g.t_throw==0)))sample();
            }else if(phase=="replay"&&getTimer()-replayAt>600) {
               check(g.maxhp==replayBefore.maxhp,"health maximum remains stable during retired-release replay");
               check(!mod.peerGrip.throwDamageActive&&g.t_throw<=replayBefore.t&&Math.abs(g.hp-replayBefore.hp)<.01,"retired release cannot rearm or repeat damage");completeSample();
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;change("done");timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,damageProbe);
            mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.peerGrip.reset();}
         Log.d("COOP EFFECTS DONE peer-throw-damage");
      }
   }
}
