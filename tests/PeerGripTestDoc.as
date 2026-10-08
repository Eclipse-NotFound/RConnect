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
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Both player-owned bodies, real native grab/action/physics and TCP. */
   public class PeerGripTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,ready:Boolean=false,localDone:Boolean=false,peerDone:Boolean=false;
      private var baseX:Number,baseY:Number,target:Object,startY:Number,minY:Number,initialMana:Number;
      private var held:int=0,samples:int=0,acted:Boolean=false,escapeAt:int=0,pauseAt:int=0,pausePos:Number=NaN;
      private var lifted:Boolean=false,peerLifted:Boolean=false,actionAt:int=0,peerPauseAt:int=0,peerPauseY:Number=NaN,pauseChecks:int=0;
      private var thrown:int=0;
      private static const CASES:Array=["denied","no-struggle","struggle","revoke","throw","pause"];
      public function PeerGripTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function caster():Boolean {return round<CASES.length?host:!host;}
      private function kind():String {return CASES[round%CASES.length];}
      private function check(v:Boolean,s:String):void {Log.d("COOP "+(v?"PASS ":"FAIL ")+"peer-grip "+s+" round="+round+" kind="+kind());}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("PEER GRIP PHASE "+(host?"host ":"join ")+s+" round="+round);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="peer-grip-test";p.op=op;if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function ghost():Object {return mod.game.getRemoteGhost(host?1:0);}
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-300;x+=40) {
            var clear:Boolean=true;for(var ix:int=0;ix<=280&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=200;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }if(clear){baseX=x;baseY=y;return;}
         }throw new Error("no native floored peer grip corridor");
      }
      private function install():void {
         check(mod.config.getValue("allowPeerGrip")=="0"&&mod.config.getValue("peerGripStruggle")=="1","safe personal defaults");
         mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();
         var l:Object=mod.game.loc;
         for each(var o:Object in l.objs.concat())if(o.X2>baseX-20&&o.X1<baseX+300&&o.Y2>baseY-210&&o.Y1<baseY+20) {
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);if(l.celObj===o)l.celObj=null;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-9500);
      }
      private function start(n:int):void {
         round=n;mod.peerGrip.reset();mod.game.forceCloseOverlays();
         var g:Object=mod.game.gg;
         g.t_throw=0;mod.game.world.ctr.keyAction=false;thrown=0;
         g.mana=g.maxmana=10000;g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;g.pers.telemaster=1;g.pers.spellsPoss=1;
         g.pers.telePorog=0;g.pers.throwForce=12;g.pers.throwDmanaMult=0;
         mod.peerGrip.setPreferences(!caster()&&kind()!="denied",kind()=="struggle");
         var saved:Config=new Config();check(saved.getValue("allowPeerGrip")==mod.config.getValue("allowPeerGrip")
            &&saved.getValue("peerGripStruggle")==mod.config.getValue("peerGripStruggle"),"personal choices persist in own storage");
         if(host)mod.session.pause.setPolicy(kind()=="pause",false);
         held=samples=0;acted=false;escapeAt=pauseAt=0;pausePos=NaN;localDone=peerDone=false;
         lifted=peerLifted=false;actionAt=peerPauseAt=pauseChecks=0;peerPauseY=NaN;
         startY=minY=baseY;change("settle");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="peer-grip-test")return;
         try {
            if(host&&p.op=="ready")ready=true;
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;install();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){start(0);send("round",{round:0});}
            else if(!host&&p.op=="round")start(p.round);
            else if(p.op=="lifted"){peerLifted=true;if(host&&lifted)beginAction();}
            else if(!host&&p.op=="action")actionAt=getTimer();
            else if(p.op=="paused-body"){peerPauseAt=getTimer();peerPauseY=p.y;}
            else if(p.op=="sampled"){peerDone=true;if(host&&localDone)releaseRound();}
            else if(!host&&p.op=="release")releaseRound();
            else if(p.op=="released"){peerDone=true;if(host&&localDone)advance();}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function before(e:Event):void {
         if(phase=="done")return;var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.invulner=true;g.transp=true;g.disabled=false;g.isTake=0;w.ctr.active=true;
         mod.game.loc.base=false;mod.game.loc.portOn=true;
         if(phase=="settle"||caster()){g.dx=g.dy=0;g.setPos(baseX+(caster()?0:100),baseY);g.setVisPos();}
         if(caster()) {
            var aimX:Number=phase=="settle"?baseX+100:baseX+150,aimY:Number=phase=="settle"?baseY-25:baseY-170;
            g.celX=w.celX=aimX;g.celY=w.celY=aimY;
            w.cam.celX=int(aimX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(aimY*w.cam.scaleV+w.cam.vy);
         }
         if(!caster()&&phase=="holding"&&(kind()=="no-struggle"||kind()=="struggle")&&actionAt>0&&getTimer()-actionAt>1100)w.ctr.keyLeft=true;
      }
      private function after(e:Event):void {
         if(phase!="holding")return;target=caster()?ghost():mod.game.gg;if(target==null)return;
         minY=Math.min(minY,target.Y);samples++;
         if(caster()?mod.game.gg.teleObj===target:target.levit==2)held++;
         if(!caster()&&target.t_throw>0)thrown++;
         if(kind()=="pause"&&mod.session.pause.paused) {
            if(isNaN(pausePos)){pausePos=target.Y;if(!caster())send("paused-body",{y:target.Y});}
            Log.d("PEER GRIP PAUSE "+JSON.stringify({round:round,caster:caster(),y:target.Y,ownY:mod.game.gg.Y,endpoint:peerPauseY,elapsed:getTimer()-peerPauseAt}));
            if(!caster()) {pauseChecks++;if(Math.abs(target.Y-pausePos)>1)check(false,"shared pause freezes actual owned player");}
            else if(peerPauseAt>0&&getTimer()-peerPauseAt>500) {pauseChecks++;if(Math.abs(target.Y-peerPauseY)>1)check(false,"remote hold settles at actual paused owner endpoint");}
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(phase=="done")return;if(getTimer()-at>(phase=="boot"?180000:90000)){check(false,"timeout "+phase);send("done");finish();return;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&ready){arena();install();send("setup",{x:baseX,y:baseY});change("setup");}else if(!host)send("ready");
            }
            var g:Object=mod.game.gg,elapsed:int=getTimer()-at;
            if(phase=="settle"&&elapsed>1600&&stable()&&ghost()!=null&&g.ggControl&&g.sost==1&&g.work!="res") {
               target=ghost();check(target.levitPoss==(caster()&&kind()!="denied"),"remote grab permission follows teammate choice");
               if(caster()) {
                  target.onCursor=1;mod.game.loc.celObj=target;mod.game.loc.celDist=0;
                  EnemyGrabProbe.grab(g);check((g.teleObj===target)==(kind()!="denied"),"native grab respects target permission");initialMana=g.mana;
               }change("holding");
            } else if(phase=="holding") {
               if(kind()!="denied"&&!lifted&&held>=3&&minY<baseY-20){lifted=true;send("lifted");if(host&&peerLifted)beginAction();}
               var actionElapsed:int=actionAt>0?getTimer()-actionAt:0;
               if(!acted&&actionElapsed>1100) {
                  acted=true;
                  if(!caster()&&kind()=="revoke")mod.peerGrip.setPreferences(false,false);
                  if(caster()&&kind()=="throw")mod.game.world.ctr.keyAction=true;
                  if(caster()&&kind()=="pause")mod.game.world.pip.onoff(5);
               }
               if(kind()=="pause"&&caster()&&actionElapsed>3100)mod.game.world.pip.onoff(-1);
               if(kind()=="denied"?elapsed>3200:actionElapsed>4300) {
                  if(kind()=="denied")check(held==0&&minY>=baseY-1,"disabled target is never moved or held");
                  else {check(held>=3,"real player actually held");check(minY<baseY-20,"native player actually lifted rise="+(baseY-minY));}
                  if(kind()=="struggle"||kind()=="revoke"||kind()=="throw")check(caster()?g.teleObj==null:g.levit!=2,"escape/revocation/throw releases both ends");
                  if(kind()=="throw"&&!caster())check(thrown>0,"native E throw reaches actual grabbed player");
                  if(kind()=="no-struggle")check(caster()?g.teleObj===ghost():g.levit==2,"WASD with struggle disabled keeps hold");
                  if(kind()=="pause")check(pauseChecks>0&&!isNaN(pausePos)&&!mod.session.pause.paused&&(caster()?g.teleObj===ghost():g.levit==2),"hold survives verified shared pause and resumes");
                  if(caster()&&kind()!="denied")check(g.mana<initialMana,"native caster mana charged");
                  Log.d("PEER GRIP SAMPLE "+JSON.stringify({round:round,caster:caster(),held:held,samples:samples,rise:baseY-minY}));
                  localDone=true;send("sampled");change("sampled");if(host&&peerDone)releaseRound();
               }
            } else if(phase=="released"&&elapsed>1200) {
               check(g.teleObj==null&&g.levit!=2,"native release leaves no player grip");
               mod.game.world.ctr.keyLeft=false;localDone=true;send("released");change("release-sampled");if(host&&peerDone)advance();
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function beginAction():void {actionAt=getTimer();send("action");}
      private function releaseRound():void {if(host)send("release");if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();mod.game.world.ctr.keyLeft=false;localDone=peerDone=false;change("released");}
      private function advance():void {if(round<CASES.length*2-1){start(round+1);send("round",{round:round});}else{send("done");finish();}}
      private function finish():void {if(phase=="done")return;change("done");timer.stop();if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.peerGrip.reset();}Log.d("COOP EFFECTS DONE peer-grip");}
   }
}
