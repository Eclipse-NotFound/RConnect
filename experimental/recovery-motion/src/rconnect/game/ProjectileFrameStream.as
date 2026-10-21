package rconnect.game {
   /** Incremental native display samples. Never invent motion or impact events. */
   public final class ProjectileFrameStream {
      public static function after(frames:Array,stamp:Number):Array {
         var out:Array=[];
         for each(var point:Object in frames)if(Number(point.at)>stamp)out.push(point);
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
