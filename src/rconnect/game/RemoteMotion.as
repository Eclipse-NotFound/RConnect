package rconnect.game
{
   /** Render each received movement over its measured packet interval.
    *  Never extrapolate beyond the last known position; teleports settle at once. */
   public class RemoteMotion
   {
      private var state:Object;
      private var origin:Object;
      private var target:Object;
      private var at:int;
      private var duration:int=50;
      private static const FIELDS:Array=["x","y","aimX","aimY"];

      public function push(snap:Object, now:int):void
      {
         var previous:Object=sample(now);
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
         if(state==null) return null;
         var t:Number=Math.max(0,Math.min(1,(now-at)/duration));
         for each(var key:String in FIELDS)
            if(isFinite(target[key])) state[key]=origin[key]+(target[key]-origin[key])*t;
         return state;
      }
   }
}
