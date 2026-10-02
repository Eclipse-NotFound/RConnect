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
      private var frames:Array=[];
      private var gaps:Array=[];
      private var offset:Number=0;
      private var cursor:Number=0;
      private var sampledAt:int=0;
      private var arrivedAt:int=0;
      private var selected:Object;
      private static const FIELDS:Array=["x","y","aimX","aimY"];

      public function RemoteMotion(intervalMs:int=50) {interval=intervalMs;}

      public function push(snap:Object, now:int):void
      {
         if(snap.sampleTime!=null && isFinite(Number(snap.sampleTime))) {
            pushTimed(snap,now);return;
         }
         var previous:Object=sample(now);
         frames=[];
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

      private function pushTimed(snap:Object,now:int):void {
         var copy:Object={};for(var key:String in snap)copy[key]=snap[key];snap=copy;
         var stamp:Number=Number(snap.sampleTime),last:Object=frames.length?frames[frames.length-1]:null;
         var clockOffset:Number=now-stamp;
         var dx:Number=last==null?0:Number(snap.x)-Number(last.snap.x);
         var dy:Number=last==null?0:Number(snap.y)-Number(last.snap.y);
         if(last==null || now-arrivedAt>1000 || stamp-Number(last.at)>1000
            || clockOffset<offset-Math.max(250,interval*2) || dx*dx+dy*dy>600*600) {
            frames=[];gaps=[];selected=null;state=null;
            offset=clockOffset;cursor=stamp-delay();sampledAt=now;
         } else {
            // Host world broadcasts can repeat an unchanged peer snapshot.
            // They must not restart either movement or the animation clock.
            if(stamp<Number(last.at))return;
            if(stamp==Number(last.at)) {last.snap=snap;return;}
            // Initial room transfer can deliver an old frame first. Calibrate
            // from fresher arrivals instead of retaining that startup delay.
            offset=Math.min(offset,clockOffset);
            gaps.push(stamp-Number(last.at));if(gaps.length>8)gaps.shift();
         }
         arrivedAt=now;frames.push({at:stamp,snap:snap});
         if(frames.length>32)frames.shift();
      }

      private function delay():Number {
         var value:Number=Math.max(100,interval*1.5);
         for each(var gap:Number in gaps)value=Math.max(value,gap*1.25);
         return Math.min(Math.max(250,interval*3),value);
      }

      private function sampleTimed(now:int):Object {
         var elapsed:Number=Math.max(0,now-sampledAt);sampledAt=Math.max(sampledAt,now);
         var wanted:Number=now-offset-delay(),next:Number=cursor+elapsed;
         // Adjust buffer depth by slightly changing playback speed, never by
         // rewinding the avatar when a slower packet interval is observed.
         cursor=next+Math.max(-elapsed*.1,Math.min(elapsed*.1,wanted-next));
         var latest:Object=frames[frames.length-1];
         cursor=Math.min(cursor,Number(latest.at));
         while(frames.length>2 && Number(frames[1].at)<=cursor)frames.shift();
         var a:Object=frames[0],b:Object=frames.length>1?frames[1]:a;
         if(cursor>=Number(b.at))a=b;
         if(selected!==a.snap) {
            selected=a.snap;state={};for(var key:String in selected)state[key]=selected[key];
         }
         var span:Number=Number(b.at)-Number(a.at);
         var t:Number=span>0?Math.max(0,Math.min(1,(cursor-Number(a.at))/span)):0;
         for each(key in FIELDS) {
            var first:Number=Number(a.snap[key]),last:Number=Number(b.snap[key]);
            if(isFinite(first) && isFinite(last))state[key]=first+(last-first)*t;
         }
         return state;
      }
   }
}
