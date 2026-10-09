package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
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

   /** Observe actual native visuals and the final remote display across TCP.
    * No production internals, simulated projectiles or hand-built wing state. */
   public class PeerVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{deg:0,body:1},{deg:160,body:1},{deg:-160,body:-1},
         {deg:85,body:-1},{deg:95,body:1},{deg:-95,body:1},{deg:180,body:-1},
         {deg:0,body:1,wing:1},{deg:0,body:-1,wing:2},{deg:0,body:1}];
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var gun:Object,oldGun:Object,oldChildren:Object,baseX:Number,baseY:Number;
      private var source:Array=[],remote:Array=[],bullet:Object,oldBullet:Object,shot:Boolean=false;
      private var localDone:Boolean=false,peerDone:Boolean=false,localNative:Array,peerNative:Array;
      private var wings:int=0,wingWrong:int=0,sourceWings:int=0,remoteClass:String="";
      private var sourceWingFrames:Object={},peerWingFrames:Object={};
      public function PeerVisualTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"peer-visual "+s+" case="+round);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="peer-visual-test";p.stage=s;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function setup():void {
         var g:Object=mod.game.gg;baseX=g.X;baseY=g.Y;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         Log.d("PEER VISUAL SETUP "+JSON.stringify({role:host?"host":"join",animOff:g.animOff,sost:g.sost,hp:g.hp,work:g.work,pose:g.vis.osn.currentLabel}));
         // rbl's opening script can leave the host in anim("die", true).
         // Release that native cinematic override before testing live wings.
         g.anim();check(g.animOff===false,"native animation released from opening script");
         var c:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         gun=c.create(g,"lmg",0);gun.setPers(g,g.pers);gun.addVisual();g.currentWeapon=gun;g.childObjs=[gun];
         gun.precision=0;gun.lvl=0;gun.perslvl=0;gun.recoilUp=0;gun.recoil=0;gun.hold=999;gun.deviation=0;
         check(gun.vis!=null&&gun.vis.stage!=null,"native LMG staged");
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function start(n:int):void {
         round=n;phase="show";at=getTimer();source=[];remote=[];localNative=peerNative=null;
         oldBullet=gun.b;bullet=null;shot=false;localDone=peerDone=false;wings=wingWrong=sourceWings=0;
         sourceWingFrames={};peerWingFrames={};
         // Use the native timed effect: pers.setParameters may replace a raw
         // ableFly assignment later in the same frame.
         mod.game.gg.remEffect("potion_fly");
         if(CASES[round].wing)mod.game.gg.addEffect("potion_fly",0,60,false);
      }
      private function before(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,a:Number=CASES[round].deg*Math.PI/180;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=CASES[round].body;g.invulner=true;g.disabled=true;
         // Exercise the real UnitPlayer.animate wing contract, including
         // acquired flying ability, airborne flapping and subsequent removal.
         g.isFly=int(CASES[round].wing)==2;
         g.stay=!g.isFly;g.isLaz=0;g.isPlav=false;
         g.celX=w.celX=baseX+Math.cos(a)*600;g.celY=w.celY=baseY-g.scY*.7+Math.sin(a)*600;
         var cam:Object=w.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
         if(!shot&&getTimer()-at>1000){gun.hold=999;gun.t_reload=0;gun.attack();shot=true;}
      }
      private function after(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         gun.step();mod.game.gg.animate();mod.game.world.testDam=true;
         if(gun.b!==oldBullet&&gun.b!=null){bullet=gun.b;oldBullet=bullet;remoteClass=getQualifiedClassName(bullet.vis);}
         mod.stage.invalidate();
      }
      private function point(v:DisplayObject):Object {
         if(v==null||!v.visible||v.stage==null)return null;
         return {x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,f:v is MovieClip?MovieClip(v).currentFrame:1};
      }
      private function wingVisible(u:Object):Boolean {
         var b:Object=GameBridge.probe(GameBridge.probe(GameBridge.probe(u,"vis"),"osn"),"body");
         return GameBridge.probe(GameBridge.probe(b,"lwing"),"visible")===true || GameBridge.probe(GameBridge.probe(b,"rwing"),"visible")===true;
      }
      private function render(e:Event):void {
         if(phase!="show")return;
         var ghost:Object=mod.game.getRemoteGhost(host?1:0);
         if(getTimer()-at>700&&ghost!=null){
            wings++;if(wingVisible(ghost)!=Boolean(CASES[round].wing))wingWrong++;if(wingVisible(mod.game.gg))sourceWings++;
            sourceWingFrames[mod.game.gg.vis.osn.body.rwing.currentFrame]=true;
            peerWingFrames[ghost.vis.osn.body.rwing.currentFrame]=true;
         }
         var p:Object=bullet==null?null:point(bullet.vis as DisplayObject);
         if(p!=null)source.push(p);
         // Exclude every real Bullet visual, not merely the latest weapon.b.
         var native:Dictionary=new Dictionary(true),o:Object=mod.game.loc.firstObj;
         for(var guard:int=0;o!=null&&guard++<5000;o=o.nobj)if(GameBridge.probe(o,"owner")!=null&&GameBridge.probe(o,"begx")!=null)native[o.vis]=true;
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i);
            if(!native[v]&&getQualifiedClassName(v)=="visualBullet") {p=point(v);if(p!=null)remote.push(p);}
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="peer-visual-test")return;
         if(host&&p.stage=="ready"&&phase=="boot"){setup();send("setup");start(0);}
         else if(!host&&p.stage=="setup"&&phase=="boot"){setup();start(0);}
         else if(p.stage=="round"&&!host)start(int(p.round));
         else if(p.stage=="native"&&int(p.round)==round){peerNative=p.frames;compare();}
         else if(p.stage=="result"&&host&&int(p.round)==round){peerDone=true;advance();}
         else if(p.stage=="done")finish();
      }
      private function compare():void {
         if(localNative==null||peerNative==null||localDone)return;
         check(wings>=12&&sourceWings==(CASES[round].wing?wings:0),"native wing contract samples="+wings+" visible="+sourceWings);
         check(wings>=12&&wingWrong==0,"peer preserves actual wing presence wrong="+wingWrong+"/"+wings);
         if(int(CASES[round].wing)==2){var sf:int=0,rf:int=0;for(var k:String in sourceWingFrames)sf++;for(k in peerWingFrames)rf++;
            check(sf>=3&&rf>=3,"real flying animation continues source="+sf+" peer="+rf);}
         check(localNative.length>0&&peerNative.length>0,"actual native bullet frames recorded "+localNative.length+"/"+peerNative.length);
         var wrong:int=0,maxError:Number=0;
         for each(var a:Object in remote) {
            var best:Number=1e9;
            for each(var b:Object in peerNative) {
               var angle:Number=Math.abs(a.r-b.r);angle=Math.min(angle,360-angle);
               best=Math.min(best,Math.max(Math.abs(a.x-b.x),Math.abs(a.y-b.y),angle,
                  Math.abs(a.sx-b.sx)*100,Math.abs(a.sy-b.sy)*100,Math.abs(a.f-b.f)*100));
            }
            maxError=Math.max(maxError,best);if(best>.05)wrong++;
         }
         check(remote.length>0,"remote tracer actually visible frames="+remote.length);
         check(remote.length>0&&wrong==0,"native trajectory/rotation/stretch/frame preserved wrong="+wrong+" max="+maxError);
         Log.d("PEER VISUAL METRIC "+JSON.stringify({role:host?"host":"join",round:round,degree:CASES[round].deg,wings:wings,wingWrong:wingWrong,
            source:source,peer:peerNative,remote:remote,wrong:wrong,maxError:maxError}));
         localDone=true;send("result",{round:round});advance();
      }
      private function advance():void {if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}else{send("done");finish();}}
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done"&&getTimer()-at>60000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&t.currentCount>160&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="show"&&getTimer()-at>3600){phase="sampled";localNative=source;send("native",{round:round,frames:source});compare();}
      }
      private function finish():void {if(phase=="done")return;phase="done";t.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            if(gun!=null)gun.remVisual();if(oldGun!=null){mod.game.gg.remEffect("potion_fly");mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}}
         Log.d("COOP EFFECTS DONE peer-visual "+(host?"host":"join"));}
   }
}
