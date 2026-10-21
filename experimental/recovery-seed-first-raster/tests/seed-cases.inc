      private function seedInfo(seed:uint=12345):Object {
         return {curLandId:"seedway",layoutSeed:seed,layoutLevel:29,sceneMerged:true,worldReady:true,
            roomKey:"seedway//0,0,0",roomEpoch:2,landX:0,landY:0,landZ:0,x:800,y:40};
      }
      private function seedPrepare():void {
         settled();mod.game.world.game.lands.seedway={id:"seedway",rnd:true};
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});
      }
      private function seedComplete(seed:uint=12345):Object {
         mod.game.completeNative(seedInfo(seed));mod.game.transition=true;mod.game.world.t_exit=19;
         mod.game.loc.spaceX=192;mod.game.loc.spaceY=75;
         var g:Object={loc:mod.game.loc,ready:false,scenePreload:false,sceneCullRender:true};
         g.sceneViewReady=function():Boolean{return g.ready;};
         mod.game.world.grafon=g;mod.game.loc.grafon=g;
         return mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,g);
      }
      private function seedSeal(epoch:int=2,seed:uint=12345):void {
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:epoch,travelId:"",info:seedInfo(seed)});
      }
      private function seedArrive():void {mod.game.transition=false;mod.game.world.t_exit=0;seedSeal();frame();}
      private function seedCases():void {
         caseName="legacy seed normal lifecycle";seedPrepare();
         check(mod.game.startCalls==1 && mod.game.transition,"legacy prepare really starts native travel once");
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo(67890)});
         check(mod.game.startCalls==1,"duplicate and overtaking prepares cannot replace active seed identity");
         var t:Object=seedComplete();
         check(t!=null && t.waiting && t.unpainted,"new random Land with exact seed receives first-raster ticket");
         check(!mod.game.roomHold && !mod.game.world.onPause && mod.game.world.t_exit==19,"seed hook keeps native exit progression runnable");
         seedSeal(1);grant(2,1,"");
         check(mod.session.rooms.epoch==1 && count("ready")==0 && mod.game.restores==1,"old epoch empty-id seal and grant do not advance new seed entry");
         seedSeal(2,67890);
         check(mod.session.rooms.epoch==1 && count("ready")==0,"same target wrong seed seal cannot bind barrier");
         seedArrive();check(count("ready")==1 && last("ready").travelId=="","seed ready retains empty wire travelId");
         seedSeal();check(count("ready")==1,"duplicate identical seed seal does not duplicate ready");
         var moved:Object=seedInfo();moved.x=1400;moved.y=100;mod.session.rooms.observeHost(moved);
         var before:int=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1 && !t.waiting && t.unpainted,"seed grant fully restores before releasing native raster");
         check(mod.game.gg.X==800 && mod.game.gg.Y==40,"first matching seal fixes entrance despite later moving host snapshots");
         check(count("ack")==0 && mod.game.roomHold,"seed grant cannot expose unpainted pixels");
         grant(2,2,"");check(mod.game.restores==before+1,"duplicate empty-id grant does not restore twice");
         mod.game.world.grafon.ready=true;t.unpainted=false;render();
         check(count("ack")==0,"seed entry still requires subsequent anchored camera frame");
         frame();render();
         check(count("ack")==1 && last("ack").travelId=="" && !mod.game.roomHold,"seed entry ACKs empty ID exactly once after actual view readiness");
         check(mod.game.rasterFinishes==1,"seed entry restores logical wall paint exactly once");
         render();check(count("ack")==1,"later render cannot ACK old seed entry again");

         caseName="legacy seed early seal";seedPrepare();seedSeal();
         check(count("ready")==0 && !mod.game.world.onPause,"early target seal does not stop generation or report old Land ready");
         t=seedComplete();mod.game.transition=false;mod.game.world.t_exit=0;frame();
         check(t!=null && count("ready")==1,"early matching seal remains bound through actual destination construction");

         caseName="legacy wrong constructed seed";seedPrepare();t=seedComplete(67890);
         check(t==null,"wrong actual constructed seed never delays native drawing");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before && count("ack")==0,"wrong Land seed cannot accept matching-looking empty-id grant");

         caseName="legacy seed death before grant";seedPrepare();t=seedComplete();mod.game.dead=true;frame();render();
         check(!t.waiting && t.unpainted && count("ack")==0,"death cancels renderer wait without claiming pixels or ACK");

         caseName="legacy seed same World new Game";seedPrepare();t=seedComplete();seedArrive();grant(2,2,"");
         before=mod.game.restores;mod.game.world.game={curLandId:"seedway",lands:{seedway:{id:"seedway",rnd:true}}};
         grant(2,2,"");frame();render();
         check(!t.waiting && mod.game.restores==before && count("ack")==0,"replacement Game rejects old empty-id grant before a frame callback");

         caseName="legacy seed disconnect";seedPrepare();t=seedComplete();mod.session.mode=Session.OFFLINE;frame();render();
         check(!t.waiting && t.unpainted && count("ack")==0 && !mod.game.roomHold,"disconnect clears local seed wait and keeps real raster unfinished");

         caseName="legacy seed config fallback";seedPrepare();t=seedComplete();mod.game.world.grafon.sceneCullRender=false;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)==null && !t.waiting,"unsupported configuration releases seed raster ticket");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1 && count("ack")==1 && last("ack").travelId=="" && mod.game.rasterFinishes==0,"config fallback retains full normal restore and empty-ID ACK");

         caseName="legacy seed failed checkpoint";seedPrepare();t=seedComplete();seedArrive();before=Log.errors.length;
         mod.session.rooms.handle({type:"room",op:"grant",barrier:2,epoch:2,term:2,owner:false,travelId:"",key:mod.game.roomKey(),state:"invalid-checkpoint"});
         check(Log.errors.length==before+1 && !t.waiting && mod.game.roomHold && count("ack")==0,"restore failure releases scheduling but keeps unconfirmed world blocked");
         before=mod.game.restores;grant(2,2,"");check(mod.game.restores==before && count("ack")==0,"failed seed barrier cannot be revived by a late empty-ID grant");

         caseName="legacy seed old barrier disables optimization";settled();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         mod.game.world.game.lands.seedway={id:"seedway",rnd:true};
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});t=seedComplete();
         check(t==null,"seed prepare with unfinished old barrier does not take over renderer");

         caseName="ordinary random room has no seed travel";settled();mod.game.world.game.lands.seedway={id:"seedway",rnd:true};
         t=seedComplete();check(t==null,"ordinary room drawing without successful seed prepare has no ticket");

         caseName="legacy seed same destination stale seal after restore";seedPrepare();t=seedComplete();seedArrive();grant(2,2,"");
         before=mod.game.restores;seedSeal(1);grant(2,1,"");
         check(mod.game.restores==before && count("ack")==0 && mod.session.rooms.epoch==2,"old epoch cannot replace waiting restored destination");
      }
