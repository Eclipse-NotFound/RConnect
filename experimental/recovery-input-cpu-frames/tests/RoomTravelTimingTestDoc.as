package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.KeyboardEvent;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Same native Pip travel sequence offline and over TCP. Timing includes
    * native transition, synchronization, final placement and return of control. */
   public class RoomTravelTimingTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,solo:Boolean,links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,target:String="rbl";
      private var peer:Object,reported:Boolean=false,bootNotice:int=0,configured:Boolean=false;
      private var exitAt:int=-1,exitDone:int=-1,coverMs:int=0,pausedMs:int=0,lastFrame:int=0;
      private var localResult:Object;
      private var rasterProbe:FirstRasterSceneProbe,livingPrepared:Boolean=false,seedGateIntent:Object;
      private var requestedWall:Number=0,keyCode:int=0,inputAt:int=0,inputX:Number=0,inputDirection:int=1;
      private var inputActor:Object,inputCtr:Object,inputEvidence:Object;
      private var baselineAt:int=0,baselineX:Number=0,baselineFrames:int=0;
      private var soloBootTravel:Boolean=false;
      // BEGIN EXTERNAL INPUT CPU
      private var inputProfile:RoomInputCpuProfile;
      // END EXTERNAL INPUT CPU
      private var sceneClass:Object;
      private var metrics:A22RoomMetrics;
      private var landClass:Object,originalSeed:Function,timingSeed:Function;
      private static const MAP_SEED:uint=1380142925;
      protected function merged():Boolean{return false;}
      public function RoomTravelTimingTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;addEventListener(Event.ENTER_FRAME,tick);
      }
      private function check(ok:Boolean,label:String):Boolean {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"travel-timing "+label+" round="+round);return ok;}
      private function stable(id:String):Boolean {
         var w:Object=mod.game.world;
         return w!=null && w.loc!=null && w.land!=null && String(w.game.curLandId)==id && String(w.land.act.id)==id
            && !mod.game.isTransitioning() && (solo || (mod.session.rooms.ready && !mod.session.rooms.busy))
            && !mod.session.rooms.entryPending && !w.onPause && w.allStat==1
            && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function send(op:String,value:Object=null):void {
         if(solo)return;
         value=value||{};value.type="travel-timing-test";value.op=op;value.round=round;
         if(host)mod.session.server.broadcast(value);else mod.session.link.send(value);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.watch(link);
      // END EXTERNAL INPUT CPU
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="travel-timing-test")return;
         if(p.op=="done"){finish();return;}
         if(host && p.op=="ready" && phase=="boot"){if(livingPrepared)depart();return;}
         if(!host && p.op=="depart") {round=int(p.round);target=String(p.target);begin(Number(p.requestedWall));}
         if(host && p.op=="result" && int(p.round)==round){peer=p.value;if(localResult!=null)compare();}
      }
      private function begin(wall:Number=0):void {
         requestedWall=wall>0?wall:new Date().time;
         rasterProbe.begin(seedGateIntent.expectSeedTicket && !solo && !host && target=="random_mane");
         phase="travel";at=getTimer();lastFrame=at;exitAt=exitDone=-1;coverMs=pausedMs=0;
         localResult=null;reported=false;peer=null;
         Log.d("TRAVEL CLOCK "+JSON.stringify({started:at,round:round,target:target}));
      }
      private function depart():void {
         target=round%2==0?"random_mane":"rbl";
         var wall:Number=new Date().time;send("depart",{target:target,requestedWall:wall});begin(wall);mod.game.forceCloseOverlays();mod.game.world.pers.healAll();
         if(round==0)mod.game.world.game.beginMission(target);
         else mod.game.world.game.gotoLand(target);
      }
      private function result():Object {
         var w:Object=mod.game.world,info:Object=mod.game.readWorldInfo();
         var actual:Boolean=false;
         try {actual=w.grafon.sceneNativeCall("state",[w.land])!=null;}catch(ignored:*){}
         if(target=="random_mane") {
            check(Number(info.layoutSeed)==MAP_SEED,"timing uses the same native generation seed");
            check(actual==merged(),"requested scene mode matches the native constructed world");
            if(merged())check(w.loc.spaceX>48 || w.loc.spaceY>25,"native merged scene is actually larger than one ordinary room");
         }
         check(w.gg.ggControl && !w.pip.noAct,"native player controls are restored");
         return {round:round,at:getTimer(),started:at,elapsed:getTimer()-at,exitStart:exitAt<0?-1:exitAt-at,
            exitEnd:exitDone<0?-1:exitDone-at,cover:coverMs,paused:pausedMs,solo:solo,
            x:Number(w.gg.X),y:Number(w.gg.Y),key:mod.game.roomKey(),width:w.loc.spaceX,height:w.loc.spaceY,
            seed:info.layoutSeed,units:w.loc.units.length,merged:merged(),actualMerged:actual,target:target};
      }
      private function compare():void {
         if(localResult==null || phase!="wait" || (!solo && peer==null))return;
         if(!solo) {
            check(localResult.key==peer.key,"shared travel finishes in the same room");
            check(localResult.width==peer.width && localResult.height==peer.height,"both native room dimensions agree");
            check(localResult.seed==peer.seed,"expedition seed agrees");
            var dx:Number=localResult.x-peer.x,dy:Number=localResult.y-peer.y;
            check(dx*dx+dy*dy<=80*80,"both arrivals share one entrance, distance="+Math.sqrt(dx*dx+dy*dy));
         }
         Log.d("TRAVEL COMPARISON "+JSON.stringify({host:localResult,join:peer}));
         if(round>=2){send("done");finish();return;}
         round++;phase="rest";at=getTimer();
      }
      private function tick(e:Event):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null)return;
         if(metrics==null)metrics=new A22RoomMetrics(mod);
         solo=mod.config.getValue("autoRole")=="";
         if(!configured) {
            configured=true;
            try{seedGateIntent=SeedGateNativeIntent.read();Log.d("SEED GATE INTENT "+JSON.stringify(seedGateIntent));}
            catch(intentError:Error){check(false,"explicit seed gate intent: "+intentError);finish();return;}
            mod.config.setValue("followTeammate","0");
            var sceneConfigured:Boolean=false;
            try {
               var nativeMain:MainFE=mod.game.main as MainFE;
               for(var key:Object in nativeMain.modEntryByLoader) {
                  var loader:Loader=key as Loader;
                  if(loader==null || !loader.contentLoaderInfo.applicationDomain.hasDefinition("ContinuousSceneMod"))continue;
                  var cls:Object=loader.contentLoaderInfo.applicationDomain.getDefinition("ContinuousSceneMod");
                  sceneClass=cls;
                  cls.nativeEnabled=host&&merged();
                  sceneConfigured=Boolean(cls.nativeEnabled)==(host&&merged());break;
               }
            }catch(error:*){Log.d("TRAVEL CONFIG ERROR "+error);}
            check(sceneConfigured,"native scene preference was explicitly configured");
            // Control only this isolated benchmark's random input. Keep native
            // generation and the production prepare/adopt path; the separate
            // map suite still exercises the unmodified random seed policy.
            landClass=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
            originalSeed=landClass.rconnectSeedSource;
            timingSeed=function(land:Object):uint {
               if(!solo && !host)return originalSeed(land);
               if(!solo && host)Object(mod.session.rooms).prepareMap(land,MAP_SEED,true);
               return MAP_SEED;
            };
            landClass.rconnectSeedSource=timingSeed;
            rasterProbe=new FirstRasterSceneProbe(mod);
      // BEGIN EXTERNAL INPUT CPU
            if(!host&&!solo)inputProfile=new RoomInputCpuProfile(mod.stage,
               function():Boolean{return round==0 && phase=="travel" && target=="random_mane";},
               function():Object {var w:Object=mod.game.world,r:Object=mod.session.rooms;
                  return {phase:phase,round:round,ready:r.ready,busy:r.busy,cover:r.entryPending,
                     pause:w.onPause,exit:w.t_exit,term:r.term,epoch:r.epoch};});
      // END EXTERNAL INPUT CPU
            Log.d("TRAVEL CONFIG "+JSON.stringify({host:host,solo:solo,merged:merged()}));
         }
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         rasterProbe.sample();
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.frame();
      // END EXTERNAL INPUT CPU
         var w:Object=mod.game.world,now:int=getTimer();mod.game.gg.invulner=true;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         // Production autoTravelLand only runs while hosting. The offline
         // control therefore performs the same native setup trip explicitly.
         if(solo && phase=="boot" && !soloBootTravel && stable("begin")) {
            soloBootTravel=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand("rbl");at=now;
         }
         if(now-at>(phase=="boot"?240000:95000)){check(false,"timeout phase="+phase);send("done");finish();return;}
         if(phase=="boot" && stable("rbl")) {
            if(!livingPrepared) {
               livingPrepared=true;var actor:Object=mod.game.gg;
               Log.d("SCENE INPUT BOOT "+JSON.stringify({animOff:actor.animOff,hp:actor.hp,sost:actor.sost,t_die:w.t_die,dead:actor.pers.dead,work:actor.work,t_work:actor.t_work}));
               if(actor.animOff===true&&actor.hp>0&&actor.sost==1&&!actor.pers.dead&&actor.work==""&&actor.t_work<=0)actor.anim();
               if(!check(!actor.animOff&&actor.hp>0&&actor.sost==1&&!actor.pers.dead,"living native source is ready before input measurement")){abort();return;}
            }
            if(solo)depart();
            else if(!host && now-bootNotice>500){bootNotice=now;send("ready");}
         }else if(phase=="rest" && now-at>1000)depart();
         else if(phase=="travel") {
            if(int(w.t_exit)>0 && exitAt<0)exitAt=now;
            if(int(w.t_exit)==0 && exitAt>=0 && exitDone<0)exitDone=now;
            if(mod.session.rooms.entryPending)coverMs+=now-lastFrame;
            if(w.onPause)pausedMs+=now-lastFrame;
            lastFrame=now;
            if(!reported && exitAt>=0 && stable(target)) {
               reported=true;localResult=result();startInputCheck();
            }
         }else if(phase=="input-baseline")baselineInput();
         else if(phase=="input") {
            var row:Object=inputSample("input-native-frame");inputEvidence.pressed.push(row);
            if(!row.sameActor||!row.sameCtr||row.keyLeft!==(inputDirection<0)||row.keyRight!==(inputDirection>0)) {
               inputError("native pressed key state or player identity changed before movement");return;
            }
            if((row.x-inputX)*inputDirection>.1&&row.walk==inputDirection&&row.dx*inputDirection>0)completeInput();
            else if(now-inputAt>1000)inputError("native key produced no matching directional movement within original 1000ms window");
         }else if(phase=="input-release")completeRelease();
      }
      private function startInputCheck():void {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         localResult.flagsReadyWall=new Date().time;localResult.requestedWall=requestedWall;localResult.seedGateIntent=seedGateIntent;
         localResult.rasterEvidence=rasterProbe.finish();
         if(!check(localResult.rasterEvidence.passed,"expected production first-raster ticket was observed and really finished")){abort();return;}

         inputDirection=1;
         if(w.loc.getAbsTile(Number(g.X)+40,Number(g.Y)-20).phis!=0)inputDirection=-1;
         if(!check(w.loc.getAbsTile(Number(g.X)+inputDirection*40,Number(g.Y)-20).phis==0,
            "native entrance has a clear direction for one input response")){abort();return;}
         inputActor=g;inputCtr=w.ctr;baselineX=Number(g.X);baselineAt=getTimer();baselineFrames=0;
         inputEvidence={direction:inputDirection,baseline:[],pressed:[],released:[]};
         localResult.inputEvidence=inputEvidence;
         inputEvidence.baseline.push(inputSample("baseline-start"));phase="input-baseline";
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.mark("baseline-start",baselineAt);
      // END EXTERNAL INPUT CPU
      }
      private function inputSample(kind:String):Object {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         return {kind:kind,wallMs:new Date().time,t:getTimer(),x:Number(g.X),y:Number(g.Y),dx:Number(g.dx),dy:Number(g.dy),
            walk:Number(g.walk),keyLeft:w.ctr.keyLeft,keyRight:w.ctr.keyRight,ctrActiveObservedOnly:w.ctr.active,
            sameActor:g===inputActor,sameCtr:w.ctr===inputCtr};
      }
      private function inputError(label:String):void {
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.stop("input-failure");
      // END EXTERNAL INPUT CPU
         Log.d("SCENE TRAVEL INPUT "+JSON.stringify({round:round,role:host?"host":"join",evidence:inputEvidence}));
         check(false,label);abort();
      }
      private function baselineInput():void {
         var row:Object=inputSample("baseline-frame");inputEvidence.baseline.push(row);
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.mark("baseline-frame",int(row.t));
      // END EXTERNAL INPUT CPU
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
         check(true,"native travel and input restoration finished");
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null && round==0)inputProfile.stop("round0-input-complete");
      // END EXTERNAL INPUT CPU
         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));
         if(host||solo){phase="wait";at=getTimer();compare();}
         else {send("result",{value:localResult});phase="wait";at=getTimer();}
      }
      private function abort():void {send("done");finish();}
      private function finish():void {
         if(phase=="done")return;phase="done";releaseKey();if(rasterProbe!=null)rasterProbe.dispose();removeEventListener(Event.ENTER_FRAME,tick);
         if(metrics!=null)metrics.finish();
      // BEGIN EXTERNAL INPUT CPU
         if(inputProfile!=null)inputProfile.finish();
      // END EXTERNAL INPUT CPU
         if(landClass!=null && landClass.rconnectSeedSource===timingSeed)landClass.rconnectSeedSource=originalSeed;
         if(!host && !solo && sceneClass!=null) {
            mod.session.leave();
            check(sceneClass.nativeEnabled===false,"disconnect restores the joiner's original scene preference");
         }
         Log.d("COOP EFFECTS DONE travel-timing "+(host?"host":"join"));
      }
   }
}
