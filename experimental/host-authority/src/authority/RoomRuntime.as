package authority {
   import flash.display.DisplayObject;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   /** Native Location still owns object stepping. B owns player scheduling. */
   public class RoomRuntime {
      public var access:NativeAccess,actors:Array,inputs:Array;
      public var tick:uint=0,roomSteps:uint=0,spawns:uint=0,remoteObjectSteps:uint=0;
      public var spawnsByPlayer:Array=[0,0];
      public var afterStep:Function,failed:Function;
      public var tactics:TacticsBridge;
      public var lives:PlayerLives;
      public var travel:PartyTravel;
      public var rooms:OccupiedRooms,transfers:RoomTransfers;
      private var oldPlayerHook:Function,oldRoomHook:Function,oldObjectHook:Function,oldDamageHook:Function;
      private var oldFindHook:Function,perception:NativePerception;
      private var oldGotoHook:Function;
      private var oldChallengeHook:Function;
      private var projectileIds:Dictionary=new Dictionary(true),nextProjectile:uint=0;
      private var ownerSpawns:Dictionary=new Dictionary(true);
      private var interactionOwners:Dictionary=new Dictionary(true);
      private var latestByRoom:Dictionary=new Dictionary(true),recent:Array=[];
      public function RoomRuntime(access:NativeAccess,actors:Array,inputs:Array) {
         this.access=access;this.actors=actors;this.inputs=inputs;
      }
      public function install():void {
         access.checkHooks();
         var Location:Class=access.definition("fe.loc.Location"),Land:Class=access.definition("fe.loc.Land"),Player:Class=access.definition("fe.unit.UnitPlayer");
         oldPlayerHook=Location["rconnectPlayerStep"];oldRoomHook=Land["rconnectRoomStep"];
         oldObjectHook=Location["rconnectObjectStep"];oldDamageHook=Player["rconnectDamage"];
         oldGotoHook=Land["rconnectGotoRoom"];
         oldChallengeHook=Land["rconnectGotoChallenge"];
         var Unit:Class=access.definition("fe.unit.Unit");oldFindHook=Unit["rconnectFindTarget"];
         if(oldPlayerHook!=null || oldRoomHook!=null || oldObjectHook!=null || oldDamageHook!=null || oldFindHook!=null || oldGotoHook!=null)throw new Error("Native scheduling seam already occupied");
         rooms=new OccupiedRooms(access,actors);transfers=new RoomTransfers(access,actors,inputs,rooms);
         Land["rconnectGotoRoom"]=transfers.request;
         Land["rconnectGotoChallenge"]=transfers.challenge;
         perception=new NativePerception(access.scope,actors);Unit["rconnectFindTarget"]=perception.find;
         Location["rconnectPlayerStep"]=stepPlayers;Location["rconnectObjectStep"]=stepObject;
         Land["rconnectRoomStep"]=stepLand;Player["rconnectDamage"]=damagePlayer;
      }
      private function stepObject(room:Object,object:Object):void {
         var bullet:Boolean=NativeAccess.get(object,"owner")!=null && NativeAccess.get(object,"weap")!=null && NativeAccess.get(object,"begx")!=null;
         if(bullet)projectile(room,object);
         stepOwnedObject(room,object);
         if(bullet) {
            var finalState:Object=projectile(room,object);
            if(!object.in_chain) {
               finalState.ended=true;recent.push(finalState);
            }
         }
      }
      private function stepOwnedObject(room:Object,object:Object):void {
         var inter:Object=NativeAccess.get(object,"inter"),operator:PlayerActor=interactionOwners[object];
         if(operator!=null && inter!=null) {
            WorldClaims.step(object,room,operator,actors);
            if(!inter.is_act && operator.interacting!==object)delete interactionOwners[object];
            return;
         }
         var claimant:PlayerActor=WorldClaims.choose(object,room,actors);
         if(claimant!=null){WorldClaims.step(object,room,claimant,actors);return;}
         var owner:Object=NativeAccess.get(object,"owner");
         for each(var actor:PlayerActor in actors) {
            if(object===actor.unit)throw new Error("Player was also inserted into native object chain");
            if(owner===actor.unit || object===actor.unit.pet) {
               if(actor.id==1)++remoteObjectSteps;
               access.scope.runRoom(actor.context,room,function():void {object.step();});return;
            }
         }
         // Native hostile AI falls back to loc.gg. Give it a real player in
         // this room; preserve a live target, otherwise inspect the nearer one.
         if(room.units.indexOf(object)>=0 && !object.player && !object.disabled) {
            var chosen:PlayerActor=null,best:Number=Number.POSITIVE_INFINITY;
            for each(actor in actors)if(actor.unit.loc===room && actor.unit.hp>0 && !actor.unit.disabled) {
               var d:Number=Math.pow(actor.unit.X-object.X,2)+Math.pow(actor.unit.Y-object.Y,2);
               if(NativeAccess.get(object,"celUnit")===actor.unit){chosen=actor;break;}
               if(d<best){chosen=actor;best=d;}
            }
            if(chosen!=null) {access.scope.run(chosen.context,function():void {object.step();});return;}
         }
         object.step();
      }
      private function damagePlayer(unit:Object,amount:Number,type:int,bullet:Object,periodic:Boolean):Number {
         for each(var actor:PlayerActor in actors)if(actor.unit===unit)
            return Number(access.scope.run(actor.context,function():Number {return unit.damage(amount,type,bullet,periodic);}));
         throw new Error("Damage requested for an unregistered native player");
      }
      private function stepPlayers(room:Object):void {
         for(var i:int=0;i<actors.length;i++)if(actors[i].unit.loc===room) {
            if(actors[i].lastStep==tick)throw new Error("Player stepped twice in one world tick");
            actors[i].lastStep=tick;
            actors[i].step(inputs[i].consume(getTimer()));inputs[i].weaponEpoch=actors[i].weaponEpoch;
            if(actors[i].interacting!=null)interactionOwners[actors[i].interacting]=actors[i];
         }
         capture(room);
      }
      private function stepLand(land:Object):void {
         try {
            if(travel!=null && land!==actors[0].context.land)travel.rebind(land);
            ++tick;
            var occupied:Array=rooms.occupied();
            for each(var room:Object in occupied) {
               var representative:PlayerActor=null;
               for each(var a:PlayerActor in actors)if(a.unit.loc===room){representative=a;break;}
               if(representative==null)throw new Error("Room lost its occupant during a simulation step");
               access.scope.run(representative.context,function():void {
                  room.step();++roomSteps;++rooms.services(room).steps;
                  if(tactics!=null)tactics.step(room,tick);
                  capture(room);
               });
            }
            for each(var actor:PlayerActor in actors)actor.finishWorldServices();
            transfers.commit();if(lives!=null)lives.step();rooms.occupied();rooms.showHost();
            if(access.scope.depth!=0)throw new Error("Native context leaked across a world step");
            if(afterStep!=null)afterStep();
         }catch(error:*) {
            Log.error(error);
            if(failed!=null)failed(String(error));
         }
      }
      private function capture(room:Object):void {
         var latestProjectiles:Object=latestByRoom[room];if(latestProjectiles==null)latestProjectiles={};
         var seen:Object={},object:Object=room.firstObj,count:int=0;
         while(object!=null && ++count<=10000) {
            var owner:Object=NativeAccess.get(object,"owner"),weapon:Object=NativeAccess.get(object,"weap");
            if(owner!=null && weapon!=null && NativeAccess.get(object,"begx")!=null) {
               var state:Object=projectile(room,object);seen[String(state.id)]=state;
            }
            object=object.nobj;
         }
         if(count>10000)throw new Error("Native object chain exceeds bound");
         for(var key:String in latestProjectiles)if(seen[key]==null && !latestProjectiles[key].ended) {
            var end:Object=PoseTween.copy(latestProjectiles[key]);end.ended=true;end.tick=tick;recent.push(end);
         }
         latestByRoom[room]=seen;
         if(recent.length>1024)throw new Error("Projectile event queue overflow");
      }
      private function projectile(room:Object,object:Object):Object {
         var owner:Object=object.owner,id:uint=projectileIds[object],born:Boolean=id==0;
         if(born) {
            id=++nextProjectile;projectileIds[object]=id;++spawns;ownerSpawns[owner]=uint(ownerSpawns[owner])+1;
            if(owner===actors[0].unit)++spawnsByPlayer[0];else if(owner===actors[1].unit)++spawnsByPlayer[1];
         }
         var clip:DisplayObject=object.vis as DisplayObject;
         var state:Object={id:id,room:access.keyFor(room),x:object.X,y:object.Y,dx:object.dx,dy:object.dy,
            bx:object.begx,by:object.begy,tick:tick,owner:owner===actors[0].unit?0:owner===actors[1].unit?1:-1,
            clip:clip==null?"":getQualifiedClassName(clip),rotation:clip==null?0:clip.rotation,visual:VisualPose.capture(clip),
            sx:clip==null?1:clip.scaleX,sy:clip==null?1:clip.scaleY,frame:NativeAccess.get(clip,"currentFrame",1),layer:object.sloy,born:born};
         if(latestByRoom[room]==null)latestByRoom[room]={};latestByRoom[room][String(id)]=state;
         if(born)recent.push(state);
         return state;
      }
      public function clearDepartedRooms():void {latestByRoom=new Dictionary(true);recent=[];interactionOwners=new Dictionary(true);}
      public function snapshot():Object {
         var objects:Array=[],events:Array=recent;recent=[];
         for each(var latest:Object in latestByRoom)for each(var value:Object in latest)objects.push(value);
         return {tick:tick,roomSteps:roomSteps,rooms:rooms.summary(),spawns:spawns,spawnsByPlayer:spawnsByPlayer.concat(),projectiles:objects,projectileEvents:events};
      }
      public function spawnsFor(owner:Object):uint {return uint(ownerSpawns[owner]);}
      public function dispose():void {
         var Location:Class=access.definition("fe.loc.Location"),Land:Class=access.definition("fe.loc.Land"),Player:Class=access.definition("fe.unit.UnitPlayer");
         Location["rconnectPlayerStep"]=oldPlayerHook;Land["rconnectRoomStep"]=oldRoomHook;
         Location["rconnectObjectStep"]=oldObjectHook;Player["rconnectDamage"]=oldDamageHook;
         Land["rconnectGotoRoom"]=oldGotoHook;
         Land["rconnectGotoChallenge"]=oldChallengeHook;
         access.definition("fe.unit.Unit")["rconnectFindTarget"]=oldFindHook;perception=null;
         if(tactics!=null){tactics.dispose();tactics=null;}
         if(rooms!=null)rooms.dispose();
         recent=[];latestByRoom=new Dictionary(true);projectileIds=new Dictionary(true);ownerSpawns=new Dictionary(true);
      }
   }
}
