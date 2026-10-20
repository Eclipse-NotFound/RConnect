package {
   import flash.desktop.NativeApplication;
   import flash.display.*;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.RoomSync;
   import rconnect.core.Session;
   import rconnect.net.RoomCodec;
   public class RoomEntryChecks extends Sprite {
      private var mod:RConnectMod,rows:Array=[],nameOfCase:String="";
      private var red:uint=0xC02020,green:uint=0x20C020;
      public function RoomEntryChecks() {addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void {
         rows.push({passed:ok,label:nameOfCase+": "+label});trace((ok?"PASS ":"FAIL ")+nameOfCase+": "+label);
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function render():void{stage.dispatchEvent(new Event(Event.RENDER));}
      private function mayPublish():Boolean {
         var rooms:Object=mod.session.rooms;
         // Historical Session used these two flags at all three world-state
         // send sites. New production centralizes that gate in RoomSync.
         return "canSyncWorld" in rooms ? Boolean(rooms.canSyncWorld) : rooms.ready && !rooms.busy;
      }
      private function frame():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));render();}
      private function pixel():uint {
         var b:BitmapData=new BitmapData(640,400,false,0);b.draw(mod.main);var v:uint=b.getPixel(50,50);b.dispose();return v;
      }
      private function fresh(role:String):void {
         if(mod!=null){mod.session.mode=Session.OFFLINE;mod.session.rooms.reset();stage.removeChild(mod.main);}
         mod=new RConnectMod(stage);mod.session.mode=role;
         if(role==Session.HOSTING)mod.session.peers.push({id:1});
         mod.session.rooms=new RoomSync(mod.session);
      }
      private function seal(n:int):void {
         mod.session.rooms.handle({type:"room",op:"seal",barrier:n,epoch:1,info:mod.game.readWorldInfo()});
      }
      private function grant(n:int,key:String=null,owner:Boolean=false):void {
         mod.session.rooms.handle({type:"room",op:"grant",barrier:n,epoch:1,term:n,owner:owner,
            state:RoomCodec.pack({key:key||mod.game.roomKey(),color:green,width:12,height:8})});
      }
      private function run():void {
         nameOfCase="terrain checkpoint encoding";RoomCodecChecks.run(check);
         nameOfCase="direct native tile checkpoint";NativeTileStateChecks.run(check);
         nameOfCase="unchanged terrain view";RoomTerrainViewChecks.run(check);
         nameOfCase="welcome received between frames";fresh(Session.OFFLINE);mod.session.mode=Session.CONNECTED;
         if("receivedWelcome" in mod.session.rooms)Object(mod.session.rooms).receivedWelcome(null);
         check(pixel()!=red,"welcome closes the provisional scene before any new frame");
         nameOfCase="initial pending host map";frame();
         check(pixel()!=red,"unconfirmed layout is not painted before host info arrives");
         check(!mod.game.world.onPause,"waiting does not freeze native load counters");
         var menu:Sprite=mod.game.world.vpip;menu.graphics.beginFill(0x2040D0);
         menu.graphics.drawRect(0,0,640,400);menu.graphics.endFill();menu.visible=true;render();
         check(pixel()==0x2040D0,"native menu remains visible above pending scene");menu.visible=false;
         mod.game.world.vsats.graphics.beginFill(red);mod.game.world.vsats.graphics.drawRect(0,0,640,400);
         mod.game.world.vsats.visible=true;render();check(pixel()!=red,"SATS copy cannot leak an unconfirmed scene");
         mod.game.world.vsats.visible=false;
         nameOfCase="native loading exposes new room at exit 16";
         mod.game.transition=true;mod.game.world.t_exit=16;mod.game.setRoom("map//1,0,0",red);frame();
         check(pixel()!=red,"native early visual enable cannot expose provisional walls");
         check(!mod.game.world.onPause,"exit sequence remains free to finish");
         mod.game.transition=false;mod.game.world.t_exit=0;seal(1);frame();
         check(mod.game.roomHold && mod.game.world.onPause,"room simulation waits for grant");
         var readyMessage:Object;
         for each(var sent:Object in mod.session.link.messages)if(sent.op=="ready")readyMessage=sent;
         check(readyMessage!=null && readyMessage.fresh==null,"shared destination does not encode an unused native copy");
         check(pixel()!=red,"waiting for complete checkpoint hides provisional layout");
         mod.game.restoreHook=function():void{render();check(pixel()!=red,"partial checkpoint cannot be displayed");};
         grant(1);render();mod.game.restoreHook=null;
         check(pixel()==green,"first released frame shows the applied checkpoint");
         check(mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.roomHold,"grant completes original barrier");
         var receipt:Object={roomKey:mod.game.roomKey(),roomEpoch:1,roomTerm:1};
         check(mod.session.rooms.acceptsReceipt(receipt),"settled room accepts its receipt");
         check(mayPublish(),"confirmed room can publish world state");
         check(!mod.session.rooms.acceptsReceipt({roomKey:receipt.roomKey,roomEpoch:0,roomTerm:1}),"stale epoch is still rejected");
         check(!mod.session.rooms.acceptsReceipt({roomKey:receipt.roomKey,roomEpoch:1,roomTerm:0}),"stale term is still rejected");
         nameOfCase="room changed during transition before ordinary check";
         mod.game.transition=true;mod.game.setRoom("map//2,0,0",red);frame();
         check(!mod.session.rooms.accepts(receipt),"old-room state cannot affect newly active native room");
         check(!mayPublish(),"new native room cannot publish with the previous room stamp");
         check(mod.session.rooms.acceptsReceipt(receipt),"final player damage still settles before the next grant");
         check(pixel()!=red,"new native room stays hidden even before room handoff begins");
         mod.game.transition=false;seal(2);frame();
         check(mod.session.rooms.busy && mod.session.rooms.acceptsReceipt(receipt),"barrier retains the ordered final player damage receipt");
         grant(2);render();
         check(pixel()==green && mod.session.rooms.term==2,"second room reveals only its restored checkpoint");
         check(!mod.session.rooms.acceptsReceipt(receipt),"old player damage cannot be accepted after the next grant");
         var saveLand:Object=mod.game.world.land;mod.game.world.land={act:{id:"map"},loc_t:0};render();
         check(pixel()!=green,"same room pointer with replaced native Land cannot look settled");
         check(!mod.session.rooms.accepts({roomKey:mod.game.roomKey(),roomEpoch:1,roomTerm:2}),"replacement Land rejects old world state");
         check(!mayPublish(),"replacement Land cannot publish with the previous generation stamp");
         mod.game.world.land=saveLand;render();check(pixel()==green,"restoring the unchanged settled Land removes the temporary cover");
         nameOfCase="late native activation after frame listener";
         mod.game.setRoom("map//3,0,0",red);render();
         check(pixel()!=red,"render fence catches activation after frame listener");
         mod.main.scaleX=.75;mod.main.scaleY=.75;mod.main.x=20;mod.main.y=15;render();
         check(pixel()!=red,"cover survives a scaled and offset game root");
         mod.main.scaleX=mod.main.scaleY=1;mod.main.x=mod.main.y=0;
         seal(3);frame();grant(3);render();
         nameOfCase="failed restore";mod.game.setRoom("map//4,0,0",red);frame();seal(4);
         mod.game.failRestore=true;grant(4);render();
         check(pixel()!=red && mod.session.rooms.busy,"restore failure keeps invalid room covered and paused");
         nameOfCase="disconnect";mod.session.mode=Session.OFFLINE;mod.session.rooms.reset();render();
         check(pixel()==red && !mod.game.roomHold && !mod.game.world.onPause,"disconnect removes only owned cover and pause");
         nameOfCase="seal arrives during native join load";fresh(Session.CONNECTED);
         mod.game.transition=true;mod.game.world.t_exit=21;seal(1);frame();
         check(!mod.game.roomHold && !mod.game.world.onPause,
            "pending peer seal cannot use an unstarted local deadline to freeze native loading");
         nameOfCase="hosting first handshake";fresh(Session.HOSTING);frame();
         check(pixel()!=red,"host also waits for complete first handshake");
         var sealMsg:Object=mod.session.outbox[0];
         mod.session.rooms.handle({type:"room",op:"ready",barrier:sealMsg.barrier,epoch:sealMsg.epoch,
            info:mod.game.readWorldInfo(),oldKey:"",oldTerm:0,own:null,fresh:RoomCodec.pack(mod.game.checkpoint())});
         render();check(pixel()==red && !mod.game.world.onPause && !mod.game.roomHold,
            "host resumes its committed authoritative room without waiting for peer rendering");
         check(mod.game.restores==0,"new authoritative native room is never restored into itself");
         check(mayPublish(),"committed host snapshots follow the grant in TCP order");
         mod.session.rooms.handle({type:"room",op:"ack",barrier:sealMsg.barrier});render();
         check(pixel()==red && !mod.session.rooms.busy,"host releases its authoritative original room on ack");
         check(mayPublish(),"host can publish again after the acknowledged grant");
         nameOfCase="only peer enters a different room";
         var beforeRestore:int=mod.game.restores;
         mod.session.rooms.handle({type:"room",op:"request",info:{roomKey:"map//1,0,0"}});render();
         check(pixel()==red,"stationary host stays visible during peer handoff");
         check(!mod.game.world.onPause && !mod.game.roomHold,"stationary host simulation continues");
         var n:int=mod.session.outbox.length,peerSeal:Object=mod.session.outbox[n-1];
         mod.session.rooms.handle({type:"room",op:"ready",barrier:peerSeal.barrier,epoch:peerSeal.epoch,
            info:{roomKey:"map//1,0,0"},oldKey:"map//0,0,0",oldTerm:1,own:null,
            fresh:RoomCodec.pack({key:"map//1,0,0",color:green,width:12,height:8})});
         mod.session.rooms.handle({type:"room",op:"ack",barrier:peerSeal.barrier});render();
         check(mod.game.restores==beforeRestore,"peer departure does not restore unchanged host room");
         check(pixel()==red && !mod.game.world.onPause,"stationary host remains available after peer entry");
         nameOfCase="new host entry while previous ack is pending";
         fresh(Session.HOSTING);frame();sealMsg=mod.session.outbox[0];
         mod.session.rooms.handle({type:"room",op:"ready",barrier:sealMsg.barrier,epoch:sealMsg.epoch,
            info:mod.game.readWorldInfo(),oldKey:"",oldTerm:0,own:null,fresh:RoomCodec.pack(mod.game.checkpoint())});
         n=mod.session.outbox.length;mod.game.setRoom("map//2,0,0",red);frame();
         check(mod.session.outbox.length==n && !mayPublish() && mod.session.rooms.entryPending,
            "next native entry waits for the prior ack and cannot publish under the old room identity");
         mod.session.rooms.handle({type:"room",op:"ack",barrier:sealMsg.barrier});frame();
         peerSeal=mod.session.outbox[mod.session.outbox.length-1];
         check(peerSeal.op=="seal" && peerSeal.barrier!=sealMsg.barrier && mod.game.roomHold,
            "prior ack allows exactly the next pending handoff to start");
         mod.session.rooms.handle({type:"room",op:"ack",barrier:sealMsg.barrier});render();
         check(mod.game.roomHold && mod.session.rooms.entryPending,
            "duplicate old ack cannot release the next unconfirmed room");
         nameOfCase="native travel boundaries";
         mod.game.world.cam={dblack:1.5};mod.game.world.t_die=0;mod.game.world.comLoad=-1;
         mod.game.world.game={crea:true,curLandId:"map",lands:{}};
         mod.game.transition=true;mod.game.world.t_exit=80;mod.game.world.vblack.alpha=0;
         frame();check(mod.game.world.t_exit==80 && mod.game.world.cam.dblack==100,"unfinished fade speeds up without skipping loading");
         mod.game.world.vblack.alpha=1;frame();check(mod.game.world.t_exit==21,"finished decorative fade uses the native quick-travel boundary");
         for each(var boundary:int in [20,19,18,17]) {
            mod.game.world.t_exit=boundary;frame();check(mod.game.world.t_exit==boundary,"native loading/click boundary retained "+boundary);
         }
         mod.game.world.t_exit=16;mod.game.world.cam.dblack=-10;mod.game.world.vblack.alpha=1;frame();
         check(mod.game.world.t_exit==16 && mod.game.world.cam.dblack==-100,"uncompleted reveal keeps native control boundary");
         mod.game.world.vblack.alpha=0;frame();check(mod.game.world.t_exit==2,"completed reveal still leaves the native HUD boundary");
         nameOfCase="fresh independent join room";fresh(Session.CONNECTED);seal(1);frame();grant(1);frame();
         var oldHostInfo:Object=mod.game.readWorldInfo();mod.game.setRoom("map//9,0,0",red);frame();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:oldHostInfo});
         readyMessage=null;for each(sent in mod.session.link.messages)if(sent.op=="ready" && sent.barrier==2)readyMessage=sent;
         beforeRestore=mod.game.restores;
         mod.session.rooms.handle({type:"room",op:"grant",barrier:2,epoch:1,term:2,owner:true,fresh:true,
            key:mod.game.roomKey(),state:readyMessage.fresh});render();
         check(mod.game.restores==beforeRestore && pixel()==red,"matching fresh owner grant preserves the held native room");
         check(mod.session.rooms.ready && mod.session.rooms.authority && !mod.game.roomHold,"fresh owner grant releases native simulation");
         nameOfCase="host joins the existing peer-owned room";
         seal(3);
         readyMessage=null;for each(sent in mod.session.link.messages)if(sent.op=="ready" && sent.barrier==3)readyMessage=sent;
         check(readyMessage.own!=null && readyMessage.fresh==null,"held owner sends one complete checkpoint");
         mod.session.rooms.handle({type:"room",op:"grant",barrier:3,epoch:1,term:3,owner:false,retained:true,
            key:mod.game.roomKey(),state:readyMessage.own});render();
         check(mod.game.retainedRestores==1,"exact held checkpoint reuses terrain and object state");
         check(mod.session.rooms.ready && !mod.session.rooms.authority && !mod.game.roomHold,"retained checkpoint still transfers simulation authority");
         nameOfCase="retained hint without a held owner checkpoint";
         seal(4);mod.session.rooms.handle({type:"room",op:"grant",barrier:4,epoch:1,term:4,owner:false,retained:true,
            key:mod.game.roomKey(),state:readyMessage.own});render();
         check(mod.session.rooms.busy && mod.game.roomHold,"unverified retained grant stays blocked");
         nameOfCase="existing pause and foreign grant";fresh(Session.CONNECTED);mod.game.world.onPause=true;
         seal(1);grant(1);render();check(mod.game.world.onPause,"existing local pause survives handoff");
         mod.game.world.onPause=false;mod.game.setRoom("map//5,0,0",red);frame();seal(2);
         grant(2,"map//6,0,0");render();check(pixel()!=red && mod.session.rooms.busy,"wrong-room grant stays closed");
         nameOfCase="disconnect before any host info";fresh(Session.CONNECTED);frame();
         mod.session.mode=Session.OFFLINE;stage.dispatchEvent(new Event(Event.ENTER_FRAME));
         check(pixel()==red,"disconnect before barrier restores view without requiring a render event");
         nameOfCase="offline";fresh(Session.OFFLINE);frame();check(pixel()==red,"standalone room is not gated");
      }
   }
}
