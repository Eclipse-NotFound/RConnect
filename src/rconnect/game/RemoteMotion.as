package rconnect.game
{
   /** A short source-time buffer absorbs packet jitter without restarting a tween.
    *  Never extrapolate beyond received positions; teleports settle at once.
    *  Unstamped room checkpoints/legacy callers retain endpoint interpolation. */
   public class RemoteMotion
   {
      private var state:Object;
      private var origin:Object;
      private var target:Object;
      private var at:int;
      private var duration:int=50;
      private var interval:int;
      private var immediateStart:Boolean;
      private var bufferLimit:int=0;
      // Only immediately visible drops use packet-burst buffering. A grab
      // has a separate low-latency policy, and avatar clocks stay unchanged.
      private var firstSample:Boolean=true;
      private var dropDelay:Number=0;
      private var frames:Array=[];
      private var gaps:Array=[];
      private var offset:Number=0;
      private var cursor:Number=0;
      private var sampledAt:int=0;
      private var arrivedAt:int=0;
      private var selected:Object;
      private var preceding:Object;
      private static const FIELDS:Array=["x","y","aimX","aimY"];

      public function RemoteMotion(intervalMs:int=50,startImmediately:Boolean=false) {
         interval=intervalMs;immediateStart=startImmediately;
      }

      /** High-rate held objects have their own presentation clock. A single
       * slow native frame must not leave a quarter-second delay on the drag.
       * This policy still interpolates only received positions, with the same
       * continuous clock and pause/release behavior as ordinary streams. */
      public static function held():RemoteMotion {
         var motion:RemoteMotion=new RemoteMotion(50);motion.bufferLimit=100;return motion;
      }

      public function push(snap:Object, now:int):void
      {
         if(snap.sampleTime!=null && isFinite(Number(snap.sampleTime))) {
            pushTimed(snap,now);return;
         }
         var previous:Object=sample(now);
         frames=[];
         preceding=null;
         var jump:Boolean=previous==null || now-at>1000;
         if(previous!=null)
         {
            var dx:Number=Number(snap.x)-Number(previous.x), dy:Number=Number(snap.y)-Number(previous.y);
            jump=jump || dx*dx+dy*dy>600*600;
         }
         duration=Math.max(50,Math.min(250,now-at));
         origin={};target={};state={};
         for(var key:String in snap) state[key]=snap[key];
         for each(key in FIELDS)
         {
            target[key]=Number(snap[key]);
            origin[key]=jump || previous[key]==null ? target[key] : Number(previous[key]);
         }
         at=now;
         sample(now);
      }

      public function sample(now:int):Object
      {
         if(frames.length>0)return sampleTimed(now);
         if(state==null) return null;
         var t:Number=Math.max(0,Math.min(1,(now-at)/duration));
         for each(var key:String in FIELDS)
            if(isFinite(target[key])) state[key]=origin[key]+(target[key]-origin[key])*t;
         return state;
      }

      /** Shared display cursor for this avatar's weapon and projectile frames. */
      public function get sourceTime():Number {return frames.length>0?cursor:NaN;}

      /** A paused world may still receive its last in-flight snapshots. Close
       * the display buffer at the received endpoint, without extrapolation.
       * Retain that cursor so resume cannot replay the pre-pause position. */
      public function settle(now:int):Object {
         if(frames.length>0) {
            cursor=Number(frames[frames.length-1].at);
            return sampleTimed(now);
         }
         if(state==null)return null;
         at=now-duration;
         return sample(now);
      }

      private function pushTimed(snap:Object,now:int):void {
         var copy:Object={};for(var key:String in snap)copy[key]=snap[key];snap=copy;
         var stamp:Number=Number(snap.sampleTime),last:Object=frames.length?frames[frames.length-1]:null;
         var clockOffset:Number=now-stamp;
         var dx:Number=last==null?0:Number(snap.x)-Number(last.snap.x);
         var dy:Number=last==null?0:Number(snap.y)-Number(last.snap.y);
         var port:Boolean=last!=null && last.snap.roomKey==snap.roomKey && last.snap.roomEpoch==snap.roomEpoch
            && TeleportVisuals.split(last.snap,snap,stamp)!=null;
         if(last==null || now-arrivedAt>1000 || stamp-Number(last.at)>1000
            || clockOffset<offset-Math.max(250,interval*2) || (!port && dx*dx+dy*dy>600*600)) {
            frames=[];gaps=[];selected=null;state=null;preceding=null;firstSample=true;dropDelay=0;
            offset=clockOffset;cursor=stamp-(immediateStart?0:delay());sampledAt=now;
         } else {
            // Host world broadcasts can repeat an unchanged peer snapshot.
            // They must not restart either movement or the animation clock.
            if(stamp<Number(last.at))return;
            if(stamp==Number(last.at)) {last.snap=snap;return;}
            // Initial room transfer can deliver an old frame first. Calibrate
            // from fresher arrivals instead of retaining that startup delay.
            var previousOffset:Number=offset;
            offset=Math.min(offset,clockOffset);
            // A newborn drop may receive several native positions in one
            // socket callback. Seeking its cursor here discards the entire
            // short arc and leaves it motionless until the next packet batch.
            if(!immediateStart)cursor+=previousOffset-offset;
            if(immediateStart)dropDelay=Math.min(500,Math.max(dropDelay,(now-arrivedAt)*1.25));
            gaps.push(stamp-Number(last.at));if(gaps.length>8)gaps.shift();
         }
         arrivedAt=now;frames.push({at:stamp,snap:snap});
         if(frames.length>32)preceding=frames.shift();
      }

      private function delay():Number {
         var value:Number=bufferLimit>0?interval*1.5:Math.max(100,interval*1.5);
         for each(var gap:Number in gaps)value=Math.max(value,gap*1.25);
         // Automatic falling arcs can absorb a slow delivery burst. The
         // delay follows observed traffic, capped at half a second; regular
         // 20 Hz drops retain their usual 100 ms target and never extrapolate.
         if(immediateStart)return Math.min(500,Math.max(value,dropDelay));
         return Math.min(bufferLimit>0?bufferLimit:Math.max(250,interval*3),value);
      }

      private function sampleTimed(now:int):Object {
         // Retain the first received arc instead of consuming a coalesced batch.
         if(firstSample && immediateStart)dropDelay=Math.min(500,Math.max(dropDelay,Number(frames[frames.length-1].at)-Number(frames[0].at)));
         firstSample=false;
         var elapsed:Number=Math.max(0,now-sampledAt);sampledAt=Math.max(sampledAt,now);
         var wanted:Number=now-offset-delay(),next:Number=cursor+elapsed;
         // Adjust buffer depth by slightly changing playback speed, never by
         // rewinding the avatar when a slower packet interval is observed.
         cursor=next+Math.max(-elapsed*.1,Math.min(elapsed*.1,wanted-next));
         var latest:Object=frames[frames.length-1];
         cursor=Math.min(cursor,Number(latest.at));
         while(frames.length>2 && Number(frames[1].at)<=cursor)preceding=frames.shift();
         var a:Object=frames[0],b:Object=frames.length>1?frames[1]:a;
         if(cursor>=Number(b.at))a=b;
         var crossing:Object=TeleportVisuals.split(a.snap,b.snap,cursor);
         var chosen:Object=crossing==null?a.snap:crossing.snapshot;
         if(selected!==chosen) {
            selected=chosen;state={};for(var key:String in selected)state[key]=selected[key];
         }
         if(crossing!=null) {
            state.x=crossing.x;state.y=crossing.y;
            // Native teleport changes world position immediately. Weapon and
            // body poses come from the matching side of that discontinuity.
            state.weapons=chosen.weapons;
            return state;
         }
         var span:Number=Number(b.at)-Number(a.at);
         var t:Number=span>0?Math.max(0,Math.min(1,(cursor-Number(a.at))/span)):0;
         for each(key in FIELDS) {
            var first:Number=Number(a.snap[key]),last:Number=Number(b.snap[key]);
            if(isFinite(first) && isFinite(last))state[key]=interval<=50 && span>0
               ? curve(key,a,b,t,span) : first+(last-first)*t;
         }
         if(a.snap.weapons is Array && b.snap.weapons is Array)
            state.weapons=WeaponDisplay.interpolate(a.snap.weapons as Array,b.snap.weapons as Array,t);
         return state;
      }

      /** Shape-preserving cubic interpolation makes velocity continuous across
       * high-rate samples. It stays within the two received endpoints, stops
       * at real direction changes, and adds no prediction or display delay. */
      private function curve(key:String,a:Object,b:Object,t:Number,h:Number):Number {
         var first:Number=Number(a.snap[key]),last:Number=Number(b.snap[key]);
         var slope:Number=(last-first)/h,left:Number=slope,right:Number=slope;
         if(preceding!=null && Number(preceding.at)<Number(a.at) && isFinite(Number(preceding.snap[key]))) {
            var hp:Number=Number(a.at)-Number(preceding.at);
            left=tangent((first-Number(preceding.snap[key]))/hp,slope,hp,h);
         }
         var following:Object=frames.length>2?frames[2]:null;
         if(following!=null && Number(following.at)>Number(b.at) && isFinite(Number(following.snap[key]))) {
            var hn:Number=Number(following.at)-Number(b.at);
            right=tangent(slope,(Number(following.snap[key])-last)/hn,h,hn);
         }
         var square:Number=t*t,cube:Number=square*t;
         var value:Number=(2*cube-3*square+1)*first+(cube-2*square+t)*h*left
            +(-2*cube+3*square)*last+(cube-square)*h*right;
         return Math.max(Math.min(first,last),Math.min(Math.max(first,last),value));
      }
      private static function tangent(a:Number,b:Number,ha:Number,hb:Number):Number {
         if(a*b<=0)return 0;
         var wa:Number=2*hb+ha,wb:Number=hb+2*ha;
         return (wa+wb)/(wa/a+wb/b);
      }
   }
}
