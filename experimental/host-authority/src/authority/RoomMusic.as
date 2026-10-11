package authority {
   /** Native music selection/timer semantics, retained with its occupied room.
    * Playback channels and each listener's volume are deliberately local. */
   public final class RoomMusic {
      public var ambient:String,track:String,loops:int=10000,priority:int=0,remaining:int=0;
      public function RoomMusic(ambient:String){this.ambient=ambient;track=ambient;}
      public function request(name:String,count:int=10000):void {
         // Native playMusic keeps an already playing identical track, even
         // when a caller supplies another repeat count.
         if(name==track)return;
         track=name;loops=count;priority=0;
      }
      public function combat(name:String,level:int,duration:int):void {
         remaining=duration;
         if(level>priority){priority=level;request(name);}
      }
      public function step():void {
         if(remaining<=0)return;
         if(remaining==1){priority=0;request(ambient);}
         --remaining;
      }
      public function snapshot():Object{return {ambient:ambient,track:track,loops:loops,priority:priority,remaining:remaining};}
   }
}
