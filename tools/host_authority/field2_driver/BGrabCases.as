package {
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;
 import flash.utils.getQualifiedClassName;
 /** Native quick-slot throws, physical Q grabs and E throws in both directions. */
 public final class BGrabCases {
  private var m:Object,d:ApplicationDomain,api:Object,side:String,room:Object,fy:Number,control:Object={};
  private var phase:int=-1,at:int,lastRead:int=0,bullet:Object,owner:Object,holder:Object,beforeSpawns:uint;
  private var heldAt:int=0,samples:int=0,hover:Boolean=false,lastLife:Number,monotonic:Boolean=true,reversed:Boolean=false;
  private var completed:Boolean=false;
  private var readyAckSent:Boolean=false,readyNeutralAck:int=-1,edgeLogged:Boolean=false,edgePointer:Boolean=false;
  public function BGrabCases(mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,role:String,a:Object){m=mod;d=domain;api=a;side=role;room=a.home;fy=Number(a.floorY);if(domain.hasDefinition("authority.ProjectileSelection")){BProjectileSelectionInputs.run(domain,api.check);BSelectionPriorityChecks.run(mod,domain,api.check);}}
  private function check(ok:Boolean,name:String,data:Object=null):void{api.check(ok,"Grab: "+name,data);}
  private function send(stage:String):void {control.stage=stage;if(stage=="settle")control.settleTick=m.host.runtime.tick;at=getTimer();api.write("grab-control.json",control);api.log("grab-stage",{phase:phase,stage:stage,tick:m.host.runtime.tick,awaitingView:m.host.runtime.awaitingFirstView,life:bullet==null?null:bullet.liv});}
  public function input():void {
   if(completed)return;
   if(side=="join" && getTimer()-lastRead>70){lastRead=getTimer();var c:Object=api.read("grab-control.json");if(c!=null){if(c.phase!=control.phase){hover=false;samples=0;readyAckSent=false;readyNeutralAck=-1;edgeLogged=false;edgePointer=false;}control=c;}}
   var w:Object=m.access.world,ctr:Object=w.ctr;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele","keyGrenad"])ctr[key]=false;
   if(control.stage==null || control.stage=="end")return;
   var me:int=side=="host"?0:1,x:Number=control.x,y:Number=control.y;
   if(control.stage=="throw" && me==control.owner) {
    if(control.wallInput==null)control.wallInput=new Date().getTime();
    ctr.keyGrenad=true;
   }
   if(control.stage=="grab") {
    var p:Object=null;
    if(side=="host" && bullet!=null)p={x:bullet.X,y:bullet.Y};
    else if(m.replica!=null && m.replica.displayFrame!=null)for each(var v:Object in m.replica.displayFrame.projectiles)if(v.id==control.id){p=v;break;}
    if(p!=null){x=p.x;y=p.y;if(me==control.holder) {
     // A real caster cannot click an ended/invisible lifetime. Wait only for
     // the already displayed active projectile, never a host-now coordinate.
     var clip:Object=side=="join"?m.replica.projectileDisplay(uint(control.id)):null;
     ctr.keyTele=side=="host" || (p.grip!=null && p.grip.active && !p.ended && clip!=null && clip.parent!=null && clip.visible && clip.alpha>0);
    }}
    // A failed first click must stay failed, not become an automatic retry
    // when a later picture changes visibility or availability.
    if(side=="join" && me==control.holder && edgeLogged)ctr.keyTele=true;
   }
   if(control.stage=="hold" || control.stage=="return") {x=control.returnX;y=fy-90;if(side=="join")y=control.floor-90;}
   if(control.stage=="return" && me==control.holder)ctr.keyAction=true;
   w.celX=x;w.celY=y;if(w.cam!=null){w.cam.celX=w.cam.vx+x*w.cam.scaleV;w.cam.celY=w.cam.vy+y*w.cam.scaleV;}
   if(side=="join" && control.stage=="grab" && control.id!=null && control.wallInput!=null && !control.wallLatencyLogged && m.replica!=null && m.replica.displayFrame!=null) {
    for each(var seenProjectile:Object in m.replica.displayFrame.projectiles)if(seenProjectile.id==control.id) {
     control.wallLatencyLogged=true;
     var wallLatency:Number=new Date().getTime()-Number(control.wallInput);
     api.log("grab-wall-latency",{phase:control.phase,id:control.id,wallLatencyMs:wallLatency,
      displayTick:m.replica.displayFrame.tick,latestTick:m.replica.lastFrame.tick});
     api.write("join-grab-latency-"+control.phase+".json",{phase:control.phase,id:control.id,wallLatencyMs:wallLatency,
      displayTick:m.replica.displayFrame.tick});
     break;
    }
   }
   if(side=="join" && control.stage=="grab" && me==control.holder && ctr.keyTele) {
    ++samples;
    // Same pre-present point and old picture as the physical Q edge. Reading
    // celObj later in step() compares a newer projectile to this older aim.
    var pick:Object="projectileSelection" in m.replica?m.replica.projectileSelection():null;
    var selected:Boolean=pick!=null && pick.id==control.id;
    hover=hover || selected;
    if(!edgeLogged) {
     edgeLogged=true;edgePointer=selected;
     api.log("grab-input-edge",{phase:control.phase,id:control.id,pick:pick,aim:[x,y],
      displayTick:m.replica.displayFrame.tick,latestTick:m.replica.lastFrame.tick,
      displayPresentation:m.replica.clock.current.presentation,fraction:m.replica.clock.fraction,
      projectile:{x:p.x,y:p.y,grip:p.grip,ended:p.ended},playerX:w.gg.X});
    }
   }
  }
  private function begin():void {
   ++phase;bullet=null;heldAt=0;lastLife=NaN;monotonic=true;reversed=false;
   if(phase>=4){control={stage:"end"};send("end");return;}
   var s:Object=m.host;owner=s.actors[phase%2];holder=s.actors[1-phase%2];
   for each(var a:Object in s.actors)m.access.scope.run(a.context,function():void {
    var g:Object=a.unit;g.dropTeleObj();g.setLocPos(500+a.id*140,fy);g.dx=g.dy=0;g.invulner=true;g.ggControl=true;g.pers.setForcLevel(60);
    for(var k:String in g.pers.skills)g.pers.skills[k]=100;g.pers.setParameters();g.pers.portPoss=0;g.pers.spellsPoss=1;
    g.pers.teleDist=1000000;g.pers.maxTeleMassa=10000;g.mana=g.maxmana=10000;g.dmana=0;g.pers.recMana=g.pers.recManaMin=0;
    g.t_port=0;g.t_culd=0;
   });
   room.base=false;room.black=false;
   m.access.scope.run(owner.context,function():void {
    var g:Object=owner.unit,Weapon:Class=m.access.definition("fe.weapon.Weapon"),id:String=phase<2?"grenade":"acidgr";
    if(g.throwWeapon!=null)g.throwWeapon.remVisual();var gun:Object=Weapon["create"](g,id,0);gun.setPers(g,g.pers);gun.loc=room;gun.hp=gun.maxhp;gun.setNull();gun.addVisual2();
    g.invent.weapons[id]=gun;g.throwWeapon=gun;g.invent.fav[29]=id;g.invent.items[gun.ammo].kol=20;
   });
   beforeSpawns=s.runtime.spawnsByPlayer[owner.id];
   control={phase:phase,owner:owner.id,holder:holder.id,x:holder.unit.X,y:fy-75,floor:fy,returnX:holder.unit.X+(holder.id==1?-70:70),
    readyAfter:getTimer(),room:m.access.keyFor(room),epoch:s.actors[1].epoch,roomEpoch:s.actors[1].roomEpoch};send("ready");s.publish();
  }
  public function step():void {
   if(completed)return;
   if(side=="join") {
    if(control.stage=="ready" && !readyAckSent && m.replica.displayFrame!=null) {
     var ready:Object=m.replica.displayFrame,joined:Object=ready.players[1];
     if(readyNeutralAck<0)readyNeutralAck=int(m.replica.lastFrame.players[1].ack);
     if(ready.room===control.room && ready.time>=control.readyAfter && joined.epoch==control.epoch && joined.roomEpoch==control.roomEpoch &&
      Math.abs(joined.x-640)<.1 && Math.abs(ready.players[0].x-500)<.1 && int(joined.ack)>readyNeutralAck) {
      readyAckSent=true;
      api.write("join-grab-ready-"+control.phase+".json",{ack:joined.ack,time:ready.time,tick:ready.tick});
      api.log("grab-ready",{phase:control.phase,ack:joined.ack,tick:ready.tick,presentation:ready.presentation,neutralBefore:readyNeutralAck});
     }
    }
    if(control.stage=="settle" && m.replica.displayFrame!=null && m.replica.displayFrame.tick>=control.settleTick && api.read("join-grab-"+control.phase+".json")==null) {
     var state:Object=m.replica.displayFrame,seen:Boolean=false;
     for each(var p:Object in state.players)if(p.id==control.holder)seen=p.held==null;
     // The joining caster aims at the delayed picture. When the host casts,
     // its brief hover can finish before that stage reaches the observer.
     if(control.holder==1)check(samples>0 && hover && edgePointer,"joining caster Q edge names the visibly hovered grenade "+control.phase,{samples:samples,hover:hover,edgePointer:edgePointer});
     check(seen,"joining holder released after return/expiry "+control.phase);
     api.write("join-grab-"+control.phase+".json",{done:true});
    }
    if(control.stage=="end"){api.write("join-grab-end.json",{done:true});completed=true;m.leaveSession();api.finish();}
    return;
   }
   if(phase<0){begin();return;}
   if(control.stage=="end"){if(api.read("join-grab-end.json")!=null && m.role==""){completed=true;api.finish();}return;}
   var elapsed:int=getTimer()-at,s:Object=m.host;
   if(control.stage=="ready" && elapsed>1200) {
    var ack:Object=api.read("join-grab-ready-"+phase+".json");
    if(ack!=null && !s.runtime.awaitingFirstView && s.inputs[1].consumed>=ack.ack && (s.inputs[1].buttons&(64|128|1024))==0){send("throw");return;}
   }
   if(control.stage=="throw") {
    for(var q:Object=room.firstObj;q!=null;q=q.nobj)if(getQualifiedClassName(q)=="fe.weapon::PhisBullet" && q.owner===owner.unit && q.weap===owner.unit.throwWeapon){bullet=q;break;}
    if(bullet!=null){control.id=s.runtime.projectileId(bullet);if(control.id==0)return;lastLife=bullet.liv;send("grab");}
   }else if(control.stage=="grab") {
    if(holder.unit.teleObj===bullet){check(true,"teammate grabs real native projectile "+phase,{owner:owner.id,holder:holder.id,id:control.id,life:bullet.liv});heldAt=s.runtime.tick;send("hold");}
    else if(bullet==null || !bullet.in_chain || bullet.babah){check(false,"projectile survives until teammate grab "+phase);send("settle");}
   }else if(control.stage=="hold") {
    if(phase<2 && s.runtime.tick-heldAt>=12)send("return");
    else if(phase>=2 && (!bullet.in_chain || bullet.babah || bullet.liv<=3)) {
     check(holder.unit.teleObj==null,"native fuse expires while teammate holds; no stuck reference "+phase);send("settle");
    }
   }else if(control.stage=="return") {
    if(holder.unit.teleObj==null){reversed=holder.id==1?bullet.dx<0:bullet.dx>0;check(reversed,"native E returns projectile away from holder "+phase,{dx:bullet.dx,dy:bullet.dy});send("await-end");}
   }else if(control.stage=="await-end" && (!bullet.in_chain || bullet.babah || bullet.liv<=3))send("settle");
   if(bullet!=null) {
    monotonic=monotonic && (isNaN(lastLife) || bullet.liv<=lastLife);lastLife=bullet.liv;
    if(control.stage=="settle" && elapsed>800 && api.read("join-grab-"+phase+".json")!=null) {
     check(monotonic && bullet.owner===owner.unit && s.runtime.projectileId(bullet)==control.id,"owner, native fuse and physical identity retained "+phase);
     check(s.runtime.spawnsByPlayer[owner.id]-beforeSpawns==1,"one real quick-slot projectile, no replica spawn "+phase,{count:s.runtime.spawnsByPlayer[owner.id]-beforeSpawns});begin();
    }
   }
   if(getTimer()-at>18000){check(false,"native projectile phase completes",{phase:phase,stage:control.stage,life:bullet==null?null:bullet.liv,held:holder.unit.teleObj===bullet});send("end");}
  }
 }
}
