package {
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.display.MovieClip;
 import flash.events.Event;
 import flash.geom.Point;
 import flash.geom.Matrix;
 import flash.system.ApplicationDomain;
 import flash.text.TextField;
 import flash.utils.getQualifiedClassName;
 import flash.utils.getTimer;

 /** Diagnostic real Part emitter playback. Records at Event.RENDER, after
  * native camera/GUI and timeline work, without changing any product method. */
 public final class BTextMotionCases {
  private var mod:Object,root:Object,api:Object,role:String,room:Object,floorY:Number;
  private var control:Object={},phase:int=-1,at:int=0,lastRead:int=0,started:Boolean=false;
  private var beginTick:uint=0,lastSpawn:int=-1,objects:Object={},kinds:Object={},metrics:Object;
  private var phaseMetrics:Object={},previous:Object={},traceRows:Array=[],lastTrace:int=0;
  private var phaseReceived:String="",lastPresented:int=-1,joinAck:String="",ended:Boolean=false;
  private var observedFrames:int=-1,observedArrival:int=0,injectedButtons:Object={};
  private var enterFrames:uint=0,renderFrames:uint=0,lastRenderFrame:uint=0,duplicateRenders:uint=0;
  private var zoomRoom:Object;
  public var finished:Boolean=false;
  public function BTextMotionCases(m:Object,r:Object,d:ApplicationDomain,c:Object,side:String,a:Object) {
   mod=m;root=r;api=a;role=side;room=a.home;floorY=Number(a.floorY);
   root.stage.addEventListener(Event.ENTER_FRAME,requestRender,false,-200000);
   root.stage.addEventListener(Event.RENDER,observe,false,-200000);
  }
  private function requestRender(event:Event):void {
   if(finished)return;
   ++enterFrames;root.stage.invalidate();
  }
  private function ensureCamera():void {
   var w:Object=mod.access.world;
   if(w.loc==null || w.cam==null)return;
   if(zoomRoom===w.loc)return;
   zoomRoom=w.loc;
   // Use the original normal-size zoom and room binding; Camera.calc retains
   // full control over position. Map-fit zoom masks all camera movement.
   w.cam.setZoom(0);w.cam.setLoc(w.loc);
  }
  private function check(ok:Boolean,name:String,data:Object=null):void{api.check(ok,"text motion: "+name,data);}
  private function stageName():String{return ["stationary","walk-right","walk-left","walk-right-attack","walk-left-attack"][phase];}
  private function setStage():void {
   beginTick=mod.host.runtime.tick;lastSpawn=-1;at=getTimer();
   control={stage:stageName(),phase:phase,tick:beginTick,keys:kinds,floor:floorY};publish();
  }
  private function publish():void {api.write("text-motion-control.json",control);}
  public function input():void {
   if(finished)return;
   if(role=="join" && getTimer()-lastRead>100) {
    lastRead=getTimer();var next:Object=api.read("text-motion-control.json");if(next!=null)control=next;
   }
   var w:Object=mod.access.world;
   ensureCamera();
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
   if(role=="join") {
    if(mod.replica.frames!=observedFrames){observedFrames=mod.replica.frames;observedArrival=getTimer();}
    if(String(control.stage).indexOf("walk-right")==0)w.ctr.keyRight=true;
    if(String(control.stage).indexOf("walk-left")==0)w.ctr.keyLeft=true;
    if(String(control.stage).indexOf("-attack")>=0 && mod.replica.lastFrame!=null)
     w.ctr.keyAttack=Math.floor(Math.max(0,mod.replica.lastFrame.tick-int(control.tick))/6)%2==0;
   }
   injectedButtons={left:w.ctr.keyLeft,right:w.ctr.keyRight,attack:w.ctr.keyAttack,action:w.ctr.keyAction,tele:w.ctr.keyTele};
   w.celX=w.gg.X+180;w.celY=w.gg.Y-35;w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;
  }
  public function step():void {
   if(finished)return;
   if(!started) {
    started=true;
    if(role=="host") {
     if(room==null || room.limX<1600)throw new Error("Text motion requires an ordinary lane at least 1600 px wide");
     clearObjects();
     var center:Number=Math.floor((room.limX/2-160)/40)*40;
     for each(var a:Object in mod.host.actors)mod.access.scope.run(a.context,function():void {
      a.unit.setLocPos(center+(a.id==0?-200:0),floorY);a.unit.dx=a.unit.dy=0;a.unit.invulner=true;
      a.personal.follow=false;a.context.transitionCooldown=0;a.context.t_battle=0;
     });
     var shooter:Object=mod.host.actors[1];
     mod.access.scope.run(shooter.context,function():void {
      var g:Object=shooter.unit,Weapon:Object=mod.access.definition("fe.weapon.Weapon");
      g.pers.setForcLevel(30);g.pers.skills.smallguns=100;g.pers.setParameters();
      if(g.currentWeapon!=null)g.currentWeapon.remVisual();
      var gun:Object=Weapon["create"](g,"lmg",0);gun.setPers(g,g.pers);gun.hp=gun.maxhp;gun.precision=0;gun.hold=30;
      g.invent.weapons.lmg=gun;g.invent.cWeaponId="lmg";g.currentWeapon=gun;g.childObjs[0]=gun;gun.addVisual();
      g.invent.items[gun.ammo].kol=1000;g.pers.jammedMult=0;shooter.observeWeapon();
     });
     mod.access.world.cam.quakeX=mod.access.world.cam.quakeY=0;phase=0;setStage();
    }
   }
   if(role=="host") {
    if(control.stage=="end") {
     if(api.read("join-text-motion-end.json")!=null && mod.role==""){finish();}return;
    }
    var elapsed:int=mod.host.runtime.tick-beginTick;
    if(lastSpawn<0 || elapsed>=lastSpawn+30){emit();lastSpawn=elapsed;publish();}
    if(elapsed>=90 && api.read("join-text-motion-"+stageName()+".json")!=null) {
     if(++phase<5)setStage();else {control={stage:"end",keys:kinds};publish();api.write("host-text-motion-final.json",{phases:phaseMetrics,trace:traceRows,renderSampling:renderStats()});}
    }
    if(getTimer()-at>25000 && control.stage!="end") {check(false,"diagnostic phase completes",{stage:control.stage});control={stage:"end",keys:kinds};publish();}
   }else if(control.stage=="end") {
    if(!ended){ended=true;api.write("join-text-motion-final.json",{phases:phaseMetrics,trace:traceRows,renderSampling:renderStats()});api.write("join-text-motion-end.json",{done:true});mod.leaveSession();finish();}
   }
  }
  private function renderStats():Object{return {enterFrames:enterFrames,renderFrames:renderFrames,duplicateRenders:duplicateRenders};}
  private function finish():void {root.stage.removeEventListener(Event.ENTER_FRAME,requestRender);root.stage.removeEventListener(Event.RENDER,observe);finished=true;api.finish();}
  private function clearObjects():void {
   var o:Object=room.firstObj,next:Object;
   while(o!=null){next=o.nobj;o.remVisual();if(getQualifiedClassName(o)=="fe.graph::Part")o.setNull();else room.remObj(o);o=next;}
   var players:Array=[];for each(o in room.units)if(o!=null){if(o.player)players.push(o);else{o.disabled=true;o.remVisual();}}
   room.units=players;room.objs=[];room.acts=[];room.bonuses=[];
  }
  private function emit():void {
   var a:Object=mod.host.actors[1],Emitter:Object=mod.access.definition("fe.graph.Emitter");
   mod.access.scope.run(a.context,function():void {
    for each(var kind:String in ["numb","replic","replic2"]) {
     // Original Emitter definitions retain native motion, camera scaling,
     // life, opacity and text formatting. No direct sprite emulation.
     var part:Object=Emitter.arr[kind].cast(room,a.unit.X+120,floorY-(kind=="numb"?100:kind=="replic"?145:190),
      {txt:kind=="numb"?"78":kind=="replic"?"B native NPC speech":"B native dialogue"});
     if(part!=null){var id:uint=mod.host.sceneId(part);objects[id]=part;kinds[id]=kind;}
    }
   });
  }
  private function initMetrics():void {
   metrics={samples:0,parts:0,numb:0,replic:0,replic2:0,rootError:0,textError:0,missingText:0,missingRecipe:0,
    rootMax:0,textMax:0,screenReversals:0,worldReversals:0,cameraReversals:0,unshakenCameraReversals:0,
    maxScreenReverse:0,maxUnshakenCameraReverse:0,maxWorldXChange:0,
    interpolation:0,underflow:0,timelineGapMax:0,cameraTargetMismatch:0,firstError:null,firstReversal:null,
    startEnterFrame:enterFrames,startRenderFrame:renderFrames,lastEnterFrame:enterFrames,lastRenderFrame:renderFrames,cameraOffsetMin:Infinity,cameraOffsetMax:-Infinity};
   phaseMetrics[control.stage]=metrics;previous={};lastPresented=-1;
  }
  private function observe(event:Event):void {
   if(lastRenderFrame==enterFrames){++duplicateRenders;return;}
   lastRenderFrame=enterFrames;++renderFrames;
   if(finished || !started || control.stage==null || control.stage=="end" || mod.role=="")return;
   try {
    if(phaseReceived!=control.stage){phaseReceived=control.stage;initMetrics();}
    var w:Object=mod.access.world,r:Object=mod.replica,clock:Object=role=="join"?r.clock:null;
    var source:Object=role=="join"?clock.current:null,next:Object=role=="join"?clock.next:null;
    var elapsed:int=role=="join"?(source==null?0:source.tick-int(control.tick)):mod.host.runtime.tick-beginTick;
    if(role=="join" && (source==null || source.tick<int(control.tick)))return;
    var fraction:Number=role=="join"?clock.fraction:0;
    ++metrics.samples;if(fraction>0 && fraction<1)++metrics.interpolation;if(role=="join" && next==null)++metrics.underflow;
    metrics.lastEnterFrame=enterFrames;metrics.lastRenderFrame=renderFrames;
    metrics.cameraOffsetMin=Math.min(metrics.cameraOffsetMin,w.cam.vx);metrics.cameraOffsetMax=Math.max(metrics.cameraOffsetMax,w.cam.vx);
    if(role=="join" && r.lastFrame!=null && r.displayFrame!=null)metrics.timelineGapMax=Math.max(metrics.timelineGapMax,Math.abs(r.lastFrame.players[1].x-r.displayFrame.players[1].x));
    if(w.cam.moved && !w.cam.showOn && !w.ctr.keyLook && Math.abs(w.cam.X-w.gg.X*w.cam.scaleV)>1.1)++metrics.cameraTargetMismatch;
    var sources:Object=role=="join"?keyed(source.scene.effects):null,futures:Object=role=="join" && next!=null?keyed(next.scene.effects):null;
    var displayed:Object=role=="join" && r.displayFrame!=null?keyed(r.displayFrame.scene.effects):null;
    var first:Object=null,all:Object=role=="join"?control.keys:kinds;
    for(var key:String in all) {
     var clip:DisplayObject,kind:String=String(all[key]),s:Object=role=="join"?sources[key]:null;
     if(role=="join") {
      var rec:Object=r.scene.effects.records[key];if(s==null || rec==null || !s.pose.v || s.pose.a<=0)continue;clip=rec.clip;
     }else {var part:Object=objects[key];if(part==null || part.vis==null || !part.in_chain)continue;clip=part.vis;}
     if(clip==null || clip.parent==null || !clip.visible || clip.alpha<=0)continue;
     var leaf:TextField=findText(clip);if(leaf==null){++metrics.missingText;continue;}
     ++metrics.parts;metrics[kind]=Number(metrics[kind])+1;
     var rootWorld:Point=clip.parent.globalToLocal(clip.localToGlobal(new Point()));
     var textWorld:Point=clip.parent.globalToLocal(leaf.localToGlobal(new Point()));
     var screen:Point=leaf.localToGlobal(new Point()),camera:Point=w.visual.localToGlobal(new Point());
     var rootErr:Number=0,textErr:Number=0;
     if(role=="join") {
      // Test whether native timeline/layout/camera changed the recipe already
      // submitted for this display. Do not interpolate flattened A/B matrices:
      // interpolating each parent and child then composing is not equivalent.
      // This intentionally does not claim to validate PoseTween's algorithm.
      var future:Object=futures==null?null:futures[key],recipe:Object=displayed==null?null:displayed[key];
      if(recipe==null || recipe.pose==null){++metrics.missingRecipe;continue;}
      var a:Object=flatten(recipe.pose),m:Array=recipe.pose.m;
      var ex:Number=m==null?recipe.pose.x:m[4],ey:Number=m==null?recipe.pose.y:m[5];
      rootErr=Math.max(Math.abs(rootWorld.x-ex),Math.abs(rootWorld.y-ey));
      if(a!=null) {
       ex=a.x;ey=a.y;
       textErr=Math.max(Math.abs(textWorld.x-ex),Math.abs(textWorld.y-ey));
      }else ++metrics.missingRecipe;
      metrics.rootMax=Math.max(metrics.rootMax,rootErr);metrics.textMax=Math.max(metrics.textMax,textErr);
      if(rootErr>0.11)++metrics.rootError;if(textErr>0.16)++metrics.textError;
      if((rootErr>0.11 || textErr>0.16) && metrics.firstError==null)
       metrics.firstError={key:key,kind:kind,rootError:rootErr,textError:textErr,tick:source.tick,next:next==null?null:next.tick,fraction:fraction,
        source:{presentation:source.presentation,time:source.time,pose:clone(s.pose)},
        future:future==null?null:{presentation:next.presentation,time:next.time,pose:clone(future.pose)},
        display:{presentation:r.displayFrame.presentation,tick:r.displayFrame.tick,time:r.displayFrame.time,pose:clone(recipe.pose)},
        actual:{root:[rootWorld.x,rootWorld.y],text:[textWorld.x,textWorld.y],screen:[screen.x,screen.y],chain:matrixChain(clip,leaf)}};
     }
     var prior:Object=previous[key],point:Object={screenX:screen.x,worldX:rootWorld.x,cameraX:camera.x,unshakenCameraX:w.cam.vx,quakeX:w.cam.quakeX};
     previous[key]=point;
     var direction:int=String(control.stage).indexOf("walk-right")==0?-1:String(control.stage).indexOf("walk-left")==0?1:0;
     if(prior!=null && direction!=0 && elapsed>18) {
      var screenReverse:Boolean=(screen.x-prior.screenX)*direction<-.25;
      if(screenReverse){++metrics.screenReversals;metrics.maxScreenReverse=Math.max(metrics.maxScreenReverse,-(screen.x-prior.screenX)*direction);if(metrics.firstReversal==null)metrics.firstReversal={key:key,kind:kind,delta:screen.x-prior.screenX,cameraDelta:camera.x-prior.cameraX,unshakenCameraDelta:w.cam.vx-prior.unshakenCameraX,quake:[prior.quakeX,w.cam.quakeX],worldDelta:rootWorld.x-prior.worldX,lead:role=="join"?r.prediction.lead:0,tick:role=="join"?source.tick:mod.host.runtime.tick};}
      if((camera.x-prior.cameraX)*direction<-.25)++metrics.cameraReversals;
      if((w.cam.vx-prior.unshakenCameraX)*direction<-.25){++metrics.unshakenCameraReversals;metrics.maxUnshakenCameraReverse=Math.max(metrics.maxUnshakenCameraReverse,-(w.cam.vx-prior.unshakenCameraX)*direction);}
      if(Math.abs(rootWorld.x-prior.worldX)>.11)++metrics.worldReversals;
      metrics.maxWorldXChange=Math.max(metrics.maxWorldXChange,Math.abs(rootWorld.x-prior.worldX));
     }
     if(first==null)first={key:key,kind:kind,root:[rootWorld.x,rootWorld.y],text:[textWorld.x,textWorld.y],screen:[screen.x,screen.y],camera:[camera.x,camera.y],rootError:rootErr,textError:textErr};
    }
    if(first!=null && traceRows.length<1200 && getTimer()-lastTrace>=35) {
     lastTrace=getTimer();first.stage=control.stage;first.localAt=getTimer();first.enterFrame=enterFrames;first.renderFrame=renderFrames;first.tick=role=="join"?source.tick:mod.host.runtime.tick;
     first.nextTick=role=="join" && next!=null?next.tick:null;first.fraction=fraction;first.playerX=w.gg.X;first.visualX=w.visual.x;
     first.predictionLead=role=="join"?r.prediction.lead:0;first.delay=role=="join"?clock.delay:0;traceRows.push(first);
     first.cameraTargetX=w.cam.X;first.cameraOffsetX=w.cam.vx;first.scale=w.cam.scaleV;
     first.quake=[w.cam.quakeX,w.cam.quakeY];
     first.injectedButtons=injectedButtons;first.finalButtons={left:w.ctr.keyLeft,right:w.ctr.keyRight,attack:w.ctr.keyAttack,action:w.ctr.keyAction,tele:w.ctr.keyTele};
     first.nativeWork=w.gg.work;
     if(role=="join") {
      first.latestTick=r.lastFrame.tick;first.latestX=r.lastFrame.players[1].x;
      first.displayX=r.displayFrame.players[1].x;first.clockPosition=clock.position;
      first.currentTime=source.time;first.nextTime=next==null?null:next.time;
      first.latestTime=r.lastFrame.time;
      first.observedFrameAgeMS=getTimer()-observedArrival;
      first.terrainRevision=r.scene.terrainRevision;first.latestTerrainRevision=r.lastFrame.scene.terrainRevision;
     }
    }
    if(role=="join" && elapsed>=75 && joinAck!=control.stage) {
     joinAck=control.stage;
     check(metrics.numb>10 && metrics.replic>10 && metrics.replic2>10,"native moving number and both speech particles observed: "+control.stage,metrics);
     check(metrics.rootError==0,"final native camera/GUI do not rewrite particle world position: "+control.stage,metrics);
     check(metrics.textError==0 && metrics.missingText==0 && metrics.missingRecipe==0,"final text layout preserves the submitted display recipe: "+control.stage,metrics);
     // Reversal is diagnostic, separately attributed to the shared camera.
     // Root decides whether the observed magnitude explains the user report.
     api.log("text-motion-diagnostic",{stage:control.stage,metrics:metrics});api.write("join-text-motion-"+control.stage+".json",metrics);
    }
   }catch(error:*) {check(false,"render-phase observer runs",{message:String(error),stack:error.getStackTrace()});finish();}
  }
  private function keyed(values:Array):Object {var result:Object={};for each(var o:Object in values)result[o.key]=o;return result;}
  private function findText(d:DisplayObject):TextField {
   if(d is TextField)return d as TextField;var c:DisplayObjectContainer=d as DisplayObjectContainer;
   if(c!=null)for(var i:int=0;i<c.numChildren;i++){var t:TextField=findText(c.getChildAt(i));if(t!=null)return t;}return null;
  }
  private function multiply(p:Array,m:Array):Array {
   return [p[0]*m[0]+p[2]*m[1],p[1]*m[0]+p[3]*m[1],p[0]*m[2]+p[2]*m[3],p[1]*m[2]+p[3]*m[3],p[0]*m[4]+p[2]*m[5]+p[4],p[1]*m[4]+p[3]*m[5]+p[5]];
  }
  private function clone(value:Object):Object{return value==null?null:JSON.parse(JSON.stringify(value));}
  private function matrixChain(clip:DisplayObject,leaf:DisplayObject):Array {
   var result:Array=[],d:DisplayObject=leaf;
   while(d!=null) {
    var m:Matrix=d.transform.matrix;
    result.unshift({name:d.name,cls:getQualifiedClassName(d),matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],
     frame:d is MovieClip?MovieClip(d).currentFrame:null});
    if(d===clip)break;d=d.parent;
   }
   return result;
  }
  /** Compose the final submitted recipe, independent of display tree state. */
  private function flatten(pose:Object,parent:Array=null):Object {
   var m:Array=pose.m;if(m==null)return null;if(parent!=null)m=multiply(parent,m);
   if(pose.plainText!=null)return {x:m[4],y:m[5],text:pose.plainText};
   if(pose.children!=null)for each(var child:Object in pose.children){var found:Object=flatten(child.s,m);if(found!=null)return found;}return null;
  }
 }
}
