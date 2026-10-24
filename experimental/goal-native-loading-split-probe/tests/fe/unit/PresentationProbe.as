package fe.unit {
   /** Native camouflage state setup; animate itself computes alpha/isVis. */
   public class PresentationProbe {
      public static function fade(unit:Unit):void {
         var u:Object=unit;
         if(unit is UnitZebra) {
            var z:UnitZebra=unit as UnitZebra;z.shine=10;z.shine2=20;z.red=false;
         } else if(unit is UnitAlicorn) {
            var a:UnitAlicorn=unit as UnitAlicorn;a.superInvis=true;a.curA=10;
            // superSila sets this once; animate deliberately leaves it false.
            u.isVis=false;
         }
         u.invis=true;u.dx=3;u.dy=0;u.stay=true;u.isShoot=false;u.animate();
      }
      public static function frame(unit:Unit):Number {
         var u:Object=unit;return unit.anims==null || unit.anims[u.animState]==null ? -1 : Number(unit.anims[u.animState].f);
      }
   }
}
