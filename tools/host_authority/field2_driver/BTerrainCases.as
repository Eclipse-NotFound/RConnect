package {
 import flash.desktop.NativeApplication;
 import flash.display.BitmapData;
 import flash.display.PNGEncoderOptions;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.geom.Point;
 import flash.geom.Rectangle;
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;

 /** External B terrain regression. The field driver prepares the empty lane.
  * The fixture places ordinary native tiles, then ONLY real attack input makes
  * native Weapon -> Bullet -> Location.hitTile -> Tile.die destroy them.
  * Product classes are resolved dynamically; no product class is compiled in.
  * API and lifecycle are identical to BUiCases. No driver wiring belongs here. */
 public final class BTerrainCases {
  private var mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,side:String,api:Object;
  private var room:Object,gun:Object,control:Object={},wall:Array=[],beforePixels:Vector.<uint>;
  private var floorY:Number,area:Rectangle,owner:int=0,caseId:int=0,wallX:int,row:int;
  private var phase:String="",at:int=0,lastRead:int=0,stageTick:int=0,baseline:Object;
  private var joinStage:String="",checksDone:Boolean=false,shotBase:uint=0,hp:Number=0;
  private var lastHash:String="",stableTicks:int=0,seenTick:int=-1,fireTick:int=0;
  private var preparationAt:int=-1,gateLogged:Boolean=false;
  public var finished:Boolean=false;
  public function BTerrainCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)
    throw new Error("Terrain cases require the isolated field application");
   mod=m;root=r;domain=d;cfg=c;side=role;api=a;room=a.home;floorY=Number(a.floorY);
  }
  private function now():int{return getTimer();}
  private function check(ok:Boolean,name:String,data:Object=null):void {api.check(ok,"Terrain: "+name,data);}
  private function rewrite():void {api.write("terrain-live-control.json",control);}
  private function publish(name:String,fire:Boolean=false,extra:Object=null):void {
   phase=name;at=now();stageTick=mod.host==null?0:mod.host.runtime.tick;
   control={stage:name,caseId:caseId,owner:owner,fire:fire,weapon:gun==null?"":gun.id,
    x:wallX*40+20,y:floorY-65,wallX:wallX,row:row,rect:area==null?null:[area.x,area.y,area.width,area.height]};
   if(extra!=null)for(var key:String in extra)control[key]=extra[key];
   if(fire)gateLogged=false;
   rewrite();
  }
  private function ack(name:String):Object{return api.read("join-terrain-"+name+".json");}
  private function acknowledge(value:Object):void {api.write("join-terrain-"+control.stage+".json",value);joinStage=control.stage;}
  public function input():void {
   if(finished)return;
   if(side=="join" && now()-lastRead>100) {
    lastRead=now();var incoming:Object=api.read("terrain-live-control.json");
    if(incoming!=null){if(control.stage!=incoming.stage)at=now();control=incoming;}
   }
   var w:Object=mod.access.world,ctr:Object=w.ctr;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele","keyZoom"])ctr[key]=false;
   if(control.stage==null)return;
   if(control.fire===true && (side=="host"?0:1)==int(control.owner))ctr.keyAttack=true;
   w.celX=Number(control.x);w.celY=Number(control.y);
   w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;
  }
  public function step():void {
   if(finished)return;
   if(!checksDone){checksDone=true;componentChecks();}
   if(side=="join"){joinStep();return;}
   if(phase=="") {
    if(preparationAt<0){preparationAt=now();api.log("terrain-await-native",firingGates());}
    if(!nativeReady()) {
     if(now()-preparationAt>45000){check(false,"both native players finish startup/lifecycle before preparing terrain",firingGates());finishHost();}
     return;
    }
    if(mod.host.actors[0].unit.loc!==room || mod.host.actors[1].unit.loc!==room)
     throw new Error("Terrain fixture room changed during native startup; driver must prepare a new lane and floor");
    if(floorY!==Math.floor((room.limY-120)/40)*40-1)
     throw new Error("Terrain fixture floor no longer belongs to the prepared room");
    startCase();return;
   }
   if(phase=="end") {
    if(ack("end")!=null && mod.role==""){finished=true;api.finish();}return;
   }
   if(mod.host==null || !mod.host.active){check(false,"host remains active",{phase:phase});finishHost();return;}
   var tick:int=mod.host.runtime.tick,response:Object,body:Object=wallState(room,wallX,row),remaining:int=countSolid(body);
   if(control.fire===true && !gateLogged && tick-fireTick>=20) {
    gateLogged=true;api.log("terrain-native-fire-gates",firingGates());
   }
   if(phase.indexOf("fixture-")==0 && tick-stageTick>=25 && now()-at>=700) {
    beforePixels=surface().getVector(area);publishReference("baseline-"+caseId);
   }else if(phase.indexOf("baseline-")==0 && ack(phase)!=null) {
    response=ack(phase);baseline=response;
    check(response.exact===true,"both sides start from the same native wall "+label(),response);
    check(remaining==15,"fixture contains fifteen solid ordinary tiles "+label(),body);
    shotBase=mod.host.runtime.spawnsFor(mod.host.actors[owner].unit);fireTick=tick;
    publish(caseId<2?"chip-"+caseId:"break-"+caseId,true);
   }else if(phase.indexOf("chip-")==0 && minHP(body)<hp) {
    check(remaining==15,"first real machine-gun hits lower durability without death "+label(),body);
    startQuiet("quiet-hp-"+caseId);
   }else if(phase.indexOf("break-")==0 && remaining<15) {
    check(mod.host.runtime.spawnsFor(mod.host.actors[owner].unit)>shotBase,
     "native projectile spawning precedes wall death "+label(),{spawns:mod.host.runtime.spawnsFor(mod.host.actors[owner].unit)-shotBase,gun:gun.id});
    startQuiet("quiet-death-"+caseId);
   }else if(phase.indexOf("quiet-")==0 && tick!=seenTick) {
    seenTick=tick;var hash:String=pixelHash(surface().getVector(area));
    stableTicks=hash==lastHash?stableTicks+1:0;lastHash=hash;
    // Input release crosses the real transport. Let trailing native projectiles
    // and blast decals settle; never remove bullets to manufacture equality.
    if(tick-stageTick>=90 && stableTicks>=20) {
     if(phase.indexOf("quiet-hp-")==0) {
      check(remaining==15 && minHP(body)<hp,"wall remains solid throughout the hp-only observation "+label(),body);
      publishReference("hp-"+caseId);
     }else {
      check(remaining<15,"native wall death persists after effects settle "+label(),body);
      if(caseId>=2)check(remaining<=13,"real missile blast damages more than one wall tile "+label(),{remaining:remaining,radius:gun.explRadius});
      var counts:Object=pixelChange();
      check(counts.changed>0 && counts.erased>0,"native front bitmap contains a real erased wall area "+label(),counts);
      publishReference("death-"+caseId);
     }
    }
   }else if(phase.indexOf("hp-")==0 && ack(phase)!=null) {
    response=ack(phase);check(response.exact===true,"hp-only front pixels and collision match the host "+label(),response);
    check(response.redraws==baseline.redraws,"ordinary durability loss does not redraw the whole room "+label(),{before:baseline.redraws,after:response.redraws});
    check(response.incremental==baseline.incremental,"durability loss is not falsely counted as wall death "+label(),response);
    fireTick=tick;publish("break-"+caseId,true);
   }else if(phase.indexOf("death-")==0 && ack(phase)!=null) {
    response=ack(phase);check(response.exact===true,"destroyed wall pixels and collision match the host "+label(),response);
    if(response.hasIncremental===true) {
     check(Number(response.incremental)>Number(baseline.incremental),"real plain wall death uses the confirmed-pixel incremental path "+label(),{before:baseline.incremental,after:response.incremental});
     check(response.redraws==baseline.redraws,"plain wall death avoids a complete room redraw "+label(),{before:baseline.redraws,after:response.redraws});
    }else api.log("terrain-baseline-no-incremental",{caseId:caseId,redraws:Number(response.redraws)-Number(baseline.redraws)});
    api.log("terrain-live-case",{caseId:caseId,owner:owner,weapon:gun.id,baseline:baseline,result:response,
     spawns:mod.host.runtime.spawnsFor(mod.host.actors[owner].unit)-shotBase,sourceTick:tick});
    if(++caseId<4)startCase();else finishHost();
   }
   if(phase!="end" && now()-at>45000) {
    check(false,"native terrain phase completes without direct damage/die calls",{phase:phase,gun:gun==null?null:gun.id,hp:minHP(body),remaining:remaining,
     spawns:mod.host.runtime.spawnsFor(mod.host.actors[owner].unit)-shotBase,hold:gun==null?0:gun.hold,tick:tick,fireTick:fireTick,gates:firingGates()});finishHost();
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
  private function firingGates():Object {
   var s:Object=mod.host,result:Object={phase:phase,owner:owner,players:[]};
   if(s==null)return result;
   result.active=s.active;result.awaitingFirstView=s.runtime.awaitingFirstView;
   result.room=room==null?null:{base:room.base,train:room.train};
   for each(var a:Object in s.actors) {
    var g:Object=a.unit,p:Object={id:a.id,sameRoom:g.loc===room,x:g.X,y:g.Y};
    for each(var key:String in ["sost","hp","maxhp","ggControl","work","t_work","invulner","atkPoss","atkWeapon","autoAttack","visSel","stun","disabled"])p[key]=g[key];
    p.input=g.ctr==null?null:{attack:g.ctr.keyAttack,tele:g.ctr.keyTele};result.players.push(p);
   }
   if(gun!=null) {
    g=s.actors[owner].unit;var state:Object={equipped:g.currentWeapon===gun,child:g.childObjs.indexOf(gun),owner:gun.owner===g,room:gun.loc===room,
     playerLevel:g.pers.level,weaponLevel:g.pers.getWeapLevel(gun.skill),spawns:s.runtime.spawnsFor(g)-shotBase};
    for each(key in ["id","skill","lvl","perslvl","hp","hold","holder","respect","ready","is_shoot","t_attack","t_reload","t_prep","jammed","kol_shoot"])state[key]=gun[key];
    result.weapon=state;
   }
   return result;
  }
  private function label():String{return "case "+caseId+" / "+gun.id+" / "+(owner==0?"host":"join");}
  private function startQuiet(name:String):void {lastHash="";stableTicks=0;seenTick=-1;publish(name);}
  private function startCase():void {
   owner=caseId%2;var s:Object=mod.host,w:Object=mod.access.world,actor:Object=s.actors[owner];
   if(room==null || room.spaceX<24 || room.spaceY<11)throw new Error("Terrain fixture needs a 24 by 11 or larger driver lane");
   if(caseId==0) {
    // The driver's geometry lane can retain authored boxes or traps in its
    // object chain. Use the existing isolated arena's native cleanup ONCE,
    // before any measurement or shot, so they cannot absorb fixture bullets.
    var Arena:Class=domain.getDefinition("authority.ProbeArena") as Class;
    floorY=Number(Arena["floor"](room));
   }
   wallX=Math.min(25,int(room.spaceX)-5);row=int((floorY+1)/40);
   room.destroyOn=true;room.tileSpawn=0;room.black=false;
   for each(var a:Object in s.actors) {
    a.unit.setLocPos(wallX*40-(a.id==owner?500:650),floorY);a.unit.dx=a.unit.dy=0;a.unit.invulner=true;
   }
   mod.access.scope.run(actor.context,function():void {
    var g:Object=actor.unit,Weapon:Class=domain.getDefinition("fe.weapon.Weapon") as Class;
    // Native Weapon.checkAvail rejects a fresh character's level-5 LMG.
    // Prepare its ordinary character skills before creating/equipping the gun;
    // leave weapon requirements and the actual attack path unchanged.
    g.pers.setForcLevel(60);g.pers.skills.smallguns=100;g.pers.skills.explosives=100;
    g.pers.setParameters();g.pers.healAll();g.hp=g.maxhp;
    gun=Weapon["create"](g,caseId<2?"lmg":"mlau",0);gun.setPers(g,g.pers);
    gun.hp=gun.maxhp;gun.respect=0;gun.loc=room;gun.setNull();gun.addVisual2();
    if(g.currentWeapon!=null)g.currentWeapon.remVisual();g.currentWeapon=gun;g.childObjs[0]=gun;g.invent.cWeaponId=gun.id;g.invent.weapons[gun.id]=gun;gun.addVisual();
    gun.hold=gun.holder;if(gun.ammo!="")g.invent.items[gun.ammo].kol=1000;
    // Remove random spread, not native collision, damage, projectile lifetime
    // or explosion behavior. The real weapon's destroy value is kept intact.
    gun.critCh=gun.dopCh=0;gun.precision=gun.deviation=gun.recoil=gun.recoilUp=0;
   });
   check(!room.base && !room.train && gun.lvl-actor.unit.pers.getWeapLevel(gun.skill)<=2 && (!gun.perslvl || actor.unit.pers.level>=gun.perslvl),
    "native room and character requirements permit firing "+label(),firingGates());
   check(gun.destroy>0,"native weapon can damage terrain "+label(),{destroy:gun.destroy,radius:gun.explRadius});
   if(caseId>=2)check(gun.explRadius>0,"missile fixture retains a real native explosion "+label(),{radius:gun.explRadius});
   hp=caseId<2?Math.max(200,Math.ceil(gun.destroy*30)):Math.max(1,Math.floor(gun.destroy*.5));wall=[];
   for(var x:int=wallX;x<wallX+3;x++)for(var y:int=row-5;y<row;y++) {
    var tile:Object=room.space[x][y];tile.mainFrame("A");tile.indestruct=false;tile.hp=hp;tile.thre=0;
    tile.front="A";tile.back=tile.zad="";tile.fake=tile.fRear=tile.vRear=tile.v2Rear=false;
    tile.water=tile.diagon=tile.stair=tile.zForm=0;tile.shelf=false;tile.door=tile.trap=null;
    tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;tile.visi=tile.t_visi=1;wall.push(tile);
   }
   // Explosion may reach the supporting floor; keep the existing fixture floor
   // solid so it cannot introduce an unrelated water/corner/terrain transition.
   for(x=Math.max(0,wallX-8);x<Math.min(room.spaceX,wallX+11);x++)room.space[x][row].indestruct=true;
   area=new Rectangle(wallX*40-64,(row-5)*40-64,3*40+128,5*40+128).intersection(surface().rect);
   w.grafon.drawLoc(room);publish("fixture-"+caseId);
  }
  private function surface():BitmapData{return mod.access.world.grafon.frontBmp as BitmapData;}
  private function pixelHash(pixels:Vector.<uint>):String {
   var digest:uint=2166136261;for each(var pixel:uint in pixels){digest^=pixel;digest*=16777619;}return digest.toString(16);
  }
  private function pixelChange():Object {
   var pixels:Vector.<uint>=surface().getVector(area),changed:int=0,erased:int=0;
   for(var i:int=0;i<pixels.length;i++)if(pixels[i]!=beforePixels[i]){++changed;if((pixels[i]>>>24)<(beforePixels[i]>>>24))++erased;}
   return {changed:changed,erased:erased};
  }
  private function wallState(loc:Object,x0:int,y0:int):Array {
   var values:Array=[];
   for(var x:int=x0;x<x0+3;x++)for(var y:int=y0-5;y<y0;y++) {
    var t:Object=loc.space[x][y];values.push([x,y,t.phis,t.hp,t.front,t.opac,t.phX1,t.phX2,t.phY1,t.phY2,t.shelf,t.diagon,t.stair,t.water,t.zForm]);
   }
   return values;
  }
  private function countSolid(values:Object):int {var n:int=0;for each(var v:Array in values)if(v[2]==1)++n;return n;}
  private function minHP(values:Object):Number {var value:Number=Number.POSITIVE_INFINITY;for each(var v:Array in values)value=Math.min(value,Number(v[3]));return value;}
  private function publishReference(name:String):void {
   if(name=="baseline-0" || name=="death-0")pictureEvidence(name,room,area,mod.host.runtime.tick);
   publish(name,false,{reference:{tick:mod.host.runtime.tick,room:mod.access.keyFor(room),hash:pixelHash(surface().getVector(area)),tiles:wallState(room,wallX,row)}});
  }
  private function pictureEvidence(name:String,loc:Object,region:Rectangle,tick:int):void {
   // Four small images total (two phases x two roles), only in the isolated
   // application's own storage. No screen capture, product state write or
   // repeated retries. The runner already archives that storage's PNG files.
   var bitmap:BitmapData=surface(),crop:BitmapData=new BitmapData(region.width,region.height,true,0);
   var file:File=File.applicationStorageDirectory.resolvePath("terrain-evidence-"+name+".png"),stream:FileStream=new FileStream();
   var opened:Boolean=false;
   try {
    crop.copyPixels(bitmap,region,new Point());stream.open(file,FileMode.WRITE);opened=true;
    stream.writeBytes(crop.encode(crop.rect,new PNGEncoderOptions()));
   }finally {if(opened)stream.close();crop.dispose();}
   var w:Object=mod.access.world,ct:Object=loc.cTransform,fields:Array=(domain.getDefinition("authority.SceneSnapshot") as Class)["TILE"];
   var tiles:Array=[],blocks:Array=[],pixels:Vector.<uint>=bitmap.getVector(region);
   var opaque:int=0,transparent:int=0,partial:int=0;
   for each(var pixel:uint in pixels){var alpha:uint=pixel>>>24;if(alpha==0)++transparent;else if(alpha==255)++opaque;else ++partial;}
   for(var x:int=Math.max(0,int(region.x/40));x<Math.min(loc.spaceX,Math.ceil(region.right/40));x++)
    for(var y:int=Math.max(0,int(region.y/40));y<Math.min(loc.spaceY,Math.ceil(region.bottom/40));y++) {
     var tile:Object=loc.space[x][y],values:Array=[];
     for each(var key:String in fields)values.push(tile[key]);
     tiles.push({x:x,y:y,v:values,bounds:[tile.phX1,tile.phX2,tile.phY1,tile.phY2],door:tile.door!=null,trap:tile.trap!=null});
    }
   for(x=int(region.x/64);x<Math.ceil(region.right/64);x++)for(y=int(region.y/64);y<Math.ceil(region.bottom/64);y++) {
    var block:Rectangle=new Rectangle(x*64,y*64,64,64).intersection(region);
    blocks.push({x:block.x,y:block.y,w:block.width,h:block.height,hash:pixelHash(bitmap.getVector(block))});
   }
   api.log("terrain-picture-evidence",{phase:name,role:side,tick:tick,file:file.name,rect:[region.x,region.y,region.width,region.height],
    hash:pixelHash(pixels),alpha:{opaque:opaque,transparent:transparent,partial:partial},surface:[bitmap.width,bitmap.height],
    sameWorldRoom:w.loc===loc,sameRoomGrafon:w.grafon===loc.grafon,sameGrafonRoom:w.grafon.loc===loc,
    room:{key:mod.access.keyFor(loc),mirror:loc.mirror,homeStable:loc.homeStable,black:loc.black,darkness:loc.darkness,
     backwall:loc.backwall,transpFon:loc.transpFon,spaceX:loc.spaceX,spaceY:loc.spaceY},
    tint:ct==null?null:[ct.redMultiplier,ct.greenMultiplier,ct.blueMultiplier,ct.alphaMultiplier,ct.redOffset,ct.greenOffset,ct.blueOffset,ct.alphaOffset],
    fields:fields,tiles:tiles,blocks:blocks});
  }
  private function joinStep():void {
   if(control.stage==null || joinStage==control.stage)return;
   if(control.stage=="end") {acknowledge({done:true});mod.leaveSession();finished=true;api.finish();return;}
   var replica:Object=mod.replica,ref:Object=control.reference;
   if(ref!=null && replica!=null && replica.displayFrame!=null && int(replica.displayFrame.tick)>=int(ref.tick)) {
    var scene:Object=replica.scene,r:Array=control.rect,region:Rectangle=new Rectangle(r[0],r[1],r[2],r[3]);
    var hash:String=pixelHash(surface().getVector(region)),values:Array=wallState(scene.room,int(control.wallX),int(control.row));
    if(control.stage=="baseline-0" || control.stage=="death-0")pictureEvidence(control.stage,scene.room,region,replica.displayFrame.tick);
    var pixelsSame:Boolean=hash==ref.hash,collisionSame:Boolean=JSON.stringify(values)==JSON.stringify(ref.tiles),roomSame:Boolean=scene.key==ref.room;
    // A displayed frame at/after the stable source reference must match now.
    // Do not retry mismatches until they happen to pass.
    acknowledge({exact:pixelsSame && collisionSame && roomSame,pixels:pixelsSame,collision:collisionSame,room:roomSame,
     expectedHash:ref.hash,hash:hash,expectedTiles:collisionSame?null:ref.tiles,tiles:collisionSame?null:values,
     sourceTick:ref.tick,displayTick:replica.displayFrame.tick,redraws:scene.terrainRedraws,
     hasIncremental:"incrementalWalls" in scene,incremental:"incrementalWalls" in scene?scene.incrementalWalls:0});
   }
   if(now()-at>45000) {check(false,"join receives a confirmed terrain reference",{stage:control.stage});mod.leaveSession();finished=true;api.finish();}
  }
  private function finishHost():void {publish("end");}
  private function componentChecks():void {
   BTerrainBoundsChecks.run(mod.access,domain,function(ok:Boolean,name:String):void {check(ok,"bounds: "+name);});
   if(!domain.hasDefinition("authority.TerrainPatch")) {
    api.log("terrain-components-absent",{side:side,note:"Baseline predates TerrainPatch; component checks skipped, live weapon cases still run."});return;
   }
   if(domain.hasDefinition("authority.TerrainPatchChecks")) {
    var all:Class=domain.getDefinition("authority.TerrainPatchChecks") as Class;
    all["run"](function(ok:Boolean,name:String):void {check(ok,"component: "+name);});return;
   }
   // The optional test class is normally tree-shaken from the product. These
   // are its inputs/assertions only; invoke the actual compiled algorithms.
   var patch:Class=domain.getDefinition("authority.TerrainPatch") as Class;
   var snapshot:Class=domain.getDefinition("authority.SceneSnapshot") as Class;
   var ink:Class=domain.getDefinition("authority.TerrainInk") as Class;
   var fields:Array=snapshot["TILE"],before:Array=[],indices:Object={};
   for(var i:int=0;i<fields.length;i++){indices[fields[i]]=i;before.push(0);}
   before[indices.phis]=1;before[indices.hp]=100;before[indices.front]="metal";before[indices.back]="brick";
   before[indices.zad]="";before[indices.opac]=1;before[indices.vid]=4;before[indices.vid2]=7;
   var after:Array=before.concat();after[indices.phis]=0;after[indices.hp]=-20;after[indices.front]="";after[indices.opac]=after[indices.vid]=after[indices.vid2]=0;
   check(patch["isFrontDestruction"](before,after,true),"component: ordinary native death shape accepted");
   check(!patch["isFrontDestruction"](before,after,false),"component: door/trap provenance must be absent on both sides");
   check(!patch["isFrontDestruction"](null,after,true),"component: no previous scene rejects incremental death");
   var variant:Array;
   for each(var name:String in fields) {
    if(["hp","phis","front","opac","vid","vid2"].indexOf(name)>=0)continue;
    variant=after.concat();variant[indices[name]]=variant[indices[name]] is String?"different":1;
    check(!patch["isFrontDestruction"](before,variant,true),"component: unrelated change rejects patch / "+name);
   }
   for each(name in ["water","diagon","stair","shelf","fRear","vRear","v2Rear"]) {
    var otherBefore:Array=before.concat();variant=after.concat();otherBefore[indices[name]]=variant[indices[name]]=1;
    check(!patch["isFrontDestruction"](otherBefore,variant,true),"component: unchanged special geometry rejects patch / "+name);
   }
   variant=before.concat();variant[indices.phis]=3;
   check(!patch["isFrontDestruction"](variant,after,true),"component: background collision rejects patch");
   var prior:Object={epoch:4,front:{}},state:Object={epoch:4,front:{}};
   for(var bx:int=0;bx<2;bx++)for(var by:int=0;by<2;by++) {
    var key:String=bx+":"+by;prior.front[key]={x:bx*64,y:by*64,pixels:{w:64,h:64}};state.front[key]={x:bx*64,y:by*64,pixels:{w:64,h:64}};
   }
   check(ink["freshFrontCoverage"](prior,state,40,40,40,40),"component: all four fresh blocks cover crossed tile");
   var block:Object=state.front["1:1"];state.front["1:1"]=prior.front["1:1"];
   check(!ink["freshFrontCoverage"](prior,state,40,40,40,40),"component: reused pixel block rejects coverage");
   delete state.front["1:1"];
   check(!ink["freshFrontCoverage"](prior,state,40,40,40,40),"component: missing pixel block rejects coverage");
   state.front["1:1"]=block;block.pixels.w=15;
   check(!ink["freshFrontCoverage"](prior,state,40,40,40,40),"component: short edge rejects coverage");
   block.pixels.w=64;state.epoch=5;
   check(!ink["freshFrontCoverage"](prior,state,40,40,40,40),"component: new native raster epoch rejects patch");state.epoch=4;
   check(!ink["freshFrontCoverage"](null,state,40,40,40,40),"component: no prior bitmap rejects coverage");
   check(!ink["freshFrontCoverage"](prior,state,-1,40,40,40),"component: negative bounds reject coverage");
  }
 }
}
