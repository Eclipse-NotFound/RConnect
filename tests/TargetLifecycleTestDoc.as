package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Point;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import fe.unit.EnemyGrabProbe;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Native SATS raster and native grab/release/retarget over the installed
    * production SWF. Never clears the native cursor or moves a receiving unit. */
   public class TargetLifecycleTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),ready:Boolean=false;
      private var baseX:Number,baseY:Number,a:Object,b:Object,aim:Object,marker:Sprite;
      private var endpoint:Number=NaN,walk:Boolean=false,walkFrames:int=0;
      private var walkReady:Boolean=false;
      private var selected:Object,selectedVisual:Object,queue:Object;
      public function TargetLifecycleTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(v:Boolean,s:String):void {Log.d("COOP "+(v?"PASS ":"FAIL ")+"target-lifecycle "+s);}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("TARGET PHASE "+(host?"host ":"join ")+s);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="target-lifecycle-test";p.op=op;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function klass(n:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(n) as Class;}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var by:int=200;by<l.limY-40;by+=40)for(var bx:int=80;bx<l.limX-340;bx+=40) {
            var clear:Boolean=true;
            for(var ix:int=0;ix<=320&&clear;ix+=20) {
               if(l.getAbsTile(bx+ix,by+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=180;iy+=20)if(l.getAbsTile(bx+ix,by-iy).phis!=0){clear=false;break;}
            }
            if(clear){baseX=bx;baseY=by;return;}
         }throw new Error("no native floored test corridor");
      }
      private function install():void {
         var l:Object=mod.game.loc,g:Object=mod.game.gg;
         mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();
         var removed:Array=[];
         for(var o:Object=l.firstObj;o!=null;o=o.nobj)
            if(o!==g&&!(o is Unit)&&GameBridge.probe(o,"X2")!=null&&o.X2>baseX-20&&o.X1<baseX+340&&o.Y2>baseY-190&&o.Y1<baseY+20)removed.push(o);
         for each(o in removed){l.remObj(o);var index:int=l.objs.indexOf(o);if(index>=0)l.objs.splice(index,1);if(l.celObj===o)l.celObj=null;}
         g.invulner=true;g.transp=true;g.pers.healAll();g.setPos(baseX,baseY);g.setVisPos();l.base=false;l.portOn=true;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,95000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
      }
      private function enemy(hp:int,px:Number):Object {
         var c:Class=klass("fe.unit.UnitSlaver"),u:Object=new c("slaver2",100,<unit tr="2"/>,null);
         u.putLoc(mod.game.loc,px,baseY);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.xp=0;u.hp=u.maxhp=hp;u.isSats=true;u.invis=false;u.animate();return u;
      }
      private function find(hp:int):Object {for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&u.id=="slaver2"&&u.maxhp==hp)return u;return null;}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="target-lifecycle-test")return;
         try {
            if(host&&p.op=="ready")ready=true;
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;install();send("installed");change("find");}
            else if(host&&p.op=="installed"){a=enemy(54321,baseX+110);b=enemy(54322,baseX+70);change("enemy-ready");}
            else if(host&&p.op=="enemy-ready"){mod.session.pause.setPolicy(false,true);walk=true;send("walk");change("walk");}
            else if(!host&&p.op=="walk")change("walk");
            else if(!host&&p.op=="walk-ready")walkReady=true;
            else if(!host&&p.op=="endpoint")endpoint=p.x;
            else if(host&&p.op=="paused-result"){walk=false;send("resume");change("wait-grab");}
            else if(!host&&p.op=="resume"){mod.game.world.sats.onoff(-1);aim=a;change("aim-a");}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function before(e:Event):void {
         if(phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;g.invulner=true;g.transp=true;g.dx=g.dy=0;g.isTake=0;
         g.setPos(baseX,baseY);g.setVisPos();w.ctr.active=true;
         if(aim!=null) {
            var ax:Number=aim.X,ay:Number=aim.Y-aim.scY/2;
            g.celX=w.celX=ax;g.celY=w.celY=ay;
            w.cam.celX=int(ax*w.cam.scaleV+w.cam.vx);w.cam.celY=int(ay*w.cam.scaleV+w.cam.vy);
         }
      }
      private function after(e:Event):void {
         if(phase=="done")return;
         if(host&&a!=null&&walk&&!mod.session.pause.paused&&mod.game.world.allStat==1) {
            a.setPos(a.X+3,baseY);a.setVisPos();++walkFrames;
            if(walkFrames==25)send("walk-ready");
         }mod.stage.invalidate();
      }
      private function openSats():void {
         var w:Object=mod.game.world,g:Object=mod.game.gg,gun:Object=new NativeTestGun(g as Unit);
         gun.loc=mod.game.loc;gun.hold=90;g.currentWeapon=gun;g.childObjs[0]=gun;gun.addVisual();gun.setPers(g,g.pers);gun.lvl=0;
         g.ggControl=true;g.pipOff=0;g.storona=1;w.catPause=false;w.pip.onoff(-1);
         mod.game.loc.getAbsTile(a.X,a.Y-a.scY/2).visi=1;
         w.ctr.keySats=true;change("opening");
      }
      private function checkRaster():void {
         var graph:Object=mod.game.world.grafon,bmp:BitmapData=graph.satsBmp;
         var reference:BitmapData=new BitmapData(bmp.width,bmp.height,true,0),sats:Object=mod.game.world.sats;
         var layerVisible:Boolean=graph.visObjs[2].visible,screenshotVisible:Boolean=graph.visSats.visible,targetsVisible:Boolean=sats.vis.visible;
         try {graph.visObjs[2].visible=true;graph.visSats.visible=false;sats.vis.visible=false;reference.draw(graph.visual);}
         finally {graph.visObjs[2].visible=layerVisible;graph.visSats.visible=screenshotVisible;sats.vis.visible=targetsVisible;}
         var old:Object=pixels(bmp),current:Object=pixels(reference);reference.dispose();
         check(old.count>=16&&current.count>=16,"native frozen/reference raster contains actual enemy marker counts="+old.count+"/"+current.count);
         check(old.count>0&&current.count>0&&Math.abs(old.x-current.x)<=1,"paused bitmap enemy and live endpoint coincide gap="+(old.x-current.x));
         Log.d("TARGET RASTER "+JSON.stringify({count:old.count,referenceCount:current.count,bitmapX:old.x,expectedX:current.x,endpoint:endpoint,bodyX:a.X}));
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("target-sats.png"),FileMode.WRITE);f.writeBytes(bmp.encode(bmp.rect,new PNGEncoderOptions()));f.close();
      }
      private function pixels(bmp:BitmapData):Object {
         var count:int=0,sum:Number=0;
         for(var py:int=0;py<bmp.height;py++)for(var px:int=0;px<bmp.width;px++)if(bmp.getPixel(px,py)==0xfb01fd){count++;sum+=px;}
         return {count:count,x:sum/count};
      }
      private function grip():void {
         var g:Object=mod.game.gg;g.mana=g.maxmana=10000;g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;
         g.pers.telemaster=1;g.pers.unitLevitMult=100;g.pers.telePorog=0;g.pers.spellsPoss=1;
         // Same native method as Q. Do not supply celObj/onCursor: resolving the
         // real pointer is precisely the release/retarget behaviour under test.
         EnemyGrabProbe.grab(g);
         Log.d("TARGET GRAB "+JSON.stringify({phase:phase,held:g.teleObj==null?null:g.teleObj.maxhp,
            cursor:mod.game.loc.celObj==null?null:getQualifiedClassName(mod.game.loc.celObj),
            cursorHp:GameBridge.probe(mod.game.loc.celObj,"maxhp"),aCursor:a.onCursor,bCursor:b.onCursor}));
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(phase=="done")return;if(getTimer()-at>90000){check(false,"timeout "+phase);send("done");finish();return;}
            var w:Object=mod.game.world,g:Object=mod.game.gg;
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&ready){arena();install();send("setup",{x:baseX,y:baseY});change("setup");}else if(!host)send("ready");
            } else if(!host&&phase=="find"&&(a=find(54321))!=null&&(b=find(54322))!=null) {
               marker=new Sprite();marker.graphics.beginFill(0xfb01fd);marker.graphics.drawRect(-30,-65,60,65);marker.graphics.endFill();a.vis.addChild(marker);
               send("enemy-ready");change("wait-walk");
            } else if(!host&&phase=="walk"&&walkReady&&mod.session.pause.policySats)openSats();
            else if(host&&phase=="walk"&&mod.session.pause.paused){endpoint=a.X;check(walkFrames>12,"native source moved before pause");send("endpoint",{x:endpoint});change("paused");}
            else if(!host&&phase=="opening"&&w.sats.active&&mod.session.pause.paused) {
               for each(var s:Object in w.sats.units)if(s.u is MirrorHitUnit&&MirrorHitUnit(s.u).body===a){selected=s;selectedVisual=s.du;}
               queue=w.sats.que;change("paused");
            } else if(!host&&phase=="paused"&&getTimer()-at>1400&&isFinite(endpoint)) {
               check(Math.abs(a.X-endpoint)<=1,"logical body settles at authoritative stop");
               check(selected!=null&&w.sats.units.indexOf(selected)>=0&&w.sats.que===queue,"target entry and attack queue retain identity");
               check(selected!=null&&Math.abs(selected.v.x-a.vis.x)<=1,"native target overlay coincides with settled enemy");
               checkRaster();send("paused-result");change("wait-resume");
            } else if(!host&&phase=="aim-a"&&getTimer()-at>900&&!mod.session.pause.paused) {
               grip();check(mod.game.grabBody(g.teleObj)===a,"native grab resolves first enemy from mouse input");change("hold-a");
            } else if(!host&&phase=="hold-a"&&getTimer()-at>500) {
               g.dropTeleObj();check(g.teleObj==null,"native release clears held pointer");aim=b;change("aim-b");
            } else if(!host&&phase=="aim-b"&&getTimer()-at>800) {
               grip();check(mod.game.grabBody(g.teleObj)===b,"release then mouse move grabs different enemy");
               check(a.onCursor==0,"released first enemy no longer advertises stale cursor");
               g.dropTeleObj();send("done");finish();
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {if(phase=="done")return;change("done");timer.stop();if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);}Log.d("COOP EFFECTS DONE target-lifecycle");}
   }
}
