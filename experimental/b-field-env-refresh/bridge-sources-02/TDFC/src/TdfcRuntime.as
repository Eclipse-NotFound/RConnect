package {
 import flash.display.DisplayObjectContainer;
 import flash.events.Event;
 import flash.system.ApplicationDomain;
 import flash.utils.Dictionary;
 import flash.utils.getTimer;
 public class TdfcRuntime {
  private static var host:DisplayObjectContainer;
  private static var worldClass:Class;
  private static var room:*;
  private static var states:Dictionary=new Dictionary(true);
  private static var all:Array=[];
  private static var nextKey:int=1,frame:int=0;
  public static var tick:int=0;
  public static var status:String="初始化";
  private static var perception:PerceptionModel=new PerceptionModel();
  private static var squads:SquadMind=new SquadMind();
  private static var overlay:DebugOverlay;
  private static var cost:Number=0;
  private static var authority:AuthoritySession;
  public static function attachAuthority(owner:Object):Object {
   if(authority!=null)throw new Error("TDFC authority already attached");
   var next:AuthoritySession=new AuthoritySession(owner);
   reset(null);authority=next;TdfcLog.line("authority","attached "+owner.role+" "+owner.session);
   return next.api(function():void {authority=null;all=[];room=null;status="等待世界";TdfcLog.line("authority","detached");});
  }
  public static function init(main:*):void {
   if(host)return;host=main as DisplayObjectContainer;
   if(!host || !host.stage){TdfcLog.line("error","stage unavailable");return;}
   TdfcLog.line("scene-compat","v0.6.4-scene1 distant-enemy scheduling available");
   overlay=new DebugOverlay(host,saveReport);ScenarioRunner.init();overlay.enabled=ScenarioRunner.active;host.stage.addEventListener(Event.ENTER_FRAME,onFrame);
   GrabDiagnostics.init(host.stage,function():*{return worldClass?worldClass["w"]:null;},function():Boolean{return overlay.enabled;});
  }
  private static function reset(loc:*):void {
   PlayerNoise.reset();
   for each(var b:BrainState in all)ActionExecutor.restore(b);
   states=new Dictionary(true);all=[];room=loc;perception.reset();squads.reset();TdfcLog.line("room","reset");
  }
  private static function onFrame(e:Event):void {
   frame++;var w:*=null;
   try {
    if(!worldClass)worldClass=ApplicationDomain.currentDomain.getDefinition("fe.World") as Class;
    w=worldClass["w"];ScenarioRunner.boot(w,frame);
    GrabDiagnostics.update(w);
    var loc:*=GameBridge.get(w,"loc");
    if(authority!=null) {
     room=loc;all=authority.view(loc);tick=authority.clock(loc);status="主侧房间调度";
    } else {
    if(loc!==room)reset(loc);
    var why:String=GameBridge.pause(w);
    if(why)status=why;
    else {
     status="运行";var start:int=getTimer();tick++;
     var gg:*=GameBridge.get(loc,"gg"),g:Object=GameBridge.snapshot(gg);
     PlayerNoise.update(gg);
     ScenarioRunner.combat(w,tick);
     var units:Array=GameBridge.get(loc,"units",[]) as Array,fresh:Array=[],present:Dictionary=new Dictionary(true);
     var sceneGrafon:*=GameBridge.get(w,"grafon"),sceneSleep:Object=null;
     if(GameBridge.get(sceneGrafon,"sceneLarge",false) && "sceneNativeCall" in sceneGrafon)
      sceneSleep=sceneGrafon.sceneNativeCall("sleeping",[loc]);
     for each(var u:* in units) {
      if(sceneSleep && sceneSleep[u]) {
       var remembered:BrainState=states[u];
       if(remembered && remembered.lastSeen>=0)sceneGrafon.sceneNativeCall("wake",[u]);
       else continue;
      }
      if(u===gg)continue;var s:Object=GameBridge.snapshot(u);if(!GameBridge.hostile(s,g))continue;
      var b:BrainState=states[u];if(!b){b=new BrainState(nextKey++,u,EnemyProfile.make(s));states[u]=b;}
      b.previous=b.sample;b.sample=s;fresh.push(b);present[u]=true;ActionExecutor.assess(b,tick);
      if(b.profile.supported)perception.observe(b,g,GameBridge.sense(b,g,loc),tick);
     }
     for each(var old:BrainState in all)if(!present[old.unit]){ActionExecutor.restore(old);delete states[old.unit];}
     all=fresh;perception.deliver(all,tick);perception.schedule(all,tick);squads.frame(all,tick);
     for each(b in all)TacticalStep.run(b,g,loc,all,squads,tick,true);
     cost=getTimer()-start;ScenarioRunner.observe(all,status,tick);
     if(tick%Config.HEARTBEAT_EVERY==0)TdfcLog.line("heartbeat","tick="+tick+" units="+all.length+" cost="+cost+"ms");
    }
    }
   }catch(err:Error){status="TDFC 错误 "+err.errorID;TdfcLog.line("error",err.message+" "+err.getStackTrace());}
   if(frame%3==0){try{overlay.update(w,all,status,tick,cost,TdfcLog.status);if(ScenarioRunner.active && frame%150==0)overlay.capture();}catch(uiErr:Error){TdfcLog.line("ui-error",uiErr.message);}}
   if(frame%30==0)TdfcLog.flush();
  }
  public static function saveReport():void {
   var lines:Array=["TDFC "+Config.VER+" "+status+" tick="+tick,new Date().toUTCString(),"Save: "+JSON.stringify(TestSave.evidence),"Grab: "+JSON.stringify(GrabDiagnostics.last),"GrabRecent: "+JSON.stringify(GrabDiagnostics.recent)];
   var g:Object=GameBridge.snapshot(GameBridge.get(room,"gg"));
   lines.push("Player: "+JSON.stringify({position:[g.x,g.y],center:[g.cx,g.cy],face:g.face,exposure:g.obs,maxExposure:g.maxObs}));
   for each(var b:BrainState in all) {
    var gun:*=GameBridge.get(b.unit,"currentWeapon");
    var aim:Object={beforeOrder:[b.sample.aimX,b.sample.aimY],current:[GameBridge.num(b.unit,"celX"),GameBridge.num(b.unit,"celY")],
     remembered:[b.knownX,b.knownY],visualAge:tick-b.lastVisual,face:GameBridge.num(b.unit,"storona"),viewAngle:GameBridge.num(b.unit,"vAngle"),
     weapon:[GameBridge.num(gun,"X"),GameBridge.num(gun,"Y")],rot:GameBridge.num(gun,"rot"),attached:GameBridge.num(gun,"krep"),ready:GameBridge.get(gun,"ready",false)};
    lines.push("#"+b.key+" "+b.sample.id+" "+b.profile.style+" T"+b.profile.tier+" "+b.profile.source+"\n  position="+b.sample.x+","+b.sample.y+" hp="+b.sample.hp+" fraction="+b.sample.fraction+"\n  evidence="+b.evidence+" age="+(tick-b.lastSeen)+" observed="+b.observed+" confirmed="+b.confirmed+"\n  action="+b.action.kind+" reason="+b.action.reason+" goal="+b.action.x+","+b.action.y+"\n  result="+b.result+" fault="+b.rejected+" stuckUntil="+b.stuckUntil+" suppressCooldown="+b.suppressCooldown+"\n  sense="+JSON.stringify(b.sensing)+"\n  aim="+JSON.stringify(aim));
   }
   TdfcLog.saveReport(lines.join("\n"));
  }
  public static function captureReport():void {if(overlay){overlay.update(worldClass?worldClass["w"]:null,all,status,tick,cost,TdfcLog.status);overlay.capture();}}
  public static function setObservation(enabled:Boolean,w:*):void {if(ScenarioRunner.active && overlay){overlay.enabled=enabled;overlay.update(w,all,status,tick,cost,TdfcLog.status);}}
 }
}
