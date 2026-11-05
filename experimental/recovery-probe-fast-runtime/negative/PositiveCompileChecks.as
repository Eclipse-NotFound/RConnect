package {
   import flash.display.Sprite;
   import fe.weapon.Weapon;
   import fe.weapon.Bullet;
   public class PositiveCompileChecks extends Sprite {
      public function PositiveCompileChecks() {
         var w:LegalWeapon=new LegalWeapon(), b:LegalBullet=new LegalBullet();
         w.hold=1;b.babah=true;trace(w.hold,b.babah,w.extraGetter,b.extraGetter);
      }
   }
   internal class LegalWeapon extends Weapon {public function get extraGetter():int{return 1;}}
   internal class LegalBullet extends Bullet {public function get extraGetter():Boolean{return true;}}
}
