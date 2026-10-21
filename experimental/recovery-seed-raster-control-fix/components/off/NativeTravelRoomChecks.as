package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.*;
   import rconnect.net.*;
   /** Drives the actual RoomSync.handle + Stage listeners, not a duplicate
    * travel state machine. This is component coverage, not native timings. */
   public class NativeTravelRoomChecks extends Sprite {
      private var mod:RConnectMod,rows:Array=[],caseName:String="";
      public function NativeTravelRoomChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void {
         rows.push({passed:ok,label:caseName+": "+label});trace((ok?"PASS ":"FAIL ")+caseName+": "+label);
      }
      private function begin(e:Event):void {
         try{run();rasterCases();seedCases();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,seed_semantics:seedSemantics,seed_gate_expected:gateExpected(),functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function frame():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));}
      private function fresh(role:String=Session.CONNECTED):void {
         if(mod!=null){mod.session.mode=Session.OFFLINE;mod.session.rooms.reset();stage.removeChild(mod.main);}
         mod=new RConnectMod(stage);mod.session.mode=role;mod.session.pause={paused:false};
         mod.session.rooms=new RoomSync(mod.session);mod.session.rooms.epoch=1;mod.game.roomEpoch=1;
      }
      private function settled():void {
         fresh();mod.session.rooms.receivedWelcome(mod.game.readWorldInfo());frame();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:1,epoch:1,info:mod.game.readWorldInfo()});
         grant(1,1,"");frame();mod.session.link.messages=[];
      }
      private function plan():Object {
         return {type:"room",op:"prepare",planVersion:1,nonce:"host",sequence:1,travelId:"host:1",fromEpoch:1,
            info:{curLandId:"way",nativeCreate:true,firstVisit:true,constructorLevel:29,entryCoord:null,layoutSeed:0}};
      }
      private function targetInfo():Object {
         return {curLandId:"way",curCoord:"",roomKey:"way//0,0,0",roomEpoch:2,travelId:"host:1",worldReady:true,
            landProb:"",landStage:0,landX:0,landY:0,landZ:0,x:800,y:40};
      }
      private function anchor():Object{return {travelId:"host:1",roomKey:"way//0,0,0",landX:0,landY:0,landZ:0,x:800,y:40};}
      private function seal(n:int):Object {
         return {type:"room",op:"seal",barrier:n,epoch:2,travelId:"host:1",info:targetInfo(),entryAnchor:anchor()};
      }
      private function grant(n:int,epoch:int,travel:String):void {
         mod.session.rooms.handle({type:"room",op:"grant",barrier:n,epoch:epoch,term:n,owner:false,
            travelId:travel,key:mod.game.roomKey(),state:RoomCodec.pack(mod.game.checkpoint()),entryAnchor:travel==""?null:anchor()});
      }
      private function count(op:String):int {
         var n:int=0;for each(var msg:Object in mod.session.link.messages)if(msg.op==op)n++;return n;
      }
      private function last(op:String):Object {
         var found:Object;for each(var msg:Object in mod.session.link.messages)if(msg.op==op)found=msg;return found;
      }
      private function complete(p:Object):void {
         var adopted:Object=mod.session.rooms.adoptNativeTravel(mod.game.world.game);
         check(adopted===p.info,"the native call consumes the accepted constructor inputs");
         mod.game.completeNative(adopted);
      }
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
      private function gateExpected():Boolean{return SeedGateCaseMode.EXPECTED;}
      private var seedSemantics:Array=[];
      private function recordSeed(label:String):void {
         seedSemantics.push({label:label,starts:mod.game.startCalls,restores:mod.game.restores,
            x:mod.game.gg.X,y:mod.game.gg.Y,epoch:mod.session.rooms.epoch,term:mod.session.rooms.term,
            ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,hold:mod.game.roomHold,
            room:mod.game.roomKey(),readyMessages:count("ready"),acks:count("ack")});
      }
      private function finishSeed(t:Object):void {
         if(t!=null){mod.game.world.grafon.ready=true;t.unpainted=false;frame();render();}
      }
      private function seedCases():void {
         caseName="seed on/off complete lifecycle";seedPrepare();
         check(mod.game.startCalls==1 && mod.game.transition,"native travel starts once");
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo(67890)});
         check(mod.game.startCalls==1,"duplicate and different-seed prepare cannot replace active identity");
         var t:Object=seedComplete();
         check((t!=null)==gateExpected(),"ticket presence exactly matches explicit on/off case");
         check(t==null || (t.waiting && t.unpainted),"existing ticket initially waits for actual pixels");
         check(!mod.game.roomHold && !mod.game.world.onPause && mod.game.world.t_exit==19,"original native exit remains runnable");
         seedSeal(1);grant(2,1,"");
         check(mod.session.rooms.epoch==1 && count("ready")==0 && mod.game.restores==1,"old empty-id epoch cannot restore new destination");
         seedSeal(2,67890);
         check(mod.session.rooms.epoch==1 && count("ready")==0,"wrong seed cannot bind the barrier");
         seedArrive();check(count("ready")==1 && last("ready").travelId=="","one ready preserves the empty wire travel id");
         seedSeal();check(count("ready")==1,"repeated seal cannot duplicate ready");
         var moved:Object=seedInfo();moved.x=1400;moved.y=100;mod.session.rooms.observeHost(moved);
         var before:int=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1,"full checkpoint restore happens exactly once");
         check(mod.game.gg.X==800 && mod.game.gg.Y==40,"fixed first-seal entrance survives moving host snapshot");
         check(count("ack")== (gateExpected()?0:1) && mod.game.roomHold==gateExpected(),"only raster scheduling changes ACK timing");
         grant(2,2,"");check(mod.game.restores==before+1,"duplicate grant cannot restore twice");
         finishSeed(t);
         check(count("ack")==1 && last("ack").travelId=="" && !mod.game.roomHold,"both routes end with exactly one original empty-id ACK");
         check(mod.game.rasterFinishes==(gateExpected()?1:0),"only delayed route needs post-raster wall completion");
         render();check(count("ack")==1,"subsequent render cannot duplicate ACK");
         seedSeal(1);grant(2,1,"");
         check(mod.game.restores==before+1 && mod.session.rooms.epoch==2 && count("ack")==1,"old epoch stays rejected after successful restore");
         recordSeed("normal-complete");

         caseName="seed early seal";seedPrepare();seedSeal();
         check(count("ready")==0 && !mod.game.world.onPause,"early seal does not pause native generation");
         t=seedComplete();mod.game.transition=false;mod.game.world.t_exit=0;frame();
         check((t!=null)==gateExpected() && count("ready")==1,"same destination identity binds after construction in both modes");

         caseName="wrong actual seed";seedPrepare();t=seedComplete(67890);
         check(t==null,"wrong actual seed never receives a ticket");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before && count("ack")==0,"wrong actual Land cannot accept grant in either mode");
         recordSeed("wrong-constructed-seed");

         caseName="seed death before grant";seedPrepare();t=seedComplete();mod.game.dead=true;frame();render();
         check((t==null || (!t.waiting && t.unpainted)) && count("ack")==0,"death never claims unconfirmed pixels or ACK");
         recordSeed("death");

         caseName="same World replacement Game before grant";seedPrepare();t=seedComplete();seedArrive();before=mod.game.restores;
         mod.game.world.game={curLandId:"seedway",lands:{seedway:{id:"seedway",rnd:true}}};grant(2,2,"");frame();render();
         check((t==null || !t.waiting) && mod.game.restores==before && count("ack")==0,"new Game rejects previous empty-id grant before frame callback");
         recordSeed("replacement-game");

         caseName="seed disconnect";seedPrepare();t=seedComplete();mod.session.mode=Session.OFFLINE;frame();render();
         check((t==null || (!t.waiting && t.unpainted)) && count("ack")==0 && !mod.game.roomHold,"disconnect releases local scheduling without successful ACK");
         recordSeed("disconnect");

         caseName="seed config fallback";seedPrepare();t=seedComplete();mod.game.world.grafon.sceneCullRender=false;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)==null && (t==null || !t.waiting),"unsupported configuration always falls back to original rendering");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1 && count("ack")==1 && last("ack").travelId=="" && mod.game.rasterFinishes==0,"fallback preserves full restore and one empty-id ACK");
         recordSeed("configuration-fallback");

         caseName="seed failed checkpoint";seedPrepare();t=seedComplete();seedArrive();before=Log.errors.length;
         mod.session.rooms.handle({type:"room",op:"grant",barrier:2,epoch:2,term:2,owner:false,travelId:"",key:mod.game.roomKey(),state:"invalid-checkpoint"});
         check(Log.errors.length==before+1 && (t==null || !t.waiting) && mod.game.roomHold && count("ack")==0,"restore failure keeps unconfirmed world blocked");
         before=mod.game.restores;grant(2,2,"");check(mod.game.restores==before && count("ack")==0,"late grant cannot revive a failed barrier");
         recordSeed("failed-restore");

         caseName="old pending barrier";settled();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         mod.game.world.game.lands.seedway={id:"seedway",rnd:true};
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});t=seedComplete();
         check(t==null,"unfinished old barrier never takes over renderer");
         caseName="ordinary room";settled();mod.game.world.game.lands.seedway={id:"seedway",rnd:true};t=seedComplete();
         check(t==null,"ordinary room without successful seed prepare has no ticket");
      }

      private function run():void {
         caseName="pause then early seal";settled();var p:Object=plan();
         mod.session.pause.paused=true;mod.session.rooms.handle(p);mod.session.rooms.handle(seal(2));frame();
         check(mod.game.startCalls==0,"paused prepare does not start native exit");
         check(count("ready")==0,"early seal cannot report the old map ready");
         check(mod.session.rooms.epoch==1 && !mod.game.roomHold,"early seal leaves old epoch and simulation lease untouched");
         mod.session.pause.paused=false;frame();
         check(mod.game.startCalls==1 && mod.game.transition,"unpause starts exactly one native exit despite early seal");
         check(!mod.game.world.onPause && count("ready")==0,"native exit remains runnable before construction");
         frame();check(mod.game.startCalls==1,"another frame does not start the same plan twice");
         complete(p);frame();
         check(count("ready")==1 && last("ready").barrier==2 && last("ready").epoch==2,"completed native destination answers the saved seal");
         check(last("ready").info.curLandId=="way" && last("ready").info.roomKey=="way//0,0,0","ready describes the new native Land");
         check(last("ready").travelId=="host:1" && mod.game.roomHold,"ready is bound to the plan and waits for grant");
         mod.session.rooms.handle(seal(2));frame();check(count("ready")==1,"duplicate applied seal does not duplicate ready");
         grant(2,2,"host:1");
         check(mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.roomHold,"matching grant releases the room");
         check(mod.game.gg.X==800 && mod.game.gg.Y==40,"grant uses the immutable host entry anchor");
         check(last("ack").travelId=="host:1" && !mod.session.rooms.nativeTravelPending,"ack completes this exact plan");
         mod.session.rooms.handle(plan());mod.session.rooms.handle(seal(2));frame();
         check(mod.game.startCalls==1 && count("ready")==1,"retired prepare and seal never restart the destination");

         caseName="old barrier remains authoritative";settled();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         check(mod.game.roomHold,"old barrier has acquired its original hold");
         mod.session.link.messages=[];p=plan();mod.session.rooms.handle(p);mod.session.rooms.handle(seal(3));frame();
         check(mod.game.startCalls==0 && mod.game.roomHold,"new prepare cannot bypass the old pending grant");
         check(count("ready")==0 && mod.session.rooms.epoch==1,"new seal neither replaces old barrier nor advances epoch");
         grant(99,1,"");frame();check(mod.game.startCalls==0 && mod.game.roomHold,"unrelated grant cannot release old barrier");
         grant(2,1,"");
         check(last("ack")!=null && last("ack").barrier==2 && last("ack").travelId=="","old grant retains its original acknowledgement identity");
         check(mod.session.rooms.nativeTravelPending,"old grant does not finish the waiting new plan");
         frame();check(mod.game.startCalls==1 && !mod.game.roomHold,"new native exit starts only after old grant completion");
         complete(p);frame();
         check(count("ready")==1 && last("ready").barrier==3 && last("ready").epoch==2,"saved new seal is used after the old barrier ends");
         grant(3,2,"host:1");check(mod.session.rooms.ready && !mod.session.rooms.nativeTravelPending,"new plan completes normally after old barrier");

         caseName="old barrier still owes ready";settled();mod.game.transition=true;
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         p=plan();mod.session.rooms.handle(p);mod.session.rooms.handle(seal(3));
         mod.session.rooms.observeHost(targetInfo());mod.game.transition=false;frame();
         check(mod.game.startCalls==0 && count("ready")==1,"old exit completion sends its ready before any new generation");
         check(last("ready").barrier==2 && last("ready").epoch==1 && last("ready").travelId=="","old ready keeps the old barrier epoch and identity");
         check(last("ready").info.curLandId=="map","new world snapshots cannot replace old barrier host info");
         grant(2,1,"");frame();complete(p);frame();
         check(count("ready")==2 && last("ready").barrier==3 && last("ready").travelId=="host:1","new ready follows old grant with its separate identity");
         grant(3,2,"host:1");check(mod.session.rooms.ready && !mod.session.rooms.nativeTravelPending,"both ordered barriers finish without an implicit bypass");

         caseName="completed counter without native adoption";settled();p=plan();mod.session.rooms.handle(p);
         mod.game.completeNative(p.info);mod.session.rooms.handle(seal(2));frame();
         check(count("ready")==0,"a changed Land and t_exit zero cannot substitute for adopting the plan");
         check(mod.session.rooms.nativeTravelPending,"unconsumed plan remains pending rather than receiving a grant");

         caseName="adopted input but old Land retained";settled();p=plan();mod.session.rooms.handle(p);
         check(mod.session.rooms.adoptNativeTravel(mod.game.world.game)===p.info,"native constructor input was adopted");
         mod.game.transition=false;mod.game.world.t_exit=0;mod.session.rooms.handle(seal(2));frame();
         check(count("ready")==0 && mod.game.world.land.act.id=="map","failed or unfinished construction cannot ready the retained old Land");

         caseName="same World loadGame replacement";settled();p=plan();mod.session.rooms.handle(p);
         var originalWorld:Object=mod.game.world;mod.game.world.game={curLandId:"way",lands:{way:{id:"way",rnd:false}}};
         check(mod.session.rooms.adoptNativeTravel(mod.game.world.game)==null,"replacement Game enters natively without consuming an old plan");
         check(mod.game.world===originalWorld && !mod.session.rooms.nativeTravelPending && mod.game.activeTravelId=="","same-World replacement cancels local plan identity");

         caseName="replacement before old grant callback";settled();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         p=plan();mod.session.rooms.handle(p);mod.session.rooms.handle(seal(3));
         var restoresBefore:int=mod.game.restores;mod.session.link.messages=[];
         // loadGame can replace Game/Land while retaining World. Deliver the
         // delayed grant before ENTER_FRAME or a native adopt callback can cancel.
         mod.game.world.game={curLandId:"map",crea:false,lands:{map:{id:"map",rnd:false},way:{id:"way",rnd:false}}};
         mod.game.completeNative({curLandId:"map"});
         grant(2,1,"");
         check(mod.game.restores==restoresBefore,"old grant cannot restore a checkpoint into replacement Game");
         check(count("ack")==0,"replacement cannot acknowledge the obsolete barrier");
         check(!mod.session.rooms.nativeTravelPending && mod.game.activeTravelId=="","message entry cancels the replaced native plan immediately");
         grant(2,1,"");
         check(mod.game.restores==restoresBefore && count("ack")==0,"cleared plan cannot reopen the old grant on duplicate delivery");
         frame();grant(2,1,"");
         check(mod.game.restores==restoresBefore && count("ack")==0,"next frame does not make the obsolete grant valid again");

         caseName="disconnect during unconfirmed native exit";settled();p=plan();mod.session.rooms.handle(p);
         mod.session.mode=Session.OFFLINE;frame();
         check(!mod.session.rooms.nativeTravelPending && mod.game.activeTravelId=="" && !mod.game.roomHold,"offline frame clears a plan even when ready and busy are both false");
         check(mod.game.transition && mod.game.world.t_exit==21,"disconnect does not cancel the remaining native single-player exit");

         caseName="capability replay";fresh(Session.HOSTING);
         var capable:TcpLink=new TcpLink(),legacy:TcpLink=new TcpLink();
         mod.session.peers=[{id:1,link:capable,nativeTravel:1}];mod.session.rooms.announceNativeTravel(plan().info);
         check(mod.session.rooms.nativeTravelPending,"capable peers enable native plans");
         mod.session.peers.push({id:2,link:legacy,nativeTravel:0});mod.session.rooms.replayNativePrepare(legacy);
         check(legacy.messages.length==0,"late peer without native bridge receives no native replay");
         mod.session.rooms.replayNativePrepare(capable);check(capable.messages.length==1 && capable.messages[0].planVersion==1,"capable peer receives the current idempotent plan");
         fresh(Session.HOSTING);mod.session.peers=[{id:1,link:legacy,nativeTravel:0}];
         mod.session.rooms.announceNativeTravel(plan().info);check(!mod.session.rooms.nativeTravelPending,"unsupported peer leaves ordinary travel untouched");
         mod.session.peers=[{id:1,link:capable,nativeTravel:1}];mod.game.mapGeneration.nativeTravelSupported=false;
         mod.session.rooms.announceNativeTravel(plan().info);check(!mod.session.rooms.nativeTravelPending,"host without native bridge cannot announce a plan");
         check(Log.errors.length==0,"all scenarios complete without a swallowed RoomSync error: "+Log.errors.join(" | "));
      }
   }
}
