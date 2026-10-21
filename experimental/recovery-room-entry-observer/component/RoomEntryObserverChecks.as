package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   public final class RoomEntryObserverChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function RoomEntryObserverChecks() {
         try {run();}catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows}));stream.close();
         NativeApplication.nativeApplication.exit(failed==0?0:1);
      }
      private function check(value:Boolean,label:String):void {
         rows.push({passed:value,label:label});if(!value)failed++;
      }
      private function view(term:int=7,epoch:int=3,key:String="map//room"):Object {
         var room:Object={},land:Object={};
         return {room:room,land:land,gameRoom:room,landRoom:room,playerRoom:room,key:key,
            stamp:{roomKey:key,roomEpoch:epoch,roomTerm:term},term:term,epoch:epoch,
            ready:true,busy:false,canSync:true,authority:true};
      }
      private function packet(op:String="ready",term:int=7,epoch:int=3,key:String="map//room",travel:String=""):Object {
         return {type:"room",op:op,barrier:term,term:term,epoch:epoch,key:key,travelId:travel};
      }
      private function run():void {
         var o:RoomEntryConfirmation=new RoomEntryConfirmation(),v:Object=view(),p:Object=packet();
         check(!o.same(v),"before READY: real native identity alone is not a local commit");
         check(!o.observe(true,packet("ack"),v),"ACK cannot create a previously unobserved commit");
         v.ready=false;check(!o.observe(true,p,v),"READY before production ready is rejected");
         v.ready=true;v.busy=true;check(!o.observe(true,p,v),"READY before production release is rejected");
         v.busy=false;v.canSync=false;check(!o.observe(true,p,v),"READY without current settled native room is rejected");
         v.canSync=true;v.authority=false;check(!o.observe(true,p,v),"host READY without host authority is rejected");
         v.authority=true;
         check(!o.observe(true,packet("ready",6),v),"old READY term cannot approve current native room");
         check(!o.observe(true,packet("ready",8),v),"future READY term cannot approve current native room");
         check(!o.observe(true,packet("ready",7,2),v),"old READY epoch cannot approve current native room");
         v.stamp.roomKey="old//room";check(!o.observe(true,p,v),"old settled room key is rejected");
         v.stamp.roomKey=v.key;v.stamp.roomTerm=6;check(!o.observe(true,p,v),"old settled term is rejected");
         v.stamp.roomTerm=7;v.stamp.roomEpoch=2;check(!o.observe(true,p,v),"old settled epoch is rejected");
         v.stamp.roomEpoch=3;v.gameRoom={};check(!o.observe(true,p,v),"game and world native identities must agree");
         v.gameRoom=v.room;v.landRoom={};check(!o.observe(true,p,v),"land native identity must agree");
         v.landRoom=v.room;v.playerRoom={};check(!o.observe(true,p,v),"player native identity must agree");
         v.playerRoom=v.room;
         check(o.observe(true,p,v),"ACK-before window: actual post-READY host commit is accepted");
         check(o.same(v),"ACK-before window: exact native identity epoch and term are confirmed");
         check(!o.peerAcknowledged,"ACK-before window: local commit never fabricates a peer ACK");
         check(!(p.op=="ack"),"legacy scene12 host condition misses this genuine READY commit");
         v.stamp.roomKey="mutated";check(o.stamp.roomKey=="map//room","confirmed stamp is a value copy");
         v.stamp.roomKey=v.key;
         check(!o.observe(true,packet("ack",6),v) && !o.peerAcknowledged,"old ACK term cannot acknowledge this commit");
         check(o.observe(true,packet("ack"),v) && o.peerAcknowledged,"exact later ACK confirms peer independently");
         check(o.observe(true,p,v) && o.peerAcknowledged,"duplicate READY preserves observed ACK");
         v.busy=true;v.canSync=false;
         check(o.same(v),"remote-only pending handshake does not hide previously confirmed native identity");
         v.busy=false;v.canSync=true;
         var next:Object=view(8,3,"map//next");
         check(!o.same(next),"new native room is unconfirmed before its READY");
         check(!o.observe(true,packet("ack",8,3,"map//next"),next),"new-room ACK cannot transfer old confirmation");
         check(o.observe(true,packet("ready",8,3,"map//next"),next) && !o.peerAcknowledged,
            "new-room READY commits its own identity and clears previous peer ACK");
         check(!o.same(v),"previous room cannot reuse the new room confirmation");
         var recreated:Object=view(8,3,"map//next");
         check(!o.same(recreated),"same textual room and term but new native objects stay unconfirmed");
         check(!o.observe(true,packet("ack",8,3,"map//next"),recreated),"ACK cannot bless reconstructed native objects");
         next.stamp.roomEpoch=4;next.epoch=4;
         check(!o.same(next),"new epoch invalidates even retained native object pointers");
         check(!o.observe(true,packet("ready",8,3,"map//next"),next),"old epoch READY remains rejected after epoch change");
         o.reset();check(o.room==null && o.stamp==null && !o.peerAcknowledged,"new connection clears both confirmation facts");
         check(!o.observe(true,packet("ack"),v),"new connection cannot inherit the old ACK");
         var client:Object=view();
         check(!o.observe(false,packet(),client),"client never treats peer READY as its grant");
         check(!o.observe(false,packet("grant",7,3,"map//wrong"),client),"client wrong-room grant rejected");
         client.busy=true;
         check(!o.observe(false,packet("grant"),client),"client grant still restoring cannot be reported released");
         client.busy=false;
         check(o.observe(false,packet("grant"),client) && o.same(client),"settled exact client grant is retained");
         check(!o.peerAcknowledged,"client grant is not mislabeled received peer ACK");
         o.reset();p=packet("ready",7,3,"map//room","travel-current");
         check(o.observe(true,p,v),"native travel READY stores its actual travel identity");
         check(!o.observe(true,packet("ack",7,3,"map//room","travel-old"),v),"old-travel ACK rejected despite matching term");
         check(o.observe(true,packet("ack",7,3,"map//room","travel-current"),v),"matching native-travel ACK accepted");
         check(!o.observe(true,{type:"worldstate",op:"ready",barrier:7,epoch:3},v),"non-room payload cannot approve a scene");
      }
   }
}
