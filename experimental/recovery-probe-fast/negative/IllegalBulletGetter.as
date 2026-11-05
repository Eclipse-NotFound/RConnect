package {
   import fe.weapon.Bullet;
   public class IllegalBulletGetter extends Bullet {
      override public function get babah():Boolean {throw new Error("cannot override slot");}
   }
}
