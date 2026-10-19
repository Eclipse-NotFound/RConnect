package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filters.GlowFilter;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Same driver runs on unmodified fix39 and the candidate. Real G/Q/E,
    * original PhisBullet simulation and fuse, production TCP. No grip calls. */
   public class PeerProjectileGripTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{id:"grenade",op:"throw"},{id:"dinamit",op:"drop"},
         {id:"spgren",op:"fuse"},{id:"acidgr",op:"throw"},{id:"grenade",op:"throw",swap:true}];
      private var cases:Array=CASES;
      private var seedClass:Object,originalSeed:Function,fixtureSeed:Function;
      private var mod:RConnectMod,host:Boolean,source:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=-1,ready:Boolean=false;
      private var baseX:Number,baseY:Number,spec:Object,tiles:Array=[],installed:Boolean=false;
      private var gun:Object,standby:Object,native:Object,vis:DisplayObject,cls:String="",seen:Dictionary;
      private var fired:Boolean=false,grabbed:Boolean=false,acted:Boolean=false,grabAt:int=0,ended:int=0;
      private var visualFrames:int=0,heldFrames:int=0,ownerHeld:int=0,sourceCount:int=0,explosions:int=0;
      private var proxyPeak:int=0,unexpected:int=0,minMana:Number=0,startMana:Number=0,initialY:Number=0,minY:Number=0;
      private var beforeDX:Number=0,throwDX:Number=0,auraFrames:int=0,nativeFrames:int=0,lifeAtBirth:int=0;
      private var beforeDY:Number=0,throwImpulse:Number=0,minHeldDX:Number=0;
      private var localDone:Boolean=false,peerDone:Boolean=false,sourceReleased:Boolean=false,kickPackets:int=0;
      private var inputFrames:int=0,diagnostics:int=0,attempting:Boolean=false;
      public function PeerProjectileGripTestDoc(scenarios:Array=null) {
         if(scenarios!=null)cases=scenarios;
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         // Identical native map for control/candidate. Only this unique test
         // process overrides its constructor seed callback, never production
         // files or saved settings. Join still adopts the host via production.
         mod=RConnectMod.instance;
         if(host&&mod!=null) {
            seedClass=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
            originalSeed=seedClass.rconnectSeedSource;
            fixtureSeed=function(land:Object):uint {
               return String(land.act.id)=="random_mane"?uint(2056490076):uint(originalSeed(land));
            };seedClass.rconnectSeedSource=fixtureSeed;
         }
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"projectile-grip "+s+" round="+round+" role="+(host?"host":"join"));}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("PROJECTILE GRIP PHASE "+s+" round="+round+" source="+source);}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="projectile-grip-test";p.op=op;p.round=round;
         if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function setup():void {
         var g:Object=mod.game.gg,l:Object=mod.game.loc,w:Object=mod.game.world;
         check(Number(w.land.rconnectLayoutSeed)==2056490076,"native map fixture replays the previously failing candidate room");
         mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();g.anim();
         var wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         if(g.currentWeapon!=null)g.currentWeapon.remVisual();standby=wc.create(g,"lmg",0);
         standby.setPers(g,g.pers);standby.addVisual();g.currentWeapon=standby;g.childObjs=[standby,g.punchWeapon];g.magicWeapon=null;
         g.pers.grenader=0;g.pers.spellsPoss=1;g.pers.maxTeleMassa=10;g.pers.teleDist=1000000;g.pers.telemaster=1;
         g.pers.telePorog=0;g.pers.throwForce=18;g.pers.throwDmanaMult=0;w.weaponsLevelsOff=false;
         l.base=false;l.black=false;l.sky=false;l.portOn=true;w.black=false;
         // Isolated terrain fixture only. The projectile's speed/fuse/bounces
         // and native player input are never replaced or extended.
         var fx:int=int(baseX/40),fy:int=int(baseY/40);
         for(var x:int=fx-1;x<=fx+11;x++)for(var y:int=fy-7;y<=fy;y++) {
            var tile:Object=l.space[x][y];tiles.push({t:tile,x:x,y:y});
         }
         for each(var o:Object in l.objs.concat())if(o.X>baseX-60&&o.X<baseX+480&&o.Y>baseY-280&&o.Y<baseY+30){l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);}
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-20000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);installed=true;
      }
      private function prepare(n:int):void {
         round=n;spec=cases[int(n/2)];source=host==(n%2==0);
         native=null;vis=null;cls="";seen=new Dictionary(true);fired=grabbed=acted=sourceReleased=localDone=peerDone=false;
         grabAt=ended=visualFrames=heldFrames=ownerHeld=sourceCount=explosions=proxyPeak=unexpected=auraFrames=nativeFrames=lifeAtBirth=kickPackets=0;
         throwDX=beforeDX=beforeDY=throwImpulse=0;minHeldDX=Infinity;initialY=minY=NaN;inputFrames=diagnostics=0;attempting=false;
         var g:Object=mod.game.gg;g.dropTeleObj();g.mana=g.maxmana=10000;startMana=minMana=g.mana;g.throwWeapon=null;
         for each(var r:Object in tiles) {
            var tile:Object=r.t,solid:Boolean=r.y==int(baseY/40)||r.x==int(baseX/40)-1||r.x==int(baseX/40)+11;
            tile.phis=tile.opac=solid?1:0;tile.front="";tile.indestruct=true;tile.water=tile.zForm=tile.diagon=tile.stair=0;tile.shelf=false;
            tile.phX1=r.x*40;tile.phX2=(r.x+1)*40;tile.phY1=r.y*40;tile.phY2=(r.y+1)*40;
         }
         mod.game.world.redrawLoc();gun=null;
         if(source) {
            var wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=wc.create(g,spec.id,0);gun.setPers(g,g.pers);gun.loc=mod.game.loc;gun.setNull();
            g.invent.items[gun.ammo].kol=50;g.throwWeapon=gun;
         }change("settle");
      }
      private function before(e:Event):void {
         if(!installed||phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,c:Object=w.ctr;
         g.invulner=true;g.transp=true;g.disabled=false;g.ggControl=true;g.isTake=0;c.active=true;
         g.setPos(baseX+(source?0:80),baseY);g.dx=g.dy=0;g.storona=1;g.setVisPos();
         for each(var u:Object in mod.game.loc.units)if(u!==g&&String(u.id).indexOf("rconnect")<0){u.disabled=true;u.invulner=true;u.trigDis=true;}
         c.keyLeft=c.keyRight=c.keyBeUp=c.keySit=c.keyJump=c.keyRun=c.keyPunch=c.keyReload=false;
         c.keyAttack=c.keyGrenad=c.keyMagic=c.keyTele=c.keyAction=false;
         var ax:Number=baseX+180,ay:Number=baseY-150;
         if(!source&&vis!=null&&!grabbed){ax=vis.x;ay=vis.y-5;}
         // Pull against the initial throw direction, proving the real body
         // follows remote intent rather than merely continuing its old arc.
         if(!source&&grabbed){ax=baseX+40;ay=baseY-210;}
         g.celX=w.celX=ax;g.celY=w.celY=ay;w.cam.celX=ax*w.cam.scaleV+w.cam.vx;w.cam.celY=ay*w.cam.scaleV+w.cam.vy;
         if(phase=="run") {
            if(source&&!fired)c.keyGrenad=true;
            // Native Q is edge-triggered. Let a missed click release before
            // retrying instead of holding Q throughout the entire fuse.
            if(!source&&!grabbed&&visualFrames>=3&&vis!=null) {
               inputFrames++;c.keyTele=inputFrames%6==1;
               if(c.keyTele&&diagnostics<8){attempting=true;diagnostic("before");}
            }
            if(!source&&grabbed&&!acted&&spec.op!="fuse"&&heldFrames>=20) {
               acted=true;if(spec.op=="throw")c.keyAction=true;else c.keyTele=true;
            }
         }mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(phase!="run")return;var g:Object=mod.game.gg;
         if(attempting){attempting=false;diagnostics++;diagnostic("after");}
         if(source&&gun.b!=null&&!seen[gun.b]) {
            seen[gun.b]=true;sourceCount++;if(native==null) {
               native=gun.b;fired=true;lifeAtBirth=native.liv;cls=getQualifiedClassName(native.vis);
               check(getQualifiedClassName(native)=="fe.weapon::PhisBullet","G created native physical projectile id="+spec.id);
               send("born",{cls:cls});
               if(spec.swap){g.throwWeapon=null;check(g.childObjs.indexOf(gun)<0,"switch leaves the launched weapon outside active slots");}
            }
         }
         if(source&&native!=null) {
            if(native.in_chain)nativeFrames++;
            if(native.levit>0) {
               ownerHeld++;if(isNaN(initialY))initialY=minY=native.Y;minY=Math.min(minY,native.Y);minHeldDX=Math.min(minHeldDX,native.dx);
               if(native.vis!=null)for each(var f:Object in native.vis.filters)if(f is GlowFilter){auraFrames++;break;}
            }
            if(ownerHeld>0&&native.levit==0&&!sourceReleased){sourceReleased=true;throwDX=native.dx-beforeDX;
               throwImpulse=Math.sqrt(throwDX*throwDX+(native.dy-beforeDY)*(native.dy-beforeDY));}
            beforeDX=native.dx;beforeDY=native.dy;
            if(native.isExpl&&!seen["expl"]){seen["expl"]=true;explosions++;}
            if(!native.in_chain&&ended==0){ended=getTimer();send("ended");}
         }
         var proxies:int=0;
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(getQualifiedClassName(o)=="fe.weapon::PhisBullet"&&!source)unexpected++;
            if(o.hasOwnProperty("code")&&o.code=="rconnect-projectile")proxies++;
         }proxyPeak=Math.max(proxyPeak,proxies);
         if(!source&&g.teleObj!=null&&g.teleObj.code=="rconnect-projectile") {
            heldFrames++;minMana=Math.min(minMana,g.mana);
            if(!grabbed){grabbed=true;grabAt=getTimer();send("held");}
         }
      }
      private function diagnostic(when:String):void {
         var g:Object=mod.game.gg,l:Object=mod.game.loc,o:Object,proxy:Object=null;
         for(o=l.firstObj;o!=null;o=o.nobj)if(o.hasOwnProperty("code")&&o.code=="rconnect-projectile"){proxy=o;break;}
         var cel:Object=l.celObj;
         Log.d("PROJECTILE GRIP INPUT "+JSON.stringify({when:when,round:round,keys:mod.game.world.ctr.keyTele,
            x:mod.game.world.celX,y:mod.game.world.celY,gx:g.X,gy:g.Y,mana:g.mana,disabled:g.disabled,trigDis:g.trigDis,
            control:g.ggControl,work:g.work,rat:g.rat,selector:g.visSel,base:l.base,range:g.pers.teleDist,mass:g.pers.maxTeleMassa,
            target:g.teleObj==null?null:getQualifiedClassName(g.teleObj),cel:cel==null?null:{cls:getQualifiedClassName(cel),
               x:cel.X,y:cel.Y,hover:cel.onCursor,poss:cel.levitPoss,dist:l.celDist,mass:cel.massa},
            proxy:proxy==null?null:{x:proxy.X,y:proxy.Y,hover:proxy.onCursor,poss:proxy.levitPoss,mass:proxy.massa,
               line:l.isLine(g.X,g.Y-g.scY*.75,proxy.X,proxy.Y-proxy.scY/2)}}));
      }
      private function render(e:Event):void {
         if(phase!="run"||source||cls=="")return;vis=null;
         var layer:Object=mod.game.world.grafon.visObjs[2];
         for(var i:int=0;i<layer.numChildren;i++) {var child:DisplayObject=layer.getChildAt(i);if(getQualifiedClassName(child)==cls){vis=child;visualFrames++;break;}}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="projectile-grip"&&p.op=="ack")Log.d("PROJECTILE GRIP ACK "+JSON.stringify(p));
         if(p.type=="projectile-grip"&&p.op=="release"&&p.kick!=null){kickPackets++;return;}
         if(p.type!="projectile-grip-test")return;
         try {
            if(host&&p.op=="ready")ready=true;
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;setup();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){prepare(0);send("round");}
            else if(!host&&p.op=="round"){prepare(p.round);send("prepared");}
            else if(host&&p.op=="prepared"){ready=true;}
            else if(!host&&p.op=="go")change("run");
            else if(p.op=="born"&&p.round==round)cls=p.cls;
            else if(p.op=="ended"&&p.round==round)ended=getTimer();
            else if(p.op=="result"&&p.round==round){peerDone=true;advance();}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function complete():void {
         if(source) {
            check(sourceCount==1&&explosions==1,"exactly one original projectile and one native explosion");
            check(ownerHeld>=3,"receiver Q affects actual owner projectile frames="+ownerHeld);
            check(minHeldDX<-.2,"owner projectile reverses toward remote mouse minDx="+minHeldDX);
            check(auraFrames>0,"native owner projectile shows remote caster glow");
            if(spec.op=="throw")check(kickPackets==1&&throwImpulse>10,"one E impulse applied to actual projectile kicks="+kickPackets+" impulse="+throwImpulse);
            if(spec.id!="acidgr")check(nativeFrames>=lifeAtBirth-3,"original fuse continues without replacement or early deletion frames="+nativeFrames+" life="+lifeAtBirth);
         } else {
            check(visualFrames>0,"remote projectile is visibly presented");
            check(grabbed&&heldFrames>=3,"Q selects teammate projectile through native cursor and object chain frames="+heldFrames);
            check(minMana<startMana,"native mana charged while holding");
            check(proxyPeak==1&&unexpected==0,"one inert proxy and zero receiver damage projectiles peak="+proxyPeak+" unexpected="+unexpected);
            check(mod.game.gg.teleObj==null,"release or native fuse clears held target");
            var count:int=0;for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)if(o.hasOwnProperty("code")&&o.code=="rconnect-projectile")count++;
            check(count==0,"expired visual leaves no selectable proxy");
         }
         Log.d("PROJECTILE GRIP RESULT "+JSON.stringify({round:round,id:spec.id,op:spec.op,source:source,ownerHeld:ownerHeld,
            heldFrames:heldFrames,minMana:minMana,initialY:initialY,minY:minY,aura:auraFrames,proxies:proxyPeak,kicks:kickPackets,throwDX:throwDX,
            throwImpulse:throwImpulse,minHeldDX:minHeldDX}));
         localDone=true;change("result");send("result");advance();
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1>=cases.length*2){send("done");finish();return;}
         ready=false;prepare(round+1);send("round");
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         mod.game.gg.invulner=true;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         if(phase=="done")return;
         try {
            if(getTimer()-at>(phase=="boot"?180000:45000)){check(false,"timeout "+phase);send("done");finish();return;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(!host)send("ready");else if(ready) {
                  var loc:Object=mod.game.loc;
                  if(loc.spaceX<17||loc.spaceY<11)throw new Error("room too small for fixture");
                  baseX=160;baseY=Math.max(320,Math.min(Math.floor(mod.game.gg.Y/40)*40,(loc.spaceY-2)*40));
                  setup();send("setup",{x:baseX,y:baseY});change("setup");ready=false;
               }
            } else if(phase=="settle"&&host&&ready&&getTimer()-at>1800&&stable()){change("run");send("go");}
            else if(phase=="run"&&ended>0&&getTimer()-ended>1100)complete();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;change("done");timer.stop();
         if(installed){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);}
         if(seedClass!=null&&seedClass.rconnectSeedSource===fixtureSeed)seedClass.rconnectSeedSource=originalSeed;
         Log.d("COOP EFFECTS DONE projectile-grip "+(host?"host":"join"));
      }
   }
}
