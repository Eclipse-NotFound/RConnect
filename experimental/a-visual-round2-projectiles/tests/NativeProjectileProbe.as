package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.events.Event;
 import flash.events.ProgressEvent;
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
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;
 import rconnect.game.GameBridge;

 /** Isolated native Weapon/Bullet execution and final-RENDER observations.
  * No receiver driving, invented trajectory, packet mutation, or clock mutation.
  * Reuses the stutter harness/result contract; this is not a product entry. */
 public class NativeProjectileProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private static const PLAN:Array=[
   {name:"both-lmg",ms:7000,weapon:"lmg",enemy:false},
   {name:"both-cflamer",ms:7000,weapon:"cflamer",enemy:false},
   {name:"both-prism",ms:7000,weapon:"prism",enemy:false},
   {name:"enemy-lightning",ms:10000,weapon:"lmg",enemy:true}];
  private static const WIRE_DETAIL_EVENTS:int=12;
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
  private var phase:String="boot",started:int=getTimer(),lastReady:int=0,index:int=-1,at:int,serial:int=0,sampled:int=-1;
  private var gun:Object,enemy:Object,bulletClass:Class;
  private var rows:Array=[],wire:Array=[],births:Array=[],allRows:Array=[],checks:Array=[];
  private var clips:Dictionary=new Dictionary(true),nativeClips:Dictionary=new Dictionary(true),seenBullets:Dictionary=new Dictionary(true),nextClip:int=1;
  private var bytes:int=0,messages:int=0,packetFrames:int=0,packetEvents:int=0,nullFlights:int=0;
  private var enterAt:int=0,priorEnter:int=0,priorRender:int=0,readyPeer:Boolean=false,donePeer:Boolean=false;
  private var sourceSeen:Object={},detailedStreams:Object={},expectedClasses:Object={},floorY:Number=560;
  private var activeBullets:Array=[],sourceEnds:Array=[],sourceRows:Array=[],wireSamples:Array=[],wireAt:int=0;
  private var localShots:int=0,enemyShots:int=0,lastLocalBullet:Object,lastEnemyBullet:Object;

  public function NativeProjectileProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;
   if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
   host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
   });
   timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function send(op:String,p:Object=null):void {
   p=p||{};p.type="stutter-probe";p.op=op;p.index=index;
   if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
  }
  private function watch(l:TcpLink):void {
   if(l==null||links[l])return;links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);
   // Read the queued-byte count, never consume or rewrite the socket.
   l.socket.addEventListener(ProgressEvent.SOCKET_DATA,function(e:ProgressEvent):void {
    if(phase=="run")bytes+=l.socket.bytesAvailable;
   },false,2147483647);
  }
  private function ready():Boolean {
   var b:Object=mod.game,g:Object=b.gg;
   return g!=null&&g.sost==1&&g.ggControl&&g.t_work==0&&g.work==""
    &&b.world.t_die==0&&!b.world.onPause&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning();
  }
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
   var b:Object=mod.game;
   if(b.world!=null&&b.world.verror!=null&&b.world.verror.visible){fail(String(b.world.verror.txt.text));return;}
   if(phase=="boot"&&ready()) {
    if(host&&readyPeer){setup();prepare(0);send("prepare");}
    else if(!host&&getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
   }
   if(phase!="done"&&getTimer()-started>150000)fail("driver timeout "+phase+" index="+index);
  }
  private function setup():void {
   var b:Object=mod.game,g:Object=b.gg,l:Object=b.loc;b.forceCloseOverlays();l.base=false;l.black=false;b.world.black=false;
   bulletClass=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
   floorY=Math.max(8,Math.min(l.spaceY-2,14))*40;
   // Same empty fixture as the existing stutter probe; the edge wall remains.
   for(var x:int=1;x<l.spaceX-1;x++)for(var y:int=1;y<l.spaceY-1;y++) {
    var tile:Object=l.space[x][y];tile.phis=y*40>=floorY?1:0;tile.opac=tile.phis;tile.front="";tile.water=0;
    tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
   }
   for each(var u:Object in l.units)if(u!==g){u.disabled=true;u.noAgro=true;u.trigDis=true;}
   g.magicWeapon=null;g.throwWeapon=null;g.invulner=true;g.disabled=false;g.hp=g.maxhp;
   b.world.redrawLoc();b.world.cam.setZoom(2);
   mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100001);
   mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
   mod.stage.addEventListener(Event.RENDER,render,false,-2147483647);
  }
  private function classFor(w:Object):String {
   if(w==null||!(w.vBullet is Class))throw new Error("Native bullet class missing");
   var cls:Class=w.vBullet as Class;return getQualifiedClassName(new cls());
  }
  private function prepare(n:int):void {
   index=n;phase="prepare";var g:Object=mod.game.gg;
   g.changeWeapon("not",true);g.invent.weapons[PLAN[n].weapon]=null;gun=g.invent.addWeapon(PLAN[n].weapon);
   if(gun==null)throw new Error("Cannot create native weapon "+PLAN[n].weapon);
   gun.lvl=0;gun.perslvl=0;g.changeWeapon(PLAN[n].weapon,true);gun.hold=Math.max(999,gun.holder);gun.hp=gun.maxhp;
   if(g.currentWeapon!==gun||gun.vis==null||gun.vis.stage==null)throw new Error("Native weapon not equipped/staged");
   g.dx=g.dy=0;g.setPos(host?240:400,floorY-2);g.setVisPos();g.storona=1;
   expectedClasses={};expectedClasses[classFor(gun)]=true;
   rows=[];wire=[];births=[];sourceEnds=[];sourceRows=[];activeBullets=[];wireSamples=[];
   nativeClips=new Dictionary(true);seenBullets=new Dictionary(true);sourceSeen={};detailedStreams={};
   bytes=messages=packetFrames=packetEvents=nullFlights=localShots=enemyShots=0;
   priorEnter=priorRender=wireAt=0;readyPeer=donePeer=false;lastLocalBullet=lastEnemyBullet=null;
   if(PLAN[n].enemy) {
    // Both sides know the authored visual class; only the authority creates an actor.
    var weaponClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon") as Class;
    var template:Object=Object(weaponClass).create(g,"alilight");
    expectedClasses[classFor(template)]=true;
    if(host) {
     var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitAlicorn") as Class;
     enemy=new cls("1",100,<unit tr="1" vis="right"/>,null);enemy.id="projectileprobe_alicorn";
     enemy.putLoc(mod.game.loc,560,floorY-150);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
     enemy.disabled=true;enemy.doop=true;enemy.lootIsDrop=true;enemy.xp=0;enemy.dx=enemy.dy=0;
     expectedClasses[classFor(enemy.currentWeapon)]=true;
    }
   }
  }
  private function begin():void {phase="run";at=getTimer();}
  private function before(e:Event):void {
   serial++;if(phase!="run")return;enterAt=getTimer();
   var b:Object=mod.game,g:Object=b.gg,remote:Object=b.getRemoteGhost(host?1:0);
   b.world.ctr.active=true;g.disabled=false;g.invulner=true;
   for each(var u:Object in b.loc.units)if(u!==g&&u!==remote)u.disabled=true;
   // UnitPlayer.control and Weapon.step own player fire; do not call attack twice.
   var age:int=enterAt-at;
   var fire:Boolean=!PLAN[index].enemy&&age<PLAN[index].ms-1500;
   // Prism is native semi-automatic: holding attack only fires its first six-ray
   // volley (Weapon.t_auto requires release). Supply clicks, never change auto.
   if(PLAN[index].weapon=="prism")fire=fire&&age%750<100;
   b.world.ctr.keyAttack=fire;gun.hold=Math.max(gun.hold,999);gun.hp=gun.maxhp;
   g.celX=b.world.celX=g.X+1200;
   g.celY=b.world.celY=g.Y-g.scY*.7-120+(PLAN[index].weapon=="prism"?45*Math.sin(age/1100):0);
   var cam:Object=b.world.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
   mod.stage.invalidate();
  }
  private function track(bullet:Object,now:int):void {
   if(bullet==null||seenBullets[bullet])return;
   var owner:Object=GameBridge.probe(bullet,"owner");
   if(owner==null||(owner!==mod.game.gg&&owner!==enemy))return;
   seenBullets[bullet]=true;
   var ownerId:String=owner===enemy?"projectileprobe_alicorn":(host?"player:0":"player:1");
   var vis:Object=GameBridge.probe(bullet,"vis"),ordinal:int=births.length+1;
   if(vis!=null)nativeClips[vis]={owner:ownerId,ordinal:ordinal};
   births.push({at:now,age:now-at,ordinal:ordinal,owner:ownerId,weapon:GameBridge.probe(bullet,"weapId"),
    cls:vis==null?null:getQualifiedClassName(vis),x:bullet.begx,y:bullet.begy,dx:bullet.dx,dy:bullet.dy,
    spring:bullet.spring,life:bullet.liv});
   activeBullets.push({bullet:bullet,born:now,ordinal:ordinal,owner:ownerId});
  }
  private function after(e:Event):void {
   if(phase!="run")return;
   var now:int=getTimer();
   if(host&&PLAN[index].enemy&&enemy!=null) {
    enemy.disabled=true;enemy.dx=enemy.dy=0;enemy.celX=enemy.X+650;enemy.celY=enemy.Y-25;
    var w:Object=enemy.currentWeapon;w.hold=999;w.damage=w.damageExpl=w.destroy=0;
    if(now-at>1000&&now-at<PLAN[index].ms-1500)w.attack();
    w.step();enemy.setVisPos();enemy.animate();
    if(w.b!=null&&w.b!==lastEnemyBullet){lastEnemyBullet=w.b;enemyShots++;track(w.b,now);}
   }
   if(gun.b!=null&&gun.b!==lastLocalBullet){lastLocalBullet=gun.b;localShots++;track(gun.b,now);}
   // Include every native burst member and invisible helper, not only Weapon.b.
   var o:Object=mod.game.loc.firstObj;
   for(var guard:int=0;o!=null&&guard++<16384;o=GameBridge.probe(o,"nobj"))if(o is bulletClass)track(o,now);
   for(var i:int=activeBullets.length-1;i>=0;i--) {
    var rec:Object=activeBullets[i],bullet:Object=rec.bullet,v:Object=GameBridge.probe(bullet,"vis");
    if(v!=null&&nativeClips[v]==null)nativeClips[v]={owner:rec.owner,ordinal:rec.ordinal};
    if(bullet.in_chain)continue;
    sourceEnds.push({at:now,ordinal:rec.ordinal,born:rec.born,owner:rec.owner,x:bullet.X,y:bullet.Y,
     visualX:v==null?null:v.x,visualY:v==null?null:v.y,onStage:v!=null&&v.stage!=null});
    activeBullets.splice(i,1);
   }
  }
  private function pose(u:Object):Object {
   if(u==null)return null;
   return {x:u.X,y:u.Y,dx:u.dx,dy:u.dy,anim:GameBridge.probe(u,"animState"),
    work:GameBridge.probe(u,"work"),workTime:GameBridge.probe(u,"t_work"),controlled:GameBridge.probe(u,"ggControl"),state:u.sost};
  }
  private function display(v:DisplayObject):Object {
   var laser:Object=GameBridge.probe(v,"laser");
   return {x:v.x,y:v.y,rot:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,visible:v.visible,
    frame:GameBridge.probe(v,"currentFrame"),ls:GameBridge.probe(laser,"scaleX"),lf:GameBridge.probe(laser,"currentFrame")};
  }
  private function render(e:Event):void {
   if(phase!="run"||sampled==serial)return;sampled=serial;
   var now:int=getTimer(),layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],items:Array=[],nativeRows:Array=[];
   for(var i:int=0;i<layer.numChildren;i++) {
    var v:DisplayObject=layer.getChildAt(i),cls:String=getQualifiedClassName(v);
    if(!expectedClasses[cls]||!v.visible||v.alpha<=0||v.stage==null)continue;
    if(clips[v]==null)clips[v]=nextClip++;
    var item:Object=display(v),source:Object=nativeClips[v];
    item.id=clips[v];item.cls=cls;item.native=source!=null;item.owner=source==null?null:source.owner;
    item.ordinal=source==null?null:source.ordinal;items.push(item);
   }
   for each(var rec:Object in activeBullets) {
    var bullet:Object=rec.bullet,bvis:DisplayObject=GameBridge.probe(bullet,"vis") as DisplayObject;
    nativeRows.push({ordinal:rec.ordinal,owner:rec.owner,x:bullet.X,y:bullet.Y,dx:bullet.dx,dy:bullet.dy,
     life:bullet.liv,babah:bullet.babah,inChain:bullet.in_chain,visual:bvis==null?null:display(bvis),onStage:bvis!=null&&bvis.stage!=null});
   }
   rows.push({age:now-at,at:now,enter:enterAt,enterGap:priorEnter>0?enterAt-priorEnter:0,
    renderGap:priorRender>0?now-priorRender:0,work:now-enterAt,
    local:pose(mod.game.gg),peer:pose(mod.game.getRemoteGhost(host?1:0)),clips:items});
   sourceRows.push({at:now,age:now-at,bullets:nativeRows});
   priorEnter=enterAt;priorRender=now;
   if(now-at>=PLAN[index].ms)endPhase();
  }
  private function snapshot(s:Object,who:String):void {
   if(s==null)return;
   var count:int=0,frames:int=0,nullCount:int=0,now:int=getTimer();
   if(s.weapons is Array)for each(var w:Object in s.weapons)if(w.events is Array)for each(var event:Object in w.events) {
    count++;if(event.flight==null){nullFlights++;nullCount++;}
    var flight:Object=event.flight,points:Array=flight==null?null:flight.frames as Array;
    if(points!=null)frames+=points.length;
    var stream:String=who+":"+w.stream,k:String=stream+":"+event.seq,row:Object=sourceSeen[k];
    if(row==null) {
     var detailed:Boolean=int(detailedStreams[stream])<WIRE_DETAIL_EVENTS;
     if(detailed)detailedStreams[stream]=int(detailedStreams[stream])+1;
     row=sourceSeen[k]={at:now,source:who,shot:k,born:event.at,sent:w.sampleTime,updates:0,
      detailed:detailed,history:[],receiveUpdates:[]};wire.push(row);
    }
    row.updates++;row.lastReceived=now;row.frames=points==null?0:points.length;row.flightNull=flight==null;
    if(flight!=null) {
     row.cls=flight.cls;row.spring=flight.spring;row.end=flight.end;
     row.lastFrame=row.frames>0?points[row.frames-1].at:null;
     row.tailGap=Number(row.end)>0&&row.lastFrame!=null?Number(row.end)-Number(row.lastFrame):null;
     if(row.detailed) {
      row.receiveUpdates.push({at:now,sent:w.sampleTime,n:row.frames,first:row.frames>0?points[0].at:null,last:row.lastFrame,end:flight.end});
      for each(var point:Object in points) {
       var history:Array=row.history;
       if(history.length>0&&Number(point.at)<Number(history[history.length-1].at))continue;
       var copy:Object={};for(var field:String in point)copy[field]=point[field];
       if(history.length>0&&Number(point.at)==Number(history[history.length-1].at))history[history.length-1]=copy;
       else history.push(copy);
      }
     }
    }
   }
   packetEvents+=count;packetFrames+=frames;
   if(now-wireAt>=500){wireAt=now;wireSamples.push({age:now-at,source:who,events:count,frames:frames,nullFlights:nullCount,sampleTime:s.sampleTime});}
  }
  private function receive(e:NetMessageEvent):void {
   try {
    var p:Object=e.data;
    if(phase=="run"&&p.type!="stutter-probe") {
     messages++;if(p.snap!=null)snapshot(p.snap,"player:1");
     if(p.players is Array)for each(var player:Object in p.players)if(player.id!=(host?0:1))snapshot(player.snap,"player:"+player.id);
     if(!host&&PLAN[index].enemy)for each(var stream:String in ["units","enemyMotion"])if(p[stream] is Array)
      for each(var u:Object in p[stream])if(String(u.id)=="projectileprobe_alicorn")snapshot(u,String(u.id));
    }
    if(p.type!="stutter-probe")return;
    if(host&&p.op=="ready"&&phase=="boot")readyPeer=true;
    else if(!host&&p.op=="prepare"){if(phase=="boot")setup();prepare(p.index);send("prepared");}
    else if(host&&p.op=="prepared"){begin();send("start");}
    else if(!host&&p.op=="start")begin();
    else if(p.op=="sampled"){donePeer=true;if(host&&phase=="sampled")next();}
    else if(p.op=="done")finish(true);
   }catch(error:*){fail("receive "+String(error));}
  }
  private function endPhase():void {
   phase="sampled";mod.game.world.ctr.keyAttack=false;
   var remoteSeen:Boolean=false,nativeSeen:Boolean=false,nativeFrames:int=0,remoteFrames:int=0;
   var nativeFirst:Number=NaN,nativeLast:Number=NaN,remoteFirst:Number=NaN,remoteLast:Number=NaN;
   for each(var row:Object in rows) {
    var localVisible:Boolean=false,peerVisible:Boolean=false;
    for each(var clip:Object in row.clips) {
     if(clip.native){nativeSeen=true;localVisible=true;}else{remoteSeen=true;peerVisible=true;}
    }
    if(localVisible){nativeFrames++;if(isNaN(nativeFirst))nativeFirst=row.at;nativeLast=row.at;}
    if(peerVisible){remoteFrames++;if(isNaN(remoteFirst))remoteFirst=row.at;remoteLast=row.at;}
   }
   var phaseChecks:Array=[{name:"final-render-samples",ok:rows.length>=60,actual:rows.length}];
   if(PLAN[index].enemy) {
    if(host)phaseChecks.push({name:"native-alicorn-fire",ok:enemyShots>=3&&nativeSeen,shots:enemyShots,nativeVisible:nativeSeen});
    else phaseChecks.push({name:"remote-alicorn-projectile",ok:wire.length>0&&remoteSeen,events:wire.length,remoteVisible:remoteSeen});
   } else if(PLAN[index].weapon=="prism")phaseChecks.push({name:"prism-native-and-remote-visible-across-clicks",
    ok:nativeFrames>=9&&remoteFrames>=9&&nativeLast-nativeFirst>=2000&&remoteLast-remoteFirst>=2000,
    nativeVisibleFrames:nativeFrames,remoteVisibleFrames:remoteFrames,
    nativeVisibleSpan:nativeLast-nativeFirst,remoteVisibleSpan:remoteLast-remoteFirst,shots:localShots});
   else phaseChecks.push({name:"both-native-and-remote-fire",ok:localShots>=3&&nativeSeen&&remoteSeen,
    shots:localShots,nativeVisible:nativeSeen,remoteVisible:remoteSeen});
   for each(var check:Object in phaseChecks){check.phase=PLAN[index].name;checks.push(check);}
   allRows.push({name:PLAN[index].name,weapon:PLAN[index].weapon,fire:!PLAN[index].enemy,rows:rows,wire:wire,
    wireSamples:wireSamples,births:births,sourceEnds:sourceEnds,sourceRows:sourceRows,checks:phaseChecks,
    localShots:localShots,enemyShots:enemyShots,weaponNative:{cls:getQualifiedClassName(gun),auto:gun.auto,
     rapid:gun.rapid,spring:gun.spring,kol:gun.kol},bytes:bytes,messages:messages,packetEvents:packetEvents,
    packetFrames:packetFrames,nullFlights:nullFlights});
   send("sampled");if(host&&donePeer)next();
  }
  private function next():void {
   if(index+1>=PLAN.length){send("done");finish(true);}else{prepare(index+1);send("prepare");}
  }
  private function fail(s:String):void {finish(false,s);}
  private function finish(ok:Boolean,error:String=""):void {
   if(phase=="done")return;phase="done";timer.stop();
   if(mod!=null&&mod.game!=null)mod.game.world.ctr.keyAttack=false;
   var passed:Boolean=ok;for each(var check:Object in checks)if(check.ok!==true)passed=false;
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({probe:"native-special-projectiles-v1",role:host?"host":"join",completed:ok,passed:passed,
    error:error,audioVolume:SoundMixer.soundTransform.volume,targetRate:mod==null?0:mod.stage.frameRate,
    checks:checks,phases:allRows,motionCursor:"private; not sampled or mutated"}));s.close();
   NativeApplication.nativeApplication.exit(ok?0:1);
  }
 }
}
