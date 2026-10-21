package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** External native travel only. No prepareMap, seed replacement, checkpoint
    * restoration, forced coordinates or assignment to Game.curLandId. */
   public final class ColdFixedTravelTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const FIXED:String="raiders",BASE:String="rbl";
      private var mod:Object,host:Boolean,solo:Boolean,configured:Boolean=false;
      private var links:Dictionary=new Dictionary(),probe:ColdTravelProbe;
      private var phase:String="boot",round:int=0,target:String=BASE,at:int=getTimer(),readyAt:int=0;
      private var requestedWall:Number=0,bootTrip:Boolean=false,peerReady:Boolean=false;
      private var gateLogAt:int=-10000;
      private var localResult:Object,peerResult:Object,cached:Object;
      private var coldWorld:Object,firstLand:Object,baseLand:Object;
      private var keyCode:int=0,inputAt:int=0,inputX:Number=0,inputDirection:int=1;
      private var inputActor:Object,inputCtr:Object,inputEvidence:Object;
      private var baselineAt:int=0,baselineX:Number=0,baselineFrames:int=0;
      private var failed:Boolean=false;

      public function ColdFixedTravelTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();abort();
         });
         addEventListener(Event.ENTER_FRAME,bootstrap);
      }
      private function check(ok:Boolean,label:String):Boolean {
         if(!ok)failed=true;
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"cold-fixed-travel "+label+" round="+round);return ok;
      }
      private function send(op:String,value:Object=null):void {
         if(solo)return;value=value||{};value.type="cold-fixed-travel-test";value.op=op;value.round=round;
         if(host)mod.session.server.broadcast(value);else if(mod.session.link!=null)mod.session.link.send(value);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function stable(id:String):Boolean {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         return w!=null&&g!=null&&w.land!=null&&w.loc!=null&&String(w.game.curLandId)==id&&String(w.land.act.id)==id
            && !mod.game.isTransitioning() && !w.onPause && w.allStat==1 && !w.mm.active
            // Native Ctr.active arms the first mouse-down (Ctr.as:558), not
            // keyboard movement. World clears it on entry; gating on it here
            // would wait forever before the test emits its first input.
            && g.ggControl && !w.pip.noAct && !w.vwait.visible
            && (!w.vblack.visible||w.vblack.alpha<=0)
            && (solo || (mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.session.rooms.entryPending));
      }
      private function traceGate(now:int):void {
         if(now-gateLogAt<10000||!(phase=="boot"||phase=="travel"||phase=="rest"))return;
         gateLogAt=now;
         var w:Object=mod.game.world,g:Object=mod.game.gg,rooms:Object=mod.session.rooms;
         Log.d("COLD TRAVEL GATE "+JSON.stringify({phase:phase,round:round,role:host?"host":"join",solo:solo,
            at:now,wallMs:new Date().time,target:target,bootTrip:bootTrip,peerReady:peerReady,
            curLandId:w.game==null?null:w.game.curLandId,landId:w.land==null?null:w.land.act.id,
            hasLoc:w.loc!=null,transitioning:mod.game.isTransitioning(),onPause:w.onPause,allStat:w.allStat,
            menuActive:w.mm.active,ggControl:g.ggControl,pipNoAct:w.pip.noAct,
            ctrActiveObservedOnly:w.ctr.active,nativeWait:w.vwait.visible,
            blackVisible:w.vblack.visible,blackAlpha:w.vblack.alpha,t_exit:w.t_exit,clickReq:w.clickReq,
            roomsReady:rooms.ready,roomsBusy:rooms.busy,entryPending:rooms.entryPending,
            sawExit:probe.sawExit,bridgeAvailable:probe.bridgeAvailable,bridgeMode:ColdTravelBuildConfig.BRIDGE_MODE}));
      }
      private function validateTarget():Boolean {
         var w:Object=mod.game.world,a:Object=w.game.lands[FIXED],definition:XML;
         var data:Object=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.GameData");
         for each(var row:XML in data.d.land)if(String(row.attribute("id"))==FIXED){definition=row;break;}
         var ok:Boolean=definition!=null&&String(definition.attribute("file"))=="rooms_raiders"
            && definition.attribute("rnd").length()==0&&String(definition.attribute("tip"))=="story"
            && int(definition.attribute("locx"))==0&&int(definition.attribute("locy"))==1
            && a!=null&&a.rnd===false&&a.id==FIXED;
         if(!check(ok,"loaded native GameData confirms fixed raiders, rooms_raiders, entrance 0,1"))return false;
         if(!check(a.land==null&&!a.visited,"target is cold: no constructed Land and never visited"))return false;
         coldWorld=w;baseLand=w.game.lands[BASE].land;
         Log.d("COLD TRAVEL FIXTURE "+JSON.stringify({role:host?"host":"join",solo:solo,
            target:FIXED,roomFile:String(definition.attribute("file")),cold:true,level:w.pers.level,
            visited:a.visited,hasCachedLand:a.land!=null,wallMs:new Date().time,
            requireBridge:ColdTravelBuildConfig.REQUIRE_BRIDGE,bridgeMode:ColdTravelBuildConfig.BRIDGE_MODE,
            bridgeAvailable:probe.bridgeAvailable}));
         if(!check(probe.bridgeAvailable===ColdTravelBuildConfig.REQUIRE_BRIDGE,
            "explicit bridge mode="+ColdTravelBuildConfig.BRIDGE_MODE+" available="+probe.bridgeAvailable))return false;
         return true;
      }
      private function bootstrap(e:Event):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null||mod.session==null)return;
         removeEventListener(Event.ENTER_FRAME,bootstrap);
         solo=mod.config.getValue("autoRole")=="";
         mod.config.setValue("followTeammate","0");
         probe=new ColdTravelProbe(mod,host?"host":"join",solo);
         mod.stage.addEventListener(Event.ENTER_FRAME,tick,false,-2000000001);
         configured=true;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="cold-fixed-travel-test")return;
         if(p.op=="abort"){check(false,"peer aborted");finish();return;}
         if(p.op=="done"){finish();return;}
         if(host&&p.op=="ready"&&phase=="boot") {
            if(!check(p.requireBridge===ColdTravelBuildConfig.REQUIRE_BRIDGE&&p.bridgeMode===ColdTravelBuildConfig.BRIDGE_MODE
               &&p.bridgeAvailable===ColdTravelBuildConfig.REQUIRE_BRIDGE,"peer uses the same explicit bridge qualification")){abort();return;}
            peerReady=true;
         }
         // This message only arms measurement. The joiner never travels from
         // this branch: the production bridge/normal world protocol must do it.
         if(!host&&p.op=="arm"&&(phase=="boot"||phase=="wait")) {
            round=int(p.round);target=String(p.target);begin(Number(p.requestedWall));
         }
         if(host&&p.op=="result"&&int(p.round)==round){peerResult=p.value;compare();}
      }
      private function begin(wall:Number):void {
         phase="travel";at=getTimer();requestedWall=wall;localResult=null;peerResult=null;
         cached=mod.game.world.game.lands[target].land;
         probe.begin(round,target,wall);
         Log.d("COLD TRAVEL ARMED "+JSON.stringify({role:host?"host":"join",round:round,target:target,
            requestedWall:wall,receivedWall:new Date().time,cached:cached!=null}));
      }
      private function depart():void {
         target=round==1?BASE:FIXED;
         mod.game.forceCloseOverlays();mod.game.world.pers.healAll();
         var wall:Number=new Date().time;
         send("arm",{target:target,requestedWall:wall});begin(wall);
         // Do not set crea, manipulate a cache or send production room messages.
         if(round==0)mod.game.world.game.beginMission(target);
         else mod.game.world.game.gotoLand(target);
         check(String(mod.game.world.game.curLandId)==target&&int(mod.game.world.t_exit)>0,
            "native "+(round==0?"beginMission":"gotoLand")+" accepted the trip");
      }
      private function startInputCheck():void {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         var clock:Object=probe.complete();
         check(w===coldWorld,"travel retains the same native World");
         check(w.land.act.rnd===false,"arrived in a fixed native Land");
         if(round==0){check(cached==null,"first arrival did not use a warmed target");firstLand=w.land;}
         else check(cached!=null&&cached===w.land,"cached native Land reused on return/revisit");
         if(round==2)check(firstLand===w.land,"revisit preserves first constructed Land identity");
         if(round==1)check(baseLand===w.land,"return preserves initial base Land identity");
         localResult={round:round,target:target,solo:solo,requestedWall:requestedWall,flagsReadyWall:new Date().time,
            started:at,elapsed:getTimer()-at,at:getTimer(),key:mod.game.roomKey(),x:g.X,y:g.Y,
            width:w.loc.spaceX,height:w.loc.spaceY,seed:0,clock:clock,cachedBefore:cached!=null,
            nativeControl:g.ggControl,pipNoAct:w.pip.noAct,ctrActive:w.ctr.active,
            requireBridge:ColdTravelBuildConfig.REQUIRE_BRIDGE,bridgeMode:ColdTravelBuildConfig.BRIDGE_MODE,
            bridgeAssertionsApplicable:!solo&&ColdTravelBuildConfig.REQUIRE_BRIDGE};
         if(!check(clock.bridgeAvailable===ColdTravelBuildConfig.REQUIRE_BRIDGE,
            "arrival preserves explicitly selected bridge mode")){abort();return;}
         // Confirm the normal input route without moving the spawn point by
         // assignment. One unobstructed native left/right step suffices; the
         // pre-input arrival above remains the entrance comparison sample.
         inputDirection=1;
         if(w.loc.getAbsTile(Number(g.X)+40,Number(g.Y)-20).phis!=0)inputDirection=-1;
         if(!check(w.loc.getAbsTile(Number(g.X)+inputDirection*40,Number(g.Y)-20).phis==0,
            "native entrance has a clear direction for one input response")){abort();return;}
         inputActor=g;inputCtr=w.ctr;baselineX=Number(g.X);baselineAt=getTimer();baselineFrames=0;
         inputEvidence={direction:inputDirection,baseline:[],pressed:[],released:[]};
         localResult.inputEvidence=inputEvidence;
         inputEvidence.baseline.push(inputSample("baseline-start"));phase="input-baseline";
      }
      private function inputSample(kind:String):Object {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         return {kind:kind,wallMs:new Date().time,t:getTimer(),x:Number(g.X),y:Number(g.Y),dx:Number(g.dx),dy:Number(g.dy),
            walk:Number(g.walk),keyLeft:w.ctr.keyLeft,keyRight:w.ctr.keyRight,ctrActiveObservedOnly:w.ctr.active,
            sameActor:g===inputActor,sameCtr:w.ctr===inputCtr};
      }
      private function inputError(label:String):void {
         Log.d("COLD TRAVEL INPUT "+JSON.stringify({round:round,role:host?"host":"join",evidence:inputEvidence}));
         check(false,label);abort();
      }
      private function baselineInput():void {
         var row:Object=inputSample("baseline-frame");inputEvidence.baseline.push(row);
         // No velocity or control field is written. Existing drift or active
         // controls invalidate this fixture rather than counting as response.
         for each(var sample:Object in inputEvidence.baseline) {
            if(!sample.sameActor||!sample.sameCtr||sample.keyLeft!==false||sample.keyRight!==false||sample.walk!=0
               ||!isFinite(sample.dx)||!isFinite(sample.x)) {
               inputError("no-input baseline has invalid identity, motion or unreleased native controls");return;
            }
         }
         // Allow native residual velocity to settle inside the existing input
         // window, retaining every initial sample. Only three consecutive
         // stationary post-update frames qualify; no initial drift is hidden.
         if(Math.abs(row.dx)>.1||(baselineFrames>0&&Math.abs(row.x-baselineX)>.1))baselineFrames=0;
         else {
            if(baselineFrames==0){baselineX=row.x;inputEvidence.stationaryBaselineFromWall=row.wallMs;}
            baselineFrames++;
         }
         if(getTimer()-baselineAt>1000){inputError("no-input baseline exceeded original 1000ms input window");return;}
         if(baselineFrames<3)return;
         check(true,"three native frames establish released controls and no horizontal drift before input");
         inputX=Number(mod.game.gg.X);inputAt=getTimer();keyCode=inputDirection>0?68:65;phase="input";
         inputEvidence.keyCode=keyCode;inputEvidence.dispatchWall=new Date().time;
         inputEvidence.baselineElapsed=getTimer()-baselineAt;
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,keyCode));
         row=inputSample("after-key-down");inputEvidence.pressed.push(row);
         if(!check(row.sameActor&&row.sameCtr&&row.keyLeft===(inputDirection<0)&&row.keyRight===(inputDirection>0),
            "Stage KEY_DOWN reaches the selected native Ctr key and leaves the opposite key released")) {
            inputError("native key-down route failed");return;
         }
      }
      private function releaseKey():void {
         if(keyCode!=0&&mod!=null)mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,keyCode));
         keyCode=0;
      }
      private function completeInput():void {
         localResult.controlResponseWall=new Date().time;
         localResult.controlResponseElapsed=localResult.controlResponseWall-requestedWall;
         localResult.inputResponseMs=getTimer()-inputAt;localResult.inputDisplacement=Number(mod.game.gg.X)-inputX;
         check(true,"native key, walk direction, velocity and displacement agree after a stationary baseline");
         releaseKey();inputEvidence.releaseWall=new Date().time;
         var row:Object=inputSample("after-key-up");inputEvidence.released.push(row);
         if(!check(row.sameActor&&row.sameCtr&&row.keyLeft===false&&row.keyRight===false,
            "Stage KEY_UP clears the actual native Ctr key")){inputError("native key-up route failed");return;}
         phase="input-release";
      }
      private function completeRelease():void {
         var row:Object=inputSample("released-next-native-frame");inputEvidence.released.push(row);
         if(!check(row.sameActor&&row.sameCtr&&row.keyLeft===false&&row.keyRight===false&&row.walk==0,
            "next native frame keeps both movement keys released and consumes the release into walk=0")) {
            inputError("native control release did not persist");return;
         }
         // Native residual velocity after release is recorded, not forced to
         // zero: KEY_UP is not a physics stop command.
         localResult.inputReleaseVerifiedWall=new Date().time;
         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));
         if(host||solo){phase="wait";at=getTimer();compare();}
         else {send("result",{value:localResult});phase="wait";at=getTimer();}
      }
      private function compare():void {
         if(localResult==null||phase!="wait"||(!solo&&peerResult==null))return;
         if(!solo) {
            check(localResult.key==peerResult.key,"both arrivals use the same room key");
            check(localResult.width==peerResult.width&&localResult.height==peerResult.height,"native room dimensions agree");
            var dx:Number=localResult.x-peerResult.x,dy:Number=localResult.y-peerResult.y;
            check(dx*dx+dy*dy<=1,"both pre-input arrivals share the same spawn coordinates, distance="+Math.sqrt(dx*dx+dy*dy));
            check(peerResult.requireBridge===ColdTravelBuildConfig.REQUIRE_BRIDGE&&peerResult.bridgeMode===ColdTravelBuildConfig.BRIDGE_MODE,
               "both results retain the explicit bridge qualification");
            check(localResult.clock.bridgeAvailable===ColdTravelBuildConfig.REQUIRE_BRIDGE
               &&peerResult.clock.bridgeAvailable===ColdTravelBuildConfig.REQUIRE_BRIDGE,"both bridges meet the selected mode; missing candidate bridge cannot skip assertions");
            if(round==0&&ColdTravelBuildConfig.REQUIRE_BRIDGE) {
               check(peerResult.clock.adoptedPlan===true,"required joiner actually adopted the production native plan");
               check(peerResult.clock.constructorBeforeWall>0&&peerResult.clock.constructorBeforeWall<localResult.flagsReadyWall,
                  "join native construction began before host regained control (not exact constructor overlap)");
            }
         }
         Log.d("COLD TRAVEL COMPARISON "+JSON.stringify({host:localResult,join:peerResult,
            teamControlElapsed:solo?localResult.controlResponseElapsed:Math.max(localResult.controlResponseWall,peerResult.controlResponseWall)-requestedWall,
            bridgeQualification:ColdTravelBuildConfig.BRIDGE_MODE,
            adoptApplicability:solo?"not-applicable-solo":(ColdTravelBuildConfig.REQUIRE_BRIDGE?"required":"not-applicable-574D-no-bridge-control"),
            functionalOnly:true,performancePass:false}));
         if(round>=2){send("done");finish();return;}
         round++;phase="rest";at=getTimer();
      }
      private function tick(e:Event):void {
         if(phase=="done")return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         var w:Object=mod.game.world,g:Object=mod.game.gg,now:int=getTimer();
         if(w==null||g==null)return;g.invulner=true;
         traceGate(now);
         if(w.verror.visible){check(false,"native game error: "+w.verror.txt.text);abort();return;}
         // Click the native loading-story prompt through its usual event route.
         // No counter, pause, control or UI visibility field is forced here.
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(now-at>(phase=="boot"?240000:95000)){check(false,"timeout phase="+phase);abort();return;}
         if(solo&&phase=="boot"&&!bootTrip&&stable("begin")) {
            bootTrip=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand(BASE);at=now;return;
         }
         if(phase=="boot"&&stable(BASE)) {
            if(coldWorld==null) {
               if(!validateTarget()){abort();return;}
               // autoGame's opening script may leave a living idle actor's
               // animation override set. Release only that known bootstrap
               // override once, before any timed journey, via native anim().
               if(g.animOff===true&&g.hp>0&&g.sost==1&&!g.pers.dead&&g.work==""&&g.t_work<=0)g.anim();
               check(!g.animOff&&g.sost==1&&!g.pers.dead,"living source ready before measurement");
            }
            if(solo||(host&&peerReady))depart();
            else if(!host&&now-readyAt>500){readyAt=now;send("ready",{
               requireBridge:ColdTravelBuildConfig.REQUIRE_BRIDGE,bridgeMode:ColdTravelBuildConfig.BRIDGE_MODE,bridgeAvailable:probe.bridgeAvailable});}
         } else if(phase=="rest"&&now-at>1000&&stable(round==2?BASE:FIXED))depart();
         else if(phase=="travel"&&probe.sawExit&&stable(target))startInputCheck();
         else if(phase=="input-baseline")baselineInput();
         else if(phase=="input") {
            var row:Object=inputSample("input-native-frame");inputEvidence.pressed.push(row);
            if(!row.sameActor||!row.sameCtr||row.keyLeft!==(inputDirection<0)||row.keyRight!==(inputDirection>0)) {
               inputError("native pressed key state or player identity changed before movement");return;
            }
            if((row.x-inputX)*inputDirection>.1&&row.walk==inputDirection&&row.dx*inputDirection>0)completeInput();
            else if(now-inputAt>1000)inputError("native key produced no matching directional movement within original 1000ms window");
         } else if(phase=="input-release")completeRelease();
      }
      private function abort():void {send("abort");finish();}
      private function finish():void {
         if(phase=="done")return;phase="done";releaseKey();
         removeEventListener(Event.ENTER_FRAME,bootstrap);
         if(configured)mod.stage.removeEventListener(Event.ENTER_FRAME,tick);
         for(var l:Object in links)l.removeEventListener(TcpLink.MESSAGE,receive);
         if(probe!=null)probe.dispose();
         Log.d("COOP EFFECTS DONE cold-fixed-travel "+(host?"host":"join")+" failed="+failed);
      }
   }
}
