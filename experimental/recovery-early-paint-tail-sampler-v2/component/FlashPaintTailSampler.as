package {
   import flash.sampler.*;
   import flash.utils.getTimer;

   /** The sole real flash.sampler adapter. Its lease protects these helpers only;
    * the runner must separately prove that no other sampler/profiler is loaded.
    * No setSamplerCallback or external profiler settings are changed.
    * sampleInternalAllocs(false) changes this process's sampler setting and is
    * permitted only in that isolated, exclusively owned diagnostic process. */
   public final class FlashPaintTailSampler {
      private static var owner:Object;
      private var admitted:Boolean;
      public function FlashPaintTailSampler(exclusiveInputConfirmed:Boolean=false) {admitted=exclusiveInputConfirmed;}
      public function now():int {return getTimer();}
      public function wall():Number {return new Date().time;}
      public function claim(token:Object):Boolean {
         if(!admitted || token==null || owner!=null)return false;
         owner=token;return true;
      }
      public function owns(token:Object):Boolean {return token!=null && owner===token;}
      private function requireOwner(token:Object):void {if(!owns(token))throw new Error("sampler lease mismatch");}
      public function release(token:Object):void {requireOwner(token);owner=null;}
      public function clear(token:Object):void {requireOwner(token);clearSamples();}
      public function internalAllocs(token:Object,value:Boolean):void {requireOwner(token);sampleInternalAllocs(value);}
      public function start(token:Object):void {requireOwner(token);startSampling();}
      public function pause(token:Object):void {requireOwner(token);pauseSampling();}
      public function stop(token:Object):void {requireOwner(token);stopSampling();}
      public function count(token:Object):Number {requireOwner(token);return getSampleCount();}
      public function samples(token:Object):Object {requireOwner(token);return getSamples();}
      public function kind(token:Object,sample:Object):int {
         requireOwner(token);
         if(sample is NewObjectSample)return 1;
         if(sample is DeleteObjectSample)return 2;
         if(!(sample is Sample))throw new Error("unexpected sampler value");
         return 0;
      }
      public function stack(token:Object,sample:Object):Object {requireOwner(token);return Sample(sample).stack;}
   }
}
