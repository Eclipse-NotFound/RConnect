package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import fe.unit.CombatStateProbe;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   public class ProjectileNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(150),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,ali:Object,oldGun:Object,oldChildren:Object,gun:NativeTestGun;
      private var nativeClass:String="",visibleFrames:int=0,shotFrames:int=0,shieldFrames:int=0,peak:int=0;
      private var playerChecked:Boolean=false,peerPlayerResult:Object;
      public function ProjectileNetworkTestDoc(){var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;t.addEventListener(TimerEvent.TIMER,tick);t.start();addEventListener(Event.ENTER_FRAME,frame);}
      private function check(b:Boolean,s:String):void{Log.d("COOP "+(b?"PASS ":"FAIL ")+"projectile-network "+s);}
      private function setPhase(s:String):void{phase=s;at=getTimer();visibleFrames=shotFrames=shieldFrames=peak=0;}
      private function send(s:String,p:Object=null):void{p=p||{};p.type="projectile-test";p.phase=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void{if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function findAli():Object{for each(var u:Object in mod.game.loc.units)if(u is Unit && getQualifiedClassName(u)=="fe.unit::UnitAlicorn")return u;return null;}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="projectile-test")return;
         if(p.phase=="ready"&&host){setupAli();send("enemy");setPhase("enemy");}
         else if(p.phase=="enemy"&&!host)setPhase("enemy");
         else if(p.phase=="enemy-result"&&host){check(p.visible>0 && p.peak>0,"alicorn lightning renders actual pixels across TCP frames="+p.visible);check(p.shield>0,"alicorn shield is visible on join");ali.shithp=0;send("shield-off");setPhase("wait");}
         else if(p.phase=="shield-off"&&!host)setPhase("shield-off");
         else if(p.phase=="players"&&host){setupPlayer();send("players");setPhase("players");}
         else if(p.phase=="players"&&!host){setupPlayer();setPhase("players");}
         else if(p.phase=="player-result"&&host){peerPlayerResult=p;finishPlayers();}
         else if(p.phase=="done")finish();
      }
      private function setupAli():void{var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitAlicorn") as Class;ali=new c("1",100,<unit tr="1"/>,null);
         ali.putLoc(mod.game.loc,mod.game.gg.X+160,mod.game.gg.Y);mod.game.loc.addObj(ali);mod.game.loc.units.push(ali);ali.disabled=true;ali.shithp=300;ali.xp=0;
         gun=new NativeTestGun(ali as Unit,"alilight");ali.currentWeapon=gun;ali.childObjs=[gun];mod.game.readUnitsSnapshot();}
      private function setupPlayer():void{oldGun=mod.game.gg.currentWeapon;oldChildren=mod.game.gg.childObjs;gun=new NativeTestGun(mod.game.gg as Unit);var w:Object=gun;w.setPers(mod.game.gg,mod.game.gg.pers);mod.game.gg.currentWeapon=gun;mod.game.gg.childObjs=[gun];mod.game.readSnapshot();}
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(t.currentCount<130)return;
         try {
            mod.game.gg.invulner=true;mod.game.gg.disabled=true;mod.game.world.testDam=true;
            if(phase=="boot"){if(!host)send("ready");setPhase("wait");}
            if(phase=="enemy"&&host){var b:Object=gun.fireAt(mod.game.gg,true);nativeClass=getQualifiedClassName(b.vis);}
            if(phase=="enemy"&&!host&&getTimer()-at>5500){send("enemy-result",{visible:visibleFrames,peak:peak,shield:shieldFrames});setPhase("wait");}
            if(phase=="shield-off"&&!host&&getTimer()-at>1000){ali=findAli();check(ali!=null&&!CombatStateProbe.shield(ali as Unit).visible,"depleted alicorn shield disappears");send("players");setPhase("wait");}
            if(phase=="players") {
               gun.fireAt({loc:mod.game.loc,X:mod.game.gg.X+90,Y:mod.game.gg.Y,scY:mod.game.gg.scY},true);
               if(getTimer()-at>5500&&!playerChecked){
                  check(visibleFrames>0 && peak>0,(host?"join":"host")+" player's cosmetic projectile has visible pixels frames="+visibleFrames);
                  check(shotFrames>0,"remote player's gun plays shoot animation frames="+shotFrames);
                  playerChecked=true;
                  if(!host){send("player-result",{visible:visibleFrames,peak:peak,shots:shotFrames});setPhase("wait");}
                  else finishPlayers();
               }
            }
            if(phase!="done"&&getTimer()-at>20000){check(false,"timeout "+phase);send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finishPlayers():void {
         if(!host || !playerChecked || peerPlayerResult==null)return;
         check(peerPlayerResult.visible>0&&peerPlayerResult.peak>0,"host player projectile pixels reach join");
         check(peerPlayerResult.shots>0,"host muzzle animation reaches join");
         send("done");finish();
      }
      private function pixels(v:DisplayObject):int {
         if(v==null||!v.visible||v.stage==null)return 0;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1||r.height<1||r.width*r.height>500000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone(),m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);
         a.draw(root,m);v.visible=false;b.draw(root,m);v.visible=true;var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),n:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;a.dispose();b.dispose();return n;
      }
      private function frame(e:Event):void {
         if(mod==null || (phase!="players" && !(phase=="enemy"&&!host)))return;
         peak=Math.max(peak,mod.game.projectileVisualCount);
         if(mod.game.projectileVisualCount>0){var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
            for(var i:int=0;i<layer.numChildren;i++){var v:DisplayObject=layer.getChildAt(i);var cls:String=getQualifiedClassName(v);
               if((cls.toLowerCase().indexOf("bullet")>=0||cls.toLowerCase().indexOf("lightning")>=0||cls.toLowerCase().indexOf("laser")>=0) && pixels(v)>0){visibleFrames++;break;}}
         }
         if(phase=="enemy"){ali=findAli();if(ali!=null&&CombatStateProbe.shield(ali as Unit).visible)shieldFrames++;}
         else {var ghost:Object=mod.game.getRemoteGhost(host?1:0);if(ghost!=null&&ghost.currentWeapon!=null&&ghost.currentWeapon.vis!=null&&ghost.currentWeapon.vis.currentLabel=="shoot")shotFrames++;}
      }
      private function finish():void{if(phase=="done")return;if(oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}if(host&&ali!=null){mod.game.loc.remObj(ali);var i:int=mod.game.loc.units.indexOf(ali);if(i>=0)mod.game.loc.units.splice(i,1);}setPhase("done");t.stop();Log.d("COOP EFFECTS DONE projectile-network "+(host?"host":"join"));}
   }
}
