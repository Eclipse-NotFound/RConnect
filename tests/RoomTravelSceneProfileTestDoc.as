package {
   /** External event timing only. Profiled durations cannot qualify a release. */
   public class RoomTravelSceneProfileTestDoc extends RoomTravelSceneTestDoc {
      override protected function profileFirstFrame():Boolean{return true;}
   }
}
