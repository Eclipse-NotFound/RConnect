package rconnect.game {
   import fe.loc.Location;
   import fe.loc.Loot;
   import fe.serv.Item;
   /** Native motion/interaction; only the inventory grant waits for arbitration. */
   public class RemoteLoot extends Loot {
      private var bridge:GameBridge,delay:int=30,manual:Boolean=false,awarded:Boolean=false;
      public var requested:Boolean=false;
      public function RemoteLoot(loc:Location,item:Item,x:Number,y:Number,b:GameBridge) {
         super(loc,item,x,y,false,false,true);bridge=b;
      }
      override public function toTake():* {manual=true;delay=0;super.toTake();}
      override public function step():* {
         if(delay>0)delay--;
         var self:Object=this;
         // An actual local impulse hands motion back to native physics. Network
         // playback itself leaves zero velocity after every displayed frame.
         if(bridge.controlsLoot(this) && (Math.abs(Number(self.dx))>.01 || Math.abs(Number(self.dy))>.01))
            bridge.releaseLootMotion(this);
         if(!requested)super.step();
         if(bridge.controlsLoot(this))self.dx=self.dy=0;
      }
      override public function run(divisor:int=1):* {
         if(bridge.controlsLoot(this))return;
         super.run(divisor);
      }
      override public function take(force:Boolean=false):* {
         if(!bridge.mirrorsRoom){super.take(force);return;}
         if(awarded || requested || (!force && delay>0))return;
         var self:Object=this,g:Object=bridge.gg;
         if(g==null || g.loc!==self.loc || g.rat>0)return;
         var dx:Number=g.X-self.X,dy:Number=g.Y-g.scY/2-self.Y;
         var wants:Boolean=manual || int(g.isTake)>=1;
         if(force || (wants && Math.abs(dx)<20 && Math.abs(dy)<20)) {
            if(bridge.world.hardInv && !manual && !self.item.checkAuto())return;
            requested=true;self.dx=self.dy=0;return;
         }
         // At a distance the original method only moves the item towards the
         // player. Its inventory branch is intercepted above.
         super.take(false);
      }
      public function grant(canonical:Item):void {
         if(awarded || canonical==null)return;
         var self:Object=this;self.item=canonical;
         awarded=true;super.take(true);
      }
      public function reject():void {requested=false;var self:Object=this;self.loc.remObj(this);}
   }
}
