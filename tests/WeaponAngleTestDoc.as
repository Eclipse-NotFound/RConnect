package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Point;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Weapon.step/animate and attack, real Session/TCP, final display axes.
    * Facing and aiming deliberately differ: a pony's facing is not gun flipping. */
   public class WeaponAngleTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{deg:0,body:1},{deg:160,body:1},{deg:-160,body:-1},
         {deg:85,body:-1},{deg:95,body:1},{deg:-95,body:1},{deg:180,body:-1}];
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var gun:Object,oldGun:Object,oldChildren:Object,baseX:Number,baseY:Number;
      private var expected:Object,samples:int=0,wrong:int=0,flashes:int=0,localDone:Boolean=false,peerDone:Boolean=false;
      private var sourceFlashes:int=0,lastShoot:int=0,sourceShots:int=0,peerSourceShots:int=0;
      private var previousAxes:Object;
      private var nativeSamples:int=0,invalidNativeAxes:int=0,diagnosticRound:int=-1;
      private var warmFrames:int=0,prepared:Boolean=false,peerPrepared:Boolean=false;
      public function WeaponAngleTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"weapon-angle "+s+" case="+round);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="weapon-angle-test";p.stage=s;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function axes(v:DisplayObject):Object {
         if(v==null || v.stage==null)return null;
         var p:Point=v.localToGlobal(new Point()),x:Point=v.localToGlobal(new Point(1000,0)),y:Point=v.localToGlobal(new Point(0,1000));
         x=x.subtract(p);y=y.subtract(p);x.normalize(1);y.normalize(1);
         return {xx:x.x,xy:x.y,yx:y.x,yy:y.y};
      }
      private function setup():void {
         var g:Object=mod.game.gg;
         baseX=g.X;baseY=g.Y;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         var c:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         gun=c.create(g,"lmg",0);gun.setPers(g,g.pers);gun.addVisual();
         g.currentWeapon=gun;g.childObjs=[gun];gun.hold=999;gun.precision=0;gun.lvl=0;gun.perslvl=0;gun.recoilUp=0;
         check(gun.vis!=null && gun.vis.stage!=null,"source uses the staged native LMG visual");
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function start(n:int):void {
         round=n;phase="warm";at=getTimer();expected=null;samples=wrong=flashes=sourceFlashes=sourceShots=peerSourceShots=0;
         warmFrames=0;prepared=peerPrepared=false;
         localDone=peerDone=false;lastShoot=0;
         previousAxes=null;
         nativeSamples=invalidNativeAxes=0;
      }
      private function before(e:Event):void {
         // The peer can still be sampling after our local timer finishes.
         // Keep the native input pose until both sides complete this round.
         if((phase!="warm" && phase!="show" && phase!="sampled") || gun==null)return;
         var g:Object=mod.game.gg,a:Number=CASES[round].deg*Math.PI/180;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=CASES[round].body;g.disabled=true;g.invulner=true;
         g.celX=baseX+Math.cos(a)*450;g.celY=baseY-g.scY*.7+Math.sin(a)*450;
         mod.game.world.celX=g.celX;mod.game.world.celY=g.celY;
         gun.hold=999;gun.t_reload=0;
         var cam:Object=mod.game.world.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
         if(phase!="warm")gun.attack();
      }
      private function after(e:Event):void {
         if((phase!="warm" && phase!="show" && phase!="sampled") || gun==null)return;
         gun.step();mod.game.world.testDam=true;
         if(phase=="warm")warmFrames++;
         mod.stage.invalidate();
      }
      private function render(e:Event):void {
         if((phase!="warm" && phase!="show" && phase!="sampled") || gun==null)return;
         var actual:Object=axes(gun.vis as DisplayObject);
         // A vanished global basis cannot be a reference for either player's
         // weapon. Keep the original peer comparisons and assert this native
         // precondition separately, with enough context to diagnose a failure.
         if(diagnosticRound!=round) {
            diagnosticRound=round;
            var chain:Array=[],node:DisplayObject=gun.vis as DisplayObject;
            while(node!=null) {
               var basis:Object=node.transform.matrix;
               chain.push({type:getQualifiedClassName(node),name:node.name,
                  a:basis.a,b:basis.b,c:basis.c,d:basis.d,tx:basis.tx,ty:basis.ty});
               node=node.parent;
            }
            var cam:Object=mod.game.world.cam;
            Log.d("WEAPON COORDINATE CONTEXT "+JSON.stringify({role:host?"host":"join",round:round,
               stageWidth:mod.stage.stageWidth,stageHeight:mod.stage.stageHeight,
               cameraScale:cam.scaleV,screenX:cam.screenX,screenY:cam.screenY,chain:chain}));
         }
         if(actual!=null && (previousAxes==null || Math.abs(actual.xx-previousAxes.xx)+Math.abs(actual.xy-previousAxes.xy)+Math.abs(actual.yx-previousAxes.yx)+Math.abs(actual.yy-previousAxes.yy)>.01)) {
            Log.d("WEAPON ANGLE NATIVE CHANGE "+JSON.stringify({role:host?"host":"join",round:round,phase:phase,elapsed:getTimer()-at,axes:actual}));previousAxes=actual;
         }
         if(actual!=null)send("native",{round:round,axes:actual});
         if(phase!="show")return;
         nativeSamples++;
         if(actual==null || !isFinite(actual.xx) || !isFinite(actual.xy) || !isFinite(actual.yx) || !isFinite(actual.yy)
            || Math.abs(actual.xx*actual.xx+actual.xy*actual.xy-1)>.01
            || Math.abs(actual.yx*actual.yx+actual.yy*actual.yy-1)>.01)invalidNativeAxes++;
         if(String(GameBridge.probe(gun.vis,"currentLabel"))=="shoot")sourceFlashes++;
         sourceShots=Math.max(sourceShots,int(gun.kol_shoot));
         if(getTimer()-at<700 || expected==null)return;
         var ghost:Object=mod.game.getRemoteGhost(host?1:0);
         if(ghost==null || ghost.currentWeapon==null)return;
         var v:Object=ghost.currentWeapon.vis,remote:Object=axes(v as DisplayObject);
         if(remote==null)return;
         samples++;
         var error:Number=Math.max(Math.abs(remote.xx-expected.xx),Math.abs(remote.xy-expected.xy),
            Math.abs(remote.yx-expected.yx),Math.abs(remote.yy-expected.yy));
         if(error>.08) {wrong++;if(wrong<=8)Log.d("WEAPON ANGLE MISMATCH "+JSON.stringify({role:host?"host":"join",round:round,elapsed:getTimer()-at,error:error,expected:expected,remote:remote}));}
         if(String(GameBridge.probe(v,"currentLabel"))=="shoot")flashes++;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="weapon-angle-test")return;
         if(host && p.stage=="ready" && phase=="boot"){setup();send("setup");start(0);}
         else if(!host && p.stage=="setup" && phase=="boot"){setup();start(0);}
         else if(p.stage=="native" && int(p.round)==round)expected=p.axes;
         else if(p.stage=="round" && !host)start(int(p.round));
         else if(p.stage=="prepared" && int(p.round)==round)peerPrepared=true;
         else if(p.stage=="go" && !host && int(p.round)==round){phase="show";at=getTimer();}
         else if(p.stage=="result" && host && int(p.round)==round){peerDone=true;peerSourceShots=int(p.shots);advance();}
         else if(p.stage=="done")finish();
      }
      private function advance():void {
         if(!host || !localDone || !peerDone)return;
         check(peerSourceShots>0,"join source actually fired native bullets");
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}
         else {send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         var w:Object=mod.game.world;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done" && getTimer()-at>60000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot" && !host && t.currentCount>160 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         // This suite checks held aim at each angle. The native gun needs up
         // to 16 simulation steps to turn; let both real guns finish first.
         if(phase=="warm" && warmFrames>=40 && !prepared){prepared=true;send("prepared",{round:round});}
         if(host && phase=="warm" && prepared && peerPrepared){phase="show";at=getTimer();send("go",{round:round});}
         if(phase=="show" && getTimer()-at>2800) {
            check(nativeSamples>=12 && invalidNativeAxes==0,"native global coordinates remain valid invalid="+invalidNativeAxes+"/"+nativeSamples);
            check(samples>=12,"final display sampled after buffering frames="+samples);
            check(samples>=12 && wrong==0,"remote gun matches native aim and flip wrong="+wrong+"/"+samples+" degree="+CASES[round].deg+" facing="+CASES[round].body);
            check(sourceFlashes>0 && sourceShots>0,"source native shoot animation and bullets observed");
            check(flashes>0,"peer's native muzzle animation plays at this angle frames="+flashes);
            Log.d("WEAPON ANGLE METRIC "+JSON.stringify({role:host?"host":"join",round:round,degree:CASES[round].deg,facing:CASES[round].body,samples:samples,wrong:wrong,flashes:flashes,sourceFlashes:sourceFlashes}));
            localDone=true;phase="sampled";send("result",{round:round,shots:sourceShots});advance();
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";t.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            if(gun!=null)gun.remVisual();if(oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}}
         Log.d("COOP EFFECTS DONE weapon-angle "+(host?"host":"join"));
      }
   }
}
