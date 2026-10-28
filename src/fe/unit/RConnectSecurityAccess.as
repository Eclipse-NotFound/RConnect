package fe.unit {
   /** Native fields stay behind one adapter; no second AI/weapon simulation. */
   public class RConnectSecurityAccess {
      public static function turret(o:Object):Boolean {return o is UnitTurret;}
      public static function state(o:Object):Object {
         var t:UnitTurret=o as UnitTurret;
         return t==null?null:{sleep:t.sleep,reprog:t.reprog,absolute:t.absVis};
      }
      public static function mirror(o:Object,s:Object,fraction:int):void {
         var t:UnitTurret=o as UnitTurret;if(t==null || s==null)return;
         t.sleep=s.sleep===true;t.reprog=s.reprog===true;o.fraction=fraction;
      }
      public static function clearTarget(o:Object,blocked:Function):void {
         var t:UnitTurret=o as UnitTurret;if(t==null)return;
         var u:Object=o,w:Object=u.currentWeapon;
         if(u.priorUnit!=null && blocked(u.priorUnit))u.priorUnit=null;
         if(u.celUnit!=null && blocked(u.celUnit)) {
            u.celUnit=null;t.aiSpok=0;t.aiState=t.hidden>0?0:1;
            if(w!=null)w.findCel=false;
            // Native control must reacquire before firing at a remembered point.
            t.aiTCh=0;
         }
      }
      public static function apply(o:Object,skill:int,everyone:Boolean,authority:Boolean):void {
         var t:UnitTurret=o as UnitTurret;if(t==null || !authority || Number(o.sost)>=3 || o.hp<=0)return;
         if(skill>0) {
            // Only the room simulator executes hack() and awards native XP.
            o.hack(skill);
         }
         else if(skill==0 && everyone)o.hack(0);
      }
      public static function detect(o:Object,target:Object,force:Boolean):Boolean {
         var t:UnitTurret=o as UnitTurret;
         if(t==null || target==null || t.sleep || o.oduplenie>0 || !o.isMeet(target)
            || target.sost>=3 || target.hp<=0 || target.invulner)return false;
         if(t.absVis && !t.reprog){o.setCel(target);return true;}
         if(target.player) {
            var noise:Number=o.listen(target);
            if(noise)target.observation(noise);
            var sight:Number=o.look(target,o.overLook || force);
            if(sight>0) {
               target.observation(sight,o.observ);
               if(target.obs>=target.maxObs){o.setCel(target);return true;}
            } else if(noise>0) {
               if(target.obs>=target.maxObs)o.setCel(null,target.X+(Math.random()-0.5)*200,target.Y+(Math.random()-0.5)*200);
               if(noise>1)return true;
            }
         } else if(o.look(target,o.overLook || force)>0.5) {o.setCel(target);return true;}
         return false;
      }
   }
}
