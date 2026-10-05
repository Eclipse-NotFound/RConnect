package {
   import fe.Pt;
   /** Scenario input inside the real Location.step. Native bullets step normally. */
   public class LightningSmartStep extends Pt {
      private var callback:Function;
      public function LightningSmartStep(f:Function) {callback=f;}
      override public function step():* {callback();}
   }
}
