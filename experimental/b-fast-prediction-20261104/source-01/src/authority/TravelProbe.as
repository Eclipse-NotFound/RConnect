package authority {
   /** Real native exit sequence; both players keep their own identity/resources. */
   public final class TravelProbe extends Probe {
      private var phase:int=0,deadline:uint=40,original:Array=[],seeds:Array=[],maps:Object={},visits:int=0,last:String="";
      private var owner:Object;
      private var observedLand:Object,layouts:Array=[],layoutRefs:Object={},layoutMatches:int=0,layoutWrong:int=0;
      public function TravelProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(!host && value.type=="travel-layout")layoutRefs[value.seed]=value;
      }
      private function layout(land:Object):String {
         var rooms:Array=[];
         for each(var column:Array in land.locs)for each(var row:Array in column)for each(var room:Object in row)if(room!=null)
            rooms.push([room.landX,room.landY,room.landZ,room.id,room.room==null?"":room.room.id,room.mirror].join(":"));
         if(rooms.length<2)throw new Error("Travel fixture failed to inspect real ordinary-room layout");
         rooms.sort();return rooms.join("|");
      }
      override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;frame.actions=[];return frame;}
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var w:Object=access.world;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame,map:String=f.map.id+":"+f.map.seed;
            if(map!=last){++visits;last=map;maps[map]=true;}
            var ref:Object=layoutRefs[f.map.seed];
            if(ref!=null && w.land.rconnectLayoutSeed==f.map.seed) {
               ++layoutMatches;if(layout(w.land)!==ref.layout)++layoutWrong;delete layoutRefs[f.map.seed];
            }
            if(visits>=9 && w.gg.ggControl && f.tick>1070) {
               check(w.land.act.id==f.map.id && w.land.rconnectLayoutSeed==f.map.seed,"join adopts the host's new exploration seed and map");
               check(replica.scene.key==f.room && f.players[0].room==f.players[1].room,"both native actors arrive in the same confirmed destination room");
               check(f.players[0].epoch==1 && f.players[1].epoch==1,"ordinary map travel does not recreate either player");
               check(w.gg.invent.items[w.gg.currentWeapon.ammo].kol==31,"join retains its own bag through repeated map travel");
               check(layoutMatches==5 && layoutWrong==0,"five independent explorations reconstruct the host's actual native room layout",{samples:layoutMatches,wrong:layoutWrong});
               SceneChecks.picture(access,"party-travel.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var tick:uint=session.runtime.tick;
         if(original.length==0) {
            owner=w.gg;original=[session.actors[0].unit,session.actors[1].unit];
         }
         if(w.land.act.id=="random_mane" && w.t_exit==0 && w.land!==observedLand && session.actors[0].unit.loc===w.loc) {
            observedLand=w.land;seeds.push(w.land.rconnectLayoutSeed);layouts.push(layout(w.land));
            session.link.send({type:"travel-layout",seed:w.land.rconnectLayoutSeed,layout:layouts[layouts.length-1]});
         }
         if(tick<deadline || w.t_exit>0)return;
         if(phase<8) {
            for each(var actor:PlayerActor in session.actors)actor.unit.pers.healAll();
            if(phase%2==0)w.game.gotoLand("rbl",null,true);else w.game.beginMission("random_mane");
            ++phase;deadline=tick+130;return;
         }
         check(original[0]===session.actors[0].unit && original[1]===session.actors[1].unit && w.gg===owner,"native party travel retains both real player objects and host controls");
         check(session.actors[0].unit.loc===session.actors[1].unit.loc && session.actors[1].unit.ggControl,"remote player rejoins the new native room with controls enabled");
         check(session.actors[0].unit.invent.items[session.actors[0].unit.currentWeapon.ammo].kol==17 &&
            session.actors[1].unit.invent.items[session.actors[1].unit.currentWeapon.ammo].kol==31,"party travel does not merge ammunition reserves");
         check(seeds[0]!=w.land.rconnectLayoutSeed && w.land.rconnectLayoutSeed!=0,"a new exploration gets a fresh native layout seed",{first:seeds[0],last:w.land.rconnectLayoutSeed});
         var uniqueSeeds:Object={},uniqueLayouts:Object={},seedCount:int=0,layoutCount:int=0;
         for(var i:int=0;i<seeds.length;i++){uniqueSeeds[seeds[i]]=true;uniqueLayouts[layouts[i]]=true;}
         for(var key:String in uniqueSeeds)++seedCount;for(key in uniqueLayouts)++layoutCount;
         check(seeds.length==5 && seedCount==5 && layoutCount==5,
            "five new explorations change both seeds and the actual arrangement of native rooms",{seeds:seeds,distinctLayouts:layoutCount});
         check(w.loc===owner.loc && access.scope.depth==0,"new map retains the host's camera and native context");finish();
      }
   }
}
