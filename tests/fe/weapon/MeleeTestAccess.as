package fe.weapon {
   import flash.display.MovieClip;

   /** Independent native oracle. The driver never calls MeleeVisuals, so the
    * same fixture also runs against the unmodified installed production SWF. */
   public class MeleeTestAccess {
      public static function trail(w:Object):MovieClip {
         var native:WClub=w as WClub;
         return native==null?null:native.visvzz;
      }
   }
}
