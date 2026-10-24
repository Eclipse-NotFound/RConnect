package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.ui.RoomEntryView;

   public class NativeLoadingUiChecks extends Sprite {
      private var rows:Array=[];
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});}
      public function NativeLoadingUiChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function exercise():void {
         var w:FakeNativeLoadingWorld=new FakeNativeLoadingWorld();
         var owner:Object={},other:Object={},nativeWait:Object=w.vwait;
         var state:Object=w.rconnectLoadingView(owner,true);
         check(state.shown && state.nativeWait===nativeWait && w.vwait.visible,"ordinary entry uses the actual native loading instance");
         check(!w.visual.visible && !w.vfon.visible && !w.vgui.visible && w.vblack.visible,"scene layers yield while original native fade layer remains untouched");
         check(w.nativeShows==0 && w.vwait.skill.currentFrame==7 && w.clickReq==0 && !w.catPause,"ordinary lease does not call native initialization or choose new artwork");
         check(w.gg.ggControl && !w.pip.noAct && !w.onPause && w.t_exit==0,"display lease does not change input, pause or transition clock");
         w.rconnectLoadingView(other,false);
         check(w.vwait.visible && !w.visual.visible,"unrelated cancellation cannot end another request");
         check(w.rconnectLoadingView(other,true).reason=="different-owner","overlapping unowned acquisition is rejected");
         w.rconnectLoadingView(owner,false);
         check(!w.vwait.visible && w.visual.visible && w.vfon.visible && w.vgui.visible && w.vblack.visible,"release restores only fields written by the ordinary lease");
         w.rconnectLoadingView(owner,false);
         check(!w.vwait.visible && w.visual.visible,"duplicate release is inert");

         w=new FakeNativeLoadingWorld();owner={};w.t_exit=21;w.gg.ggControl=false;w.pip.noAct=true;
         check(w.rconnectLoadingView(owner,true).reason=="native-fade" && !w.vwait.visible,"native pre-loading fade remains native-owned");
         w.t_exit=20;w.nativeShow();w.rconnectLoadingView(owner,true);
         check(w.nativeShows==1 && w.vwait.visible && !w.visual.visible,"cross-map native show occurs exactly once");
         w.nativeExit16();
         check(w.t_exit==16 && w.nativeFinishes==1 && w.gg.ggControl && !w.pip.noAct,"native completion executes once and transition is not frozen");
         check(w.vwait.visible && !w.visual.visible && !w.vgui.visible,"only display completion is deferred after native exit16");
         w.t_exit=0;w.rconnectLoadingView(owner,true);w.rconnectLoadingView(owner,false);
         check(w.nativeFinishes==1 && !w.vwait.visible && w.visual.visible,"network completion releases display without replaying native finish");

         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.nativeScene();
         check(w.catPause && w.vscene.visible && !w.visual.visible && !w.vwait.visible,"native same-value visual=false write takes ownership before story begins");
         check(w.rconnectLoadingView(owner,true).reason=="native-story" && w.catPause && w.vscene.visible,"ongoing pending request cannot override later story");
         w.rconnectLoadingView(owner,false);
         check(w.catPause && w.vscene.visible && !w.visual.visible,"late cancellation cannot restore pre-story visibility");
         w.nativeSceneEnd();
         check(!w.catPause && w.visual.visible,"native scene exit retains its own restoration");

         w=new FakeNativeLoadingWorld();owner={};w.clickReq=1;w.vwait.story.visible=true;w.vwait.visible=true;
         check(w.rconnectLoadingView(owner,true).reason=="native-story" && w.clickReq==1 && w.vwait.story.visible,"story click prompt is not reset or covered");
         w.rconnectLoadingView(owner,false);
         check(w.vwait.visible && w.clickReq==1,"release cannot hide pre-existing native story wait");

         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.sats.active=true;
         check(w.rconnectLoadingView(owner,true).reason=="native-overlay" && !w.vwait.visible && w.visual.visible && w.sats.active,"later SATS keeps ownership and is not closed or hidden");
         w.rconnectLoadingView(owner,false);
         check(w.sats.active && !w.onPause && w.gg.ggControl,"lease release does not unlock or cancel SATS");
         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.verror.visible=true;
         check(w.rconnectLoadingView(owner,true).reason=="native-overlay" && w.verror.visible && !w.vwait.visible,"native error display wins over pending loading");
         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.t_die=12;
         check(w.rconnectLoadingView(owner,true).reason=="native-load-or-death" && w.t_die==12 && w.gg.ggControl,"death abort does not rewrite native clock or control");

         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);var previousRoom:Object=w.loc;w.nativeRoom();
         check(w.loc!==previousRoom && w.visual.visible,"new room native writer revokes old-room display fields first");
         check(w.rconnectLoadingView(owner,true).shown && !w.visual.visible,"continuous ordinary crossing can renew display for native destination");
         w.nativeResize(1024,768);w.rconnectLoadingView(owner,true);w.rconnectLoadingView(owner,false);
         check(w.vwait.x==512 && w.vwait.y==384 && w.visual.visible,"resize updates native baseline instead of restoring old coordinates");
         w.rconnectLoadingView(owner,true);w.nativeNewIdentity();
         check(w.rconnectLoadingView(owner,true).reason=="identity-changed" && w.visual.visible && !w.gg.ggControl,"old request cannot claim new game/player identity");
         w.rconnectLoadingView(owner,false);check(w.rconnectLoadingUiFaults==0,"all lifecycle paths retain zero helper faults");

         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.vblack.visible=false;
         w.rconnectLoadingView(owner,false);
         check(!w.vblack.visible,"Camera finishing the native fade is never overwritten by lease cleanup");
         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.nativeMenuNewGame();
         check(w.vwait.visible && w.vwait.progres.text=="加载中" && w.allStat==-1,"native menu-to-newGame same-value wait handoff remains visible");
         w.rconnectLoadingView(owner,false);
         check(w.vwait.visible,"late old-session cancellation cannot hide newGame's native wait");
         w=new FakeNativeLoadingWorld();owner={};w.rconnectLoadingView(owner,true);w.verror=null;
         w.nativeExit16();
         check(w.rconnectLoadingUiFaults==1 && w.nativeFinishes==1 && w.visual.visible,"damaged display reference cannot escape the native exit16 helper");
         check(w.rconnectLoadingView(owner,true).reason=="display-fault","display faults explicitly latch instead of repeatedly reclaiming ownership");

         w=new FakeNativeLoadingWorld();var view:RoomEntryView=new RoomEntryView();
         check(w.nativeShows==0 && !w.vwait.visible,"no request leaves stationary world untouched");
         view.show(w,stage,"");check(view.lastState.shown && w.vwait.visible,"adapter obtains native lease without display children");
         view.clear();check(!w.vwait.visible && w.visual.visible,"adapter clear releases its exact world request");
         view.show({gg:{},game:{}},stage,"");check(!view.lastState.supported && view.lastState.reason=="native-bridge-unavailable","old host is explicitly unsupported without custom fallback");view.clear();
      }
      private function begin(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,begin);
         try{exercise();}catch(error:*){check(false,String(error));}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false,performance_qualified:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
