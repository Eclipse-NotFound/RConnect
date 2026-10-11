package authority {
   import flash.utils.getTimer;
   /** B1 counterexample: two different profiles, then the profiles trade roles.
    * Inputs use confirmed simulation ticks, not a wall-clock firing schedule. */
   public class OwnershipProbe extends Probe {
      private var swap:Boolean,ready:Boolean=false,initial:Object,targets:Array=[],foes:Array=[],enemyKind:String;
      private var acquiredHost:Boolean=false,acquiredJoin:Boolean=false;
      private var aiHealth:Array=[],aiMinimum:Array=[],aiShots:Array=[];
      private var tick:uint=0,burst:Boolean=false,reloaded:Boolean=false,switched:Boolean=false,aiStarted:Boolean=false;
      private var movementChecked:Boolean=false;
      private var primary:String,secondary:String,hostDamage:Number,remoteDamage:Number,beginAt:int=0;
      // Raiders need a longer natural reaction/evasion window. The turret
      // case keeps its original incoming-fire window; death is a later phase.
      private function get endTick():uint {return enemyKind=="tdfc"?760:440;}
      public function OwnershipProbe(a:NativeAccess,h:Boolean,swap:Boolean,enemyKind:String="native") {
         super(a,h);this.swap=swap;this.enemyKind=enemyKind;
      }
      override public function prepare():void {
         super.prepare();
         var g:Object=access.world.gg,Weapon:Class=access.definition("fe.weapon.Weapon");
         primary=(host!=swap)?"r32":"lmg";secondary=primary=="lmg"?"r32":"lmg";
         g.currentWeapon.remVisual();
         for each(var id:String in [primary,secondary]) {
            var gun:Object=Weapon["create"](g,id,0);gun.setPers(g,g.pers);gun.hp=gun.maxhp;
            gun.hold=id==primary?(primary=="lmg"?11:3):2;
            g.invent.weapons[id]=gun;g.invent.items[gun.ammo].kol=id==primary?(primary=="lmg"?31:17):13;
         }
         g.currentWeapon=g.invent.weapons[primary];g.currentWeapon.addVisual();g.childObjs=[g.currentWeapon,g.punchWeapon];
         g.invent.cWeaponId=primary;g.work="";g.t_work=0;
         var armor:String=host!=swap?"power":"assault";
         g.invent.addArmor(armor);g.changeArmor(armor,true);
         g.hp=host?190:170;g.mana=host?30:45;
         Log.write("ownership-profile",{host:host,swap:swap,weapon:primary,ammo:g.currentWeapon.ammo,
            hold:g.currentWeapon.hold,reserve:g.invent.items[g.currentWeapon.ammo].kol,armor:g.currentArmor.id,skin:g.skin});
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && session!=null && session.active)tick=session.runtime.tick;
         frame.buttons=tick>=20 && tick<45?Commands.FIRE:0;
         if(tick>=110 && tick<122)frame.buttons|=host?Commands.LEFT:Commands.RIGHT;
         frame.actions=[];
         frame.aimX=host?210:890;frame.aimY=access.world.gg.Y-55;
         if(!host && (tick==80 || tick==81 || tick==82))frame.actions=[{id:1,type:"reload"}];
         if(!host && tick>=240 && tick<246)frame.actions=[{id:2,type:"equip",weapon:secondary}];
         return frame;
      }
      private function stock(g:Object,id:String=null):int {
         var gun:Object=id==null?g.currentWeapon:g.invent.weapons[id];
         return int(gun.hold)+int(g.invent.items[gun.ammo].kol);
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            tick=replica.lastTick;
            if(tick>=endTick-10) {
               check(replica.playerApplications[0]>100 && replica.playerApplications[1]>100,"both players are driven by confirmed native samples");
               check(replica.projectileApplications>0,"confirmed native projectiles reach display objects");
               check(replica.lastFrame.players[1].weapon.id==secondary && replica.lastFrame.players[1].weaponEpoch==2,
                  "confirmed weapon switch changes the client's current native display");
               check(access.world.onPause,"client never advances a second combat simulation");
               if(replica.tactics!=null)check(replica.tactics.inspect(access.world.loc).steps==0,"join-side TDFC never executes a tactical simulation");
               finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:Object=session.actors[0].unit,b:Object=session.actors[1].unit;
         tick=session.runtime.tick;
         if(!ready) {
            ready=true;beginAt=getTimer();
            fixture(session);
            initial={aWeapon:a.currentWeapon.id,bWeapon:b.currentWeapon.id,aAmmo:a.currentWeapon.ammo,bAmmo:b.currentWeapon.ammo,
               aHold:a.currentWeapon.hold,bHold:b.currentWeapon.hold,aStock:stock(a),bStock:stock(b),
               aReserve:a.invent.items[a.currentWeapon.ammo].kol,bReserve:b.invent.items[b.currentWeapon.ammo].kol,
               aArmor:a.currentArmor.id,bArmor:b.currentArmor.id,aSkin:a.skin,bSkin:b.skin,aDefense:a.armor,bDefense:b.armor,aMana:a.mana,bMana:b.mana,
               aOther:stock(a,b.currentWeapon.id),bOther:stock(b,a.currentWeapon.id)};
            check(a.pers!==b.pers && a.invent!==b.invent && a.ctr!==b.ctr && a.pers.gg===a && b.pers.gg===b,"native character references are independent");
            check(initial.aAmmo!=initial.bAmmo && initial.aStock!=initial.bStock && initial.aArmor!=initial.bArmor && initial.aDefense!=initial.bDefense,
               "counterexample uses genuinely different native ammo and defense",initial);
         }
         if(tick>=70 && !burst) {
            burst=true;
            check(targets[0].hp<10000 && targets[1].hp<10000,"both input streams cause native collision damage",{hostTarget:targets[0].hp,joinTarget:targets[1].hp});
            for(var i:int=0;i<2;i++) {
               var g:Object=i==0?a:b,before:int=i==0?initial.aStock:initial.bStock;
               check(before-stock(g)==session.runtime.spawnsByPlayer[i] && session.runtime.spawnsByPlayer[i]>0,
                  "one ammunition expense per native shot player "+i,{before:before,after:stock(g),shots:session.runtime.spawnsByPlayer[i]});
            }
            initial.aAfterShot=stock(a);initial.bAfterShot=stock(b);
            var oldA:Number=a.hp,oldB:Number=b.hp,manaA:Number=a.mana,manaB:Number=b.mana;
            b.damage(25,0,null,true);remoteDamage=oldB-b.hp;
            check(remoteDamage>0 && a.hp==oldA,"remote damage changes only the remote body");
            oldB=b.hp;
            access.scope.run(session.actors[1].context,function():void {a.damage(25,0,null,true);});
            hostDamage=oldA-a.hp;
            check(hostDamage>0 && b.hp==oldB,"host damage restores victim context even inside a remote-owned callback");
            check(a.mana==manaA && b.mana==manaB,"both physical damage calls preserve each player's current mana",
               {hostBefore:manaA,hostAfter:a.mana,joinBefore:manaB,joinAfter:b.mana});
            check(a.currentArmor.id==initial.aArmor && b.currentArmor.id==initial.bArmor && a.skin==initial.aSkin && b.skin==initial.bSkin,
               "native armor and defense remain separate after both damage paths");
         }
         if(tick>=220 && !reloaded) {
            reloaded=true;
            check(stock(b)==initial.bAfterShot && b.currentWeapon.hold>0 && b.invent.items[b.currentWeapon.ammo].kol<initial.bReserve && b.currentWeapon.t_reload==0,
               "remote reload preserves total ammunition and consumes its own reserve");
            check(stock(a)==initial.aAfterShot && stock(a,initial.bWeapon)==initial.aOther,"remote reload leaves both host ammunition families unchanged");
            initial.aBeforeSwitch=a.currentWeapon;initial.bBeforeSwitch=b.currentWeapon;
            initial.bBeforeSwitchStock=stock(b);initial.aBeforeSwitchStock=stock(a);
         }
         if(tick>=155 && !movementChecked) {
            movementChecked=true;
            check(a.X<395 && b.X>705,"opposite input streams move their own native bodies",{hostX:a.X,joinX:b.X});
            check(session.lastFrame.players[0].x==a.X && session.lastFrame.players[1].x==b.X,"movement confirmations belong to the correct native players");
         }
         if(tick>=300 && !switched) {
            switched=true;
            check(b.currentWeapon!=null && b.currentWeapon.id==initial.aWeapon && session.actors[1].weaponEpoch==2,
               "remote equip request runs the native weapon change exactly once");
            check(a.currentWeapon===initial.aBeforeSwitch && stock(a)==initial.aBeforeSwitchStock,
               "remote equip does not replace or spend the host weapon");
            check(stock(b,initial.bWeapon)==initial.bBeforeSwitchStock,"switching away preserves the previous native magazine and reserve");
            Log.write("mana-observed",{hostStart:initial.aMana,hostNow:a.mana,joinStart:initial.bMana,joinNow:b.mana,
               note:"Native recovery advances during the scene; no fixed-mana assumption across ticks"});
         }
         if(tick>=315 && !aiStarted) {
            aiStarted=true;
            // Retire the stationary outgoing-hit targets before testing the
            // incoming path; they must not absorb the enemy's real bullets.
            for each(var target:Object in targets) {
               target.disabled=true;target.remVisual();
               var index:int=access.world.loc.units.indexOf(target);
               if(index>=0)access.world.loc.units.splice(index,1);
            }
            a.hp=a.maxhp=10000;b.hp=b.maxhp=10000;
            aiHealth=[a.hp,b.hp];aiMinimum=aiHealth.concat();
            a.obs=a.maxObs;b.obs=b.maxObs;
            foes=[spawnFoe(a.X-85,a.Y),spawnFoe(b.X+85,b.Y)];
            aiShots=[session.runtime.spawnsFor(foes[0]),session.runtime.spawnsFor(foes[1])];
         }
         if(aiStarted)for each(var foe:Object in foes) {
            acquiredHost=acquiredHost || foe.celUnit===a;acquiredJoin=acquiredJoin || foe.celUnit===b;
            aiMinimum[0]=Math.min(aiMinimum[0],a.hp);aiMinimum[1]=Math.min(aiMinimum[1],b.hp);
         }
         if(tick>=endTick) {
            if(session.tactics!=null) {
               var tactics:Object=session.tactics.inspect(access.world.loc);
               check(tactics.steps==session.runtime.roomSteps && tactics.tick==session.runtime.roomSteps,"host TDFC advances exactly once per occupied room step");
               var faults:int=0;for each(var brain:Object in tactics.brains)faults+=brain.faults;
               check(faults==0,"TDFC native action execution has no swallowed errors");
               Log.write("tactics-evidence",tactics);
            }
            check(acquiredHost && acquiredJoin,"enemy AI acquired both real players during the observation window",
               {kind:enemyKind,host:acquiredHost,join:acquiredJoin,left:enemyState(foes[0],a),right:enemyState(foes[1],b)});
            check(session.runtime.spawnsFor(foes[0])>aiShots[0] && session.runtime.spawnsFor(foes[1])>aiShots[1],
               "both enemy native weapons generated real projectiles",{kind:enemyKind,before:aiShots,after:[session.runtime.spawnsFor(foes[0]),session.runtime.spawnsFor(foes[1])]});
            check(aiMinimum[0]<aiHealth[0] && aiMinimum[1]<aiHealth[1],
               "native enemy attacks damage both real player bodies",{kind:enemyKind,before:aiHealth,minimum:aiMinimum,
                  note:"Raider contact attacks are also enabled; this alone does not attribute every HP loss to a projectile."});
            check(session.actors[0].steps==session.runtime.roomSteps && session.actors[1].steps==session.runtime.roomSteps,"both real players step once per room simulation step");
            check(access.world.gg===a && access.world.pers===a.pers && access.world.invent===a.invent && access.world.gui.gg===a && access.scope.depth==0,
               "world and UI references return to the host after all phases");
            Log.write("ownership-complete",{swap:swap,tick:tick,elapsed:getTimer()-beginAt,shots:session.runtime.spawnsByPlayer});
            session.link.send({type:"probe-result",passed:passed,failed:failed});finish();
         }
      }
      private function fixture(session:HostSession):void {
         var room:Object=access.world.loc,y:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((y+1)/40);
         // Only the fixture lane changes. The real native collision grid, gun,
         // reload, damage and actor step implementations execute unmodified.
         // A complete bounded lane lets native evasive movement continue.
         // The earlier partial floor ended at x=120: enemies could flee off
         // it before the four-second fire window, invalidating that fixture.
         for(var x:int=0;x<room.space.length;x++)for(var z:int=0;z<=row;z++) {
            var tile:Object=room.space[x][z];tile.phis=z==row || x==0 || x==room.space.length-1?1:0;
            tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=z*40;tile.phY2=(z+1)*40;
            tile.water=0;tile.visi=1;tile.t_visi=1;tile.shelf=false;tile.diagon=0;tile.stair=0;tile.door=null;tile.trap=null;
         }
         // This fixture uses absolute left/right coordinates. Native putLoc
         // otherwise mirrors aiNapr independently of the rendered facing.
         room.black=false;room.mirror=false;
         for each(var actor:PlayerActor in session.actors) {
            access.scope.run(actor.context,function():void {actor.unit.setLocPos(actor.id==0?400:700,y);actor.unit.dx=actor.unit.dy=0;});
         }
         targets=[spawnTarget(210,y),spawnTarget(890,y)];
      }
      private function spawnTarget(x:Number,y:Number):Object {
         var Type:Class=access.definition("fe.unit.UnitZombie"),u:Object=new Type("1",100,<unit tr="1" dig="0"/>,null);
         u.putLoc(access.world.loc,x,y);access.world.loc.units.push(u);u.addVisual();
         u.hp=u.maxhp=10000;u.skin=u.armor=u.dexter=u.dodge=0;u.invulner=u.disabled=u.trigDis=false;
         u.doop=true;u.lootIsDrop=true;u.xp=0;u.scX=60;u.scY=100;u.setPos(x,y);u.setVisPos();u.animate();return u;
      }
      private function spawnFoe(x:Number,y:Number):Object {
         var Type:Class=access.definition(enemyKind=="tdfc"?"fe.unit.UnitRaider":"fe.unit.UnitTurret");
         var u:Object=enemyKind=="tdfc"?new Type("1",10,<unit tr="1" weap="r32" turn={x<550?1:-1}/>,null):
            new Type("land",100,<unit tr="2" vis={x<550?"right":"left"}/>,null);
         u.putLoc(access.world.loc,x,y);access.world.loc.units.push(u);access.world.loc.addObj(u);
         u.addVisual();
         u.invulner=false;u.disabled=false;u.oduplenie=0;u.overLook=true;u.vision=5;u.hp=u.maxhp=10000;
         u.storona=x<550?1:-1;
         if(u.currentWeapon!=null){u.currentWeapon.damage=75;u.currentWeapon.damageExpl=0;}
         return u;
      }
      private function enemyState(e:Object,player:Object):Object {
         return {target:e.celUnit==null?null:e.celUnit.id,x:e.X,y:e.Y,eyeX:e.eyeX,eyeY:e.eyeY,dir:e.storona,
            state:NativeAccess.get(e,"aiState"),sost:e.sost,wait:e.oduplenie,look:e.look(player,true),meet:e.isMeet(player),enemyAct:access.world.enemyAct,
            px:player.X,py:player.Y,obs:player.obs,maxObs:player.maxObs,invulner:player.invulner,disabled:player.disabled,trigDis:player.trigDis};
      }
   }
}
