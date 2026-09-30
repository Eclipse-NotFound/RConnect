package fe.unit {
   /** Native raiders remember World.gg in control(). A remote player keeps a
    * non-UnitPlayer body, so mirror that recognition only after native sight. */
   public class RConnectPerceptionAccess {
      public static function recognize(u:Unit,newTarget:Boolean=false):void {
         if(u is UnitRaider) {
            (u as UnitRaider).aiVKurse=true;
            // A freshly seen candidate must reach native findCel before idle
            // patrol changes direction. Leave alarm/reaction/attack to control().
            if(newTarget && u.aiState<=1)u.aiTCh=2;
         }
      }
   }
}
