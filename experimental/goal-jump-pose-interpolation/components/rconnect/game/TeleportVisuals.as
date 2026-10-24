package rconnect.game {
   public class TeleportVisuals {
      private static function valid(e:Object):Boolean {
         if(e==null || int(e.seq)<=0 || !isFinite(Number(e.at)))return false;
         for each(var k:String in ["fromX","fromY","toX","toY","postX","postY","scX","scY"])
            if(e[k]==null || !isFinite(Number(e[k])))return false;
         return Number(e.scX)>0 && Number(e.scY)>0 && Number(e.scX)<=1000 && Number(e.scY)<=1000;
      }
      public static function split(a:Object,b:Object,time:Number):Object {
         if(a==null || b==null || b.port==null || !(b.port.events is Array))return null;
         var first:Number=Number(a.sampleTime),last:Number=Number(b.sampleTime);
         if(!isFinite(first+last+time) || last<=first)return null;
         var x0:Number=Number(a.x),y0:Number=Number(a.y),x1:Number=Number(b.x),y1:Number=Number(b.y);
         var t0:Number=first,t1:Number=last,found:Boolean=false,after:Boolean=false,edge:Number=NaN;
         for each(var e:Object in b.port.events) {
            if(!valid(e) || Number(e.at)<=first || Number(e.at)>last ||
               String(e.roomKey)!=String(b.roomKey) || int(e.roomEpoch)!=int(b.roomEpoch))continue;
            found=true;edge=Number(e.at);
            if(time<Number(e.at)) {x1=Number(e.fromX);y1=Number(e.fromY);t1=Number(e.at);break;}
            x0=Number(e.postX);y0=Number(e.postY);t0=Number(e.at);after=true;
         }
         if(!found)return null;
         var t:Number=t1>t0?Math.max(0,Math.min(1,(time-t0)/(t1-t0))):1;
         return {x:x0+(x1-x0)*t,y:y0+(y1-y0)*t,after:after,at:edge,snapshot:after?b:a};
      }
   }
}
