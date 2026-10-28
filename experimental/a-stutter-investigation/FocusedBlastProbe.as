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
 import flash.utils.Dictionary;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 import flash.utils.getQualifiedClassName;
 import rconnect.game.GameBridge;
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 /** Isolates native explosion-record lifetime. Not a collision/visual performance test.
  * Actual NPC Weapon.attack/step creates each rocket. Public Bullet.explosion()
  * invokes native explBlast/explBullet; no synthetic shot or network record.
  */
 public class FocusedBlastProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
  private var phase:String="boot",started:int=getTimer(),lastReady:int=0,at:int,serial:int=0,sampled:int=-1;
  private var shooter:Object,gun:Object,lastBullet:Object,targets:Array=[],baseX:Number=300,baseY:Number=500;
  private var rows:Array=[],blasts:Array=[],wire:Array=[],seen:Dictionary=new Dictionary(true),invisibleBirths:int=0;
  private var byteCount:int=0,done:Boolean=false,peerDone:Boolean=false,lastWire:Object={},lastFrame:int=0;
  public function FocusedBlastProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;
   if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();finish(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
   });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function send(op:String,p:Object=null):void {p=p||{};p.type="focused-blast-probe";p.op=op;
   if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
  private function watch(l:TcpLink):void {if(l==null||links[l])return;links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
   var b:Object=mod.game,g:Object=b.gg;
   if(b.world!=null&&b.world.verror!=null&&b.world.verror.visible){finish(false,String(b.world.verror.txt.text));return;}
   if(phase=="boot"&&g!=null&&g.sost==1&&g.t_work==0&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning())
    if(!host&&getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
   if(phase!="done"&&getTimer()-started>120000)finish(false,"timeout "+phase);
  }
  private function spawn(id:String,map:XML,x:Number,y:Number):Object {
   var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
   var u:Object=new cls("1",100,map,null);u.id=id;u.putLoc(mod.game.loc,x,y);
   mod.game.loc.addObj(u);mod.game.loc.units.push(u);u.disabled=true;u.noAgro=true;u.trigDis=true;
   u.doop=true;u.lootIsDrop=true;u.xp=0;u.hp=u.maxhp=100000;u.dx=u.dy=0;return u;
  }
  private function setup():void {
   var b:Object=mod.game,g:Object=b.gg,l:Object=b.loc;b.forceCloseOverlays();l.base=false;l.black=false;b.world.black=false;
   baseX=Math.max(240,Math.min(400,l.limX-300));baseY=Math.max(320,Math.min(560,l.limY-120));
   for(var x:int=1;x<l.spaceX-1;x++)for(var y:int=1;y<l.spaceY-1;y++) {
    var tile:Object=l.space[x][y];tile.phis=y*40>=baseY+80?1:0;tile.opac=tile.phis;tile.front="";tile.water=0;
    tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
   }
   for each(var u:Object in l.units)if(u!==g){u.disabled=true;u.noAgro=true;u.trigDis=true;}
   g.disabled=true;g.invulner=true;g.hp=g.maxhp;g.dx=g.dy=0;g.setPos(baseX-160,baseY);g.setVisPos();
   if(host) {
    shooter=spawn("blastprobe_source",<unit tr="1" weap="mlau" vis="right"/>,baseX,baseY);
    shooter.invulner=true;gun=shooter.currentWeapon;
    if(gun==null||gun.id!="mlau"||gun.owner!==shooter)throw new Error("Native NPC rocket weapon missing");
    for(var n:int=0;n<8;n++)targets.push(spawn("blastprobe_target_"+n,<unit tr="1" weap=""/>,baseX+55+n*4,baseY));
   }
   b.world.redrawLoc();b.world.cam.setZoom(2);
   // Native Location.step has already executed; production observation is -10000.
   // Thus real invisible probes remain in the chain for ordinary RC observation.
   mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
   mod.stage.addEventListener(Event.RENDER,sample,false,-2147483647);phase="prepared";
  }
  private function chain():Object {
   var total:int=0,blank:int=0,newBlank:int=0,guard:int=0,classes:Object={};
   for(var o:Object=GameBridge.probe(mod.game.loc,"firstObj");o!=null&&guard++<16384;o=GameBridge.probe(o,"nobj")) {
    if(GameBridge.probe(o,"weap")!==gun)continue;total++;
    if(GameBridge.probe(o,"vis")!=null)continue;blank++;
    var cls:String=getQualifiedClassName(o);classes[cls]=int(classes[cls])+1;
    if(!seen[o]){seen[o]=true;newBlank++;invisibleBirths++;}
   }
   return {total:total,invisible:blank,newInvisible:newBlank,classes:classes};
  }
  private function blast(bullet:Object):void {
   var old:Array=[],before:Object=chain();
   for each(var u:Object in targets) {
    old.push({unit:u,disabled:u.disabled,trigDis:u.trigDis,invulner:u.invulner});
    // Native explBlast excludes all three flags. Eligibility is opened only
    // synchronously for this real explosion; no AI/game step occurs here.
    u.disabled=false;u.trigDis=false;u.invulner=false;u.hp=u.maxhp;u.dx=u.dy=0;
    u.setPos(bullet.X+18+old.length*5,bullet.Y+u.scY/2+6);u.setVisPos();
   }
   var record:Object={age:getTimer()-at,at:getTimer(),x:bullet.X,y:bullet.Y,
    nativeClass:getQualifiedClassName(bullet),explRadius:bullet.explRadius,explTip:bullet.explTip,
    isExplBefore:bullet.isExpl,chainBefore:before,targetCount:targets.length};
   try {bullet.explosion();}
   finally {for each(var saved:Object in old){saved.unit.disabled=saved.disabled;saved.unit.trigDis=saved.trigDis;saved.unit.invulner=saved.invulner;}}
   record.isExplAfter=bullet.isExpl;record.chainAfter=chain();blasts.push(record);
  }
  private function drive(e:Event):void {
   serial++;if(phase!="run")return;var age:int=getTimer()-at;
   var b:Object=mod.game,g:Object=b.gg;g.disabled=true;g.invulner=true;
   for each(var unit:Object in b.loc.units)unit.disabled=true;
   if(host) {
    shooter.disabled=true;shooter.dx=shooter.dy=0;shooter.storona=1;shooter.setPos(baseX,baseY);shooter.setVisPos();
    shooter.celX=baseX+1000;shooter.celY=baseY-35;shooter.setWeaponPos(gun.tip);gun.findCel=false;gun.forceRot=0;
    gun.hold=Math.max(999,gun.hold);gun.hp=gun.maxhp;
    if(age>=2000&&age<22000)gun.attack();
    gun.step(); // Disabled NPC: one actual Weapon.step, not an extra native step.
    if(gun.b!=null&&gun.b!==lastBullet){lastBullet=gun.b;if(age>=2000&&age<22000)blast(gun.b);}
   }
   mod.stage.invalidate();
  }
  private function sample(e:Event):void {
   if(phase!="run"||sampled==serial)return;sampled=serial;
   var now:int=getTimer(),age:int=now-at;
   rows.push({at:now,age:age,phase:age<2000?"cold":age<22000?"blast":"cleanup",gap:lastFrame>0?now-lastFrame:0,
    chain:host?chain():null,latestWire:lastWire});lastFrame=now;
   if(age<27000)return;
   done=true;phase="sampled";send("sampled");if(host&&peerDone){send("done");finish(true);}
  }
  private function inspectUnit(u:Object,stream:String):void {
   if(u==null||u.id!="blastprobe_source")return;
   var count:int=0,blank:int=0,frames:int=0,keys:Array=[];
   for each(var w:Object in u.weapons)if(w.id=="mlau")for each(var shot:Object in w.events) {
    count++;if(shot.flight==null){blank++;keys.push(w.stream+":"+shot.seq);}
    else if(shot.flight.frames is Array)frames+=shot.flight.frames.length;
   }
   var record:Object={at:getTimer(),age:getTimer()-at,stream:stream,sampleTime:u.sampleTime,events:count,nullFlights:blank,frames:frames,nullKeys:keys};
   wire.push(record);lastWire=record;
  }
  private function receive(e:NetMessageEvent):void {
   try {
    var p:Object=e.data;
    if(!host&&phase=="run")for each(var stream:String in ["units","enemyMotion"])if(p[stream] is Array)
     for each(var u:Object in p[stream])inspectUnit(u,stream);
    if(p.type!="focused-blast-probe")return;
    if(host&&p.op=="ready"&&phase=="boot"){setup();send("prepare");}
    else if(!host&&p.op=="prepare"&&phase=="boot"){setup();send("prepared");}
    else if(host&&p.op=="prepared"){phase="run";at=getTimer();send("start");}
    else if(!host&&p.op=="start"){phase="run";at=getTimer();}
    else if(p.op=="sampled"){peerDone=true;if(host&&done){send("done");finish(true);}}
    else if(p.op=="done")finish(true);
   }catch(error:*){finish(false,"receive "+(error is Error?Error(error).getStackTrace():String(error)));}
  }
  private function finish(ok:Boolean,error:String=""):void {
   if(phase=="done")return;phase="done";timer.stop();
   if(ok&&host&&(blasts.length<3||invisibleBirths<24)){ok=false;error="Fixture produced insufficient native explosions/probes: "+blasts.length+"/"+invisibleBirths;}
   if(ok&&!host&&wire.length==0){ok=false;error="No source weapon snapshots observed";}
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({kind:"focused-native-blast",role:host?"host":"join",completed:ok,error:error,
    audioVolume:SoundMixer.soundTransform.volume,phases:[],rows:rows,blasts:blasts,wire:wire,invisibleBirths:invisibleBirths,
    boundary:"Controlled public Bullet.explosion on native NPC Weapon shots; record lifetime only, not collision fidelity or frame-rate qualification"}));s.close();
   // Delay owned exit to let the flushed 'done' packet reach the other process.
   var exitTimer:Timer=new Timer(250,1);exitTimer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void{NativeApplication.nativeApplication.exit(ok?0:1);});exitTimer.start();
  }
 }
}
