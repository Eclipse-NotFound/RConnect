package {
 import flash.events.Event; import flash.filesystem.*; import flash.utils.*; import flash.system.System;
 import flash.display.BitmapData; import flash.geom.Matrix; import flash.display.PNGEncoderOptions;
 /** Common scene, frame observer and socket echo. Adapters only translate inputs/readiness. */
 public class ABBench {
  private var mod:Object,main:Object,cfg:Object,host:Boolean,isB:Boolean,ready:Boolean=false,peerReady:Boolean=false;
  private var links:Dictionary=new Dictionary(),phase:int=-1,preparedAt:int,started:int=0,prev:int=0,lastSample:int=0;
  private var intervals:Array=[],rtts:Array=[],samples:Array=[],baseAmmo:Array=[],windows:Object={},inputFrame:int=0;
  private var armed:Boolean=false,finished:Boolean=false,phaseCounts:Array=[8,80],enemyCount:int=0,lastFire:Boolean=false;
  private var anchors:Array=[];
  private static const MAGAZINE:int=1000,SAMPLE_MS:int=750;
  private var phaseReserve:Array=[],peerMagazineReady:Boolean=false,magazineReported:Boolean=false,beginAllowed:Boolean=false;
  public var lastInputSequence:int=0;
  private var localEndSequence:int=-1,peerEndSequence:int=-1;
  private function neutral():Boolean {
   var inputs:Array=mod.host.inputs,actors:Array=mod.host.actors;
   // Released buttons can still contain a buffered press edge. The authority
   // must execute a newer, neutral command after each side stopped firing.
   return inputs[0].consumed>localEndSequence && inputs[1].consumed>peerEndSequence &&
    inputs[0].buttons==0 && inputs[1].buttons==0 && !actors[0].context.ctr.keyAttack && !actors[1].context.ctr.keyAttack;
  }
  private var readinessAt:int=0;
  private function readiness():void {
   if(started!=0 || getTimer()-preparedAt<2000 || getTimer()-readinessAt<2000)return;
   readinessAt=getTimer();var f:Object=host?mod.host.lastFrame:mod.replica.lastFrame,seen:Object=host?f:mod.replica.displayFrame;
   var commands:Array=[];
   if(host)for each(var c:Object in mod.host.inputs)commands.push({accepted:c.accepted,consumed:c.consumed,buttons:c.buttons,age:getTimer()-c.lastAt});
   log("readiness",{phase:phase,wait:getTimer()-preparedAt,players:weaponState(),commands:commands,
    peerReady:peerMagazineReady,observed:magazineReported,begin:beginAllowed,
    receivedTick:f.tick,receivedHold:f.players[1].weapon.hold,receivedCapacity:f.players[1].weapon.native.holder,
    displayTick:seen.tick,displayHold:seen.players[1].weapon.hold,spawns:f.spawnsByPlayer});
   if(getTimer()-preparedAt>20000)throw new Error("Sustained phase preparation did not complete; see readiness evidence");
  }
  private function weaponState():Array {
   var rows:Array=[];
   for each(var g:Object in actors()) {var gun:Object=g.currentWeapon;
    rows.push({id:gun.id,capacity:gun.holder,hold:gun.hold,reload:gun.t_reload,
     reserve:g.invent.items[gun.ammo].kol,attack:gun.t_attack});}
   return rows;
  }
  private function prepareMagazines():void {
   if(!isB || !host)throw new Error("Sustained preparation requires authoritative B host");
   phaseReserve=[];var records:Array=[];
   for each(var actor:Object in mod.host.actors) {
    if(actor.id!=records.length)throw new Error("Unexpected actor order");
    mod.access.scope.run(actor.context,function():void {
     var g:Object=actor.unit,gun:Object=g.currentWeapon;
     if(gun==null || gun.id!="lmg" || gun.variant!=0 || gun.ammo!="p556" || gun.rapid!=2 || gun.rashod!=1 || gun.kol!=1)
      throw new Error("Unexpected native LMG");
     var row:Object={player:actor.id,beforeCapacity:gun.holder,beforeHold:gun.hold,
      reload:gun.t_reload,attack:gun.t_attack,reserve:g.invent.items[gun.ammo].kol};
     gun.holder=MAGAZINE;gun.hold=MAGAZINE;
     phaseReserve.push(row.reserve);row.capacity=gun.holder;row.hold=gun.hold;records.push(row);
    });
   }
   if(records.length!=2)throw new Error("Missing authoritative actors");
   log("magazine-prepared",{phase:phase,capacity:MAGAZINE,sampleMs:SAMPLE_MS,players:records});
  }
  private function checkMagazines(full:Boolean):void {
   var members:Array=actors();
   if(!isB || members.length!=(host?2:1) || phaseReserve.length!=members.length)throw new Error("Missing magazine baseline");
   for(var i:int=0;i<members.length;i++) {
    var g:Object=members[i],gun:Object=g.currentWeapon;
    if(gun==null || gun.id!="lmg" || gun.holder!=MAGAZINE || gun.hold<=0 || gun.hold>MAGAZINE ||
       (full && gun.hold!=MAGAZINE) || gun.t_reload!=0 || g.invent.items[gun.ammo].kol!=phaseReserve[i])
     throw new Error("Sustained magazine contract: phase "+phase+", player "+i);
   }
  }
  public var profileBegin:Function,profileEnd:Function,finishProbe:Function;
  public function ABBench(m:Object,root:Object,c:Object){mod=m;main=root;cfg=c;host=c.role=="host";isB=c.variant=="B";
   main.stage.addEventListener(Event.ENTER_FRAME,step,false,100000);
   log("installed",cfg);
  }
  public static function log(k:String,d:Object=null):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("ABBench.log"),FileMode.APPEND);f.writeUTFBytes(JSON.stringify({kind:k,at:getTimer(),data:d})+"\n");f.close();}
  private function world():Object{return isB?mod.access.world:mod.game.world;}
  private function definition(n:String):Class {return isB?mod.access.definition(n):mod.main.loaderInfo.applicationDomain.getDefinition(n) as Class;}
  public function equip(g:Object):void {
   g.pers.setForcLevel(30);g.pers.skills.smallguns=100;g.pers.setParameters();
   if(g.currentWeapon!=null)g.currentWeapon.remVisual();
   var Weapon:Object=definition("fe.weapon.Weapon"),gun:Object=Weapon.create(g,"lmg",0);gun.setPers(g,g.pers);
   gun.hold=gun.holder;gun.hp=gun.maxhp;gun.precision=0;gun.forceRot=0;gun.findCel=false;
   g.invent.weapons.lmg=gun;g.invent.cWeaponId="lmg";g.currentWeapon=gun;g.childObjs=[gun,g.punchWeapon];gun.addVisual();
   g.invent.items[gun.ammo].kol=10000;g.pers.jammedMult=0;g.invulner=true;g.hp=g.maxhp;g.ctr.clearAll();
  }
  public function fire():Boolean {return armed && (getTimer()-started)%3000<2500;}
  private function actors():Array {return isB && host?[mod.host.actors[0].unit,mod.host.actors[1].unit]:[world().gg];}
  private function ammo():Array {var out:Array=[];for each(var g:Object in actors())out.push(g.currentWeapon.hold+g.invent.items[g.currentWeapon.ammo].kol);return out;}
  private function send(v:Object):void {v.type="ab-bench";if(isB)mod.link.send(v);else if(host)mod.session.server.broadcast(v);else mod.session.link.send(v);}
  public function message(v:Object):void {
   if(v.type!="ab-bench")return;
   if(v.op=="ready")peerReady=true;
   if(v.op=="phase" && !host){phase=int(v.phase);preparedAt=getTimer();started=0;prev=0;armed=false;magazineReported=false;beginAllowed=false;phaseReserve=[];log("phase-prepared",{phase:phase,count:phaseCounts[phase]});}
   if(v.op=="magazine-ready" && host && v.phase===phase && v.capacity===MAGAZINE && v.hold===MAGAZINE && v.reload===0)peerMagazineReady=true;
   if(v.op=="begin" && !host && v.phase===phase)beginAllowed=true;
   if(v.op=="ping")send({op:"pong",time:v.time});
   if(v.op=="pong" && started>0)rtts.push(getTimer()-int(v.time));
   if(v.op=="end" && host){
    if(!(v.seq is Number) || v.seq<=0 || v.seq!=int(v.seq))throw new Error("Missing final peer input sequence");
    peerEndSequence=int(v.seq);peerReady=true;
   }
  }
  private function watch(link:Object):void {if(link!=null && !links[link]){links[link]=true;link.addEventListener("message",function(e:Event):void {message(Object(e).data);});}}
  private function sceneReady():Boolean {
   var w:Object=world();if(w==null || w.gg==null || w.loc==null || w.land==null || w.game.curLandId!="rbl" || w.land.act.id!="rbl")return false;
   if(isB)return host?mod.host!=null && mod.host.active && mod.host.lastFrame!=null:mod.replica!=null && mod.replica.displayFrame!=null;
   if(host){if(mod.session.server!=null)for each(var l:Object in mod.session.server.clients)watch(l);}else watch(mod.session.link);
   return mod.session.rooms.ready && !mod.session.rooms.busy && mod.game.remoteCount()>0;
  }
  private function clearLane():Number {
   var r:Object=world().loc;r.mirror=false;r.base=false;
   var y:Number=Math.floor((r.limY-120)/40)*40-1,row:int=int((y+1)/40),o:Object=r.firstObj,n:Object;
   while(o!=null){n=o.nobj;o.remVisual();if(getQualifiedClassName(o)=="fe.graph::Part")o.setNull();else r.remObj(o);o=n;}
   var players:Array=[];for each(o in r.units)if(o!=null){if(o.player)players.push(o);else{o.disabled=true;o.remVisual();}}
   r.units=players;r.objs=[];r.acts=[];r.bonuses=[];
   for(var x:int=1;x<r.spaceX-1;x++)for(var t:int=1;t<=row;t++){
    var tile:Object=r.space[x][t];tile.phis=t==row?1:0;tile.water=0;tile.shelf=false;tile.diagon=tile.stair=0;tile.door=tile.trap=null;tile.visi=tile.t_visi=1;
    tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=t*40;tile.phY2=(t+1)*40;
    if(tile.phis==0){tile.front=tile.back=tile.zad="";tile.vid=tile.vid2=tile.zForm=0;}
   }r.black=false;r.visMult=1;r.isRebuild=true;world().grafon.drawLoc(r);return y;
  }
  private function spawn(count:int):void {
   var w:Object=world(),r:Object=w.loc,Type:Class=definition("fe.unit.UnitZombie"),y:Number=Math.floor((r.limY-120)/40)*40-1;
   for(var i:int=enemyCount;i<count;i++){var u:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
    u.putLoc(r,Math.min(r.limX-100,650+(i%20)*35),y-int(i/20)*100);r.units.push(u);r.addObj(u);u.addVisual();
    u.disabled=false;u.invulner=true;u.hp=u.maxhp=10000;u.lootIsDrop=true;u.xp=0;u.setVisPos();
   }enemyCount=count;r.isRebuild=true;
  }
  private function countEnemies():Object {
   var count:int=0,attached:int=0,visible:int=0,seen:Dictionary=new Dictionary();
   for each(var u:Object in world().loc.units){if(u==null || u.player)continue;
    if(getQualifiedClassName(u)=="rconnect.game::MirrorHitUnit")u=u.body;
    if(u==null || seen[u])continue;seen[u]=true;
    if(u.fraction>0 && u.fraction<100){count++;if(u.vis!=null && u.vis.parent!=null){attached++;if(u.vis.visible && u.vis.alpha>0)visible++;}}
   }return {count:count,attached:attached,visible:visible};
  }
  private function picture():void {var b:BitmapData=new BitmapData(main.stage.stageWidth,main.stage.stageHeight,false,0);b.draw(main.stage,new Matrix());
   var bytes:ByteArray=b.encode(b.rect,new PNGEncoderOptions());b.dispose();var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("ab-phase-"+phase+".png"),FileMode.WRITE);f.writeBytes(bytes);f.close();}
  private function step(e:Event):void {
   if(finished)return;
   try {
    if(!sceneReady())return;var w:Object=world(),now:int=getTimer();
    if(!ready){
     ready=true;var y:Number=host || !isB?clearLane():Math.floor((w.loc.limY-120)/40)*40-1;
     if(!isB)equip(w.gg);
     var aa:Array=actors();if(host || !isB)for(var j:int=0;j<aa.length;j++){var a:Object=aa[j];var ax:Number=250+(isB?j:(host?0:1))*80;
      anchors.push({x:ax,y:y});a.setLocPos(ax,y);a.invulner=true;a.ggControl=true;}
     w.gui.dialScript.running=false;w.gui.dialText(null);w.dialOn=false;
     log("ready",{land:w.game.curLandId,room:w.loc.id,width:w.loc.limX,height:w.loc.limY,spaceX:w.loc.spaceX,spaceY:w.loc.spaceY,stageWidth:main.stage.stageWidth,stageHeight:main.stage.stageHeight,rate:main.stage.frameRate});
     send({op:"ready"});return;
    }
    if(host && peerReady && !armed && (phase<0 || started<0) && neutral()){
     peerReady=false;phase++;if(phase>=phaseCounts.length){done();return;}
     log("neutral-before-phase",{phase:phase,localEnd:localEndSequence,peerEnd:peerEndSequence,
      localConsumed:mod.host.inputs[0].consumed,peerConsumed:mod.host.inputs[1].consumed,
      localButtons:mod.host.inputs[0].buttons,peerButtons:mod.host.inputs[1].buttons,
      localFire:mod.host.actors[0].context.ctr.keyAttack,peerFire:mod.host.actors[1].context.ctr.keyAttack});
     spawn(phaseCounts[phase]);prepareMagazines();peerMagazineReady=false;preparedAt=now;started=0;prev=0;send({op:"phase",phase:phase});log("phase-prepared",{phase:phase,count:phaseCounts[phase]});
    }
    if(phase<0)return;
    if(started<0)return;
    readiness();
    if(!host && started==0 && !magazineReported && w.gg.currentWeapon.holder==MAGAZINE && w.gg.currentWeapon.hold==MAGAZINE && w.gg.currentWeapon.t_reload==0) {
     phaseReserve=[w.gg.invent.items[w.gg.currentWeapon.ammo].kol];checkMagazines(true);magazineReported=true;
     log("magazine-observed",{phase:phase,players:weaponState()});
     send({op:"magazine-ready",phase:phase,capacity:MAGAZINE,hold:MAGAZINE,reload:0});
    }
    if(started==0 && (host?now-preparedAt>=5000 && peerMagazineReady:beginAllowed && magazineReported)){
     if(host){checkMagazines(true);send({op:"begin",phase:phase});}else checkMagazines(false);
     started=now;armed=true;inputFrame=0;intervals=[];rtts=[];samples=[];windows={};baseAmmo=ammo();prev=0;lastSample=0;if(profileBegin!=null)profileBegin();log("measure-begin",{phase:phase,ammo:baseAmmo,enemies:countEnemies()});}
    aa=actors();for(j=0;j<aa.length;j++){a=aa[j];a.currentWeapon.hp=a.currentWeapon.maxhp;a.pers.jammedMult=0;
     // setLocPos is a room-entry reset and cancels native reload timers.
     // Anchor with geometry-only setPos so the real gun keeps its lifecycle.
     if(host || !isB){a.invulner=true;a.hp=a.maxhp;a.setPos(anchors[j].x,anchors[j].y);a.dx=a.dy=0;}}
    w.cam.celX=(w.gg.X+380)*w.cam.scaleV+w.cam.vx;w.cam.celY=(w.gg.Y-45)*w.cam.scaleV+w.cam.vy;
    if(!isB){var pressed:Boolean=fire();if(!pressed)w.ctr.keyAttack=false;else if(!lastFire)w.ctr.keyAttack=true;lastFire=pressed;
     w.celX=w.gg.X+380;w.celY=w.gg.Y-45;}
    if(started<=0)return;
    checkMagazines(false);
    if(prev>0)intervals.push(now-prev);prev=now;
    if(now-lastSample>=SAMPLE_MS){lastSample=now;var positions:Array=[];for each(a in actors())positions.push({x:a.X,y:a.Y,hp:a.hp,maxhp:a.maxhp});
     var v:Object={ms:now-started,heap:System.totalMemory,ammo:ammo(),enemies:countEnemies(),players:positions};
     v.weapons=[];for each(a in actors())v.weapons.push({id:a.currentWeapon.id,capacity:a.currentWeapon.holder,hold:a.currentWeapon.hold,reserve:a.invent.items[a.currentWeapon.ammo].kol,reload:a.currentWeapon.t_reload,attack:a.currentWeapon.t_attack,requestedFire:fire(),nativeFire:a.ctr.keyAttack});
     if(isB){var f:Object=host?mod.host.lastFrame:mod.replica.displayFrame;v.hostTick=f.tick;v.shots=f.spawnsByPlayer;if(!host){v.queued=mod.replica.clock.queued;v.delay=mod.replica.clock.delay;v.underflows=mod.replica.clock.underflows;}}
     samples.push(v);send({op:"ping",time:now});log("sample",v);
    }
    if(now-started<int(cfg.seconds)*1000)return;
    armed=false;if(host)localEndSequence=lastInputSequence;intervals.sort(Array.NUMERIC);rtts.sort(Array.NUMERIC);
    log("result",{phase:phase,expectedEnemies:phaseCounts[phase],elapsed:now-started,frames:intervals.length,intervals:intervals,rtt:rtts,samples:samples,baseAmmo:baseAmmo,finalAmmo:ammo(),enemies:countEnemies(),timings:profileEnd==null?null:profileEnd()});
    picture();started=-1;
    if(!host){send({op:"end",seq:lastInputSequence});if(phase==phaseCounts.length-1)done();}
   }catch(error:*){finished=true;log("fatal",{error:String(error),stack:error.getStackTrace()});}
  }
  private function done():void {finished=true;armed=false;if(finishProbe!=null)finishProbe();log("done");}
 }
}
