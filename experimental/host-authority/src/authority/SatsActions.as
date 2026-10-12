package authority {
   import flash.display.MovieClip;
   import flash.filters.GlowFilter;
   public final class SatsActions {
      /** Optional isolated-probe observer; no diagnostic work during play. */
      public static var observed:Function;
      public static function valid(plan:*):Boolean {
         if(!(plan is Array) || plan.length>32)return false;
         for each(var p:Object in plan)if(p==null || !(p.target is Number) || p.target<0 || p.target!=uint(p.target)
            || !(p.x is Number) || !(p.y is Number) || !isFinite(p.x) || !isFinite(p.y) || Math.abs(p.x)>100000 || Math.abs(p.y)>100000)return false;
         return true;
      }
      public static function execute(actor:PlayerActor,plan:Array):void {
         var g:Object=actor.unit,w:Object=actor.access.world,s:Object=g.sats,gun:Object=g.currentWeapon;
         s.clearAll();
         if(gun==null || gun.noSats || gun.status()>3 || g.hp<=0) {
            if(observed!=null)observed({player:actor.id,reason:"weapon-or-life",status:gun==null?-1:gun.status(),hp:g.hp,hold:gun==null?0:gun.hold});
            return;
         }
         s.weapon=gun;s.gg=g;s.skillConf=1;
         if(w.weaponsLevelsOff) {
            var gap:int=gun.lvl-g.pers.getWeapLevel(gun.skill);
            if(gap==1)s.skillConf=.8;else if(gap==2)s.skillConf=.6;else if(gap>2){if(observed!=null)observed({player:actor.id,reason:"skill",gap:gap});return;}
         }
         s.odv=s.od;
         var beforeX:Number=w.celX,beforeY:Number=w.celY,units:Array=s.units;
         try {
            for each(var p:Object in plan) {
               s.units=[];
               if(p.target!=0) {
                  var target:Object=actor.resolveTarget==null?null:actor.resolveTarget(p.target);
                  if(observed!=null)observed({player:actor.id,reason:"target",target:p.target,missing:target==null,
                     status:gun.status(),hold:gun.hold,reserve:g.invent.items[gun.ammo]==null?0:g.invent.items[gun.ammo].kol,
                     sameRoom:target!=null && target.loc===g.loc,hp:target==null?0:target.hp,
                     sost:target==null?-1:target.sost,isSats:target!=null && target.isSats,invis:target!=null && target.invis,
                     meet:target!=null && g.isMeet(target),look:target==null?0:g.look(target),tile:target!=null && actor.sight.visible(target)});
                  if(target==null || target.loc!==g.loc || target.sost>=3 || !target.isSats || target.invis || !g.isMeet(target))continue;
                  if(gun.satsMelee ? g.look(target,false,0,g.pers.meleeR*1.2+100)<=0 : g.look(target)<=0 || !actor.sight.visible(target))continue;
                  var outline:MovieClip=new MovieClip();outline.filters=[new GlowFilter()];
                  s.units.push({u:target,du:outline,p:s.getPrec(target),n:0});
               }
               w.celX=p.x;w.celY=p.y;s.setCel();
            }
         }finally {w.celX=beforeX;w.celY=beforeY;s.units=units;}
         if(observed!=null)observed({player:actor.id,reason:"planned",queued:s.que.length,od:s.od,odv:s.odv});
      }
   }
}
