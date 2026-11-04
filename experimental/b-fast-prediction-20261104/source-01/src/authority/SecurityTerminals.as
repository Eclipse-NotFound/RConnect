package authority {
   import flash.utils.Dictionary;
   /** Host-only native security. The shared terminal keeps two personal lock
    * states; a successful activation records an immutable scope for each grant.
    * Native Interact, turret perception, weapons and damage still do the work. */
   public final class SecurityTerminals {
      public var shared:Boolean=true;
      private var session:HostSession,oldHook:Function;
      private var terminals:Dictionary=new Dictionary(true),turrets:Dictionary=new Dictionary(true);
      private var actorDepth:int=0;
      public var activations:uint=0;
      public function SecurityTerminals(session:HostSession) {
         this.session=session;
         var Unit:Class=session.access.definition("fe.unit.Unit");
         if(!("RCONNECT_SECURITY_B" in Unit) || Unit["RCONNECT_SECURITY_B"]!=="b-security-v1")
            throw new Error("B security native interface is unavailable");
         oldHook=Unit["rconnectSecurityB"];
         if(oldHook!=null)throw new Error("B security native interface is occupied");
         Unit["rconnectSecurityB"]=hook;
      }
      private function actorFor(unit:Object):PlayerActor {
         if(unit==null)return null;
         if("rconnectOwner" in unit && unit.rconnectOwner!=null)unit=unit.rconnectOwner;
         for each(var actor:PlayerActor in session.actors)if(actor.unit===unit || actor.unit.pet===unit)return actor;
         return null;
      }
      public function owns(inter:Object):Boolean {
         return inter!=null && inter.allact=="hack_robot" && inter.prob==null;
      }
      private function isTurret(unit:Object):Boolean {
         return unit!=null && "rconnectSecurityClear" in unit;
      }
      private function record(inter:Object):Object {
         var r:Object=terminals[inter];
         if(r==null) {
            var initial:Object=inter.rconnectSecurityState();
            r={inter:inter,players:[PlainData.copy(initial),PlainData.copy(initial)],open:[false,false],pending:[false,false]};
            terminals[inter]=r;
         }
         return r;
      }
      private function inRoom(room:Object):Array {
         var list:Array=[],seen:Dictionary=new Dictionary(true);
         for each(var objects:Array in [room.objs,room.acts])for each(var object:Object in objects)
            if(object!=null && !seen[object] && "inter" in object && owns(object.inter)) {
               seen[object]=true;list.push(record(object.inter));
            }
         return list;
      }
      private function restore(r:Object,player:int):void {
         var state:Object=r.players[player];
         if(r.open[player]){state.lock=0;state.saveLock=101;}
         r.inter.rconnectSecurityState(state);
      }
      /** Called only around a real player's native step, so both players may
       * work on the same terminal without sharing attempts or unlock skill. */
      public function player(actor:PlayerActor,operation:Function):void {
         var list:Array=inRoom(actor.unit.loc),r:Object;
         if(list.length==0){operation();return;}
         if(actorDepth!=0)throw new Error("Security player context re-entered");
         ++actorDepth;
         try {
            for each(r in list)restore(r,actor.id);
            operation();
         } finally {
            for(var i:int=0;i<list.length;i++) {
               r=list[i];r.players[actor.id]=r.inter.rconnectSecurityState();
               if(r.players[actor.id].is_act){r.pending[actor.id]=true;r.players[actor.id].is_act=false;}
               // Outside player work, the host's native pointer/UI sees the
               // host's own state. Remote presentation is read separately.
               restore(r,0);
            }
            --actorDepth;
         }
      }
      /** Interact.act runs per completed personal request. The actual object
       * and its timers/physics still step exactly once in the native room chain. */
      public function stepObject(room:Object,object:Object):Boolean {
         if(object==null || !("inter" in object) || !owns(object.inter))return false;
         // Land construction also calls Location.preStep/stepInvis through
         // this hook, before either actor occupies the new room. Let native
         // initialization finish before recording any personal lock state.
         var representative:PlayerActor=null;
         for each(var actor:PlayerActor in session.actors)if(actor.unit.loc===room){representative=actor;break;}
         if(representative==null)return false;
         var r:Object=record(object.inter),done:Array=[false,false],inter:Object=object.inter;
         for each(actor in session.actors)if(r.pending[actor.id]) {
            r.pending[actor.id]=false;done[actor.id]=true;
            if(actor.unit.loc!==room || actor.unit.sost>=3 || actor.unit.hp<=0)continue;
            session.access.scope.run(actor.context,function():void {
               restore(r,actor.id);
               try {inter.act();}
               finally {r.players[actor.id]=inter.rconnectSecurityState();r.players[actor.id].is_act=false;restore(r,0);}
            });
         }
         // All personal activations were consumed above; no second native act.
         inter.is_act=false;
         session.access.scope.run(representative.context,function():void {object.step();});
         for(var id:int=0;id<2;id++)if(!done[id])r.players[id].is_ready=true;
         restore(r,0);return true;
      }
      public function capture(inter:Object,player:int):Object {
         if(!owns(inter))return NativeFields.capture(inter);
         var r:Object=record(inter),prior:Object=inter.rconnectSecurityState(),result:Object;
         try {restore(r,player);result=NativeFields.capture(inter);}
         finally {inter.rconnectSecurityState(prior);}
         return result;
      }
      private function grant(inter:Object,actor:PlayerActor,skill:int):void {
         var r:Object=record(inter),first:Boolean=!r.open[actor.id],fresh:Boolean=false;
         // allAct is inside native act(): retain the lock result just obtained,
         // rather than restoring its pre-attempt fields over the native result.
         r.players[actor.id]=inter.rconnectSecurityState();
         if(first) {
            r.open[actor.id]=true;
            if(shared)r.open[0]=r.open[1]=true;
         }
         for each(var unit:Object in inter.owner.loc.units)if(isTurret(unit) && unit.sost<3 && unit.hp>0) {
            var g:Object=turrets[unit],state:Object=unit.rconnectSecurityState();
            // Saved/scripted global safety is never narrowed by a personal hack.
            if(g==null && (state.sleep || state.reprog || unit.fraction==100))continue;
            if(g==null)g=turrets[unit]={players:[false,false],skill:-1};
            // Switching individual -> shared cannot reshare an earlier grant
            // by pressing that already-authorized terminal again.
            if(g.players[actor.id])continue;
            fresh=true;
            g.players[actor.id]=true;if(shared)g.players[0]=g.players[1]=true;
            g.skill=skill;
            if(skill>0 || g.players[0] && g.players[1])unit.hack(skill);
            clear(unit);
         }
         // A genuinely new turret grant is a new activation under today's
         // policy. Merely pressing an already-authorized terminal is not.
         if(shared && fresh)r.open[0]=r.open[1]=true;
         ++activations;
         session.access.world.gui.infoText("term1Act");session.access.world.gui.bulb(inter.X,inter.Y);
         restore(r,actor.id);
      }
      public function permission(turret:Object,player:Object):* {
         var g:Object=turrets[turret];if(g==null)return null;
         var actor:PlayerActor=actorFor(player);
         return actor==null || g==null?null:g.players[actor.id]===true;
      }
      public function hit(source:Object,target:Object,nativeAllowed:Boolean):Boolean {
         var p:*=permission(source,target);
         if(p!==null)return !Boolean(p);
         if(permission(target,source)===false)return true;
         return nativeAllowed;
      }
      private function clear(turret:Object):void {
         turret.rconnectSecurityClear(function(unit:Object):Boolean {return permission(turret,unit)===true;});
      }
      private function detect(turret:Object,target:Object,force:Boolean,state:Object):Boolean {
         if(state.sleep || turret.oduplenie>0 || !turret.isMeet(target) || target.sost>=3 || target.hp<=0 || target.invulner)return false;
         if(state.absolute && !state.reprog){turret.setCel(target);return true;}
         var noise:Number=turret.listen(target);if(noise)target.observation(noise);
         var sight:Number=turret.look(target,turret.overLook || force);
         if(sight>0) {
            target.observation(sight,turret.observ);
            if(target.obs>=target.maxObs){turret.setCel(target);return true;}
         }else if(noise>0) {
            if(target.obs>=target.maxObs)turret.setCel(null,target.X+(Math.random()-.5)*200,target.Y+(Math.random()-.5)*200);
            if(noise>1)return true;
         }
         return false;
      }
      private function hook(op:String,object:Object,arg:*=null):* {
         if(op=="terminal") {
            if(!owns(object))return null;
            var actor:PlayerActor=actorFor(session.access.world.gg);
            if(actor==null)return null;
            grant(object,actor,Math.max(0,Math.min(2,int(arg))));return true;
         }
         if(!isTurret(object) || turrets[object]==null)return null;
         clear(object);
         if(op!="find")return null;
         var state:Object=object.rconnectSecurityState();if(state.sleep)return false;
         // Preserve native retaliation against non-player enemies/objects.
         if(state.reprog && object.priorUnit!=null && actorFor(object.priorUnit)==null
            && object.isMeet(object.priorUnit) && object.priorUnit.sost<3 && object.priorUnit.hp>0 && !object.priorUnit.doop)return null;
         var candidates:Array=session.actors.concat();
         if(candidates.length==2 && object.priorUnit===candidates[1].unit)candidates.reverse();
         for each(actor in candidates)if(actor.unit.loc===object.loc && permission(object,actor.unit)===false) {
            var found:Boolean=Boolean(session.access.scope.run(actor.context,function():Boolean {return detect(object,actor.unit,Boolean(arg),state);}));
            if(found)return true;
         }
         if(state.reprog)return null; // Native enemy selection still runs.
         object.celUnit=null;object.priorUnit=null;return false;
      }
      public function resetWorld():void {terminals=new Dictionary(true);turrets=new Dictionary(true);}
      public function dispose():void {
         for(var inter:Object in terminals)restore(terminals[inter],0);
         session.access.definition("fe.unit.Unit")["rconnectSecurityB"]=oldHook;resetWorld();
      }
   }
}
