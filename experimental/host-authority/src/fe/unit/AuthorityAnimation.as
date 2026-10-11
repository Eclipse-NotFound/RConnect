package fe.unit {
   /** Package-scoped read of the exact native blit frame. No animate/AI call. */
   public final class AuthorityAnimation {
      public static function burning(unit:Unit):Boolean {return unit!=null && unit.burn!=null;}
      public static function inCover(unit:UnitPlayer):Boolean {return unit.lurked;}
      public static function capture(unit:Unit):Object {
         var u:Object=unit,a:Object=unit.anims==null?null:unit.anims[u.animState];
         if(u.blitData==null || a==null)return null;
         return {id:a.id,frame:int(unit.blitRect.x/unit.blitX),state:u.animState,
            blank:unit.visData!=null && unit.visData.getColorBoundsRect(0xFF000000,0,false).isEmpty()};
      }
      public static function apply(unit:Unit,state:Object):void {
         if(state==null)return;
         unit.blit(int(state.id),int(state.frame));
         if(state.blank && unit.visData!=null)unit.visData.fillRect(unit.visData.rect,0);
         Object(unit).animState=Object(unit).animState2=state.state;
      }
   }
}
