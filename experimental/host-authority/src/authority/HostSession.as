package authority {
   import flash.utils.getTimer;
   public class HostSession {
      public var access:NativeAccess,session:String,link:Link;
      public var actors:Array=[],inputs:Array=[],runtime:RoomRuntime;
      public var active:Boolean=false,failed:Function,lastFrame:Object;
      public var tactics:TacticsBridge;
      private var expectedRoom:String;
      public function HostSession(access:NativeAccess,session:String){this.access=access;this.session=session;}
      public function accept(link:Link,hello:Object):void {
         if(active || !Commands.greetingMatches(hello,session))throw new Error("Architecture/build/session mismatch");
         access.checkHooks();
         expectedRoom=access.roomKey();
         var local:PlayerActor=PlayerActor.local(access);
         var remote:PlayerActor=access.createPlayer(hello.profile,access.world.loc,local.unit.X+70,local.unit.Y);
         actors=[local,remote];this.link=link;
         if(tactics!=null)tactics.bind(actors);
         for(var i:int=0;i<2;i++) {
            inputs.push(new Commands(session,i,expectedRoom));
            actors[i].failed=fail;
         }
         runtime=new RoomRuntime(access,actors,inputs);runtime.afterStep=publish;runtime.failed=fail;
         runtime.tactics=tactics;
         runtime.install();active=true;
         var welcome:Object=Commands.greeting("welcome",session);welcome.player=1;welcome.room=expectedRoom;welcome.epoch=1;welcome.weaponEpoch=1;
         link.send(welcome);
         Log.write("host-ready",{room:expectedRoom,localClass:"UnitPlayer",remoteClass:"AuthorityPlayer",independent:
            local.unit.pers!==remote.unit.pers && local.unit.invent!==remote.unit.invent && local.unit.ctr!==remote.unit.ctr});
      }
      public function receive(value:Object):void {
         if(!active || value.type!=="input" || value.player!==1)return;
         var reason:String=inputs[1].accept(value,getTimer());
         if(reason!="" && reason!="sequence")link.send({type:"rejected",seq:value.seq,reason:reason});
      }
      public function localInput(value:Object):void {
         if(!active)return;
         var reason:String=inputs[0].accept(value,getTimer());
         if(reason!="")throw new Error("Invalid local input: "+reason);
      }
      private function publish():void {
         if(!active)return;
         var frame:Object=runtime.snapshot();frame.type="frame";frame.session=session;frame.room=inputs[1].room;
         frame.players=[actors[0].snapshot(inputs[0].consumed),actors[1].snapshot(inputs[1].consumed)];
         frame.resources={hold:actors[1].unit.currentWeapon==null?0:actors[1].unit.currentWeapon.hold,
            hp:actors[1].unit.hp,mana:actors[1].unit.mana};
         lastFrame=frame;
         if(!link.send(frame))fail("Cannot publish confirmation");
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
         if(runtime!=null)runtime.dispose();
         for each(var actor:PlayerActor in actors)actor.destroy();
         actors=[];inputs=[];
      }
   }
}
