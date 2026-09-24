package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.RConnectUnitAccess;
   import fe.inter.RoomTravelUiProbe;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.game.NativeRoomState;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;
   public class RoomCooperationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),mod:RConnectMod,host:Boolean;
      private var links:Dictionary=new Dictionary(),phase:String="boot",at:int=0;
      private var a:Object,b:Object,expected:Object,fixture:Object,readySent:Boolean=false;
      private var stale:Object,stageSeq:int=0,oldLand:Object,challenge:String="";
      public function RoomCooperationTestDoc(){
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void{
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"room "+label);}
      private function setPhase(p:String):void {phase=p;at=getTimer();Log.d("ROOM TEST "+(host?"host ":"join ")+p);}
      private function send(p:String,data:Object=null):void {var m:Object=data||{};m.type="room-test";m.phase=p;if(host)mod.session.server.broadcast(m);else mod.session.link.send(m);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function info(loc:Object):Object{return {landX:loc.landX,landY:loc.landY,landZ:loc.landZ,landProb:loc.landProb,key:mod.game.roomKey(loc)};}
      private function go(i:Object):void {TravelGuard.follow(mod.game,i);}
      private function stable():Boolean{return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();}
      private function findFixture():Object {for each(var u:Object in mod.game.loc.units)if(u.code=="rooms-fixture")return u;return null;}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p==null || p.type!="room-test")return;
         try {
            if(!host) {
               if(p.phase=="split"){a=p.a;b=p.b;go(b);setPhase("split");}
               else if(p.phase=="mirror"){expected=p.expected;setPhase("mirror");}
               else if(p.phase=="promote"){setPhase("promote");}
               else if(p.phase=="vacate"){go(a);setPhase("vacate");}
               else if(p.phase=="revisit"){go(b);setPhase("revisit");}
               else if(p.phase=="new-floor"){stageSeq=int(p.epoch);oldLand=mod.game.world.land;setPhase("new-floor");}
               else if(p.phase=="challenge"){challenge=p.prob;a=p.a;setPhase("challenge");}
               else if(p.phase=="challenge-out")setPhase("challenge-out");
               else if(p.phase=="done")finish();
            } else {
               if(p.phase=="prepared"){expected=p.expected;check(mod.game.roomKey()==a.key,"host stays in its own room while join explores");setPhase("split-hold");}
               else if(p.phase=="mirrored"){expected.burstHp=p.burstHp;go(a);send("promote");setPhase("promote-wait");}
               else if(p.phase=="killed"){expected=p.expected;send("vacate");setPhase("vacate-wait");}
               else if(p.phase=="vacated"){go(b);setPhase("empty-revisit");}
               else if(p.phase=="revisited"){
                  stageSeq=mod.session.rooms.epoch+1;oldLand=mod.game.world.land;
                  send("new-floor",{epoch:stageSeq});mod.game.world.game.gotoNextLevel();setPhase("new-floor");
               }
               else if(p.phase=="floor-ready"){
                  check(mod.session.rooms.epoch==stageSeq && mod.game.world.land!==oldLand,"host next floor creates a new map generation");
                  a=info(mod.game.loc);
                  for each(var room:Object in mod.game.world.land.listLocs)if(room.prob!=null){challenge=room.landProb;break;}
                  check(challenge!="","native challenge room exists for grouped travel");
                  if(challenge==""){send("done");finish();return;}
                  send("challenge",{prob:challenge,a:a});go({landProb:challenge});setPhase("challenge");
               }
               else if(p.phase=="challenge-ready"){
                  check(mod.game.loc.landProb==challenge,"host leads challenge entry");
                  go(a);send("challenge-out");setPhase("challenge-out");
               }
               else if(p.phase=="challenge-out-ready"){send("done");finish();}
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null || mod.game.loc==null)return;
         if(host){for each(var link:TcpLink in mod.session.server.clients)watch(link);}else watch(mod.session.link);
         if(timer.currentCount<60 || mod.game.readWorldInfo().curLandId!="random_mane")return;
         try {
            mod.game.gg.invulner=true;mod.game.gg.disabled=true;mod.game.gg.dx=mod.game.gg.dy=0;
            if(!stable())return;
            if(host && phase=="boot" && mod.session.peers.length) {
               var list:Array=ordinaryRooms();
               Log.d("ROOM TEST candidates "+(list==null?"null":list.length));
               a=info(mod.game.loc);
               if(TravelGuard.restricted(mod.game.loc)) {
                  for each(var room:Object in list)if(!TravelGuard.restricted(room)){a=info(room);go(a);setPhase("find-rooms");return;}
               }
               setPhase("find-rooms");
            }
            if(host && phase=="find-rooms") {
               a=info(mod.game.loc);
               for each(room in ordinaryRooms())if(mod.game.roomKey(room)!=a.key && !TravelGuard.restricted(room)){b=info(room);break;}
               check(b!=null,"two real ordinary rooms found");
               if(b==null){send("done");finish();return;}
               Log.d("ROOM TEST pair "+JSON.stringify({a:a,b:b}));
               // Join starts with the host; this synchronizes a test origin only.
               send("split",{a:a,b:b});setPhase("wait-prepared");
            }
            if(!host && phase=="split" && mod.game.roomKey()==b.key && getTimer()-at>1000) {
               check(mod.session.rooms.authority,"join obtains native authority in an independent room");
               check(RoomTravelUiProbe.blocked(mod.game.world.pip,false),"map travel button is intercepted before the native handler");
               check(RoomTravelUiProbe.blocked(mod.game.world.pip,true),"return scroll button is intercepted before consuming an item");
               setup();send("prepared",{expected:expected});setPhase("wait-merge");
            }
            if(host && phase=="split-hold" && getTimer()-at>2500) {
               check(mod.game.roomKey()==a.key,"different rooms remain separate across many network ticks");
               go(b);setPhase("merge");
            }
            if(host && phase=="merge" && mod.game.roomKey()==b.key && getTimer()-at>700) {
               inspect(false);send("mirror",{expected:expected});setPhase("mirror-wait");
            }
            if(!host && phase=="mirror" && !mod.session.rooms.authority && getTimer()-at>1000) {
               inspect(false);check(!mod.session.rooms.authority,"join becomes mirror when host enters");
               stale=mod.session.rooms.stamp({type:"damage",hits:[{id:fixture.id,k:mod.game.readUnitsSnapshot()[0].k,dmg:777}]});
               var burst:Object=mod.game.loc.space[expected.burstX][expected.ty];
               mod.game.loc.hitTile(burst,10,expected.burstX*40+20,expected.ty*40+20);
               mod.session.flushRoomReports();
               mod.game.loc.hitTile(burst,13,expected.burstX*40+20,expected.ty*40+20);
               expected.burstHp=77;
               check(burst.hp==77,"two native wall hits queued immediately before room handoff");
               send("mirrored",{burstHp:expected.burstHp});setPhase("wait-promote");
            }
            if(!host && phase=="promote" && mod.session.rooms.authority && getTimer()-at>1000) {
               inspect(false);check(mod.game.freezeAI==false,"promoted room uses native combat");
               fixture.disabled=false;fixture.currentWeapon.t_reload=60;
               setPhase("native-combat");
            }
            if(!host && phase=="native-combat" && getTimer()-at>800) {
               check(fixture.currentWeapon.t_reload<60,"native enemy weapon timers advance after promotion");
               var before:Number=fixture.hp;
               fixture.damage(51,100,null,false);
               check(fixture.hp<before,"join native damage changes authoritative enemy health");
               fixture.hp=0;fixture.die();
               check(int(fixture.sost)>=3,"join native enemy death runs once");
               expected.dead=true;
               var loots:Array=mod.game.readLootSync()||[];expected.loots=loots.length;
               send("killed",{expected:expected});setPhase("wait-vacate");
            }
            if(!host && phase=="vacate" && mod.game.roomKey()==a.key && getTimer()-at>1000) {
               if(stale!=null)mod.session.link.send(stale);
               check(!mod.session.rooms.authority,"join can reunite in host room after owning another");
               mod.game.travelToLand("stable_pi");setPhase("blocked-travel");
            }
            if(!host && phase=="blocked-travel" && getTimer()-at>1000) {
               check(mod.game.readWorldInfo().curLandId=="random_mane" && int(mod.game.world.t_exit)==0,"join independent map exit is blocked before loading");
               send("vacated");setPhase("wait-revisit");
            }
            if(host && phase=="empty-revisit" && mod.game.roomKey()==b.key && getTimer()-at>700) {
               inspect(true);send("revisit");setPhase("revisit-wait");
            }
            if(!host && phase=="revisit" && mod.game.roomKey()==b.key && getTimer()-at>1000) {
               inspect(true);send("revisited");setPhase("wait-done");
            }
            if(!host && phase=="new-floor" && mod.session.rooms.epoch==stageSeq && mod.game.world.land!==oldLand) {
               check(mod.game.readWorldInfo().curLandId=="random_mane","host same-map next floor brings join to the new generation");
               check(mod.game.loc.landProb=="","new floor has a normal room identity");
               send("floor-ready");setPhase("wait-challenge");
            }
            if(!host && phase=="challenge" && mod.game.loc.landProb==challenge && getTimer()-at>700) {
               check(!mod.session.rooms.authority,"challenge remains host-owned after grouped entry");
               check(mod.game.loc.prob.onWave==false && mod.game.loc.prob.inScript==null,"join challenge cannot start independent waves or entry scripts");
               var exits:int=0;
               for each(var obj:Object in mod.game.loc.objs)if(obj.inter!=null && obj.inter.prob!=null) {
                  check(obj.inter.action==0 && !obj.inter.active,"join challenge exits are blocked at the native interaction");exits++;
               }
               check(exits>0,"native challenge exit guarded");
               send("challenge-ready");setPhase("wait-challenge-out");
            }
            if(!host && phase=="challenge-out" && mod.game.loc.landProb=="" && getTimer()-at>700) {
               check(mod.game.roomKey()==a.key,"leaving challenge brings both players back together");
               send("challenge-out-ready");setPhase("wait-done");
            }
            if(phase!="done" && at>0 && getTimer()-at>50000){check(false,"timeout "+phase);send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function ordinaryRooms():Array {
         var out:Array=[];
         for each(var column:Array in mod.game.world.land.locs)if(column!=null)
            for each(var row:Array in column)if(row!=null)
               for each(var room:Object in row)if(room!=null)out.push(room);
         return out;
      }
      private function setup():void {
         var g:GameBridge=mod.game;
         for each(var old:Object in (g.loc.units as Array).concat())if(old!==g.gg && int(old.fraction)<100){g.loc.remObj(old);var ix:int=g.loc.units.indexOf(old);if(ix>=0)g.loc.units.splice(ix,1);}
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret") as Class;
         fixture=new cls("hidden",12,<unit tr="3"/>,null);fixture.putLoc(g.loc,g.gg.X+100,g.gg.Y);g.loc.addObj(fixture);g.loc.units.push(fixture);
         fixture.code="rooms-fixture";fixture.alarma();fixture.disabled=true;fixture.maxhp=901;fixture.hp=613;fixture.armor=37;fixture.xp=23;
         fixture.currentWeapon.damage=17.25;fixture.currentWeapon.hold=47;
         var props:Object=NativeRoomState.unit(fixture);
         check(props.p.hp==613 && props.p.maxhp==901,"checkpoint captures real native scalar stats");
         check(props.internal.ai==3 && props.internal.groups.UnitTurret.hidden==1,"checkpoint captures native AI and hidden turret kind");
         var tx:int=Math.min(g.loc.spaceX-3,int(g.gg.X/40)+2),ty:int=Math.max(2,int(g.gg.Y/40)-1),tile:Object=g.loc.space[tx][ty];
         tile.mainFrame("A");tile.indestruct=false;tile.hp=60;tile.thre=0;tile.door=null;tile.trap=null;
         g.loc.destroyOn=true;g.loc.tileSpawn=0;
         var bc:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var bullet:Object=new bc(g.gg,tx*40+20,ty*40+20,null,false);bullet.damage=0;bullet.destroy=1000;bullet.dx=1;bullet.dy=0;bullet.precision=0;bullet.partEmit=false;bullet.run();
         check(tile.phis==0,"native solo join bullet destroys wall");
         var burst:Object=g.loc.space[tx+1][ty];burst.mainFrame("A");burst.indestruct=false;burst.hp=100;burst.thre=0;burst.door=null;burst.trap=null;
         var box:Object=null;
         for each(var ob:Object in g.loc.objs)if(GameBridge.probe(ob,"hp")!=null && GameBridge.probe(ob,"dead")===false){box=ob;break;}
         if(box!=null){box.hp=19;if(box.inter!=null)box.inter.saveLoot=2;}
         expected={hp:613,maxhp:901,armor:37,xp:23,damage:17.25,ammo:47,tx:tx,ty:ty,burstX:tx+1,burstHp:100,box:box==null?null:{id:box.id,x:box.X,y:box.Y},dead:false};
         var ic:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.serv.Item") as Class,lc:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Loot") as Class;
         new lc(g.loc,new ic(null,"kofe",3),g.gg.X+160,g.gg.Y,false,false,false);
         expected.loots=(g.readLootSync()||[]).length;
      }
      private function inspect(dead:Boolean):void {
         var g:GameBridge=mod.game;fixture=findFixture();
         if(!dead){
            check(fixture!=null,"transferred enemy exists");if(fixture==null)return;
            check(fixture.hp==expected.hp && fixture.maxhp==expected.maxhp,"enemy does not heal or reroll difficulty on handoff");
            check(fixture.armor==expected.armor && fixture.xp==expected.xp,"armor and reward data survive handoff");
            check(fixture.currentWeapon.damage==expected.damage && fixture.currentWeapon.hold==expected.ammo,"actual weapon damage and magazine survive handoff");
            check(RConnectUnitAccess.capture(fixture as Unit).groups.UnitTurret.hidden==1,"hidden turret keeps native constructor state");
         } else check(fixture==null || int(fixture.sost)>=3,"dead enemy stays dead on empty-room revisit");
         check(g.loc.space[expected.tx][expected.ty].phis==0,"destroyed wall survives transfer and revisit");
         check(g.loc.space[expected.burstX][expected.ty].hp==expected.burstHp,"wall hit immediately before handoff is retained exactly once");
         if(expected.box!=null){var found:Object=null;for each(var ob:Object in g.loc.objs)if(ob.id==expected.box.id && Math.abs(ob.X-expected.box.x)<50){found=ob;break;}
            check(found!=null && found.hp==19,"scene object partial damage retained");
            if(found!=null && found.inter!=null)check(found.inter.saveLoot==2,"container stays looted");}
         var loots:Array=g.readLootSync()||[],keys:Object={},unique:Boolean=true;
         for each(var lo:Object in loots){if(keys[lo.k])unique=false;keys[lo.k]=true;}
         check(unique,"loot identity keys remain unique after handoff");
         if(dead)check(loots.length==expected.loots,"no duplicate drops on repeated room import");
      }
      private function finish():void {if(phase=="done")return;phase="done";timer.stop();Log.d("COOP EFFECTS DONE rooms "+(host?"host":"join"));}
   }
}
