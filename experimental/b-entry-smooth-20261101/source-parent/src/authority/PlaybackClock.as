package authority {
   /** One source timeline for the entire visible room, never one per entity. */
   public final class PlaybackClock {
      public var delay:Number=65,position:Number=0,current:Object,next:Object;
      public var queued:uint=0,underflows:uint=0;
      private var pending:Array=[],offset:Number=NaN,last:Object;
      private var intervals:Array=[],jitter:Array=[];
      private function pace(frame:Object,estimate:Number,boundary:Boolean):void {
         if(boundary){intervals=[];jitter=[];return;}
         if(last==null || last.paused || frame.paused)return;
         var interval:Number=frame.time-last.time;
         if(interval<=0 || interval>1000)return;
         intervals.push(interval);jitter.push(Math.max(0,estimate-offset));
         if(intervals.length>32){intervals.shift();jitter.shift();}
         if(intervals.length<4)return;
         var gaps:Array=intervals.concat().sort(Array.NUMERIC),late:Array=jitter.concat().sort(Array.NUMERIC);
         // A fixed 65 ms buffer repeatedly runs dry when the host needs
         // 100+ ms for a dense scene. Keep roughly one observed source frame
         // plus bounded arrival jitter, without predicting combat outcomes.
         var wanted:Number=Math.max(65,Math.min(250,gaps[int((gaps.length-1)*.9)]+late[int((late.length-1)*.9)]+15));
         // Fill promptly when cadence slows; drain gently when it recovers.
         // take() never moves the displayed source time backwards.
         delay=wanted>delay?wanted:Math.max(wanted,delay-2);
      }
      public function push(frame:Object,now:Number):Boolean {
         if(!isFinite(frame.time) || last!=null && frame.time<last.time)throw new Error("Invalid source presentation time");
         var boundary:Boolean=last==null || frame.room!==last.room || frame.pauseEpoch!=last.pauseEpoch;
         if(last!=null && frame.timeControl!=null && last.timeControl!=null &&
            (frame.timeControl.phase!==last.timeControl.phase || frame.timeControl.cycle!==last.timeControl.cycle))boundary=true;
         if(last!=null)for(var i:int=0;i<frame.players.length;i++)
            if(frame.players[i].epoch!=last.players[i].epoch || frame.players[i].roomEpoch!=last.players[i].roomEpoch)boundary=true;
         // Minimum observed arrival offset removes queue jitter without ever
         // claiming that a late packet describes the current simulation time.
         var estimate:Number=now-frame.time;
         if(isNaN(offset) || estimate<offset)offset=estimate;
         pace(frame,estimate,boundary);
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
