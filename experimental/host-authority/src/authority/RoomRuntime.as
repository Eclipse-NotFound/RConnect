package authority {
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
      private var oldPlayerHook:Function,oldRoomHook:Function,oldObjectHook:Function,oldDamageHook:Function;
      private var oldFindHook:Function,perception:NativePerception;
      private var projectileIds:Dictionary=new Dictionary(true),nextProjectile:uint=0;
      private var ownerSpawns:Dictionary=new Dictionary(true);
      private var latestProjectiles:Object={},recent:Array=[];
      public function RoomRuntime(access:NativeAccess,actors:Array,inputs:Array) {
         this.access=access;this.actors=actors;this.inputs=inputs;
      }
      public function install():void {
         access.checkHooks();
         var Location:Class=access.definition("fe.loc.Location"),Land:Class=access.definition("fe.loc.Land"),Player:Class=access.definition("fe.unit.UnitPlayer");
         oldPlayerHook=Location["rconnectPlayerStep"];oldRoomHook=Land["rconnectRoomStep"];
         oldObjectHook=Location["rconnectObjectStep"];oldDamageHook=Player["rconnectDamage"];
         var Unit:Class=access.definition("fe.unit.Unit");oldFindHook=Unit["rconnectFindTarget"];
         if(oldPlayerHook!=null || oldRoomHook!=null || oldObjectHook!=null || oldDamageHook!=null || oldFindHook!=null)throw new Error("Native scheduling seam already occupied");
         perception=new NativePerception(access.scope,actors);Unit["rconnectFindTarget"]=perception.find;
         Location["rconnectPlayerStep"]=stepPlayers;Location["rconnectObjectStep"]=stepObject;
         Land["rconnectRoomStep"]=stepLand;Player["rconnectDamage"]=damagePlayer;
      }
      private function stepObject(room:Object,object:Object):void {
         var owner:Object=NativeAccess.get(object,"owner");
         for each(var actor:PlayerActor in actors) {
            if(object===actor.unit)throw new Error("Player was also inserted into native object chain");
            if(owner===actor.unit) {
               if(actor.id==1)++remoteObjectSteps;
               access.scope.run(actor.context,function():void {object.step();});return;
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
            actors[i].step(inputs[i].consume(getTimer()));inputs[i].weaponEpoch=actors[i].weaponEpoch;
         }
         capture(room);
      }
      private function stepLand(land:Object):void {
         try {
            ++tick;
            // B1: one room. The extension to occupied-room sets stays here,
            // not in World.step or in a second independent timer.
            land.loc.step();++roomSteps;
            for each(var actor:PlayerActor in actors)actor.finishWorldServices();
            if(tactics!=null)tactics.step(land.loc,tick);
            capture(land.loc);
            if(access.scope.depth!=0)throw new Error("Native context leaked across a world step");
            if(afterStep!=null)afterStep();
         }catch(error:*) {
            Log.error(error);
            if(failed!=null)failed(String(error));
         }
      }
      private function capture(room:Object):void {
         var seen:Object={},object:Object=room.firstObj,count:int=0;
         while(object!=null && ++count<=10000) {
            var owner:Object=NativeAccess.get(object,"owner"),weapon:Object=NativeAccess.get(object,"weap");
            if(owner!=null && weapon!=null && NativeAccess.get(object,"begx")!=null) {
               var id:uint=projectileIds[object];
               if(id==0){id=++nextProjectile;projectileIds[object]=id;++spawns;
                  ownerSpawns[owner]=uint(ownerSpawns[owner])+1;
                  if(owner===actors[0].unit)++spawnsByPlayer[0];else if(owner===actors[1].unit)++spawnsByPlayer[1];}
               var clip:Object=object.vis;
               var state:Object={id:id,x:object.X,y:object.Y,dx:object.dx,dy:object.dy,
                  bx:object.begx,by:object.begy,tick:tick,owner:owner===actors[0].unit?0:owner===actors[1].unit?1:-1,
                  clip:clip==null?"":getQualifiedClassName(clip),rotation:clip==null?0:clip.rotation,
                  sx:clip==null?1:clip.scaleX,sy:clip==null?1:clip.scaleY,frame:clip==null?1:clip.currentFrame,
                  born:latestProjectiles[String(id)]==null};
               seen[String(id)]=state;
               if(state.born)recent.push(state);
            }
            object=object.nobj;
         }
         if(count>10000)throw new Error("Native object chain exceeds bound");
         for(var key:String in latestProjectiles)if(seen[key]==null) {
            var end:Object=latestProjectiles[key];end.ended=true;end.tick=tick;recent.push(end);
         }
         latestProjectiles=seen;
         if(recent.length>1024)throw new Error("Projectile event queue overflow");
      }
      public function snapshot():Object {
         var objects:Array=[],events:Array=recent;recent=[];
         for each(var value:Object in latestProjectiles)objects.push(value);
         return {tick:tick,roomSteps:roomSteps,spawns:spawns,spawnsByPlayer:spawnsByPlayer.concat(),projectiles:objects,projectileEvents:events};
      }
      public function spawnsFor(owner:Object):uint {return uint(ownerSpawns[owner]);}
      public function dispose():void {
         var Location:Class=access.definition("fe.loc.Location"),Land:Class=access.definition("fe.loc.Land"),Player:Class=access.definition("fe.unit.UnitPlayer");
         Location["rconnectPlayerStep"]=oldPlayerHook;Land["rconnectRoomStep"]=oldRoomHook;
         Location["rconnectObjectStep"]=oldObjectHook;Player["rconnectDamage"]=oldDamageHook;
         access.definition("fe.unit.Unit")["rconnectFindTarget"]=oldFindHook;perception=null;
         if(tactics!=null){tactics.dispose();tactics=null;}
         recent=[];latestProjectiles={};projectileIds=new Dictionary(true);ownerSpawns=new Dictionary(true);
      }
   }
}
