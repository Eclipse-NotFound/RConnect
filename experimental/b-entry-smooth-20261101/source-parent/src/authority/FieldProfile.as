package authority {
   import flash.utils.getTimer;
   /** Paired capture timings on the same real native objects, only when requested by a probe. */
   public final class FieldProfile {
      public static function run(access:NativeAccess,check:Function):void {
         var Type:Class=access.definition("fe.unit.UnitZombie"),values:Array=[];
         for(var i:int=0;i<80;i++)values.push(new Type("1",10,<unit tr="1" dig="0"/>,null));
         var profiling:Boolean=Timing.enabled;Timing.enabled=false;
         try {
            for each(var mode:String in ["moving","stable","alternating"]) {
               var previousMs:Array=[],currentMs:Array=[],equal:Boolean=true;
               for each(var unit:Object in values){PreviousFields178.capture(unit);NativeFields.capture(unit);}
               for(var round:int=0;round<24;round++) {
                  var oldStates:Array=[],newStates:Array=[],before:int;
                  // Alternate order to reduce warm-up, timer and background-load bias.
                  if(round%2==0) {
                     before=getTimer();sample(values,mode,round,true,oldStates);previousMs.push(getTimer()-before);
                     before=getTimer();sample(values,mode,round,false,newStates);currentMs.push(getTimer()-before);
                  }else {
                     before=getTimer();sample(values,mode,round,false,newStates);currentMs.push(getTimer()-before);
                     before=getTimer();sample(values,mode,round,true,oldStates);previousMs.push(getTimer()-before);
                  }
                  for(i=0;i<values.length;i++)if(!VisualPose.recipeEqual(oldStates[i],newStates[i]))equal=false;
               }
               check(equal,"paired native public-field capture remains equal: "+mode);
               Log.write("fields-profile",{mode:mode,objects:80,callsPerChunk:320,chunks:24,
                  previous:stats(previousMs),current:stats(currentMs),
                  previousChunks:previousMs,currentChunks:currentMs,
                  note:"Paired primitive capture cost; does not measure battle frame rate."});
            }
         }finally {Timing.enabled=profiling;}
      }
      private static function sample(values:Array,mode:String,round:int,previous:Boolean,out:Array):void {
         for(var repeat:int=0;repeat<4;repeat++)for(var i:int=0;i<values.length;i++) {
            var unit:Object=values[i],moving:Boolean=mode=="moving" || mode=="alternating" && round%2==0;
            if(moving) {
               unit.X=400+i+round*4+repeat;unit.eyeX=unit.X+5;
               unit.Y=800+i%4+repeat;unit.eyeY=unit.Y-30;
               unit.dx=repeat%2?1:-1;unit.dy=repeat%2?-1:1;
            }
            out[i]=previous?PreviousFields178.capture(unit):NativeFields.capture(unit);
         }
      }
      private static function stats(samples:Array):Object {
         var sorted:Array=samples.concat();sorted.sort(Array.NUMERIC);
         var total:int=0;for each(var ms:int in samples)total+=ms;
         return {totalMs:total,meanMs:total/samples.length,p50Ms:sorted[int(sorted.length*.5)],p95Ms:sorted[int(sorted.length*.95)]};
      }
   }
}
