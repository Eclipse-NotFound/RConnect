package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filters.GlowFilter;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import fe.unit.EnemyGrabProbe;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native actTele/actions/throwTele -> real Session/TCP -> one enemy simulation.
    * Fixtures never move the enemy or force levitation after the real grab. */
   public class EnemyGrabTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=["host","join","throw","resistance","200-mana",
         "mana-empty","heavy","immune","199-mana","host-first","join-first","paused-hold","menus-local","disconnect"];
      private var timer:Timer=new Timer(100),mod:RConnectMod,host:Boolean;
      private var links:Dictionary=new Dictionary(),phase:String="boot",at:int=getTimer();
      private var baseX:Number,baseY:Number,target:Object,round:int=0,initialY:Number,initialMana:Number;
      private var samples:int=0,lifted:int=0,held:int=0,glowing:int=0,minY:Number,thrown:int=0;
      private var localDone:Boolean=false,peerDone:Boolean=false,readyAt:int=0;
      private var acted:Boolean=false,opposed:Boolean=false,lastHold:Object,lastRelease:Object;
      private var nativeMass:Number,nativeLimit:Number,observedRelease:Boolean=false;
      private var pauseRef:Object,pausedSamples:int=0,pauseStill:int=0,menuClosed:Boolean=false;
      private var releaseBefore:Object,releaseCount:int=0;
      public function EnemyGrabTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,text:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"enemy-grab "+text+" case="+CASES[round]);}
      private function send(stage:String,p:Object=null):void {
         p=p||{};p.type="enemy-grab-test";p.stage=stage;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null && !links[link]) {
            links[link]=true;link.addEventListener(TcpLink.MESSAGE,wireBefore,false,100);
            link.addEventListener(TcpLink.MESSAGE,receive);link.addEventListener(TcpLink.MESSAGE,wireAfter,false,-100);
         }
      }
      private function wireBefore(e:NetMessageEvent):void {
         if(host && round==2 && target!=null && e.data.type=="unit-grip" && e.data.op=="release")
            releaseBefore={x:target.dx,y:target.dy,t:target.t_throw};
      }
      private function wireAfter(e:NetMessageEvent):void {
         if(!host || round!=2 || releaseBefore==null || e.data.type!="unit-grip" || e.data.op!="release")return;
         var b:Object=releaseBefore,k:Object=e.data.kick;releaseBefore=null;++releaseCount;
         if(releaseCount==1)check(k!=null && target.t_throw==45
            && Math.abs(target.dx-b.x-Number(k.x))<0.0001 && Math.abs(target.dy-b.y-Number(k.y))<0.0001,
            "authority applies exactly one native throw impulse");
         else check(target.dx==b.x && target.dy==b.y && target.t_throw==b.t,"duplicate release cannot replay throw impulse");
      }
      private function find():Object {
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)
            if(String(GameBridge.probe(o,"id"))=="rconnect_grab_fixture")return o;
         return null;
      }
      private function glow():Boolean {
         if(target==null || target.vis==null)return false;
         for each(var f:Object in target.vis.filters)if(f is GlowFilter)return true;return false;
      }
      private function player():void {
         var g:Object=mod.game.gg;
         if(!((round==11 || round==12) && acted && !menuClosed))mod.game.forceCloseOverlays();
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.isTake=0;g.work="";
         g.setPos(baseX+(host?0:50),baseY);g.setVisPos();
         mod.game.loc.base=false;mod.game.loc.portOn=true;
      }
      private function start(n:int):void {
         round=n;phase="settle";at=getTimer();samples=lifted=held=glowing=thrown=0;
         localDone=peerDone=acted=opposed=observedRelease=false;lastHold=lastRelease=null;
         pauseRef=null;pausedSamples=pauseStill=0;menuClosed=false;
         releaseBefore=null;releaseCount=0;
         if(host && round>=11)mod.session.pause.setPolicy(round==11,false);
         var g:Object=mod.game.gg;
         if(g.teleObj!=null)g.dropTeleObj();
         g.maxmana=10000;g.mana=10000;g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;
         g.pers.telemaster=1;g.pers.unitLevitMult=round==3?1:100;
         g.pers.teleMult=1;g.pers.allDManaMult=1;g.pers.teleMana=0;
         g.pers.telePorog=0;
         g.pers.throwForce=12;g.pers.throwDmagic=2;g.pers.throwDmanaMult=0;g.pers.spellsPoss=1;
         if(host){target.levit=0;target.dx=target.dy=0;target.levit_r=0;target.t_throw=0;
            target.massa=round==6?1100:nativeMass;target.levit_max=round==3?18:nativeLimit;
            target.levitPoss=round!=7;target.setPos(baseX+110,baseY);target.disabled=false;}
         Log.d("ENEMY GRAB CASE "+CASES[round]+" "+(host?"host":"join"));
      }
      private function grab(expect:Boolean=true):void {
         var b:Object=mod.game,g:Object=b.gg;
         target.onCursor=1;b.loc.celObj=target;b.loc.celDist=0;
         if(round==4)g.mana=200;if(round==8)g.mana=199;
         EnemyGrabProbe.grab(g);
         check((g.teleObj===target)==expect,"native actTele "+(expect?"accepts":"rejects"));
         if(expect)check(target.levit==1,"native levitation starts");
         initialMana=g.mana;
      }
      private function holder():Boolean {return round==0 || round==9 ? host : !host;}
      private function observe(e:Event):void {if(phase=="holding" && target!=null && target.t_throw>0)++thrown;}
      private function drive(e:Event):void {
         if(phase=="done" || phase=="disconnected" || mod.game.gg==null)return;
         var b:Object=mod.game,g:Object=b.gg;player();
         g.celX=baseX+110;g.celY=baseY-160;b.loc.celDist=0;
         if(phase=="holding") {
            var elapsed:int=getTimer()-at;
            if(round==2 && !host && !acted && elapsed>1200) {
               acted=true;var mana:Number=g.mana;EnemyGrabProbe.launch(g);
               check(g.teleObj==null && target.t_throw==45,"native throw releases and arms collision");
               check(g.mana<mana,"native throw consumes mana");
            }
            if(round==5 && !host && !acted && elapsed>1200){acted=true;g.mana=0;}
            if((round==11 || round==12) && !host) {
               if(!acted && elapsed>900){acted=true;b.world.pip.onoff(5);}
               if(acted && !menuClosed && elapsed>2600){menuClosed=true;b.world.pip.onoff(-1);}
            }
            if((round==9 && !host || round==10 && host) && !opposed && elapsed>800){opposed=true;grab();}
            // Player is disabled solely to pin the caster. Exercise native mana,
            // acceleration and release once, not a replica of their calculations.
            if(g.teleObj!=null && b.world.allStat==1 && !b.world.onPause && !mod.session.pause.paused)g.actions();
         }
         mod.stage.invalidate();
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="unit-grip" && host){if(p.op=="hold")lastHold=JSON.parse(JSON.stringify(p));if(p.op=="release")lastRelease=JSON.parse(JSON.stringify(p));}
         if(p.type!="enemy-grab-test")return;
         try {
            if(host && phase=="boot" && p.stage=="ready") {
               baseX=mod.game.gg.X;baseY=mod.game.gg.Y;player();
               var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
               target=new c("1",10,<unit weap="lmg"/>,null);target.id="rconnect_grab_fixture";
               target.putLoc(mod.game.loc,baseX+110,baseY);mod.game.loc.addObj(target);mod.game.loc.units.push(target);
               target.invulner=true;target.doop=true;target.xp=0;nativeMass=target.massa;nativeLimit=target.levit_max;
               mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-6000);
               mod.stage.addEventListener(Event.ENTER_FRAME,observe,false,98000);
               phase="prepared";at=getTimer();send("setup",{x:baseX,y:baseY});
            } else if(!host && p.stage=="setup") {
               baseX=p.x;baseY=p.y;player();phase="find";at=getTimer();
               mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-6000);
               mod.stage.addEventListener(Event.ENTER_FRAME,observe,false,98000);
            } else if(host && p.stage=="prepared") {start(0);send("round",{round:0});}
            else if(!host && p.stage=="round")start(int(p.round));
            else if(p.stage=="sampled"){peerDone=true;if(host && localDone)releaseRound();}
            else if(!host && p.stage=="release")releaseRound();
            else if(p.stage=="released"){peerDone=true;if(host && localDone)advance();}
            else if(!host && p.stage=="replay") {
               if(p.hold!=null)mod.session.link.send(p.hold);
               if(p.release!=null)mod.session.link.send(p.release);
            }
            else if(!host && p.stage=="disconnect") {mod.session.leave();phase="disconnected";at=getTimer();}
            else if(p.stage=="done")finish();
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(host && mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(phase=="disconnected") {
               if(getTimer()-at>1600){check(target.levit==0,"disconnect releases enemy");check(mod.game.gg.teleObj==null,"disconnect clears caster");finish();}
               return;
            }
            if(phase!="done" && getTimer()-at>(phase=="boot"?90000:30000)){check(false,"timeout "+phase);send("done");finish();return;}
            if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning() || mod.game.gg==null)return;
            if(phase=="boot" && !host && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="find") {target=find();if(target!=null){phase="prepared";send("prepared");}}
            if(phase=="settle" && getTimer()-at>1400) {
               if(holder())grab(round<6 || round>8);
               phase="holding";at=getTimer();initialY=target.Y;minY=initialY;
            }
            if(phase=="holding") {
               ++samples;if(target.levit>0)++lifted;if(mod.game.gg.teleObj===target)++held;
               if(glow())++glowing;if(target.t_throw>0)++thrown;
               if(lifted>0 && target.levit==0)observedRelease=true;
               minY=Math.min(minY,target.Y);
               if(round==11 && getTimer()-at>1500 && getTimer()-at<2400) {
                  ++pausedSamples;
                  if(pauseRef==null)pauseRef={y:target.Y,mana:mod.game.gg.mana,resistance:target.levit_r};
                  if(mod.session.pause.paused && target.levit==1 && Math.abs(target.Y-pauseRef.y)<1
                     && mod.game.gg.mana==pauseRef.mana && target.levit_r==pauseRef.resistance)++pauseStill;
               }
               if(getTimer()-at>((round==11 || round==12)?4200:2600)) {
                  var transient:Boolean=round==2 || round==3 || round==5 || round==12,negative:Boolean=round>=6 && round<=8;
                  check(negative?lifted==0:transient?lifted>0:lifted>samples/2,"authority/mirror held state "+lifted+"/"+samples);
                  // Deliberately short holds end before a full lift. They must
                  // still move upward (the old bug stays at zero), then release.
                  if(!negative)check(minY<initialY-(transient?1:35),"enemy actually lifts rise="+(initialY-minY));
                  if(!negative && !transient)check(glowing>samples/2,"native glow remains during hold");
                  if(negative)check(mod.game.gg.teleObj==null,"native restriction never creates a hold");
                  if(round==2 && host)check(thrown>0 && lastRelease!=null && lastRelease.kick!=null,"native throw reaches authority");
                  if(round==3 || round==5)check(observedRelease && target.levit==0,"native resistance/mana ends hold");
                  if(round==9 || round==10)check((mod.game.gg.teleObj===target)==holder(),"first accepted caster retains ownership");
                  if(round==11) {
                     check(pausedSamples>3 && pauseStill==pausedSamples,"shared pause freezes held enemy, mana and resistance");
                     check(!mod.session.pause.paused && target.levit==1,"grip resumes after native menu closes");
                     check(pauseRef!=null && target.levit_r>pauseRef.resistance,"native resistance resumes after pause");
                     if(holder())check(pauseRef!=null && mod.game.gg.mana<pauseRef.mana,"native mana consumption resumes after pause");
                  }
                  if(round==12)check(target.levit==0 && mod.game.gg.teleObj==null,"local-only menu releases remote grip");
                  if(holder() && !negative && !transient)check(mod.game.gg.mana<initialMana,"native sustained mana consumed");
                  Log.d("ENEMY GRAB SAMPLE role="+(host?"host":"join")+" case="+CASES[round]+" levit="+lifted+" samples="+samples+" held="+held+" rise="+(initialY-minY));
                  phase="sampled";localDone=true;send("sampled");if(host && peerDone)releaseRound();
               }
            }
            if(phase=="released" && getTimer()-at>1400) {
               if(host && round==2)check(releaseCount==2,"duplicate throw message exercised over TCP");
               check(target.levit==0,"release stays released despite replay");
               check(!glow(),"release clears body glow");
               check(mod.game.gg.teleObj==null,"release clears local pointer");
               phase="release-sampled";localDone=true;send("released");if(host && peerDone)advance();
            }
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function releaseRound():void {
         localDone=peerDone=false;
         if(round==13) {
            if(host){send("disconnect");phase="disconnected";at=getTimer();}
            return;
         }
         if(host)send("release");
         if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();
         phase="released";at=getTimer();
         if(host && round==2){send("replay",{hold:lastHold,release:lastRelease});}
      }
      private function advance():void {if(round<CASES.length-1){start(round+1);send("round",{round:round});}else {send("done");finish();}}
      private function finish():void {
         phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.ENTER_FRAME,observe);try{if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();}catch(e:Error){}}
         Log.d("COOP EFFECTS DONE");
      }
   }
}
