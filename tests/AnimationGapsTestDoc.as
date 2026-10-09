package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.RConnectAnimationAccess;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.DeathVisuals;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native loot and MovieClip enemies through the actual two-end Session. */
   public class AnimationGapsTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),mod:RConnectMod,host:Boolean,links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,baseX:Number,baseY:Number,units:Array=[],drop:Object,weaponDrop:Object;
      private var trace:Array=[],clipTrace:Array=[],serial:int=0,sampled:int=-1,frameTime:int=0,previous:int=0,px:Number,py:Number;
      private var incomingLoot:Array=[];
      private var clips:Object={},parts:Dictionary=new Dictionary(),effects:Object={},knownEffects:Object={};
      private var ready:Boolean=false,localDone:Boolean=false,peerDone:Boolean=false,deathAt:int=0;
      private var paused:Boolean=false,resumed:Boolean=false,pauseFrames:Object={},pauseSamples:int=0,weaponFrames:int=0,weaponMotion:int=0,weaponPrevious:Number=NaN,weaponOffset:Boolean=false;
      private var stoppedFixture:Object,fixturePose:Object,fixtureStopped:Boolean=true,fixtureFrames:Object={};
      public function AnimationGapsTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"animation-gaps "+label);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="animation-gaps-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(!host && p.lootMotion is Array)for each(var received:Object in p.lootMotion)
            if(received.b=="kofe")incomingLoot.push({received:getTimer(),sample:received.sampleTime,x:received.x,y:received.y});
         if(p.type!="animation-gaps-test")return;
         if(host && p.stage=="ready"){baseX=mod.game.gg.X;baseY=mod.game.gg.Y;setup();send("begin",{x:baseX,y:baseY});}
         else if(!host && p.stage=="begin"){baseX=p.x;baseY=p.y;setup();}
         else if(p.stage=="sampled"){peerDone=true;if(localDone){send("done");finish();}}
         else if(p.stage=="done")finish();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(mod.game.gg!=null){mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;}
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(phase=="boot" && mod.game.gg!=null && mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning() && !host) {
            send("ready");phase="waiting";at=getTimer();
         }
         if(phase!="done" && at>0 && getTimer()-at>35000){check(false,"timeout "+phase);send("done");finish();}
      }
      private function spawn(name:String,id:String,tr:int,offset:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class,xml:XML=<unit/>;xml.@tr=tr;
         var u:Object=new c(String(tr),100,xml,null);u.id="gaps_"+id;
         u.putLoc(mod.game.loc,baseX+offset,baseY-90);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.xp=0;u.doop=true;u.dx=u.dy=0;units.push(u);return u;
      }
      private function setup():void {
         phase="running";at=getTimer();
         var b:Object=mod.game;b.gg.disabled=true;b.gg.dx=b.gg.dy=0;b.gg.isTake=0;
         if(host){
            spawn("UnitBloat","bloat1",1,100);spawn("UnitBloat","bloat8",8,220);spawn("UnitMsp","msp",1,160);
            var itemClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.serv.Item") as Class;
            var lootClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Loot") as Class;
            drop=new lootClass(b.loc,new itemClass(null,"kofe",1),baseX+80,baseY-160,false,false,false);
            drop.stay=true;drop.auto=false;
            stoppedFixture=spawn("UnitBloat","stopped",1,300);
            // A fresh native MovieClip is implicitly autoplaying yet reports
            // isPlaying=false. First received stopped pose at that exact frame
            // must really stop it, then resume at the same frame on request.
            fixturePose={ai:0,clip:{frame:stoppedFixture.vis.osn.currentFrame,playing:false}};
            RConnectAnimationAccess.receive(stoppedFixture as Unit,fixturePose,"");
         }
         // Discover native particle identities without relying on a generic Part count.
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         for each(var key:String in ["expl","flare","miniexpl"]){
            var part:Object=emitter.arr[key].cast(b.loc,baseX,baseY-100);
            if(part!=null){knownEffects[key]={cls:part.vClass,blit:part.blitData};b.loc.remObj(part);}
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,beginFrame,false,100001);
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
      }
      private function beginFrame(e:Event):void {frameTime=getTimer();serial++;}
      private function drive(e:Event):void {
         if(phase!="running")return;
         mod.game.forceCloseOverlays();mod.game.gg.disabled=true;mod.game.gg.isTake=0;
         if(host) {
            var elapsed:int=frameTime-at;
            for each(var u:Object in units)if(u.sost<3){u.disabled=true;u.dx=u.dy=0;}
            drop.X=baseX+80+elapsed*.015;drop.Y=baseY-160+elapsed*.006;
            drop.dx=drop.dy=0;drop.stay=true;drop.vis.x=drop.X;drop.vis.y=drop.Y;
            if(elapsed>2000 && weaponDrop==null) {
               var itemClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.serv.Item") as Class;
               var lootClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Loot") as Class;
               weaponDrop=new lootClass(mod.game.loc,new itemClass("weapon","lmg",1),baseX+230,baseY-130,true,false,false);
               weaponDrop.dx=2;weaponDrop.dy=-8;
               RConnectAnimationAccess.receive(stoppedFixture as Unit,{ai:0,clip:{frame:fixturePose.clip.frame,playing:true}},"",fixturePose);
            }
            if(elapsed>4500 && !paused){paused=true;units[0].vis.osn.gotoAndStop(2);}
            if(elapsed>5900 && !resumed){resumed=true;units[0].vis.osn.gotoAndPlay(2);}
            if(elapsed>6500 && deathAt==0){deathAt=frameTime;units[2].dam=0;units[2].hp=0;units[2].die();}
         }
         mod.stage.invalidate();
      }
      private function find(id:String):Object {for each(var u:Object in mod.game.loc.units)if(u.id=="gaps_"+id)return u;return null;}
      private function findDrop(id:String="kofe"):Object {
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)
            if(GameBridge.probe(o,"item")!=null && o.item.id==id)return o;
         return null;
      }
      private function tree(v:DisplayObjectContainer,prefix:String,out:Object,depth:int=0):void {
         if(v==null || depth>4)return;
         if(v is MovieClip && MovieClip(v).totalFrames>1)out[prefix]={f:MovieClip(v).currentFrame,n:MovieClip(v).totalFrames,play:MovieClip(v).isPlaying,label:MovieClip(v).currentLabel};
         for(var i:int=0;i<v.numChildren;i++)if(v.getChildAt(i) is DisplayObjectContainer)
            tree(v.getChildAt(i) as DisplayObjectContainer,prefix+"/"+v.getChildAt(i).name,out,depth+1);
      }
      private function collectEffects():void {
         for(var p:Object=mod.game.loc.firstObj;p!=null;p=p.nobj) {
            if(getQualifiedClassName(p)!="fe.graph::Part" || parts[p])continue;parts[p]=true;
            for(var key:String in knownEffects) {
               var identity:Object=knownEffects[key];
               if(identity.blit!=null?p.blitData===identity.blit:p.vClass===identity.cls)effects[key]=int(effects[key])+1;
            }
         }
      }
      private function sample(e:Event):void {
         if(phase!="running" || sampled==serial)return;sampled=serial;
         try {
            var elapsed:int=frameTime-at;
            collectEffects();
            if(host && elapsed>500 && elapsed<1900)fixtureStopped=fixtureStopped && stoppedFixture.vis.osn.currentFrame==fixturePose.clip.frame;
            if(host && elapsed>2300 && elapsed<4000)fixtureFrames[stoppedFixture.vis.osn.currentFrame]=true;
            if(!host){drop=findDrop();weaponDrop=findDrop("lmg");}
            if(weaponDrop!=null) {
               weaponFrames++;
               if(!isNaN(weaponPrevious) && Math.abs(weaponDrop.vis.y-weaponPrevious)>.1)weaponMotion++;
               weaponPrevious=weaponDrop.vis.y;
               if(elapsed>4500)weaponOffset=Math.abs(weaponDrop.Y-weaponDrop.vis.y-10)<.05;
            }
            if(elapsed>1500 && drop!=null) {
               if(previous>0)trace.push({at:frameTime,x:drop.vis.x,y:drop.vis.y,dt:frameTime-previous,dx:drop.vis.x-px,dy:drop.vis.y-py});
               previous=frameTime;px=drop.vis.x;py=drop.vis.y;
               for each(var id:String in ["bloat1","bloat8"]) {
                  var u:Object=find(id);if(u==null)continue;
                  var state:Object={};tree(u.vis as DisplayObjectContainer,id,state);
                  if(id=="bloat1")clipTrace.push({t:elapsed,f:u.vis.osn.currentFrame,play:u.vis.osn.isPlaying});
                  if(!ready)Log.d("ANIMATION TREE "+JSON.stringify(state));
                  for(var path:String in state) {
                     var row:Object=clips[path];if(row==null)row=clips[path]={frames:{},changes:0,last:-1,n:state[path].n,playing:state[path].play};
                     if(row.last!=state[path].f)row.changes++;row.last=state[path].f;row.frames[String(row.last)]=true;
                  }
               }
               ready=true;
            }
            if(elapsed>5200 && elapsed<5750) {
               var stopped:Object=find("bloat1");if(stopped!=null){pauseFrames[stopped.vis.osn.currentFrame]=true;pauseSamples++;}
            }
            if(elapsed>9000) {
               Log.d("ANIMATION CLIPS "+JSON.stringify(clips));Log.d("ANIMATION LOOT "+JSON.stringify(trace));Log.d("ANIMATION EFFECTS "+JSON.stringify(effects));
               Log.d("ANIMATION PAUSE TRACE "+JSON.stringify(clipTrace));
               Log.d("ANIMATION LOOT ARRIVALS "+JSON.stringify(incomingLoot));
               // This fixture drives steady motion from the native frame. A
               // half-second source stall supplies no new positions; a bounded
               // receiver must then hold its last point. Record that prerequisite
               // separately instead of attributing every hold to interpolation.
               // Keep the original remote stall and speed-error limits below.
               if(host) {
                  var maxSourceGap:int=0;
                  for each(var sourceFrame:Object in trace)maxSourceGap=Math.max(maxSourceGap,int(sourceFrame.dt));
                  check(maxSourceGap<=200,"steady-motion source frames remain within 200ms actual="+maxSourceGap);
               }
               var stalls:int=0,errors:Array=[];
               for each(var t:Object in trace){if(Math.abs(t.dx)<.01)stalls++;errors.push(Math.abs(t.dx/t.dt-.015));}
               errors.sort(Array.NUMERIC);
               check(trace.length>30 && stalls<trace.length*.15 && errors[int(errors.length*.95)]<.015,
                  "drop advances between packets frames="+trace.length+" stalls="+stalls+" p95="+errors[int(errors.length*.95)]);
               for each(id in ["bloat1","bloat8"]) {
                  var maxChanges:int=0;for(path in clips)if(path.indexOf(id+"/")==0)maxChanges=Math.max(maxChanges,clips[path].changes);
                  check(maxChanges>trace.length*.5,"native flight clip advances "+id+" changes="+maxChanges+" frames="+trace.length);
               }
               var stoppedFrames:int=0;for(var f:String in pauseFrames)stoppedFrames++;
               check(pauseSamples>=4 && stoppedFrames==1,"host-stopped flight stays stopped samples="+pauseSamples+" frames="+stoppedFrames);
               var resumedSamples:int=0,resumedChanges:int=0,lastFrame:int=-1;
               for each(var flight:Object in clipTrace)if(flight.t>6500){resumedSamples++;if(lastFrame!=flight.f)resumedChanges++;lastFrame=flight.f;}
               check(resumedSamples>=10 && resumedChanges>resumedSamples*.85,"resumed flight advances continuously changes="+resumedChanges+"/"+resumedSamples);
               check(weaponFrames>10 && weaponMotion>5,"native weapon toss has intermediate falling frames="+weaponMotion+"/"+weaponFrames);
               check(weaponOffset,"weapon drop preserves native 10px display offset after landing");
               check(int(effects.expl)>0 && int(effects.flare)>0,"spider mine produces full explosion and flare "+JSON.stringify(effects));
               if(!host){
                  var before:String=JSON.stringify(effects);mod.game.applyUnitsSync(mod.game.readUnitsSnapshot());collectEffects();
                  check(JSON.stringify(effects)==before,"repeated dead snapshot never replays explosion");
               }
               else {
                  var count:int=0;for(var key:String in fixtureFrames)count++;
                  check(fixtureStopped,"first stopped pose overrides implicit autoplay at the same frame");
                  check(count==3,"same-frame resume advances the whole native flight cycle frames="+count);
                  ownershipChecks();
               }
               localDone=true;phase="sampled";send("sampled");if(peerDone){send("done");finish();}
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function ownershipChecks():void {
         // Unit.explosion constructs a Bullet outside the step chain and calls
         // explosion immediately. No run() means no water detection, even in a
         // wet tile. Keep the cosmetic recipe faithful to that native path.
         var mine:Object=units[2],tile:Object=mod.game.loc.getAbsTile(mine.X,mine.Y-3),water:int=tile.water;
         var bulletClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         try {
            tile.water=1;
            var nativeBlast:Object=new bulletClass(mine as Unit,mine.X,mine.Y-3,null,false);
            check(nativeBlast.inWater==-1 && !nativeBlast.in_chain && DeathVisuals.capture(mine).water===false,
               "immediate native death blast keeps its default water state without stepping or damage");
         } finally {tile.water=water;}
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
         b.world=mod.game.world;b.loc=mod.game.loc;b.gg=mod.game.gg;b.roomRole(false);
         var itemClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.serv.Item") as Class;
         var data:Object={k:"test-local",b:"kofe",item:(new itemClass(null,"kofe",1)).save(),x:baseX+360,y:baseY-140,sampleTime:getTimer()};
         b.applyLootSync([data]);var lo:Object;
         for(var o:Object=b.loc.firstObj;o!=null;o=o.nobj)
            if(GameBridge.probe(o,"item")!=null && o.item.id=="kofe" && Math.abs(o.X-data.x)<1)lo=o;
         check(lo!=null && b.controlsLoot(lo),"remote drop is controlled by owner trajectory");
         if(lo!=null) {
            var x:Number=lo.X,y:Number=lo.Y;
            for(var i:int=0;i<8;i++)lo.step();
            check(lo.X==x && lo.Y==y,"repeated native physics steps cannot drift a network-owned drop");
            lo.dx=3;lo.step();
            check(!b.controlsLoot(lo) && lo.X!=x,"local impulse returns motion to native physics");
            lo.levit=1;lo.X+=60;x=lo.X;b.applyLootSync([data]);
            var reports:Object=b.scanLootReports();
            check(lo.X==x && reports!=null && reports.moved.length==1,"telekinesis retains local position and reports it to owner");
            lo.levit=0;lo.vsos=true;b.applyLootSync([data]);
            check(!b.controlsLoot(lo) && lo.X==x,"local pickup suction takes precedence over old host position");
            lo.vsos=false;b.roomRole(true);lo.dx=3;x=lo.X;lo.step();
            check(lo.X!=x,"new room owner resumes native loot motion");
         }
         b.applyLootSync([]);b.endSession();
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,beginFrame);mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE animation-gaps "+(host?"host":"join"));
      }
   }
}
