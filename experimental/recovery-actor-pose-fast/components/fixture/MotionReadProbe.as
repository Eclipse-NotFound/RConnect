package fixture {
   /** Observes fallback reads; native production motion is a plain data record. */
   public final class MotionReadProbe {
      public var at:int=900,duration:Number=200,x:Number=2,y:Number=4,reads:int=0;
      public function get r():Number {reads++;return 0;}
   }
}
