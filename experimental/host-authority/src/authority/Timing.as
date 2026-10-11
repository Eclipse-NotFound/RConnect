package authority {
   import flash.utils.getTimer;
   /** Disabled in play. Fixed-size millisecond histograms for isolated probes. */
   public final class Timing {
      public static var enabled:Boolean=false;
      private static var samples:Object={};
      public static function start():int{return enabled?getTimer():0;}
      public static function end(name:String,started:int):void {if(enabled)record(name,getTimer()-started);}
      public static function record(name:String,ms:Number):void {
         if(!enabled)return;
         var r:Object=samples[name];if(r==null)r=samples[name]={n:0,sum:0,max:0,bins:new Vector.<uint>(2001,true)};
         ++r.n;r.sum+=ms;r.max=Math.max(r.max,ms);++r.bins[Math.max(0,Math.min(2000,int(ms)))];
      }
      private static function percentile(r:Object,part:Number):Number {
         var n:int=0;for(var i:int=0;i<r.bins.length;i++){n+=r.bins[i];if(n>=r.n*part)return i;}return r.max;
      }
      public static function snapshot():Object {
         var result:Object={};for(var key:String in samples) {
            var r:Object=samples[key];result[key]={n:r.n,totalMs:r.sum,meanMs:r.sum/r.n,p50Ms:percentile(r,.5),p95Ms:percentile(r,.95),maxMs:r.max};
         }return result;
      }
      public static function reset():void {samples={};}
   }
}
