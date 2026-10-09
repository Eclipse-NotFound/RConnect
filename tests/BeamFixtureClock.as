package {
   import rconnect.game.RemoteMotion;
   public class BeamFixtureClock extends RemoteMotion {
      public var time:Number=950;
      override public function get sourceTime():Number {return time;}
   }
}
