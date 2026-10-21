      private function rasterDestination():Object {
         settled();var p:Object=plan();p.info.sceneMerged=true;
         mod.session.rooms.handle(p);
         var input:Object=mod.session.rooms.adoptNativeTravel(mod.game.world.game);
         mod.game.completeNative(input);
         // This is the native sceneOpen callback boundary; native construction
         // and pixels are substituted, actual RoomSync/Gate remain unchanged.
         mod.game.transition=true;mod.game.world.t_exit=19;
         mod.game.loc.spaceX=192;mod.game.loc.spaceY=75;
         var renderer:Object={loc:mod.game.loc,ready:false,ticket:null,scenePreload:false,sceneCullRender:true};
         renderer.sceneViewReady=function():Boolean{return renderer.ready;};
         mod.game.world.grafon=renderer;mod.game.loc.grafon=renderer;
         var ticket:Object=mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,renderer);
         renderer.ticket=ticket;
         return ticket;
      }
      private function rasterSeal():void {
         mod.game.transition=false;mod.game.world.t_exit=0;
         mod.session.rooms.handle(seal(2));frame();
      }
      private function render():void {stage.dispatchEvent(new Event(Event.RENDER));}
      private function rasterCases():void {
         caseName="deferred large native destination";var ticket:Object=rasterDestination();
         check(ticket!=null && ticket.waiting && ticket.unpainted,"exact shared scene gets one pending ticket");
         check(!mod.game.world.onPause && !mod.game.roomHold && mod.game.world.t_exit==19,"first raster hook does not stop exitStep");
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)===ticket,"same native destination reuses identity");
         rasterSeal();check(count("ready")==1 && count("ack")==0,"native exit completes and sends ready without pixels");
         var before:int=mod.game.restores;grant(2,2,"host:1");
         check(mod.game.restores==before+1 && !ticket.waiting,"matching grant performs complete restore and allows raster");
         check(mod.game.gg.X==800 && mod.game.gg.Y==40,"anchor is installed before waiting for camera");
         check(count("ack")==0 && mod.session.rooms.busy && mod.game.roomHold,"unpainted destination is neither ACKed nor released");
         grant(2,2,"host:1");check(mod.game.restores==before+1,"duplicate grant while awaiting pixels does not reapply state");
         mod.game.world.grafon.ready=true;ticket.unpainted=false;render();
         check(count("ack")==0,"same-frame pixel flag cannot substitute for anchored native camera frame");
         frame();mod.game.world.grafon.ready=false;render();check(count("ack")==0,"next frame still requires actual view readiness");
         mod.game.world.grafon.ready=true;render();
         check(count("ack")==1 && !mod.session.rooms.busy && !mod.game.roomHold,"next native view releases exactly once");
         check(mod.game.rasterFinishes==1 && !mod.session.rooms.nativeTravelPending,"logical wall finish precedes completed travel");
         render();check(count("ack")==1 && mod.game.rasterFinishes==1,"later render cannot repeat ACK or wall finish");

         caseName="replacement Game while awaiting raster";ticket=rasterDestination();rasterSeal();grant(2,2,"host:1");
         before=mod.game.restores;mod.game.world.game={curLandId:"way",lands:{way:{id:"way",rnd:false}}};
         frame();render();grant(2,2,"host:1");
         check(!ticket.waiting && !mod.session.rooms.nativeTravelPending,"same World replacement cancels exact raster/travel binding");
         check(count("ack")==0 && mod.game.restores==before,"replacement never receives or acknowledges old grant twice");

         caseName="death before grant";ticket=rasterDestination();mod.game.dead=true;frame();render();
         check(!ticket.waiting && !mod.session.rooms.nativeTravelPending,"death releases renderer wait without claiming pixels");
         check(ticket.unpainted && count("ack")==0,"death does not fabricate raster completion or ACK");

         caseName="disconnect before grant";ticket=rasterDestination();mod.session.mode=Session.OFFLINE;frame();render();
         check(!ticket.waiting && !mod.game.roomHold && !mod.session.rooms.nativeTravelPending,"offline reset releases renderer and native transition");
         check(ticket.unpainted && count("ack")==0,"offline native renderer must still produce real pixels");

         caseName="destination Location changes before grant";ticket=rasterDestination();
         mod.game.setRoom("way//1,0,0");mod.game.world.grafon.loc=mod.game.loc;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)==null,"different Location falls back to full native draw");
         check(!ticket.waiting && ticket.unpainted,"obsolete Location ticket cannot retain a raster wait");

         caseName="supported renderer configuration becomes unsupported";ticket=rasterDestination();
         mod.game.world.grafon.scenePreload=false;mod.game.world.grafon.sceneCullRender=false;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)==null,"nonpreload without culling falls back to ordinary drawing");
         check(!ticket.waiting && ticket.unpainted,"configuration fallback releases old ticket without fabricating pixels");
         rasterSeal();before=mod.game.restores;grant(2,2,"host:1");
         check(mod.game.restores==before+1 && count("ack")==1 && !mod.session.rooms.busy && mod.game.rasterFinishes==0,"fallback grant uses original complete restore and ACK path without an obsolete gate");

         caseName="invalid grant failure";ticket=rasterDestination();rasterSeal();before=Log.errors.length;
         mod.session.rooms.handle({type:"room",op:"grant",barrier:2,epoch:2,term:2,owner:false,
            travelId:"host:1",key:mod.game.roomKey(),state:"invalid-checkpoint",entryAnchor:anchor()});
         check(Log.errors.length==before+1 && !ticket.waiting,"failed decode releases only raster scheduling");
         check(mod.game.roomHold && mod.session.rooms.entryPending && count("ack")==0,"failure remains visibly blocked and unacknowledged");

         caseName="ordinary room and host isolation";settled();
         var g:Object={};mod.game.world.grafon=g;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,g)==null,"ordinary join room has no native ticket");
         fresh(Session.HOSTING);mod.game.world.grafon=g;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,g)==null,"host follows old path");
         fresh(Session.OFFLINE);mod.game.world.grafon=g;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,g)==null,"offline follows old path");
      }
