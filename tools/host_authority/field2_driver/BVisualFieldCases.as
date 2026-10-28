package {
 import flash.display.Bitmap;
 import flash.display.BitmapData;
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.display.MovieClip;
 import flash.display.Shape;
 import flash.events.Event;
 import flash.geom.ColorTransform;
 import flash.geom.Matrix;
 import flash.geom.Point;
 import flash.geom.Rectangle;
 import flash.system.ApplicationDomain;
 import flash.text.TextField;
 import flash.utils.ByteArray;
 import flash.utils.getQualifiedClassName;
 import flash.utils.getTimer;

 /** Bounded diagnostic in the original base. No room/terrain replacement,
  * no combat simulation, and no visual-equivalence pass inferred from a hash.
  * Host/client native trees are paired by the actual presentation number. */
 public final class BVisualFieldCases {
  private var mod:Object,root:Object,api:Object,side:String,room:Object;
  private var phase:int=-1,at:int=0,lastRead:int=0,lastSample:int=0;
  private var control:Object={},tracked:Object={},hostRows:Object={},clientRows:Object={},paired:Object={};
  private var rowOrder:Array=[],clientOrder:Array=[],pairs:Array=[],created:Array=[];
  private var finished:Boolean=false,started:Boolean=false,phaseSeen:int=-2,phaseRows:int=0;
  private var originalZoom:int=0,treeBudget:int=0;
  private var hostZoomChanged:Boolean=false,scaleChecks:Object={};
  private var readySent:Object={},scaleAckSent:Object={};
  public function BVisualFieldCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   mod=m;root=r;api=a;side=role;room=a.home;at=getTimer();
   originalZoom=int(mod.access.world.cam.isZoom);
   root.stage.addEventListener(Event.EXIT_FRAME,observe,false,-200000);
  }
  private function check(ok:Boolean,name:String,data:Object=null):void {api.check(ok,"visualfield: "+name,data);}
  public function input():void {
   if(finished)return;
   var w:Object=mod.access.world;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
   if(side=="join" && getTimer()-lastRead>150) {
    lastRead=getTimer();var incoming:Object=api.read("visualfield-control.json");
    if(incoming!=null)control=incoming;
    var refs:Object=api.read("visualfield-host-rows.json");if(refs!=null)hostRows=refs.rows;
   }
   if(control.phase!=null && int(control.phase)!=phaseSeen && !control.end) {
    phaseSeen=int(control.phase);
    var zoom:int=side=="join" && phaseSeen>0?1-int(control.zoom):int(control.zoom);
    w.cam.setZoom(zoom);w.cam.setLoc(w.loc);
   }
  }
  public function step():void {
   if(finished)return;
   if(side=="host") {
    if(!started) {
     if(mod.host==null || mod.host.lastFrame==null || mod.host.runtime.awaitingFirstView)return;
     started=true;room=mod.host.actors[0].unit.loc;
     check(room.base && mod.host.actors[1].unit.loc===room,"original base and both players retained",{base:room.base,room:mod.access.keyFor(room)});
     for each(var actor:Object in mod.host.actors){actor.personal.follow=false;actor.unit.invulner=true;}
     chooseObjects();beginPhase();return;
    }
    if(phase>0 && phase<5 && !control.spawned) {
     var ready:Object=api.read("visualfield-ready-"+phase+".json");
     if(ready!=null && ready.phase==phase && ready.zoom==1-int(control.zoom))spawnBubbles();
    }
    if(phase>0 && phase<5 && control.spawned && !hostZoomChanged) {
     var birth:Object=api.read("visualfield-birth-ack-"+phase+".json");
     if(birth!=null && birth.phase==phase && birth.observed==2) {
      check(birth.passed,"both native bubbles were checked at birth: "+phase,birth);
      hostZoomChanged=true;mod.access.world.cam.setZoom(1-int(control.zoom));mod.access.world.cam.setLoc(room);
      control.hostZoomAfterBirth=1-int(control.zoom);
      control.hostZoomAfterBirthPresentation=mod.host.lastFrame.presentation;
      api.write("visualfield-control.json",control);
     }
    }
    var ack:Object=api.read("visualfield-phase-"+phase+".json");
    var after:Object=phase>0?api.read("visualfield-after-ack-"+phase+".json"):null;
    if(ack!=null && getTimer()-at>1600 && (phase==0 || after!=null && after.phase==phase && after.observed==2)) {
     if(phase>0)check(after.passed,"both native bubbles were checked after host zoom: "+phase,after);
     check(ack.pairs>0,"both sides observed the same confirmation: phase "+phase,ack);
     if(phase>=4){control.end=true;api.write("visualfield-control.json",control);phase=5;at=getTimer();}
     else beginPhase();
    }
    if(phase==5 && api.read("visualfield-join-done.json")!=null){finish();return;}
    if(getTimer()-at>18000){check(false,"bounded diagnostic phase completes",{phase:phase,spawned:control.spawned,hostZoomChanged:hostZoomChanged,birth:birth,after:after});finish();}
   }else if(control.end) {
    matchRows();api.write("visualfield-join-final.json",{pairs:pairs,unmatched:clientOrder,diagnosticOnly:true});
    api.write("visualfield-join-done.json",{done:true,pairs:pairs.length});
    check(pairs.length>0,"native visual evidence has actual matching presentations",{pairs:pairs.length});finish();
   }else if(getTimer()-at>180000){check(false,"base visual scenario receives host phases");finish();}
  }
  private function chooseObjects():void {
   var seen:Object={},o:Object,kind:String;
   for each(var list:Array in [room.objs,room.acts,room.bonuses])for each(o in list)if(o!=null && o.vis!=null) {
    kind=getQualifiedClassName(o.vis);
    if(kind.indexOf("vismedbox")>=0 && seen.medbox==null)seen.medbox=o;
    if(kind.indexOf("visterm")>=0 && seen.term==null)seen.term=o;
   }
   for each(kind in ["medbox","term"]) {
    o=seen[kind];
    if(o==null) {
     var Box:Class=mod.access.definition("fe.loc.Box") as Class;
     o=new Box(room,kind,int(mod.host.actors[0].unit.X)+(kind=="medbox"?100:170),int(mod.host.actors[0].unit.Y),null,null);
     room.addObj(o);room.objs.push(o);o.addVisual();created.push(o);
    }
    tracked[String(mod.host.sceneId(o))]={object:o,kind:kind,created:created.indexOf(o)>=0};
    check(getQualifiedClassName(o.vis).indexOf("vis"+kind)>=0,"original native symbol participates: "+kind,{cls:getQualifiedClassName(o.vis),created:created.indexOf(o)>=0});
   }
  }
  private function beginPhase():void {
   ++phase;phaseRows=0;at=getTimer();hostZoomChanged=false;
   // Baseline first; then two native zoom modes x two explicit emitter scales.
   var zoom:int=phase==0?originalZoom:(phase-1)%2;
   var scale:Number=phase<3?.5:1.5;
   control={phase:phase,zoom:zoom,scale:scale,room:mod.access.keyFor(room),keys:{},spawned:phase==0,end:false};
   mod.access.world.cam.setZoom(zoom);mod.access.world.cam.setLoc(room);phaseSeen=phase;
   for(var key:String in tracked)if(tracked[key].kind=="replic" || tracked[key].kind=="replic2")delete tracked[key];
   publishKeys();
  }
  private function spawnBubbles():void {
    var scale:Number=Number(control.scale),zoom:int=int(control.zoom);
    var Emitter:Object=mod.access.definition("fe.graph.Emitter"),g:Object=mod.host.actors[0].unit;
    for each(var kind:String in ["replic","replic2"]) {
     var emitter:Object=Emitter.arr[kind];
     var part:Object=emitter.cast(room,g.X+100,g.Y-(kind=="replic"?100:155),{txt:"B native NPC scale "+scale,scale:scale});
     check(part!=null && part.vis!=null,"native Emitter creates "+kind,{phase:phase,camscale:emitter.camscale,paramScale:scale,zoom:zoom});
     if(part!=null)tracked[String(mod.host.sceneId(part))]={object:part,kind:kind,camscale:emitter.camscale,paramScale:scale};
    }
   control.spawned=true;publishKeys();
  }
  private function publishKeys():void {
   for(var key:String in tracked){var info:Object=tracked[key];control.keys[key]={kind:info.kind,camscale:info.camscale,paramScale:info.paramScale,created:info.created};}
   api.write("visualfield-control.json",control);
  }
  private function observe(event:Event):void {
   if(finished || control.end || control.phase==null)return;
   try {
    var frame:Object=side=="host"?mod.host.lastFrame:mod.replica.displayFrame;
    var source:Object=side=="host"?frame:mod.replica.clock.current;
    if(frame==null || source==null || frame.room!=control.room)return;
    if(side=="join" && int(control.phase)>0 && !control.spawned && !readySent[control.phase] &&
       mod.access.world.cam.isZoom==1-int(control.zoom)) {
     readySent[control.phase]=true;
     api.write("visualfield-ready-"+control.phase+".json",{phase:control.phase,zoom:mod.access.world.cam.isZoom,cameraScale:mod.access.world.cam.scaleV,presentation:source.presentation});
    }
    var id:String=String(source.presentation);
    if(side=="host") {
     if(getTimer()-lastSample<140 || hostRows[id]!=null)return;lastSample=getTimer();
     hostRows[id]=sample(frame,source);rowOrder.push(id);
     while(rowOrder.length>48)delete hostRows[rowOrder.shift()];
     api.write("visualfield-host-rows.json",{rows:hostRows,order:rowOrder});
     if(++phaseRows==1 && api.picture!=null)api.picture("host-visualfield-"+phase);
    }else {
     if(getTimer()-lastSample<100 || clientRows[id]!=null)return;lastSample=getTimer();
     clientRows[id]=sample(frame,source);clientOrder.push(id);
     while(clientOrder.length>64)delete clientRows[clientOrder.shift()];
     matchRows();
    }
   }catch(error:*){check(false,"visual observer accesses public native fields",{message:String(error),stack:error.getStackTrace()});finish();}
  }
  private function sample(frame:Object,source:Object):Object {
   var w:Object=mod.access.world,localRoom:Object=w.loc,objects:Object={};
   for(var key:String in control.keys) {
    var display:DisplayObject=null;
    if(side=="host"){var t:Object=tracked[key];if(t!=null && t.object!=null)display=t.object.vis as DisplayObject;}
    else {
     var rec:Object=mod.replica.scene.objects[key];
     if(rec!=null)display=rec.object.vis as DisplayObject;
     else {rec=mod.replica.scene.effects.records[key];if(rec!=null)display=rec.clip as DisplayObject;}
    }
    if(display!=null){
     treeBudget=180;var actualScale:Array=[display.scaleX*w.cam.scaleV,display.scaleY*w.cam.scaleV];
     var scaleContract:Number=0;
     if(source.scene!=null && source.scene.effects!=null)for each(var effect:Object in source.scene.effects)
      if(String(effect.key)==key && Number(effect.screenScale)>0){scaleContract=Number(effect.screenScale);break;}
     var localBounds:Rectangle=display.getBounds(display);
     var center:Point=display.localToGlobal(new Point(localBounds.x+localBounds.width/2,localBounds.y+localBounds.height/2));
     objects[key]={kind:control.keys[key].kind,tree:tree(display,0),pixels:art(display),screenScale:actualScale,screenScaleContract:scaleContract,
      parents:parents(display),grafonLayer:layer(display,w.grafon),lighting:lightAt(center,w),screen:screenPixels(center),
      siblings:siblings(display),hostShadow:side=="host" && t!=null && t.object!=null && "shad" in t.object?renderNode(t.object.shad as DisplayObject):null};
     if(side=="join" && control.keys[key].camscale===true && scaleContract>0) {
      var scaleStage:String=control.hostZoomAfterBirth==null?"birth":"after-host-zoom";
      // The after check must use a confirmation published after the real
      // host-only zoom change, not the older frame still on the playback clock.
      if(scaleStage=="after-host-zoom" && Number(source.presentation)<=Number(control.hostZoomAfterBirthPresentation))continue;
      var scaleKey:String=String(control.phase)+":"+key+":"+scaleStage;
      if(!scaleChecks[scaleKey]) {
       var expected:Number=Number(control.keys[key].paramScale);
       var ok:Boolean=Math.abs(actualScale[0]-expected)<.02 && Math.abs(actualScale[1]-expected)<.02;
       scaleChecks[scaleKey]={passed:ok,kind:control.keys[key].kind,presentation:source.presentation,actual:actualScale,expected:expected};
       check(ok,
        "native camscale text keeps its requested on-screen scale: "+scaleKey,
        {actual:actualScale,expected:expected,contract:scaleContract,localCamera:w.cam.scaleV,zoom:w.cam.isZoom,presentation:source.presentation});
       publishScaleAck(scaleStage);
      }
     }
    }
   }
   var back:Array=[];
   if(localRoom.backobjs!=null)for each(var bo:Object in localRoom.backobjs) {
    if(back.length>=100)break;
    var bv:DisplayObject=bo.vis as DisplayObject;treeBudget=80;
    back.push({id:String(bo.id),x:bo.X,y:bo.Y,tree:bv==null?null:tree(bv,0),parents:bv==null?null:parents(bv),grafonLayer:bv==null?null:layer(bv,w.grafon)});
   }
   var playerScreen:Point=w.visual.localToGlobal(new Point(w.gg.X,w.gg.Y-25));treeBudget=80;
   var lightTree:Object=tree(w.grafon.visLight,0);
   return {phase:int(control.phase),presentation:source.presentation,displayPresentation:frame.presentation,tick:source.tick,
    fraction:side=="join"?mod.replica.clock.fraction:0,room:mod.access.keyFor(localRoom),base:localRoom.base,
    roomBlack:localRoom.black,worldBlack:w.black,player:{x:w.gg.X,y:w.gg.Y,screen:[playerScreen.x,playerScreen.y],light:lightAt(playerScreen,w),pixels:screenPixels(playerScreen)},
    visLight:{tree:lightTree,parents:parents(w.grafon.visLight),bitmap:bitmapInfo(w.grafon.lightBmp as BitmapData)},
    zoom:w.cam.isZoom,cameraScale:w.cam.scaleV,backCount:localRoom.backobjs==null?0:localRoom.backobjs.length,backobjs:back,
    front:bitmapInfo(w.grafon.frontBmp as BitmapData),back:surface(w.grafon.visBack),back2:surface(w.grafon.visBack2),objects:objects};
  }
  private function publishScaleAck(stage:String):void {
   var name:String=String(control.phase)+":"+stage;if(scaleAckSent[name])return;
   var rows:Array=[],kinds:Object={},passed:Boolean=true;
   for(var key:String in control.keys) {
    var kind:String=String(control.keys[key].kind);
    if(kind!="replic" && kind!="replic2")continue;
    var observation:Object=scaleChecks[String(control.phase)+":"+key+":"+stage];
    if(observation==null)return;
    rows.push(observation);kinds[kind]=true;passed=passed && observation.passed;
   }
   if(rows.length!=2 || !kinds.replic || !kinds.replic2)return;
   scaleAckSent[name]=true;
   api.write("visualfield-"+(stage=="birth"?"birth":"after")+"-ack-"+control.phase+".json",
    {phase:control.phase,stage:stage,observed:2,passed:passed,observations:rows});
  }
  private function matchRows():void {
   var matched:int=0;
   for each(var key:String in clientOrder) {
    var h:Object=hostRows[key],j:Object=clientRows[key];
    if(h==null || j==null || paired[key] || h.phase!=j.phase)continue;
    paired[key]=true;++matched;
    var differences:Array=[];
    if(h.backCount!=j.backCount)differences.push("backobjs count");
    if(JSON.stringify(h.front)!=JSON.stringify(j.front))differences.push("front bitmap sample");
    if(JSON.stringify(h.back)!=JSON.stringify(j.back))differences.push("back bitmap sample");
    for(var objectKey:String in h.objects) {
     if(j.objects[objectKey]==null)differences.push("missing native "+objectKey);
     else {
      if(JSON.stringify(withoutNames(h.objects[objectKey].tree))!=JSON.stringify(withoutNames(j.objects[objectKey].tree)))differences.push("native tree excluding instance names (including interpolation) "+objectKey);
      if(JSON.stringify(h.objects[objectKey].pixels)!=JSON.stringify(j.objects[objectKey].pixels))differences.push("artwork sample "+objectKey);
     }
    }
    pairs.push({presentation:key,phase:h.phase,differences:differences,host:h,join:j});
    if(pairs.length>32)pairs.shift();
    api.log("visualfield-pair",{presentation:key,phase:h.phase,differences:differences,diagnosticOnly:true});
   }
   if(matched>0) {
    api.write("visualfield-join-pairs.json",{pairs:pairs,diagnosticOnly:true});
    var count:int=0;for each(var pair:Object in pairs)if(pair.phase==int(control.phase))++count;
    if(count>0) {
     api.write("visualfield-phase-"+control.phase+".json",{pairs:count,phase:control.phase,diagnosticOnly:true});
     if(api.picture!=null)api.picture("join-visualfield-"+control.phase);
    }
   }
  }
  private function tree(display:DisplayObject,depth:int):Object {
   if(display==null || --treeBudget<0 || depth>8)return {truncated:true};
   var m:Matrix=display.transform.matrix,c:ColorTransform=display.transform.colorTransform;
   var out:Object={cls:getQualifiedClassName(display),name:display.name,m:[m.a,m.b,m.c,m.d,m.tx,m.ty],
    color:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset],
    alpha:display.alpha,visible:display.visible,width:display.width,height:display.height,filters:display.filters.length};
   if(display is MovieClip){out.frame=MovieClip(display).currentFrame;out.totalFrames=MovieClip(display).totalFrames;}
   if(display is TextField){out.text=TextField(display).text;out.textColor=TextField(display).textColor;out.autoSize=TextField(display).autoSize;}
   if(display is Bitmap)out.bitmap=bitmapInfo(Bitmap(display).bitmapData);
   var parent:DisplayObjectContainer=display as DisplayObjectContainer;
   if(parent!=null){out.children=[];for(var i:int=0;i<parent.numChildren && i<40;i++)out.children.push(tree(parent.getChildAt(i),depth+1));}
   return out;
  }
  private function withoutNames(value:*):* {
   if(value==null || typeof value!="object")return value;
   if(value is Array){var list:Array=[];for each(var item:* in value)list.push(withoutNames(item));return list;}
   var out:Object={};for(var key:String in value)if(key!="name")out[key]=withoutNames(value[key]);return out;
  }
  private function matrixValues(m:Matrix):Array {return m==null?null:[m.a,m.b,m.c,m.d,m.tx,m.ty];}
  private function colorValues(c:ColorTransform):Array {return c==null?null:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];}
  private function rectValues(r:Rectangle):Array{return r==null?null:[r.x,r.y,r.width,r.height];}
  /** The source pixels may be correct while an ancestor's mask, light layer or
   * colour transform darkens the final screen. Keep those causes independent. */
  private function parents(display:DisplayObject):Array {
   var out:Array=[],node:DisplayObject=display;
   while(node!=null && out.length<16) {
    // Stage deliberately rejects some inherited DisplayObject properties.
    // Record the endpoint without probing its transform/filter accessors.
    if(node===root.stage){out.push({cls:getQualifiedClassName(node),stage:true,childIndex:-1,width:root.stage.stageWidth,height:root.stage.stageHeight});break;}
    var mask:DisplayObject=node.mask,filters:Array=[];
    for each(var f:Object in node.filters) {
     var fs:Object={kind:getQualifiedClassName(f)};
     for each(var field:String in ["matrix","color","alpha","blurX","blurY","strength","quality","inner","knockout","distance","angle","hideObject"])
      if(field in f)fs[field]=f[field];
     filters.push(fs);
    }
    out.push({cls:getQualifiedClassName(node),name:node.name,childIndex:node.parent==null?-1:node.parent.getChildIndex(node),visible:node.visible,alpha:node.alpha,blend:node.blendMode,
     m:matrixValues(node.transform.matrix),color:colorValues(node.transform.colorTransform),
     concatenatedMatrix:matrixValues(node.transform.concatenatedMatrix),concatenatedColor:colorValues(node.transform.concatenatedColorTransform),
     scrollRect:rectValues(node.scrollRect),filters:filters,
     mask:mask==null?null:{cls:getQualifiedClassName(mask),name:mask.name,visible:mask.visible,alpha:mask.alpha,
      m:matrixValues(mask.transform.matrix),screenBounds:rectValues(mask.getBounds(root.stage))}});
    node=node.parent;
   }
   return out;
  }
  private function renderNode(node:DisplayObject):Object {
   if(node==null)return null;
   var filters:Array=[];
   for each(var f:Object in node.filters) {
    var item:Object={kind:getQualifiedClassName(f)};
    for each(var key:String in ["color","alpha","blurX","blurY","strength","quality","inner","knockout","distance","angle","hideObject"])
     if(key in f)item[key]=f[key];
    filters.push(item);
   }
   return {cls:getQualifiedClassName(node),index:node.parent==null?-1:node.parent.getChildIndex(node),
    m:matrixValues(node.transform.matrix),color:colorValues(node.transform.colorTransform),
    filters:filters,alpha:node.alpha,visible:node.visible,attached:node.parent!=null};
  }
  /** Keep the actual common-layer draw order. A Box's authored shadow uses
   * the same symbol plus DropShadowFilter.hideObject; listing nearby siblings
   * avoids guessing which effect is its shadow on the read-only receiver. */
  private function siblings(display:DisplayObject):Object {
   var parent:DisplayObjectContainer=display.parent,items:Array=[];
   if(parent==null)return {detached:true,items:items};
   var at:int=parent.getChildIndex(display),start:int=Math.max(0,Math.min(at-64,parent.numChildren-128));
   var end:int=Math.min(parent.numChildren,start+128);
   for(var i:int=start;i<end;i++)items.push(renderNode(parent.getChildAt(i)));
   return {parentClass:getQualifiedClassName(parent),targetIndex:at,count:parent.numChildren,start:start,end:end,items:items};
  }
  private function layer(display:DisplayObject,grafon:Object):Object {
   var node:DisplayObject=display;
   while(node!=null) {
    if(grafon.visObjs!=null)for(var i:int=0;i<grafon.visObjs.length;i++)if(node===grafon.visObjs[i])return {kind:"visObjs",index:i};
    for each(var name:String in ["visFront","visBack","visBack2","visLight","visSats","visVoda"])if(node===grafon[name])return {kind:name,index:-1};
    if(node===root.stage)break;node=node.parent;
   }
   return {kind:"detached-or-other",index:-1};
  }
  private function lightAt(screen:Point,w:Object):Object {
   var light:DisplayObject=w.grafon.visLight as DisplayObject,bitmap:BitmapData=w.grafon.lightBmp as BitmapData;
   var world:Point=w.visual.globalToLocal(screen),at:Point=light==null?null:light.globalToLocal(screen);
   var x:int=at==null?-1:int(Math.floor(at.x)),y:int=at==null?-1:int(Math.floor(at.y));
   var inside:Boolean=bitmap!=null && x>=0 && y>=0 && x<bitmap.width && y<bitmap.height;
   return {screen:[screen.x,screen.y],world:[world.x,world.y],lightLocal:at==null?null:[at.x,at.y],pixel:[x,y],
    inside:inside,argb:inside?bitmap.getPixel32(x,y).toString(16):null,visible:light==null?false:light.visible};
  }
  private function screenPixels(center:Point):Object {
   var x:int=int(Math.floor(center.x)),y:int=int(Math.floor(center.y));
   if(!isFinite(center.x) || !isFinite(center.y) || x<0 || y<0 || x>=root.stage.stageWidth || y>=root.stage.stageHeight)
    return {screen:[center.x,center.y],offscreen:true};
   var bitmap:BitmapData=new BitmapData(7,7,true,0),pixels:Array=[];
   try {
    bitmap.draw(root.stage,new Matrix(1,0,0,1,3-x,3-y),null,null,null,false);
    for(var py:int=0;py<7;py++)for(var px:int=0;px<7;px++)pixels.push(bitmap.getPixel32(px,py).toString(16));
   }finally {bitmap.dispose();}
   return {screen:[x,y],width:7,height:7,pixels:pixels,offscreen:false};
  }
  private function art(display:DisplayObject):Object {
   var bounds:Rectangle=display.getBounds(display);
   if(!isFinite(bounds.width) || !isFinite(bounds.height) || bounds.width<=0 || bounds.height<=0)return {empty:true};
   var width:int=Math.min(256,Math.max(1,Math.ceil(bounds.width))),height:int=Math.min(256,Math.max(1,Math.ceil(bounds.height)));
   var bitmap:BitmapData=new BitmapData(width,height,true,0),result:Object;
   try {bitmap.draw(display,new Matrix(1,0,0,1,-bounds.x,-bounds.y),null,null,null,false);result=bitmapInfo(bitmap);}
   finally {bitmap.dispose();}
   result.bounds=[bounds.x,bounds.y,bounds.width,bounds.height];result.clipped=bounds.width>256 || bounds.height>256;return result;
  }
  private function surface(parent:DisplayObjectContainer):Array {
   var out:Array=[];if(parent==null)return out;
   for(var i:int=0;i<parent.numChildren;i++)if(parent.getChildAt(i) is Bitmap)out.push(bitmapInfo(Bitmap(parent.getChildAt(i)).bitmapData));
   return out;
  }
  private function bitmapInfo(bitmap:BitmapData):Object {
   if(bitmap==null)return null;
   var hash:uint=2166136261,nonzero:int=0,total:int=bitmap.width*bitmap.height,stride:int=Math.max(1,int(total/4096));
   for(var n:int=0;n<total;n+=stride){var pixel:uint=bitmap.getPixel32(n%bitmap.width,int(n/bitmap.width));hash=(hash^pixel)*16777619;if(pixel>>>24)++nonzero;}
   return {width:bitmap.width,height:bitmap.height,sampleHash:hash.toString(16),sampleNonzero:nonzero,stride:stride,sampled:true};
  }
  private function finish():void {
   if(finished)return;finished=true;root.stage.removeEventListener(Event.EXIT_FRAME,observe);
   mod.access.world.cam.setZoom(originalZoom);mod.access.world.cam.setLoc(mod.access.world.loc);
   api.finish();
  }
 }
}
