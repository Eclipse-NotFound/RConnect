package rconnect.game {
   /** Pure presentation math. No simulation, damage, creation or wire changes. */
   public class ProjectilePlayback {
      private static const SMOOTH_FIELDS:Array=["x","y","sx","sy","a","ls"];
      /** Only interpolate between received points. Native movie frames remain
       * discrete; translation and same-sign transform changes are continuous. */
      public static function sample(flight:Object,time:Number,out:Object=null):Object {
         var frames:Array=flight.frames as Array;
         if(frames==null || frames.length==0 || time<Number(frames[0].at)
            || (int(flight.end)>0 && time>=Number(flight.end)))return null;
         var point:Object=frames[0],next:Object=null;
         for each(var frame:Object in frames){if(Number(frame.at)>time){next=frame;break;}point=frame;}
         if(next==null)return point;
         var span:Number=Number(next.at)-Number(point.at);
         var t:Number=span>0?Math.max(0,Math.min(1,(time-Number(point.at))/span)):0;
         if(t<=0)return point;
         // A sign change is an authored flip, not a scale through zero.
         if(Number(point.sx)*Number(next.sx)<=0 || Number(point.sy)*Number(next.sy)<=0)return point;
         if(out==null)out={};for(var key:String in point)out[key]=point[key];
         for each(key in SMOOTH_FIELDS)
            out[key]=Number(point[key])+(Number(next[key])-Number(point[key]))*t;
         var angle:Number=(Number(next.rot)-Number(point.rot)+540)%360-180;
         out.rot=Number(point.rot)+angle*t;
         return out;
      }
   }
}
