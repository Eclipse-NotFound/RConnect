package {
   import fe.unit.Unit;
   import fe.weapon.Weapon;
   /** Exposes the real Weapon.shoot without substituting a visual or bullet. */
   public class NativeBeamGun extends Weapon {
      public function NativeBeamGun(owner:Unit,id:String) {super(owner,id,0);}
      public function fire(x:Number,y:Number,angle:Number=0):Object {
         var w:Object=this;w.X=x;w.Y=y;w.rot=angle;w.hold=10000;
         w.damage=w.damageExpl=w.destroy=0;w.deviation=0;w.precision=0;
         // The original muzzle reads vis.emit when the gun is attached.
         // Move that native visual too before firing from the fixture corridor.
         w.owner.celX=x+Math.cos(angle)*600;w.owner.celY=y+Math.sin(angle)*600;
         w.owner.storona=Math.cos(angle)>=0?1:-1;w.animate();
         var b:Object=super.shoot();
         if(b==null)throw new Error("native beam did not fire "+w.id);
         b.miss=b.critCh=b.critInvis=b.desintegr=0;b.precision=0;
         return b;
      }
   }
}
