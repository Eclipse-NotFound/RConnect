package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.PeerHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   /** Real MSW acquisition, native player attack and victim-owned friendly fire.
    * No lock assignment, guidance invocation or direct damage injection. */
   public class A22SmartPeerTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private const CASES:Array=["off","single","multi","off-again","host-shot","join-shot","revoke"];
      private var mod:RConnectMod,msw:Object,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,bx:Number,by:Number;
      private var gun:Object,oldGun:Object,oldChildren:Object,retired:Object;
      private var shots:Dictionary=new Dictionary(),guided:int=0,locks:int=0,fireIssued:Boolean=false,revokeSent:Boolean=false;
      private var hpBefore:Number,localDone:Boolean=false,peerDone:Boolean=false,ammoBefore:Number;
      public function A22SmartPeerTestDoc() {
         host=NativeApplication.nativeApplication.applicationID.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,e.error is Error?Error(e.error).getStackTrace():String(e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"smart-peer "+label+" case="+CASES[round]);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="a22-smart-test";p.op=op;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function proxy():Object {for each(var u:Object in mod.game.loc.units)if(u is PeerHitUnit)return u;return null;}
      private function shooter():Boolean {return round==4?host:!host;}
      private function enabled():Boolean {return round!=0&&round!=3;}
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-360;x+=40) {
            var clear:Boolean=true;
            for(var ix:int=0;ix<=340&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=180;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }if(clear){bx=x;by=y;return;}
         }throw new Error("No native smart-fire corridor");
      }
      private function setup():void {
         msw=LightningModAccess.instance(mod.main as MainFE);
         check(msw!=null&&msw.smart!=null,"loaded real MSW smart controller");
         if(msw==null)throw new Error("MSW unavailable");
         var g:Object=mod.game.gg;
         oldGun=g.currentWeapon;oldChildren=g.childObjs;
         var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         gun=factory.create(g,"lmg",0);gun.setPers(g,g.pers);g.currentWeapon=gun;g.childObjs=[gun];gun.addVisual();
         gun.precision=gun.deviation=gun.recoil=gun.recoilUp=0;gun.critCh=gun.dopCh=0;
         // Fresh isolated characters do not meet the LMG's normal level gate.
         // Like the existing native weapon fixtures, make this test weapon
         // level-neutral; retain native control, cooldown, ammunition and hit.
         gun.lvl=gun.perslvl=0;
         gun.skillConf=1;gun.damage=10;gun.destroy=0;gun.damageExpl=0;
         msw.cfg.smartEnabled=true;msw.cfg.smartExclusions={};
         mod.game.world.godMode=false;mod.game.world.testDam=true;
         mod.config.setValue("followTeammate","0");mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100005);
         mod.stage.addEventListener(Event.RENDER,sample,false,-35000);
      }
      private function start(n:int):void {
         round=n;phase="run";at=getTimer();localDone=peerDone=false;guided=locks=0;fireIssued=revokeSent=false;shots=new Dictionary();
         var g:Object=mod.game.gg;g.pers.healAll();g.maxhp=g.hp=10000;g.healhp=0;g.invulner=false;g.shithp=0;g.neujaz=0;
         g.skin=g.armor_qual=g.dexter=g.dexterPlus=g.dodge=0;g.currentArmor=null;g.allVulnerMult=1;
         hpBefore=g.hp;gun.hold=1000;ammoBefore=gun.hold;gun.hp=gun.maxhp;gun.t_reload=0;
         gun.speed=round==6?12:180;msw.cfg.smartMultiLock=round==2;
         if(host)mod.friendlyFire.setEnabled(enabled());
      }
      private function before(e:Event):void {
         if(phase=="done"||phase=="boot")return;
         var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();
         g.disabled=false;g.ggControl=true;g.dx=g.dy=0;g.stay=true;g.setPos(bx+(host?40:300),by);g.setVisPos();
         g.isTake=0;g.work="";b.loc.base=false;
         for each(var u:Object in b.loc.units)if(u!==g&&Number(u.fraction)<100){u.disabled=true;u.trigDis=true;}
         g.ctr.clearAll();g.storona=host?1:-1;
         b.world.celX=bx+(host?300:40);b.world.celY=by-g.scY/2;
         b.world.cam.celX=b.world.celX*b.world.cam.scaleV+b.world.cam.vx;
         b.world.cam.celY=b.world.celY*b.world.cam.scaleV+b.world.cam.vy;
         g.celX=b.world.celX;g.celY=b.world.celY;g.setWeaponPos(gun.tip);
         gun.findCel=false;gun.forceRot=Math.atan2(g.celY-g.weaponY,g.celX-g.weaponX);
         var elapsed:int=getTimer()-at;
         if(phase=="run"&&round>=4&&shooter()&&elapsed>2000&&elapsed<3000&&(round!=6||!fireIssued))g.ctr.keyAttack=true;
         mod.stage.invalidate();
      }
      private function sample(e:Event):void {
         if(phase!="run")return;
         var p:Object=proxy();
         if(p!=null) {
            retired=p;
            if(msw.smart.lock.target===p)locks++;
            for each(var lock:Object in msw.smart.multiLock.locks)if(lock.target===p)locks++;
         }
         for(var b:Object=mod.game.loc.firstObj;b!=null;b=b.nobj) {
            if(b==null||!("weap" in b)||b.weap!==gun||!("begx" in b))continue;
            if(!shots[b]){shots[b]=true;fireIssued=true;}
            var s:Object=msw.smart.snapshot(b);if(s!=null&&s.target is PeerHitUnit&&s.remaining>0)guided++;
         }
         if(round==6&&shooter()&&guided>0&&!revokeSent){revokeSent=true;send("revoke");}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="a22-smart-test")return;
         try {
            if(p.op=="done"){finish();return;}
            if(host&&p.op=="ready"&&phase=="boot"){arena();setup();start(0);send("setup",{x:bx,y:by});}
            else if(!host&&p.op=="setup"){bx=p.x;by=p.y;setup();start(0);}
            else if(!host&&p.op=="round")start(p.round);
            else if(host&&p.op=="revoke")mod.friendlyFire.setEnabled(false);
            else if(host&&p.op=="complete"){peerDone=true;advance();}
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}else{send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
         if(phase=="boot"&&mod.game.gg!=null)mod.game.gg.invulner=true;
         var list:Array=host?mod.session.server.clients:[mod.session.link];
         for each(var l:TcpLink in list)if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}
         if(phase=="done")return;
         if(phase!="boot"&&getTimer()-at>15000){check(false,"timeout");send("done");finish();return;}
         if(mod.game.gg==null||!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(String(mod.game.readWorldInfo().curLandId)!="rbl")return;
         if(phase=="boot"&&!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="run"&&getTimer()-at>5000) {
            try {
               var p:Object=proxy();
               if(round==0||round==3||round==6) {
                  check(!mod.friendlyFire.enabled&&p==null,"disabled policy removes the target");
                  check(!(msw.smart.lock.target is PeerHitUnit)&&msw.smart.multiLock.locks.length==0,"single and multiple locks are revoked");
                  if(retired!=null)check(!msw.smart.targetAllowed(retired,mod.game.world),"retired receiver stays ineligible");
               } else {
                  check(p!=null&&msw.smart.targetAllowed(p,mod.game.world),"live peer is eligible when host enables friendly fire");
                  check(locks>0,"real native frame acquires peer lock samples="+locks);
                  check(!msw.smart.targetAllowed(mod.game.gg,mod.game.world),"own player never becomes a target");
               }
               if(round==4||round==5) {
                  Log.d("A22 SMART FIRE "+JSON.stringify({shooter:shooter(),hold:gun.hold,before:ammoBefore,issued:fireIssued,
                     guided:guided,atkPoss:mod.game.gg.atkPoss,hp:mod.game.gg.hp,lvl:gun.lvl,ready:gun.ready}));
                  if(shooter())check(fireIssued&&gun.hold<ammoBefore&&guided>0,"native attack consumes ammo and receives guidance count="+guided);
                  else check(mod.game.gg.hp<hpBefore,"guided peer attack damages victim loss="+(hpBefore-mod.game.gg.hp));
               }
               if(round==6) {
                  if(shooter()) {
                     var stopped:Boolean=true,count:int=0;
                     for(var b:Object in shots){var s:Object=msw.smart.snapshot(b);if(s!=null){count++;if(s.remaining>0)stopped=false;}}
                     check(guided>0&&count>0&&stopped,"in-flight guidance ends after policy revocation");
                  } else check(mod.game.gg.hp==hpBefore,"revoked in-flight shot cannot deal friendly damage");
               }
               localDone=true;phase="waiting";if(host)advance();else send("complete");
            }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE smart-peer");
      }
   }
}
