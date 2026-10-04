package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Hold a genuine host-requested native exit longer than the old 15s permit. */
   public class SlowTravelTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const TARGET:String="rbl";
      private var timer:Timer=new Timer(100),mod:RConnectMod,host:Boolean;
      private var watched:Dictionary=new Dictionary(),state:String="boot";
      private var at:int=0,bootAt:int=getTimer(),nextReady:int=0;
      private var joinReady:Boolean=false,joinArrived:Boolean=false;
      private var hooked:Boolean=false;
      private var heldWorld:Object,heldAt:int,heldExit:int,rollback:Boolean=false;
      private var unauthorizedRoom:Object,unauthorizedLand:Object;
      private var attemptFrames:int=0;
      private var redirected:Boolean=false,redirectedPeer:Boolean=false;
      private var expectedLand:String=TARGET;

      public function SlowTravelTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();abort();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"slowtravel "+label);}
      private function change(value:String):void {state=value;at=getTimer();Log.d("SLOW TRAVEL "+(host?"host ":"join ")+value);}
      private function send(op:String,data:Object=null):void {
         var msg:Object=data||{};msg.type="slow-travel-test";msg.op=op;
         if(host&&mod.session.server!=null)mod.session.server.broadcast(msg);
         else if(!host&&mod.session.link!=null)mod.session.link.send(msg);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!watched[link]){watched[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function receive(e:NetMessageEvent):void {
         if(e.data==null||e.data.type!="slow-travel-test"||state=="done")return;
         try {
            var op:String=e.data.op;
            if(op=="ready"&&host)joinReady=true;
            else if(op=="arm"&&!host)change("watch-exit");
            else if(op=="released"&&host)change("arriving");
            else if(op=="arrived"&&host)joinArrived=true;
            else if((op=="same-target"||op=="other-target")&&!host)attempt(op);
            else if(op=="same-denied"&&host){check(true,"join rejected reuse of the completed host destination permit");send("other-target");change("wait-other");}
            else if(op=="other-denied"&&host){check(true,"join rejected an unauthorized different destination");startEncounter();}
            else if(op=="encounter"&&!host) {
               mod.game.world.game.triggers["encounter_way"]=0;
               // Relay an actual host snapshot immediately, before its native
               // Encounter runs. This drives the normal public world adapter.
               mod.session.rooms.observeHost(e.data.info);change("encounter");
            }
            else if(op=="encounter-arrived"&&host)redirectedPeer=true;
            else if(op=="redirect-reuse"&&!host){expectedLand="way";attempt(op);}
            else if(op=="redirect-denied"&&host){check(true,"completed redirected exit cannot authorize another same-target trip");send("done");finish();}
            else if(op=="done")finish();
            else if(op=="abort"){check(false,"peer aborted after a recorded native travel failure");finish();}
         }catch(error:Error){check(false,"receive "+error.getStackTrace());abort();}
      }
      private function stable(land:String):Boolean {
         return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning()
            && String(mod.game.readWorldInfo().curLandId)==land;
      }
      private function early(e:Event):void {
         if(state=="done"||mod.game.world==null)return;
         try {
            var w:Object=mod.game.world;
            if(!host&&state=="watch-exit"&&String(w.game.curLandId)==TARGET&&int(w.t_exit)>0&&int(w.t_exit)<95&&!w.onPause) {
               heldWorld=w;heldExit=int(w.t_exit);heldAt=getTimer();rollback=false;w.onPause=true;
               check(heldExit>0&&heldExit<95,"captured the genuine host-authorized native exit at "+heldExit);
               change("holding");
            }
            else if(state=="holding") {
               if(w!==heldWorld||String(w.game.curLandId)!=TARGET||int(w.t_exit)!=heldExit) {
                  if(!rollback)Log.d("SLOW TRAVEL rollback witness elapsed="+(getTimer()-heldAt)+" destination="+w.game.curLandId+" exit="+w.t_exit+" expected="+heldExit);
                  rollback=true;
               }
            }
            else if(state=="same-target"||state=="other-target"||state=="redirect-reuse")attemptFrames++;
            else if(state=="encounter"&&!redirected&&String(w.game.curLandId)=="way") {
               redirected=true;
               check(int(w.t_exit)>0&&int(w.t_exit)<=19,"real native Encounter redirects random_canter to way within the original exit; remaining="+w.t_exit);
            }
         }catch(error:Error){check(false,"early "+error.getStackTrace());abort();}
      }
      private function releaseHold():void {
         // Acquire only while RoomSync is not holding; do not undo a later
         // independent room checkpoint owner during an already failed red run.
         if(heldWorld!=null&&!mod.session.rooms.busy)heldWorld.onPause=false;
         heldWorld=null;
      }
      private function attempt(kind:String):void {
         var w:Object=mod.game.world;
         unauthorizedRoom=mod.game.loc;unauthorizedLand=w.land;attemptFrames=0;
         w.game.gotoLand(kind=="same-target"?TARGET:(kind=="redirect-reuse"?"random_canter":"begin"));
         check(int(w.t_exit)>0,"native unauthorized attempt really began: "+kind);
         change(kind);
      }
      private function startEncounter():void {
         var w:Object=mod.game.world;
         w.game.triggers["encounter_way"]=0;
         w.game.gotoLand("random_canter");
         check(String(w.game.curLandId)=="random_canter"&&int(w.t_exit)>0,"host starts the real native Encounter destination");
         change("encounter");send("encounter",{info:mod.game.readWorldInfo()});
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(state=="done"||mod==null||mod.session==null)return;
         try {
            if(getTimer()-bootAt>280000){check(false,"overall timeout in "+state);abort();return;}
            if(mod.game.world==null||mod.game.gg==null||mod.game.loc==null)return;
            var w:Object=mod.game.world,g:Object=mod.game.gg;
            w.godMode=true;g.invulner=true;g.disabled=true;
            if(!hooked) {
               mod.stage.addEventListener(Event.ENTER_FRAME,early,false,100100,true);hooked=true;
            }
            if(host&&mod.session.server!=null)for each(var p:Object in mod.session.peers)watch(p.link);
            else if(!host)watch(mod.session.link);
            if(state=="boot") {
               w.pip.onoff(-1);w.sats.onoff(-1);
               if(!stable("begin"))return;
               if(!host) {if(getTimer()>=nextReady){send("ready");nextReady=getTimer()+500;}}
               else if(joinReady) {
                  check(!mod.session.pause.policyMenus&&!mod.session.pause.policySats,"cooperative pause switches remain off");
                  send("arm");change("waiting-hold");w.game.gotoLand(TARGET);
                  check(String(w.game.curLandId)==TARGET&&int(w.t_exit)>0,"host starts the real native map trip");
               }
            }
            else if(state=="holding"&&getTimer()-heldAt>=17000) {
               var elapsed:int=getTimer()-heldAt;
               check(elapsed>=17000,"native exit held beyond old permit: "+elapsed+"ms");
               check(!rollback,"authorized destination and native countdown stayed intact for the complete hold");
               releaseHold();
               if(rollback){abort();return;}
               send("released");change("arriving");
            }
            else if(state=="arriving"&&stable(TARGET)) {
               if(!host) {check(true,"joining player completes the delayed native trip and room grant");send("arrived");change("wait-attempt");}
               else if(joinArrived) {check(true,"both players finish the delayed room handoff");send("same-target");change("wait-same");}
            }
            else if((state=="same-target"||state=="other-target"||state=="redirect-reuse")&&attemptFrames>=5&&getTimer()-at>=700) {
               var correct:Boolean=String(w.game.curLandId)==expectedLand&&int(w.t_exit)==0
                  &&mod.game.loc===unauthorizedRoom&&w.land===unauthorizedLand&&stable(expectedLand);
               check(correct,"completed travel permit is revoked; native "+state+" exit is blocked");
               check(!w.verror.visible,"blocked "+state+" causes no native error dialog");
               if(!correct){abort();return;}
               send(state=="same-target"?"same-denied":(state=="redirect-reuse"?"redirect-denied":"other-denied"));change("wait-attempt");
            }
            else if(state=="encounter"&&stable("way")&&redirected) {
               if(!host){check(true,"joining player completes native Encounter redirect without a rollback");send("encounter-arrived");change("wait-attempt");}
               else if(redirectedPeer){check(true,"both players receive the redirected map grant");send("redirect-reuse");change("wait-redirect-denial");}
            }
            if(state!="boot"&&getTimer()-at>65000){check(false,"phase timeout in "+state);abort();}
         }catch(error:Error){check(false,"tick "+error.getStackTrace());abort();}
      }
      private function abort():void {if(state=="done")return;send("abort");finish();}
      private function finish():void {
         if(state=="done")return;releaseHold();state="done";timer.stop();
         if(mod!=null)mod.stage.removeEventListener(Event.ENTER_FRAME,early);
         Log.d("COOP EFFECTS DONE slowtravel "+(host?"host":"join"));
      }
   }
}
