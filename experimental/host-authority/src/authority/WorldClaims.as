package authority {
   import flash.utils.getQualifiedClassName;
   /** Select an actual occupant for single-copy pickups and native triggers. */
   public final class WorldClaims {
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
      public static function step(object:Object,room:Object,actor:PlayerActor,actors:Array):void {
         var type:String=getQualifiedClassName(object),xp:int=0,wasXP:Boolean=type=="fe.loc::Bonus" && object.id=="xp" && object.sost==1;
         if(wasXP)xp=room.kolXp==1 && room.maxXp>1?room.unXp*room.maxXp:room.unXp;
         if(wasXP && room.kolXp==1 && room.maxXp>1 && !room.detecting && room.summXp>0)xp+=room.summXp;
         var cp:Boolean=type=="fe.loc::CheckPoint",before:int=cp?int(object.active):-1;
         actor.access.scope.runRoom(actor.context,room,function():void {object.step();});
         if(wasXP && object.sost==2)for each(var other:PlayerActor in actors)if(other!==actor)
            actor.access.scope.run(other.context,function():void {other.unit.pers.expa(xp);});
         if(cp && before!=2 && object.active==2)for each(other in actors) {
            other.unit.pers.currentCP=object;other.unit.pers.currentCPCode=object.code;
            if(object.code)other.unit.pers.prevCPCode=object.code;
         }
      }
   }
}
