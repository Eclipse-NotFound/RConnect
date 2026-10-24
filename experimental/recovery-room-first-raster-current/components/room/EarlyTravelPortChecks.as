package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.*;
   import rconnect.game.GameBridge;

   /** Incremental port cases. Real RoomSync/Gate; native start failure is an
    * explicit subclass fixture, never an overwrite of the production method. */
   public class EarlyTravelPortChecks extends Sprite {
      private var rows:Array=[],mods:Array=[],h:RConnectMod,j:RConnectMod;
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});}
      public function EarlyTravelPortChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function make(role:String,reject:Boolean=false):RConnectMod {
         var m:RConnectMod=new RConnectMod(stage);mods.push(m);
         if(reject)m.game=new DecliningTravelGameBridge(m.main);
         m.session.mode=role;m.session.pause={paused:false};m.session.hostEarlyTravel=1;
         if(role==Session.HOSTING)m.session.peers=[{earlyTravel:1}];
         m.session.rooms=new RoomSync(m.session);m.session.rooms.epoch=1;m.game.roomEpoch=1;
         m.game.mapGeneration.earlyTravelSupported=true;
         m.game.world.game.lands.random_city={id:"random_city",rnd:true};
         m.game.world.grafon={scenePreload:false,sceneCullRender:true,sceneViewReady:function():Boolean{return true;}};
         m.game.world.pip={noAct:false};m.game.gg.ggControl=true;
         var player:Object=m.game.gg,world:Object=m.game.world;
         player.controlOff=function():void{player.ggControl=false;world.pip.noAct=true;};
         player.controlOn=function():void{player.ggControl=true;world.pip.noAct=false;};
         return m;
      }
      private function clear():void {
         for each(var m:RConnectMod in mods){m.session.mode=Session.OFFLINE;m.session.rooms.reset();}mods=[];
      }
      private function messages(m:RConnectMod):Array{return m.session.mode==Session.HOSTING?m.session.outbox:m.session.link.messages;}
      private function last(m:RConnectMod,op:String):Object {var result:Object;for each(var x:Object in messages(m))if(x.op==op)result=x;return result;}
      private function count(m:RConnectMod,op:String):int {var n:int=0;for each(var x:Object in messages(m))if(x.op==op)n++;return n;}
      private function prepare():Object {
         h.game.world.t_exit=19;
         h.session.rooms.prepareMap({act:{id:"random_city",rnd:true,landStage:0,visited:false},landDifLevel:29,sceneMerged:true},77,true);
         return last(h,"prepare");
      }
      private function construct(m:RConnectMod,info:Object):Object {
         m.game.completeNative(info);m.game.world.t_exit=19;m.game.transition=true;
         var ticket:Object=m.session.rooms.openFirstRaster(m.game.world,m.game.loc,m.game.world.grafon);
         m.session.rooms.nativeConstructed(m.game.world.game);return ticket;
      }
      private function releaseOldHold():void {
         clear();j=make(Session.CONNECTED);
         j.session.rooms.receivedWelcome(j.game.readWorldInfo());
         stage.dispatchEvent(new Event(Event.ENTER_FRAME));
         // No seal has been delivered. The real ordinary request path has
         // acquired a room hold while pending is still zero.
         check(j.session.rooms.busy && j.game.roomHold && j.game.world.onPause && count(j,"request")==1 && count(j,"ready")==0,
            "ordinary request without a seal holds old room before early prepare");
         h=make(Session.HOSTING);var prep:Object=prepare();j.session.rooms.handle(prep);
         check(j.session.rooms.earlyTravelPending && j.game.startCalls==1 && j.game.transition && j.game.world.t_exit==21,
            "prepare starts exactly one authorized native trip from the old room hold");
         check(!j.session.rooms.busy && !j.game.roomHold && !j.game.world.onPause,
            "successful early start releases old pending-zero pause so native construction can run");
         check(j.game.mapGeneration.externalAcquires==1 && j.game.mapGeneration.externalReleases==0,
            "old room release keeps the new early transaction lease");
         construct(h,prep.info);j.session.rooms.handle(last(h,"seal"));
         var ticket:Object=construct(j,prep.info);
         check(ticket!=null && ticket.waiting===true && j.session.rooms.busy && j.game.world.onPause,
            "declared native completion obtains a new destination raster hold");
         check(count(j,"ready")==1 && last(j,"ready").earlyId==prep.info.earlyId && j.game.restores==0,
            "new destination sends one ready and never imports before its grant");
      }
      private function rejectedStart():void {
         clear();h=make(Session.HOSTING);j=make(Session.CONNECTED,true);
         var prep:Object=prepare();j.session.rooms.handle(prep);
         check(j.game.startCalls==1 && j.game.world.t_exit==0 && !j.game.transition,
            "explicit native refusal has no fabricated load or destination");
         check(!j.session.rooms.earlyTravelPending && j.game.mapGeneration.externalAcquires==1 && j.game.mapGeneration.externalReleases==1,
            "failed start cancels the armed gate and releases its exact external lease");
         check(count(j,"earlyCancel")==1 && last(j,"earlyCancel").earlyId==prep.info.earlyId,
            "failed start notifies host with the matching early token once");
         check(!j.session.rooms.busy && !j.game.roomHold && !j.game.world.onPause && j.game.gg.ggControl,
            "failed start leaves the original player playable");
         check(j.game.restores==0 && count(j,"ready")==0 && count(j,"ack")==0 && j.session.rooms.nativeLoadingHold(j.game.world.game)==null,
            "failed start cannot import, acknowledge or expose a native loading exception");
         h.session.rooms.handle(last(j,"earlyCancel"));
         check(!h.session.rooms.earlyTravelPending && h.game.mapGeneration.externalReleases==1,
            "host receives native refusal and releases its matching preparation lease");
      }
      private function begin(e:Event):void {
         try{releaseOldHold();rejectedStart();clear();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
