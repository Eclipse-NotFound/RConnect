package fe.serv {
   /** Optional bridge into the high-FPS host's package-internal scheduler result.
    *  Only call after checking that the host defines fe.serv.Gov60.
    *  frame() must never be called here: the host has already scheduled this frame.
    */
   public class SandyHighFpsClock {
      public static function isLogicFrame():Boolean { return Gov60.k == 0; }
   }
}