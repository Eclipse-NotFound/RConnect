package {
   import fe.unit.Unit;
   import fe.weapon.Weapon;
   public class NativeTestGun extends Weapon {
      public function NativeTestGun(owner:Unit) { super(owner,"lmg",0); }
      public function fireAt(target:Object,deterministic:Boolean=false):Object {
         var self:Object=this;
         self.loc=target.loc; self.X=target.X-45; self.Y=target.Y-target.scY/2;
         self.hold=90; self.rot=0; self.deviation=0; self.precision=0;
         var b:Object=super.shoot();
         if(b==null) throw new Error("native lmg did not create bullet");
         if(deterministic){b.miss=0;b.critCh=0;b.critInvis=0;b.desintegr=0;}
         b.precision=0; b.dx=15; b.dy=0;
         for(var i:int=0;i<5 && !b.babah;i++) b.run();
         self.loc.remObj(b);
         return b;
      }
   }
}
