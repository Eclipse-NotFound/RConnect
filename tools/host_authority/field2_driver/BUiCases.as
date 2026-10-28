package {
 import flash.display.BitmapData;
 import flash.display.DisplayObject;
 import flash.display.MovieClip;
 import flash.geom.Matrix;
 import flash.system.ApplicationDomain;
 import flash.text.TextField;
 import flash.text.TextFieldAutoSize;
 import flash.utils.getTimer;

 /** External, identical baseline/candidate checks. No product test hook needed.
  * Construct after the driver's native setup. input() precedes game input;
  * step() follows the native GUI step. api: check/write/read/finish/log,
  * home/nextRoom/floorY (host only). See UI-TEST-INTEGRATION.md. */
 public final class BUiCases {
  private var mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,role:String,api:Object;
  private var home:Object,nextRoom:Object,target:Object,floorY:Number;
  private var control:Object={},lastRead:int=0,at:int=0,round:int=0,epoch:uint;
  private var phase:String="",joinStage:String="",tip:int=1,stats:Object;
  private var activeSeen:Boolean=false,ended:Boolean=false,textDone:Boolean=false;
  public var finished:Boolean=false;
  public function BUiCases(m:Object,r:Object,d:ApplicationDomain,c:Object,side:String,a:Object) {
   mod=m;root=r;domain=d;cfg=c;role=side;api=a;
   home=a.home;nextRoom=a.nextRoom;floorY=Number(a.floorY);
  }
  private function check(ok:Boolean,name:String,data:Object=null):void {api.check(ok,"UI: "+name,data);}
  private function now():int {return getTimer();}
  private function publish(name:String,move:String="",direction:int=0,action:String=""):void {
   phase=name;at=now();control={stage:name,move:move,direction:direction,action:action,x:700,y:floorY-20};
   api.write("ui-control.json",control);
   api.log("ui-stage",{stage:name,action:action,tick:mod.host==null?null:mod.host.runtime.tick});
  }
  private function rewrite():void {api.write("ui-control.json",control);}
  private function ack(name:String):Object {return api.read("join-ui-"+name+".json");}
  private function acknowledge(data:Object):void {api.write("join-ui-"+control.stage+".json",data);joinStage=control.stage;}
  public function input():void {
   if(finished)return;
   if(role=="join" && now()-lastRead>100) {
    lastRead=now();var next:Object=api.read("ui-control.json");
    if(next!=null) {
     if(next.stage!=control.stage){at=now();stats=null;api.log("ui-control-seen",{stage:next.stage,action:next.action});}
     control=next;
    }
   }
   var w:Object=mod.access.world,ctr:Object=w.ctr;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele","keyZoom"])ctr[key]=false;
   if(control.stage==null)return;
   if(control.move==role)ctr[control.direction==1?"keyLeft":"keyRight"]=true;
   if(control.action==role)ctr.keyAction=true;
   w.celX=Number(control.x);w.celY=Number(control.y);
   w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;
  }
  public function step():void {
   if(finished)return;
   if(!textDone){textDone=true;textChecks();if(role=="host")startExit();}
   if(role=="join"){joinStep();return;}
   if(phase=="end") {
    if(ack("end")!=null && mod.role==""){finished=true;api.finish();}
    return;
   }
   if(phase.indexOf("exit-")==0) {
    var index:int=round<4?0:1,a:Object=mod.host.actors[index];
    if(a.roomEpoch>epoch) {
     var expected:Object=round%2==0?nextRoom:home,w:Object=mod.access.world;
     check(a.unit.loc===expected,"physical ordinary exit reaches expected room "+round,{room:mod.access.keyFor(a.unit.loc),epoch:a.roomEpoch});
     check(mod.host.actors[1-index].unit.loc===home,"non-following peer stays in own room "+round);
     check(w.gg===mod.host.actors[0].unit && w.loc===w.gg.loc && w.gg.ggControl,"host retains native own actor and view "+round);
     cameraCheck(zoomFor(round),"after exit "+round);
     publish("settle-"+round);control.expectedRoom=mod.access.keyFor(mod.host.actors[1].unit.loc);rewrite();
    }
   }else if(phase.indexOf("settle-")==0 && now()-at>900 && ack(phase)!=null) {
    cameraCheck(zoomFor(round),"after presentation settles "+round);
    if(++round<6)startExit();else makeLock();
   }else if(phase.indexOf("lock-ready-")==0 && now()-at>1100) {
    var ready:Object=ack(phase);a=mod.host.actors[1];
    // Do not begin E from a fixed wall-clock sleep after a forced fixture
    // placement. Join must see the new object/actor and a confirmed neutral
    // command; the host must have consumed that acknowledged command too.
    if(ready!=null && ready.ready===true && ready.ack>0 && mod.host.inputs[1].consumed>=ready.ack && !a.context.ctr.keyAction && a.unit.actionObj==null) {
     api.log("ui-lock-ready",{tip:tip,join:ready,host:actionState(a)});
     activeSeen=false;publish("lock-hold-"+tip,"",0,"join");
    }
   }else if(phase.indexOf("lock-hold-")==0) {
    a=mod.host.actors[1];observeActionStart(a);
    var response:Object=ack(phase);
    if(response!=null) {
     check(activeSeen && a.unit.actionObj===target.inter,"join E begins native timed interaction before cancel, tip "+tip,{remaining:a.unit.t_action,total:a.unit.mt_action,client:response});
     publish("lock-cancel-"+tip);
    }else if(activeSeen && a.unit.actionObj==null) {
     check(false,"cancel observation arrives before native action ends, tip "+tip,actionState(a));
     publish("lock-cancel-"+tip);
    }
   }else if(phase.indexOf("lock-cancel-")==0 && now()-at>1000 && ack(phase)!=null) {
    a=mod.host.actors[1];check(a.unit.actionObj==null && target.inter.lock==1,"releasing E cancels real action without unlocking, tip "+tip,{lock:target.inter.lock});
    activeSeen=false;publish("lock-retry-"+tip,"",0,"join");
   }else if(phase.indexOf("lock-retry-")==0) {
    a=mod.host.actors[1];observeActionStart(a);
    if(activeSeen && a.unit.actionObj==null && target.inter.lock!=1) {
     check(target.inter.lock==0 || target.inter.lock==101,"native interaction resolves successful unlock, tip "+tip,{lock:target.inter.lock,remaining:a.unit.t_action});
     publish("lock-complete-"+tip);
    }
   }else if(phase.indexOf("lock-complete-")==0 && now()-at>1000 && ack(phase)!=null) {
    if(tip==1){tip=2;makeLock();}else publish("end");
   }
   if(phase!="end" && now()-at>16000) {
    check(false,"native UI scenario phase completes",{phase:phase,room:mod.access.roomKey(),actor:mod.host.actors[1].unit.work,action:mod.host.actors[1].unit.actionObj!=null});
    publish("end");
   }
  }
  private function observeActionStart(actor:Object):void {
   if(actor.unit.actionObj!==target.inter)return;
   activeSeen=true;
   if(!control.hasOwnProperty("actionTick")) {
    // Cancellation leaves t_action nonzero. Gate observations on a real new
    // host action and its confirmed tick, not the stale numeric remainder.
    control.actionTick=mod.host.runtime.tick;rewrite();
    api.log("ui-action-start",actionState(actor));
   }
  }
  private function actionState(actor:Object):Object {
   // PlayerActor.snapshot(ack) takes this value as a parameter; PlayerActor
   // has no ack member. HostSession publishes Commands.consumed for its id.
   var command:Object=mod.host.inputs[actor.id];
   return {stage:phase,tick:mod.host.runtime.tick,ack:command.consumed,
    accepted:command.accepted,inputAge:command.lastAt<0?-1:now()-command.lastAt,buttons:command.buttons,
    room:mod.access.keyFor(actor.unit.loc),
    epoch:actor.epoch,roomEpoch:actor.roomEpoch,x:actor.unit.X,y:actor.unit.Y,
    action:actor.unit.actionObj!=null,target:actor.unit.actionObj===target.inter,
    work:actor.unit.work,remaining:actor.unit.t_action,total:actor.unit.mt_action,
    keyAction:actor.context.ctr.keyAction,lock:target.inter.lock,unlock:target.inter.unlock,master:target.inter.master,
    lockTip:target.inter.lockTip,lockSkill:actor.context.pers.getLockTip(target.inter.lockTip),
    lockMaster:actor.context.pers.getLockMaster(target.inter.lockTip)};
  }
  private function zoomFor(n:int):int {return n==1 || n==2?2:1;}
  private function cameraCheck(mode:int,label:String):void {
   var w:Object=mod.access.world,cam:Object=w.cam;
   // Independent native setZoom formula, rather than comparing copied fields.
   var sx:Number=root.stage.stageWidth/w.loc.limX,sy:Number=root.stage.stageHeight/w.loc.limY;
   var expected:Number=mode==0?1:mode==1?Math.max(sx,sy):Math.min(sx,sy);if(expected>0.98)expected=1;
   check(cam.isZoom==mode,"user zoom choice survives "+label,{mode:cam.isZoom,expected:mode});
   check(Math.abs(cam.scaleV-expected)<0.0001 && Math.abs(w.visual.scaleX-expected)<0.0001 && Math.abs(w.visual.scaleY-expected)<0.0001 && Math.abs(w.sats.vis.scaleX-expected)<0.0001,
    "native room and SATS display scales match selected mode "+label,{scale:cam.scaleV,visual:w.visual.scaleX,expected:expected,room:mod.access.roomKey()});
  }
  private function startExit():void {
   var index:int=round<4?0:1,a:Object=mod.host.actors[index],direction:int=round%2==0?2:1,room:Object=a.unit.loc;
   mod.access.world.cam.setZoom(zoomFor(round));cameraCheck(zoomFor(round),"before exit "+round);
   a.context.transitionCooldown=0;a.context.t_battle=0;room.t_alarm=0;mod.access.world.t_battle=0;
   mod.access.scope.run(a.context,function():void {a.unit.setLocPos(direction==2?room.limX-a.unit.scX/2-30:a.unit.scX/2+30,floorY);a.unit.dx=a.unit.dy=0;});
   epoch=a.roomEpoch;publish("exit-"+round,index==1?"join":"host",direction);
   control.x=a.unit.X+(direction==2?100:-100);control.y=floorY-40;rewrite();
   api.log("ui-exit-start",{round:round,actor:index,room:mod.access.keyFor(room),epoch:epoch,mode:zoomFor(round)});
  }
  private function makeLock():void {
   var a:Object=mod.host.actors[1],host:Object=mod.host.actors[0],Box:Class=mod.access.definition("fe.loc.Box");
   mod.access.scope.run(a.context,function():void {
    a.unit.setLocPos(600,floorY);a.unit.dx=a.unit.dy=0;
    // Use persistent native qualifications, not temporary derived fields:
    // Addiction's normal 15-tick setParameters() discards direct lockPick/
    // hacker assignments. The original input, timer and unlock still execute.
    var p:Object=a.context.pers;
    p.skills.lockpick=20;p.skills.science=20;
    a.unit.invent.items.screwdriver.kol=Math.max(1,a.unit.invent.items.screwdriver.kol);
    p.setParameters();
    var qualified:Object={lock:p.getLockTip(1),hack:p.getLockTip(2),lockMaster:p.getLockMaster(1),hackMaster:p.getLockMaster(2)};
    p.setParameters();
    check(qualified.lock>=4 && qualified.hack>=4 && qualified.lockMaster>=1 && qualified.hackMaster>=1 &&
     p.getLockTip(1)==qualified.lock && p.getLockTip(2)==qualified.hack &&
     p.getLockMaster(1)==qualified.lockMaster && p.getLockMaster(2)==qualified.hackMaster,
     "fixture qualifications survive native parameter recomputation, tip "+tip,qualified);
   });
   mod.access.scope.run(host.context,function():void {
    if(target==null) {
     target=new Box(home,"case",700,floorY,<obj cont="custom" lock="1" mine="0"><item id="kofe" kol="9"/></obj>,null);
     home.addObj(target);home.objs.push(target);target.addVisual();
    }
    target.nazv=tip==1?"B UI lock fixture":"B UI hacking fixture";
    target.inter.lockTip=tip;target.inter.t_action=180;target.inter.lockLevel=1;
    target.inter.setAct("lock",1);target.inter.update();
   });
   publish("lock-ready-"+tip);control.target=target.nazv;
   control.preparedAt=now();control.expectedRoom=mod.access.keyFor(a.unit.loc);
   control.epoch=a.epoch;control.roomEpoch=a.roomEpoch;control.playerX=a.unit.X;
   rewrite();
  }
  private function joinStep():void {
   var name:String=String(control.stage),w:Object=mod.access.world;
   if(control.stage==null)return;
   if(name=="end") {
    if(!ended){ended=true;acknowledge({done:true});mod.leaveSession();finished=true;api.finish();}return;
   }
   if(name.indexOf("lock-ready-")==0 && name!=joinStage) {
    var frame:Object=mod.replica.displayFrame;
    if(frame==null || frame.players==null || frame.scene==null || !control.hasOwnProperty("preparedAt") || frame.time<control.preparedAt)return;
    var player:Object=frame.players[1],found:Boolean=false;
    for each(var item:Object in frame.scene.objects)if(item.fields!=null && item.fields.nazv===control.target && item.inter!=null && item.inter.lock==1)found=true;
    // This only qualifies the fixture. It never counts as the later progress
    // bar test and does not write native action/timer state or replay a key.
    if(found && frame.room===control.expectedRoom && mod.access.roomKey()===control.expectedRoom &&
       player.epoch==control.epoch && player.roomEpoch==control.roomEpoch &&
       Math.abs(Number(player.x)-Number(control.playerX))<.1 && Math.abs(w.gg.X-Number(control.playerX))<.1 &&
       player.action==null && w.gg.actionObj==null && !w.ctr.keyAction && player.ack>0) {
     var readyData:Object={ready:true,room:frame.room,epoch:player.epoch,roomEpoch:player.roomEpoch,
      tick:frame.tick,time:frame.time,ack:player.ack,x:player.x,target:control.target};
     api.log("ui-ready-observed",readyData);acknowledge(readyData);
    }
   }else if(name.indexOf("settle-")==0 && name!=joinStage && now()-at>800) {
    var data:Object={room:mod.access.roomKey(),expected:control.expectedRoom,frames:mod.replica.frames};
    check(data.room==data.expected,"join presents its own independently occupied room "+name,data);acknowledge(data);
   }else if(name.indexOf("lock-hold-")==0 || name.indexOf("lock-retry-")==0) {
    sampleProgress();
    if(name.indexOf("lock-hold-")==0 && name!=joinStage && stats.samples>=4 && stats.changes>=2) {
     reportProgress(name);acknowledge(stats);
    }
   }else if((name.indexOf("lock-cancel-")==0 || name.indexOf("lock-complete-")==0) && name!=joinStage && now()-at>700) {
    if(name.indexOf("lock-complete-")==0) {
     var retry:String="lock-retry-"+name.substr("lock-complete-".length);
     check(api.read("join-ui-"+retry+".json")!=null,"completed attempt was observed past 70 percent: "+retry);
    }
    var bar:MovieClip=w.gui.vis.getChildByName("pr_bar") as MovieClip;
    check(w.gg.actionObj==null && bar!=null && !bar.visible,"native progress clears on "+name,{action:w.gg.actionObj!=null,visible:bar==null?null:bar.visible});
    acknowledge({cleared:w.gg.actionObj==null && bar!=null && !bar.visible});
   }
  }
  private function sampleProgress():void {
   var w:Object=mod.access.world,g:Object=w.gg,frame:Object=mod.replica.displayFrame;
   if(stats==null)stats={samples:0,changes:0,visible:0,exact:0,text:0,min:1,max:0,last:-1,firstProblem:null};
   if(frame==null || frame.players==null || !control.hasOwnProperty("actionTick") || frame.tick<control.actionTick)return;
   var n:Object=frame.players[1].native;
   if(n==null || n.t_action<=0 || n.mt_action<=0 || n.t_action>=n.mt_action)return;
   var ratio:Number=(g.mt_action-g.t_action)/g.mt_action;
   if(ratio<0.08 || ratio>0.92)return;
   var bar:MovieClip=w.gui.vis.getChildByName("pr_bar") as MovieClip,text:TextField=w.gui.vis.getChildByName("celObj") as TextField;
   ++stats.samples;if(stats.last!=g.t_action)++stats.changes;stats.last=g.t_action;
   if(bar!=null && bar.visible)++stats.visible;
   var exact:Boolean=bar!=null && bar.visible && Math.abs(bar.pr.scaleX-ratio)<0.002;
   if(exact)++stats.exact;
   var named:Boolean=text!=null && text.visible && text.text.indexOf("B UI ")>=0 && g.actionObj!=null && g.actionObj.owner!=null && text.text.indexOf(g.actionObj.actionText)>=0;
   if(named)++stats.text;stats.min=Math.min(stats.min,ratio);stats.max=Math.max(stats.max,ratio);
   if((!exact || !named) && stats.firstProblem==null)stats.firstProblem={expected:ratio,actual:bar==null?null:bar.pr.scaleX,visible:bar==null?null:bar.visible,action:g.actionObj!=null,text:text==null?null:text.text};
   // A completion attempt gets an early and a late check without a per-frame
   // file stream. Host's real unlock and cleared-bar check cover its ending.
   if(String(control.stage).indexOf("lock-retry-")==0 && ratio>0.7 && stats.samples>=4 && stats.changes>=2 && joinStage!=control.stage) {
    reportProgress(control.stage);acknowledge(stats);
   }
  }
  private function reportProgress(name:String):void {
   check(stats.samples>=4 && stats.changes>=2,"real native action advances across confirmations "+name,stats);
   check(stats.visible==stats.samples && stats.exact==stats.samples && stats.text==stats.samples,
    "native GUI renders target, action and accurate progress every sampled frame "+name,stats);
  }
  private function pixels(d:DisplayObject):BitmapData {var b:BitmapData=new BitmapData(320,160,true,0);b.draw(d,new Matrix(1,0,0,1,110,80));return b;}
  private function same(a:BitmapData,b:BitmapData):Boolean {var diff:*=a.compare(b),ok:Boolean=diff===0;if(diff is BitmapData)BitmapData(diff).dispose();return ok;}
  private function textChecks():void {
   var Pose:Object=domain.getDefinition("authority.VisualPose");
   for each(var mode:String in [TextFieldAutoSize.CENTER,TextFieldAutoSize.RIGHT]) {
    var source:TextField=new TextField(),targetText:TextField=new TextField(),stable:Boolean=true,detail:Object=null;
    source.autoSize=targetText.autoSize=mode;source.multiline=targetText.multiline=false;
    source.text="initial";targetText.text="different width initially";
    for(var i:int=0;i<24;i++) {
     source.text=["78","1000000","MISS","Long NPC response",""][i%5];source.x=17+i*.25;source.y=-13+i*.125;
     var pose:Object=Pose.capture(source);Pose.apply(targetText,pose);
     var applied:Matrix=targetText.transform.matrix,expected:Matrix=source.transform.matrix;Pose.motion(targetText,pose);
     var motion:Matrix=targetText.transform.matrix;
     if(applied.tx!==expected.tx || applied.ty!==expected.ty || motion.tx!==applied.tx || motion.ty!==applied.ty) {
      stable=false;if(detail==null)detail={mode:mode,index:i,expected:[expected.tx,expected.ty],applied:[applied.tx,applied.ty],motion:[motion.tx,motion.ty]};
     }
    }
    check(stable,"text autosize never shifts between confirmation and motion: "+mode,detail);Pose.dispose(source);Pose.dispose(targetText);
   }
   for each(var symbol:String in ["visualNumb","visReplic","visReplic2"]) {
    var Type:Class=mod.access.visualClass(symbol),original:MovieClip=new Type(),copy:MovieClip=new Type();original.stop();copy.stop();
    var field:TextField=symbol=="visualNumb"?original.numb:original.text.text;
    var exact:Boolean=true,settled:Boolean=true;
    for(i=0;i<12;i++) {
     field.text=i%2==0?"78":"NPC response";pose=Pose.capture(original);Pose.apply(copy,pose);
     var nativeImage:BitmapData=pixels(original),confirmed:BitmapData=pixels(copy);Pose.motion(copy,pose);var moving:BitmapData=pixels(copy);
     exact=same(nativeImage,confirmed)&&exact;settled=same(confirmed,moving)&&settled;
     nativeImage.dispose();confirmed.dispose();moving.dispose();
    }
    check(exact,"authored native text pixels match source: "+symbol);check(settled,"authored number/speech pixels remain stable between confirmation and motion: "+symbol);
    Pose.dispose(original);Pose.dispose(copy);
   }
  }
 }
}
