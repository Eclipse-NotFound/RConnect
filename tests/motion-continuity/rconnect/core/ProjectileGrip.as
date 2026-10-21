package rconnect.core {
   public class ProjectileGrip {
      public static var instance:ProjectileGrip=null;
      public function describe(b:Object):Object {throw new Error("Grip outside projectile component");}
      public function present(b:Object):void {throw new Error("Grip outside projectile component");}
      public function forget(b:Object):void {throw new Error("Grip outside projectile component");}
   }
}
