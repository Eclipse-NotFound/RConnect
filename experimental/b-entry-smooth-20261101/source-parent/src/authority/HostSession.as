package authority {
   import flash.utils.getTimer;
   public class HostSession {
      public var access:NativeAccess,session:String,link:Link;
      public var actors:Array=[],inputs:Array=[],runtime:RoomRuntime;
      public var active:Boolean=false,failed:Function,lastFrame:Object;
      public var presentations:uint=0;
      public var tactics:TacticsBridge;
      public var lives:PlayerLives,saves:PersonalSaves;
      public var grips:PeerGrabs;
      public var travel:PartyTravel;
      public var combat:FriendlyCombat;
      public var security:SecurityTerminals;
      public var sound:SessionSound;
      public var projectileSelection:ProjectileSelection;
      private var nativeMenus:NativeMenus;
      private var expectedRoom:String;
      private var scene:SceneSnapshot;
      private var encoder:FrameDelta=new FrameDelta();
      public var pause:SharedPause=new SharedPause();
      public function HostSession(access:NativeAccess,session:String){this.access=access;this.session=session;}
      public function accept(link:Link,hello:Object):void {
         if(active || !Commands.greetingMatches(hello,session))throw new Error("Architecture/build/session mismatch");
         access.checkHooks();
         expectedRoom=access.roomKey();
         var local:PlayerActor=PlayerActor.local(access);
         // The host may be standing at a ledge or beside a wall. An arbitrary
         // horizontal offset can spawn the second player in a shaft.
         var remote:PlayerActor=access.createPlayer(hello.profile,access.world.loc,local.unit.X,local.unit.Y);
         actors=[local,remote];this.link=link;
         nativeMenus=new NativeMenus(access,null,this);
         local.observeWeapon();remote.observeWeapon();
         local.unit.isSats=remote.unit.isSats=false;
         security=new SecurityTerminals(this);local.security=remote.security=security;
         combat=new FriendlyCombat(this);
         if(access.addons!=null)access.addons.bind(this,hello.profile.addons);
         if(access.weapons!=null)access.weapons.bind(this,hello.profile.msw);
         grips=new PeerGrabs(actors);local.grips=remote.grips=grips;
         if(tactics!=null)tactics.bind(actors);
         for(var i:int=0;i<2;i++) {
            inputs.push(new Commands(session,i,expectedRoom,access.addons==null?null:access.addons.acceptsInput));
            actors[i].failed=fail;
         }
         runtime=new RoomRuntime(access,actors,inputs);runtime.afterStep=capturePresentation;runtime.failed=fail;
         projectileSelection=new ProjectileSelection(runtime);remote.projectileSelection=projectileSelection;
         runtime.tactics=tactics;runtime.security=security;
         runtime.install();active=true;
         if(access.time!=null)access.time.bind(this);
         runtime.transfers.notice=notice;
         for each(var member:PlayerActor in actors)member.requestMeet=function(requester:PlayerActor):void{runtime.transfers.meet(requester);};
         lives=new PlayerLives(this);runtime.lives=lives;saves=new PersonalSaves(access,this);
         travel=new PartyTravel(this);runtime.travel=travel;
         scene=new SceneSnapshot(access);scene.security=security;
         sound=new SessionSound(access,actors);
         runtime.music=sound.music;
         for each(var actor:PlayerActor in actors)actor.resolveTarget=scene.target;
         var welcome:Object=Commands.greeting("welcome",session);welcome.player=1;welcome.room=expectedRoom;welcome.epoch=1;welcome.weaponEpoch=1;
         welcome.profile=access.profile();
         link.send(welcome);
         Log.write("host-ready",{room:expectedRoom,localClass:"UnitPlayer",remoteClass:"AuthorityPlayer",independent:
            local.unit.pers!==remote.unit.pers && local.unit.invent!==remote.unit.invent && local.unit.ctr!==remote.unit.ctr});
         // Send tick zero before advancing either player. The joining machine
         // must assemble its first confirmed view before combat begins.
         publish();
      }
      public function receive(value:Object):void {
         if(!active || value.type!=="input" || value.player!==1)return;
         var reason:String=inputs[1].accept(value,getTimer());
         if(reason==""){pause.remote=value.pause===true;pause.remoteMenus=value.pauseMenus===true;pause.remoteSats=value.pauseSats===true;}
         if(reason=="" && runtime.awaitingFirstView && value.confirmation is Number && value.confirmation>=0 &&
            value.confirmation==uint(value.confirmation) && value.confirmation<=runtime.tick) {
            runtime.awaitingFirstView=false;Log.write("peer-view-ready",{tick:runtime.tick,seq:value.seq});
         }
         if(reason=="")personal(actors[1],value.settings);
         // A native entry script may transfer/equip the party while the first
         // view is still being assembled. Keep rejecting stale controls, but
         // publish the new identity instead of waiting for an identity the
         // joining side has never received. Simulation remains stopped.
         if(reason=="identity" && runtime.awaitingFirstView && lastFrame!=null) {
            var sent:Object=lastFrame.players[1],remote:PlayerActor=actors[1];
            if(sent.room!==inputs[1].room || sent.roomEpoch!==remote.roomEpoch ||
               sent.epoch!==remote.epoch || sent.weaponEpoch!==remote.weaponEpoch)publish();
         }
         if(reason!="" && reason!="sequence")link.send({type:"rejected",seq:value.seq,reason:reason});
      }
      public function localInput(value:Object):void {
         if(!active)return;
         var reason:String=inputs[0].accept(value,getTimer());
         if(reason!="")throw new Error("Invalid local input: "+reason);
         personal(actors[0],value.settings);
      }
      private function personal(actor:PlayerActor,state:Object):void {
         if(state==null)return;
         for each(var key:String in ["allowGrab","struggle","thrownDamage","follow"])if(state[key] is Boolean)actor.personal[key]=state[key];
      }
      public function menus():void {
         var changed:Boolean=false;
         for each(var actor:PlayerActor in actors) {
            var batch:Array=inputs[actor.id].takeMenus();
            if(batch.length==0)continue;
            changed=true;
            access.scope.run(actor.context,function():void {
               for each(var action:Object in batch) {
                  var ok:Boolean=NativeIntents.execute(actor,action.key,action.args);
                  Log.write("native-menu-action",{player:actor.id,key:action.key,accepted:ok});
               }
            });
            actor.observeWeapon();inputs[actor.id].weaponEpoch=actor.weaponEpoch;
         }
         // Native World services only its local GUI. The second GUI owns
         // original dialogue/information scripts and must advance even while
         // the combat world is paused, using that player's acknowledgement.
         var remote:PlayerActor=actors[1];
         access.scope.run(remote.context,function():void {remote.context.gui.step();});
         if(changed && pause.paused)publish();
      }
      public function publish():void {
         if(active)runtime.requestPresentation();
      }
      private function capturePresentation():void {
         if(!active)return;
         var began:int=Timing.start(),part:int=began;
         if(access.injury!=null)access.injury.afterWorld(actors);
         if(access.weapons!=null)access.weapons.present(access.weapons.snapshot(0));
         if(access.addons!=null)access.addons.present(access.addons.snapshot(0));
         if(access.time==null || access.time.phase!="replay"){grips.present();combat.update();}
         var frame:Object=runtime.snapshot();frame.type="frame";frame.session=session;frame.room=access.keyFor(actors[1].unit.loc);
         frame.presentation=++presentations;
         // Display may be replaying an older room/weapon. Reliable controls
         // continue to name the live endpoint, never the historical picture.
         frame.control={room:inputs[1].room,roomEpoch:inputs[1].roomEpoch,epoch:inputs[1].epoch,weaponEpoch:inputs[1].weaponEpoch};
         frame.time=getTimer();
         frame.paused=pause.paused;frame.pauseEpoch=pause.epoch;
         if(access.time!=null){frame.timeControl=access.time.snapshot(frame.paused,1);access.time.present(access.time.snapshot(frame.paused,0));}
         frame.pausePolicies={menus:pause.enabled || pause.policyMenus,sats:pause.enabled || pause.policySats};
         frame.map=MapState.capture(actors[1].unit.loc.land);
         frame.players=[actors[0].snapshot(inputs[0].consumed),actors[1].snapshot(inputs[1].consumed)];
         for each(var actor:PlayerActor in actors) {
            frame.players[actor.id].key=scene.id(actor.unit);
            if(frame.players[actor.id].held!=null)frame.players[actor.id].held.key=scene.id(actor.unit.teleObj);
            frame.players[actor.id].actionAck=inputs[actor.id].receivedAction;
         }
         frame.friendlyFire=combat.enabled;frame.securityShared=security.shared;
         frame.horseshoeShared=runtime.shareHorseshoeXP;
         frame.audio=sound.snapshot(frame.room,runtime.tick,frame.paused);
         frame.scene=scene.capture(actors[1].unit.loc,actors,runtime.tick);
         Timing.end("host.sceneAndPlayers",part);part=Timing.start();
         frame.character=CharacterState.capture(actors[1]);
         if(access.weapons!=null)frame.character.msw=access.weapons.snapshot(1);
         if(access.addons!=null)frame.character.addons=access.addons.snapshot(1);
         if(access.injury!=null)frame.character.injury=access.injury.snapshot(actors[1]);
         Timing.end("host.character",part);part=Timing.start();
         frame.resources={hold:actors[1].unit.currentWeapon==null?0:actors[1].unit.currentWeapon.hold,
            hp:actors[1].unit.hp,mana:actors[1].unit.mana};
         lastFrame=frame;
         // The runtime and lastFrame retain both rooms' complete lifetimes.
         // Only the peer's displayed room needs projectile pictures on wire.
         // During replay frame.room can differ from the live control endpoint.
         var outgoing:Object=PoseTween.copy(frame);
         outgoing.projectiles=projectilesForRoom(frame.projectiles,frame.room);
         outgoing.projectileEvents=projectilesForRoom(frame.projectileEvents,frame.room);
         var packet:Object=encoder.encode(outgoing);Timing.end("host.delta",part);part=Timing.start();
         if(!link.send(packet))fail("Cannot publish confirmation");
         else projectileSelection.published(outgoing);
         Timing.end("host.send",part);Timing.end("host.publish",began);
      }
      private static function projectilesForRoom(values:Array,room:String):Array {
         var out:Array=[];
         // Preserve births, final states and order, including a projectile
         // that appears and ends in the same host tick. No visibility culling.
         for each(var value:Object in values)if(value.room===room)out.push(value);
         return out;
      }
      public function fail(reason:String):void {
         if(!active)return;
         active=false;access.world.onPause=true;
         for each(var c:Commands in inputs)c.clear();
         Log.write("session-failed",{reason:reason});
         if(link!=null)link.send({type:"stopped",reason:reason});
         if(failed!=null)failed(reason);
      }
      public function dispose():void {
         active=false;
         pause.dispose();
         for each(var owner:PlayerActor in actors)access.scope.run(owner.context,function():void {owner.unit.dropTeleObj();owner.context.sats.clearAll();});
         if(travel!=null)travel.dispose();
         if(combat!=null)combat.dispose();
         if(security!=null)security.dispose();
         if(lives!=null)lives.dispose();if(saves!=null)saves.dispose();
         if(nativeMenus!=null)nativeMenus.dispose();
         if(sound!=null)sound.dispose();
         if(projectileSelection!=null)projectileSelection.clear();
         if(runtime!=null)runtime.dispose();
         if(scene!=null)scene.dispose();
         for each(var actor:PlayerActor in actors)actor.destroy();
         actors=[];inputs=[];
      }
      public function resetScene():void {scene.reset();}
      public function fullScene():void {scene.fullNext();}
      public function sceneId(object:Object):uint {return scene.id(object);}
      public function notice(text:String):void {link.send({type:"notice",text:text});Log.write("notice",{text:text});}
   }
}
