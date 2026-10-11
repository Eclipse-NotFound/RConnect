package authority {
   /** One source timeline for the entire visible room, never one per entity. */
   public final class PlaybackClock {
      public var delay:Number=65,position:Number=0,current:Object,next:Object;
      public var queued:uint=0,underflows:uint=0;
      private var pending:Array=[],offset:Number=NaN,last:Object;
      public function push(frame:Object,now:Number):Boolean {
         if(!isFinite(frame.time) || last!=null && frame.time<last.time)throw new Error("Invalid source presentation time");
         var boundary:Boolean=last==null || frame.room!==last.room || frame.pauseEpoch!=last.pauseEpoch;
         if(last!=null)for(var i:int=0;i<frame.players.length;i++)
            if(frame.players[i].epoch!=last.players[i].epoch || frame.players[i].roomEpoch!=last.players[i].roomEpoch)boundary=true;
         // Minimum observed arrival offset removes queue jitter without ever
         // claiming that a late packet describes the current simulation time.
         var estimate:Number=now-frame.time;
         if(isNaN(offset) || estimate<offset)offset=estimate;
         pending.push(frame);last=frame;queued=pending.length;
         return boundary;
      }
      public function take(now:Number,flush:Boolean=false):Array {
         var out:Array=[];
         if(last==null)return out;
         var target:Number=flush?last.time:Math.min(last.time,now-offset-delay);
         position=Math.max(position,target);
         while(pending.length>0 && (current==null || pending[0].time<=position)) {
            current=pending.shift();out.push(current);
         }
         next=pending.length==0?null:pending[0];queued=pending.length;
         if(next==null && !last.paused)++underflows;
         return out;
      }
      public function get fraction():Number {
         if(current==null || next==null || next.time<=current.time || current.paused)return 0;
         return Math.max(0,Math.min(1,(position-current.time)/(next.time-current.time)));
      }
   }
}
