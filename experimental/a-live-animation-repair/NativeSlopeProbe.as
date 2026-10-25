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
 import rconnect.game.GameBridge;
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 public class NativeSlopeProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary(),keys:Object={};
  private var phase:String="boot",at:int=getTimer(),ping:int=0,serial:int=0,sampled:int=-1;
  private var rows:Array=[],done:Boolean=false,peerDone:Boolean=false;
  public function NativeSlopeProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
   host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
   });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"native-slope "+s);}
  private function send(op:String,p:Object=null):void {p=p||{};p.type="native-slope-probe";p.op=op;
   if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
  private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
  private function ready():Boolean {var g:Object=mod.game.gg;return g!=null&&g.sost==1&&g.t_work==0&&g.ggControl&&!g.disabled
   &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game==null)return;
   if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
   if(phase=="boot"&&!host&&ready()&&getTimer()-ping>500){ping=getTimer();send("ready");}
   if(phase!="done"&&getTimer()-at>60000){check(false,"timeout "+phase);finish();}
  }
  private function stairs():Object {
   var l:Object=mod.game.loc;
   for each(var column:Object in l.space)for each(var tile:Object in column) {
    if(tile==null||tile.diagon==0)continue;
    var x:Number=(tile.phX1+tile.phX2)/2,y:Number=tile.getMaxY(x),clear:Boolean=true;
    for(var dy:int=20;dy<=100;dy+=20)if(l.getAbsTile(x,y-dy).phis==1)clear=false;
    var near:Object=l.getAbsTile(x+40,y-40*Number(tile.diagon));
    if(clear&&near.diagon==tile.diagon)return {x:x,y:y,sign:tile.diagon,phis:tile.phis};
   }
   return {x:460,y:500,sign:1,phis:0,fixture:true};
  }
  private function receive(e:NetMessageEvent):void {
   var p:Object=e.data;if(p.type!="native-slope-probe")return;
   if(host&&p.op=="ready"&&phase=="boot"&&ready()){var site:Object=stairs();setup(site);send("setup",site);}
   else if(!host&&p.op=="setup"&&phase=="boot"){setup(p);send("installed");}
   else if(host&&p.op=="installed"){phase="running";at=getTimer();send("start");}
   else if(!host&&p.op=="start"){phase="running";at=getTimer();}
   else if(p.op=="sampled"){peerDone=true;if(done){send("done");finish();}}
   else if(p.op=="done")finish();
  }
  private function setup(site:Object):void {
   var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();
   if(site.fixture) {
    // Native map decoder and the shipped steel-stair form, only in this
    // disposable room. Physics/control/animation thereafter remain native.
    var l:Object=b.loc;
    if(l.limX<800||l.limY<680)throw new Error("Fixture does not fit native room");
    for(var x:int=320;x<760;x+=40)for(var y:int=160;y<640;y+=40)l.getAbsTile(x,y).dec("_");
    for(var i:int=0;i<8;i++)l.getAbsTile(320+i*40,600-i*40).dec("_\u0418");
    for each(var box:Object in l.objs.concat())if(box.X2>320&&box.X1<760&&box.Y2>160&&box.Y1<640){
     l.remObj(box);l.objs.splice(l.objs.indexOf(box),1);var unit:Object=GameBridge.probe(box,"un");
     if(l.units.indexOf(unit)>=0)l.units.splice(l.units.indexOf(unit),1);
    }
    l.isRebuild=true;l.isRelight=true;
    check(l.getAbsTile(460,500).diagon==1&&l.getAbsTile(460,500).phis==0,"native pass-through diagonal form decoded");
   }
   if(g.animOff===true&&g.work==""&&g.t_work==0)g.anim();
   g.invulner=true;g.hp=g.maxhp;g.dx=g.dy=0;g.setPos(site.x,site.y-2);g.setVisPos();
   Log.d("NATIVE SLOPE SITE "+JSON.stringify(site));
   mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100001);
   mod.stage.addEventListener(Event.RENDER,sample,false,-30000);phase="warm";at=getTimer();
  }
  private function key(code:int,down:Boolean):void {if(Boolean(keys[code])==down)return;keys[code]=down;
   mod.stage.dispatchEvent(new KeyboardEvent(down?KeyboardEvent.KEY_DOWN:KeyboardEvent.KEY_UP,true,false,0,code));}
  private function before(e:Event):void {
   serial++;if(phase!="running")return;
   var age:int=getTimer()-at,b:Object=mod.game,g:Object=b.gg;
   b.forceCloseOverlays();b.world.ctr.active=true;g.invulner=true;
   var remote:Object=b.getRemoteGhost(host?1:0);
   for each(var u:Object in b.loc.units)if(u!==g&&u!==remote)u.disabled=true;
   key(68,age>=2000&&age<2200);key(65,age>=6500&&age<6700);mod.stage.invalidate();
  }
  private function pose(u:Object):Object {if(u==null)return null;var b:Object=u.vis.osn.body;
   return {x:u.X,y:u.Y,dx:u.dx,dy:u.dy,stay:u.stay,anim:u.animState,label:u.vis.osn.currentLabel,body:b.currentFrame,playing:b.isPlaying};}
  private function sample(e:Event):void {
   if(phase!="running"||sampled==serial)return;sampled=serial;var age:int=getTimer()-at;
   rows.push({age:age,local:pose(mod.game.gg),peer:pose(mod.game.getRemoteGhost(host?1:0))});
   if(age<11000)return;
   var count:int=0,bad:int=0,walk:int=0;
   for each(var r:Object in rows) {
    if(r.local.anim=="trot_up"||r.local.anim=="trot_down")walk++;
    if(!(r.age>3200&&r.age<6000||r.age>7800&&r.age<10500)||r.peer==null)continue;
    if(r.local.anim!="diag_up"&&r.local.anim!="diag_down")continue;
    count++;if(r.peer.body!=1||r.peer.playing)bad++;
   }
   Log.d("NATIVE SLOPE TRACE "+JSON.stringify({role:host?"host":"join",rows:rows}));
   check(walk>0,"native keyboard walks along diagonal samples="+walk);
   check(count>100,"native stationary diagonal samples="+count);
   check(bad==0,"remote stopped pose mismatches="+bad);
   done=true;phase="sampled";send("sampled");if(peerDone){send("done");finish();}
  }
  private function finish():void {if(phase=="done")return;phase="done";timer.stop();if(mod!=null){key(65,false);key(68,false);
   mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,sample);}
   Log.d("COOP EFFECTS DONE native-slope "+(host?"host":"join"));}
 }
}
