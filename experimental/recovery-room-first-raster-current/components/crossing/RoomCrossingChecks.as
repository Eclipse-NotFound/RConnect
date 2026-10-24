package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.*;
   import rconnect.net.*;

   /** Actual RoomSync and codec; transport/native rooms are explicit fixtures.
    * This does not measure native performance or qualify actual game graphics. */
   public class RoomCrossingChecks extends Sprite {
      private var h:RConnectMod,j:RConnectMod,mods:Array=[],rows:Array=[],label:String="";
      private const X:String="map//0,0,0",A:String="map//1,0,0",B:String="map//2,0,0",D:String="map//3,0,0";
      public function RoomCrossingChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,text:String):void {
         rows.push({passed:ok,label:label+": "+text});trace((ok?"PASS ":"FAIL ")+label+": "+text);
      }
      private function frame():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));}
      private function make(role:String):RConnectMod {
         var m:RConnectMod=new RConnectMod(stage);mods.push(m);m.session.mode=role;
         m.session.pause={paused:false};if(role==Session.HOSTING)m.session.peers=[{}];
         m.session.rooms=new RoomSync(m.session);return m;
      }
      private function messages(m:RConnectMod):Array{return m===h?m.session.outbox:m.session.link.messages;}
      private function clearMessages():void{h.session.outbox=[];j.session.link.messages=[];}
      private function last(m:RConnectMod,op:String):Object {
         var out:Object;for each(var msg:Object in messages(m))if(msg.op==op)out=msg;
         if(out==null)throw new Error("Missing "+op+" from "+(m===h?"host":"join"));return out;
      }
      private function count(m:RConnectMod,op:String):int {
         var n:int=0;for each(var msg:Object in messages(m))if(msg.op==op)n++;return n;
      }
      private function pump():void {
         var cycles:int=0;
         while(h.session.outbox.length || j.session.link.messages.length) {
            if(cycles++>100)throw new Error("Unbounded protocol exchange");
            var hs:Array=h.session.outbox;h.session.outbox=[];
            for each(var msg:Object in hs)j.session.rooms.handle(msg);
            var js:Array=j.session.link.messages;j.session.link.messages=[];
            for each(msg in js)h.session.rooms.handle(msg);
         }
      }
      private function setup():void {
         for each(var m:RConnectMod in mods){m.session.mode=Session.OFFLINE;m.session.rooms.reset();}
         mods=[];Log.errors=[];h=make(Session.HOSTING);j=make(Session.CONNECTED);
         for(var n:int=0;n<3;n++){frame();pump();}
         check(h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld,"initial shared room is settled");
         j.game.setRoom(B);frame();pump();frame();pump();
         check(h.session.rooms.authority && j.session.rooms.authority && j.game.roomKey()==B,"split B belongs to join");
         clearMessages();
      }
      private function finish(seal:Object):void {
         j.session.rooms.handle(seal);h.session.rooms.handle(last(j,"ready"));
         j.session.rooms.handle(last(h,"grant"));h.session.rooms.handle(last(j,"ack"));
      }
      private function joinCross(observed:Boolean):void {
         label="join crosses while unchanged, frame="+observed;setup();
         j.game.loc.marker=42;h.game.setRoom(A);frame();
         j.session.rooms.handle(last(h,"seal"));var ready:Object=last(j,"ready");
         check(ready.own==null && ready.fresh==null && !j.game.roomHold,"unchanged owner really remains playable");
         j.game.setRoom(D);if(observed)frame();
         var request:Object=observed?last(j,"request"):null;
         h.session.rooms.handle(ready);var oldGrant:Object=last(h,"grant");
         check(oldGrant.unchanged===true && oldGrant.key==B,"old grant belongs to B");
         if(request!=null)h.session.rooms.handle(request);
         var before:int=j.game.restores;j.session.rooms.handle(oldGrant);
         check(Log.errors.length==0,"late unchanged grant is accepted without sync failure");
         check(j.game.restores==before && j.game.rooms[B].marker==42,"B live state is neither restored nor rolled back");
         check(j.game.roomHold && j.game.world.onPause && !j.session.rooms.canSyncWorld,"D remains held inside the grant callback");
         check(j.session.rooms.stamp({}).roomKey==B,"old grant never grants authority for D");
         check(count(j,"request")==1,"crossing request is sent once, before or after ACK as appropriate");
         h.session.rooms.handle(last(j,"ack"));
         if(!observed)h.session.rooms.handle(last(j,"request"));
         var nextSeal:Object=last(h,"seal");check(nextSeal.barrier>oldGrant.barrier,"queued crossing creates the next barrier");
         clearMessages();finish(nextSeal);
         check(j.game.roomKey()==D && j.session.rooms.canSyncWorld && !j.game.roomHold,"D is released only after its own grant");
         check(Log.errors.length==0,"two linked handoffs have no errors");
      }
      private function hostCross(observed:Boolean):void {
         label="host crosses before ready, frame="+observed;setup();
         // A previously announced B request is allowed to trigger a barrier.
         // It can be queued behind another handoff; no private field is set.
         j.game.loc.marker=99;
         h.session.rooms.handle({type:"room",op:"request",epoch:h.session.rooms.epoch,info:j.game.readWorldInfo()});
         j.session.rooms.handle(last(h,"seal"));var ready:Object=last(j,"ready");
         check(!h.game.roomHold && !j.game.roomHold && ready.own==null,"both unchanged owners remain playable before crossing");
         h.game.setRoom(B);h.game.loc.marker=7;if(observed)frame();
         var nativeRoom:Object=h.game.loc,playerRoom:Object=h.game.gg.loc,before:int=h.game.restores;
         h.session.rooms.handle(ready);var grant:Object=last(h,"grant");
         check(Log.errors.length==0,"old ready completes against its sealed room");
         check(h.game.loc===nativeRoom && h.game.world.loc===nativeRoom && h.game.world.land.loc===nativeRoom
            && h.game.gg.loc===playerRoom,"scoped commit restores native pointers without moving the player");
         check(h.game.restores==before && h.game.loc.marker==7,"old transaction does not restore stale B into current B");
         check(h.session.rooms.stamp({}).roomKey==X && grant.unchanged===true,"old transaction remains X host / B join");
         check(h.game.roomHold && h.game.world.onPause && !h.session.rooms.canSyncWorld,"new host room is paused before returning");
         j.session.rooms.handle(grant);h.session.rooms.handle(last(j,"ack"));
         var nextSeal:Object=last(h,"seal");check(nextSeal.info.roomKey==B && nextSeal.barrier>grant.barrier,"ACK starts fresh B ownership handoff");
         clearMessages();j.session.rooms.handle(nextSeal);ready=last(j,"ready");
         check(ready.own!=null && RoomCodec.unpack(ready.own).marker==99,"new B handoff obtains its live owner checkpoint");
         h.session.rooms.handle(ready);j.session.rooms.handle(last(h,"grant"));h.session.rooms.handle(last(j,"ack"));
         check(h.game.loc.marker==99 && j.game.loc.marker==99,"both B views retain actual owner progress");
         check(h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld && !j.session.rooms.authority,"shared B is settled with correct owner");
      }
      private function hostQueuedPrelude():void {
         label="native request prelude for host crossing";setup();
         j.game.setRoom(D);frame();h.session.rooms.handle(last(j,"request"));
         j.session.rooms.handle(last(h,"seal"));var ready:Object=last(j,"ready");
         check(!h.game.roomHold,"host may walk while join enters D");
         h.game.setRoom(A);frame();h.session.rooms.handle(ready);
         var grant:Object=last(h,"grant");j.session.rooms.handle(grant);h.session.rooms.handle(last(j,"ack"));
         check(h.game.roomHold && h.session.rooms.stamp({}).roomKey==X,"queued seal cannot prematurely make A settled/playable");
         var nextSeal:Object=last(h,"seal");clearMessages();finish(nextSeal);
         check(h.game.roomKey()==A && j.game.roomKey()==D && h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld,"ordinary double crossing finishes A/D without a redundant free-running barrier");
      }
      private function wrongLand():void {
         label="Land identity rejection";setup();
         h.session.rooms.handle({type:"room",op:"request",epoch:h.session.rooms.epoch,info:j.game.readWorldInfo()});
         j.session.rooms.handle(last(h,"seal"));var ready:Object=last(j,"ready");
         h.game.world.land={act:{id:"map"},loc_t:0};h.game.setRoom(X);
         var before:int=count(h,"grant");h.session.rooms.handle(ready);
         check(Log.errors.length==1 && count(h,"grant")==before && h.game.roomHold,"same map ID with replacement Land cannot reuse the old barrier");
      }
      private function coveredRequest():void {
         label="request before READY is already covered";setup();
         h.game.setRoom(A);frame();var seal:Object=last(h,"seal");
         // Both walk in the same interval. Join sends request(D), then sees
         // the host's existing seal(A), so its READY(D) covers that request.
         j.game.setRoom(D);frame();var request:Object=last(j,"request");
         j.session.rooms.handle(seal);var ready:Object=last(j,"ready");
         check(request.info.roomKey==D && ready.info.roomKey==D,"request and READY refer to the same native destination");
         h.session.rooms.handle(request);var seals:int=count(h,"seal");
         h.session.rooms.handle(ready);j.session.rooms.handle(last(h,"grant"));h.session.rooms.handle(last(j,"ack"));
         check(count(h,"seal")==seals,"ACK does not create a redundant second barrier");
         check(h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld && h.game.roomKey()==A && j.game.roomKey()==D,"both destinations settle after one barrier");
         check(Log.errors.length==0,"covered request is consumed without error");
      }
      private function updatedRequest():void {
         label="distinct queued request survives older READY";setup();
         h.game.setRoom(A);frame();j.session.rooms.handle(last(h,"seal"));var ready:Object=last(j,"ready");
         j.game.setRoom(D);frame();var request:Object=last(j,"request");
         // Explicit component robustness case: a queued destination is newer
         // than the READY under examination. This is not a TCP reordering claim.
         h.session.rooms.handle(request);h.session.rooms.handle(ready);var oldGrant:Object=last(h,"grant");
         check(request.info.roomKey!=ready.info.roomKey,"queued request is not covered by this READY");
         j.session.rooms.handle(oldGrant);h.session.rooms.handle(last(j,"ack"));
         var seal:Object=last(h,"seal");check(seal.barrier>oldGrant.barrier,"different destination remains queued after ACK");
         clearMessages();finish(seal);
         check(j.game.roomKey()==D && j.session.rooms.canSyncWorld && !j.game.roomHold,"new destination receives its own usable grant");
         check(Log.errors.length==0,"newer request is not lost");
      }
      private function rawPair():void {
         for each(var m:RConnectMod in mods){m.session.mode=Session.OFFLINE;m.session.rooms.reset();}
         mods=[];Log.errors=[];h=make(Session.HOSTING);j=make(Session.CONNECTED);
      }
      private function sealBeforeCheck():void {
         label="seal reaches completed native world before first check";rawPair();
         // Join generation is still pending at the host frame. Its constructor
         // returns before the queued seal callback, without an intervening frame.
         j.game.transition=true;frame();var seal:Object=last(h,"seal");
         j.game.transition=false;clearMessages();j.session.rooms.handle(seal);
         var ready:Object=last(j,"ready"),epoch:int=j.session.rooms.epoch;
         check(count(j,"request")==0 && ready.info.roomKey==X,"seal directly sends READY for the current native room");
         frame();
         check(count(j,"request")==0 && count(j,"ready")==1,"next frame does not rediscover the READY destination");
         check(j.session.rooms.epoch==epoch && j.game.roomEpoch==epoch,"marking observation does not advance epoch");
         h.session.rooms.handle(ready);
         // Preserve actual stream order: READY is followed by any redundant
         // frame-generated request, before the acknowledgement of its grant.
         for each(var late:Object in messages(j))if(late.op=="request")h.session.rooms.handle(late);
         j.session.rooms.handle(last(h,"grant"));h.session.rooms.handle(last(j,"ack"));
         check(count(h,"seal")==0 && h.session.rooms.canSyncWorld && j.session.rooms.canSyncWorld,"one grant and ACK settle without a second seal");
         check(j.session.rooms.stamp({}).roomKey==X && !j.session.rooms.authority,"normal settled room and mirror ownership are unchanged");
         check(Log.errors.length==0,"seal-first ordering has no protocol error");
      }
      private function realChangesAfterReady():void {
         label="real departures remain observable after READY";setup();
         var epoch:int=j.session.rooms.epoch;
         j.game.setRoom(D);frame();
         check(count(j,"request")==1 && last(j,"request").info.roomKey==D,"actual crossing to D still requests once");
         pump();frame();pump();check(j.session.rooms.canSyncWorld && j.game.roomKey()==D,"D completes its independent ownership barrier");
         clearMessages();j.game.setRoom(B);frame();
         check(count(j,"request")==1 && last(j,"request").info.roomKey==B,"return to prior B is a new request");
         pump();frame();pump();check(j.session.rooms.canSyncWorld && j.game.roomKey()==B,"revisited B completes normally");
         check(j.session.rooms.epoch==epoch && h.session.rooms.epoch==epoch,"ordinary room changes retain map epoch");
         clearMessages();var oldLand:Object=j.game.world.land,oldRoom:Object=j.game.loc;
         j.game.world.land={act:{id:"map"},loc_t:0};j.game.setRoom(B);frame();
         check(j.game.world.land!==oldLand && j.game.loc!==oldRoom && j.game.roomKey()==B,"fixture replaced native Land and room while keeping their text key");
         check(count(j,"request")==1 && last(j,"request").info.roomKey==B,"replacement Land with identical key still requests");
         check(j.game.roomHold && !j.session.rooms.canSyncWorld,"replacement identity is not silently treated as settled");
         check(Log.errors.length==0,"identity observation does not itself fail or fabricate an epoch");
      }
      private function restrictedSealFirst():void {
         label="restricted departure still returns after seal-first READY";setup();
         var oldRoom:Object=j.game.loc,epoch:int=j.session.rooms.epoch;
         j.game.setRoom(D);j.game.loc.restricted=true;
         h.session.rooms.handle({type:"room",op:"request",epoch:epoch,info:j.game.readWorldInfo()});
         j.session.rooms.handle(last(h,"seal"));
         check(count(j,"ready")==1 && j.game.roomKey()==D,"fixture delivers seal before restricted-room frame check");
         frame();
         check(TravelGuard.returns==1 && j.game.loc===oldRoom,"original restricted-room guard returns to settled B");
         check(count(j,"request")==0,"rejected restricted destination does not emit a crossing request");
         check(j.session.rooms.epoch==epoch && j.session.rooms.stamp({}).roomKey==B,"restriction preserves epoch and previously settled key");
         check(Log.errors.length==0,"restricted path retains the original check semantics");
      }
      private function begin(e:Event):void {
         try{joinCross(true);joinCross(false);hostCross(true);hostCross(false);hostQueuedPrelude();coveredRequest();updatedRequest();wrongLand();sealBeforeCheck();realChangesAfterReady();restrictedSealFirst();}
         catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
