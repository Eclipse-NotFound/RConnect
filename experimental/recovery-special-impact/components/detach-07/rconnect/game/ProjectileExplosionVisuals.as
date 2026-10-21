package rconnect.game {
   public class ProjectileExplosionVisuals {
      public static function capture(b:Object):Object {return GameBridge.probe(b,"fixtureExplosion");}
      public static function play(...args):void {throw new Error("explosion rendering outside capture fixture");}
   }
}
