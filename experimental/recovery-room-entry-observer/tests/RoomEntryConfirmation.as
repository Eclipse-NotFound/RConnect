package {
   /** External observation only. A host's local commit and its peer's ACK are
    * separate facts. Nothing here changes RoomSync, native pause or packets. */
   public final class RoomEntryConfirmation {
      public var room:Object,land:Object,stamp:Object;
      public var peerAcknowledged:Boolean=false;
      private var travelId:String="";

      public function reset():void {
         room=null;land=null;stamp=null;peerAcknowledged=false;travelId="";
      }
      private function identity(v:Object):Boolean {
         return v!=null && v.room!=null && v.land!=null && v.room===v.gameRoom
            && v.room===v.landRoom && v.room===v.playerRoom;
      }
      private function currentStamp(v:Object):Boolean {
         return v.stamp!=null && String(v.key)!="" && String(v.stamp.roomKey)==String(v.key)
            && int(v.stamp.roomEpoch)==int(v.epoch) && int(v.stamp.roomTerm)==int(v.term)
            && int(v.term)>0 && int(v.epoch)>0;
      }
      public function same(v:Object):Boolean {
         return identity(v) && currentStamp(v) && stamp!=null && room===v.room && land===v.land
            && String(stamp.roomKey)==String(v.stamp.roomKey)
            && int(stamp.roomEpoch)==int(v.stamp.roomEpoch) && int(stamp.roomTerm)==int(v.stamp.roomTerm);
      }
      public function observe(host:Boolean,p:Object,v:Object):Boolean {
         if(p==null || p.type!="room" || !identity(v) || !currentStamp(v)
            || v.ready!==true || v.busy!==false || v.canSync!==true
            || int(p.barrier)!=int(v.term))return false;
         if(host && p.op=="ack") {
            // An ACK cannot invent local confirmation, nor confirm a different
            // native object with the same textual key or a previous generation.
            if(!same(v) || String(p.travelId || "")!=travelId)return false;
            peerAcknowledged=true;return true;
         }
         if(host) {
            if(p.op!="ready" || v.authority!==true)return false;
         }else {
            if(p.op!="grant" || String(p.key)!=String(v.key) || int(p.term)!=int(v.term))return false;
         }
         if(int(p.epoch)!=int(v.epoch))return false;
         var duplicate:Boolean=same(v) && travelId==String(p.travelId || "");
         room=v.room;land=v.land;
         stamp={roomKey:String(v.stamp.roomKey),roomEpoch:int(v.stamp.roomEpoch),roomTerm:int(v.stamp.roomTerm)};
         travelId=String(p.travelId || "");
         if(!duplicate)peerAcknowledged=false;
         return true;
      }
   }
}
