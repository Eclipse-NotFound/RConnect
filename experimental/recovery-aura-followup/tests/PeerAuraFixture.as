package {
   import rconnect.core.Log;
   /** A known native corridor, only inside the independently compiled driver.
    * Host chooses a reproducible test layout; join uses production seed adoption. */
   public class PeerAuraFixture {
      public static const SEED:uint=1192051184;
      private static var bound:Boolean=false;
      /** Persistent native inputs, not per-frame writes to derived Pers stats.
       * Tele 14 is native rank 4: 12 lifting mass, 0.8 free-lift threshold.
       * Rank 5 would make a mass-1 player free to hold and invalidate the
       * existing mana-charge assertion. Level 15 satisfies telemaster's gate. */
      public static function prepareCaster(g:Object):Object {
         if(g==null || g.pers==null)throw new Error("native caster unavailable");
         var p:Object=g.pers;
         if(p.level<15)p.setForcLevel(15);
         p.addSkill("tele",Math.max(0,14-Number(p.skills.tele)));
         p.addSkill("magic",Math.max(0,20-Number(p.skills.magic)));
         if(!p.perks.telemaster)p.addPerk("telemaster");
         if(!p.perks.telethrow)p.addPerk("telethrow");
         p.healAll();p.setParameters();
         var first:Object=casterState(g);
         // Exercise the exact native recalculation which broke round 14.
         // This runs at fixture installation, never around Q or packet send.
         p.setParameters();
         var second:Object=casterState(g);
         if(first.mass!=second.mass || first.master!=second.master || first.range!=second.range
            || first.threshold!=second.threshold || first.force!=second.force || first.spells!=second.spells)
            throw new Error("native caster skill/perk inputs do not survive setParameters");
         if(!canLift(g,1,0) || p.telePorog>=1 || p.teleMult<=0)
            throw new Error("native caster must support a mass-1 player and charge mana during hold: "+JSON.stringify(second));
         Log.d("PEER AURA FIXTURE native caster "+JSON.stringify(second));
         return second;
      }
      public static function casterState(g:Object):Object {
         var p:Object=g.pers;
         return {level:p.level,tele:p.skills.tele,magic:p.skills.magic,
            telemasterPerk:p.perks.telemaster,telethrowPerk:p.perks.telethrow,
            mass:p.maxTeleMassa,master:p.telemaster,range:p.teleDist,threshold:p.telePorog,
            force:p.throwForce,spells:p.spellsPoss,teleMult:p.teleMult,mana:g.mana,maxmana:g.maxmana};
      }
      public static function canLift(g:Object,mass:Number,distanceSquared:Number):Boolean {
         var p:Object=g.pers;
         return isFinite(Number(p.maxTeleMassa)) && p.maxTeleMassa>=mass && p.telemaster==1
            && p.spellsPoss>0 && p.throwForce>0 && isFinite(Number(p.teleDist)) && p.teleDist>=distanceSquared;
      }
      public static function prepare(mod:Object,host:Boolean):void {
         if(bound || !host)return;
         var landClass:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");
         if(!("rconnectSeedSource" in landClass) || !(landClass.rconnectSeedSource is Function))
            throw new Error("native seed boundary unavailable for test fixture");
         var info:Object=mod.game.readWorldInfo();
         if(info!=null && info.curLandId=="random_mane")throw new Error("test seed binding was too late");
         var previous:Function=landClass.rconnectSeedSource;
         landClass.rconnectSeedSource=function(land:Object):uint {
            if(land!=null && land.act!=null && land.act.id=="random_mane") {
               Log.d("PEER AURA FIXTURE native layout seed="+SEED);return SEED;
            }
            return previous(land);
         };
         bound=true;
      }
   }
}
