package authority {
   /** Resolve native exits, then move actors only between complete room steps. */
   public class RoomTransfers {
      private var access:NativeAccess,actors:Array,inputs:Array,rooms:OccupiedRooms,pending:Array=[];
      public var notice:Function;
      private var returnPoint:Object;
      public function RoomTransfers(a:NativeAccess,players:Array,commands:Array,rooms:OccupiedRooms) {
         access=a;actors=players;inputs=commands;this.rooms=rooms;
      }
      public function request(land:Object,direction:int,x:Number,y:Number):Object {
         var actor:PlayerActor=null;
         for each(var candidate:PlayerActor in actors)if(candidate.unit===access.world.gg)actor=candidate;
         if(actor==null || actor.unit.loc.land!==land)throw new Error("Exit has no registered native player");
         var from:Object=actor.unit.loc,lx:int=from.landX,ly:int=from.landY,lz:int=from.landZ;
         if(direction==1)--lx;else if(direction==2)++lx;else if(direction==3)++ly;
         else if(direction==4)--ly;else if(direction==5)lz=1-lz;else return null;
         var grid:Array=from.landProb==""?land.locs:land.probs[from.landProb];
         var to:Object=grid==null || grid[lx]==null || grid[lx][ly]==null?null:grid[lx][ly][lz];
         if(to==null)return direction==3?{die:true}:null;
         // Challenge and scripted travel are a separate joint-party transaction.
         var joint:Boolean=to.landProb!="" || to.prob!=null || to.sky || from.landProb!="";
         if(joint && actor.id!=0){if(notice!=null)notice("剧情与挑战区域需由宿主带队进入。");return null;}
         var u:Object=actor.unit;
         if(direction==1){x=to.limX-u.scX/2-9;y=u.Y-1;}
         else if(direction==2){x=u.scX/2+9;y=u.Y-1;}
         else if(direction==3){x=u.X;y=u.scY+10;}
         else if(direction==4){x=u.X;y=to.limY-10;}
         if(!isFinite(x) || !isFinite(y) || x<0 || y<0 || x>to.limX || y>to.limY || to.collisionUnit(x,y,u.scX-4,u.scY))return null;
         if(pending[actor.id]!=null)return pending[actor.id].result;
         var result:Object={x:x,y:y};pending[actor.id]={actor:actor,from:from,to:to,result:result};
         if(joint)for each(candidate in actors)if(candidate!==actor)
            pending[candidate.id]={actor:candidate,from:candidate.unit.loc,to:to,result:{x:x,y:y}};
         return result;
      }
      public function challenge(land:Object,id:String,x:Number,y:Number):Boolean {
         if(access.world.gg!==actors[0].unit) {
            if(notice!=null)notice("剧情与挑战区域需由宿主带队进入。");return true;
         }
         var to:Object,point:Object;
         if(id=="") {
            if(returnPoint==null)return true;
            to=returnPoint.room;point=returnPoint;returnPoint=null;
         }else {
            if(land.probs[id]==null || land.probs[id][0]==null || land.probs[id][0][0]==null || land.probs[id][0][0][0]==null)return true;
            var g:Object=actors[0].unit;
            returnPoint={room:g.loc,x:x<0?g.X:x,y:y<0?g.Y:y};to=land.probs[id][0][0][0];
            var spawn:Object=to.spawnPoints.length>0?to.spawnPoints[0]:{x:3,y:3};
            point={x:(spawn.x+1)*40,y:(spawn.y+1)*40-1};
         }
         for each(var actor:PlayerActor in actors)
            pending[actor.id]={actor:actor,from:actor.unit.loc,to:to,result:{x:point.x,y:point.y}};
         return true;
      }
      public function commit():void {
         var batch:Array=pending;pending=[];
         for each(var plan:Object in batch)if(plan!=null) {
            if(plan.actor.unit.loc!==plan.from)throw new Error("Room changed before exit committed");
            relocate(plan.actor,plan.to,plan.result.x,plan.result.y);
            for each(var follower:PlayerActor in actors)if(follower!==plan.actor && follower.personal.follow &&
               follower.unit.loc.land===plan.to.land && follower.unit.hp>0 && batch[follower.id]==null)
               relocate(follower,plan.to,plan.result.x,plan.result.y);
         }
      }
      public function meet(actor:PlayerActor):void {
         var peer:PlayerActor=actors[1-actor.id],from:Object=actor.unit.loc,to:Object=peer.unit.loc;
         if(actor.unit.hp<=0 || peer.unit.hp<=0 || from.land!==to.land || from.prob!=null || to.prob!=null ||
            from.landProb!="" || to.landProb!="" || from.sky || to.sky) {
            if(notice!=null)notice("只能传送到同一地图的普通房间；双方需存活。");return;
         }
         pending[actor.id]={actor:actor,from:from,to:to,result:{x:peer.unit.X,y:peer.unit.Y}};
      }
      public function relocate(actor:PlayerActor,to:Object,x:Number,y:Number):void {
         var from:Object=actor.unit.loc;
         if(from===to){access.scope.run(actor.context,function():void {actor.unit.setLocPos(x,y);});return;}
         rooms.ensure(to);
         var pet:Object=actor.unit.pet,petIndex:int;
         if(pet!=null) {
            pet.remVisual();from.remObj(pet);petIndex=from.units.indexOf(pet);if(petIndex>=0)from.units.splice(petIndex,1);
         }
         actor.unit.remVisual();actor.context.loc=to;actor.context.land=to.land;
         access.scope.run(actor.context,function():void {
            // inLoc's fixed pet slot belongs to the single-player roster; retain
            // native enemies and reconstruct player membership explicitly.
            var roster:Array=to.units.concat();
            actor.unit.inLoc(to);to.units=roster;
            actor.unit.setLocPos(x,y);
            if(pet!=null) {
               pet.loc=to;pet.setPos(x,y-20);
               if(to.units.indexOf(pet)<0)to.units.push(pet);
               // Native Unit.childObjs already steps its pet. Adding it to the
               // room's object chain would advance its AI and weapon twice.
               if(to.petOn && pet.sost<3)pet.addVisual();
            }
         });
         rooms.repairRoster(from);rooms.prepare(actor);
         ++actor.roomEpoch;actor.context.transitionCooldown=150;
         inputs[actor.id].retarget(access.keyFor(to),actor.roomEpoch);
         Log.write("room-transferred",{player:actor.id,from:access.keyFor(from),room:access.keyFor(to),roomEpoch:actor.roomEpoch});
      }
   }
}
