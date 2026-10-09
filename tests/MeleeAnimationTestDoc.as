package {
   import fe.weapon.MeleeTestAccess;
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Point;
   import flash.geom.Matrix;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native attack/step, independent source display oracle, actual Session/TCP
    * and final remote graphics. No calls to the production melee presenter. */
   public class MeleeAnimationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"knife",dir:1,mode:"auto",trail:true,frame:false,motion:true},
         {id:"knife",dir:-1,mode:"auto",trail:true,frame:false,motion:true},
         {id:"bat",dir:1,mode:"single",trail:true,frame:false,motion:true},
         {id:"spear",dir:-1,mode:"charge",trail:false,frame:false,motion:true},
         {id:"shovel",dir:1,mode:"charge",trail:true,frame:false,motion:true},
         {id:"elsword",dir:-1,mode:"single",trail:false,frame:true,motion:true},
         {id:"ripper",dir:1,mode:"auto",trail:false,frame:true,motion:false},
         {id:"autoaxe",dir:-1,mode:"auto",trail:false,frame:true,motion:false},
         {id:"knife",dir:1,mode:"auto",trail:true,frame:false,motion:true,switchGun:true},
         {id:"knife",dir:-1,mode:"auto",trail:true,frame:false,motion:true,stealth:true},
         {id:"elsword",dir:1,mode:"single",trail:false,frame:true,motion:true,stealth:true}
      ];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,nativeFrame:int=0;
      private var weapon:Object,oldWeapon:Object,oldChildren:Object,baseX:Number,baseY:Number;
      private var nativeTrace:Array=[],remoteTrace:Array=[],peerTrace:Array;
      private var sourceAttacks:int=0,sourceCharge:int=0,sourceTrail:int=0,remoteTrail:int=0;
      private var sourceFrames:Object={},remoteFrames:Object={},missing:int=0,wireFrames:int=0;
      private var localDone:Boolean=false,peerDone:Boolean=false,peerMetrics:Object;
      private var sourceEnd:Object,remoteEnd:Object;
      private var lastRemoteTrail:MovieClip,switched:Boolean=false,switchedRemote:int=0,switchTrailWrong:int=0;
      private var oldStealth:Number=0,sourceBodyAlpha:Number=1,remoteBodyAlpha:Number=1;
      private var sourceLifeReady:Boolean=false;
      private var warmFrames:int=0,prepared:Boolean=false,peerPrepared:Boolean=false;

      public function MeleeAnimationTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"melee-animation "+s+" case="+round);}
      private function send(stage:String,p:Object=null):void {
         p=p||{};p.type="melee-animation-test";p.stage=stage;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {if(link!=null && !links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function healthy(g:Object):Boolean {
         return g!=null && Number(g.hp)>0 && int(g.sost)<2 && GameBridge.probe(g,"animOff")!==true
            && !(Number(GameBridge.probe(g,"t_work"))>0 && (g.work=="die" || g.work=="res"));
      }
      private function setup():void {
         var g:Object=mod.game.gg;baseX=g.X;baseY=g.Y;oldWeapon=g.currentWeapon;oldChildren=g.childObjs;
         var item:Object=GameBridge.probe(g.invent.items,"stealth");
         if(item!=null){oldStealth=Number(item.kol);item.kol=Math.max(20,oldStealth);}
         check(healthy(g),"native living player ready before freezing physics");
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function start(n:int):void {
         if(weapon!=null)weapon.remVisual();
         round=n;phase="warm";at=getTimer();nativeFrame=warmFrames=0;prepared=peerPrepared=false;
         localDone=peerDone=false;peerTrace=null;peerMetrics=null;
         sourceAttacks=sourceCharge=sourceTrail=remoteTrail=missing=wireFrames=0;
         sourceFrames={};remoteFrames={};nativeTrace=[];remoteTrace=[];sourceEnd=remoteEnd=null;
         lastRemoteTrail=null;switched=false;switchedRemote=switchTrailWrong=0;
         sourceBodyAlpha=remoteBodyAlpha=1;
         var g:Object=mod.game.gg,factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         g.remEffect("stealth");g.remEffect("stealth_armor");
         weapon=factory.create(g,String(CASES[n].id),0);
         if(weapon==null){check(false,"native factory missing "+CASES[n].id);send("done");finish();return;}
         weapon.setPers(g,g.pers);weapon.addVisual();g.currentWeapon=weapon;g.childObjs=[weapon];
         weapon.lvl=0;weapon.perslvl=0;weapon.hold=999;weapon.t_reload=0;weapon.damage=0;
         check(weapon.vis!=null && weapon.vis.stage!=null,"source native "+weapon.id+" staged");
         if(CASES[n].stealth===true)check(g.invent.useItem("stealth"),"source consumes the real native stealth item");
      }
      private function before(e:Event):void {
         if(phase!="warm" && phase!="show" && phase!="sampled")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,c:Object=CASES[round];
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.storona=int(c.dir);g.disabled=true;g.invulner=true;
         g.celX=w.celX=baseX+int(c.dir)*160;g.celY=w.celY=baseY-60;
         var cam:Object=w.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
         if(phase=="warm")warmFrames++;
         if(phase=="show")nativeFrame++;
         weapon.hold=999;weapon.t_reload=0;
         if(nativeFrame>=24 && nativeFrame<=104 && phase=="show" && !switched) {
            if(c.mode=="auto" || c.mode=="single" && (nativeFrame-24)%20==0
               || c.mode=="charge" && ((nativeFrame>=24 && nativeFrame<=45) || (nativeFrame>=68 && nativeFrame<=89)))weapon.attack();
         }
      }
      private function after(e:Event):void {
         if(phase!="warm" && phase!="show" && phase!="sampled")return;
         weapon.step();mod.game.world.testDam=true;
         if(phase=="show") {
            if(int(weapon.t_attack)>0)sourceAttacks++;
            if(Number(weapon.pow)>2)sourceCharge++;
            if(CASES[round].switchGun===true && !switched && nativeFrame>=76
               && MeleeTestAccess.trail(weapon)!=null && MeleeTestAccess.trail(weapon).visible) {
               check(true,"switch occurs while the native knife slash is visible");
               weapon.remVisual();
               var g:Object=mod.game.gg,factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
               weapon=factory.create(g,"lmg",0);weapon.setPers(g,g.pers);weapon.addVisual();g.currentWeapon=weapon;g.childObjs=[weapon];
               weapon.lvl=weapon.perslvl=0;weapon.damage=0;switched=true;
            }
         }
         mod.stage.invalidate();
      }
      /** Independent point oracle: apply each real local transform to the
       * point, then reverse the destination chain. Avoid Flash global pixel
       * projection rounding, without calling the production matrix helper. */
      private function project(v:DisplayObject,layer:DisplayObject,p:Point):Point {
         var node:DisplayObject=v,chain:Array=[];
         while(node!=null){p=node.transform.matrix.transformPoint(p);node=node.parent;}
         node=layer;while(node!=null){chain.push(node);node=node.parent;}
         for(var i:int=chain.length-1;i>=0;i--){var m:Matrix=chain[i].transform.matrix.clone();m.invert();p=m.transformPoint(p);}
         return p;
      }
      private function pose(u:Object,v:DisplayObject):Object {
         var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
         var layer:DisplayObjectContainer=body==null?null:body.parent;
         if(v==null || v.stage==null || layer==null)return null;
         var p:Point=project(v,layer,new Point());
         // Independent point-projection oracle, with long axes to avoid
         // magnifying Flash's subpixel coordinate rounding.
         var a:Point=project(v,layer,new Point(1000,0)).subtract(p);
         var b:Point=project(v,layer,new Point(0,1000)).subtract(p);
         a.x/=1000;a.y/=1000;b.x/=1000;b.y/=1000;
         var sx:Number=Math.sqrt(a.x*a.x+a.y*a.y);
         return {x:p.x-Number(u.X),y:p.y-Number(u.Y),r:Math.atan2(a.y,a.x),sx:sx,
            sy:sx<.0001?0:(a.x*b.y-a.y*b.x)/sx,visible:v.visible,
            f:v is MovieClip?MovieClip(v).currentFrame:1,a:opacity(v,layer)};
      }
      private function opacity(v:DisplayObject,layer:DisplayObjectContainer):Number {
         var a:Number=1,o:DisplayObject=v;
         while(o!=null && o!==layer){a*=o.alpha;o=o.parent;}return a;
      }
      private function render(e:Event):void {
         if(phase!="show")return;
         var a:Object=pose(mod.game.gg,weapon.vis as DisplayObject);
         var slash:MovieClip=MeleeTestAccess.trail(weapon);
         if(a!=null && !switched) {
            sourceBodyAlpha=Number(mod.game.gg.vis.alpha);
            sourceFrames[String(a.f)]=true;
            var s:Object=pose(mod.game.gg,slash);nativeTrace.push({weapon:a,trail:s});sourceEnd={weapon:a,trail:s};
            if(s!=null && s.visible)sourceTrail++;
         }
         var ghost:Object=mod.game.getRemoteGhost(host?1:0),w:Object=ghost==null?null:GameBridge.probe(ghost,"currentWeapon");
         if(CASES[round].switchGun===true && w!=null && w.id=="lmg") {
            switchedRemote++;
            if(lastRemoteTrail!=null && lastRemoteTrail.parent!=null && lastRemoteTrail.visible)switchTrailWrong++;
            return;
         }
         if(w==null || String(w.id)!=String(CASES[round].id)){missing++;return;}
         a=pose(ghost,w.vis as DisplayObject);
         if(a==null){missing++;return;}
         s=pose(ghost,MeleeTestAccess.trail(w));
         remoteBodyAlpha=Number(ghost.vis.alpha);
         lastRemoteTrail=MeleeTestAccess.trail(w);
         remoteTrace.push({weapon:a,trail:s});remoteEnd={weapon:a,trail:s};remoteFrames[String(a.f)]=true;
         if(s!=null && s.visible)remoteTrail++;
      }
      private function wire(p:Object):void {
         var snapshot:Object=host?p.snap:null;
         if(!host && p.players is Array)for each(var player:Object in p.players)if(int(player.id)==0)snapshot=player.snap;
         if(snapshot!=null && snapshot.weapons is Array)for each(var w:Object in snapshot.weapons) {
            if(w.main===true && w.id==CASES[round].id && w.melee!=null && w.melee.frames is Array)
               wireFrames=Math.max(wireFrames,w.melee.frames.length);
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(phase=="show")wire(p);
         if(p.type!="melee-animation-test")return;
         if(host && p.stage=="ready" && phase=="boot" && healthy(mod.game.gg)){setup();send("setup");start(0);}
         else if(!host && p.stage=="setup" && phase=="boot"){setup();start(0);}
         else if(p.stage=="round" && !host)start(int(p.round));
         else if(p.stage=="prepared" && int(p.round)==round)peerPrepared=true;
         else if(p.stage=="go" && !host && int(p.round)==round){phase="show";at=getTimer();}
         else if(p.stage=="native" && int(p.round)==round){peerTrace=p.trace;peerMetrics=p.metrics;compare();}
         else if(p.stage=="result" && host && int(p.round)==round){peerDone=true;advance();}
         else if(p.stage=="done")finish();
      }
      private function range(trace:Array,key:String):Number {
         var low:Number=Infinity,high:Number=-Infinity;
         for each(var p:Object in trace){low=Math.min(low,Number(p.weapon[key]));high=Math.max(high,Number(p.weapon[key]));}
         return high-low;
      }
      private function error(a:Object,b:Object):Number {
         if(a==null || b==null)return a==null && b==null?0:1e6;
         if(a.visible!==b.visible || int(a.f)!=int(b.f) || Number(a.sy)*Number(b.sy)<0)return 1e6;
         var angle:Number=Number(a.r)-Number(b.r);
         while(angle>Math.PI)angle-=Math.PI*2;while(angle<-Math.PI)angle+=Math.PI*2;
         return Math.max(Math.abs(Number(a.x)-Number(b.x)),Math.abs(Number(a.y)-Number(b.y)),
            Math.abs(angle)*20,Math.abs(Number(a.sx)-Number(b.sx))*20,Math.abs(Number(a.sy)-Number(b.sy))*20);
      }
      private function interpolate(a:Object,b:Object,t:Number):Object {
         if(a==null || b==null)return a;
         var angle:Number=Number(b.r)-Number(a.r);
         while(angle>Math.PI)angle-=Math.PI*2;while(angle<-Math.PI)angle+=Math.PI*2;
         return {x:Number(a.x)+(Number(b.x)-Number(a.x))*t,y:Number(a.y)+(Number(b.y)-Number(a.y))*t,
            r:Number(a.r)+angle*t,sx:a.sx,sy:a.sy,visible:a.visible,f:a.f,a:a.a};
      }
      private function nearest(a:Object):Number {
         var best:Number=Infinity;
         for(var i:int=0;i<peerTrace.length;i++) {
            var b:Object=peerTrace[i],next:Object=i+1<peerTrace.length?peerTrace[i+1]:b;
            // The remote can be between two native frames. Check the native
            // segment independently, including its discrete frame/visibility.
            for(var n:int=0;n<=20;n++) {
               var t:Number=n/20,p:Object={weapon:interpolate(b.weapon,next.weapon,t),trail:interpolate(b.trail,next.trail,t)};
               var e:Number=error(a.weapon,p.weapon);
               if(CASES[round].stealth===true)e=Math.max(e,Math.abs(Number(a.weapon.a)/.75-Number(p.weapon.a))*20);
               if(a.trail!=null && a.trail.visible)e=Math.max(e,error(a.trail,p.trail));
               if(CASES[round].stealth===true && a.trail!=null && a.trail.visible && p.trail!=null)
                  e=Math.max(e,Math.abs(Number(a.trail.a)/.75-Number(p.trail.a))*20);
               best=Math.min(best,e);
            }
         }
         return best;
      }
      private function compare():void {
         if(phase!="sampled" || peerTrace==null || localDone)return;
         var c:Object=CASES[round],wrong:int=0,maxError:Number=0;
         check(nativeTrace.length>=40 && sourceAttacks>0,"real native attacks sampled frames="+nativeTrace.length+" attack="+sourceAttacks);
         if(c.mode=="charge")check(sourceCharge>0,"real native charge observed frames="+sourceCharge);
         check(remoteTrace.length>=24 && missing==0,"remote native weapon stays staged frames="+remoteTrace.length+" missing="+missing);
         check(wireFrames>=4,"real TCP contains short native melee history frames="+wireFrames);
         if(c.motion) {
            var nativeRange:Number=Math.max(range(peerTrace,"x"),range(peerTrace,"y"),range(peerTrace,"r")*20);
            var remoteRange:Number=Math.max(range(remoteTrace,"x"),range(remoteTrace,"y"),range(remoteTrace,"r")*20);
            check(nativeRange>10,"native swing/thrust really moves range="+nativeRange);
            check(remoteRange>=nativeRange*.65,"remote swing/thrust preserved range="+remoteRange+" native="+nativeRange);
         }
         if(c.trail) {
            check(sourceTrail>0 && int(peerMetrics.trail)>0,"both sources emitted their native slash frames="+sourceTrail+"/"+peerMetrics.trail);
            check(remoteTrail>0,"peer's native slash actually visible frames="+remoteTrail);
         }
         if(c.frame) {
            check(sourceFrames["2"]===true && sourceFrames["3"]===true,"source blade activation/hit frames observed");
            check(remoteFrames["2"]===true && remoteFrames["3"]===true,"remote blade activation/hit frames observed");
         }
         if(c.stealth===true) {
            check(Math.abs(sourceBodyAlpha-.5)<.002 && Math.abs(Number(peerMetrics.bodyAlpha)-.5)<.002,"both native stealth bodies really use alpha=.5");
            check(Math.abs(remoteBodyAlpha-Number(peerMetrics.bodyAlpha)*.75)<.002,"remote body retains native stealth and the teammate marker alpha="+remoteBodyAlpha);
            check(remoteEnd!=null && Math.abs(Number(remoteEnd.weapon.a)-Number(peerTrace[peerTrace.length-1].weapon.a)*.75)<.002,
               "world-layer weapon alpha is independent of native stealth body alpha="+(remoteEnd==null?-1:remoteEnd.weapon.a));
         }
         // Bound comparison work, with uniform coverage across the full run.
         for(var i:int=0;i<remoteTrace.length;i+=Math.max(1,int(remoteTrace.length/40))) {
            var err:Number=nearest(remoteTrace[i]);maxError=Math.max(maxError,err);
            if(err>1.5)wrong++;
         }
         check(remoteTrace.length>=24 && wrong==0,"remote final poses follow native curves wrong="+wrong+" maxPxEquivalent="+maxError);
         var terminal:Object=peerTrace.length>0?peerTrace[peerTrace.length-1]:null;
         if(c.switchGun===true) {
            check(switched,"source really replaced the attacking knife with a native gun");
            check(switchedRemote>=12 && switchTrailWrong==0,"remote gun replacement clears the old melee slash frames="+switchedRemote+" wrong="+switchTrailWrong);
         } else check(remoteEnd!=null && terminal!=null && error(remoteEnd.weapon,terminal.weapon)<.1
            && (remoteEnd.trail==null || !remoteEnd.trail.visible),"released weapon reaches native rest frame and leaves no slash");
         Log.d("MELEE ANIMATION METRIC "+JSON.stringify({role:host?"host":"join",round:round,id:c.id,dir:c.dir,mode:c.mode,
            sourceAttacks:sourceAttacks,sourceCharge:sourceCharge,sourceTrail:sourceTrail,remoteTrail:remoteTrail,
            sourceFrames:sourceFrames,remoteFrames:remoteFrames,wireFrames:wireFrames,missing:missing,wrong:wrong,maxError:maxError,
            switched:switched,switchedRemote:switchedRemote,switchTrailWrong:switchTrailWrong,
            sourceBodyAlpha:sourceBodyAlpha,remoteBodyAlpha:remoteBodyAlpha,
            source:nativeTrace,peer:peerTrace,remote:remoteTrace}));
         localDone=true;send("result",{round:round});advance();
      }
      private function advance():void {
         if(!host || !localDone || !peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}
         else{send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done" && getTimer()-at>60000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         var g:Object=mod.game.gg;
         if(phase=="boot") {
            // Isolated newGame enters the opening story's scripted die pose
            // while the pony is alive. Release only that known intro override.
            if(g.animOff===true&&g.hp>0&&int(g.sost)==1&&g.work==""
               &&g.vis.osn.currentFrameLabel=="die")g.anim();
            sourceLifeReady=healthy(g);
         }
         if(phase=="boot" && !host && sourceLifeReady && timer.currentCount>160 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         // Both real weapons finish equipping before the observation window.
         // No source warmup is discarded while the receiver still displays it.
         if(phase=="warm" && warmFrames>=40 && !prepared){prepared=true;send("prepared",{round:round});}
         if(host && phase=="warm" && prepared && peerPrepared){phase="show";at=getTimer();send("go",{round:round});}
         if(phase=="show" && nativeFrame>=140 && getTimer()-at>=5500) {
            phase="sampled";send("native",{round:round,trace:nativeTrace,metrics:{trail:sourceTrail,attacks:sourceAttacks,charge:sourceCharge,bodyAlpha:sourceBodyAlpha}});compare();
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            if(weapon!=null)weapon.remVisual();
            mod.game.gg.remEffect("stealth");
            var item:Object=GameBridge.probe(mod.game.gg.invent.items,"stealth");if(item!=null)item.kol=oldStealth;
            if(oldWeapon!=null){mod.game.gg.currentWeapon=oldWeapon;mod.game.gg.childObjs=oldChildren;}
         }
         Log.d("COOP EFFECTS DONE melee-animation "+(host?"host":"join"));
      }
   }
}
