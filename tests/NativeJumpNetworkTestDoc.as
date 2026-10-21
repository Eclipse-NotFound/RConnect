package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native keyboard -> native player physics -> ordinary TCP -> final render.
    * The initial fixture placement is the only setPos. No receiving position,
    * jump velocity, native gravity or terrain is supplied by this driver.
    * Ambient AI is frozen: these measurements do not qualify dense performance. */
   public class NativeJumpNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var area:Object,keys:Object={},trace:Array=[],incoming:Array=[];
      private var serial:int=0,sampled:int=-1,frameAt:int=0,previous:int=0;
      private var pulses:int=0,pulseEnd:int=0,grounded:int=0,direction:int=1;
      private var localDone:Boolean=false,peerDone:Boolean=false;
      public function NativeJumpNetworkTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
            e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"native-jump "+label);}
      private function send(stage:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="native-jump-test";p.stage=stage;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function ready():Boolean {
         var b:Object=mod.game,g:Object=b.gg,w:Object=b.world;
         return g!=null&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning()
            &&g.ggControl&&!g.disabled&&g.work!="res"&&g.t_work<=0&&!w.onPause
            &&(!w.vblack.visible||w.vblack.alpha<=0);
      }
      private function arena():Object {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-400;x+=40) {
            var clear:Boolean=true;
            for(var ix:int=0;ix<=360&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=220;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }
            if(!clear)continue;
            for each(var o:Object in l.objs)if(o.X2>x&&o.X1<x+360&&o.Y2>y-220&&o.Y1<y+1){clear=false;break;}
            if(clear)return {x:x,y:y-1,width:360};
         }
         throw new Error("No unmodified native floor/clearance for jump fixture");
      }
      private function setup(p:Object):void {
         area=p;phase="settle";at=getTimer();
         var b:Object=mod.game,g:Object=b.gg;
         b.forceCloseOverlays();g.invulner=true;g.hp=g.maxhp;
         g.setPos(area.x+(host?140:220),area.y);g.setVisPos();
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100001);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function key(code:int,down:Boolean):void {
         if(Boolean(keys[code])==down)return;keys[code]=down;
         mod.stage.dispatchEvent(new KeyboardEvent(down?KeyboardEvent.KEY_DOWN:KeyboardEvent.KEY_UP,true,false,0,code));
      }
      private function before(e:Event):void {
         serial++;frameAt=getTimer();
         var g:Object=mod.game.gg,b:Object=mod.game;
         g.invulner=true;g.hp=g.maxhp;b.world.ctr.active=true;
         var remote:Object=b.getRemoteGhost(host?1:0);
         for each(var u:Object in b.loc.units)if(u!==g&&u!==remote)u.disabled=true;
         if(phase=="settle"&&frameAt-at>1500&&g.stay){phase="moving";at=frameAt;}
         if(phase!="moving")return;
         var age:int=frameAt-at;
         // First half: vertical jumps. Second half: native run plus jumps.
         if(g.X<area.x+80)direction=1;else if(g.X>area.x+280)direction=-1;
         key(65,age>8000&&age<15000&&direction<0);
         key(68,age>8000&&age<15000&&direction>0);
         key(16,age>8000&&age<15000);
         if(g.stay&&!Boolean(keys[32]))grounded++;else grounded=0;
         if(grounded>=8&&age<15000){key(32,true);pulseEnd=serial+4;pulses++;grounded=0;}
         if(Boolean(keys[32])&&serial>=pulseEnd)key(32,false);
         mod.stage.invalidate();
      }
      private function render(e:Event):void {
         if(phase!="moving"||sampled==serial)return;sampled=serial;
         var g:Object=mod.game.gg,p:Object=mod.game.getRemoteGhost(host?1:0),age:int=frameAt-at;
         if(p!=null&&p.vis!=null)trace.push({t:age,dt:previous==0?0:frameAt-previous,
            x:g.X,y:g.Y,stay:g.stay,dy:g.dy,peerX:p.vis.x,peerY:p.vis.y,
            body:p.vis.osn.body.currentFrame});
         previous=frameAt;
         if(age<18000)return;
         var localMin:Number=Infinity,localMax:Number=-Infinity,peerMin:Number=Infinity,peerMax:Number=-Infinity;
         var frames:Object={},count:int=0,stalls:int=0,last:Object;
         for each(var r:Object in trace) {
            localMin=Math.min(localMin,r.y);localMax=Math.max(localMax,r.y);
            peerMin=Math.min(peerMin,r.peerY);peerMax=Math.max(peerMax,r.peerY);frames[r.body]=true;
            if(last!=null&&r.peerY<area.y-20&&Math.abs(r.peerY-last.peerY)<.01)stalls++;
            last=r;
         }
         for(var k:String in frames)count++;
         check(pulses>=3&&localMax-localMin>40,"native keyboard produced repeated jumps pulses="+pulses+" height="+(localMax-localMin));
         check(trace.length>=60&&incoming.length>=25,"actual final render and production snapshots available frames="+trace.length+" snapshots="+incoming.length);
         check(peerMax-peerMin>40,"opposite player actual display rises/falls height="+(peerMax-peerMin));
         check(count>=2,"opposite body animation changes distinct="+count);
         Log.d("NATIVE JUMP TRACE "+(host?"host":"join")+" "+JSON.stringify(trace));
         Log.d("NATIVE JUMP SOURCE "+(host?"host":"join")+" "+JSON.stringify(incoming));
         Log.d("COOP METRIC native-jump "+JSON.stringify({role:host?"host":"join",frames:trace.length,
            pulses:pulses,airborneRepeatedPositions:stalls,diagnosticOnly:true}));
         phase="sampled";key(32,false);key(65,false);key(68,false);key(16,false);
         localDone=true;send("sampled");if(peerDone){send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data,snap:Object=host?p.snap:null;
         if(!host&&p.players is Array)for each(var row:Object in p.players)if(row.id==0)snap=row.snap;
         if(phase=="moving"&&snap!=null)incoming.push({received:getTimer()-at,t:snap.sampleTime,x:snap.x,y:snap.y});
         if(p.type!="native-jump-test")return;
         if(host&&phase=="boot"&&p.stage=="ready"&&ready()) {
            try{var a:Object=arena();setup(a);send("setup",a);}catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
         } else if(!host&&phase=="boot"&&p.stage=="setup")setup(p);
         else if(p.stage=="sampled"){peerDone=true;if(localDone){send("done");finish();}}
         else if(p.stage=="done")finish();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.gg!=null){mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;}
         if(phase=="boot"&&!host&&ready()&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase!="done"&&getTimer()-at>(phase=="boot"?180000:60000)){check(false,"timeout "+phase);send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){key(32,false);key(65,false);key(68,false);key(16,false);
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);}
         Log.d("COOP EFFECTS DONE native-jump "+(host?"host":"join"));
      }
   }
}
