package authority {
   /** Host native travel, then one transaction rebinds both existing actors. */
   public final class PartyTravel {
      private var session:HostSession,oldIntent:Function;
      public function PartyTravel(session:HostSession) {
         this.session=session;
         var Type:Class=session.access.definition("fe.loc.Game");oldIntent=Type["rconnectIntent"];
         if(oldIntent!=null)throw new Error("Host map intent seam occupied");Type["rconnectIntent"]=request;
      }
      private function request(target:Object,key:String,args:Array):Boolean {
         if(session.access.world.gg!==session.actors[0].unit) {
            session.link.send({type:"notice",text:"整张地图旅行由宿主发起。"});return true;
         }
         return false;
      }
      public function rebind(land:Object):void {
         var access:NativeAccess=session.access,w:Object=access.world,r:RoomRuntime=session.runtime;
         var old:Object=session.actors[1].unit.loc,hostX:Number=w.gg.X,hostY:Number=w.gg.Y;
         for each(var a:PlayerActor in session.actors) {
            // The native host has already entered the new map. No call may
            // borrow the old room service while adopting the new references.
            session.inputs[a.id].clear();
            a.context.loc=w.loc;a.context.land=land;a.context.transitionCooldown=0;
         }
         r.rooms.dispose();
         r.clearDepartedRooms();
         var b:PlayerActor=session.actors[1],i:int=old.units.indexOf(b.unit);
         if(i>=0)old.units.splice(i,1);
         access.scope.run(b.context,function():void {
            b.unit.remVisual();var roster:Array=w.loc.units.concat();
            b.context.sats.clearAll();b.unit.dropTeleObj();
            b.unit.inLoc(w.loc);w.loc.units=roster;b.unit.setLocPos(hostX,hostY);b.unit.controlOn();
         });
         r.rooms=new OccupiedRooms(access,session.actors);
         r.transfers=new RoomTransfers(access,session.actors,session.inputs,r.rooms);
         access.definition("fe.loc.Land")["rconnectGotoRoom"]=r.transfers.request;
         access.definition("fe.loc.Land")["rconnectGotoChallenge"]=r.transfers.challenge;r.transfers.notice=session.notice;
         for each(a in session.actors) {
            r.rooms.prepare(a);++a.roomEpoch;
            session.inputs[a.id].retarget(access.keyFor(a.unit.loc),a.roomEpoch);
            a.spawn={room:a.unit.loc,x:a.unit.X,y:a.unit.Y};
         }
         r.rooms.showHost();session.resetScene();
         Log.write("party-map-entered",{map:land.act.id,seed:land.rconnectLayoutSeed,room:access.roomKey()});
      }
      public function dispose():void {session.access.definition("fe.loc.Game")["rconnectIntent"]=oldIntent;}
   }
}
