package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native slope pose and Box.damage, through unmodified production TCP. */
   public class AnimationRepairProbe extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var baseX:Number,baseY:Number,doors:Array=[],rows:Array=[],parts:Dictionary=new Dictionary(),debris:Array=[];
      private var broken:Array=[false,false],counts:Array=[0,0],done:Boolean=false,peerDone:Boolean=false;
      private var readyLocal:Boolean=false;
      public function AnimationRepairProbe() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"animation-repair "+s);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="animation-repair-probe";p.op=op;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function ready():Boolean {
         var b:Object=mod.game,g:Object=b.gg;
         return g!=null && mod.session.rooms.ready && !mod.session.rooms.busy && !b.isTransitioning()
            && g.sost==1 && g.t_work==0 && !b.world.onPause;
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.session==null || mod.game==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(phase=="boot" && ready()) {
            readyLocal=true;
            if(!host && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         }
         if(phase!="done" && getTimer()-at>60000){check(false,"timeout "+phase);finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="animation-repair-probe")return;
         if(host && p.op=="ready" && phase=="boot" && readyLocal) {
            baseX=Math.max(120,Math.min(Math.floor(mod.game.gg.X/40)*40,mod.game.loc.limX-360));
            baseY=Math.max(160,Math.min(Math.floor(mod.game.gg.Y/40)*40,mod.game.loc.limY-40));
            setup();send("setup",{x:baseX,y:baseY});
         } else if(!host && p.op=="setup" && phase=="boot") {
            baseX=p.x;baseY=p.y;setup();send("installed");
         } else if(host && p.op=="installed") {phase="running";at=getTimer();send("start");}
         else if(!host && p.op=="start") {phase="running";at=getTimer();}
         else if(p.op=="sampled"){peerDone=true;if(done){send("done");finish();}}
         else if(p.op=="done")finish();
      }
      private function setup():void {
         var b:Object=mod.game,g:Object=b.gg,loc:Object=b.loc;
         b.forceCloseOverlays();if(g.animOff===true && g.work=="" && g.t_work==0)g.anim();
         check(g.animOff===false,"source native animation unlocked");
         g.invulner=true;g.hp=g.maxhp;g.disabled=true;
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
         for(var i:int=0;i<2;i++) {
            var d:Object=new cls(loc,i==0?"door1a":"window1",int(baseX+120+i*120),int(baseY),<obj lock="0" mine="0"/>,null);
            loc.addObj(d);loc.objs.push(d);if(d.inter!=null)d.inter.setAct("lock",0);doors.push(d);
            check(d.tiles.length>0 && d.vis.stage!=null,"real destructible fixture "+d.id);
         }
         var em:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr;
         for each(var n:String in ["schep","steklo","metal"])
            debris.push({id:n,cls:em[n].visClass,bitmap:em[n].blit?b.world.grafon.getSpriteList(em[n].blit,1):null});
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
         phase="warm";at=getTimer();
      }
      private function drive(e:Event):void {
         if(phase!="running")return;
         var age:int=getTimer()-at,g:Object=mod.game.gg;
         mod.game.forceCloseOverlays();g.disabled=true;g.invulner=true;g.stay=true;g.dx=g.dy=0;
         g.isLaz=0;g.isFly=false;g.isPlav=false;g.storona=1;
         // Use the native public collision method: Unit.diagon is protected.
         // Each player stands at the centre of a one-way diagonal tile.
         var px:Number=baseX+20+(host?0:40),py:Number=baseY+30;
         var tile:Object=mod.game.loc.getAbsTile(px,py);
         tile.diagon=age<5000?1:(age<10000?-1:0);tile.phis=2;
         g.setPos(px,py);var floor:Number=g.checkDiagon(0);
         if(floor!=0)g.setPos(px,floor);
         g.setVisPos();g.animate();
         if(!host)for(var i:int=0;i<2;i++)if(age>13000+i*5000&&!broken[i]) {
            broken[i]=true;doors[i].damage(Number(doors[i].hp)+Number(doors[i].thre)+100);
            check(doors[i].dead===true,"local damage destroys "+doors[i].id);
         }
         mod.stage.invalidate();
      }
      private function pose(u:Object):Object {
         if(u==null)return null;
         var o:Object=u.vis.osn,b:Object=o.body;
         return {x:u.X,y:u.Y,dx:u.dx,dy:u.dy,diagon:GameBridge.probe(u,"diagon"),anim:u.animState,
            label:o.currentLabel,frame:o.currentFrame,body:b.currentFrame,playing:b.isPlaying};
      }
      private function sample(e:Event):void {
         if(phase!="running")return;
         var age:int=getTimer()-at;
         rows.push({age:age,local:pose(mod.game.gg),peer:pose(mod.game.getRemoteGhost(host?1:0))});
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(getQualifiedClassName(o)!="fe.graph::Part"||parts[o])continue;parts[o]=true;
            for each(var d:Object in debris)if(d.cls!=null&&o.vClass===d.cls||d.bitmap!=null&&o.blitData===d.bitmap) {
               if(age>=12500&&age<17500)counts[0]++;if(age>=17500&&age<22500)counts[1]++;break;
            }
         }
         if(age<23000)return;
         var measured:int=0,mismatch:int=0,sourceStill:int=0,peerChanges:int=0,previous:Object=null;
         for each(var r:Object in rows) {
            if(!(r.age>1200&&r.age<4700||r.age>6200&&r.age<9700)||r.peer==null){previous=null;continue;}
            measured++;if(r.local.body==1&&!r.local.playing)sourceStill++;
            if(r.peer.body!=1||r.peer.playing)mismatch++;
            if(previous!=null&&previous.peer.body!=r.peer.body)peerChanges++;previous=r;
         }
         Log.d("ANIMATION REPAIR TRACE "+JSON.stringify({role:host?"host":"join",rows:rows,parts:counts,measured:measured,mismatch:mismatch,sourceStill:sourceStill,peerChanges:peerChanges}));
         check(measured>150,"slope final render samples="+measured);
         check(sourceStill==measured,"native slope stays at stopped frame1 count="+sourceStill);
         check(mismatch==0,"remote slope stopped frame1 mismatches="+mismatch+" bodyChanges="+peerChanges);
         for(var i:int=0;i<2;i++) {
            check(doors[i].dead===true,"remote destruction state "+doors[i].id);
            check(counts[i]>0,"destruction particles "+doors[i].id+" count="+counts[i]);
         }
         done=true;phase="sampled";send("sampled");if(peerDone){send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE animation-repair "+(host?"host":"join"));
      }
   }
}
