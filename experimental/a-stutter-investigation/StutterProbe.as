package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.events.Event;
 import flash.events.KeyboardEvent;
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
 /** Real player control/Weapon/Bullet steps; no fabricated trajectory or remote driving. */
 public class StutterProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private static const PLAN:Array=[
   {name:"idle",ms:3000,weapon:"lmg",fire:"none",move:false},
   {name:"input",ms:6000,weapon:"lmg",fire:"none",move:true},
   {name:"host-lmg",ms:8000,weapon:"lmg",fire:"host",move:false},
   {name:"join-lmg",ms:8000,weapon:"lmg",fire:"join",move:false},
   {name:"both-lmg",ms:8000,weapon:"lmg",fire:"both",move:true},
   {name:"host-plamg",ms:8000,weapon:"plamg",fire:"host",move:false},
   {name:"join-plamg",ms:8000,weapon:"plamg",fire:"join",move:false},
   {name:"both-plamg",ms:8000,weapon:"plamg",fire:"both",move:true},
   {name:"both-rockets",ms:12000,weapon:"mlau",fire:"both",move:false},
   {name:"cooldown",ms:8000,weapon:"lmg",fire:"none",move:true}];
  private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
  private var phase:String="boot",started:int=getTimer(),lastReady:int=0,index:int=-1,at:int,serial:int=0,sampled:int=-1;
  private var gun:Object,lastBullet:Object,keys:Object={},rows:Array=[],wire:Array=[],births:Array=[],summary:Array=[],allRows:Array=[];
  private var clips:Dictionary=new Dictionary(true),nativeClips:Dictionary=new Dictionary(true),nextClip:int=1;
  private var bytes:int=0,messages:int=0,packetFrames:int=0,packetEvents:int=0,nullFlights:int=0,fire:Boolean=false,expectedClass:String="";
  private var enterAt:int=0,priorEnter:int=0,priorRender:int=0,readyPeer:Boolean=false,donePeer:Boolean=false;
  private var sourceSeen:Object={},floorY:Number=560;
  private var activeBullets:Array=[],sourceEnds:Array=[];
  private var wireSamples:Array=[],wireAt:int=0;
  public function StutterProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;
   if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
   });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function send(op:String,p:Object=null):void {p=p||{};p.type="stutter-probe";p.op=op;p.index=index;
   if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);}
  private function watch(l:TcpLink):void {if(l==null||links[l])return;links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);
   // Observe bytes already queued by AIR before TcpLink drains them. Never read/consume the socket.
   l.socket.addEventListener(ProgressEvent.SOCKET_DATA,function(e:ProgressEvent):void {
    if(phase=="run")bytes+=l.socket.bytesAvailable;
   },false,2147483647);
  }
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
   var b:Object=mod.game,g:Object=b.gg;
   if(b.world!=null&&b.world.verror!=null&&b.world.verror.visible){fail(String(b.world.verror.txt.text));return;}
   if(phase=="boot"&&g!=null&&g.sost==1&&g.ggControl&&g.t_work==0&&g.work==""
      &&b.world.t_die==0&&!b.world.onPause&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning()) {
    if(host&&readyPeer){setup();prepare(0);send("prepare");}
    else if(!host&&getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
   }
   if(phase!="done"&&getTimer()-started>150000)fail("driver timeout "+phase+" index="+index);
  }
  private function setup():void {
   var b:Object=mod.game,g:Object=b.gg,l:Object=b.loc;b.forceCloseOverlays();l.base=false;l.black=false;b.world.black=false;
   floorY=Math.max(8,Math.min(l.spaceY-2,14))*40;
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
  private function key(code:int,down:Boolean):void {if(Boolean(keys[code])==down)return;keys[code]=down;
   mod.stage.dispatchEvent(new KeyboardEvent(down?KeyboardEvent.KEY_DOWN:KeyboardEvent.KEY_UP,true,false,0,code));}
  private function prepare(n:int):void {
   index=n;phase="prepare";var g:Object=mod.game.gg;key(65,false);key(68,false);key(32,false);
   g.changeWeapon("not",true);g.invent.weapons[PLAN[n].weapon]=null;gun=g.invent.addWeapon(PLAN[n].weapon);
   if(gun==null)throw new Error("Cannot create native weapon "+PLAN[n].weapon);
   gun.lvl=0;gun.perslvl=0;g.changeWeapon(PLAN[n].weapon,true);gun.hold=Math.max(999,gun.holder);gun.hp=gun.maxhp;
   if(g.currentWeapon!==gun||gun.vis==null||gun.vis.stage==null)throw new Error("Native weapon not equipped/staged");
   var cls:Class=gun.vBullet as Class;expectedClass=getQualifiedClassName(new cls());
   g.dx=g.dy=0;g.setPos(host?240:400,floorY-2);g.setVisPos();g.storona=1;
   rows=[];wire=[];wireSamples=[];wireAt=0;births=[];sourceEnds=[];activeBullets=[];nativeClips=new Dictionary(true);lastBullet=null;sourceSeen={};
   bytes=messages=packetFrames=packetEvents=nullFlights=0;priorEnter=priorRender=0;readyPeer=donePeer=false;
   fire=PLAN[n].fire=="both"||PLAN[n].fire==(host?"host":"join");
  }
  private function begin():void {phase="run";at=getTimer();}
  private function before(e:Event):void {
   serial++;if(phase!="run")return;enterAt=getTimer();
   var age:int=enterAt-at,g:Object=mod.game.gg,b:Object=mod.game,remote:Object=b.getRemoteGhost(host?1:0);
   b.world.ctr.active=true;g.disabled=false;g.invulner=true;
   for each(var u:Object in b.loc.units)if(u!==g&&u!==remote)u.disabled=true;
   var move:Boolean=PLAN[index].move,part:int=age%3000;
   key(68,move&&part<550);key(65,move&&part>=1500&&part<2050);key(32,move&&part>=700&&part<850);
   // Native UnitPlayer.control owns attack and Weapon.step; only replenish fixture ammunition.
   b.world.ctr.keyAttack=fire;gun.hold=Math.max(gun.hold,999);gun.hp=gun.maxhp;
   g.celX=b.world.celX=g.X+1200;g.celY=b.world.celY=g.Y-g.scY*.7-120;
   var cam:Object=b.world.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
   mod.stage.invalidate();
  }
  private function after(e:Event):void {
   if(phase!="run")return;
   if(gun.b!=null&&gun.b!==lastBullet){lastBullet=gun.b;
    if(gun.b.vis!=null)nativeClips[gun.b.vis]=true;
    births.push({at:getTimer(),age:getTimer()-at,x:gun.b.begx,y:gun.b.begy,dx:gun.b.dx,dy:gun.b.dy});
    activeBullets.push({bullet:gun.b,born:getTimer(),ordinal:births.length});
   }
   for(var i:int=activeBullets.length-1;i>=0;i--) {
    var track:Object=activeBullets[i],bullet:Object=track.bullet;
    if(bullet.in_chain)continue;
    sourceEnds.push({at:getTimer(),ordinal:track.ordinal,born:track.born,x:bullet.X,y:bullet.Y,
     visualX:bullet.vis==null?null:bullet.vis.x,visualY:bullet.vis==null?null:bullet.vis.y,
     onStage:bullet.vis!=null&&bullet.vis.stage!=null});activeBullets.splice(i,1);
   }
  }
  private function pose(u:Object):Object {if(u==null)return null;
   return {x:u.X,y:u.Y,dx:u.dx,dy:u.dy,anim:GameBridge.probe(u,"animState"),
    work:GameBridge.probe(u,"work"),workTime:GameBridge.probe(u,"t_work"),
    controlled:GameBridge.probe(u,"ggControl"),state:u.sost};}
  private function render(e:Event):void {
   if(phase!="run"||sampled==serial)return;sampled=serial;
   var now:int=getTimer(),layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],items:Array=[];
   for(var i:int=0;i<layer.numChildren;i++){
    var v:DisplayObject=layer.getChildAt(i);if(getQualifiedClassName(v)!=expectedClass||!v.visible||v.alpha<=0||v.stage==null)continue;
    if(clips[v]==null)clips[v]=nextClip++;
    items.push({id:clips[v],x:v.x,y:v.y,rot:v.rotation,native:nativeClips[v]===true});
   }
   rows.push({age:now-at,at:now,enter:enterAt,enterGap:priorEnter>0?enterAt-priorEnter:0,
    renderGap:priorRender>0?now-priorRender:0,work:now-enterAt,
    local:pose(mod.game.gg),peer:pose(mod.game.getRemoteGhost(host?1:0)),clips:items});
   priorEnter=enterAt;priorRender=now;
   if(now-at>=PLAN[index].ms)endPhase();
  }
  private function snapshot(s:Object,who:int):void {
   if(s==null)return;var count:int=0,frames:int=0,nullCount:int=0;
   if(s.weapons is Array)for each(var w:Object in s.weapons)if(w.events is Array)for each(var event:Object in w.events) {
    count++;if(event.flight==null){nullFlights++;nullCount++;}if(event.flight!=null&&event.flight.frames is Array)frames+=event.flight.frames.length;
    var k:String=who+":"+w.stream+":"+event.seq;
    var row:Object=sourceSeen[k];
    if(row==null){row=sourceSeen[k]={at:getTimer(),source:who,shot:k,born:event.at,sent:w.sampleTime,updates:0};wire.push(row);}
    row.updates++;row.lastReceived=getTimer();row.frames=event.flight!=null&&event.flight.frames is Array?event.flight.frames.length:0;
    row.flightNull=event.flight==null;
    if(event.flight!=null) {
     row.end=event.flight.end;row.lastFrame=row.frames>0?event.flight.frames[row.frames-1].at:null;
     row.tailGap=Number(row.end)>0&&row.lastFrame!=null?Number(row.end)-Number(row.lastFrame):null;
    }
   }
   packetEvents+=count;packetFrames+=frames;
   if(getTimer()-wireAt>=500){wireAt=getTimer();wireSamples.push({age:wireAt-at,source:who,events:count,frames:frames,nullFlights:nullCount,sampleTime:s.sampleTime});}
  }
  private function receive(e:NetMessageEvent):void {
   try {
    var p:Object=e.data;
    if(phase=="run"&&p.type!="stutter-probe") {
     messages++;if(p.snap!=null)snapshot(p.snap,1);
     if(p.players is Array)for each(var player:Object in p.players)if(player.id!=(host?0:1))snapshot(player.snap,player.id);
    }
    if(p.type!="stutter-probe")return;
    if(host&&p.op=="ready"&&phase=="boot")readyPeer=true;
    else if(!host&&p.op=="prepare"){if(phase=="boot")setup();prepare(p.index);send("prepared");}
    else if(host&&p.op=="prepared"){begin();send("start");}
    else if(!host&&p.op=="start")begin();
    else if(p.op=="sampled"){donePeer=true;if(host&&phase=="sampled")next();}
    else if(p.op=="done")finish(true);
   } catch(error:*){fail("receive "+String(error));}
  }
  private function endPhase():void {
   var name:String=PLAN[index].name,minX:Number=Infinity,maxX:Number=-Infinity,minY:Number=Infinity,maxY:Number=-Infinity;
   var remoteSeen:Boolean=false;
   for each(var row:Object in rows){minX=Math.min(minX,row.local.x);maxX=Math.max(maxX,row.local.x);
    minY=Math.min(minY,row.local.y);maxY=Math.max(maxY,row.local.y);
    for each(var clip:Object in row.clips)if(!clip.native)remoteSeen=true;}
   if(name=="input"&&(maxX-minX<=30||maxY-minY<=30)){fail("Native input did not move/jump: "+(maxX-minX)+","+(maxY-minY));return;}
   if((name=="both-lmg"||name=="both-plamg")&&(births.length<50||!remoteSeen)){
    fail("Sustained fire/remote visual missing: "+name+" births="+births.length+" remote="+remoteSeen);return;}
   phase="sampled";mod.game.world.ctr.keyAttack=false;key(65,false);key(68,false);key(32,false);
   allRows.push({name:PLAN[index].name,weapon:PLAN[index].weapon,fire:fire,rows:rows,wire:wire,wireSamples:wireSamples,births:births,sourceEnds:sourceEnds,
    bytes:bytes,messages:messages,packetEvents:packetEvents,packetFrames:packetFrames,nullFlights:nullFlights});
   send("sampled");if(host&&donePeer)next();
  }
  private function next():void {if(index+1>=PLAN.length){send("done");finish(true);}else{prepare(index+1);send("prepare");}}
  private function fail(s:String):void {finish(false,s);}
  private function finish(ok:Boolean,error:String=""):void {
   if(phase=="done")return;phase="done";timer.stop();
   if(mod!=null&&mod.game!=null){mod.game.world.ctr.keyAttack=false;key(65,false);key(68,false);key(32,false);}
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({role:host?"host":"join",completed:ok,error:error,audioVolume:SoundMixer.soundTransform.volume,
    targetRate:mod==null?0:mod.stage.frameRate,phases:allRows,motionCursor:"private; not sampled or mutated"}));s.close();
   NativeApplication.nativeApplication.exit(ok?0:1);
  }
 }
}
