package {
   import fe.weapon.Weapon;
   /** Expected compiler rejection: a subclass cannot replace the public var
    * slot with an accessor. Keep OUTSIDE the component source path. */
   public class IllegalWeaponGetter extends Weapon {
      override public function get hold():int {throw new Error("cannot override slot");}
   }
}
