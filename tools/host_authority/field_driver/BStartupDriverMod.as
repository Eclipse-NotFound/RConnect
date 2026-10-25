package {
 import flash.display.Sprite;
 import flash.display.Loader;
 import flash.display.DisplayObject;
 import flash.display.BitmapData;
 import flash.display.PNGEncoderOptions;
 import flash.display.DisplayObjectContainer;
 import flash.display.MovieClip;
 import flash.display.Bitmap;
 import flash.display.Shape;
 import flash.geom.Matrix;
 import flash.geom.ColorTransform;
 import flash.text.TextField;
 import flash.filters.GlowFilter;
 import flash.filters.BlurFilter;
 import flash.filters.DropShadowFilter;
 import flash.filters.ColorMatrixFilter;
 import flash.utils.ByteArray;
 import flash.utils.getQualifiedClassName;
 import flash.utils.describeType;
 import flash.desktop.NativeApplication;
 import flash.events.Event;
 import flash.events.MouseEvent;
 import flash.events.IOErrorEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.net.URLRequest;
 import flash.system.ApplicationDomain;
 import flash.system.LoaderContext;
 import flash.utils.getTimer;
 /** External physical-input regression. No product code or user profile writes. */
 public class BStartupDriverMod extends Sprite {
  private static var root:Object,mod:Object,domain:ApplicationDomain,cfg:Object,role:String;
  private static var phase:int=0,began:int,at:int,round:int=0,good:int=0,bad:int=0;
  private static var booted:Boolean=false,done:Boolean=false,control:Object={},lastRead:int=0,lastSample:int=-1;
  private static var home:Object,nextRoom:Object,target:Object,floorY:Number,epoch:uint,joinStage:String="";
  private static function file(name:String):File {return new File(String(cfg.evidenceDirectory)).resolvePath(name);}
  private static function write(name:String,value:Object):void {var f:FileStream=new FileStream();f.open(file(name),FileMode.WRITE);f.writeUTFBytes(JSON.stringify(value));f.close();}
  private static function read(name:String):Object {if(!file(name).exists)return null;var f:FileStream=new FileStream();f.open(file(name),FileMode.READ);var s:String=f.readUTFBytes(f.bytesAvailable);f.close();return JSON.parse(s);}
  private static function log(kind:String,data:Object=null):void {var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("BStartupDriver.log"),FileMode.APPEND);f.writeUTFBytes(JSON.stringify({kind:kind,data:data,at:getTimer()})+"\n");f.close();}
  private static function check(ok:Boolean,name:String,data:Object=null):void {if(ok)good++;else bad++;log(ok?"PASS":"FAIL",{name:name,details:data});}
  private static function finish():void {if(done)return;done=true;write(role+"-finished.json",{passed:good,failed:bad});log("DONE",{passed:good,failed:bad});}
  private static function click(name:String):void {var b:DisplayObject=mod.hud.getChildByName("rconnect-"+name);if(b==null)throw new Error("Missing button "+name);b.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));}
  public static function init(main:*):void {
   var id:String=NativeApplication.nativeApplication.applicationID;
   if(id.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)throw new Error("Isolated field profile required");
   root=main;domain=ApplicationDomain.currentDomain;began=getTimer();role=id.indexOf("-join-")>=0?"join":"host";
   var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("startup-test.json"),FileMode.READ);cfg=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();
   var loader:Loader=new Loader(),context:LoaderContext=new LoaderContext(false,domain);context.allowCodeImport=true;
   loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
    try {var entry:Object=domain.getDefinition("RConnectMod");entry.init(root);mod=entry.instance;
     mod.preferences.setValue("port",String(cfg.port));mod.preferences.setValue("hostIp","127.0.0.1");mod.preferences.setValue("followTeammate","0");
     log("installed",{version:entry.VERSION,source:domain.getDefinition("authority.BuildInfo")["SOURCE"],scenario:cfg.scenario,role:role});
     poseContract();
     fieldsContract();
     if(cfg.scenario=="enemies"){var ProbeType:Class=domain.getDefinition("authority.EnemyVisualProbe") as Class;mod.probe=new ProbeType(mod.access,role=="host");}
     root.stage.addEventListener(Event.ENTER_FRAME,input,false,200000);root.stage.addEventListener(Event.ENTER_FRAME,step,false,-100000);
    }catch(error:*){check(false,"driver initialized",String(error));finish();}
   });
   loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void {check(false,"B loaded",e.text);finish();});
   loader.load(new URLRequest("app:/mods/Rconnect/release/RConnectMod.swf"),context);
  }
  private static function poseContract():void {
   var Pose:Object=domain.getDefinition("authority.VisualPose"),Delta:Class=domain.getDefinition("authority.FrameDelta") as Class;
   var encoder:Object=new Delta(),decoder:Object=new Delta(),sprite:Sprite=new Sprite(),text:TextField=new TextField(),child:Sprite=new Sprite();
   sprite.addChild(text);sprite.addChild(child);sprite.graphics.beginFill(0xff00ff);sprite.graphics.drawCircle(0,0,15);sprite.graphics.endFill();
   child.graphics.beginFill(0x00ff00);child.graphics.drawRect(0,0,10,20);child.graphics.endFill();
   var matches:Boolean=true,immutable:Boolean=true,previous:Object=null,frozen:String="";
   for(var i:int=0;i<160;i++) {
    sprite.transform.matrix=new Matrix(i%2==0?1:-1,i%7/10,-i%9/10,1,i%11,i%13);
    sprite.transform.colorTransform=new ColorTransform(i%3/2,1,0.7,i%5==0?0:1,i%17,0,0,0);
    sprite.visible=i%19!=0;child.visible=i%11!=0;child.rotation=i*17;child.x=i%8;
    sprite.filters=i%4==0?[]:i%4==1?[new GlowFilter(0x22ddaa,0.6,4,5,2)]:i%4==2?[new BlurFilter(2,3)]:[new DropShadowFilter(3,35,0x110022,.5)];
    text.htmlText="<b>"+(i%7)+"</b> hits";text.textColor=i%2==0?0xff0000:0xffffff;
    if(previous!=null && JSON.stringify(previous)!=frozen)immutable=false;
    var actual:Object=Pose.capture(sprite),expected:Object=referencePose(sprite),wire:ByteArray=new ByteArray();
    wire.writeObject(encoder.encode({session:"pose-contract",pose:actual}));wire.position=0;
    var decoded:Object=decoder.decode(wire.readObject());
    matches=matches && equalPose(actual,expected) && equalPose(decoded.pose,expected);
    previous=actual;frozen=JSON.stringify(actual);
   }
   check(matches,"160 pose and wire results match independent native-value capture");
   check(immutable,"prior pose snapshots remain immutable during later captures");
   Pose.dispose(sprite);
  }
  private static function equalPose(a:*,b:*):Boolean {
   if(a===b)return true;if(a==null || b==null || typeof(a)!="object" || typeof(b)!="object" || (a is Array)!=(b is Array))return false;
   if(a is ByteArray || b is ByteArray){if(!(a is ByteArray) || !(b is ByteArray) || a.length!=b.length)return false;for(var j:int=0;j<a.length;j++)if(a[j]!=b[j])return false;return true;}
   if(a is Array && a.length!=b.length)return false;
   for(var k:String in a)if(!b.hasOwnProperty(k) || !equalPose(a[k],b[k]))return false;
   for(k in b)if(!a.hasOwnProperty(k))return false;return true;
  }
  private static function fieldsContract():void {
   var Fields:Object=domain.getDefinition("authority.NativeFields"),Delta:Class=domain.getDefinition("authority.FrameDelta") as Class;
   var encoder:Object=new Delta(),decoder:Object=new Delta(),v:FieldSample=new FieldSample(),matches:Boolean=true,previous:Object=null,frozen:String="";
   var immutable:Boolean=true,application:Boolean=true,restored:FieldSample=new FieldSample(),reference:FieldSample=new FieldSample();
   for(var i:int=0;i<192;i++) {
    v.integer=i-60;v.unsigned=uint(i-60);v.flag=i%2==0;v.number=i%5==0?NaN:i%7==0?Number.POSITIVE_INFINITY:i/7;
    v.string=i%4==0?null:String(i);v.any=[null,NaN,true,"s",i,{x:1},[1,2],Number.NEGATIVE_INFINITY][i%8];v.object=[null,NaN,false,"t",i,{x:2},[2,3]][i%7];v.array=[i];v.in_chain=i%2==0;v.n=i;
    var expected:Object={};
    for each(var field:XML in describeType(v).variable) {
     var key:String=String(field.@name);if(field.hasOwnProperty("@uri") || key=="in_chain" || key=="n")continue;
     var item:*=Object(v)[key];if(item is Number?isFinite(item):item is String || item is Boolean)expected[key]=item;
    }
    if(previous!=null && JSON.stringify(previous)!=frozen)immutable=false;
    var actual:Object=Fields.capture(v),wire:ByteArray=new ByteArray();wire.writeObject(encoder.encode({session:"field-contract",fields:actual}));wire.position=0;
    matches=matches && equalPose(actual,expected) && equalPose(decoder.decode(wire.readObject()).fields,expected);
    // Both destinations may have been modified locally between confirmations.
    restored.integer=reference.integer=-999;restored.flag=reference.flag=false;
    var update:Object={};for(key in actual)update[key]=actual[key];update.n=99;update.in_chain=true;update.absent=7;
    for(key in update)if(key!="n" && key!="in_chain" && key in reference)Object(reference)[key]=update[key];
    Fields.apply(restored,update);
    application=application && equalPose(Fields.capture(restored),Fields.capture(reference)) && restored.n==0 && !restored.in_chain && !("absent" in restored);
    previous=actual;frozen=JSON.stringify(actual);
   }
   check(matches,"192 typed and dynamic scalar snapshots and wire deltas match reference");
   check(immutable,"prior scalar snapshots remain immutable through removals and type changes");
   check(application,"192 native field applications match uncached semantics after local mutations");
   var dynamicTarget:Object={existing:0};Fields.apply(dynamicTarget,{existing:1,later:2});var dynamicOK:Boolean=dynamicTarget.existing==1 && !("later" in dynamicTarget);
   dynamicTarget.later=0;Fields.apply(dynamicTarget,{existing:3,later:4});dynamicOK=dynamicOK && dynamicTarget.existing==3 && dynamicTarget.later==4;
   delete dynamicTarget.later;Fields.apply(dynamicTarget,{later:5});check(dynamicOK && !("later" in dynamicTarget),"dynamic field additions and removals retain original existence checks");
   var accessor:FieldAccessorSample=new FieldAccessorSample();Fields.apply(accessor,{value:3});Fields.apply(accessor,{value:3});
   check(accessor.writes==2 && accessor.value==3,"repeated accessor assignments retain native setter effects");
   var negativeZero:Number=-1;negativeZero/=Number.POSITIVE_INFINITY;
   Fields.apply(restored,{number:negativeZero});var signedZero:Boolean=1/restored.number==Number.NEGATIVE_INFINITY;
   Fields.apply(restored,{number:0.0});check(signedZero && 1/restored.number==Number.POSITIVE_INFINITY,"signed zero retains native assignment semantics");
  }
  /** Frozen B190 capture semantics without interning. Compares values, not the
   * candidate's cache implementation; includes visibility, filters and flips. */
  private static function referencePose(display:DisplayObject,depth:int=0):Object {
   var c:ColorTransform=display.transform.colorTransform,m:Matrix=display.transform.matrix;
   var s:Object={x:display.x,y:display.y,sx:display.scaleX,sy:display.scaleY,r:display.rotation,m:[m.a,m.b,m.c,m.d,m.tx,m.ty],a:display.alpha,v:display.visible,c:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset],blend:display.blendMode,cache:display.cacheAsBitmap,filters:[]};
   if(display is Bitmap){s.smoothing=Bitmap(display).smoothing;s.pixelSnapping=Bitmap(display).pixelSnapping;}
   for each(var filter:Object in display.filters) {
    var f:Object={kind:getQualifiedClassName(filter)};
    if(filter is ColorMatrixFilter)f.matrix=filter.matrix;
    else if(filter is GlowFilter || filter is BlurFilter || filter is DropShadowFilter){for each(var k:String in ["color","alpha","blurX","blurY","strength","quality","inner","knockout","distance","angle","hideObject"])if(k in filter)f[k]=filter[k];}
    else continue;s.filters.push(f);
   }
   if(display is TextField){var t:TextField=TextField(display);s.text=t.htmlText;s.plainText=t.text;s.textColor=t.textColor;s.multiline=t.multiline;s.scrollH=t.scrollH;s.scrollV=t.scrollV;}
   var clip:MovieClip=display as MovieClip;if(clip!=null)s.f=clip.currentFrame;
   var vector:Object=domain.getDefinition("authority.VectorDraw");
   if(display is Sprite && (clip==null || getQualifiedClassName(display)=="flash.display::MovieClip"))s.vector=vector.capture(Sprite(display).graphics);
   else if(display is Shape)s.vector=vector.capture(Shape(display).graphics);
   var parent:DisplayObjectContainer=display as DisplayObjectContainer;
   if(parent!=null && display.visible && display.alpha>0 && depth<12) {
    s.children=[];for(var i:int=0;i<parent.numChildren;i++) {
     var child:DisplayObject=parent.getChildAt(i);if(child==null)continue;
     if(child is MovieClip || child is TextField || child is Sprite || child is Bitmap || clip==null && child is Shape)s.children.push({n:child.name,i:i,cls:getQualifiedClassName(child),s:referencePose(child,depth+1)});
    }
   }
   return s;
  }
  private static function input(e:Event):void {
   if(done || mod==null || !mod.access.ready())return;
   // The historical enemy probe owns its command stream. Physical-input
   // injection is only for the exit and pointer regressions below.
   if(cfg.scenario=="enemies")return;
   try {
    if(role=="join" && getTimer()-lastRead>100){lastRead=getTimer();var c:Object=read("control.json");if(c!=null){if(c.stage!=control.stage)at=getTimer();control=c;}}
    var w:Object=mod.access.world,ctr:Object=w.ctr;
    for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])ctr[key]=false;
    if(control.stage==null)return;
    if(control.move==role)ctr[control.direction==1?"keyLeft":"keyRight"]=true;
    if(control.action==role)ctr.keyAction=true;
    w.celX=Number(control.x);w.celY=Number(control.y);
    if(w.cam!=null){w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;}
   }catch(error:*){check(false,"input injection",String(error));finish();}
  }
  private static function stage(name:String,x:Number=700,y:Number=300,move:String="",direction:int=0):void {
   control={stage:name,x:x,y:y,move:move,direction:direction};write("control.json",control);at=getTimer();
  }
  private static function lane(room:Object):Number {
   var fy:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((fy+1)/40);
   for each(var u:Object in room.units)if(u!=null && !u.player){u.disabled=true;u.remVisual();}
   for(var x:int=0;x<room.space.length;x++)for(var y:int=0;y<=row;y++) {
    var tile:Object=room.space[x][y];tile.phis=y==row?1:0;tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
    tile.water=0;tile.visi=tile.t_visi=1;tile.shelf=false;tile.diagon=tile.stair=0;tile.door=tile.trap=null;
    if(tile.phis==0){tile.front=tile.back=tile.zad="";tile.vid=tile.vid2=tile.zForm=0;}
   }
   room.black=room.mirror=room.base=false;return fy;
  }
  private static function setup():void {
   var s:Object=mod.host,r:Object=s.runtime,w:Object=mod.access.world,a:Object;
   home=s.actors[0].unit.loc;
   if(cfg.scenario=="boundary") {
    home=null;
    for(var x:int=0;x<w.land.locs.length-1 && home==null;x++)for(var y:int=0;y<w.land.locs[x].length;y++) {
     var left:Object=w.land.locs[x][y],right:Object=w.land.locs[x+1][y];
     if(left!=null && right!=null && left[0]!=null && right[0]!=null && !left[0].sky && !right[0].sky && left[0].prob==null && right[0].prob==null && left[0].limY==right[0].limY){home=left[0];nextRoom=right[0];break;}
    }
    if(home==null)throw new Error("Map lacks adjacent ordinary rooms");
    r.rooms.ensure(home);r.rooms.ensure(nextRoom);lane(nextRoom);
   }
   floorY=lane(home);
   for each(a in s.actors) {
    r.transfers.relocate(a,home,a.id==0?520:600,floorY);
    mod.access.scope.run(a.context,function():void {a.unit.setLocPos(a.id==0?520:600,floorY);a.unit.dx=a.unit.dy=0;a.unit.invulner=true;a.unit.hp=a.unit.maxhp;});
    a.personal.follow=false;a.context.transitionCooldown=0;a.context.t_battle=0;
   }
   home.t_alarm=0;w.t_battle=0;r.rooms.showHost();
   check(!s.actors[0].personal.follow && !s.actors[1].personal.follow,"both follow preferences are off");
   if(cfg.scenario=="hover") {
    var Box:Class=mod.access.definition("fe.loc.Box");
    mod.access.scope.run(s.actors[0].context,function():void {
     target=new Box(home,"case",700,floorY,<obj cont="custom" lock="1" mine="0"><item id="kofe" kol="9"/></obj>,null);
     home.addObj(target);home.objs.push(target);target.addVisual();target.nazv="B Field cabinet";target.inter.setAct("lock",1);target.inter.update();
    });
    stage("locked",700,floorY-20);
   }else startExit();
  }
  private static function startExit():void {
   var s:Object=mod.host,index:int=round<2?1:0,a:Object=s.actors[index],direction:int=round%2==0?2:1,room:Object=a.unit.loc;
   a.context.transitionCooldown=0;a.context.t_battle=0;room.t_alarm=0;mod.access.world.t_battle=0;
   mod.access.scope.run(a.context,function():void {a.unit.setLocPos(direction==2?room.limX-a.unit.scX/2-30:a.unit.scX/2+30,floorY);a.unit.dx=a.unit.dy=0;});
   epoch=a.roomEpoch;stage("exit-"+round,a.unit.X+100,floorY-40,index==1?"join":"host",direction);
   log("exit-start",{round:round,player:index,room:mod.access.keyFor(room),x:a.unit.X,epoch:epoch});
  }
  private static function sampleHover():void {
   var w:Object=mod.access.world,t:Object=w.gui.vis.getChildByName("celObj"),object:Object=w.loc.celObj;
   var data:Object={stage:control.stage,visible:t.visible,text:t.text,html:t.htmlText,cel:object==null?null:object.nazv,x:w.celX,y:w.celY,lock:object==null || object.inter==null?-1:object.inter.lock,state:object==null || object.inter==null?null:object.inter.stateText};
   log("hover",data);
   if(control.stage=="empty")check(!t.visible || t.text=="","hover clears away from targets",data);
   else check(t.visible && String(t.text).indexOf(control.stage=="loot"?control.expectedName:"B Field cabinet")>=0,"native item hover visible: "+control.stage,data);
   if(control.stage=="locked")check(data.lock==1 && data.state!=null && data.state!="" && String(t.htmlText).indexOf(data.state)>=0,"native locked state is included in hover",data);
   var bitmap:BitmapData=new BitmapData(root.stage.stageWidth,root.stage.stageHeight,false,0);bitmap.draw(root.stage);
   var f:FileStream=new FileStream();f.open(file(role+"-"+control.stage+".png"),FileMode.WRITE);f.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));f.close();bitmap.dispose();
   write(role+"-"+control.stage+".json",data);
  }
  private static function step(e:Event):void {
   if(done)return;
   try {
    if(getTimer()-began>int(cfg.timeout)*1000){check(false,"scenario timeout",{phase:phase,stage:control.stage});finish();return;}
    var w:Object=mod.access.world;
    if(w.verror.visible){check(false,"no native error",String(w.verror.txt.text));finish();return;}
    if(read((role=="host"?"join":"host")+"-finished.json")!=null && phase<90){check(false,"peer stopped before scenario completion");finish();return;}
    if(!booted && w.landData!=null && w.allLandsLoaded){booted=true;w.mm.active=false;w.newGame(cfg.scenario=="enemies"?-1:0,"B Field Test",null);return;}
    if(!mod.access.ready())return;
    if(mod.role=="") {
     if(w.pip.active)w.pip.onoff(-1);
     if(w.clickReq==1)w.ctr.onMouseDown1(new MouseEvent(MouseEvent.MOUSE_DOWN));
     if(w.t_exit>0 || w.t_die>0 || !w.gg.ggControl || w.gg.work=="res" || w.gg.work=="change")return;
    }
    if(phase==0){if(role=="host" && cfg.scenario=="boundary" || cfg.scenario=="enemies")w.game.beginMission("random_mane");phase=1;at=getTimer();return;}
    if(phase==1 && getTimer()-at>1000){if(cfg.scenario=="enemies"){check(!w.loc.base && w.land.act.id=="random_mane","historical combat fixture uses an exploration room",{base:w.loc.base,land:w.land.act.id});mod.probe.prepare();}click(role);phase=2;return;}
    if(cfg.scenario=="enemies" && phase>=2) {
     if(mod.probe.finished && !file(role+"-probe.json").exists){phase=90;check(mod.probe.failed==0,"historical enemy visuals and gameplay regression",{passed:mod.probe.passed,failed:mod.probe.failed});write(role+"-probe.json",{passed:mod.probe.passed,failed:mod.probe.failed});}
     if(file("host-probe.json").exists && file("join-probe.json").exists){phase=90;if(role=="join")mod.leaveSession();if(role=="join" || mod.role=="")finish();}
     return;
    }
    if(phase==2 && mod.welcomed){mod.hud.visible=false;phase=3;at=getTimer();return;}
    if(phase==3 && getTimer()-at>1500){if(role=="host")setup();phase=4;at=getTimer();return;}
    if(phase<4)return;
    if(mod.ui.session.error!=""){check(false,"session stays live",mod.ui.session.error);finish();return;}
    if(control.stage=="end"){phase=90;if(role=="join"){mod.leaveSession();finish();}else if(mod.role=="")finish();return;}
    if(cfg.scenario=="hover") {
     var n:int=control.stage=="locked"?0:control.stage=="unlocked"?1:control.stage=="empty"?2:control.stage=="loot"?3:-1;
     if(n>=0 && n!=lastSample && getTimer()-at>2500){lastSample=n;sampleHover();}
     if(role=="host" && n>=0 && read("host-"+control.stage+".json")!=null && read("join-"+control.stage+".json")!=null) {
      if(n==0){target.inter.setAct("lock",0);target.inter.update();stage("unlocked",700,floorY-20);}
      else if(n==1){stage("interact",700,floorY-20);control.action="join";write("control.json",control);}
      else if(n==3)stage("empty",850,floorY-150);
      else {stage("end");phase=90;}
     }
     if(role=="host" && control.stage=="interact" && getTimer()-at>2000) {
      check(target.inter.open || target.inter.cont=="empty" || !target.inter.active,"join still performs authoritative container interaction",{open:target.inter.open,cont:target.inter.cont,active:target.inter.active});
      var drop:Object=home.firstObj;while(drop!=null && !("item" in drop && drop.item!=null && drop.item.id=="kofe"))drop=drop.nobj;
      if(drop==null){check(false,"container created real loot for hover check");stage("empty",850,floorY-150);}
      else {drop.auto=false;stage("loot",drop.X,drop.Y-10);control.expectedName=drop.nazv;write("control.json",control);}
     }
    }else if(role=="host") {
     var index:int=round<2?1:0,a:Object=mod.host.actors[index],peer:Object=mod.host.actors[1-index],expected:Object=round%2==0?nextRoom:home;
     if(a.roomEpoch>epoch) {
      check(a.unit.loc===expected,"physical walk crosses ordinary exit round "+round,{room:mod.access.keyFor(a.unit.loc)});
      check(peer.unit.loc===home,"non-following teammate stays in own room round "+round);
      check(w.gg===mod.host.actors[0].unit && w.loc===w.gg.loc && w.gg.ggControl,"host retains own actor and view round "+round);
      stage("settle-"+round);control.expectedRoom=mod.access.keyFor(mod.host.actors[1].unit.loc);write("control.json",control);phase=5;at=getTimer();epoch=a.roomEpoch;
     }
     if(phase==5 && getTimer()-at>1500 && read("join-settle-"+round+".json")!=null){round++;phase=4;if(round==4){stage("end");phase=90;}else startExit();}
     if(phase==5 && getTimer()-at>10000){check(false,"join confirms room presentation",{round:round});finish();}
     else if(phase==4 && getTimer()-at>12000){check(false,"physical exit responds",{round:round,x:a.unit.X,room:mod.access.keyFor(a.unit.loc),work:a.unit.work,tBattle:a.context.t_battle,alarm:a.unit.loc.t_alarm});finish();}
    }else if(control.stage!=null && String(control.stage).indexOf("settle-")==0 && String(control.stage)!=joinStage && getTimer()-at>800) {
     // Evidence uses replica-confirmed identities; it never moves the native player.
     joinStage=String(control.stage);var info:Object={stage:control.stage,room:mod.access.keyFor(w.loc),expected:control.expectedRoom,player:w.gg.X,frames:mod.replica.frames};
     check(info.room==info.expected,"join presents its independently occupied room "+joinStage,info);write("join-"+joinStage+".json",info);
    }
   }catch(error:*){check(false,"driver scenario executed",{message:String(error),stack:error.getStackTrace()});finish();}
  }
 }
}
 class FieldSample {
  public var integer:int=0,unsigned:uint=0,flag:Boolean=false,number:Number=0,string:String="",any:*,object:Object,array:Array=[],in_chain:Boolean=false,n:int=0;
 }
 class FieldAccessorSample {
  public var writes:int=0;private var stored:int=0;
  public function get value():int{return stored;}
  public function set value(v:int):void{stored=v;++writes;}
 }
