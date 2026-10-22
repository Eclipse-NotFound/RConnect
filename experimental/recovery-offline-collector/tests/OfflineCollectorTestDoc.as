package {
   import flash.desktop.NativeApplication;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.net.ServerSocket;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Real native firing and public snapshot readback. No private collector access. */
   public final class OfflineCollectorTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const VERSION:String="0.2.24-offline1";
      private static const CASES:Array=["virgin","null","throws","falseValue","truthyString","afterHost"];
      private static const GUN:String="flamer";
      private static const TOTAL_MS:int=240000,BOOT_MS:int=180000,ROUND_MS:int=15000;
      private var mod:RConnectMod,bridge:Object,session:Object,config:Object,world:Object,actor:Object,room:Object,nativeGame:Object;
      private var originalHook:Function,installedHook:Function,saved:Object,inventory:Object;
      private var oldWeapons:Array,privateWeapons:Array,oldChildren:Array,childEntries:Array,oldGun:Object;
      private var throwHook:Function,falseHook:Function,stringHook:Function;
      private var gun:Object,bullet:Object,lane:Object,reservation:ServerSocket,reservationClosed:Boolean=false;
      private var newWeapons:Array=[],nativePoints:Array=[],observations:Array=[],phases:Array=[];
      private var coverage:Object={virgin:false,"null":false,throws:false,falseValue:false,truthyString:false,afterHost:false};
      private var phase:String="boot",round:int=-1,began:int=getTimer(),roundAt:int=began;
      private var enterCount:int=0,roundEnter:int=0,renderCount:int=0,lastNativeEnter:int=-1;
      private var checks:int=0,failed:int=0,stable:int=0,hookCalls:int=0,throwCalls:int=0;
      private var roundHookCalls:int=0,roundThrowCalls:int=0,snapshotCalls:int=0,phaseSnapshots:int=0;
      private var prepared:Boolean=false,bootTravel:Boolean=false,finished:Boolean=false,issued:Boolean=false,captured:Boolean=false;
      private var hostAttempted:Boolean=false,abortReason:String="",actualVersion:String="";
      private var timer:Timer;

      public function OfflineCollectorTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-host-")!=0)return;
         throwHook=function():* {++hookCalls;++throwCalls;throw "RC_COLLECTOR_EXPECTED_SENTINEL";};
         falseHook=function():* {++hookCalls;return false;};
         stringHook=function():* {++hookCalls;return "true";};
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onUncaught);
         addEventListener(Event.ENTER_FRAME,boot);
         timer=new Timer(250);timer.addEventListener(TimerEvent.TIMER,watch);timer.start();
      }
      private function check(ok:Boolean,label:String):void {
         ++checks;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"offline-collector "+label);
         if(!ok)throw new Error(label);
      }
      private function record(label:String,data:Object=null):void {
         if(observations.length>=64)throw new Error("Collector observation limit exceeded");
         observations.push({label:label,phase:phase,round:round,at:getTimer(),enter:enterCount,data:data});
      }
      private static function copyMap(a:Array):Array {
         var out:Array=[];for(var key:String in a)out[key]=a[key];return out;
      }
      private function identity():void {
         if(RConnectMod.instance!==mod || Object(mod.game)!==bridge || Object(mod.session)!==session
            || Object(mod.config)!==config || bridge.world!==world || bridge.gg!==actor
            || bridge.loc!==room || actor.loc!==room || world.game!==nativeGame || actor.invent!==inventory)
            throw new Error("Native collector fixture identity changed");
         if(bridge.offlinePresentationEligibility!==installedHook)throw new Error("Unexpected public hook replacement");
         if(world.verror!=null && world.verror.visible)throw new Error("Native dialog: "+String(world.verror.txt.text));
         if(bridge.isTransitioning() || world.onPause || actor.pers.dead)throw new Error("Native world no longer running normally");
         if(prepared && inventory.weapons!==privateWeapons)throw new Error("Private inventory identity changed");
      }
      private function boot(e:Event):void {
         if(finished)return;
         try {
            deadline();mod=RConnectMod.instance;
            if(mod==null || mod.game==null || mod.session==null || mod.game.gg==null)return;
            var w:Object=mod.game.world;if(w==null || w.game==null)return;
            if(w.verror!=null && w.verror.visible)throw new Error("Native boot dialog: "+String(w.verror.txt.text));
            if(w.clickReq==1) {
               mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
               mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
            }
            if(!bootTravel && String(w.game.curLandId)=="begin" && !mod.game.isTransitioning()
               && int(w.ng_wait)==0 && int(w.comLoad)<0 && w.allStat==1 && !w.onPause) {
               bootTravel=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand("rbl");
               record("native-bootstrap-travel",{target:"rbl"});return;
            }
            if(String(w.game.curLandId)!=="rbl" || w.land==null || w.land.act==null || String(w.land.act.id)!=="rbl"
               || mod.game.isTransitioning() || int(w.ng_wait)>0 || int(w.comLoad)>=0 || w.onPause){stable=0;return;}
            if(++stable<5)return;
            bridge=Object(mod.game);session=Object(mod.session);config=Object(mod.config);
            world=w;nativeGame=w.game;actor=bridge.gg;room=bridge.loc;inventory=actor.invent;
            actualVersion=String(Object(MOD_CLASS)["VERSION"]);
            check(actualVersion===VERSION,"exact offline1 production class");
            check(String(config.getValue("autoRole"))==="","private instance has no automatic network role");
            originalHook=bridge.offlinePresentationEligibility as Function;installedHook=originalHook;
            check(originalHook!=null && session.canSkipOfflinePresentation is Function,"real public eligibility interfaces exist");
            check(session.mode==="offline" && session.server==null && session.link==null
               && session.canSkipOfflinePresentation()===true && originalHook()===true,"real virgin production hook permits skipping");
            check(actor.disabled!==true && actor.trigDis!==true && actor.ggControl===true,"normal native player step is enabled");
            check(inventory.weapons is Array && actor.childObjs is Array,"native inventory and child list exist");
            lane=chooseLane();
            oldGun=actor.currentWeapon;oldWeapons=inventory.weapons;oldChildren=actor.childObjs;childEntries=oldChildren.concat();
            saved={port:config.getValue("port"),x:actor.X,y:actor.Y,cx:actor.celX,cy:actor.celY,side:actor.storona,
               worldX:world.celX,worldY:world.celY,camX:world.cam.celX,camY:world.cam.celY,
               keyAttack:world.ctr.keyAttack,magic:actor.magicWeapon,thrown:actor.throwWeapon,
               fav:inventory.fav,favIds:inventory.favIds,items:inventory.items};
            privateWeapons=copyMap(oldWeapons);inventory.weapons=privateWeapons;prepared=true;
            removeEventListener(Event.ENTER_FRAME,boot);
            mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
            mod.stage.addEventListener(Event.RENDER,render,false,-40000);
            record("prepared",{lane:lane,weapon:GUN,nativeSpeed:40,originalWeapon:oldGun==null?null:String(oldGun.id)});
            startRound(0);
         }catch(error:*){abort(error);}
      }
      /** Read existing terrain only; an unsuitable room fails instead of being rebuilt. */
      private function chooseLane():Object {
         var width:int=int(room.spaceX),height:int=int(room.spaceY);
         for(var y:int=4;y<height-2;y++)for(var x:int=2;x<width-13;x++) {
            var floor:Object=room.space[x][y+1];
            if(floor==null || Number(floor.phis)<1 || floor.fake || floor.door!=null || Number(floor.water)>0)continue;
            var clear:Boolean=true;
            for(var cx:int=x-1;cx<=x+12 && clear;cx++)for(var cy:int=y-3;cy<=y;cy++) {
               var tile:Object=room.space[cx][cy];
               if(tile==null || Number(tile.phis)!=0 || Number(tile.water)>0){clear=false;break;}
            }
            if(!clear)continue;
            var left:Number=x*40-40,right:Number=(x+13)*40,top:Number=(y-3)*40,bottom:Number=(y+1)*40;
            for each(var unit:Object in room.units)if(unit!==actor && int(unit.sost)<3
               && Number(unit.X)>=left-100 && Number(unit.X)<=right+100 && Number(unit.Y)>=top-100 && Number(unit.Y)<=bottom+100)clear=false;
            if(clear)return {x:x*40+20,y:(y+1)*40,left:left,right:right,top:top,bottom:bottom};
         }
         throw new Error("No existing dry enemy-free native flight lane; preparation failure");
      }
      private function installHook(value:Function):void {installedHook=value;bridge.offlinePresentationEligibility=value;}
      private function startHost():void {
         reservation=new ServerSocket();reservation.bind(0,"127.0.0.1");
         var port:int=reservation.localPort;check(reservation.bound && port>0,"owned bind0 host port reserved");
         reservation.close();reservationClosed=true;config.setValue("port",port);
         hostAttempted=true;session.startHost();
         check(session.mode==="hosting" && session.server!=null && session.server.bound
            && session.server.port==port && session.server.clients.length==0 && session.peers.length==0,"real host listening without a peer");
         check(session.canSkipOfflinePresentation()===false && originalHook()===false,"first actual host attempt opens production collection path");
         record("real-host-started",{port:port});
      }
      private function startRound(index:int):void {
         identity();
         if(round>=0){var previous:Object=phases[phases.length-1];previous.endAt=getTimer();previous.endEnter=enterCount;}
         round=index;phase="armed";roundAt=getTimer();roundEnter=0;issued=captured=false;
         bullet=null;nativePoints=[];lastNativeEnter=-1;phaseSnapshots=0;roundHookCalls=hookCalls;roundThrowCalls=throwCalls;
         if(index==0 || index==5)installHook(originalHook);
         else if(index==1)installHook(null);
         else if(index==2)installHook(throwHook);
         else if(index==3)installHook(falseHook);
         else installHook(stringHook);
         if(index==5)startHost();
         actor.changeWeapon("not",true);privateWeapons[GUN]=null;
         gun=inventory.addWeapon(GUN,16777215,200);
         check(gun!=null && newWeapons.indexOf(gun)<0,"fresh native inventory weapon for "+CASES[index]);
         newWeapons.push(gun);actor.changeWeapon(GUN,true);
         check(actor.currentWeapon===gun && gun.owner===actor && gun.loc===room
            && inventory.weapons[GUN]===gun && actor.childObjs.indexOf(gun)>=0,"native equip owns new weapon for "+CASES[index]);
         check(gun.b==null && int(gun.flame)>0 && Number(gun.speed)>0 && gun.vis!=null,"fresh native flame weapon has no old projectile");
         phases.push({name:CASES[index],at:roundAt,enter:enterCount,weapon:GUN,speed:Number(gun.speed),flame:int(gun.flame)});
         record("round-start",{name:CASES[index],hookIsOriginal:installedHook===originalHook,mode:session.mode});
      }
      private function pose():void {
         world.ctr.keyAttack=false;
         actor.setPos(lane.x,lane.y);actor.setVisPos();actor.storona=1;actor.setWeaponPos(gun.tip);
         actor.celX=world.celX=lane.x+400;actor.celY=world.celY=lane.y-100;
         world.cam.celX=int(world.celX*world.cam.scaleV+world.cam.vx);
         world.cam.celY=int(world.celY*world.cam.scaleV+world.cam.vy);
         gun.findCel=false;gun.forceRot=-Math.PI/16;
      }
      private function before(e:Event):void {
         if(finished)return;
         try {
            ++enterCount;++roundEnter;deadline();identity();
            if(round==5 && (session.server==null || !session.server.bound || session.server.clients.length!=0 || session.peers.length!=0))
               throw new Error("Peer-free host changed during collector proof");
            if(actor.currentWeapon!==gun || gun.owner!==actor || inventory.weapons[GUN]!==gun)
               throw new Error("Native current weapon identity changed");
            pose();
            if(phase==="armed" && roundEnter>=5) {
               check(gun.attack()===true,"native attack accepted for "+CASES[round]);issued=true;phase="flight";
               record("native-attack",{name:CASES[round],at:getTimer(),weapon:GUN});
            }else if(phase==="drain" && bullet!=null && bullet.in_chain!==true) {
               if(round+1<CASES.length)startRound(round+1);
               else {
                  for(var key:String in coverage)check(coverage[key]===true,"required collector coverage "+key);
                  check(snapshotCalls==6,"driver took exactly one public snapshot per phase");
                  phase="done";finish();
               }
            }
         }catch(error:*){abort(error);}
      }
      private function render(e:Event):void {
         if(finished || !issued || captured)return;
         try {
            ++renderCount;deadline();identity();
            if(gun.b==null)return;
            if(bullet==null)bullet=gun.b;
            if(gun.b!==bullet || bullet.weap!==gun || bullet.owner!==actor || bullet.loc!==room || Number(bullet.flame)<=0)
               throw new Error("Native projectile identity changed or extra shot occurred");
            if(bullet.in_chain!==true)throw new Error("Native projectile ended before three visible flight frames");
            var view:DisplayObject=bullet.vis as DisplayObject;
            if(view==null || !view.visible || view.stage==null || view.alpha<=0)return;
            if(lastNativeEnter==enterCount)return;
            lastNativeEnter=enterCount;
            if(nativePoints.length>=32)throw new Error("Native sample bound exceeded");
            nativePoints.push({enter:enterCount,render:renderCount,at:getTimer(),x:view.x,y:view.y,rot:view.rotation,
               bulletX:Number(bullet.X),bulletY:Number(bullet.Y),inChain:bullet.in_chain===true});
            if(nativePoints.length>=3 && movingPoints(nativePoints)>=3)evaluate();
         }catch(error:*){abort(error);}
      }
      private static function different(a:Object,b:Object):Boolean {
         return Math.abs(Number(a.x)-Number(b.x))+Math.abs(Number(a.y)-Number(b.y))>0.001;
      }
      private static function movingPoints(list:Array):int {
         var accepted:Array=[];
         for each(var point:Object in list) {
            var distinct:Boolean=true;for each(var previous:Object in accepted)if(!different(point,previous))distinct=false;
            if(distinct)accepted.push(point);
         }
         return accepted.length;
      }
      private function evaluate():void {
         captured=true;++snapshotCalls;++phaseSnapshots;
         // This is the driver's only readSnapshot in this phase. The host's
         // own periodic sends may also capture at stamp=0 in afterHost.
         var snapshot:Object=bridge.readSnapshot();
         check(snapshot!=null && snapshot.weapons is Array,"public snapshot returns native weapon list for "+CASES[round]);
         var selected:Object=null,mains:int=0;
         for each(var entry:Object in snapshot.weapons)if(entry.main===true) {selected=entry;++mains;}
         check(mains==1 && selected!=null && selected.id===GUN && selected.events is Array,"exact current weapon snapshot selected");
         check(selected.events.length==1,"fresh single shot has one event in "+CASES[round]);
         var flight:Object=selected.events[0].flight;
         check(flight!=null && String(flight.cls)===getQualifiedClassName(bullet.vis),"snapshot projectile matches actual native display class");
         var frames:Array=flight.frames is Array?flight.frames:[],matches:Array=[],pairs:int=0;
         for each(var point:Object in frames) {
            if(!isFinite(Number(point.at)) || Number(point.at)<=0 || !isFinite(Number(point.x)) || !isFinite(Number(point.y)))
               throw new Error("Invalid collected native flight frame");
            var found:Boolean=false;
            for each(var nativePoint:Object in nativePoints)if(!different(point,nativePoint)){found=true;break;}
            if(found)matches.push({at:Number(point.at),x:Number(point.x),y:Number(point.y)});
         }
         for(var i:int=0;i<matches.length;i++)for(var j:int=i+1;j<matches.length;j++)
            if(matches[i].at!=matches[j].at && different(matches[i],matches[j]))++pairs;
         check(phaseSnapshots==1 && nativePoints.length>=3 && movingPoints(nativePoints)>=3,"native motion exists independently of snapshot capture");
         if(round==0) {
            check(bridge.offlinePresentationEligibility===originalHook && session.canSkipOfflinePresentation()===true,
               "virgin negative control kept actual production hook");
            check(frames.length==0,"virgin gate leaves no collected flight history despite native motion");
         }else {
            check(frames.length>=2 && pairs>0,"fallback collected distinct timed positions matching native flight in "+CASES[round]);
            if(round>=2 && round<=4)check(hookCalls>roundHookCalls,"substituted hook was actually consulted in "+CASES[round]);
            if(round==2)check(throwCalls>roundThrowCalls,"expected sentinel was thrown inside eligibility hook");
            if(round<5)check(session.canSkipOfflinePresentation()===true && session.mode==="offline","fallback phase did not alter virgin Session");
            else check(installedHook===originalHook && originalHook()===false,"after-host collection uses unchanged original hook");
         }
         // Copy only the evidence fields; capture returns live arrays which can
         // later be extended by native observation. Do not retain those aliases.
         record("collector-proof",JSON.parse(JSON.stringify({name:CASES[round],"native":nativePoints,
            nativeBullet:getQualifiedClassName(bullet),nativeView:getQualifiedClassName(bullet.vis),
            frames:frames,matchedTimedPairs:pairs,matchedFrames:matches.length,driverSnapshots:phaseSnapshots,
            hookCalls:hookCalls-roundHookCalls,throwCalls:throwCalls-roundThrowCalls,
            productMayCapture:round==5,frameHistoryRequiresPositiveStamp:true})));
         coverage[String(CASES[round])]=true;phase="drain";
      }
      private function deadline():void {
         if(getTimer()-began>TOTAL_MS || getTimer()-roundAt>(prepared?ROUND_MS:BOOT_MS))
            throw new Error("Collector absolute/phase timeout: "+phase);
      }
      private function watch(e:TimerEvent):void {
         if(finished)return;try{deadline();if(prepared)identity();}catch(error:*){abort(error);}
      }
      private function onUncaught(e:UncaughtErrorEvent):void {e.preventDefault();abort(e.error);}
      private function abort(error:*):void {
         if(finished)return;abortReason=String(error);++failed;Log.d("COOP FAIL offline-collector "+abortReason);finish();
      }
      private function cleanupFailure(errors:Array,error:*):void {
         ++failed;errors.push(String(error));Log.d("COOP FAIL offline-collector cleanup "+error);
      }
      private function finish():void {
         if(finished)return;finished=true;removeEventListener(Event.ENTER_FRAME,boot);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onUncaught);
         if(timer!=null){timer.stop();timer.removeEventListener(TimerEvent.TIMER,watch);}
         var errors:Array=[],cleanup:Object={errors:errors,hookRestored:false,configRestored:false,
            sessionReleased:false,equipmentRestored:false};
         if(mod!=null && mod.stage!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);
         }
         if(prepared && RConnectMod.instance===mod && Object(mod.game)===bridge && bridge.gg===actor
            && Object(mod.session)===session && Object(mod.config)===config && actor.invent===inventory) {
            try {
               bridge.offlinePresentationEligibility=originalHook;installedHook=originalHook;
               cleanup.hookRestored=bridge.offlinePresentationEligibility===originalHook;
            }catch(hookError:*){cleanupFailure(errors,hookError);}
            try {
               session.leave();cleanup.sessionReleased=session.mode==="offline" && session.server==null && session.link==null;
               if(session.canSkipOfflinePresentation()!==(!hostAttempted))throw new Error("Session history changed during cleanup");
            }catch(sessionError:*){cleanupFailure(errors,sessionError);}
            try {
               actor.changeWeapon("not",true);inventory.weapons=oldWeapons;
               actor.changeWeapon(oldGun==null?"not":String(oldGun.id),true);
               var childrenOK:Boolean=actor.childObjs===oldChildren && actor.childObjs.length==childEntries.length;
               for(var i:int=0;i<childEntries.length;i++)if(actor.childObjs[i]!==childEntries[i])childrenOK=false;
               cleanup.equipmentRestored=inventory.weapons===oldWeapons && actor.currentWeapon===oldGun && childrenOK
                  && actor.magicWeapon===saved.magic && actor.throwWeapon===saved.thrown
                  && inventory.fav===saved.fav && inventory.favIds===saved.favIds && inventory.items===saved.items;
               if(!cleanup.equipmentRestored)throw new Error("Original inventory/equipped objects were not restored");
               actor.setPos(saved.x,saved.y);actor.setVisPos();actor.storona=saved.side;
               actor.celX=saved.cx;actor.celY=saved.cy;world.celX=saved.worldX;world.celY=saved.worldY;
               world.cam.celX=saved.camX;world.cam.celY=saved.camY;world.ctr.keyAttack=saved.keyAttack;
            }catch(equipmentError:*){cleanupFailure(errors,equipmentError);}
            try {
               config.setValue("port",saved.port);cleanup.configRestored=config.getValue("port")===saved.port;
            }catch(configError:*){cleanupFailure(errors,configError);}
         }else if(prepared)cleanupFailure(errors,"Native cleanup ownership identity no longer matches");
         try {
            if(reservation!=null && !reservationClosed && reservation.bound){reservation.close();reservationClosed=true;}
         }catch(socketError:*){cleanupFailure(errors,socketError);}
         if(prepared && (!cleanup.hookRestored || !cleanup.configRestored || !cleanup.sessionReleased || !cleanup.equipmentRestored))
            cleanupFailure(errors,"Required cleanup confirmation missing");
         if(phases.length>0){var last:Object=phases[phases.length-1];last.endAt=getTimer();last.endEnter=enterCount;}
         var complete:Boolean=phase==="done" && failed==0;
         Log.d("OFFLINE COLLECTOR RESULT "+JSON.stringify({passed:complete,checks:checks,failed:failed,version:actualVersion,
            phase:phase,abortReason:abortReason,applicationId:NativeApplication.nativeApplication.applicationID,
            elapsedMs:getTimer()-began,enterCallbacks:enterCount,renderCallbacks:renderCount,
            driverSnapshotCalls:snapshotCalls,observations:observations,phases:phases,coverage:coverage,cleanup:cleanup,
            collectorExecutionQualified:complete,collectorQualifiedScope:"native player projectile frame history only",
            nativeVisualEquivalenceQualified:false,bodyEffectsQualified:false,twoGameConnectionQualified:false,
            performanceQualified:false,hostAttempted:hostAttempted,expectedHookThrows:throwCalls}));
         Log.d("COOP EFFECTS DONE offline-collector");
      }
   }
}
