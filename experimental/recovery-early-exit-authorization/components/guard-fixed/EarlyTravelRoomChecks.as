package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.*;
   import rconnect.net.*;
   /** Real RoomSync + Gate, native objects/network are explicit fixtures.
    * No native raster, timing, mod-loader or whole-game qualification. */
   public class EarlyTravelRoomChecks extends Sprite {
      private var rows:Array=[],mods:Array=[];
      private var h:RConnectMod,j:RConnectMod,prep:Object,seal:Object,grant:Object,ht:Object,jt:Object;
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      public function EarlyTravelRoomChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function begin(e:Event):void {
         try{lifecycle();fallbacks();cancellations();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function make(role:String):RConnectMod {
         var m:RConnectMod=new RConnectMod(stage);mods.push(m);m.session.mode=role;
         m.session.pause={paused:false};m.session.hostEarlyTravel=1;
         m.session.rooms=new RoomSync(m.session);m.session.rooms.epoch=1;m.game.roomEpoch=1;
         m.game.mapGeneration.earlyTravelSupported=true;
         m.game.world.game.lands.random_city={id:"random_city",rnd:true};
         m.game.world.grafon={scenePreload:false,sceneCullRender:true,sceneViewReady:function():Boolean{return true;}};
         m.game.world.pip={noAct:false};m.game.gg.ggControl=true;
         m.game.gg.offCount=0;m.game.gg.onCount=0;
         var player:Object=m.game.gg,world:Object=m.game.world;
         player.controlOff=function():void{player.offCount++;player.ggControl=false;world.pip.noAct=true;};
         player.controlOn=function():void{player.onCount++;player.ggControl=true;world.pip.noAct=false;};
         if(role==Session.HOSTING)m.session.peers=[{nativeTravel:1,earlyTravel:1}];
         return m;
      }
      private function clear():void {
         for each(var m:RConnectMod in mods){m.session.mode=Session.OFFLINE;m.session.rooms.reset();}
         mods=[];
      }
      private function last(m:RConnectMod,op:String):Object {
         var found:Object,list:Array=m.session.mode==Session.HOSTING?m.session.outbox:m.session.link.messages;
         for each(var x:Object in list)if(x.op==op)found=x;return found;
      }
      private function count(m:RConnectMod,op:String):int {
         var n:int=0,list:Array=m.session.mode==Session.HOSTING?m.session.outbox:m.session.link.messages;
         for each(var x:Object in list)if(x.op==op)n++;return n;
      }
      private function start(rejectPeerLease:Boolean=false):void {
         clear();h=make(Session.HOSTING);j=make(Session.CONNECTED);
         j.game.mapGeneration.externalAvailable=!rejectPeerLease;
         h.game.world.t_exit=19;
         h.session.rooms.prepareMap({act:{id:"random_city",rnd:true,landStage:0,visited:false},landDifLevel:29,sceneMerged:true},77,true);
         prep=last(h,"prepare");j.session.rooms.handle(prep);
      }
      private function construct(m:RConnectMod,x:Number):Object {
         m.game.completeNative(prep.info);m.game.world.t_exit=19;m.game.transition=true;
         m.game.gg.X=x;m.game.gg.Y=240;
         var ticket:Object=m.session.rooms.openFirstRaster(m.game.world,m.game.loc,m.game.world.grafon);
         m.session.rooms.nativeConstructed(m.game.world.game);return ticket;
      }
      private function build():void {
         start();ht=construct(h,800);seal=last(h,"seal");
         j.session.rooms.handle(seal);jt=construct(j,12);
         h.session.rooms.handle(last(j,"ready"));grant=last(h,"grant");
      }
      private function render():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));stage.dispatchEvent(new Event(Event.RENDER));}
      private function lifecycle():void {
         build();
         check(prep.info.earlyId is String && prep.info.earlyEpoch==1,"explicit two-sided capability creates one travel token");
         check(h.session.rooms.busy && j.session.rooms.busy && h.game.world.onPause && j.game.world.onPause,"both constructed destinations are paused before rendering");
         check(h.game.gg.offCount==1 && j.game.gg.offCount==1,"control closes once per constructed destination");
         check(ht.waiting===false && jt.waiting===true,"only captured host may paint before join restore");
         check(grant.epoch==2 && grant.earlyId==prep.info.earlyId && seal.info.worldReady===true,"early grant uses new epoch and explicit logical-ready seal");
         check(h.game.captures==1,"host freezes exactly one checkpoint for the shared new room");
         h.session.rooms.handle(last(j,"ready"));
         check(h.game.captures==1 && count(h,"grant")==1,"duplicate ready does not recapture or regrant");
         j.game.onRestore=function():void {check(jt.waiting===true && j.game.gg.X==12,"full restore still holds raster before anchor");};
         j.session.rooms.handle(grant);
         check(j.game.restores==1 && j.game.gg.X==800 && j.game.gg.Y==240,"join performs full restore and exact host spawn");
         check(jt.waiting===false && count(j,"ack")==0,"paint is allowed after restore but ACK waits native readiness");
         j.session.rooms.handle(grant);
         check(j.game.restores==1,"duplicate grant never restores twice");
         ht.unpainted=false;jt.unpainted=false;render();
         check(count(j,"ack")==0 && h.session.rooms.busy,"painted destination alone cannot bypass native countdown");
         j.game.world.t_exit=0;j.game.transition=false;render();
         check(count(j,"ack")==1 && j.game.gg.ggControl===false,"join native ready sends one ACK but remains held");
         h.session.rooms.handle(last(j,"ack"));
         check(count(h,"activate")==0 && h.session.rooms.busy,"peer ACK cannot activate host before its native countdown");
         h.game.world.t_exit=0;h.game.transition=false;render();
         check(count(h,"activate")==1 && !h.session.rooms.busy && h.game.gg.onCount==1,"host own ready plus exact ACK activates once");
         j.session.rooms.handle(last(h,"activate"));
         check(!j.session.rooms.busy && j.game.gg.onCount==1 && !j.game.world.pip.noAct,"join activation restores deferred native control");
         check(!h.game.world.onPause && !j.game.world.onPause && h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld,"both worlds become publishable only after activation");
         j.session.rooms.handle(last(h,"activate"));j.session.rooms.handle(grant);
         check(j.game.gg.onCount==1 && j.game.restores==1,"retired early token cannot repeat control or import");
      }
      private function fallbacks():void {
         clear();h=make(Session.HOSTING);h.session.peers[0].earlyTravel=0;
         h.session.rooms.prepareMap({act:{id:"random_city"},landDifLevel:1,sceneMerged:true},77,true);
         check(!h.session.rooms.earlyTravelPending && last(h,"prepare").info.earlyId==null,"one unsupported peer retains ordinary loading");
         clear();h=make(Session.HOSTING);
         h.session.rooms.prepareMap({act:{id:"random_city"},landDifLevel:1,sceneMerged:false},77,true);
         check(!h.session.rooms.earlyTravelPending,"small/nonmerged maps retain original path");
         start();h.game.world.grafon.sceneCullRender=false;
         h.game.completeNative(prep.info);h.game.world.t_exit=19;h.game.transition=true;
         check(h.session.rooms.openFirstRaster(h.game.world,h.game.loc,h.game.world.grafon)==null && !h.session.rooms.earlyTravelPending,"unsupported configuration before construction releases ticket");
         j.session.rooms.handle(last(h,"earlyCancel"));
         check(!j.session.rooms.earlyTravelPending,"peer receives explicit preconstruction optimization cancellation");
         clear();j=make(Session.CONNECTED);j.session.rooms.receivedWelcome(j.game.readWorldInfo());
         check(!j.session.rooms.earlyTravelPending && j.session.rooms.nativeLoadingHold(j.game.world.game)==null,"ordinary room never obtains loading exception");
         start();j.session.rooms.handle(prep);
         check(j.game.startCalls==1,"duplicate prepare does not start a second native load");
         start(true);ht=construct(h,800);h.session.rooms.handle(last(j,"earlyCancel"));
         check(!h.session.rooms.earlyTravelPending && !h.session.rooms.busy && !h.game.world.onPause && ht.waiting===false,
            "peer atomic refusal after host construction but before grant returns to ordinary loading");
         check(h.game.captures==0 && j.game.restores==0 && h.game.mapGeneration.externalReleases==1,
            "pregrant fallback releases exact external lease without checkpoint or partial restore");
      }
      private function cancellations():void {
         build();var oldPause:Boolean=j.game.world.onPause;
         var stale:Object=JSON.parse(JSON.stringify(seal));stale.epoch=1;
         j.session.rooms.handle(stale);
         check(j.game.restores==0 && j.game.world.onPause==oldPause,"old epoch seal cannot release or import");
         stale=JSON.parse(JSON.stringify(grant));stale.earlyId="old:token";j.session.rooms.handle(stale);
         check(j.game.restores==0,"wrong early generation grant rejected");
         j.session.rooms.handle(grant);j.session.rooms.handle({type:"room",op:"earlyCancel",earlyId:prep.info.earlyId});
         check(j.session.rooms.busy && j.game.world.onPause && !j.game.gg.ggControl,"cancellation after restore stays fail-closed");
         j.session.mode=Session.OFFLINE;j.session.rooms.reset();
         check(!j.game.world.onPause && j.game.gg.onCount==1,"explicit disconnect releases only its own live player");
         build();var oldPlayer:Object=j.game.gg;
         j.game.world.game={curLandId:"map",lands:{}};j.game.world.gg={X:1,Y:2};
         j.game.world.onPause=true;
         j.session.rooms.nativeLoadingHold(j.game.world.game);
         check(j.game.world.onPause===true && oldPlayer.onCount==0 && !j.session.rooms.earlyTravelPending,"same World replacement Game never receives old pause/control writes");
         build();j.game.dead=true;j.game.world.t_die=200;
         j.session.rooms.nativeLoadingHold(j.game.world.game);
         check(j.game.gg.onCount==0 && !j.session.rooms.earlyTravelPending,"death retires optimization without reviving control");
         build();j.game.world.comLoad=2;
         j.session.rooms.cancelNativeLoading(j.game.world.game);
         check(j.game.gg.onCount==0 && !j.session.rooms.earlyTravelPending,"load request cancels old native ownership");
         build();j.game.restoreFailure=true;j.session.rooms.handle(grant);
         check(j.session.rooms.busy && jt.waiting===true && count(j,"ack")==0,"restore exception never exposes partial world or ACK");
         start();ht=construct(h,800);j.session.rooms.handle(last(h,"seal"));
         j.game.gg.controlOff=function():void{j.game.gg.offCount++;j.game.gg.ggControl=false;throw new Error("fixture controlOff failure");};
         jt=construct(j,12);
         check(j.session.rooms.busy && jt.waiting===true && j.game.gg.onCount==0,
            "native controlOff exception keeps constructed destination held");
         j.session.mode=Session.OFFLINE;j.session.rooms.reset();
         check(j.game.gg.onCount==1 && !j.game.world.onPause,
            "disconnect compensates deferred exit16 even when controlOff threw");
         clear();
      }
   }
}
