package authority {
   import flash.utils.Dictionary;
   /** Native telekinesis moves the real player; personal consent stays independent. */
   public final class PeerGrabs {
      private var actors:Array,grips:Dictionary=new Dictionary(true);
      public function PeerGrabs(actors:Array){this.actors=actors;}
      public function prepare(actor:PlayerActor,input:Object):void {
         var g:Object=actor.unit,holder:PlayerActor=null;
         g.levitPoss=actor.personal.allowGrab;
         for each(var other:PlayerActor in actors)if(other!==actor && other.unit.teleObj===g){holder=other;break;}
         if(holder==null)return;
         if(!actor.personal.allowGrab || holder.unit.loc!==g.loc || g.hp<=0 || holder.unit.hp<=0 ||
            actor.personal.struggle && (input.buttons&(Commands.LEFT|Commands.RIGHT|Commands.UP|Commands.SIT))!=0) {
            holder.access.scope.run(holder.context,function():void {holder.unit.dropTeleObj();});delete grips[g];return;
         }
         // Level two is native externally imposed lift. Level one is the
         // player's own levitation and would spend its mana/reset on key-up.
         g.levit=2;
         input.buttons&=~(Commands.LEFT|Commands.RIGHT|Commands.UP|Commands.SIT|Commands.JUMP|Commands.DASH);
         input.pressed&=~(Commands.LEFT|Commands.RIGHT|Commands.UP|Commands.SIT|Commands.JUMP|Commands.DASH);
      }
      public function present():void {
         var live:Dictionary=new Dictionary(true);
         for each(var holder:PlayerActor in actors)for each(var target:PlayerActor in actors)if(holder!==target && holder.unit.teleObj===target.unit) {
            var g:Object=target.unit;
            if(!target.personal.allowGrab){holder.access.scope.run(holder.context,function():void {holder.unit.dropTeleObj();});continue;}
            var rec:Object=grips[g];
            if(rec==null)rec=grips[g]={holder:holder,filters:g.vis.filters,color:g.vis.transform.colorTransform};
            g.levit=2;g.vis.filters=rec.filters;g.vis.transform.colorTransform=rec.color;live[g]=true;
         }
         for(var key:Object in grips)if(!live[key])delete grips[key];
      }
      public function afterStep(holder:PlayerActor):void {
         var target:PlayerActor=actorFor(holder.unit.teleObj);
         if(target!=null && target!==holder && grips[target.unit]==null)
            grips[target.unit]={holder:holder,filters:target.unit.vis.filters,color:target.unit.vis.transform.colorTransform};
      }
      public function actorFor(unit:Object):PlayerActor {for each(var a:PlayerActor in actors)if(a.unit===unit)return a;return null;}
   }
}
