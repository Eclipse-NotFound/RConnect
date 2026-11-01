package authority {
   /** Native dual-room execution plus confirmation-only scene assertions. */
   public class SplitRoomProbe extends Probe {
      private var tick:uint=0,ready:Boolean=false,home:Object,back:Object,targets:Array=[],foes:Array=[];
      private var phase:int=0,base:Array=[],empty:Object,dead:Object,wall:Object,hostRoom:Object,hostVisual:Object,hostCamera:Object;
      private var previousSteps:Array=[0,0],previousTick:uint=0,stepChecks:Boolean=true,restored:Boolean=true;
      private var minimum:Array=[10000,10000],acquired:Array=[false,false],shotBase:Array=[0,0];
      private var confirmedAimY:Number=700;
      private var enemyKind:String,initialArt:int;
      private var sceneChecks:SceneChecks=new SceneChecks();
      private var begin:int=-1;
      override public function message(value:Object):void {
         if(!host && value.type=="split-route")sceneChecks.expectedRooms=value.rooms;
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      private function get extra():int {return enemyKind=="tdfc"?325:0;}
      public function SplitRoomProbe(a:NativeAccess,h:Boolean,enemyKind:String="native"){super(a,h);this.enemyKind=enemyKind;}
      override public function input(frame:Object,session:HostSession):Object {
         if(host && session!=null && session.active && begin>=0)tick=session.runtime.tick-begin;
         if(!host && begin>=0)frame.probeStart=begin;
         frame.buttons=begin>=0 && tick>=30 && tick<48?Commands.FIRE:0;frame.actions=[];
         frame.aimX=750;frame.aimY=host && session!=null && session.active?session.actors[0].unit.Y-55:confirmedAimY;
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            if(begin<0)begin=replica.lastTick;
            tick=replica.lastTick-begin;
            sceneChecks.observe(replica);
            confirmedAimY=replica.lastFrame.players[1].y-55;
            if(tick>=320+extra) {
               var f:Object=replica.lastFrame;
               check(f.rooms.length>=2,"join receives retained identities for both host-native rooms");
               var visited:Object={};
               for each(var column:Array in access.world.land.locs)for each(var row:Array in column)for each(var place:Object in row)
                  if(place!=null && place.visited)visited[access.keyFor(place)]=true;
               var visitsCorrect:Boolean=true;
               for each(var retained:Object in f.rooms)if(String(retained.room).split(":")[5]=="" && !visited[retained.room])visitsCorrect=false;
               check(visitsCorrect,"native map retains explored ordinary foreground and background rooms after both players leave");
               check(f.players[0].roomEpoch>=3 && f.players[1].roomEpoch>=4,"join confirms independent room visits");
               check(f.players[0].steps==f.tick && f.players[1].steps==f.tick,"join confirms each native actor advances once per world tick");
               check(f.spawnsByPlayer[0]>0 && f.spawnsByPlayer[1]>0,"both separated players fired native projectiles");
               check(access.world.onPause,"join remains a confirmation consumer during host dual-room combat");
               sceneChecks.finish(check,enemyKind);
               finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         tick=session.runtime.tick;
         var runtime:RoomRuntime=session.runtime,a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1];
         if(!ready) {
            ready=true;setup(session);previousSteps=[a.steps,b.steps];previousTick=tick;
            // Keep this public native map timer away from its random reset;
            // the native Land.artStep still performs every decrement itself.
            access.world.land.art_t=10000;initialArt=10000+int(tick);
            return;
         }
         if(begin<0)return;tick=runtime.tick-begin;
         if(runtime.tick>previousTick) {
            stepChecks=stepChecks && a.steps-previousSteps[0]==runtime.tick-previousTick && b.steps-previousSteps[1]==runtime.tick-previousTick;
            previousSteps=[a.steps,b.steps];previousTick=runtime.tick;
         }
         restored=restored && access.world.gg===a.unit && access.world.loc===a.unit.loc && a.unit.loc.gg===a.unit && access.world.land.loc===a.unit.loc && access.world.land.gg===a.unit && access.world.grafon===a.unit.loc.grafon && access.world.visual===a.unit.loc.grafon.visual && access.world.cam===runtime.rooms.services(a.unit.loc).cam && access.world.ctr===a.context.ctr && access.world.sats.gg===a.unit && access.world.gui.gg===a.unit && access.scope.depth==0;
         if(phase==0 && tick>=70) {
            phase=1;
            check(a.unit.loc===home && b.unit.loc===back && home!==back,"host runs two real native rooms concurrently");
            check(access.world.loc===hostRoom && access.world.visual===hostVisual && access.world.cam===hostCamera,"join entering a background room leaves host room and camera unchanged");
            check(targets[0].hp<10000 && targets[1].hp<10000,"native bullets hit enemies in both independently occupied rooms",{hp:[targets[0].hp,targets[1].hp]});
            check(home.grafon!==back.grafon && targets[0].vis.parent!==targets[1].vis.parent,"room bodies and graphics are not shared");
            for each(var target:Object in targets){target.disabled=true;target.remVisual();}
            for(var i:int=0;i<2;i++) {
               var actor:PlayerActor=session.actors[i];
               actor.unit.hp=actor.unit.maxhp=10000;actor.unit.obs=actor.unit.maxObs;
               access.scope.run(actor.context,function():void {foes.push(spawnFoe(actor.unit.loc,actor.unit.X+90,actor.unit.Y));});
            }
            shotBase=[runtime.spawnsFor(foes[0]),runtime.spawnsFor(foes[1])];
         }
         if(phase==1)for(i=0;i<2;i++) {
            minimum[i]=Math.min(minimum[i],session.actors[i].unit.hp);
            acquired[i]=acquired[i] || foes[i].celUnit===session.actors[i].unit;
         }
         if(phase==1 && tick>=190+extra) {
            phase=2;
            check(acquired[0] && acquired[1],"enemies independently acquire the occupant of each room",{acquired:acquired});
            check(runtime.spawnsFor(foes[0])>shotBase[0] && runtime.spawnsFor(foes[1])>shotBase[1],"both rooms generate actual hostile projectiles");
            check(minimum[0]<10000 && minimum[1]<10000,"both real players receive native enemy damage in separate rooms",{minimum:minimum});
            if(enemyKind=="tdfc") {
               var left:Object=session.tactics.inspect(home),right:Object=session.tactics.inspect(back),faults:int=0;
               for each(var brain:Object in left.brains.concat(right.brains))faults+=brain.faults;
               check(left.units>0 && right.units>0 && faults==0,"TDFC controls real native combatants in both rooms without swallowed errors");
               Log.write("split-tactics-evidence",{home:left,back:right});
            }
            for each(var foe:Object in foes)foe.disabled=true;
            // Death is native; no synthetic HP snapshot is used for re-entry.
            dead=targets[1];dead.disabled=false;
            access.scope.run(b.context,function():void {dead.damage(100000,0,null,true);});
            wall=back.space[25][4];wall.phis=1;wall.hp=10;wall.indestruct=false;
            access.scope.run(b.context,function():void {back.hitTile(wall,10000,1020,180,4);});
            check(wall.phis==0 && wall.hp<=0,"native terrain damage destroys the prepared background wall tile");
            nativeExit(b,5,400,base[0]);
         }
         if(phase==2 && tick>=195+extra) {
            phase=3;
            check(b.unit.loc===home,"native hidden-room exit returns only the requesting player");
            empty={steps:runtime.rooms.services(back).steps,tactics:session.tactics==null?0:session.tactics.inspect(back).tick,
               deadHP:dead.hp,deadState:dead.sost,first:back.firstObj,shots:runtime.spawnsFor(foes[1])};
         }
         if(phase==3 && tick>=240+extra) {
            phase=4;
            check(runtime.rooms.services(back).steps==empty.steps && runtime.spawnsFor(foes[1])==empty.shots,"empty native room does not simulate objects or bullets");
            if(session.tactics!=null)check(session.tactics.inspect(back).tick==empty.tactics,"empty room tactical clock stays paused");
            nativeExit(b,5,400,base[1]);
         }
         if(phase==4 && tick>=246+extra) {
            phase=5;
            check(b.unit.loc===back && back.firstObj===empty.first && dead.hp==empty.deadHP && dead.sost==empty.deadState && dead.sost>=3,
               "re-entering retains native room objects and a killed enemy",{hp:dead.hp,state:dead.sost});
            check(back.space[25][4]===wall && wall.phis==0 && wall.hp<=0,"re-entry retains the changed native tile object");
            check(access.world.loc===home && access.world.visual===hostVisual && access.world.cam===hostCamera,"second hidden-room visit still leaves the host camera alone");
            nativeExit(a,5,600,base[1]);
         }
         if(phase==5 && tick>=252+extra) {
            phase=6;
            check(a.unit.loc===back && b.unit.loc===back && access.world.loc===back && access.world.visual===back.grafon.visual,"host changes only its own displayed room when following later");
            empty={steps:runtime.rooms.services(home).steps,tactics:session.tactics==null?0:session.tactics.inspect(home).tick,
               backSteps:runtime.rooms.services(back).steps,tick:tick};
         }
         if(phase==6 && tick>=295+extra) {
            phase=7;
            check(runtime.rooms.services(home).steps==empty.steps,"previous foreground room pauses after its last player leaves");
            check(runtime.rooms.services(back).steps-empty.backSteps==tick-empty.tick,"reunited players advance their shared room once, without double speed");
            nativeExit(a,5,400,base[0]);
         }
         if(phase==7 && tick>=310+extra) {
            phase=8;RoomWeaponChecks.run(session,check);
         }
         if(tick>=330+extra) {
            check(initialArt-access.world.land.art_t==runtime.tick,"native map-wide artillery clock advances once regardless of occupied room count",
               {initial:initialArt,current:access.world.land.art_t,tick:runtime.tick});
            check(stepChecks && a.steps==runtime.tick && b.steps==runtime.tick,"split, reunion and exits never double-step or omit a native player");
            check(restored && access.world.loc===home,"all world and camera ownership references return to the host after every world step");
            if(session.tactics!=null) {
               var rs:Array=runtime.rooms.summary(),sum:int=0;
               for each(var r:Object in rs)sum+=r.steps;
               check(session.tactics.inspect(home).steps==sum,"TDFC runs once for each actual occupied-room step");
               check(session.tactics.inspect(home).tick==runtime.rooms.services(home).steps && session.tactics.inspect(back).tick==runtime.rooms.services(back).steps,
                  "each TDFC room clock matches its retained native room");
            }
            var sa:Object=a.snapshot(0),sb:Object=b.snapshot(0);delete sa.visual;delete sb.visual;
            if(sa.weapon!=null)delete sa.weapon.visual;if(sb.weapon!=null)delete sb.weapon.visual;
            Log.write("split-room-evidence",{tick:tick,rooms:runtime.rooms.summary(),players:[sa,sb],minimum:minimum,acquired:acquired});
            finish();
         }
      }
      private function nativeExit(actor:PlayerActor,direction:int,x:Number,y:Number):void {
         actor.context.t_battle=0;actor.context.transitionCooldown=0;
         if(actor.id==0)access.world.t_battle=0;
         actor.unit.loc.t_alarm=0;
         access.scope.run(actor.context,function():void {
            check(actor.unit.outLoc(direction,x,y),"native player exit accepts background-door coordinates player "+actor.id);
         });
      }
      private function setup(session:HostSession):void {
         var land:Object=access.world.land;
         for each(var column:Array in land.locs)for each(var row:Array in column)if(row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky) {
            home=row[0];back=row[1];break;
         }
         if(home==null)throw new Error("Generated map has no native foreground/background pair");
         session.link.send({type:"split-route",rooms:[access.keyFor(back),access.keyFor(home),access.keyFor(back)]});
         base=[lane(home),lane(back)];
         var runtime:RoomRuntime=session.runtime;
         runtime.transfers.relocate(session.actors[0],home,400,base[0]);
         runtime.transfers.relocate(session.actors[1],home,600,base[0]);
         runtime.rooms.showHost();hostRoom=access.world.loc;hostVisual=access.world.visual;hostCamera=access.world.cam;
         nativeExit(session.actors[1],5,400,base[1]);
         runtime.transfers.commit();runtime.rooms.occupied();runtime.rooms.showHost();
         for(var i:int=0;i<2;i++) {
            var actor:PlayerActor=session.actors[i];
            access.scope.run(actor.context,function():void {targets.push(spawnTarget(actor.unit.loc,750,actor.unit.Y));});
         }
         check(home.units.indexOf(session.actors[1].unit)<0 && back.units.indexOf(session.actors[0].unit)<0,"native rosters contain only players physically present");
      }
      private function lane(room:Object):Number {
         var y:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((y+1)/40);
         for each(var u:Object in room.units)if(u!=null && !u.player){u.disabled=true;u.remVisual();}
         for(var x:int=0;x<room.space.length;x++)for(var z:int=0;z<=row;z++) {
            var tile:Object=room.space[x][z];tile.phis=z==row || x==0 || x==room.space.length-1?1:0;
            tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=z*40;tile.phY2=(z+1)*40;
            tile.water=0;tile.visi=tile.t_visi=1;tile.shelf=false;tile.diagon=tile.stair=0;tile.door=tile.trap=null;
            // The fixture changes collision and artwork together; retaining an
            // old wall's front texture would cover actors in the cleared lane.
            if(tile.phis==0){tile.front=tile.back=tile.zad="";tile.vid=tile.vid2=tile.zForm=0;}
         }
         room.black=room.mirror=false;return y;
      }
      private function spawnTarget(room:Object,x:Number,y:Number):Object {
         var Type:Class=access.definition("fe.unit.UnitZombie"),u:Object=new Type("1",100,<unit tr="1" dig="0"/>,null);
         u.putLoc(room,x,y);room.units.push(u);u.addVisual();u.hp=u.maxhp=10000;
         u.skin=u.armor=u.dexter=u.dodge=0;u.invulner=u.disabled=u.trigDis=false;u.doop=true;u.lootIsDrop=true;u.xp=0;
         u.scX=60;u.scY=100;u.setPos(x,y);u.setVisPos();u.animate();return u;
      }
      private function spawnFoe(room:Object,x:Number,y:Number):Object {
         var Type:Class=access.definition(enemyKind=="tdfc"?"fe.unit.UnitRaider":"fe.unit.UnitTurret");
         var u:Object=enemyKind=="tdfc"?new Type("1",10,<unit tr="1" weap="r32" turn="-1"/>,null):new Type("land",100,<unit tr="2" vis="left"/>,null);
         u.putLoc(room,x,y);room.units.push(u);room.addObj(u);u.addVisual();u.disabled=false;u.invulner=false;
         u.oduplenie=0;u.overLook=true;u.vision=5;u.hp=u.maxhp=10000;u.storona=-1;
         if(u.currentWeapon!=null){u.currentWeapon.damage=75;u.currentWeapon.damageExpl=0;}
         return u;
      }
   }
}
