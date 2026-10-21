package rconnect.game {
   /** Incremental native display samples. Never invent motion or impact events. */
   public final class ProjectileFrameStreamBefore {
      /** A projectile outlives its shooter. When the owner's motion clock is
       * removed on death, continue from its last displayed source time rather
       * than retaining a frozen clock or jumping to a different delay. */
      public static function receiveClock(state:Object,motion:RemoteMotionBefore,offset:Number,delay:Number,now:int):void {
         if(state.clockReady===true && state.motion!==motion) {
            var previous:Number=sourceTime(state,now);
            state.detachedOffset=motion==null && isFinite(previous)?now-previous-delay:NaN;
         }
         if(state.clockReady!==true){state.clockAt=now;state.clockReady=true;}
         var detached:Number=state.detachedOffset==null?NaN:Number(state.detachedOffset);
         state.motion=motion;state.delay=delay;state.offset=isFinite(detached)?detached:offset;
      }
      public static function sourceTime(state:Object,now:int):Number {
         var time:Number=state.motion!=null?state.motion.sourceTime:NaN;
         return isFinite(time)?time:now-Number(state.offset)-Number(state.delay);
      }
      /** No later packet is guaranteed after a shooter leaves this room.
       * Anchor the fallback to the last displayed cursor, not the latest
       * received endpoint. Call with the effective paused time when stopped. */
      public static function detachClock(state:Object,now:int):void {
         if(state==null || state.motion==null)return;
         receiveClock(state,null,Number(state.offset),Number(state.delay),now);
         // This fallback starts here, even if its event arrived mid-pause.
         // Resume must subtract the pause interval from this new anchor.
         state.clockAt=now;
      }
      public static function shiftClock(state:Object,elapsed:int):void {
         state.offset=Number(state.offset)+elapsed;
         if(state.detachedOffset!=null && isFinite(Number(state.detachedOffset)))
            state.detachedOffset=Number(state.detachedOffset)+elapsed;
      }
      /** Capture rebuilds point objects even when their visible values stay
       * unchanged. Object identity alone would resend a paused pose forever. */
      public static function samePoint(a:Object,b:Object):Boolean {
         if(a===b)return true;
         if(a==null || b==null)return false;
         var fields:int=0,otherFields:int=0;
         for(var key:String in a) {
            fields++;
            var left:*=a[key],right:*=b[key];
            if(left is Array && right is Array) {
               if(left.length!=right.length)return false;
               for(var i:int=0;i<left.length;i++)if(left[i]!==right[i])return false;
            } else if(left!==right)return false;
         }
         for(key in b)otherFields++;
         return fields==otherFields;
      }
      public static function after(frames:Array,stamp:Number):Array {
         var out:Array=[];
         for each(var point:Object in frames)if(Number(point.at)>stamp)out.push(point);
         return out;
      }
      /** Same result as after() followed by the first changed same-stamp
       * point. Keep input order, including duplicate or out-of-order samples;
       * only the history traversal is shared. */
      public static function afterWithRevision(frames:Array,stamp:Number,previous:Object,revisionStamp:Number):Array {
         var out:Array=[],revised:Object=null;
         for each(var point:Object in frames) {
            var at:Number=Number(point.at);
            if(at>stamp)out.push(point);
            if(revised==null && previous!=null && at==revisionStamp && !samePoint(point,previous))revised=point;
         }
         if(revised!=null)out.unshift(revised);
         return out;
      }
      public static function merge(previous:Array,incoming:Array):Array {
         if(previous==null||previous.length==0)return incoming==null?[]:incoming.concat();
         if(incoming==null||incoming.length==0)return previous;
         var out:Array=previous.concat(),last:Number=Number(out[out.length-1].at);
         for each(var point:Object in incoming) {
            var stamp:Number=Number(point.at);
            if(!isFinite(stamp)||stamp<last)continue;
            if(stamp==last)out[out.length-1]=point;
            else {out.push(point);last=stamp;}
         }
         if(out.length>64)out.splice(0,out.length-64);
         return out;
      }
   }
}
