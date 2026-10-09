package {
   import flash.display.Sprite;
   public class ThrowingProbeField extends Sprite {
      public var calls:int=0;
      public function get X():Number {calls++;throw new Error("expected probe exception");}
      override public function get width():Number {calls++;throw new Error("expected overridden width exception");}
   }
}
