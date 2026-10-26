package {
 import flash.desktop.NativeApplication;
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;

 /** External live regression: actual E input, native AI, actual weapon/bullets.
  * Same constructor/input/step/finished API as BUiCases. The host's preceding
  * BSecurityChecks/driver owns arena preparation. No product class is linked.
  * Does not set celUnit, aiState, attack, actionObj, is_act or a success result. */
 public final class BSecurityLiveCases {
  private var mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,side:String,api:Object;
  private var room:Object,terminal:Object,turret:Object,control:Object={},stats:Object;
  private var floorY:Number,caseId:int=0,owner:int=0,other:int=1,skill:int=1;
  private var phase:String="",at:int=0,lastRead:int=0,started:int=0,seenTick:int=-1,preparationAt:int=-1;
  private var seenAction:Boolean=false,joinStage:String="",sourcePolicy:Boolean=true;
  private var initialPlayers:Array,caseHadFailure:Boolean=false;
  public var finished:Boolean=false;
  public function BSecurityLiveCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)
    throw new Error("Security live cases require the isolated field application");
   mod=m;root=r;domain=d;cfg=c;side=role;api=a;room=a.home;floorY=Number(a.floorY);
  }
  private function now():int{return getTimer();}
  private function check(ok:Boolean,name:String,data:Object=null):void {api.check(ok,"Security live: "+name,data);}
  private function publish(name:String,action:String="",extra:Object=null):void {
   phase=name;at=now();control={stage:name,caseId:caseId,owner:owner,other:other,skill:skill,action:action,
    x:terminal==null?300:terminal.X,y:terminal==null?floorY-100:terminal.Y-terminal.scY/2};
   // Both AIR processes run independently: even a single host step can expose
   // the first write. Build the complete stage before publishing it once.
   if(extra!=null)for(var key:String in extra)control[key]=extra[key];
   api.write("security-live-control.json",control);
  }
  private function ack(name:String):Object{return api.read("join-security-live-"+name+".json");}
  private function acknowledge(value:Object):void {api.write("join-security-live-"+control.stage+".json",value);joinStage=control.stage;}
  public function input():void {
   if(finished)return;
   if(side=="join" && now()-lastRead>100) {
    lastRead=now();var incoming:Object=api.read("security-live-control.json");
    if(incoming!=null) {if(control.stage!=incoming.stage)at=now();control=incoming;}
   }
   var w:Object=mod.access.world,ctr:Object=w.ctr;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele","keyZoom"])ctr[key]=false;
   if(control.stage==null)return;
   if(control.action==side)ctr.keyAction=true;
   w.celX=Number(control.x);w.celY=Number(control.y);
   if(w.cam!=null){w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;}
  }
  public function step():void {
   if(finished)return;
   if(side=="join"){joinStep();return;}
   if(phase=="") {
    if(preparationAt<0){preparationAt=now();sourcePolicy=mod.host.security.shared;api.log("security-live-await-native",diagnostic());}
    // A delayed first view suspends native simulation. Healing/repositioning a
    // dying player cannot cancel that native lifecycle; its later resurrection
    // would overwrite the fixture position and remove preparation protection.
    if(!nativeReady()) {
     if(now()-preparationAt>45000){caseHadFailure=true;check(false,"both native players finish startup/lifecycle before fixture preparation",diagnostic());finishHost();}
     return;
    }
    if(mod.host.actors[0].unit.loc!==room || mod.host.actors[1].unit.loc!==room)
     throw new Error("Security fixture room changed during native startup; driver must prepare a new lane and floor");
    if(floorY!==Math.floor((room.limY-120)/40)*40-1)
     throw new Error("Security fixture floor no longer belongs to the prepared room");
    savePlayers();startCase();return;
   }
   if(phase=="end") {
    if(ack("end")!=null && mod.role==""){finished=true;api.finish();}return;
   }
   if(mod.host==null || !mod.host.active){check(false,"host session stays active",{phase:phase});finishHost();return;}
   var s:Object=mod.host,a:Object=s.actors[owner],tick:int=s.runtime.tick;
   if(phase.indexOf("ready-")==0 && now()-at>600 && ack(phase)!=null) {
    seenAction=false;publish("unlock-"+caseId,owner==0?"host":"join");
   }else if(phase.indexOf("unlock-")==0) {
    if(a.unit.actionObj===terminal.inter)seenAction=true;
    if(s.security.capture(terminal.inter,owner).lock==0 && a.unit.actionObj==null) {
     check(seenAction,"actual E input completed personal terminal hacking "+label(),{nativeTick:tick});
     check(s.security.capture(terminal.inter,other).lock>0,"other player's terminal remains personally locked "+label());
     publish("release-"+caseId,"",{unlockTick:tick});
    }
   }else if(phase.indexOf("release-")==0 && now()-at>600 && ack(phase)!=null) {
    seenAction=false;publish("activate-"+caseId,owner==0?"host":"join");
   }else if(phase.indexOf("activate-")==0) {
    if(a.unit.actionObj===terminal.inter)seenAction=true;
    if(s.security.permission(turret,a.unit)===true && a.unit.actionObj==null) {
     check(seenAction,"second actual E action activates native security terminal "+label());
     check(s.security.permission(turret,s.actors[other].unit)===false,"native activation grants only its operator "+label());
     var state:Object=turret.rconnectSecurityState();
     check(state.reprog && !state.sleep && turret.fraction==100,"personal skill reprograms a live native turret "+label(),state);
     startLive();
    }
   }else if(phase.indexOf("live-")==0) {
    if(tick!=seenTick){seenTick=tick;sample();}
    if(tick-started>=240)endLive();
   }else if(phase.indexOf("settle-")==0 && ack(phase)!=null && now()-at>700) {
    var response:Object=ack(phase);check(response.exact===true,"join confirms final health of both real players "+label(),response);
    if(++caseId<4)startCase();else finishHost();
   }
   if(phase!="end" && now()-at>45000) {
    caseHadFailure=true;check(false,"native phase completes without a forced target or attack",diagnostic());finishHost();
   }
  }
  private function nativeReady():Boolean {
   if(mod.host==null || !mod.host.active || mod.host.runtime.awaitingFirstView)return false;
   for each(var a:Object in mod.host.actors) {
    var g:Object=a.unit;
    if(g.sost!=1 || g.hp<=0 || !g.ggControl || ["die","res","change"].indexOf(g.work)>=0)return false;
   }
   return true;
  }
  private function label():String{return "case "+caseId+" / skill "+skill+" / "+(owner==0?"host":"join");}
  private function savePlayers():void {
   initialPlayers=[];
   for each(var a:Object in mod.host.actors) {
    var g:Object=a.unit,p:Object=a.context.pers,record:Object={unit:{},pers:{}};
    for each(var key:String in ["maxhp","hp","invulner","dexter","dexterPlus","dodge","skin","armor","marmor","armor_hp","shithp","shitArmor","obs","visibility","stealthMult","demask"])
     record.unit[key]=g[key];
    for each(key in ["security","hacker","hackerMaster","lockPickTime","regenFew","regenMax","level","xpCur","xpPrev","xpNext","headHP","torsHP","legsHP","bloodHP","manaHP"])record.pers[key]=p[key];
    initialPlayers.push(record);
   }
  }
  private function startCase():void {
   owner=caseId%2;other=1-owner;skill=1+int(caseId/2);caseHadFailure=false;
   var s:Object=mod.host,Box:Class=mod.access.definition("fe.loc.Box"),Turret:Class=mod.access.definition("fe.unit.UnitTurret");
   room=s.actors[0].unit.loc;
   if(s.actors[1].unit.loc!==room || !isFinite(floorY))throw new Error("Security live fixture requires both players in the prepared room");
   if(room.limX<900)throw new Error("Security live fixture requires at least 900 units of lane width");
   s.security.shared=false;s.security.resetWorld();
   for each(var a:Object in s.actors)mod.access.scope.run(a.context,function():void {
    var g:Object=a.unit,p:Object=a.context.pers;
    g.setLocPos(a.id==owner?280:760,floorY);g.dx=g.dy=0;
    // The native unlock can award XP and recompute maxhp. Preparation must
    // not be interrupted by turret fire before the second real E completes.
    // This protection ends explicitly before any live combat sample.
    p.setForcLevel(60);p.setParameters();p.healAll();
    g.hp=g.maxhp;g.invulner=true;g.dexter=g.dexterPlus=g.dodge=0;
    g.skin=g.armor=g.marmor=g.armor_hp=g.shithp=g.shitArmor=0;
    g.visibility=2000;g.stealthMult=1;g.demask=0;g.obs=g.maxObs;
    p.regenFew=p.regenMax=0;p.security=a.id==owner?skill:0;
    p.hacker=p.hackerMaster=10;p.lockPickTime=45;
   });
   mod.access.scope.run(s.actors[0].context,function():void {
    // Wall-mounted terminal is above the firing corridor, so turret fire
    // cannot accidentally destroy the object before its input test completes.
    terminal=new Box(room,"term1",300,floorY-100);terminal.nazv="B Security live terminal "+caseId;
    terminal.inter.lockTip=2;terminal.inter.lockLevel=1;terminal.inter.setAct("lock",1);
    terminal.inter.t_action=50;terminal.inter.at_once=0;terminal.inter.update();
    room.objs.push(terminal);room.addObj(terminal);
    turret=new Turret("",100,<unit tr="1" vis="right"/>,null);
    turret.id="b-security-live-"+caseId;turret.putLoc(room,400,floorY);
    turret.fixed=turret.stay=true;turret.doop=false;turret.lootIsDrop=true;turret.xp=17;
    turret.hp=turret.maxhp=10000;turret.oduplenie=0;turret.overLook=true;turret.vision=500;
    room.units.push(turret);room.addObj(turret);
   });
   publish("ready-"+caseId,"",{room:mod.access.keyFor(room)});
   api.log("security-live-start",diagnostic());
  }
  private function startLive():void {
   var s:Object=mod.host;
   // Only arrange the fixture and refill health. Native AI decides its own
   // target, aim, alert timing, attack cadence, projectile creation and damage.
   for each(var a:Object in s.actors)mod.access.scope.run(a.context,function():void {
    a.unit.setLocPos(a.id==owner?560:760,floorY);a.unit.dx=a.unit.dy=0;
    // Re-establish the fixture after native XP/level recalculation, then
    // remove preparation protection before the first measured native tick.
    a.context.pers.setParameters();a.context.pers.healAll();a.unit.hp=a.unit.maxhp;a.unit.invulner=false;
    a.unit.dexter=a.unit.dexterPlus=a.unit.dodge=0;
    a.unit.skin=a.unit.armor=a.unit.marmor=a.unit.armor_hp=a.unit.shithp=a.unit.shitArmor=0;
    a.context.pers.regenFew=a.context.pers.regenMax=0;
   });
   check(!s.actors[0].unit.invulner && !s.actors[1].unit.invulner &&
    s.actors[0].unit.sost<3 && s.actors[1].unit.sost<3 && s.actors[0].unit.ggControl && s.actors[1].unit.ggControl,
    "preparation ends with two living controllable players and no invulnerability "+label(),diagnostic());
   started=s.runtime.tick;seenTick=-1;
   stats={samples:0,selectedUnsafe:0,selectedProtected:0,geometry:0,shotsInLine:0,
    baseSpawns:s.runtime.spawnsFor(turret),baseShots:turret.currentWeapon.kol_shoot,lastShots:turret.currentWeapon.kol_shoot,
    protectedStart:s.actors[owner].unit.hp,unsafeStart:s.actors[other].unit.hp,
    protectedMin:s.actors[owner].unit.hp,unsafeMin:s.actors[other].unit.hp,firstUnsafeDamage:-1,firstSpawn:-1,
    protectedInvulner:0,unsafeInvulner:0,deathSamples:0,
    unsafeMaxhpMin:s.actors[other].unit.maxhp,unsafeMaxhpMax:s.actors[other].unit.maxhp};
   publish("live-"+caseId,"",{beginTick:started});api.log("security-live-combat-start",diagnostic());
  }
  private function sample():void {
   var s:Object=mod.host,safe:Object=s.actors[owner].unit,unsafe:Object=s.actors[other].unit,w:Object=turret.currentWeapon;
   ++stats.samples;
   if(turret.celUnit===unsafe)++stats.selectedUnsafe;
   if(turret.celUnit===safe)++stats.selectedProtected;
   stats.protectedMin=Math.min(stats.protectedMin,safe.hp);stats.unsafeMin=Math.min(stats.unsafeMin,unsafe.hp);
   if(safe.invulner)++stats.protectedInvulner;if(unsafe.invulner)++stats.unsafeInvulner;
   if(safe.sost>=3 || unsafe.sost>=3 || safe.hp<=0 || unsafe.hp<=0)++stats.deathSamples;
   stats.unsafeMaxhpMin=Math.min(stats.unsafeMaxhpMin,unsafe.maxhp);stats.unsafeMaxhpMax=Math.max(stats.unsafeMaxhpMax,unsafe.maxhp);
   if(unsafe.hp<stats.unsafeStart && stats.firstUnsafeDamage<0)stats.firstUnsafeDamage=s.runtime.tick-started;
   if(s.runtime.spawnsFor(turret)>stats.baseSpawns && stats.firstSpawn<0)stats.firstSpawn=s.runtime.tick-started;
   // The protected body must actually stand between muzzle and target, not
   // merely be elsewhere in the same room. The gun's real aim ray crosses it.
   var x0:Number=w.X,y0:Number=w.Y,dx:Number=Math.cos(w.rot),dy:Number=Math.sin(w.rot);
   var distance:Number=dx==0?-1:(safe.X-x0)/dx,y:Number=y0+distance*dy;
   var line:Boolean=turret.celUnit===unsafe && safe.X>x0 && safe.X<unsafe.X && distance>0 && y>=safe.Y1 && y<=safe.Y2;
   if(line)++stats.geometry;
   var shots:uint=uint(w.kol_shoot);
   if(shots>stats.lastShots && line)stats.shotsInLine+=shots-stats.lastShots;
   stats.lastShots=shots;
  }
  private function endLive():void {
   var s:Object=mod.host,detail:Object=diagnostic();detail.stats=stats;
   detail.elapsedTicks=s.runtime.tick-started;detail.spawns=s.runtime.spawnsFor(turret)-stats.baseSpawns;
   detail.shots=turret.currentWeapon.kol_shoot-stats.baseShots;
   check(detail.elapsedTicks>=240 && stats.samples>=180,"native firing scene runs at least 180 distinct ticks "+label(),detail);
   check(stats.deathSamples==0,"native level and organ health keep both fixture players alive without healing during samples "+label(),detail);
   check(detail.spawns>0 && detail.shots>0 && stats.selectedUnsafe>0,"native AI acquires unauthorized player and creates real bullets "+label(),detail);
   check(stats.unsafeMin<stats.unsafeStart,"actual turret bullets reduce unauthorized player's health "+label(),detail);
   check(stats.geometry>=30 && stats.shotsInLine>0,"authorized teammate stands across the firing line during real shots "+label(),detail);
   check(stats.protectedMin==stats.protectedStart && stats.protectedInvulner==0 && stats.unsafeInvulner==0,
    "authorized teammate takes no damage without invulnerability "+label(),detail);
   check(stats.selectedProtected==0,"turret never reacquires the authorized teammate during the live window "+label(),detail);
   var tick:int=s.runtime.tick;removeFixture();
   publish("settle-"+caseId,"",{finalTick:tick,health:[s.actors[0].unit.hp,s.actors[1].unit.hp]});
  }
  private function diagnostic():Object {
   var s:Object=mod.host;
   if(s==null)return {phase:phase,caseId:caseId};
   var operator:Object=s.actors[owner].unit;
   return {phase:phase,caseId:caseId,owner:owner,skill:skill,tick:s.runtime.tick,enemyAct:mod.access.world.enemyAct,awaitingFirstView:s.runtime.awaitingFirstView,
    permission:turret==null?null:[s.security.permission(turret,s.actors[0].unit),s.security.permission(turret,s.actors[1].unit)],
    nativeTurret:turret==null?null:turret.rconnectSecurityState(),
    selected:turret==null?-1:turret.celUnit===s.actors[0].unit?0:turret.celUnit===s.actors[1].unit?1:-1,
    playerHP:[s.actors[0].unit.hp,s.actors[1].unit.hp],playerMaxHP:[s.actors[0].unit.maxhp,s.actors[1].unit.maxhp],
    playerInvulner:[s.actors[0].unit.invulner,s.actors[1].unit.invulner],playerSost:[s.actors[0].unit.sost,s.actors[1].unit.sost],
    playerControl:[s.actors[0].unit.ggControl,s.actors[1].unit.ggControl],playerWork:[s.actors[0].unit.work,s.actors[1].unit.work],
    playerPosition:[[s.actors[0].unit.X,s.actors[0].unit.Y],[s.actors[1].unit.X,s.actors[1].unit.Y]],
    action:terminal!=null && operator.actionObj===terminal.inter,actionTime:[operator.t_action,operator.mt_action],
    terminal:terminal==null?null:{x:terminal.X,y:terminal.Y,x1:terminal.X1,x2:terminal.X2,y1:terminal.Y1,y2:terminal.Y2,
     cursor:[mod.access.world.celX,mod.access.world.celY],onCursor:terminal.onCursor,
     distanceSquared:Math.pow(operator.X-terminal.X,2)+Math.pow(operator.Y-terminal.Y,2),
     localPointer:room.celObj===terminal,personal:s.security.capture(terminal.inter,owner)}};
  }
  private function removeFixture():void {
   if(turret!=null) {
    var object:Object=room.firstObj,next:Object;
    while(object!=null) {
     next=object.nobj;
     if("owner" in object && object.owner===turret && "weap" in object && "begx" in object)room.remObj(object);
     object=next;
    }
    room.remObj(turret);var index:int=room.units.indexOf(turret);if(index>=0)room.units.splice(index,1);turret=null;
   }
   if(terminal!=null){room.remObj(terminal);index=room.objs.indexOf(terminal);if(index>=0)room.objs.splice(index,1);terminal=null;}
  }
  private function finishHost():void {
   removeFixture();
   if(mod.host!=null) {
    mod.host.security.shared=sourcePolicy;mod.host.security.resetWorld();
    if(initialPlayers!=null)for each(var a:Object in mod.host.actors) {
     var record:Object=initialPlayers[a.id];
     a.context.pers.level=record.pers.level;
     mod.access.scope.run(a.context,function():void {a.context.pers.setParameters();});
     for(var key:String in record.unit)a.unit[key]=record.unit[key];
     for(key in record.pers)a.context.pers[key]=record.pers[key];
    }
   }
   publish("end","",{completedCases:caseHadFailure?caseId:4});
  }
  private function joinStep():void {
   if(control.stage==null)return;
   var name:String=String(control.stage);
   if(name=="end") {
    if(joinStage!="end"){acknowledge({done:true,completedCases:control.completedCases});mod.leaveSession();finished=true;api.finish();}return;
   }
   if(name==joinStage)return;
   if((name.indexOf("ready-")==0 || name.indexOf("release-")==0) && now()-at>300) {
    acknowledge({ready:true,stage:name});return;
   }
   if(name.indexOf("settle-")==0) {
    if(!control.hasOwnProperty("finalTick") || !(control.health is Array) || control.health.length!=2)
     throw new Error("Incomplete security settle reference: "+JSON.stringify(control));
    var f:Object=mod.replica==null?null:mod.replica.displayFrame;
    if(f==null || f.tick<control.finalTick || f.players==null || f.players[0]==null || f.players[1]==null)return;
    var health:Array=[f.players[0].hp,f.players[1].hp];
    var exact:Boolean=Math.abs(health[0]-control.health[0])<.01 && Math.abs(health[1]-control.health[1])<.01;
    if(!exact && now()-at<3000)return;
    check(exact,"presented health matches final native firing results "+name,{health:health,expected:control.health,tick:f.tick,sourceTick:control.finalTick});
    acknowledge({exact:exact,health:health,expected:control.health,tick:f.tick});
   }
  }
 }
}
