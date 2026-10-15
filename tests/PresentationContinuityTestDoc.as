package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.Bitmap;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;
   import fe.unit.Unit;
   import fe.unit.RConnectAnimationAccess;

   /** Actual container interaction, native Loot physics and native SATS over TCP.
    * A controlled moving native enemy isolates presentation from autonomous AI.
    * Ambient foes are removed from this isolated fixture before spawning its
    * controlled enemy. Density is checked separately; receiving objects never move by driver. */
   public class PresentationContinuityTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),ready:Boolean=false,round:int=0;
      private var baseX:Number,baseY:Number,box:Object,enemy:Object,gun:Object;
      private var renderFrame:int=0,lastRender:int=-1,trace:Array=[],peerTrace:Array=[],lootArrivals:Array=[];
      private var moving:Boolean=false,walkAt:int=0,walkX:Number=0;
      private var endpoint:Number=NaN,pausedX:Number=NaN,resumeJump:Number=0;
      private var stablePauseAt:int=0,initialGap:Number=NaN,worldFrames:int=0;
      private var lastEnemyX:Number=NaN,lastWalk:int=0;
      private var timelineOnly:Boolean=false,latestMotion:Object;
      private var endpointReceived:int=0,endpointSettled:int=0,bufferFrames:Array=[];
      private var bodyFrames:Object={},bodyBacksteps:int=0,previousBody:Object,endpointPose:Object;
      private var seedClass:Object,originalSeed:Function;
      private var bodyTrace:Array=[];
      private var pauseTiming:Array=[];
      private var pauseRounds:int=1,walkNumber:int=0;
      private var deferPausedPackets:Boolean=false,releasingPacket:Boolean=false;
      private var delayedPackets:Array=[],lateExpected:Object,lateFrames:int=0,lateMisses:int=0;
      private var pausedCheckPending:Boolean=false,lateMoving:int=0;
      private var betweenFrames:Boolean=false,repaintIssued:Boolean=false;
      private var packetRelease:Timer=new Timer(10,1),savedFrameRate:Number=NaN;
      private var paintReceived:int=0,paintFrame:int=0,repaintChecks:int=0;

      public function PresentationContinuityTestDoc(enemyTimeline:Boolean=false,repeatPauses:int=1,latePackets:Boolean=false,betweenFramePackets:Boolean=false) {
         timelineOnly=enemyTimeline;
         pauseRounds=Math.max(1,repeatPauses);
         deferPausedPackets=latePackets;
         betweenFrames=betweenFramePackets;
         packetRelease.addEventListener(TimerEvent.TIMER,releaseBetweenFrames);
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         MotionCadenceRegression.run(check);
         DropMotionBurstRegression.run(check);
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"continuity "+label);}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("CONTINUITY PHASE "+(host?"host ":"join ")+s+" round="+round);}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="continuity-test";p.op=op;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);
         if(!host&&deferPausedPackets)l.addEventListener(TcpLink.MESSAGE,deferPacket,false,100000);}}
      private function deferPacket(e:NetMessageEvent):void {
         if(releasingPacket||mod==null||!mod.game.coopPaused)return;
         var p:Object=e.data;
         if(!(p.enemyMotion is Array)&&p.type!="unitsync")return;
         if(betweenFrames && repaintIssued)return;
         // Retain the exact authenticated TCP payload and ordinary Session
         // handlers. Only delivery timing changes; no receiver position is set.
         delayedPackets.push({link:e.currentTarget,data:p});e.stopImmediatePropagation();
         if(betweenFrames && !packetRelease.running) {
            // A slow NEXT simulation frame must not delay a received stop pose.
            // Only this isolated paused fixture changes its stage cadence.
            savedFrameRate=mod.stage.frameRate;mod.stage.frameRate=2;
            packetRelease.reset();packetRelease.start();
         }
      }
      private function releaseBetweenFrames(e:TimerEvent):void {
         repaintIssued=true;paintReceived=getTimer();paintFrame=renderFrame;
         releaseQueuedPackets();
         // Deliberately do not invalidate/updateAfterEvent here. Repainting is
         // production's responsibility, not an effect of the test driver.
      }
      private function releaseQueuedPackets():void {
         var pending:Array=delayedPackets;delayedPackets=[];releasingPacket=true;
         try {for each(var message:Object in pending) {
            message.link.dispatchEvent(new NetMessageEvent(TcpLink.MESSAGE,message.data));
            lateExpected=enemy==null||!mod.game.coopPaused?null:{x:Number(enemy.X)};
            if(lateExpected!=null&&Math.abs(Number(enemy.vis.x)-Number(enemy.X))>1)++lateMoving;
         }}finally{releasingPacket=false;}
      }
      private function klass(n:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(n) as Class;}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function findArena():void {
         var l:Object=mod.game.loc;
         for(var y:int=200;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-320;x+=40) {
            var clear:Boolean=true;
            for(var ix:int=0;ix<=300&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=180;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }
            if(clear){baseX=x;baseY=y;return;}
         }
         throw new Error("native map has no clear floored fixture area");
      }
      private function install():void {
         var g:Object=mod.game.gg;
         g.setPos(baseX,baseY);g.setVisPos();g.invulner=true;g.pers.healAll();
         mod.game.world.pip.onoff(-1);mod.game.world.sats.onoff(-1);
         mod.config.setValue("followTeammate","0");
         // Clear only scene objects intersecting the original tile corridor.
         var l:Object=mod.game.loc;
         if(l.base)throw new Error("continuity needs native combat-room containers and SATS");
         if(host) {
            var removed:int=0;
            for each(var u:Object in l.units.concat())
               if(u!==g && Number(u.fraction)>0 && Number(u.fraction)<100) {
                  l.remObj(u);l.units.splice(l.units.indexOf(u),1);++removed;
               }
            Log.d("CONTINUITY FIXTURE ambient foes removed="+removed);
         }
         for each(var o:Object in l.objs.concat())if(o.X2>baseX-20&&o.X1<baseX+320&&o.Y2>baseY-190&&o.Y1<baseY+20) {
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
         if(timelineOnly) {
            mod.game.presentationTiming={viewMs:0,viewCalls:0,motionMs:0,motionCalls:0};
            mod.stage.addEventListener(Event.ENTER_FRAME,endFrame,false,-30000);
            mod.stage.addEventListener(Event.RENDER,beginRender,false,100000);
         }
      }
      private function makeBox():void {
         var xml:XML=<obj cont="custom"><item id="kofe" kol="37"/></obj>;xml.item.@kol=37+round;
         var c:Class=klass("fe.loc.Box");box=new c(mod.game.loc,"case",baseX+150,baseY,xml,null);
         mod.game.loc.addObj(box);mod.game.loc.objs.push(box);
         trace=[];send("box",{round:round});change("box-ready");
      }
      private function findBox():Object {
         for each(var o:Object in mod.game.loc.objs)
            if(o.id=="case"&&Math.abs(o.begX-baseX-150)<1&&o.inter!=null&&o.inter.cont!="empty")return o;
         return null;
      }
      private function drop():Object {
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            var item:Object=GameBridge.probe(o,"item");
            if(item!=null&&item.id=="kofe"&&int(item.kol)==37+round)return o;
         }
         return null;
      }
      private function makeEnemy():void {
         var c:Class=klass("fe.unit.UnitSlaver");enemy=new c("slaver2",100,<unit tr="2"/>,null);
         enemy.putLoc(mod.game.loc,baseX+90,baseY);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
         enemy.disabled=true;enemy.doop=true;enemy.xp=0;enemy.hp=enemy.maxhp=54321;
         enemy.isSats=true;enemy.invis=false;enemy.animate();
         mod.session.pause.setPolicy(false,true);send("enemy");change("enemy-ready");
      }
      private function findEnemy():Boolean {
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit)&&u.id=="slaver2"&&Number(u.maxhp)==54321)enemy=u;
         return enemy!=null;
      }
      private function startWalk():void {
         ++walkNumber;Log.d("CONTINUITY WALK "+walkNumber+"/"+pauseRounds);
         trace=[];endpoint=pausedX=initialGap=lastEnemyX=NaN;resumeJump=0;stablePauseAt=0;
         endpointReceived=endpointSettled=0;bufferFrames=[];bodyFrames={};bodyBacksteps=0;
         previousBody=endpointPose=latestMotion=null;bodyTrace=[];pauseTiming=[];
         lateExpected=null;
         repaintIssued=false;paintReceived=0;
         moving=true;walkAt=lastWalk=getTimer();walkX=baseX+90;worldFrames=0;
         if(host){enemy.setPos(walkX,baseY);send("walk");}change("walk");
      }
      private function openSats():void {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         if(gun==null)gun=new NativeTestGun(g as Unit);gun.loc=mod.game.loc;gun.hold=90;
         g.currentWeapon=gun;g.childObjs[0]=gun;gun.addVisual();gun.setPers(g,g.pers);gun.lvl=0;
         g.ggControl=true;g.pipOff=0;w.catPause=false;w.pip.onoff(-1);g.storona=1;
         mod.game.loc.getAbsTile(enemy.X,enemy.Y-enemy.scY/2).visi=1;
         w.ctr.keySats=true;change("opening");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(!host && timelineOnly) {
            var poses:Array=p.enemyMotion is Array?p.enemyMotion:(p.type=="unitsync"?p.units:null);
            if(poses!=null)for each(var motion:Object in poses)if(motion.id=="slaver2")latestMotion=motion;
         }
         if(!host && p.lootMotion is Array && (phase=="falling" || phase=="drop-wait"))
            for each(var received:Object in p.lootMotion)
               if(received.item!=null && received.item.id=="kofe" && int(received.item.kol)==37+round)
                  lootArrivals.push({received:getTimer(),sample:received.sampleTime,x:received.x,y:received.y,stay:received.stay});
         if(p.type!="continuity-test")return;
         try {
            if(p.op=="ready"&&host)ready=true;
            else if(p.op=="setup"&&!host){baseX=p.x;baseY=p.y;install();send("installed");change("waiting");}
            else if(p.op=="installed"&&host){if(timelineOnly)makeEnemy();else makeBox();}
            else if(p.op=="box"&&!host){round=p.round;trace=[];lootArrivals=[];change("find-box");}
            else if(p.op=="box-ready"&&host){send("open");if(round==1)box.inter.actOsn();change("falling");}
            else if(p.op=="open"&&!host){if(round==0)box.inter.actOsn();change("falling");}
            else if(p.op=="drop-trace"&&!host){peerTrace=p.trace;analyseDrop();send("drop-result");change("waiting");}
            else if(p.op=="drop-result"&&host){round++;if(round<2)makeBox();else makeEnemy();}
            else if(p.op=="enemy"&&!host)change("find-enemy");
            else if(p.op=="enemy-ready"&&host)startWalk();
            else if(p.op=="walk"&&!host)startWalk();
            else if(p.op=="repeat"&&host)startWalk();
            else if(p.op=="endpoint"&&!host){endpoint=p.x;endpointPose=p.pose;initialGap=Math.abs(enemy.X-endpoint);endpointReceived=getTimer();pauseStamp("endpoint-received");}
            else if(p.op=="paused-result"&&host){moving=false;send("resume");change("resume-wait");}
            else if(p.op=="resume"&&!host){mod.game.world.sats.onoff(-1);change("resuming");}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(error:Error){check(false,"receive "+error.getStackTrace());finish();}
      }
      private function before(e:Event):void {
         ++renderFrame;if(phase=="done")return;
         pauseStamp("enter-begin");
         var g:Object=mod.game.gg;g.invulner=true;g.dx=g.dy=0;g.isTake=0;
         g.setPos(baseX,baseY);g.setVisPos();
      }
      private function after(e:Event):void {
         if(phase=="done")return;
         if(host&&enemy!=null) {
            enemy.disabled=true;
            if(moving&&!mod.session.pause.paused&&mod.game.world.allStat==1) {
               // Continuous known trajectory; all receiving movement remains production code.
               walkX+=3;enemy.setPos(walkX,baseY);enemy.setVisPos();++worldFrames;
               // Use native movement animation selection; assigning animState
               // with dx=0 would be overwritten to stay by Raider.animate.
               if(timelineOnly){enemy.dx=3;enemy.stay=true;enemy.animate();}
            }
         }
         mod.stage.invalidate();
      }
      // Observation only: bracket existing stage callbacks without driving the
      // receiver, changing its cadence, or substituting logical positions for
      // rendered positions. Keep repeated RENDER visits visible in this trace.
      private function endFrame(e:Event):void {pauseStamp("enter-end");}
      private function beginRender(e:Event):void {
         // A packet released during resume is not a paused-frame expectation.
         // Never carry an observation into a later pause or a later render.
         if(!betweenFrames) {
            lateExpected=null;
            if(delayedPackets.length)releaseQueuedPackets();
         }
         pauseStamp("render-begin");
      }
      private function pauseStamp(kind:String):void {
         if(!timelineOnly||enemy==null||(phase!="opening"&&phase!="paused"&&phase!="walk"))return;
         var timing:Object=mod.game.presentationTiming;
         pauseTiming.push({at:getTimer(),kind:kind,frame:renderFrame,phase:phase,
            x:Number(enemy.vis.x),logicalX:Number(enemy.X),paused:mod.session.pause.paused,
            sats:mod.game.world.sats.active,alreadyRendered:lastRender==renderFrame,
            viewMs:timing.viewMs,viewCalls:timing.viewCalls,
            motionMs:timing.motionMs,motionCalls:timing.motionCalls});
         if(pauseTiming.length>220)pauseTiming.shift();
      }
      private function render(e:Event):void {
         pauseStamp("render-observed");
         if(lateExpected!=null&&enemy!=null&&mod.game.coopPaused) {
            ++lateFrames;
            if(Math.abs(Number(enemy.vis.x)-Number(lateExpected.x))>1)++lateMisses;
            Log.d("A22 LATE PAUSE FRAME "+JSON.stringify({frame:renderFrame,expected:lateExpected.x,actual:enemy.vis.x,misses:lateMisses}));
         }
         lateExpected=null;
         if(betweenFrames && paintReceived>0) {
            var delay:int=getTimer()-paintReceived;
            ++repaintChecks;
            check(renderFrame==paintFrame && delay<=100,
               "paused TCP pose repaints without another simulation frame ms="+delay+" frames="+(renderFrame-paintFrame));
            paintReceived=0;
            mod.stage.frameRate=savedFrameRate;savedFrameRate=NaN;
         }
         // Display-only timer events legitimately render between ENTER_FRAMEs.
         // Observe the actual endpoint on every final render, not once per
         // simulation frame; movement/animation cadence samples stay deduped.
         if(timelineOnly&&!host&&enemy!=null&&endpointReceived>0&&endpointSettled==0
            &&Math.abs(Number(enemy.vis.x)-endpoint)<=1)endpointSettled=getTimer();
         if(lastRender==renderFrame||phase=="done")return;lastRender=renderFrame;
         if(phase=="falling"||phase=="drop-wait") {
            var o:Object=drop();if(o!=null&&o.vis!=null&&o.vis.stage!=null)
               trace.push({t:getTimer(),x:o.vis.x,y:o.vis.y,logicalY:o.Y,stay:o.stay,dx:o.dx,dy:o.dy});
         }
         if(enemy!=null&&(phase=="walk"||phase=="opening"||phase=="paused"||phase=="resuming"||phase=="resume-wait")) {
            var x:Number=Number(enemy.vis.x);
            if(!host&&phase=="resuming"&&isFinite(lastEnemyX))resumeJump=Math.max(resumeJump,Math.abs(x-lastEnemyX));
            lastEnemyX=x;trace.push({t:getTimer(),x:x,logicalX:enemy.X,paused:mod.session.pause.paused,sats:mod.game.world.sats.active});
            if(timelineOnly&&!host&&phase=="walk"&&getTimer()-walkAt>600&&latestMotion!=null)
               bufferFrames.push(Math.max(0,(Number(latestMotion.x)-x)/3));
            if(timelineOnly&&phase=="walk") {
               var body:Object=RConnectAnimationAccess.capture(enemy as Unit),anim:String=String(enemy.animState);
               if(body!=null&&body.blit!=null) {
                  var f:Number=Number(body.blit.f);bodyFrames[anim+":"+int(f)]=true;
                  // A loop wrap is a large negative change. Small backward
                  // corrections during a single native gait are visible jitter.
                  if(previousBody!=null&&previousBody.anim==anim&&f<previousBody.f-.01&&f>previousBody.f-4)bodyBacksteps++;
                  previousBody={anim:anim,f:f};
                  if(bodyTrace.length<160)bodyTrace.push({at:getTimer(),f:f,anim:anim,source:latestMotion==null?null:latestMotion.pose});
               }
            }
            if(timelineOnly&&!host&&endpointReceived>0&&endpointSettled==0&&Math.abs(x-endpoint)<=1)
               endpointSettled=getTimer();
         }
         if(pausedCheckPending)checkPausedFrame();
      }
      private function checkPausedFrame():void {
         pausedCheckPending=false;var w:Object=mod.game.world;
         if(timelineOnly) {
            bufferFrames.sort(Array.NUMERIC);
            var lag:Number=bufferFrames.length?bufferFrames[int((bufferFrames.length-1)*.9)]:NaN;
            check(bufferFrames.length>=8,"enemy buffered-frame sample coverage="+bufferFrames.length);
            check(lag<=4,"enemy display is within four already-received native frames p90="+lag);
            check(endpointSettled>0&&endpointSettled-endpointReceived<=100,"SATS final endpoint settles within 100ms after confirmed stop actual="+(endpointSettled-endpointReceived));
            var bodyCount:int=0;for(var frameKey:String in bodyFrames)bodyCount++;
            check(bodyCount>=8,"native walking body presents distinct animation frames="+bodyCount);
            check(bodyBacksteps==0,"walking body does not rewind a few frames between packets count="+bodyBacksteps);
            Log.d("A22 BODY FRAMES "+JSON.stringify(bodyTrace));
            var pausedPose:Object=RConnectAnimationAccess.capture(enemy as Unit);
            check(endpointPose!=null&&endpointPose.blit!=null&&pausedPose.blit!=null&&Math.abs(Number(endpointPose.blit.f)-Number(pausedPose.blit.f))<.01,
               "SATS native body phase matches authority source="+JSON.stringify(endpointPose)+" display="+JSON.stringify(pausedPose));
            Log.d("A22 ENEMY TIMELINE "+JSON.stringify({bodyFrames:bodyCount,bodyBacksteps:bodyBacksteps,bufferFrames:bufferFrames,p90:lag,initialPauseGap:initialGap,settleMs:endpointSettled-endpointReceived,trace:trace}));
            Log.d("A22 PAUSE TIMING "+JSON.stringify(pauseTiming));
         }
         pausedX=enemy.X;check(Math.abs(pausedX-endpoint)<=1,"paused enemy matches authority endpoint gap="+Math.abs(pausedX-endpoint));
         check(mod.session.pause.paused&&w.sats.active,"pause remains owned by native SATS");
         var overlay:Object=null;
         for each(var entry:Object in w.sats.units)
            if(entry.u is MirrorHitUnit && MirrorHitUnit(entry.u).body===enemy)overlay=entry.v;
         check(overlay!=null,"native SATS retains its real enemy targeting overlay");
         check(overlay!=null&&Math.abs(Number(overlay.x)-endpoint)<=1,"SATS target overlay matches paused authority endpoint x="+(overlay==null?"missing":overlay.x));
         if(timelineOnly && overlay!=null) {
            var actual:MovieClip=overlay.getChildAt(0) as MovieClip;
            var fresh:MovieClip=w.sats.drawUnit(enemy);
            var actualBitmap:Bitmap=actual.getChildAt(0) as Bitmap;
            var expectedBitmap:Bitmap=fresh.getChildAt(0) as Bitmap;
            var comparison:Object=actualBitmap.bitmapData.compare(expectedBitmap.bitmapData);
            Log.d("A22 SATS PIXELS "+JSON.stringify({comparison:comparison is BitmapData?"pixels":comparison,
               actual:[actualBitmap.width,actualBitmap.height,actualBitmap.x,actualBitmap.y],
               expected:[expectedBitmap.width,expectedBitmap.height,expectedBitmap.x,expectedBitmap.y],
               pose:RConnectAnimationAccess.capture(enemy as Unit),bodyBounds:enemy.vis.getBounds(enemy.vis)}));
            if(!(comparison is uint && uint(comparison)==0)) {
               saveBitmap(actualBitmap.bitmapData,"actual");saveBitmap(expectedBitmap.bitmapData,"expected");
               if(comparison is BitmapData)saveBitmap(comparison as BitmapData,"difference");
            }
            check(comparison is uint && uint(comparison)==0,"SATS target bitmap matches the final received native body pose");
            if(comparison is flash.display.BitmapData)comparison.dispose();
            expectedBitmap.bitmapData.dispose();
         }
         send("paused-result");change("paused-wait");
      }
      private function analyseDrop():void {
         var minY:Number=Infinity,maxY:Number=-Infinity,endY:Number=trace.length?trace[trace.length-1].y:NaN;
         var sourceMin:Number=Infinity,sourceMax:Number=-Infinity;
         for each(var s:Object in peerTrace){sourceMin=Math.min(sourceMin,s.y);sourceMax=Math.max(sourceMax,s.y);}
         var last:Object=null,stillAt:int=0,longest:int=0,airFrames:int=0;
         for each(s in trace) {
            minY=Math.min(minY,s.y);maxY=Math.max(maxY,s.y);
            if(Math.abs(s.y-endY)>3) {
               ++airFrames;
               if(last!=null&&Math.abs(s.x-last.x)+Math.abs(s.y-last.y)<.05) {
                  if(stillAt==0)stillAt=last.t;longest=Math.max(longest,int(s.t)-stillAt);
               }else stillAt=0;
            }else stillAt=0;
            last=s;
         }
         Log.d("CONTINUITY DROP "+JSON.stringify({round:round,airFrames:airFrames,longestStillMs:longest,span:maxY-minY,sourceSpan:sourceMax-sourceMin,source:peerTrace,display:trace,arrivals:lootArrivals}));
         check(peerTrace.length>10&&sourceMax-sourceMin>20,"native container loot completes a visible falling arc round="+round);
         check(airFrames>=8&&maxY-minY>20,"receiver renders the drop arc round="+round+" frames="+airFrames);
         check(longest<=85,"falling loot has no stationary display gap above 85ms round="+round+" actual="+longest);
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null)return;
         if(seedClass==null) {
            // Reuse the recorded baseline map, only in this isolated driver.
            // A random room without a clear corridor cannot test gait/SATS.
            seedClass=klass("fe.loc.Land");originalSeed=seedClass.rconnectSeedSource;
            var fallback:Function=originalSeed;
            seedClass.rconnectSeedSource=function(land:Object):uint {
               return String(land.act.id)=="random_mane"?uint(2646199556):uint(fallback(land));
            };
         }
         if(mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            var w:Object=mod.game.world;mod.game.gg.invulner=true;
            if(phase=="done")return;
            if(getTimer()-at>90000){check(false,"timeout "+phase);finish();return;}
            if(phase=="boot"&&stable()&&String(mod.game.readWorldInfo().curLandId)=="random_mane") {
               if(host&&ready){check(Number(GameBridge.probe(mod.game.world.land,"rconnectLayoutSeed"))==2646199556,"isolated fixture uses recorded native map seed");findArena();install();send("setup",{x:baseX,y:baseY});change("setup-wait");}
               else if(!host)send("ready");
            }
            else if(!host&&phase=="find-box"&&getTimer()-at>900&&(box=findBox())!=null){send("box-ready");change("box-wait");}
            else if(host&&phase=="falling"&&getTimer()-at>4500) {
               check(trace.length>10,"source container actually spawned native loot round="+round);
               send("drop-trace",{trace:trace});change("drop-wait");
            }
            else if(!host&&phase=="find-enemy"&&findEnemy()&&mod.session.pause.policySats){send("enemy-ready");change("enemy-wait");}
            else if(!host&&phase=="walk"&&getTimer()-at>(timelineOnly?2100:1500))openSats();
            else if(!host&&phase=="opening"&&w.sats.active&&mod.session.pause.paused) {check(true,"native joining SATS initiates shared pause");change("paused");}
            else if(host&&phase=="walk"&&mod.session.pause.paused) {
               endpoint=enemy.X;check(worldFrames>=12,"source enemy was moving before pause frames="+worldFrames);
               send("endpoint",{x:endpoint,pose:RConnectAnimationAccess.capture(enemy as Unit)});change("paused");
            }
            else if(!host&&phase=="paused"&&getTimer()-at>1200&&isFinite(endpoint))pausedCheckPending=true;
            else if(!host&&phase=="resuming"&&getTimer()-at>900&&!mod.session.pause.paused) {
               Log.d("CONTINUITY PAUSE "+JSON.stringify({endpoint:endpoint,initialGap:initialGap,pausedX:pausedX,resumeJump:resumeJump,trace:trace}));
               check(resumeJump<=4,"resume does not teleport a stopped enemy jump="+resumeJump);
               check(Math.abs(enemy.X-endpoint)<=1,"resumed enemy still matches source endpoint");
               if(walkNumber<pauseRounds){send("repeat");change("repeat-wait");}
               else {send("done");finish();}
            }
         }catch(error:Error){check(false,"tick "+error.getStackTrace());send("done");finish();}
      }
      private function saveBitmap(data:BitmapData,name:String):void {
         var file:File=File.applicationStorageDirectory.resolvePath("presentation-sats-target-"+name+".png");
         var stream:FileStream=new FileStream();stream.open(file,FileMode.WRITE);
         try {stream.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));}finally{stream.close();}
      }
      private function finish():void {
         if(phase=="done")return;change("done");timer.stop();
         packetRelease.stop();
         if(mod!=null && isFinite(savedFrameRate))mod.stage.frameRate=savedFrameRate;
         if(!host&&betweenFrames)check(repaintChecks==pauseRounds,"between-frame repaint covers every fixed pause round="+repaintChecks);
         if(!host&&deferPausedPackets) {
            check(lateFrames>=4,"late paused TCP packet coverage="+lateFrames);
            check(lateMoving>=1,"late delivery actually changes accepted logical position="+lateMoving);
            check(lateMisses==0,"late paused TCP pose reaches the same render misses="+lateMisses);
         }
         if(seedClass!=null)seedClass.rconnectSeedSource=originalSeed;
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            mod.stage.removeEventListener(Event.ENTER_FRAME,endFrame);mod.stage.removeEventListener(Event.RENDER,beginRender);mod.game.presentationTiming=null;}
         for(var link:Object in links) {
            link.removeEventListener(TcpLink.MESSAGE,receive);
            link.removeEventListener(TcpLink.MESSAGE,deferPacket);
         }
         Log.d("COOP EFFECTS DONE continuity "+(host?"host":"join"));
      }
   }
}
