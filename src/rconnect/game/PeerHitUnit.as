package rconnect.game {
   import fe.unit.Unit;
   import fe.weapon.Bullet;

   /** Collision-only receiver for the local player's attacks against a teammate.
    * The teammate's native player owns armor, status effects and death. */
   public class PeerHitUnit extends Unit {
      private var target:Object;
      private var emit:Function,allowed:Function;
      private var disposed:Boolean=false;
      private static const SHAPE:Array=["loc","X","Y","X1","X2","Y1","Y2","scX","scY",
         "storona","hp","maxhp","sost","trigDis","dexter","dexterPlus","dodge","transp","invulner","stay","mat"];

      public function PeerHitUnit(body:Object,accept:Function,send:Function) {
         super();target=body;allowed=accept;emit=send;
         var self:Object=this;
         self.id="rconnect_peer_hit";self.fraction=101;
         self.doop=true;self.unres=true;self.npc=true;self.noAgro=true;
         self.noBox=true;self.activateTrap=0;self.levitPoss=false;
         self.isSats=false;self.showNumbs=false;self.dopTestOn=true;
         sync();
      }
      public static function localAttack(bullet:Object,room:Object):Boolean {
         if(bullet==null || room==null)return false;
         var actor:Object=GameBridge.probe(room,"gg");
         return actor!=null && (GameBridge.probe(bullet,"owner")===actor
            || GameBridge.probe(GameBridge.probe(bullet,"weap"),"owner")===actor);
      }
      public function sync():void {
         if(disposed)return;
         var self:Object=this;
         for each(var k:String in SHAPE) {
            var v:*=GameBridge.probe(target,k);if(v!=null)self[k]=v;
         }
         var resist:*=GameBridge.probe(target,"vulner");
         if(resist is Array)self.vulner=(resist as Array).concat();
         self.disabled=target==null || target.disabled || self.sost>=3;
      }
      override public function dopTest(bullet:Bullet):Boolean {
         return !disposed && allowed!=null && allowed() && localAttack(bullet,Object(this).loc);
      }
      /** Optional smart-weapon eligibility contract. The same live host policy
       * as collision is checked on acquisition and every guided projectile step.
       * This never changes faction/npc flags or makes the peer an AI enemy. */
      public function rconnectSmartTargetAllowed(player:Object):Boolean {
         return !disposed && allowed!=null && allowed() && player!=null
            && GameBridge.probe(Object(this).loc,"gg")===player;
      }
      override public function udarBullet(bullet:Bullet,mode:int=0):int {
         if(!dopTest(bullet))return -1;
         return super.udarBullet(bullet,mode);
      }
      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {
         if(!isFinite(amount) || amount<=0 || !dopTest(bullet) || Object(this).invulner)return 0;
         emit(NativeHit.capture(amount,type,bullet,periodic));
         return amount;
      }
      override public function die(type:int=0):* {}
      public function dispose():void {
         if(disposed)return;disposed=true;
         var self:Object=this,room:Object=self.loc;
         if(room!=null && room.units is Array) {
            var i:int=room.units.indexOf(this);if(i>=0)room.units.splice(i,1);
         }
         self.disabled=true;self.sost=4;self.vis=null;self.hpbar=null;
         target=null;emit=null;allowed=null;
      }
   }
}
