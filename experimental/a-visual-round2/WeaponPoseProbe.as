package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.display.MovieClip;
 import flash.events.Event;
 import flash.events.TimerEvent;
 import flash.events.UncaughtErrorEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.geom.Matrix;
 import flash.media.SoundMixer;
 import flash.utils.Dictionary;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 import flash.utils.getQualifiedClassName;
 import rconnect.game.GameBridge;
 import rconnect.game.MirrorHitUnit;
 import rconnect.net.TcpLink;
 import rconnect.net.NetMessageEvent;

 /** Native NPC Weapon.attack/step. Join receives normal product messages only.
  * Source controls aim and attached/free mounting; no fake animation packets. */
 public class WeaponPoseProbe extends Sprite {
  public static const MOD_CLASS:Class=RConnectMod;
  private var mod:RConnectMod,host:Boolean,phase:String="boot",started:int=getTimer(),at:int;
  private var timer:Timer=new Timer(100),links:Dictionary=new Dictionary(),readyPeer:Boolean=false,lastReady:int;
  private var units:Array=[],rows:Array=[],wire:Array=[],checks:Array=[],specs:Array=[];
  private var serial:int=0,sampled:int=-1,done:Boolean=false,peerDone:Boolean=false,baseY:Number=560;
  public function WeaponPoseProbe() {
   var app:String=NativeApplication.nativeApplication.applicationID;
   if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
   host=app.indexOf("-host-")>=0;
   loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
    e.preventDefault();finish(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():String(e.error)));
   });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
  }
  private function send(op:String,p:Object=null):void {p=p||{};p.type="weapon-pose-probe";p.op=op;
   if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
  }
  private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
  private function tick(e:TimerEvent):void {
   mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.session==null)return;
   if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
   var b:Object=mod.game,g:Object=b.gg;
   if(b.world!=null&&b.world.verror!=null&&b.world.verror.visible){finish(false,String(b.world.verror.txt.text));return;}
   if(phase=="boot"&&g!=null&&g.sost==1&&g.ggControl&&g.t_work==0&&g.work==""
      &&b.world.t_die==0&&!b.world.onPause&&mod.session.rooms.ready&&!mod.session.rooms.busy&&!b.isTransitioning()) {
    if(host&&readyPeer){setup();send("prepare",{specs:specs});}
    else if(!host&&getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
   }
   if(phase!="done"&&getTimer()-started>110000)finish(false,"timeout "+phase);
  }
  private function spawn(spec:Object,index:int):void {
   var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
   var map:XML=<unit tr="1" vis="right"/>;map.@weap=spec.weapon;
   var u:Object=new cls("1",100,map,null);u.id=spec.id;
   u.putLoc(mod.game.loc,220+index*200,baseY);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
   u.disabled=true;u.noAgro=true;u.trigDis=true;u.doop=true;u.lootIsDrop=true;u.xp=0;u.invulner=true;
   var gun:Object=u.currentWeapon;
   if(gun==null||gun.id!=spec.weapon)throw new Error("Native weapon missing: "+spec.weapon);
   gun.krep=spec.krep;u.weaponKrep=spec.krep;
   // Damage and ammunition belong to the fixture; no mirror combat is invoked.
   gun.damage=gun.damageExpl=gun.destroy=0;gun.hold=999;gun.hp=gun.maxhp;
   units.push(u);
  }
  private function setup():void {
   var b:Object=mod.game,g:Object=b.gg,l:Object=b.loc;b.forceCloseOverlays();l.base=false;l.black=false;b.world.black=false;
   baseY=Math.max(8,Math.min(l.spaceY-2,14))*40;
   for(var x:int=1;x<l.spaceX-1;x++)for(var y:int=1;y<l.spaceY-1;y++) {
    var tile:Object=l.space[x][y];tile.phis=y*40>=baseY?1:0;tile.opac=tile.phis;tile.front="";tile.water=0;
    tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
   }
   for each(var old:Object in l.units)if(old!==g){old.disabled=true;old.noAgro=true;old.trigDis=true;}
   g.invulner=true;g.disabled=true;g.hp=g.maxhp;g.dx=g.dy=0;g.setPos(120,baseY);g.setVisPos();
   if(host) {
    var all:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.AllData");
    var regular:String="",laser:String="";
    for each(var node:XML in all.d.weapon)if(int(node.@tip)==1) {
     if(int(node.vis[0].@lasm)>0){if(laser=="")laser=String(node.@id);}
     else if((!node.@mtip.length()||int(node.@mtip)==0)&&regular=="")regular=String(node.@id);
    }
    if(regular==""||laser=="")throw new Error("Native ordinary and animated melee fixture not found");
    specs=[{id:"weaponpose_free",weapon:"lmg",krep:0},
     {id:"weaponpose_fixed",weapon:"lmg",krep:1},
     {id:"weaponpose_club",weapon:regular,krep:0},
     {id:"weaponpose_laser",weapon:laser,krep:0}];
    for(var i:int=0;i<specs.length;i++)spawn(specs[i],i);
   }
   b.world.redrawLoc();b.world.cam.setZoom(2);
   // drawAllObjs replaces the native layers. Disabled source actors are skipped
   // by Unit.addVisual, so explicitly use that native method after the redraw.
   // Temporarily enabling display attachment performs no Unit/Weapon step.
   attachNativeVisual(g);
   if(host)for each(var source:Object in units)attachNativeVisual(source);
   mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
   mod.stage.addEventListener(Event.RENDER,sample,false,-2147483647);phase="prepared";
  }
  private function attachNativeVisual(u:Object):void {
   var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
   var weapon:Object=GameBridge.probe(u,"currentWeapon"),gun:DisplayObject=GameBridge.probe(weapon,"vis") as DisplayObject;
   if(body!=null&&body.stage===mod.stage&&(weapon==null||gun!=null&&gun.stage===mod.stage))return;
   var disabled:Boolean=u.disabled,trigger:Boolean=u.trigDis;
   try {u.disabled=false;u.trigDis=false;u.addVisual();}
   finally {u.disabled=disabled;u.trigDis=trigger;}
   if(body==null||body.stage!==mod.stage||weapon!=null&&(gun==null||gun.stage!==mod.stage))
    throw new Error("Native display attachment failed for "+u.id);
  }
  private function drive(e:Event):void {
   serial++;if(phase!="run")return;var age:int=getTimer()-at,b:Object=mod.game;
   b.gg.disabled=true;b.gg.invulner=true;
   for each(var old:Object in b.loc.units)old.disabled=true;
   if(host)for(var i:int=0;i<units.length;i++) {
    var u:Object=units[i],gun:Object=u.currentWeapon,dir:int=(int(age/2000)%2)==0?1:-1;
    attachNativeVisual(u);
    u.dx=u.dy=0;u.storona=dir;u.setPos(220+i*200,baseY);u.setVisPos();u.stay=true;
    u.celX=u.X+dir*250;u.celY=u.Y-60+Math.sin(age/700)*140;u.setWeaponPos(gun.tip);
    gun.hold=Math.max(999,gun.hold);gun.hp=gun.maxhp;
    // A disabled native NPC will not execute its child weapon itself.
    if(age>1200&&age<13000)gun.attack();
    gun.step();u.animate();
   }
   mod.stage.invalidate();
  }
  private function matrix(u:Object,v:DisplayObject):Array {
   if(v==null||v.parent==null||u.vis==null||u.vis.parent==null)return null;
   // Independent display-tree read, without calling product capture/interpolate.
   var m:Matrix=v.transform.concatenatedMatrix.clone(),basis:Matrix=u.vis.parent.transform.concatenatedMatrix.clone();
   basis.invert();m.concat(basis);
   return [m.a,m.b,m.c,m.d,m.tx-u.X,m.ty-u.Y];
  }
  private function frames(v:DisplayObject,path:String="",depth:int=0):Array {
   var out:Array=[];if(v==null)return out;
   if(v is MovieClip)out.push({path:path,cls:getQualifiedClassName(v),frame:MovieClip(v).currentFrame,total:MovieClip(v).totalFrames});
   if(depth>=2||!(v is DisplayObjectContainer))return out;
   var c:DisplayObjectContainer=v as DisplayObjectContainer;
   for(var i:int=0;i<c.numChildren;i++){var child:DisplayObject=c.getChildAt(i);out=out.concat(frames(child,path+"/"+child.name,depth+1));}
   return out;
  }
  private function sample(e:Event):void {
   if(phase!="run"||serial==sampled)return;sampled=serial;
   var now:int=getTimer(),actors:Array=[];
   for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&String(u.id).indexOf("weaponpose_")==0) {
    var w:Object=u.currentWeapon,v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
    actors.push({id:u.id,x:u.X,y:u.Y,weapon:w==null?null:w.id,krep:GameBridge.probe(w,"krep"),
     facing:u.storona,aimX:u.celX,aimY:u.celY,nativeRot:GameBridge.probe(w,"rot"),
     matrix:matrix(u,v),onStage:v!=null&&v.stage!=null,visible:v!=null&&v.visible,
     attack:GameBridge.probe(w,"t_attack"),frames:frames(v)});
   }
   rows.push({at:now,age:now-at,actors:actors});
   if(now-at<15500)return;
   done=true;phase="sampled";send("sampled");if(host&&peerDone){send("done");finish(true);}
  }
  private function inspect(u:Object,stream:String):void {
   if(String(u.id).indexOf("weaponpose_")!=0)return;
   for each(var w:Object in u.weapons) {
    var ms:Object=w.melee,fs:Array=ms==null?null:ms.frames as Array;
    wire.push({at:getTimer(),age:getTimer()-at,id:u.id,weapon:w.id,stream:stream,stamp:u.sampleTime,
     display:w.display,meleeCount:fs==null?0:fs.length,meleeFirst:fs==null||fs.length==0?null:fs[0].at,
     meleeLast:fs==null||fs.length==0?null:fs[fs.length-1].at,
     // Retain source poses, never serialize in the receive loop.
     melee:ms});
   }
  }
  private function receive(e:NetMessageEvent):void {
   try {
    var p:Object=e.data;
    if(!host&&phase=="run")for each(var stream:String in ["units","enemyMotion"])if(p[stream] is Array)
     for each(var u:Object in p[stream])inspect(u,stream);
    if(p.type!="weapon-pose-probe")return;
    if(host&&p.op=="ready"&&phase=="boot")readyPeer=true;
    else if(!host&&p.op=="prepare"&&phase=="boot"){specs=p.specs;setup();send("prepared");}
    else if(host&&p.op=="prepared"){phase="run";at=getTimer();send("start");}
    else if(!host&&p.op=="start"){phase="run";at=getTimer();}
    else if(p.op=="sampled"){peerDone=true;if(host&&done){send("done");finish(true);}}
    else if(p.op=="done")finish(true);
   }catch(error:*){finish(false,"receive "+(error is Error?Error(error).getStackTrace():String(error)));}
  }
  private function check(ok:Boolean,text:String):void {checks.push({ok:ok,text:text});}
  private function finish(ok:Boolean,error:String=""):void {
   if(phase=="done")return;phase="done";timer.stop();
   if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
   var found:Object={},signs:Object={},moves:Object={},last:Object={};
   for each(var row:Object in rows)for each(var a:Object in row.actors)if(a.onStage&&a.matrix!=null) {
    found[a.id]=true;var m:Array=a.matrix,sign:int=m[0]*m[3]-m[1]*m[2]<0?-1:1;
    if(signs[a.id]==null)signs[a.id]={};signs[a.id][sign]=true;
    if(last[a.id]!=null&&(Math.abs(m[0]-last[a.id][0])>.001||Math.abs(m[1]-last[a.id][1])>.001))moves[a.id]=int(moves[a.id])+1;
    last[a.id]=m;
   }
   check(rows.length>250,"Final display samples > 250");
   for each(var spec:Object in specs) {
    check(found[spec.id]===true,"Native actor visible "+spec.id);
    check(signs[spec.id]!=null&&signs[spec.id][-1]===true&&signs[spec.id][1]===true,"Both native handedness signs "+spec.id);
    check(int(moves[spec.id])>30,"Weapon actually changes rendered angle "+spec.id+" changes="+int(moves[spec.id]));
   }
   if(!host) {
    var fast:int=0,meleeFast:int=0;
    for each(var packet:Object in wire)if(packet.stream=="enemyMotion") {
     if(packet.display!=null)fast++;
     if((packet.id=="weaponpose_club"||packet.id=="weaponpose_laser")&&packet.meleeCount>0)meleeFast++;
    }
    check(fast>30,"Frequent enemy poses carry native weapon transform: "+fast);
    check(meleeFast>30,"Frequent enemy poses carry sampled native swing history: "+meleeFast);
   }
   for each(var c:Object in checks)if(!c.ok){ok=false;if(error=="")error=c.text;}
   var f:File=File.applicationStorageDirectory.resolvePath("stutter-result.json"),s:FileStream=new FileStream();s.open(f,FileMode.WRITE);
   s.writeUTFBytes(JSON.stringify({kind:"native-enemy-weapon-pose",role:host?"host":"join",completed:ok,error:error,
    audioVolume:SoundMixer.soundTransform.volume,phases:[],checks:checks,specs:specs,rows:rows,wire:wire,
    boundary:"Native NPC mounted/free gun and ordinary/animated WClub display. Matrix/root/child-frame evidence; no damage or overall performance claim."}));s.close();
   var exitTimer:Timer=new Timer(250,1);exitTimer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void{NativeApplication.nativeApplication.exit(ok?0:1);});exitTimer.start();
  }
 }
}
