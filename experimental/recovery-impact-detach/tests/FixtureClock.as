package {
   import rconnect.game.RemoteMotion;
   /** Controlled shooter clock only. The production receiver/queue/fallback
    * are not substituted or called a second time by this fixture. */
   public class FixtureClock extends RemoteMotion {
      public var time:Number=900;
      override public function get sourceTime():Number {return time;}
   }
}
