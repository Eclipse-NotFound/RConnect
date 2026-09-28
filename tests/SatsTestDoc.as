package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Uses native World.step -> Sats.onoff -> getUnits through real input. */
   public class SatsTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),mod:RConnectMod,host:Boolean;
      private var watched:Dictionary=new Dictionary(),phase:String="boot",at:int=0;
      private var enemy:Object,proxy:Object,gun:Object,selected:Object;
      private var shotHp:Number=NaN,ammoBefore:Number,odBefore:Number;
      private var settledAt:int=0,authorityHp:Number=NaN;
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"sats "+label);}
      public function SatsTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function watch(link:TcpLink):void {
         if(link!=null && !watched[link]){watched[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function setPhase(value:String):void {phase=value;at=getTimer();}
      private function send(stage:String,data:Object=null):void {
         var msg:Object=data||{};msg.type="sats-test";msg.stage=stage;
         if(host)mod.session.server.broadcast(msg);else mod.session.link.send(msg);
      }
      private function receive(e:NetMessageEvent):void {
         if(!host && e.data.type=="unitsync")
            for each(var state:Object in e.data.units)if(state.id=="slaver2")authorityHp=Number(state.hp);
         if(e.data.type!="sats-test")return;
         if(e.data.stage=="done"){if(host)check(true,"host receives completed native SATS scenario");finish();return;}
         if(host) {
            if(e.data.stage=="shot"){shotHp=e.data.hp;setPhase("shot-settle");}
            else if(e.data.stage=="cloak"){enemy.isSats=true;enemy.invis=true;send("cloaked");setPhase("wait");}
            else if(e.data.stage=="reveal"){enemy.invis=false;send("revealed");setPhase("wait");}
         } else setPhase(e.data.stage);
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         Log.d("COOP EFFECTS DONE sats "+(host?"host":"join"));
      }
      private function targetEntry():Object {
         var found:Object=null,count:int=0;
         for each(var candidate:Object in mod.game.world.sats.units)if(candidate.u===proxy){found=candidate;count++;}
         if(count>1)throw new Error("duplicate native SATS targets for one mirrored body");
         return found;
      }
      private function reopen():Object {
         var s:Object=mod.game.world.sats;
         s.onoff(-1);mod.game.loc.getAbsTile(enemy.X,enemy.Y-enemy.scY/2).visi=1;
         s.onoff(1);return targetEntry();
      }
      private function inFlight():Boolean {
         var cur:Object=mod.game.loc.firstObj,seen:Dictionary=new Dictionary();
         while(cur!=null && !seen[cur]) {
            seen[cur]=true;
            if(getQualifiedClassName(cur).indexOf("Bullet")>=0 && cur.owner===mod.game.gg && !cur.babah && !cur.off)return true;
            cur=cur.nobj;
         }
         return false;
      }
      private function lifecycleChecks():void {
         var s:Object=mod.game.world.sats,body:Object=enemy.vis,bar:Object=enemy.hpbar,parent:Object=body.parent;
         try {
            enemy.vis=null;proxy.sync();reopen();
            check(s.active && targetEntry()==null,"temporarily absent body is excluded without a native SATS error");
            enemy.vis=new MovieClip();proxy.sync();reopen();
            check(targetEntry()==null,"empty body is excluded before native bitmap allocation");
            enemy.vis=body;proxy.sync();
            check(proxy.vis===body && proxy.hpbar===bar,"restored body and health bar references are refreshed");
         } finally {enemy.vis=body;proxy.sync();}
         selected=reopen();
         selected.du.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OVER,true));s.setCel();
         check(selected.n==1 && s.getReady(),"native hover queues a live bound target before authority handoff");
         // Exercise the same production cleanup called by RoomSync grants.
         mod.game.roomRole(true);
         check(mod.game.loc.units.indexOf(proxy)<0 && proxy.sost==4 && !proxy.isSats,"authority handoff retires the old collision receiver");
         check(!s.getReady(),"unstarted native SATS order skips a retired target");
         check(body.parent===parent && enemy.vis===body,"receiver cleanup preserves the real enemy visual");
         var before:Number=enemy.hp;proxy.sync();proxy.dispose();proxy.damage(10,100);
         check(proxy.vis==null && proxy.hpbar==null && enemy.hp==before,"retired receiver cannot revive or apply stale damage");
         s.clearAll();s.onoff(-1);
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null)return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         try {
            if(host && phase=="boot") {
               var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitSlaver") as Class;
               enemy=new c("slaver2",100,<unit tr="2"/>,null);
               enemy.putLoc(mod.game.loc,g.X+90,g.Y);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
               enemy.disabled=true;enemy.doop=true;enemy.xp=0;enemy.hp=enemy.maxhp=2000;
               enemy.isSats=true;enemy.invis=false;enemy.animate();
               check(enemy.vis!=null && !mod.game.loc.base,"host creates visible enemy in native combat room");
               setPhase("wait");
            }
            if(!host && phase=="boot") {
               for each(var u:Object in mod.game.loc.units) {
                  if(u.id=="slaver2")enemy=u;
                  if(u.id=="rconnect_hit_slaver2")proxy=u;
               }
               if(enemy==null || proxy==null)return;
               g.invulner=true;g.storona=1;
               gun=new NativeTestGun(g as Unit);gun.hold=90;gun.loc=mod.game.loc;
               gun.X=g.X;gun.Y=g.Y-g.scY/2;g.currentWeapon=gun;
               // Install the fixture weapon in the native player step chain so
               // SATS fires through UnitPlayer.actions -> Weapon.step -> Bullet.
               g.childObjs[0]=gun;gun.addVisual();gun.setPers(g,g.pers);
               gun.lvl=0;gun.precision=0;gun.deviation=0;w.testDam=true;
               // Native vision still decides selection. Prime the visible corridor,
               // exactly as the isolated rendering fixtures do after a room import.
               var tile:Object=mod.game.loc.getAbsTile(enemy.X,enemy.Y-enemy.scY/2);tile.visi=1;
               check(gun.status()<=1 && !gun.noSats,"native LMG permits SATS entry");
               // The isolated new character must meet the native input gates.
               g.ggControl=true;g.pipOff=0;w.catPause=false;w.pip.onoff(-1);gun.lvl=0;
               w.ctr.keySats=true;setPhase("opening");
            }
            else if(!host && phase=="opening" && getTimer()-at>350) {
               if(w.verror.visible) {
                  check(false,"native entry error: "+w.verror.txt.text);
                  w.verror.visible=false;
                  send("done");finish();return;
               }
               check(w.sats.active,"native World.step SATS entry opens without null-reference error");
               selected=targetEntry();
               check(selected!=null && selected.du.width>0,"mirrored enemy has exactly one drawable SATS target");
               check(selected.v.getChildAt(1).txt.text.indexOf(enemy.nazv)==0 && proxy.level==enemy.level,"SATS shows the real enemy name and level");
               check(proxy.vis===enemy.vis && proxy.hpbar===enemy.hpbar && proxy.armor_maxhp==enemy.armor_maxhp,"receiver uses matching body and health-bar data");
               var repeated:Boolean=true;
               for(var repeat:int=0;repeat<25;repeat++)if(reopen()==null)repeated=false;
               check(repeated,"25 native close/reopen cycles retain a selectable enemy");
               selected=targetEntry();selected.du.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OVER,true));
               ammoBefore=gun.hold;odBefore=w.sats.od;w.ctr.keyAttack=true;setPhase("queue");
            }
            else if(!host && phase=="queue" && getTimer()-at>350) {
               check(w.sats.que.length==1 && selected.n==1,"native hover and attack input queue an enemy rather than a coordinate");
               check(w.sats.odv<w.sats.od,"native target selection reserves action points");
               w.ctr.keyAction=true;setPhase("shooting");
            }
            else if(!host && phase=="shooting" && w.sats.que.length==0 && getTimer()-at>1500) {
               // A cleared SATS order does not imply its last bullet has arrived,
               // or that the authority has echoed that hit. Observe the real
               // projectile chain and keep the exact final-HP assertion below.
               if(inFlight() || !isFinite(authorityHp) || Math.abs(enemy.hp-authorityHp)>0.01){settledAt=0;return;}
               if(settledAt==0){settledAt=getTimer();Log.d("SATS settling local="+enemy.hp+" authority="+authorityHp+" ammo="+gun.hold);return;}
               if(getTimer()-settledAt<1200)return;
               check(gun.hold<ammoBefore && w.sats.od<odBefore,"native SATS volley consumes ammunition and action points");
               check(enemy.hp<2000,"native SATS volley damages the mirrored enemy");
               Log.d("SATS volley join hp="+enemy.hp+" ammo="+gun.hold+" ap="+w.sats.od);
               send("shot",{hp:enemy.hp});setPhase("wait");
            }
            else if(host && phase=="shot-settle" && getTimer()-at>1200) {
               check(enemy.hp<2000 && Math.abs(enemy.hp-shotHp)<0.01,"SATS damage reaches the host once and converges over TCP");
               Log.d("SATS volley host hp="+enemy.hp);
               enemy.isSats=false;send("disabled");setPhase("wait");
            }
            else if(!host && phase=="disabled" && !enemy.isSats && !proxy.isSats) {
               reopen();check(targetEntry()==null,"host SATS-ineligible flag excludes the mirrored target");
               w.sats.onoff(-1);send("cloak");setPhase("wait");
            }
            else if(!host && phase=="cloaked" && enemy.invis && proxy.invis && proxy.isSats) {
               reopen();check(targetEntry()==null,"host invisibility excludes the mirrored target");
               w.sats.onoff(-1);send("reveal");setPhase("wait");
            }
            else if(!host && phase=="revealed" && !enemy.invis && !proxy.invis && proxy.isSats) {
               check(reopen()!=null,"revealed enemy becomes selectable again");
               lifecycleChecks();send("done");finish();
            }
            if(at>0 && getTimer()-at>30000){check(false,"scenario timeout "+phase);send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
   }
}
