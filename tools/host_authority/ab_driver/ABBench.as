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
   if(v.op=="phase" && !host){phase=int(v.phase);preparedAt=getTimer();started=0;prev=0;armed=false;log("phase-prepared",{phase:phase,count:phaseCounts[phase]});}
   if(v.op=="ping")send({op:"pong",time:v.time});
   if(v.op=="pong" && started>0)rtts.push(getTimer()-int(v.time));
   if(v.op=="end" && host){peerReady=true;}
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
    if(host && peerReady && !armed && (phase<0 || started<0)){
     peerReady=false;phase++;if(phase>=phaseCounts.length){finished=true;log("done");return;}
     spawn(phaseCounts[phase]);preparedAt=now;started=0;prev=0;send({op:"phase",phase:phase});log("phase-prepared",{phase:phase,count:phaseCounts[phase]});
    }
    if(phase<0)return;
    if(started<0)return;
    if(started==0 && now-preparedAt>=5000){started=now;armed=true;inputFrame=0;intervals=[];rtts=[];samples=[];windows={};baseAmmo=ammo();prev=0;lastSample=0;log("measure-begin",{phase:phase,ammo:baseAmmo,enemies:countEnemies()});}
    aa=actors();for(j=0;j<aa.length;j++){a=aa[j];a.currentWeapon.hp=a.currentWeapon.maxhp;a.pers.jammedMult=0;
     // setLocPos is a room-entry reset and cancels native reload timers.
     // Anchor with geometry-only setPos so the real gun keeps its lifecycle.
     if(host || !isB){a.invulner=true;a.hp=a.maxhp;a.setPos(anchors[j].x,anchors[j].y);a.dx=a.dy=0;}}
    w.cam.celX=(w.gg.X+380)*w.cam.scaleV+w.cam.vx;w.cam.celY=(w.gg.Y-45)*w.cam.scaleV+w.cam.vy;
    if(!isB){var pressed:Boolean=fire();if(!pressed)w.ctr.keyAttack=false;else if(!lastFire)w.ctr.keyAttack=true;lastFire=pressed;
     w.celX=w.gg.X+380;w.celY=w.gg.Y-45;}
    if(started<=0)return;
    if(prev>0)intervals.push(now-prev);prev=now;
    if(now-lastSample>=1000){lastSample=now;var positions:Array=[];for each(a in actors())positions.push({x:a.X,y:a.Y,hp:a.hp,maxhp:a.maxhp});
     var v:Object={ms:now-started,heap:System.totalMemory,ammo:ammo(),enemies:countEnemies(),players:positions};
     if(isB){var f:Object=host?mod.host.lastFrame:mod.replica.displayFrame;v.hostTick=f.tick;v.shots=f.spawnsByPlayer;if(!host){v.queued=mod.replica.clock.queued;v.delay=mod.replica.clock.delay;v.underflows=mod.replica.clock.underflows;}}
     samples.push(v);send({op:"ping",time:now});log("sample",v);
    }
    if(now-started<int(cfg.seconds)*1000)return;
    armed=false;intervals.sort(Array.NUMERIC);rtts.sort(Array.NUMERIC);
    log("result",{phase:phase,expectedEnemies:phaseCounts[phase],elapsed:now-started,frames:intervals.length,intervals:intervals,rtt:rtts,samples:samples,baseAmmo:baseAmmo,finalAmmo:ammo(),enemies:countEnemies()});
    picture();started=-1;
    if(!host){send({op:"end"});if(phase==phaseCounts.length-1){finished=true;log("done");}}
   }catch(error:*){finished=true;log("fatal",{error:String(error),stack:error.getStackTrace()});}
  }
 }
}
