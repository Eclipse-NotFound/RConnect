package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real WThrow ammo consumption -> native Mine -> TCP -> native enemy HP.
    * No production placement/damage method is called by the fixture. */
   public class MineSyncTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{host:true,id:"mine"},{host:false,id:"mine"},
         {host:false,id:"plamine"},{host:false,id:"x37"}];
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var baseX:Number,baseY:Number,gun:Object,oldGun:Object,oldChildren:Object,ammoBefore:int;
      private var mine:Object,enemy:Object,seen:Boolean=false,hp:Number,settledHp:Number;
      private var nativeBefore:Dictionary,placement:Object,statePacket:Object,detPacket:Object;
      private var frames:int=0,remoteFrames:int=0;
      private var watchedHp:Number=NaN;
      public function MineSyncTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"mine-sync "+s+" case="+round);}
      private function setPhase(s:String):void {phase=s;at=getTimer();}
      private function klass(s:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(s) as Class;}
      private function source():Boolean {return host==Boolean(CASES[round].host);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="mine-sync-test";p.stage=s;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function isMine(u:Object):Boolean {return u!=null&&getQualifiedClassName(u)=="fe.unit::Mine"&&u.fraction==100;}
      private function liveMines():Array {var a:Array=[];for each(var u:Object in mod.game.loc.units)if(isMine(u)&&u.sost<4&&u.id==CASES[round].id)a.push(u);return a;}
      private function prepare():void {
         var g:Object=mod.game.gg;g.disabled=true;g.invulner=true;g.dx=g.dy=0;
         mod.game.world.testDam=true;mod.config.setValue("followTeammate","0");
         g.setPos(baseX+(source()?0:260),baseY);mine=null;seen=false;placement=statePacket=detPacket=null;frames=remoteFrames=0;
         if(host) {
            // Keep the native explosion as the sole damage source. Random
            // room NPCs and blast-tossed furniture otherwise change HP during
            // the duplicate-packet window even when no second mine exists.
            for each(var resident:Object in mod.game.loc.units)
               if(resident!==g&&Number(resident.fraction)<100)resident.disabled=true;
            if(enemy!=null){mod.game.loc.remObj(enemy);enemy.remVisual();var z:int=mod.game.loc.units.indexOf(enemy);if(z>=0)mod.game.loc.units.splice(z,1);}
            var c:Class=klass("fe.unit.UnitZombie");enemy=new c("1",100,<unit tr="1" dig="0"/>,null);
            enemy.putLoc(mod.game.loc,baseX+650,baseY);mod.game.loc.units.push(enemy);enemy.addVisual();
            // Kept outside firstObj: stationary native damage receiver, not an
            // invulnerable/disabled enemy and not a test reimplementation.
            enemy.disabled=false;enemy.invulner=false;enemy.noBox=true;enemy.hp=enemy.maxhp=5000;enemy.skin=0;
            enemy.armor_qual=0;enemy.shithp=0;enemy.dexter=0;enemy.dodge=0;enemy.xp=0;
            for(var i:int=0;i<enemy.vulner.length;i++)enemy.vulner[i]=1;
            hp=enemy.hp;watchedHp=hp;
         }
         setPhase("prepared");
      }
      private function place():void {
         if(!source())return;var g:Object=mod.game.gg,c:Object=klass("fe.weapon.Weapon");
         oldGun=g.currentWeapon;oldChildren=g.childObjs;
         gun=c.create(g,String(CASES[round].id),0);gun.setPers(g,g.pers);gun.lvl=0;
         gun.addVisual();g.currentWeapon=gun;g.childObjs=[gun];g.celX=baseX+60;g.celY=baseY-20;gun.step();
         g.invent.items[gun.id].kol=10;ammoBefore=g.invent.items[gun.id].kol;
         nativeBefore=new Dictionary();for each(var u:Object in mod.game.loc.units)nativeBefore[u]=true;
         gun.t_attack=0;gun.attack(true);gun.step();
         for each(u in mod.game.loc.units)if(isMine(u)&&!nativeBefore[u])mine=u;
         check(mine!=null,"real WThrow creates friendly native Mine");
         check(g.invent.items[gun.id].kol==ammoBefore-1,"one native ammo consumed");
         if(mine==null){send("done");finish();return;}
         send("placed",{x:mine.X,y:mine.Y,damage:mine.damage1});setPhase("observe");
      }
      private function releaseGun():void {
         if(gun==null)return;gun.remVisual();mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;gun=null;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="player-mines") {
            if(p.op=="place")placement=p;
            if(p.op=="state")statePacket=p;
            if(p.op=="detonate")detPacket=p;
            return;
         }
         if(p.type!="mine-sync-test")return;
         if(p.stage=="done"){finish();return;}
         if(host&&p.stage=="ready"&&phase=="boot") {
            baseX=Number(p.x);baseY=Number(p.y);prepare();send("prepare",{x:baseX,y:baseY});
         } else if(!host&&p.stage=="prepare") {round=int(p.round);baseX=p.x;baseY=p.y;prepare();send("prepared");}
         else if(host&&p.stage=="prepared") {setPhase("wait-placement");send("place");place();}
         else if(!host&&p.stage=="place")place();
         else if(p.stage=="placed") {setPhase("observe");}
         else if(host&&p.stage=="visible") {
            check(p.visibleFrames>0,"joining endpoint renders planted mine frames="+p.visibleFrames);
            check(p.count==1,"joining endpoint has exactly one representation count="+p.count);
            var a:Array=liveMines();check(a.length==1,"authority owns exactly one live native mine count="+a.length);
            if(a.length==1){mine=a[0];enemy.setPos(mine.X+45,mine.Y);enemy.setVisPos();}
            check(a.length==1&&mine.in_chain&&!mine.disabled,"authority actually simulates planted mine");
            send("trigger");setPhase("damage");
         } else if(!host&&p.stage=="trigger") {
            if(CASES[round].id=="x37"&&gun!=null)check(gun.detonator(),"native radio detonator accepts input");
            setPhase("damage");
         } else if(p.stage=="replay") {
            // Deliberately resend a real packet: duplicates must not plant a
            // second mine or replay a finished explosion.
            if(!host&&p.placement!=null)mod.session.link.send(p.placement);
            if(!host&&p.detonate!=null)mod.session.link.send(p.detonate);
            if(!host&&statePacket!=null)send("replay-state",{saved:statePacket});
         } else if(host&&p.stage=="replay-state"&&p.saved!=null) {
            mod.session.server.broadcast(p.saved);
         } else if(!host&&p.stage=="settled") {
            check(liveMines().length==0,"exploded mine removed on joiner");releaseGun();send("next");setPhase("wait-next");
         } else if(host&&p.stage=="next") {
            check(Math.abs(enemy.hp-settledHp)<.001,"replayed placement cannot apply a second explosion before="+settledHp+" after="+enemy.hp);
            check(liveMines().length==0,"dead mine does not respawn after duplicate packet");releaseGun();
            round++;if(round>=CASES.length){send("done");finish();}else{prepare();send("prepare",{x:baseX,y:baseY});}
         }
      }
      private function render(e:Event):void {
         if(phase!="observe")return;frames++;
         for each(var u:Object in liveMines()) {
            var v:DisplayObject=u.vis as DisplayObject;
            if(v!=null&&v.visible&&v.alpha>0&&v.stage!=null){seen=true;remoteFrames++;}
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host&&mod.session.server!=null)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>65000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(host&&enemy!=null&&Number(enemy.hp)!=watchedHp) {
            Log.d("MINE HP TRACE "+JSON.stringify({round:round,phase:phase,before:watchedHp,hp:enemy.hp,
               at:getTimer(),sost:enemy.sost,chain:enemy.in_chain,disabled:enemy.disabled,live:liveMines().length}));
            watchedHp=Number(enemy.hp);
         }
         if(phase=="boot") {
            mod.game.gg.invulner=true;
            mod.stage.addEventListener(Event.RENDER,render,false,-40000);
            if(!host&&t.currentCount>180&&getTimer()-readyAt>500){readyAt=getTimer();send("ready",{x:mod.game.gg.X,y:mod.game.gg.Y});}
         }
         if(phase=="observe") {
            mod.stage.invalidate();
            if(getTimer()-at>3500) {
               check(seen&&remoteFrames>0,"planted mine visibly staged frames="+remoteFrames);
               if(!host){var running:int=0;for each(var u:Object in liveMines())if(u.in_chain&&!u.disabled)running++;
                  check(running==0,"joining replica cannot run contact AI or native explosions count="+running);
                  send("visible",{visibleFrames:remoteFrames,count:liveMines().length});setPhase("wait-trigger");}
               else setPhase("wait-visible");
            }
         }
         if(host&&phase=="damage"&&getTimer()-at>7000) {
            check(enemy.hp<hp,"native enemy receives mine explosion hpLoss="+(hp-enemy.hp));
            if(!CASES[round].host)check(placement!=null,"captured real placement packet for duplicate replay");
            settledHp=enemy.hp;send("replay",{placement:placement,detonate:detPacket});setPhase("settle");
         }
         if(host&&phase=="settle"&&getTimer()-at>2000){send("settled");setPhase("wait-next");}
      }
      private function finish():void {if(phase=="done")return;setPhase("done");t.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.RENDER,render);releaseGun();}
         Log.d("COOP EFFECTS DONE mine-sync "+(host?"host":"join"));}
   }
}
