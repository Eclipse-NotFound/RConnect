package authority {
   import flash.events.KeyboardEvent;
   import flash.utils.getTimer;
   /** Explicitly enabled, isolated-app B1 integration scenario. */
   public class Probe {
      public var host:Boolean,access:NativeAccess,finished:Boolean=false,passed:int=0,failed:int=0;
      private var prepared:Boolean=false,start:int=-1,damageChecked:Boolean=false,initial:Object;
      private var target:Object,targetHP:Number=0;
      private var peerReady:Boolean=false;
      public function Probe(access:NativeAccess,host:Boolean){this.access=access;this.host=host;}
      public function check(ok:Boolean,name:String,details:Object=null):void {
         if(ok)++passed;else ++failed;
         Log.write(ok?"PASS":"FAIL",{name:name,details:details});
      }
      public function message(value:Object):void {
         if(host && !peerReady && value.type=="input" && value.player==1 && value.probeReady===true) {
            peerReady=true;start=getTimer();
         }
      }
      public function prepare():void {
         if(prepared)return;prepared=true;
         ContractChecks.run(check);
         var g:Object=access.world.gg,Weapon:Class=access.definition("fe.weapon.Weapon");
         // Native save/reload must reconstruct a character qualified to use LMG;
         // modifying only one live weapon's requirements would not survive it.
         g.pers.setForcLevel(30);g.pers.skills.smallguns=100;g.pers.setParameters();
         if(g.currentWeapon!=null)g.currentWeapon.remVisual();
         var gun:Object=Weapon["create"](g,"lmg",0);gun.setPers(g,g.pers);
         gun.hold=host?7:11;gun.hp=gun.maxhp;gun.precision=0;
         g.invent.weapons["lmg"]=gun;g.invent.cWeaponId="lmg";
         g.currentWeapon=gun;g.childObjs=[gun,g.punchWeapon];gun.addVisual();
         g.invent.items[gun.ammo].kol=host?17:31;
         g.pers.jammedMult=0;g.hp=host?90:70;
         for each(var unit:Object in access.world.loc.units)if(unit!==g && unit!=null)unit.disabled=true;
         access.world.ctr.clearAll();
         Log.write("probe-prepared",{host:host,hold:gun.hold,ammo:gun.ammo,reserve:g.invent.items[gun.ammo].kol});
      }
      public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         var elapsed:int=start<0?0:getTimer()-start;
         if(!host) {
            if(start<0)return frame;
            frame.probeReady=true;
            if(elapsed>800 && elapsed<2000)frame.buttons=Commands.FIRE;
            // Aim horizontally; the host probes a real native target separately.
            frame.aimX=access.world.gg.X+350;frame.aimY=access.world.gg.Y-access.world.gg.scY*.65;
         }
         return frame;
      }
      public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(host) {
            if(session==null || !session.active)return;
            var a:Object=session.actors[0].unit,b:Object=session.actors[1].unit;
            if(initial==null) {
               if(a.currentWeapon==null || b.currentWeapon==null)throw new Error("Probe requires both native magazines after player assembly");
               start=getTimer();initial={hostHP:a.hp,hostHold:a.currentWeapon.hold,remoteHold:b.currentWeapon.hold,
                  hostReserve:a.invent.items[a.currentWeapon.ammo].kol,remoteReserve:b.invent.items[b.currentWeapon.ammo].kol};
               check(a!==b && a.pers!==b.pers && a.invent!==b.invent,"native players have distinct character state");
               check(b.pers.gg===b && b.invent.gg===b && b.invent.owner===b,"remote native ownership");
               check(initial.hostHold==7 && initial.remoteHold==11 && initial.hostReserve==17 && initial.remoteReserve==31,"profile preserves distinct named inventory maps",initial);
               prepareTarget(b);
               b.ctr.clearAll();access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,65));
               check(!b.ctr.keyLeft,"remote controller has no local keyboard listener");
               access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,65));
            }
            if(!peerReady)return;
            if(getTimer()-start>3000 && !damageChecked) {
               damageChecked=true;
               var before:Number=b.hp,other:Number=a.hp;
               b.damage(5,0,null,true);
               check(b.hp<before && a.hp==other,"remote native damage stays on remote character",{before:before,after:b.hp,hostBefore:other,hostAfter:a.hp});
            }
            if(getTimer()-start>6000) {
               check(session.runtime.spawns>0,"native gun generated real projectile objects",{spawns:session.runtime.spawns});
               check(session.runtime.remoteObjectSteps>0,"native projectile steps use the owning player's context",{steps:session.runtime.remoteObjectSteps});
               check(target!=null && target.hp<targetHP,"join input causes real native projectile impact damage",{before:targetHP,after:target==null?null:target.hp});
               var remaining:int=b.currentWeapon.hold+b.invent.items[b.currentWeapon.ammo].kol;
               var spent:int=initial.remoteHold+initial.remoteReserve-remaining;
               check(spent>0 && spent==session.runtime.spawnsByPlayer[1],"join native shots consume exactly one round each including automatic reload",
                  {before:initial.remoteHold+initial.remoteReserve,after:remaining,shots:session.runtime.spawnsByPlayer[1]});
               check(a.currentWeapon.hold==initial.hostHold,"join firing does not consume host magazine");
               check(a.invent.items[a.currentWeapon.ammo].kol==initial.hostReserve,"host reserve ammunition remains separate");
               check(session.actors[0].steps==session.runtime.roomSteps && session.actors[1].steps==session.runtime.roomSteps,"one native player step per room step",
                  {host:session.actors[0].steps,join:session.actors[1].steps,room:session.runtime.roomSteps});
               check(access.world.gg===a && access.world.pers===a.pers && access.world.invent===a.invent && access.world.gui.gg===a && access.scope.depth==0,"host world and UI restored after native invocation");
               session.link.send({type:"probe-result",passed:passed,failed:failed});finish();
            }
         } else if(replica!=null && replica.lastFrame!=null) {
            if(start<0)start=getTimer();
            if(getTimer()-start<=5500)return;
            check(replica.frames>20,"client receives host confirmation stream",{frames:replica.frames});
            check(access.world.onPause,"client native world is not simulating a second battle");
            check(replica.lastFrame.players[1].ack>0,"host acknowledges consumed join input");
            check(replica.lastFrame.spawns>0,"client receives authoritative projectile identities");
            check(replica.shortProjectileApplications>0,"client renders terminal native bullet symbols that disappear within a host step",{applied:replica.shortProjectileApplications});
            finish();
         }
      }
      private function prepareTarget(remote:Object):void {
         var room:Object=remote.loc,y:Number=Math.floor((room.limY-120)/40)*40-1,x:Number=770,row:int=int((y+1)/40);
         // Controlled shooting lane in this test copy only. Native collision and
         // damage remain enabled; only unrelated terrain and AI are excluded.
         for(var tx:int=1;tx<room.spaceX-1;tx++)
            for(var ty:int=1;ty<=row;ty++) {
               var tile:Object=room.space[tx][ty];tile.phis=ty==row?1:0;
               tile.phX1=tx*40;tile.phX2=(tx+1)*40;tile.phY1=ty*40;tile.phY2=(ty+1)*40;
               tile.water=0;tile.shelf=false;tile.diagon=tile.stair=0;tile.trap=tile.door=null;tile.visi=tile.t_visi=1;
               if(tile.phis==0){tile.front=tile.back=tile.zad="";tile.vid=tile.vid2=tile.zForm=0;}
            }
         room.black=false;access.world.gg.setLocPos(400,y);remote.setLocPos(600,y);
         var Type:Class=access.definition("fe.unit.UnitZombie");
         target=new Type("1",100,<unit tr="1" dig="0"/>,null);
         target.putLoc(room,x,y);room.units.push(target);
         target.addVisual();target.setVisPos();target.hp=target.maxhp=10000;
         target.skin=target.armor=target.dexter=target.dodge=0;
         target.invulner=target.disabled=target.trigDis=false;target.doop=true;target.lootIsDrop=true;target.xp=0;
         target.scX=50;target.scY=100;target.setPos(x,y);target.animate();targetHP=target.hp;
         Log.write("probe-target",{x:x,y:y,hp:targetHP,remoteX:remote.X,remoteY:remote.Y,level:remote.currentWeapon.lvl,
            persLevel:remote.pers.level,required:remote.currentWeapon.perslvl});
      }
      public function finish():void {finished=true;Log.write("DONE",{passed:passed,failed:failed,scope:"Isolated authority technical probe; not release validation"});}
   }
}
