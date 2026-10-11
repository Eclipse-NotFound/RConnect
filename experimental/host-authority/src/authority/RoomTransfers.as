package authority {
   /** Resolve native exits, then move actors only between complete room steps. */
   public class RoomTransfers {
      private var access:NativeAccess,actors:Array,inputs:Array,rooms:OccupiedRooms,pending:Array=[];
      public function RoomTransfers(a:NativeAccess,players:Array,commands:Array,rooms:OccupiedRooms) {
         access=a;actors=players;inputs=commands;this.rooms=rooms;
      }
      public function request(land:Object,direction:int,x:Number,y:Number):Object {
         var actor:PlayerActor=null;
         for each(var candidate:PlayerActor in actors)if(candidate.unit===access.world.gg)actor=candidate;
         if(actor==null || actor.unit.loc.land!==land)throw new Error("Exit has no registered native player");
         var from:Object=actor.unit.loc,lx:int=from.landX,ly:int=from.landY,lz:int=from.landZ;
         if(from.landProb!="" || from.prob!=null)return null;
         if(direction==1)--lx;else if(direction==2)++lx;else if(direction==3)++ly;
         else if(direction==4)--ly;else if(direction==5)lz=1-lz;else return null;
         var to:Object=land.locs[lx]==null || land.locs[lx][ly]==null?null:land.locs[lx][ly][lz];
         if(to==null)return direction==3?{die:true}:null;
         // Challenge and scripted travel are a separate joint-party transaction.
         if(to.landProb!="" || to.prob!=null || to.sky)return null;
         var u:Object=actor.unit;
         if(direction==1){x=to.limX-u.scX/2-9;y=u.Y-1;}
         else if(direction==2){x=u.scX/2+9;y=u.Y-1;}
         else if(direction==3){x=u.X;y=u.scY+10;}
         else if(direction==4){x=u.X;y=to.limY-10;}
         if(!isFinite(x) || !isFinite(y) || x<0 || y<0 || x>to.limX || y>to.limY || to.collisionUnit(x,y,u.scX-4,u.scY))return null;
         if(pending[actor.id]!=null)return pending[actor.id].result;
         var result:Object={x:x,y:y};pending[actor.id]={actor:actor,from:from,to:to,result:result};
         return result;
      }
      public function commit():void {
         var batch:Array=pending;pending=[];
         for each(var plan:Object in batch)if(plan!=null) {
            if(plan.actor.unit.loc!==plan.from)throw new Error("Room changed before exit committed");
            relocate(plan.actor,plan.to,plan.result.x,plan.result.y);
         }
      }
      public function relocate(actor:PlayerActor,to:Object,x:Number,y:Number):void {
         var from:Object=actor.unit.loc;
         if(from===to){access.scope.run(actor.context,function():void {actor.unit.setLocPos(x,y);});return;}
         if(actor.unit.pet!=null)throw new Error("B2 companion room transfer is not implemented");
         rooms.ensure(to);
         actor.unit.remVisual();actor.context.loc=to;actor.context.land=to.land;
         access.scope.run(actor.context,function():void {
            // inLoc's fixed pet slot belongs to the single-player roster; retain
            // native enemies and reconstruct player membership explicitly.
            var roster:Array=to.units.concat();
            actor.unit.inLoc(to);to.units=roster;
            actor.unit.setLocPos(x,y);
         });
         rooms.repairRoster(from);rooms.prepare(actor);
         ++actor.roomEpoch;actor.context.transitionCooldown=150;
         inputs[actor.id].retarget(access.keyFor(to),actor.roomEpoch);
         Log.write("room-transferred",{player:actor.id,from:access.keyFor(from),room:access.keyFor(to),roomEpoch:actor.roomEpoch});
      }
   }
}
