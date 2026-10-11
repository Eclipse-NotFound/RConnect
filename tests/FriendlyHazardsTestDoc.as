package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Mine;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real WThrow placement, native mine sensors/Interact.act, and installed
    * MSW weapon callbacks. Each direction includes protected/allowed cases. */
   public class FriendlyHazardsTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=["mine-off","mine-trigger","mine-disarm","laser-off","laser","pointer"];
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,remoteReady:Boolean=false,localReady:Boolean=false;
      private var started:Boolean=false,doneLocal:Boolean=false,doneRemote:Boolean=false,installed:Boolean=false;
      private var baseX:Number,baseY:Number,mineX:Number,mineY:Number,approach:Boolean=false;
      private var mine:Object,wp:Object,msw:Object,geometry:Object,oldWeapon:Object,oldChildren:Array;
      private var startHp:Number=0,lootBefore:int=0,sawBlind:Boolean=false,sawNumber:Boolean=false,numberValue:Number=0;
      private var oldNumbers:Dictionary=new Dictionary(true),blocked:Boolean=false,lastReady:int=0;
      private var lightStopped:Boolean=false,controlRetained:Boolean=true;
      private var badDuration:Boolean=false;
      public function FriendlyHazardsTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function kind():String {return CASES[round%CASES.length];}
      private function source():Boolean {return round<CASES.length?host:!host;}
      private function enabled():Boolean {return kind()!="mine-off"&&kind()!="laser-off";}
      private function optical():Boolean {return kind().indexOf("mine")!=0;}
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"friendly-hazards "+s+" round="+round+" kind="+kind());}
      private function change(s:String):void {phase=s;at=getTimer();}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="friendly-hazards-test";p.op=op;
         p.room=mod.game.roomKey();p.epoch=mod.game.roomEpoch;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function arena():void {
         var loc:Object=mod.game.loc;
         for(var y:int=240;y<loc.limY-40;y+=40)for(var x:int=80;x<loc.limX-480;x+=40) {
            var clear:Boolean=true;
            for(var dx:int=0;dx<=460&&clear;dx+=20) {
               if(loc.getAbsTile(x+dx,y+1).phis!=1){clear=false;break;}
               for(var dy:int=20;dy<=180;dy+=20)if(loc.getAbsTile(x+dx,y-dy).phis!=0){clear=false;break;}
            }if(clear){baseX=x;baseY=y;return;}
         }throw new Error("no native hazards corridor");
      }
      private function install():void {
         installed=true;mod.game.forceCloseOverlays();mod.config.setValue("followTeammate","0");
         mod.game.world.godMode=false;mod.game.world.testDam=true;mod.game.world.showHit=1;
         for each(var obj:Object in mod.game.loc.objs.concat())if(obj.X2>baseX-30&&obj.X1<baseX+480&&obj.Y2>baseY-180&&obj.Y1<baseY+30) {
            mod.game.loc.remObj(obj);mod.game.loc.objs.splice(mod.game.loc.objs.indexOf(obj),1);
         }
         var ad:Object=RConnectModDomains.find(mod.main,"MoreSkillsWeaponsMod");
         check(ad!=null&&ad.hasDefinition("MSWLaserGeometry"),"installed MSW available through its native loader");
         if(ad==null)throw new Error("MSW sibling domain missing");
         msw=ad.getDefinition("MoreSkillsWeaponsMod").testInstance();geometry=ad.getDefinition("MSWLaserGeometry");
         if(msw==null)throw new Error("MSW isolated test instance missing");
         msw.cfg.laserEnabled=msw.cfg.pointerEnabled=true;msw.cfg.laserAssist=false;
         msw.cfg.laserDuration=msw.cfg.pointerDuration=.8;msw.cfg.laserNonFront=false;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
      }
      private function liveMines():Array {
         var out:Array=[];for each(var u:Object in mod.game.loc.units)if(u is Mine&&u.fraction==100&&u.id=="mine"&&u.sost<4)out.push(u);return out;
      }
      private function lootCount():int {
         var count:int=0;for each(var item:Object in mod.game.readLootSync())if(item.id=="mine")count++;return count;
      }
      private function restoreWeapon():void {
         if(wp!=null)wp.remVisual();wp=null;
         if(oldWeapon!=null){mod.game.gg.currentWeapon=oldWeapon;mod.game.gg.childObjs=oldChildren;oldWeapon=oldChildren=null;}
      }
      private function start(n:int):void {
         restoreWeapon();round=n;localReady=remoteReady=started=doneLocal=doneRemote=false;
         approach=blocked=sawBlind=sawNumber=lightStopped=badDuration=false;numberValue=0;controlRetained=true;
         mine=null;mineX=mineY=0;
         var g:Object=mod.game.gg;
         g.remEffect("blindness");g.pers.inMaxHP=1000000;g.pers.begHP=10000;g.pers.healAll();g.hp=g.maxhp=10000;
         g.currentArmor=null;g.skin=g.marmor=g.armor_qual=0;g.allVulnerMult=1;g.shithp=0;g.healhp=0;g.rad=0;
         g.invulner=g.disabled=false;g.dexter=g.dexterPlus=g.dodge=g.neujaz=0;
         for(var i:int=0;i<g.vulner.length;i++)g.vulner[i]=1;
         for each(var u:Object in liveMines())if(mod.session.rooms.authority){u.sost=4;u.disabled=true;u.lootIsDrop=false;u.remVisual();mod.game.loc.remObj(u);}
         if(host)mod.friendlyFire.setEnabled(enabled());
         oldNumbers=new Dictionary(true);scanNumbers(true);startHp=g.hp;lootBefore=lootCount();change("settle");
      }
      private function before(e:Event):void {
         if(!installed||phase=="done"||mod.game.gg==null)return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.setPos(!optical()&&approach?source()?baseX+440:mineX+(kind()=="mine-disarm"?170:45):baseX+(source()?40:340),
            !optical()&&!source()&&approach?mineY:baseY);
         g.dx=g.dy=0;g.stay=true;g.storona=source()?1:-1;g.eyeX=g.X;g.eyeY=g.Y-30;g.setVisPos();
         w.ctr.keyLeft=w.ctr.keyRight=w.ctr.keyBeUp=w.ctr.keySit=w.ctr.keyJump=false;
         w.ctr.keyAttack=false;
         for each(var u:Object in mod.game.loc.units)if(u!==g&&Number(u.fraction)<100)u.disabled=true;
         if(source()&&wp!=null&&optical()) {
            var target:Object=mod.game.getRemoteGhost(host?1:0);
            if(target!=null){var eye:Object=geometry.eye(target);g.celX=w.celX=eye.x;g.celY=w.celY=eye.y;}
         }
         if(phase=="observe") {
            for each(var eff:Object in g.effects)if(eff.id=="blindness"&&!eff.vse&&eff.t>0){sawBlind=true;checkDuration(eff);}
            controlRetained=controlRetained&&!g.disabled&&g.ggControl;
            if(source())scanNumbers(false);
         }
      }
      private function checkDuration(effect:Object):void {
         if(effect.t>30&&!badDuration){badDuration=true;check(false,"MSW configured duration applied to player t="+effect.t);}
      }
      private function scanNumbers(baseline:Boolean):void {
         for(var obj:Object=mod.game.loc.firstObj,guard:int=0;obj!=null&&guard++<4096;obj=obj.nobj) {
            var vis:Object=obj.vis;if(vis==null||!("numb" in vis)||vis.numb==null||oldNumbers[obj])continue;
            oldNumbers[obj]=true;if(!baseline&&/^\d+$/.test(String(vis.numb.text))) {sawNumber=true;numberValue=Number(vis.numb.text);}
         }
      }
      private function equip(id:String):void {
         var g:Object=mod.game.gg;oldWeapon=g.currentWeapon;oldChildren=g.childObjs;
         var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         wp=id=="mine"?factory.create(g,id,0):g.invent.weapons[id];
         if(wp==null)throw new Error("missing installed weapon "+id);
         wp.setPers(g,g.pers);wp.addVisual();g.currentWeapon=wp;g.childObjs=[wp];wp.t_attack=wp.t_prep=wp.t_reload=0;
         if(id=="mine"){wp.lvl=0;g.invent.items.mine.kol=10;}
         else {g.invent.items.batt.kol=10000;wp.hold=wp.holder;}
      }
      private function act():void {
         if(source()) {
            equip(optical()?kind()=="pointer"?"mswlaserpointer":"mswdazzler":"mine");
            if(!optical()) {
               wp.step();var ammo:int=mod.game.gg.invent.items.mine.kol;wp.attack(true);wp.step();
               check(mod.game.gg.invent.items.mine.kol==ammo-1,"real WThrow consumes one mine");
               var all:Array=liveMines();check(all.length==1,"real planted Mine exists");
               if(all.length==0)throw new Error("WThrow placement failed");mine=all[0];mineX=mine.X;mineY=mine.Y;
               send("placed",{x:mineX,y:mineY});restoreWeapon();change("arm");
            }else change("equip");
         }else change(optical()?"observe":"arm");
      }
      private function fire():void {
         var g:Object=mod.game.gg;wp.step();wp.getBulXY();
         var target:Object=mod.game.getRemoteGhost(host?1:0),eye:Object=geometry.eye(target);
         g.celX=mod.game.world.celX=eye.x;g.celY=mod.game.world.celY=eye.y;
         if(kind()=="pointer") {mod.game.world.ctr.keyAttack=true;wp.attack(false);check(msw.pointer.lit,"real MSW press lights pointer");}
         else {var ammo:Number=wp.hold;wp.attack(true);wp.step();check(wp.hold<ammo,"real installed MSW dazzler fires and pays battery");}
         send("fired");change("observe");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="friendly-hazards-test")return;
         if(p.op=="done"){finish();return;}
         try {
            if(host&&p.op=="ready"&&phase=="boot"&&p.room==mod.game.roomKey()&&p.epoch==mod.game.roomEpoch) {
               arena();install();send("setup",{x:baseX,y:baseY});change("setup");
            }else if(!host&&p.op=="setup") {baseX=p.x;baseY=p.y;install();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){start(0);send("round",{round:0});}
            else if(!host&&p.op=="round")start(p.round);
            else if(host&&p.op=="case-ready"){remoteReady=true;begin();}
            else if(!host&&p.op=="act")act();
            else if(p.op=="placed"){mineX=p.x;mineY=p.y;change("arm");}
            else if(p.op=="approach"){approach=true;change("observe");}
            else if(p.op=="fired")change("observe");
            else if(p.op=="sampled") {
               if(source()&&kind()=="mine-trigger")check(sawNumber&&numberValue==Math.round(Number(p.loss)),"placer sees the teammate's settled mine damage");
               doneRemote=true;if(host&&doneLocal)advance();
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function begin():void {if(host&&localReady&&remoteReady&&!started){started=true;send("act");act();}}
      private function advance():void {if(round<CASES.length*2-1){start(round+1);send("round",{round:round});}else {send("done");finish();}}
      private function sample():void {
         var g:Object=mod.game.gg,loss:Number=startHp-g.hp;
         if(!optical()) {
            if(source())check(loss==0,"placing player outside the blast remains unharmed");
            else if(kind()=="mine-off") {
               check(loss==0&&liveMines().length==1,"disabled friendly fire prevents teammate sensor/damage");
               if(liveMines().length==1)check(!liveMines()[0].inter.active,"disabled friendly fire keeps teammate disarming unavailable");
            }else if(kind()=="mine-trigger")check(loss>0&&liveMines().length==0,"other player's real mine sensor detonates and damages victim once loss="+loss);
            if(kind()=="mine-disarm") {check(liveMines().length==0,"other player's native disarming removes mine on both endpoints");
               check(lootCount()==lootBefore+1,"native disarming produces exactly one synchronized ground mine");}
         }else {
            check(loss==0,"nonlethal optical attack never deals HP damage");
            if(!source())check(sawBlind==enabled(),"native blindness follows friendly policy");
            check(controlRetained,"affected player retains native control");
         }
         doneLocal=true;send("sampled",{loss:loss});change("sampled");if(host&&doneRemote)advance();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>80000){check(false,"timeout "+phase);send("done");finish();return;}
         try {
            if(phase=="boot") {if(!TestRoomReadiness.ready(mod,host))return;
               if(!host&&getTimer()-lastReady>1000){lastReady=getTimer();send("ready");}return;}
            if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
            var elapsed:int=getTimer()-at;
            if(phase=="settle"&&elapsed>1500&&mod.friendlyFire.enabled==enabled()&&mod.game.gg.work==""&&mod.game.gg.t_work==0) {
               if(!localReady){localReady=true;if(host)begin();else send("case-ready");}
            }else if(phase=="equip"&&elapsed>1000)fire();
            else if(phase=="arm"&&host) {
               var all:Array=liveMines();
               if(all.length==1&&all[0].reloadTime==0&&elapsed>1000) {
                  mine=all[0];mineX=mine.X;mineY=mine.Y;approach=true;send("approach");change("observe");
               }
            }else if(phase=="observe") {
               if(kind()=="mine-disarm"&&!source()&&!blocked) {
                  all=liveMines();if(all.length==1&&all[0].inter.active) {
                     all[0].inter.unlock=100;all[0].inter.needSkill=null;all[0].inter.mine=1;
                     all[0].inter.act();blocked=true;check(true,"native Interact.act runs successful disarming");
                  }
               }
               if(kind()=="pointer"&&source()&&elapsed>1700&&!lightStopped){msw.pointer.stop();lightStopped=true;}
               if(elapsed>(optical()?3200:11000))sample();
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function finish():void {if(phase=="done")return;change("done");t.stop();
         if(mod!=null)mod.stage.removeEventListener(Event.ENTER_FRAME,before);
         Log.d("COOP EFFECTS DONE friendly-hazards "+(host?"host":"join"));}
   }
}
