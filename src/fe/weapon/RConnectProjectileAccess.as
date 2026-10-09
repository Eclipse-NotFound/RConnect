package fe.weapon {
   /** Read the native explosion pulse counter; never advance it or settle hits. */
   public class RConnectProjectileAccess {
      public static function remaining(b:Bullet):int {return b==null?0:b.expl_t;}
   }
}
