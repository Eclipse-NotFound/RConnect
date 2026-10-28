package authority {
   import flash.utils.getQualifiedClassName;
   import flash.utils.Dictionary;
   /** Select an actual occupant for single-copy pickups and native triggers. */
   public final class WorldClaims {
      private static var areaVisits:Dictionary=new Dictionary(true);
      public static function choose(object:Object,room:Object,actors:Array):PlayerActor {
         var type:String=getQualifiedClassName(object);
         if(type!="fe.loc::Loot" && type!="fe.loc::Bonus" && type!="fe.loc::CheckPoint" && type!="fe.loc::Area")return null;
         var chosen:PlayerActor=null,best:Number=Number.POSITIVE_INFINITY;
         for each(var actor:PlayerActor in actors)if(actor.unit.loc===room && actor.unit.hp>0 && actor.unit.sost<2) {
            var g:Object=actor.unit,d:Number=Math.pow(g.X-object.X,2)+Math.pow(g.Y-g.scY/2-object.Y,2);
            if(type!="fe.loc::Loot" && object.areaTest(g))d=-1;
            if(d<best){chosen=actor;best=d;}
         }
         return chosen;
      }
      public static function step(object:Object,room:Object,actor:PlayerActor,actors:Array,shareHorseshoeXP:Boolean=true):void {
         var type:String=getQualifiedClassName(object),xp:int=0,wasXP:Boolean=type=="fe.loc::Bonus" && object.id=="xp" && object.sost==1;
         var beforeXP:int=wasXP?int(room.kolXp):0;
         if(type=="fe.loc::Area" && object.tip=="gg") {stepArea(object,room,actor,actors);return;}
         if(wasXP)xp=room.kolXp==1 && room.maxXp>1?room.unXp*room.maxXp:room.unXp;
         if(wasXP && room.kolXp==1 && room.maxXp>1 && !room.detecting && room.summXp>0)xp+=room.summXp;
         var cp:Boolean=type=="fe.loc::CheckPoint",before:int=cp?int(object.active):-1;
         actor.access.scope.runRoom(actor.context,room,function():void {object.step();});
         // Native Bonus.take always rewards its real collector. This policy
         // only controls the extra teammate reward for a consumed XP point;
         // expiry/removal is not a pickup, and other XP sources stay native.
         if(shareHorseshoeXP && wasXP && object.sost==2 && int(room.kolXp)<beforeXP)for each(var other:PlayerActor in actors)if(other!==actor)
            actor.access.scope.run(other.context,function():void {other.unit.pers.expa(xp);});
         if(cp && before!=2 && object.active==2)for each(other in actors) {
            other.unit.pers.currentCP=object;other.unit.pers.currentCPCode=object.code;
            if(object.code)other.unit.pers.prevCPCode=object.code;
            if(other!==actor)actor.access.scope.run(other.context,function():void {actor.access.world.saveGame();});
         }
      }
      private static function stepArea(area:Object,room:Object,chosen:PlayerActor,actors:Array):void {
         var visits:Object=areaVisits[area];if(visits==null)visits=areaVisits[area]={};
         var active:Array=[],wasPort:Boolean=area.onPort,previousActivator:Object=area.activator;
         for each(var actor:PlayerActor in actors) {
            var inside:Boolean=area.enabled && room.active && actor.unit.loc===room && actor.unit.hp>0 && actor.unit.sost<3 && area.areaTest(actor.unit);
            var previous:Object=visits[actor.id];
            active.push({actor:actor,inside:inside,entered:inside && (previous==null || !previous.inside || previous.epoch!=actor.roomEpoch)});
            visits[actor.id]={inside:inside,epoch:actor.roomEpoch};
         }
         // The area emits and advances shared scripts once. Its personal
         // portal entry is tracked separately for every real occupant.
         area.onPort=false;
         try {chosen.access.scope.runRoom(chosen.context,room,function():void {area.step();});}
         finally {area.onPort=wasPort;}
         previousActivator=area.activator;
         for each(var state:Object in active)if(state.inside) {
            actor=state.actor;
            if(actor!==chosen)chosen.access.scope.runRoom(actor.context,room,function():void {
               area.activator=actor.unit;
               try {
                  if(area.noRad)actor.unit.noRad=true;
                  if(area.mess)actor.context.gui.messText(area.mess,"",area.messDown);
                  if(area.run!=null)area.run();
               }finally{area.activator=previousActivator;}
            });
            if(wasPort && state.entered)chosen.access.scope.runRoom(actor.context,room,function():void {area.teleport(actor.unit);});
         }
      }
   }
}
