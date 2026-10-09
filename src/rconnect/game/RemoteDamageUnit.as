package rconnect.game {
   import fe.unit.UnitPonPon;
   import fe.weapon.Bullet;

   /** A remote body detects native hits; the real UnitPlayer owns mitigation,
    * armor wear, elemental effects and death. Never turn a hit into NPC HP loss. */
   public class RemoteDamageUnit extends UnitPonPon {
      private var hits:Array=[];
      public var beforeNativeStep:Function;
      public function RemoteDamageUnit(variant:int) {
         super("stab",100,null,{tr:variant});Object(this).dopTestOn=true;
      }
      override public function dopTest(bullet:Bullet):Boolean {
         // Player-origin impacts have a single receiver, PeerHitUnit. This also
         // excludes targeted explosion bullets that bypass the faction check.
         return !PeerHitUnit.localAttack(bullet,Object(this).loc);
      }
      override public function udarBullet(bullet:Bullet,mode:int=0):int {
         return dopTest(bullet)?super.udarBullet(bullet,mode):-1;
      }
      override public function step():* {
         if(beforeNativeStep!=null)beforeNativeStep(this);
         super.step();
      }
      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {
         var self:Object=this;
         if(self.invulner || self.disabled || !isFinite(amount) || amount==0 || !dopTest(bullet))return 0;
         hits.push(NativeHit.capture(amount,type,bullet,periodic));
         return Math.max(0,amount);
      }
      override public function die(type:int=0):* {}
      public function drain():Array {var result:Array=hits;hits=[];return result;}
   }
}
