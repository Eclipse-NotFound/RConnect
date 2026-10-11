package authority {
   /** Real native exit sequence; both players keep their own identity/resources. */
   public final class TravelProbe extends Probe {
      private var phase:int=0,deadline:uint=40,original:Array=[],seeds:Array=[],maps:Object={},visits:int=0,last:String="";
      private var owner:Object;
      public function TravelProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;frame.actions=[];return frame;}
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var w:Object=access.world;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame,map:String=f.map.id+":"+f.map.seed;
            if(map!=last){++visits;last=map;maps[map]=true;}
            if(visits>=5 && w.gg.ggControl && f.tick>550) {
               check(w.land.act.id==f.map.id && w.land.rconnectLayoutSeed==f.map.seed,"join adopts the host's new exploration seed and map");
               check(replica.scene.key==f.room && f.players[0].room==f.players[1].room,"both native actors arrive in the same confirmed destination room");
               check(f.players[0].epoch==1 && f.players[1].epoch==1,"ordinary map travel does not recreate either player");
               check(w.gg.invent.items[w.gg.currentWeapon.ammo].kol==31,"join retains its own bag through repeated map travel");
               SceneChecks.picture(access,"party-travel.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var tick:uint=session.runtime.tick;
         if(original.length==0) {
            owner=w.gg;original=[session.actors[0].unit,session.actors[1].unit];seeds.push(w.land.rconnectLayoutSeed);
         }
         if(tick<deadline || w.t_exit>0)return;
         if(phase<4) {
            for each(var actor:PlayerActor in session.actors)actor.unit.pers.healAll();
            if(phase%2==0)w.game.gotoLand("rbl",null,true);else w.game.beginMission("random_mane");
            ++phase;deadline=tick+130;return;
         }
         check(original[0]===session.actors[0].unit && original[1]===session.actors[1].unit && w.gg===owner,"native party travel retains both real player objects and host controls");
         check(session.actors[0].unit.loc===session.actors[1].unit.loc && session.actors[1].unit.ggControl,"remote player rejoins the new native room with controls enabled");
         check(session.actors[0].unit.invent.items[session.actors[0].unit.currentWeapon.ammo].kol==17 &&
            session.actors[1].unit.invent.items[session.actors[1].unit.currentWeapon.ammo].kol==31,"party travel does not merge ammunition reserves");
         check(seeds[0]!=w.land.rconnectLayoutSeed && w.land.rconnectLayoutSeed!=0,"a new exploration gets a fresh native layout seed",{first:seeds[0],last:w.land.rconnectLayoutSeed});
         check(w.loc===owner.loc && access.scope.depth==0,"new map retains the host's camera and native context");finish();
      }
   }
}
