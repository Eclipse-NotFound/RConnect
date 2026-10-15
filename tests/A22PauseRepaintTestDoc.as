package {
   /** Real paused TCP delivery between frames at 2 FPS; only production can
    * request a display-only repaint before the next simulation frame. */
   public class A22PauseRepaintTestDoc extends PresentationContinuityTestDoc {
      public function A22PauseRepaintTestDoc() {super(true,4,true,true);}
   }
}
