package authority {
   import flash.display.MovieClip;
   import flash.filters.GlowFilter;
   public final class SatsActions {
      public static function valid(plan:*):Boolean {
         if(!(plan is Array) || plan.length>32)return false;
         for each(var p:Object in plan)if(p==null || !(p.target is Number) || p.target<0 || p.target!=uint(p.target)
            || !(p.x is Number) || !(p.y is Number) || !isFinite(p.x) || !isFinite(p.y) || Math.abs(p.x)>100000 || Math.abs(p.y)>100000)return false;
         return true;
      }
      public static function execute(actor:PlayerActor,plan:Array):void {
         var g:Object=actor.unit,w:Object=actor.access.world,s:Object=g.sats,gun:Object=g.currentWeapon;
         s.clearAll();
         if(gun==null || gun.noSats || gun.status()>3 || g.hp<=0)return;
         s.weapon=gun;s.gg=g;s.skillConf=1;
         if(w.weaponsLevelsOff) {
            var gap:int=gun.lvl-g.pers.getWeapLevel(gun.skill);
            if(gap==1)s.skillConf=.8;else if(gap==2)s.skillConf=.6;else if(gap>2)return;
         }
         s.odv=s.od;
         var beforeX:Number=w.celX,beforeY:Number=w.celY,units:Array=s.units;
         try {
            for each(var p:Object in plan) {
               s.units=[];
               if(p.target!=0) {
                  var target:Object=actor.resolveTarget==null?null:actor.resolveTarget(p.target);
                  if(target==null || target.loc!==g.loc || target.sost>=3 || !target.isSats || target.invis || !g.isMeet(target))continue;
                  if(gun.satsMelee ? g.look(target,false,0,g.pers.meleeR*1.2+100)<=0 : g.look(target)<=0 || !target.getTileVisi())continue;
                  var outline:MovieClip=new MovieClip();outline.filters=[new GlowFilter()];
                  s.units.push({u:target,du:outline,p:s.getPrec(target),n:0});
               }
               w.celX=p.x;w.celY=p.y;s.setCel();
            }
         }finally {w.celX=beforeX;w.celY=beforeY;s.units=units;}
      }
   }
}
