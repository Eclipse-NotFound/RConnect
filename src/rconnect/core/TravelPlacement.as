package rconnect.core {
   import rconnect.game.GameBridge;

   /** A discontinuous move must also move the native floating weapon anchors.
    * Unit.setPos/setVisPos only move the pony. Weapon.actions otherwise eases
    * from the previous room's position and transmits that same offset to peers. */
   public class TravelPlacement {
      public static function place(gg:Object,x:Number,y:Number):void {
         if(gg==null || !isFinite(x) || !isFinite(y))throw new Error("Invalid travel placement");
         var dx:Number=x-Number(gg.X),dy:Number=y-Number(gg.Y);
         gg.setPos(x,y);gg.dx=0;gg.dy=0;gg.isLaz=0;gg.setVisPos();
         // setWeaponPos queries terrain using the previous anchor before it
         // updates its Y. Keep that query in the new coordinate neighborhood.
         gg.weaponX+=dx;gg.weaponY+=dy;
         var list:Array=[],w:Object;
         for each(var key:String in ["currentWeapon","throwWeapon","magicWeapon"]) {
            w=GameBridge.probe(gg,key);
            if(w!=null && list.indexOf(w)<0 && GameBridge.probe(w,"owner")===gg)list.push(w);
         }
         for each(w in list) {
            gg.setWeaponPos(int(w.tip));
            w.X=int(w.tip)==5?Number(gg.magicX):Number(gg.weaponX);
            w.Y=int(w.tip)==5?Number(gg.magicY):Number(gg.weaponY);
            // No actions/step/setNull: these can fire, spend ammo, or reset
            // attack/reload timers. Only refresh the native display pose.
            if(GameBridge.probe(w,"vis")!=null)w.animate();
         }
         w=GameBridge.probe(gg,"currentWeapon");
         gg.setWeaponPos(w==null?0:int(w.tip));
      }
   }
}
