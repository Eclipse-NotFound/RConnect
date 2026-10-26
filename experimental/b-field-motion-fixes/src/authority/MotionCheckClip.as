package authority {
   import flash.display.MovieClip;
   /** Test-only sprite; kept in its own file for the Flex source-path resolver. */
   public class MotionCheckClip extends MovieClip {
      public function MotionCheckClip() {
         graphics.beginFill(0x4499EE);graphics.drawRect(-6,-9,12,18);graphics.endFill();stop();
      }
   }
}
