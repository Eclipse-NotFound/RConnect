package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.events.TimerEvent;
 import flash.events.UncaughtErrorEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.media.SoundMixer;
 import flash.system.ApplicationDomain;
 import flash.utils.Dictionary;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 import flash.utils.getQualifiedClassName;
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 public class DoorCycleProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
  private var phase:String="boot",boot:int=getTimer(),at:int,readyAt:int=0,peerReady:Boolean=false,peerDone:Boolean=false;
  private var doors:Array=[],checks:Array=[],trace:Array=[],seen:Dictionary=new Dictionary(true),counts:Array=[0,0,0];
  private var debris:Array=[],baseX:Number,baseY:Number,toggle:int=-1,replayDone:Boolean=false,breakDone:Boolean=false,done:Boolean=false;
  public function DoorCycleProbe(){
   var id:String=NativeApplication.nativeApplication.applicationID;
   if(id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;host=id.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();finish(false,e.error is Error?Error(e.error).getStackTrace():String(e.error));});
   timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function send(op:String,data:Object=null):void {data=data||{};data.type="door-cycle-probe";data.op=op;
   if(host)mod.session.server.broadcast(data);else mod.session.link.send(data);}
  private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
  private function ready():Boolean {var g:Object=mod.game.gg,b:Object=mod.game;
   return g!=null&&g.sost==1&&g.ggControl&&g.t_work==0&&g.work==""&&b.world.t_die==0&&!b.world.onPause
    &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning();}
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
   if(phase=="boot"&&ready()){
    if(host&&peerReady){baseX=Math.max(120,Math.min(500,mod.game.loc.limX-480));baseY=Math.max(200,Math.min(560,mod.game.loc.limY-80));setup();send("setup",{x:baseX,y:baseY});}
    else if(!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
   }
   if(phase!="done"&&getTimer()-boot>120000)finish(false,"timeout "+phase);
  }
  private function receive(e:NetMessageEvent):void {
   var p:Object=e.data;if(p.type!="door-cycle-probe")return;
   if(host&&p.op=="ready"&&phase=="boot")peerReady=true;
   else if(!host&&p.op=="setup"&&phase=="boot"){baseX=p.x;baseY=p.y;setup();send("installed");}
   else if(host&&p.op=="installed"){phase="run";at=getTimer();send("start");}
   else if(!host&&p.op=="start"){phase="run";at=getTimer();}
   else if(p.op=="sampled"){peerDone=true;if(done){send("done");finish(true);}}
   else if(p.op=="done")finish(true);
  }
  private function check(ok:Boolean,label:String):void {checks.push({ok:ok,label:label});}
  private function setup():void {
   var b:Object=mod.game,g:Object=b.gg,l:Object=b.loc;
   b.forceCloseOverlays();g.invulner=true;g.hp=g.maxhp;g.setPos(100,baseY);g.setVisPos();
   var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
   for(var i:int=0;i<3;i++){
    var d:Object=new cls(l,i==2?"window1":"door1a",int(baseX+i*140),int(baseY),<obj lock="0" mine="0"/>,null);
    l.addObj(d);l.objs.push(d);if(d.inter!=null)d.inter.setAct("lock",0);d.setDoor(false);doors.push(d);
    check(d.tiles.length>0&&d.vis.stage!=null,"native fixture "+i);
   }
   var em:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr;
   for each(var name:String in ["schep","steklo","metal"]){var v:Object=em[name];debris.push({cls:v.visClass,bitmap:v.blit?b.world.grafon.getSpriteList(v.blit,1):null});}
   mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
   mod.stage.addEventListener(Event.RENDER,sample,false,-30000);phase="warm";
  }
  private function countNew():int {
   var n:int=0;
   for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj){
    if(getQualifiedClassName(o)!="fe.graph::Part"||seen[o])continue;seen[o]=true;
    for each(var d:Object in debris)if(d.cls!=null&&o.vClass===d.cls||d.bitmap!=null&&o.blitData===d.bitmap){n++;break;}
   }return n;
  }
  private function drive(e:Event):void {
   if(phase!="run")return;var age:int=getTimer()-at,g:Object=mod.game.gg;
   g.invulner=true;g.disabled=true;mod.game.world.ctr.keyAttack=false;
   if(!replayDone&&age>1500){replayDone=true;countNew();
    var c:Class=ApplicationDomain.currentDomain.getDefinition("rconnect.game.TerrainSync") as Class;
    var terrain:Object=new c(),d:Object=doors[0];terrain.hostPatch(mod.game.loc);d.setDoor(true);
    var patch:Array=terrain.hostPatch(mod.game.loc);d.setDoor(false);terrain.apply(mod.game.loc,patch,true);
    counts[0]+=countNew();check(counts[0]==0,"stale open terrain emits no debris");
    check(d.tiles[0].phis==d.phis&&d.tiles[0].opac==d.door_opac,"stale terrain preserves native closed collision");
    check(terrain.dirty==false,"door-only packet does not redraw whole room");
    d.setDoor(false);
   }
   if(!host&&age>=3500&&age<8500){var step:int=int((age-3500)/120);if(step!=toggle){toggle=step;doors[1].inter.setAct("open",step%2==0?1:0);}}
   if(!host&&age>=8500&&toggle!=-2){toggle=-2;doors[1].inter.setAct("open",0);}
   if(!host&&age>=11000&&!breakDone){breakDone=true;doors[1].damage(doors[1].hp+doors[1].thre+100);doors[2].damage(doors[2].hp+doors[2].thre+100);}
   mod.stage.invalidate();
  }
  private function sample(e:Event):void {
   if(phase!="run")return;var age:int=getTimer()-at,n:int=countNew();
   if(age<10500)counts[1]+=n;else counts[2]+=n;
   trace.push({age:age,open:doors[1].inter.open,phis:doors[1].tiles[0].phis,dead:doors[1].dead,parts:n});
   if(age<14500)return;
   check(counts[1]==0,"rapid native open/close emits no destruction particles");
   check(doors[1].dead&&doors[2].dead,"native damage really destroys door and window on both sides");
   check(counts[2]>=24,"real door/window destruction still has native fragments "+counts[2]);
   phase="sampled";done=true;send("sampled");if(peerDone){send("done");finish(true);}
  }
  private function finish(ok:Boolean,error:String=""):void {
   if(phase=="done")return;phase="done";timer.stop();for each(var c:Object in checks)if(!c.ok)ok=false;
   if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({role:host?"host":"join",completed:ok,error:error,audioVolume:SoundMixer.soundTransform.volume,checks:checks,trace:trace,counts:counts}));s.close();
   NativeApplication.nativeApplication.exit(ok?0:1);
  }
 }
}
