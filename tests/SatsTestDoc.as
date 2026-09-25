package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
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
      private var enemy:Object,proxy:Object,gun:Object;
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"sats "+label);}
      public function SatsTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function watch(link:TcpLink):void {
         if(link!=null && !watched[link]){watched[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function send(stage:String):void {
         var msg:Object={type:"sats-test",stage:stage};
         if(host)mod.session.server.broadcast(msg);else mod.session.link.send(msg);
      }
      private function receive(e:NetMessageEvent):void {
         if(e.data.type!="sats-test")return;
         if(host && e.data.stage=="done"){check(true,"host receives completed native SATS scenario");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         Log.d("COOP EFFECTS DONE sats "+(host?"host":"join"));
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
               phase="wait";at=getTimer();
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
               // Native vision still decides selection. Prime the visible corridor,
               // exactly as the isolated rendering fixtures do after a room import.
               var tile:Object=mod.game.loc.getAbsTile(enemy.X,enemy.Y-enemy.scY/2);tile.visi=1;
               check(gun.status()<=1 && !gun.noSats,"native LMG permits SATS entry");
               Log.d("SATS fixture targetVis="+(enemy.vis!=null)+" proxyVis="+(proxy.vis!=null)+
                  " eligible="+g.isMeet(proxy)+" isSats="+proxy.isSats+" look="+g.look(proxy)+" tile="+proxy.getTileVisi());
               Log.d("SATS entry control="+g.ggControl+" pip="+w.pip.active+" pipOff="+g.pipOff+
                  " catPause="+w.catPause+" allStat="+w.allStat+" level="+gun.lvl+" skill="+g.pers.getWeapLevel(gun.skill));
               // The intro room disables player controls during its opening script.
               // Finish that isolated fixture gate before exercising World.step input.
               g.ggControl=true;g.pipOff=0;w.catPause=false;w.pip.onoff(-1);gun.lvl=0;
               w.ctr.keySats=true;phase="opening";at=getTimer();
            }
            else if(!host && phase=="opening" && getTimer()-at>350) {
               if(w.verror.visible) {
                  check(false,"native entry error: "+w.verror.txt.text);
                  w.verror.visible=false;
               } else {
                  check(w.sats.active,"native SATS opens without null-reference error");
                  var matches:int=0;
                  for each(var candidate:Object in w.sats.units)if(candidate.u===proxy){matches++;check(candidate.du.width>0,"mirrored enemy has a drawable SATS outline");}
                  check(matches==1,"mirrored enemy is selectable exactly once");
               }
               w.sats.onoff(-1);send("done");finish();
            }
            if(at>0 && getTimer()-at>20000){check(false,"scenario timeout "+phase);send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
   }
}
