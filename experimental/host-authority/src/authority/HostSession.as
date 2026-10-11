package authority {
   import flash.utils.getTimer;
   public class HostSession {
      public var access:NativeAccess,session:String,link:Link;
      public var actors:Array=[],inputs:Array=[],runtime:RoomRuntime;
      public var active:Boolean=false,failed:Function,lastFrame:Object;
      public var tactics:TacticsBridge;
      public var lives:PlayerLives,saves:PersonalSaves;
      public var grips:PeerGrabs;
      public var travel:PartyTravel;
      public var combat:FriendlyCombat;
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
         local.observeWeapon();remote.observeWeapon();
         local.unit.isSats=remote.unit.isSats=false;
         combat=new FriendlyCombat(this);
         grips=new PeerGrabs(actors);local.grips=remote.grips=grips;
         if(tactics!=null)tactics.bind(actors);
         for(var i:int=0;i<2;i++) {
            inputs.push(new Commands(session,i,expectedRoom));
            actors[i].failed=fail;
         }
         runtime=new RoomRuntime(access,actors,inputs);runtime.afterStep=publish;runtime.failed=fail;
         runtime.tactics=tactics;
         runtime.install();active=true;
         runtime.transfers.notice=notice;
         lives=new PlayerLives(this);runtime.lives=lives;saves=new PersonalSaves(access,this);
         travel=new PartyTravel(this);runtime.travel=travel;
         scene=new SceneSnapshot(access);
         for each(var actor:PlayerActor in actors)actor.resolveTarget=scene.target;
         var welcome:Object=Commands.greeting("welcome",session);welcome.player=1;welcome.room=expectedRoom;welcome.epoch=1;welcome.weaponEpoch=1;
         welcome.profile=access.profile();
         link.send(welcome);
         Log.write("host-ready",{room:expectedRoom,localClass:"UnitPlayer",remoteClass:"AuthorityPlayer",independent:
            local.unit.pers!==remote.unit.pers && local.unit.invent!==remote.unit.invent && local.unit.ctr!==remote.unit.ctr});
      }
      public function receive(value:Object):void {
         if(!active || value.type!=="input" || value.player!==1)return;
         var reason:String=inputs[1].accept(value,getTimer());
         if(reason=="")pause.remote=value.pause===true;
         if(reason=="")personal(actors[1],value.settings);
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
         if(changed && pause.paused)publish();
      }
      public function publish():void {
         if(!active)return;
         grips.present();
         combat.update();
         var frame:Object=runtime.snapshot();frame.type="frame";frame.session=session;frame.room=inputs[1].room;
         frame.time=getTimer();
         frame.paused=pause.paused;frame.pauseEpoch=pause.epoch;
         frame.map=MapState.capture(actors[1].unit.loc.land);
         frame.players=[actors[0].snapshot(inputs[0].consumed),actors[1].snapshot(inputs[1].consumed)];
         for each(var actor:PlayerActor in actors) {
            frame.players[actor.id].key=scene.id(actor.unit);
            frame.players[actor.id].actionAck=inputs[actor.id].receivedAction;
         }
         frame.friendlyFire=combat.enabled;
         frame.scene=scene.capture(actors[1].unit.loc,actors,runtime.tick);
         frame.character=CharacterState.capture(actors[1]);
         frame.resources={hold:actors[1].unit.currentWeapon==null?0:actors[1].unit.currentWeapon.hold,
            hp:actors[1].unit.hp,mana:actors[1].unit.mana};
         lastFrame=frame;
         if(!link.send(encoder.encode(frame)))fail("Cannot publish confirmation");
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
         if(travel!=null)travel.dispose();
         if(combat!=null)combat.dispose();
         if(lives!=null)lives.dispose();if(saves!=null)saves.dispose();
         if(runtime!=null)runtime.dispose();
         for each(var actor:PlayerActor in actors)actor.destroy();
         actors=[];inputs=[];
      }
      public function resetScene():void {scene.reset();}
      public function notice(text:String):void {link.send({type:"notice",text:text});Log.write("notice",{text:text});}
   }
}
