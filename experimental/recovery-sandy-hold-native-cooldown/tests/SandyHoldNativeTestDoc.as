package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Actual 003 Sandevistan + early2 MapGeneration; isolated cooldown=120, unique native AIR world.
    * No private Sand fields, test-state injection, clock/physics writes or direct startSandy. */
   public final class SandyHoldNativeTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const KEY:uint=220;
      private static const HOLD_FRAMES:int=12;
      private var mod:RConnectMod,carrier:Object,map:Object,world:Object,nativeGame:Object,actor:Object;
      private var phase:String="boot",at:int=getTimer(),frames:int=0,totalFrames:int=0;
      private var checks:int=0,failed:int=0,finished:Boolean=false,bootTravel:Boolean=false;
      private var observations:Array=[],keyEvents:Array=[],initial:Object,holdState:Object,holdControls:Object;
      private var activeStart:Number=0,replaySeen:Boolean=false,secondActive:Boolean=false;
      private var directOwner:Object={},directId:String="",leaseId:String="native-sandy-lifecycle";
      private var leaseHeld:Boolean=false;
      private var cooldownPrevious:Number=0,cooldownAdvanced:Boolean=false;

      public function SandyHoldNativeTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-host-")!=0)return;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         addEventListener(Event.ENTER_FRAME,tick);
      }
      private function ensure(ok:Boolean,label:String):void {
         ++checks;if(!ok)++failed;
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"sandy-native "+label);
         if(!ok)throw new Error(label);
      }
      private function controls():Object {
         return {paused:world.onPause,ggControl:actor.ggControl,noAct:world.pip.noAct,
            allStat:world.allStat,tExit:world.t_exit};
      }
      private function equalControls(a:Object,b:Object):Boolean {
         return a.paused===b.paused && a.ggControl===b.ggControl && a.noAct===b.noAct
            && a.allStat===b.allStat && a.tExit===b.tExit;
      }
      private function query():Object {
         var state:Object=carrier.query(world,nativeGame);
         if(state==null || state.version!==1 || state.contract!=="sandy-travel-hold/1")
            throw new Error("Actual carrier query is unavailable or changed");
         return state;
      }
      private function sameCounters(a:Object,b:Object):Boolean {
         return a.sandyLeft===b.sandyLeft && a.cooldownLeft===b.cooldownLeft
            && a.replayIndex===b.replayIndex && a.enemyEnabled===b.enemyEnabled && a.debugTest===b.debugTest;
      }
      private function note(label:String,state:Object=null):void {
         if(observations.length>=96)throw new Error("Bounded observation capacity exhausted");
         var row:Object={label:label,at:getTimer(),frame:totalFrames,phase:phase,phaseFrame:frames};
         if(state!=null)row.state={phase:state.phase,held:state.held,sandyLeft:state.sandyLeft,
            cooldownLeft:state.cooldownLeft,replayIndex:state.replayIndex,enemyEnabled:state.enemyEnabled,debugTest:state.debugTest};
         if(world!=null)row.controls=controls();
         observations.push(row);
      }
      private function change(next:String):void {phase=next;frames=0;at=getTimer();note(next,carrier==null?null:query());}
      private function down():void {
         keyEvents.push({kind:"down",at:getTimer(),frame:totalFrames,phase:phase});
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,KEY));
      }
      private function up():void {
         if(mod==null)return;
         keyEvents.push({kind:"up",at:getTimer(),frame:totalFrames,phase:phase});
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,KEY));
      }
      private function tap():void {down();up();}
      private function denyDuring(expected:String):void {
         var before:Object=query(),flags:Object=controls();
         ensure(before.phase===expected && before.held===false,"real "+expected+" precedes refusal");
         directId="native-sandy-deny-"+expected;
         var direct:Boolean=carrier.acquire(directOwner,world,nativeGame,directId)===true;
         ensure(!direct,"real carrier atomically refuses "+expected);
         directId="";
         ensure(map.acquireEarly(leaseId)===false,"real MapGeneration refuses "+expected);
         var after:Object=query();
         ensure(after.phase===before.phase && after.held===false && sameCounters(before,after)
            && equalControls(flags,controls()),"refusal leaves actual counters and controls unchanged");
         note(expected+"-refused",after);
      }
      private function stable(id:String):Boolean {
         var w:Object=mod.game.world;
         return w!=null && w.loc!=null && w.game!=null && String(w.game.curLandId)==id
            && !mod.game.isTransitioning() && !w.onPause && w.allStat==1
            && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function prepare():Boolean {
         mod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null)return false;
         var w:Object=mod.game.world;
         if(w.clickReq==1) {
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));
         }
         if(!bootTravel && stable("begin")) {
            bootTravel=true;mod.game.forceCloseOverlays();w.pers.healAll();w.game.gotoLand("rbl");
         }
         if(!stable("rbl"))return false;
         ensure(mod.config.getValue("autoRole")=="","single isolated native world has no concurrent peer driver");
         world=w;nativeGame=w.game;actor=mod.game.gg;map=Object(mod.game).mapGeneration;
         note("living-before");
         Log.d("SANDY HOLD BOOT "+JSON.stringify({animOff:actor.animOff,hp:actor.hp,sost:actor.sost,
            t_die:w.t_die,dead:actor.pers.dead,work:actor.work,t_work:actor.t_work}));
         if(actor.animOff===true && actor.hp>0 && actor.sost==1 && !actor.pers.dead && actor.work=="" && actor.t_work<=0)actor.anim();
         ensure(!actor.animOff && actor.hp>0 && actor.sost==1 && !actor.pers.dead,"living native actor is ready; no dead actor revival");
         carrier=mod.game.main.getChildByName("SandevistanTravelHoldV1");
         ensure(carrier!=null && carrier.version===1 && carrier.contract==="sandy-travel-hold/1","real A travel-hold carrier is loaded");
         ensure(map!=null && map.earlyTravelSupported===true,"exact early MapGeneration is available");
         initial=query();
         ensure(initial.phase==="idle" && initial.held===false && initial.debugTest===false && initial.cooldownLeft<=0,"idle unheld real Sand accepts native activation");
         ensure(actor.ggControl===true && world.pip.noAct===false,"native gameplay controls are available");
         mod.stage.focus=null;
         tap();
         var state:Object=query();
         ensure(state.phase==="active" && state.sandyLeft>0,"real Stage key down/up activates Sand");
         activeStart=state.sandyLeft;change("active");return true;
      }
      private function tick(e:Event):void {
         if(finished)return;
         ++totalFrames;++frames;
         try {
            if(getTimer()-at>(phase=="boot"?240000:60000))throw new Error("Native lifecycle timeout "+phase);
            if(phase=="boot"){prepare();return;}
            ensureIdentity();
            var state:Object=query();
            if(phase=="active") {
               if(frames<8)return;
               ensure(state.phase==="active" && state.sandyLeft<activeStart,"real active counter advances before any hold");
               denyDuring("active");tap();state=query();
               ensure(state.phase==="replay","second real key down/up enters replay");
               replaySeen=true;denyDuring("replay");change("replay");
            }else if(phase=="replay") {
               if(state.phase!=="idle")return;
               ensure(state.held===false && state.cooldownLeft>0 && state.cooldownLeft<=120,"real replay naturally finishes with the pinned nonzero cooldown");
               holdControls=controls();
               leaseHeld=map.acquireEarly(leaseId)===true;
               ensure(leaseHeld,"real MapGeneration acquires idle carrier");
               holdState=query();
               ensure(holdState.held===true && holdState.phase==="idle" && equalControls(holdControls,controls()),"acquisition changes only the real carrier permit");
               ensure(map.acquireEarly(leaseId)===true,"same production lease is idempotent");
               ensure(map.releaseEarly(leaseId+"-other")===false && query().held===true,"wrong production ticket cannot release hold");
               change("held");
            }else if(phase=="held") {
               if(frames==2 || frames==5)down();
               if(frames==7)up();
               state=query();note("held-frame",state);
               ensure(state.held===true && state.phase==="idle" && sameCounters(holdState,state)
                  && equalControls(holdControls,controls()),"held frame "+frames+" preserves public Sand counters and native controls");
               if(frames<HOLD_FRAMES)return;
               ensure(map.releaseEarly(leaseId)===true,"correct production release succeeds after twelve native ENTER callbacks");
               leaseHeld=false;state=query();
               ensure(state.held===false && state.phase==="idle" && sameCounters(holdState,state)
                  && equalControls(holdControls,controls()),"release does not rewrite gameplay state");
               cooldownPrevious=state.cooldownLeft;change("cooldown");
            }else if(phase=="cooldown") {
               if(state.phase!=="idle" || state.held!==false || state.cooldownLeft<0 || state.cooldownLeft>cooldownPrevious)
                  throw new Error("Released cooldown changed phase, held state or monotonic direction");
               cooldownPrevious=state.cooldownLeft;
               if(frames==8) {
                  ensure(state.cooldownLeft>0 && state.cooldownLeft<holdState.cooldownLeft,
                     "real nonzero cooldown decreases after release under native ENTER callbacks");
                  cooldownAdvanced=true;note("cooldown-progress",state);
               }
               if(state.cooldownLeft>0)return;
               ensure(cooldownAdvanced && equalControls(holdControls,controls()),
                  "real cooldown naturally reaches zero with unchanged native controls");
               note("cooldown-zero",state);tap();state=query();
               ensure(state.phase==="active" && state.sandyLeft>0,"same native key activates after held KEY_UP and release");
               secondActive=true;activeStart=state.sandyLeft;change("active-after-release");
            }else if(phase=="active-after-release") {
               if(frames<8)return;
               ensure(state.phase==="active" && state.sandyLeft<activeStart,"actual Sand advances again after release");
               tap();state=query();ensure(state.phase==="replay","post-release real key toggles into replay");change("final-replay");
            }else if(phase=="final-replay" && state.phase==="idle") {
               ensure(state.held===false && replaySeen && secondActive,"both real active/replay cycles finish without a leaked permit");
               ensure(actor.ggControl===true && world.pip.noAct===false && !world.onPause,"native controls and pause restore after final replay");
               note("finished",state);finish();
            }
         }catch(error:*) {
            if(failed==0){++failed;Log.d("COOP FAIL sandy-native "+error);}
            finish();
         }
      }
      private function ensureIdentity():void {
         if(mod.game.world!==world || world.game!==nativeGame || mod.game.gg!==actor)
            throw new Error("Native World/Game/player changed during lifecycle");
      }
      private function uncaught(e:UncaughtErrorEvent):void {
         ++failed;Log.d("COOP FAIL sandy-native uncaught "+e.error);e.preventDefault();finish();
      }
      private function finish():void {
         if(finished)return;finished=true;up();removeEventListener(Event.ENTER_FRAME,tick);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         var cleanup:Object={leaseHeldBefore:leaseHeld,directId:directId};
         try {
            if(directId!="")cleanup.directReleased=carrier.release(directOwner,directId);
            if(leaseHeld)cleanup.productionReleased=map.releaseEarly(leaseId);
            if(carrier!=null)cleanup.final=query();
         }catch(error:*) {++failed;cleanup.error=String(error);Log.d("COOP FAIL sandy-native cleanup "+error);}
         Log.d("SANDY HOLD RESULT "+JSON.stringify({passed:failed==0,checks:checks,failed:failed,
            observations:observations,keyEvents:keyEvents,cleanup:cleanup,holdFrames:HOLD_FRAMES,keyboardCode:KEY,
            functionOnly:true,performanceQualified:false,travelFallbackQualified:false,
            enemyManualStepQualified:false,cooldownFreezeQualified:failed==0 && cooldownAdvanced,cooldownAdvanced:cooldownAdvanced}));
         Log.d("COOP EFFECTS DONE sandy-native");
      }
   }
}
