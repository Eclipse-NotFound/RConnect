package fe.weapon {
   import flash.display.MovieClip;

   /** The native slash visual is internal to WClub, in this package namespace.
    * This access never advances the weapon or its bound collision Bullet. */
   public class RConnectMeleeAccess {
      public static function isClub(w:Object):Boolean {return w is WClub;}
      public static function trail(w:Object):MovieClip {
         var club:WClub=w as WClub;
         return club==null?null:club.visvzz;
      }
   }
}
