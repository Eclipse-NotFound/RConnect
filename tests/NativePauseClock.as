package {
   import fe.Pt;
   /** Counts calls from native Location.step; no Timer/ENTER_FRAME surrogate. */
   public class NativePauseClock extends Pt {
      public var steps:int=0;
      override public function step():* {steps++;}
   }
}
