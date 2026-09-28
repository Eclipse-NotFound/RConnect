package rconnect.game {
   import fe.unit.UnitPonPon;
   import fe.weapon.Bullet;

   /** A remote body detects native hits; the real UnitPlayer owns mitigation,
    * armor wear, elemental effects and death. Never turn a hit into NPC HP loss. */
   public class RemoteDamageUnit extends UnitPonPon {
      private var hits:Array=[];
      public function RemoteDamageUnit(variant:int) {super("stab",100,null,{tr:variant});}
      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {
         var self:Object=this;
         if(self.invulner || self.disabled || !isFinite(amount) || amount==0)return 0;
         hits.push(NativeHit.capture(amount,type,bullet,periodic));
         return Math.max(0,amount);
      }
      override public function die(type:int=0):* {}
      public function drain():Array {var result:Array=hits;hits=[];return result;}
   }
}
