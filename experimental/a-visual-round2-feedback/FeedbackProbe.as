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
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 /** External semantic probe. Native Emitter/Unit.damageWall; not proof of E-key input. */
 public class FeedbackProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),started:int=getTimer(),at:int=0,phase:int=-1;
  private var links:Dictionary=new Dictionary(),readyPeer:Boolean=false,lastReady:int=0,peerDone:Boolean=false;
  private var target:Object,bubble:Object,checks:Array=[],rows:Array=[],packets:Array=[],seen:Object={},ended:Object={};
  private var cancelled:Boolean=false,duplicate:Boolean=false,done:Boolean=false;
  public function FeedbackProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;
   if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();finish(false,String(e.error));
   });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function watch(l:TcpLink):void {if(l==null||links[l])return;links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}
  private function send(op:String,p:Object=null):void {p=p||{};p.type="feedback-probe";p.op=op;
   if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
  private function check(ok:Boolean,s:String):void {checks.push({ok:ok,label:s});}
  private function receive(e:NetMessageEvent):void {
   var p:Object=e.data;
   if(p.type=="native-text"&&!host) {
    packets.push(p);for each(var item:Object in p.items){if(item.ended)ended[item.id]=true;else seen[item.kind]=true;}
   }
   if(p.type!="feedback-probe")return;
   if(host&&p.op=="ready")readyPeer=true;
   else if(!host&&p.op=="start"){phase=0;at=getTimer();mod.game.forceCloseOverlays();mod.game.world.showHit=1;}
   else if(!host&&p.op=="mode")mod.game.world.showHit=int(p.value);
   else if(p.op=="sampled"){peerDone=true;if(host&&done){send("done");finish(true);}}
   else if(p.op=="done")finish(true);
  }
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
   if(getTimer()-started>65000){finish(false,"timeout");return;}
   var b:Object=mod.game,g:Object=b.gg;
   if(b.world!=null&&b.world.verror!=null&&b.world.verror.visible){finish(false,String(b.world.verror.txt.text));return;}
   if(phase<0&&g!=null&&g.sost==1&&g.ggControl&&g.t_work==0&&g.work==""&&b.world.t_die==0&&!b.world.onPause
      &&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning()) {
    if(host&&readyPeer){setup();phase=0;at=getTimer();send("start");
     mod.stage.addEventListener(Event.ENTER_FRAME,function(e:Event):void {if(!done&&phase>=0&&phase!=99)drive(getTimer()-at);},false,97000);}
    else if(!host&&getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
   }
   if(phase<0||done)return;
   var age:int=getTimer()-at;
   sample(age);
   if(age>11000) {
    done=true;
    if(host)check(duplicate,"repeated identical speech packet sent through real TCP");
    else {check(seen.replic===true,"native speech packet received");check(seen.numb===true,"native throw number packet received");}
    check(rows.length>50,"native display samples");send("sampled");if(host&&peerDone){send("done");finish(true);}
   }
  }
  private function setup():void {
   var b:Object=mod.game;b.forceCloseOverlays();b.gg.invulner=true;b.world.showHit=1;
   var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
   target=new cls("1",100,<unit tr="1" vis="right"/>,null);target.id="feedback_probe_raider";
   target.putLoc(b.loc,b.gg.X+100,b.gg.Y);b.loc.addObj(target);b.loc.units.push(target);
   target.disabled=true;target.noAgro=true;target.maxhp=target.hp=10000;target.showNumbs=true;
  }
  private function drive(age:int):void {
   var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
   if(phase==0&&age>700) {
    bubble=emitter.arr["replic"].cast(mod.game.loc,target.X,target.Y-110,{txt:"RConnect 原生话语",ry:0});
    check(bubble!=null,"actual native replic Part");phase=1;
   }
   if(phase==1&&age>1800) {bubble.remVisual();if(bubble.in_chain)bubble.setNull();cancelled=true;phase=2;}
   if(phase==2&&age>2300) {
    target.dx=32;target.dy=0;target.t_throw=45;
    trackThrow();
    target.damageWall(1);check(target.hp<10000,"native collision settled damage");phase=3;
   }
   if(phase==3&&age>4300) {
    mod.game.world.showHit=2;send("mode",{value:2});phase=4;
   }
   if(phase==4&&age>4700) {target.dx=31;target.t_throw=45;trackThrow();target.damageWall(1);phase=5;}
   if(phase==5&&age>4800) {target.dx=30;target.t_throw=1;trackThrow();target.damageWall(1);phase=6;}
   if(!duplicate&&age>6500) {
    // Dedicated repeated native-text fixture uses a new isolated id, so it
    // checks receiver idempotence without altering an actual damage record.
    var packet:Object=mod.session.rooms.stamp({type:"native-text",items:[{id:900000,revision:1,kind:"replic",txt:"去重测试",
     x:target.X,y:target.Y-130,dx:0,dy:0,ddy:0,brake:1,life:15,maxLife:15,move:false,alph:true,prealph:false,
     frame:1,sx:1,sy:1,alpha:1,color:0xffffff}]});
    mod.session.server.broadcast(packet);mod.session.server.broadcast(packet);duplicate=true;
   }
  }
  private function trackThrow():void {
   ApplicationDomain.currentDomain.getDefinition("rconnect.game.NativeTextVisuals").watchThrow(target,mod.session.peers[0].link);
  }
  private function sample(age:int):void {
   var out:Array=[],o:Object=mod.game.loc.firstObj;
   for(var n:int=0;o!=null&&n++<8192;o=o.nobj) {
    var v:Object=o.vis;if(v==null)continue;
    try {if(v.numb!=null)out.push({kind:"numb",txt:String(v.numb.text),color:uint(v.numb.textColor),frame:int(v.currentFrame),x:v.x,y:v.y,sx:v.scaleX,life:o.liv});}catch(e:*){}
    try {if(v.text!=null&&v.text.text!=null)out.push({kind:"speech",txt:String(v.text.text.text),color:uint(v.text.text.textColor),x:v.x,y:v.y,life:o.liv});}catch(error:*){}
   }
   rows.push({age:age,parts:out});
  }
  private function finish(ok:Boolean,error:String=""):void {
   if(phase==99)return;phase=99;timer.stop();
   for each(var c:Object in checks)if(!c.ok)ok=false;
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({completed:ok,error:error,role:host?"host":"join",audioVolume:SoundMixer.soundTransform.volume,
    checks:checks,rows:rows,packets:packets,scope:"native cast/collision feedback; E-key input not exercised"}));s.close();
   NativeApplication.nativeApplication.exit(ok?0:1);
  }
 }
}
