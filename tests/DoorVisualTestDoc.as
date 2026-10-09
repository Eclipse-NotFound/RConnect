package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real Box/Interact doors on both worlds, through the production scene and
    * tile streams. No calls into TerrainSync or handcrafted scene packets. */
   public class DoorVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const IDS:Array=["door1a","door1b","door2a"];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1;
      private var doors:Array=[],baseX:Number,baseY:Number,seen:Dictionary=new Dictionary(),debris:Array=[];
      private var fragments:int=0,acted:Boolean=false,localDone:Boolean=false,peerDone:Boolean=false;
      public function DoorVisualTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            e.preventDefault();check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"door-visual "+s+" round="+round);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="door-visual-test";p.op=op;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function setup():void {
         var loc:Object=mod.game.loc,cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
         mod.game.gg.anim();mod.game.gg.invulner=true;mod.game.gg.disabled=true;
         // Each side constructs the same stable object key. Opening is still
         // performed by only one side, and has to reach the other through TCP.
         for(var i:int=0;i<IDS.length;i++) {
            var door:Object=new cls(loc,IDS[i],int(baseX+i*80),int(baseY),<obj lock="0" mine="0"/>,null);
            loc.addObj(door);loc.objs.push(door);door.inter.setAct("lock",0);door.inter.setAct("open",0);doors.push(door);
            check(door.tiles.length>0 && door.vis.stage!=null,"native door constructed id="+door.id+" name="+door.nazv);
         }
         var e:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr;
         for each(var id:String in ["schep","metal","kusok","kusokB","kusokD","steklo"])
            debris.push({cls:e[id].visClass,bitmap:e[id].blit?mod.game.world.grafon.getSpriteList(e[id].blit,1):null});
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
         phase="warm";at=getTimer();
      }
      private function begin(n:int):void {round=n;acted=localDone=peerDone=false;fragments=0;seen=new Dictionary();phase="watch";at=getTimer();}
      private function source():Boolean {return host==(int(round/6)%2==1);}
      private function current():Object {return doors[int(round/12)];}
      private function opening():Boolean {return round%2==0;}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="door-visual-test")return;
         if(host && p.op=="ready" && phase=="boot") {
            baseX=Math.max(100,Math.min(Math.floor(mod.game.gg.X/40)*40+100,mod.game.loc.limX-300));
            baseY=Math.floor(mod.game.gg.Y/40)*40;setup();send("setup",{x:baseX,y:baseY});
         } else if(!host && p.op=="setup" && phase=="boot") {baseX=p.x;baseY=p.y;setup();send("installed");}
         else if(host && p.op=="installed" && phase=="warm"){phase="ready";at=getTimer();}
         else if(!host && p.op=="round"){begin(int(p.round));send("round-ready",{round:round});}
         else if(host && p.op=="round-ready" && int(p.round)==round){phase="watch";at=getTimer();send("go",{round:round});}
         else if(!host && p.op=="go" && int(p.round)==round){at=getTimer();}
         else if(host && p.op=="result" && int(p.round)==round){peerDone=true;advance();}
         else if(p.op=="done")finish();
      }
      private function before(e:Event):void {
         mod.game.forceCloseOverlays();var g:Object=mod.game.gg;
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.setPos(baseX-65,baseY);g.setVisPos();
         for each(var u:Object in mod.game.loc.units)if(u!==g){u.disabled=true;u.invulner=true;}
         mod.stage.invalidate();
      }
      private function render(e:Event):void {
         if(phase!="watch" || round<0)return;
         for(var p:Object=mod.game.loc.firstObj,guard:int=0;p!=null && guard++<10000;p=p.nobj) {
            if(getQualifiedClassName(p)!="fe.graph::Part" || seen[p])continue;
            seen[p]=true;
            for each(var d:Object in debris)if(d.cls!=null && p.vClass===d.cls || d.bitmap!=null && p.blitData===d.bitmap){fragments++;break;}
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(phase=="done")return;
         if(getTimer()-at>70000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="ready"&&getTimer()-at>1800){begin(0);phase="await-round";send("round",{round:0});}
         if(phase!="watch")return;
         if(source()&&!acted&&getTimer()-at>400){acted=true;current().inter.setAct("open",opening()?1:0);}
         if(getTimer()-at>1800 && !localDone) {
            var door:Object=current();
            check(!door.dead && door.inter.open==opening(),"open/close state reaches both worlds id="+door.id+" open="+opening());
            check(fragments==0,"open/close emits no wall destruction parts="+fragments+" id="+door.id);
            var collision:Boolean=true;
            for each(var tile:Object in door.tiles)collision=collision && int(tile.phis)==(opening()?0:1);
            check(collision,"native door collision follows open state");
            localDone=true;send("result",{round:round});advance();
         }
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1>=IDS.length*12){send("done");finish();return;}
         begin(round+1);phase="await-round";send("round",{round:round});
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);}
         Log.d("COOP EFFECTS DONE door-visual "+(host?"host":"join"));
      }
   }
}
