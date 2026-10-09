package rconnect.game {
   import fe.unit.Unit;

   /** Location.step calls gg.step before its firstObj chain. This invisible
    * first link hands new WThrow mines to the room owner before any projectile
    * or contact AI can hit/detonate the joining player's temporary mine. */
   public class PlayerMineGate extends Unit {
      private var collect:Function;
      public function PlayerMineGate(room:Object,callback:Function) {
         super();collect=callback;
         var self:Object=this;self.loc=room;self.vis=null;self.disabled=true;
         self.fraction=100;self.id="rconnect_mine_gate";self.isSats=false;
      }
      override public function step():* {if(collect!=null)collect(Object(this).loc);}
      public function dispose():void {collect=null;var self:Object=this;if(self.loc!=null)self.loc.remObj(this);}
   }
}
