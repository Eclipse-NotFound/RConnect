package {
 import flash.display.MovieClip;
 import flash.system.ApplicationDomain;
 import flash.utils.getQualifiedClassName;
 import flash.utils.getTimer;

 /** Same external real-Q test for old and new B. No calls to candidate-only
  * withCursorLight, no injected native teleport and no fabricated visibility. */
 public final class BDarkTeleportCases {
  private var mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,role:String,api:Object;
  private var room:Object,floorY:Number,control:Object={},phase:String="",lastRead:int=0,at:int=0;
  private var index:int=0,started:Boolean=false,seen:String="",prepared:String="";
  private var fromX:Number,toX:Number,stableY:Number,manaBefore:Number,initialEpoch:uint,maxCharge:int=0;
  private var tick:uint=0,chargeSamples:int=0,markerGood:int=0,lastCharge:int=-1;
  private var lastMarker:Object,restoreVision:Boolean=false;
  public var finished:Boolean=false;
  public function BDarkTeleportCases(m:Object,r:Object,d:ApplicationDomain,c:Object,side:String,a:Object) {
   mod=m;root=r;domain=d;cfg=c;role=side;api=a;room=a.home;floorY=Number(a.floorY);
  }
  private function check(ok:Boolean,name:String,data:Object=null):void {api.check(ok,"dark Q: "+name,data);}
  private function now():int{return getTimer();}
  private function name():String{return ["join-lit","host-lit-only","solid-target"][index];}
  private function acknowledge(data:Object):void {api.write("join-dark-q-"+control.stage+".json",data);seen=control.stage;}
  private function ack():Object{return api.read("join-dark-q-"+phase+".json");}
  private function publish(stage:String,hold:Boolean=false):void {
   phase=stage;at=now();control={stage:stage,index:index,kind:name(),hold:hold,x:toX,y:floorY-39,
    from:fromX,floor:floorY,room:mod.access.keyFor(room),tick:mod.host.runtime.tick,expected:index==0};
   api.write("dark-q-control.json",control);
  }
  public function input():void {
   if(finished)return;
   if(role=="join" && now()-lastRead>100) {
    lastRead=now();var next:Object=api.read("dark-q-control.json");
    if(next!=null) {
     if(next.stage!=control.stage){at=now();chargeSamples=markerGood=0;lastCharge=-1;}
     control=next;index=int(next.index);floorY=Number(next.floor);toX=Number(next.x);fromX=Number(next.from);
    }
   }
   var w:Object=mod.access.world;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
   if(control.stage==null)return;
   w.celX=Number(control.x);w.celY=Number(control.y);
   w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;
   if(role=="join" && control.hold)w.ctr.keyTele=true;
  }
  public function step():void {
   if(finished)return;
   if(!started) {
    started=true;restoreVision=mod.vision.enabled;mod.vision.enabled=false;
    if(role=="host")setupCase();
   }
   if(role=="join"){joinStep();return;}
   if(phase=="end") {
    if(ack()!=null && mod.role==""){mod.vision.enabled=restoreVision;finished=true;api.finish();}return;
   }
   var a:Object=mod.host.actors[1],g:Object=a.unit;
   if(phase.indexOf("ready-")==0 && ack()!=null && now()-at>600) {
    var client:Object=ack(),nativeView:Object=hostVisibility();
    check(nativeView.hostVisible==(index==1),"host target light is independently computed "+name(),nativeView);
    check(nativeView.remoteVisible==(index!=1),"remote ActorSight computes its own target light "+name(),nativeView);
    check(client.localCheck==Boolean(control.expected),"local native target predicate has expected result "+name(),client);
    check(client.collision==(index==2),"collision rejection is independent of light "+name(),client);
    check(index==1?client.light<0.8:client.light>=0.8,"join local light matches fixture "+name(),client);
    // Native floor resolution can settle the fixture at floorY+1. Retain the
    // actual stationary position, not its pre-physics setLocPos coordinate.
    stableY=g.Y;manaBefore=g.mana;initialEpoch=mod.access.positionEpoch(g);maxCharge=0;tick=mod.host.runtime.tick;
    publish("hold-"+index,true);
   }else if(phase.indexOf("hold-")==0) {
    maxCharge=Math.max(maxCharge,g.t_port);
    if(maxCharge>=35 && ack()!=null) {
     check(maxCharge>=g.pers.portTime && g.teleObj==null,"native Q charges without grabbing an object "+name(),{charge:maxCharge,minimum:g.pers.portTime,held:g.teleObj!=null});
     client=ack();check(client.markerGood==client.samples && client.samples>=2,"native visible target marker agrees with own sight "+name(),client);
     publish("release-"+index);tick=mod.host.runtime.tick;
    }
   }else if(phase.indexOf("release-")==0 && mod.host.runtime.tick-tick>=25 && ack()!=null) {
    var expectedX:Number=index==0?toX:fromX,after:uint=mod.access.positionEpoch(g);
    check(Math.abs(g.X-expectedX)<0.06 && Math.abs(g.Y-stableY)<0.06,"real Q release has correct position "+name(),{x:g.X,y:g.Y,expectedX:expectedX,expectedY:stableY,floor:floorY,charge:maxCharge});
    check(index==0?after==initialEpoch+1 && g.mana<manaBefore:after==initialEpoch && g.mana==manaBefore,
     "only accepted cast spends mana and records one position discontinuity "+name(),{epochBefore:initialEpoch,epochAfter:after,manaBefore:manaBefore,manaAfter:g.mana});
    client=ack();check(Math.abs(client.x-expectedX)<0.06 && Math.abs(client.y-stableY)<0.06,"join receives authoritative cast result "+name(),{actual:client,expectedX:expectedX,expectedY:stableY});
    if(++index<3)setupCase();else publish("end");
   }
   if(phase!="end" && now()-at>18000) {
    check(false,"real Q phase completes",{phase:phase,charge:maxCharge,work:g.work,held:g.teleObj!=null,view:hostVisibility()});publish("end");
   }
  }
  /** Remove only isolated test content using native lifecycle; preserve players. */
  private function clearObjects():void {
   var o:Object=room.firstObj,next:Object;
   while(o!=null) {
    next=o.nobj;o.remVisual();
    if(getQualifiedClassName(o)=="fe.graph::Part")o.setNull();else room.remObj(o);
    o=next;
   }
   var players:Array=[];
   for each(o in room.units)if(o!=null){if(o.player)players.push(o);else{o.disabled=true;o.remVisual();}}
   room.units=players;room.objs=[];room.acts=[];room.bonuses=[];
  }
  private function resetDarkGrid(loc:Object):void {
   // Start as an unexplored dark room. Only native lighting will turn tiles on.
   for(var x:int=0;x<loc.spaceX;x++)for(var y:int=0;y<loc.spaceY;y++)loc.space[x][y].visi=loc.space[x][y].t_visi=0;
   loc.relight_t=0;
  }
  private function fillNativeLight(loc:Object):void {loc.lighting();for(var n:int=0;n<11;n++)loc.lighting2();}
  private function setupCase():void {
   if(room==null || room.limX<1040)throw new Error("Dark Q needs an ordinary test room at least 1040 px wide");
   clearObjects();toX=Math.floor((room.limX-200)/40)*40;fromX=index==1?160:toX-80;
   var row:int=int((floorY+1)/40),w:Object=mod.access.world;
   for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<=row;y++) {
    var t:Object=room.space[x][y];t.phis=y==row?1:0;t.opac=0;t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
    t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
    if(y<row){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
   }
   // A transparent solid obstacle isolates collision from sight, akin to glass.
   if(index==2)for(y=row-3;y<row;y++)room.space[int(toX/40)][y].phis=1;
   room.black=room.retDark=true;room.base=room.sky=false;room.portOn=true;room.lDist1=160;room.lDist2=320;room.visMult=1;
   for each(var a:Object in mod.host.actors) {
    a.personal.follow=false;a.personal.allowGrab=false;a.context.transitionCooldown=0;a.context.t_battle=0;
    mod.access.scope.run(a.context,function():void {
     var g:Object=a.unit;g.dropTeleObj();g.setLocPos(a.id==1?fromX:index==1?toX-80:160,floorY);g.dx=g.dy=0;
     g.invulner=true;g.ggControl=true;g.t_culd=g.t_port=0;g.mana=g.maxmana=10000;g.dmana=0;
     g.pers.recMana=g.pers.recManaMin=0;g.pers.portPoss=g.pers.spellsPoss=1;g.pers.portTime=25;
     g.pers.portMagic=950;g.pers.portMana=25;g.pers.portDown=300;g.pers.spellDown=g.pers.allDManaMult=1;
    });
    a.sight.dispose();
   }
   resetDarkGrid(room);
   var host:Object=mod.host.actors[0];
   mod.access.scope.run(host.context,function():void {room.gg=host.unit;fillNativeLight(room);});
   for(var n:int=0;n<12;n++)mod.host.actors[1].sight.update();
   room.t_alarm=0;w.t_battle=0;mod.host.runtime.rooms.showHost();publish("ready-"+index);
  }
  private function hostVisibility():Object {
   var a:Object=mod.host.actors[1],tile:Object=room.getAbsTile(toX,floorY-39);
   var probe:Object={loc:room,X:toX,Y:floorY-39,scY:0};
   return {hostLight:tile.visi,hostVisible:tile.visi>=0.8,remoteVisible:a.sight.visible(probe),targetX:toX,targetY:floorY-39};
  }
  private function joinStep():void {
   if(control.stage==null)return;
   var stage:String=String(control.stage),w:Object=mod.access.world,frame:Object=mod.replica==null?null:mod.replica.displayFrame;
   if(stage=="end") {
    acknowledge({done:true});mod.vision.enabled=restoreVision;mod.leaveSession();finished=true;api.finish();return;
   }
   if(frame==null || frame.tick<int(control.tick)+2 || mod.access.roomKey()!=control.room)return;
   var g:Object=w.gg;
   if(stage.indexOf("ready-")==0 && stage!=seen && now()-at>800 && w.loc.black && w.loc.retDark && Math.abs(g.X-fromX)<0.06) {
    if(prepared!=stage){prepared=stage;resetDarkGrid(w.loc);fillNativeLight(w.loc);}
    var localCheck:Boolean=g.checkPort(),light:Number=w.loc.getAbsTile(toX,floorY-39).visi;
    acknowledge({localCheck:localCheck,light:light,collision:w.loc.collisionUnit(toX,floorY,g.stayX,g.stayY),x:g.X,y:g.Y,room:mod.access.roomKey()});
   }else if(stage.indexOf("hold-")==0 && stage!=seen && g.t_port>=25 && g.t_port!=lastCharge) {
    lastCharge=g.t_port;var marker:MovieClip=w.gui.vis.portCel;
    ++chargeSamples;
    var expectedFrame:int=control.expected?2:3;
    if(marker.visible && marker.currentFrame==expectedFrame && g.checkPort()==Boolean(control.expected))++markerGood;
    lastMarker={visible:marker.visible,frame:marker.currentFrame,check:g.checkPort(),light:w.loc.getAbsTile(toX,floorY-39).visi,charge:g.t_port};
    if(chargeSamples>=3)acknowledge({samples:chargeSamples,markerGood:markerGood,last:lastMarker});
   }else if(stage.indexOf("release-")==0 && stage!=seen && frame.tick>=int(control.tick)+20 && g.t_port==0) {
    acknowledge({x:g.X,y:g.Y,mana:g.mana,tick:frame.tick,charge:g.t_port});
   }
  }
 }
}
