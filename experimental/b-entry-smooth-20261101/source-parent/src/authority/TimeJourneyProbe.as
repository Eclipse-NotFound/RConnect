package authority {
   import flash.events.KeyboardEvent;
   /** Real split-room shots, background exits, death/revival and queued travel. */
   public final class TimeJourneyProbe extends Probe {
      private var ready:Boolean=false,peer:Boolean=false,phase:int=0,round:int=0;
      private var home:Object,back:Object,ground:Array=[],targets:Array=[],owners:Array=[];
      private var queued:uint=0,applied:uint=0,replaySteps:Array,replayAmmo:Array;
      private var entered:Boolean=false,returned:Boolean=false,replayHome:Boolean=false,replayBack:Boolean=false;
      private var frames:uint=0,sawSplit:Boolean=false,sawReplay:Boolean=false,sawRevival:Boolean=false,sawMap:Boolean=false;
      private var lastMap:Object,travelRequested:Boolean=false,deathTicks:int=0,settled:uint=0;
      private var targetKey:uint=0,nextBurst:int=5,burstUntil:int=0;
      private var mine:Object,mineVictimHP:Number=0,detonated:Boolean=false;
      public function TimeJourneyProbe(a:NativeAccess,h:Boolean){super(a,h);}
      private function key():void {
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,220));
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,220));
      }
      override public function message(v:Object):void {
         if(host && v.type=="time-journey-ready")peer=true;
         if(!host && v.type=="time-journey-toggle")key();
         if(!host && v.type=="time-journey-round"){round=v.round;nextBurst=5;burstUntil=0;targetKey=v.target;}
         if(!host && v.type=="time-journey-finish") {
            check(frames>80 && sawSplit && sawReplay,"join receives split rooms and shared replay throughout the native journey");
            check(sawRevival && sawMap,"join receives the revived character and the deferred shared map travel");
            SceneChecks.picture(access,"time-journey-join.png");finish();
         }
      }
      override public function input(f:Object,s:HostSession):Object {
         var actions:Array=[];for each(var a:Object in f.actions)if(a.type=="native" && a.key=="sandyToggle")actions.push(a);
         f.actions=actions;f.buttons=0;f.settings.follow=false;
         f.aimX=850;f.aimY=access.world.gg.Y-45;
         var time:Object=host?access.time==null?null:access.time.snapshot(false):RConnectMod.instance.replica==null?null:
            RConnectMod.instance.replica.lastFrame==null?null:RConnectMod.instance.replica.lastFrame.timeControl;
         if(time!=null && time.phase=="record" && (round==0 || round==4) && time.recorded>=5 && time.recorded<85) {
            var target:Object=host?targets[round==4?2:0]:null;
            if(!host)for each(var u:Object in RConnectMod.instance.replica.lastFrame.scene.units)if(u.key==targetKey){target=u.fields;break;}
            if(target!=null) {
               f.aimX=target.X;f.aimY=target.Y-target.scY*.6;
               if(time.recorded>=nextBurst){burstUntil=time.recorded+2;nextBurst=time.recorded+12;}
               if(time.recorded<burstUntil)f.buttons=Commands.FIRE;
            }
         }
         return f;
      }
      private function ammo(s:HostSession):Array {
         var values:Array=[];for each(var a:PlayerActor in s.actors)values.push(a.unit.currentWeapon.hold+a.unit.invent.items[a.unit.currentWeapon.ammo].kol);return values;
      }
      private function enemy(s:HostSession,actor:PlayerActor,turret:Boolean,hp:Number):Object {
         var u:Object,room:Object=actor.unit.loc;
         access.scope.run(actor.context,function():void {
            var Type:Class=access.definition(turret?"fe.unit.UnitTurret":"fe.unit.UnitZombie");
            u=new Type(turret?"land":"1",10,turret?<unit tr="4" turn="-1"/>:<unit tr="1" dig="0"/>,null);
            u.putLoc(room,850,actor.unit.Y);room.units.push(u);room.addObj(u);u.addVisual();u.setVisPos();
            u.hp=u.maxhp=hp;u.skin=u.armor=u.dexter=u.dodge=0;u.shithp=0;
            u.disabled=u.invulner=u.trigDis=false;u.stun=10000;u.doop=true;u.lootIsDrop=true;u.xp=0;
            u.setPos(850,actor.unit.Y);u.animate();
         });return u;
      }
      private function exit(s:HostSession,actor:PlayerActor,y:Number):void {
         actor.context.t_battle=actor.context.transitionCooldown=0;actor.unit.loc.t_alarm=0;
         if(actor.id==0)access.world.t_battle=0;
         access.scope.run(actor.context,function():void {check(actor.unit.outLoc(5,400,y),"native background exit accepted during shared time control");});
      }
      private function begin(s:HostSession):void {
         nextBurst=5;burstUntil=0;
         s.link.send({type:"time-journey-round",round:round,target:s.sceneId(targets[1])});queued=access.time.hits.queued;applied=access.time.hits.applied;
         for each(var a:PlayerActor in s.actors){a.unit.currentWeapon.hold=100;a.unit.invent.items[a.unit.currentWeapon.ammo].kol=100;}
         phase=1;if(round%2==0)key();else s.link.send({type:"time-journey-toggle"});
      }
      private function placeMine(s:HostSession):void {
         var a:PlayerActor=s.actors[0],b:PlayerActor=s.actors[1];
         s.runtime.transfers.relocate(b,home,580,ground[0]);s.runtime.rooms.showHost();
         a.unit.invent.items.mine.kol=3;s.combat.enabled=true;b.unit.invulner=false;
         access.scope.run(a.context,function():void {
            var Weapon:Class=access.definition("fe.weapon.Weapon"),w:Object=Weapon["create"](a.unit,"mine",0),old:Object=a.unit.currentWeapon;
            w.setPers(a.unit,a.unit.pers);w.lvl=0;w.addVisual();a.unit.currentWeapon=w;
            a.unit.celX=550;a.unit.celY=ground[0];w.step();w.attack(true);w.step();w.remVisual();a.unit.currentWeapon=old;
            for each(var u:Object in home.units)if(NativeAccess.get(u,"rconnectOwner")===a.unit)mine=u;
         });
         check(mine!=null && a.unit.invent.items.mine.kol==2,"native placement retains one player's real mine before shared time control");
         if(mine==null)throw new Error("Native player mine missing");
         mine.setPos(550,ground[0]);mine.fixed=true;mine.sens=0;mine.oduplenie=0;mine.damage1=10;
         mineVictimHP=b.unit.hp;
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null)return;
            if(!ready){ready=true;RConnectMod.instance.link.send({type:"time-journey-ready"});}
            var f:Object=r.displayFrame;++frames;
            sawSplit=sawSplit || f.players[0].room!=f.players[1].room;
            sawReplay=sawReplay || f.timeControl!=null && f.timeControl.phase=="replay";
            sawRevival=sawRevival || f.players[1].epoch==2;
            sawMap=sawMap || f.map.id=="rbl";return;
         }
         if(s==null || !s.active || !peer || s.runtime.tick<30)return;
         var a0:PlayerActor=s.actors[0],a1:PlayerActor=s.actors[1],t:TimeBridge=access.time;
         if(!ready) {
            if(t==null)throw new Error("Journey probe requires the independent time bridge");ready=true;
            for each(var col:Array in access.world.land.locs)for each(var row:Array in col)
               if(home==null && row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky){home=row[0];back=row[1];}
            if(home==null)throw new Error("Native background pair unavailable");
            ground=[ProbeArena.floor(home),ProbeArena.floor(back)];
            s.runtime.transfers.relocate(a0,home,400,ground[0]);s.runtime.transfers.relocate(a1,back,400,ground[1]);s.runtime.rooms.showHost();
            for each(var actor:PlayerActor in s.actors){actor.unit.invulner=true;owners.push(actor.unit);}
            targets=[enemy(s,a0,false,100),enemy(s,a1,true,100)];begin(s);return;
         }
         if(phase==1 && t.phase=="record") {
            if(round==3 && t.recorded>=20 && !detonated){detonated=true;mine.die();}
            if(round==1 && t.recorded>=35 && !entered){entered=true;exit(s,a1,ground[0]);}
            if(round==1 && t.recorded>=60 && !returned){returned=true;check(a1.unit.loc===home,"joining player enters the foreground while recording");exit(s,a1,ground[1]);}
            if(round==2 && t.recorded>=35) {
               a1.spawn={room:back,x:400,y:ground[1]};a1.unit.pers.currentCP=null;a1.unit.invulner=false;
               access.scope.run(a1.context,function():void {a1.unit.damage(1000000,0,null,true);});
               check(a1.unit.hp<=0 && a1.deathTicks==300,"native environmental death remains immediate during recording");phase=2;
            }else if(round==4 && t.recorded>=65) {
               check(t.hits.pending>0 && targets[2].hp==10000,"new native hits are pending before the host requests travel");
               lastMap=access.world.land;access.world.game.gotoLand("rbl",null,true);travelRequested=true;phase=2;
               check(access.world.land===lastMap && access.world.game.curLandId!="rbl" && access.world.t_exit==0,
                  "host map travel waits for recorded damage and replay");
            }else if(round==3 && t.recorded>=40) {
               check(t.hits.pending>0 && a1.unit.hp==mineVictimHP,"teammate damage from a player-owned mine waits for replay",{before:mineVictimHP,after:a1.unit.hp,pending:t.hits.pending});
               s.link.send({type:"time-journey-toggle"});phase=2;
            }else if(round<2 && t.recorded>=90) {
               if(round==0)check(t.hits.queued>queued && targets[0].hp==100 && targets[1].hp==100,
                  "both real rooms retain enemy health until native shot replay",{queued:t.hits.queued-queued,hp:[targets[0].hp,targets[1].hp],shots:s.runtime.spawnsByPlayer.concat()});
               if(round%2==0)key();else s.link.send({type:"time-journey-toggle"});phase=2;
            }
         }
         if(phase==2 && t.phase=="replay") {
            phase=3;replaySteps=[a0.steps,a1.steps];replayAmmo=ammo(s);deathTicks=a1.deathTicks;
         }
         if(phase==3 && t.phase=="replay") {
            if(round==1){replayHome=replayHome || a1.unit.loc===home;replayBack=replayBack || a1.unit.loc===back;}
            if(travelRequested && access.world.land!==lastMap)check(false,"map remains intact until replay finishes");
         }
         if(phase==3 && t.phase=="idle") {
            check(a0.steps==replaySteps[0] && a1.steps==replaySteps[1] && JSON.stringify(ammo(s))==JSON.stringify(replayAmmo),
               "journey replay does not repeat player steps or ammunition expenditure",{round:round});
            check(t.hits.pending==0 && access.scope.depth==0 && access.world.gg===owners[0],"journey replay consumes hits and restores the host context",{round:round});
            if(round==0)check(targets[0].hp<=0 && targets[1].hp<=0 && t.hits.applied>applied,
               "real zombie and turret in separate rooms die only from their replayed native impacts",{hp:[targets[0].hp,targets[1].hp]});
            if(round==1)check(replayHome && replayBack && a0.unit.loc===home && a1.unit.loc===back && a1.unit.ggControl,
               "background-room film replays both rooms then restores each live endpoint and control");
            if(round==2) {
               check(a1.deathTicks==deathTicks && a1.epoch==1,"automatic death-triggered replay preserves the native revival countdown");phase=4;return;
            }
            if(round==3) {
               check(a1.unit.hp<mineVictimHP && a0.unit.invent.items.mine.kol==2 && mine.sost>=3,
                  "native mine explosion settles once in replay without a second mine expenditure",{before:mineVictimHP,after:a1.unit.hp});
               // Restore the split-room firing lane after the mine fixture.
               // An invulnerable teammate still legitimately stops a native
               // bullet when friendly fire is enabled.
               a1.unit.invulner=true;s.combat.enabled=false;
               s.runtime.transfers.relocate(a1,back,400,ground[1]);s.runtime.rooms.showHost();
               targets.push(enemy(s,a0,false,10000));
            }
            if(round==4){phase=5;return;}
            ++round;begin(s);
         }
         if(phase==4 && a1.epoch==2 && a1.deathTicks==0 && a1.unit.ggControl) {
            check(a1.unit.loc===back && a0.unit===owners[0] && a1.unit===owners[1] && targets[0].hp<=0 && targets[1].hp<=0,
               "revival retains both original players and defeated enemies after time replay");
            for each(actor in s.actors)access.scope.run(actor.context,function():void {actor.unit.pers.healAll();actor.unit.invulner=true;});
            placeMine(s);++round;begin(s);
         }
         if(phase==5 && access.world.land.act.id=="rbl" && access.world.t_exit==0 && a0.unit.loc===a1.unit.loc) {
            if(settled==0)settled=s.runtime.tick;
            if(s.runtime.tick-settled<25)return;
            check(targets[2].hp<10000 && t.hits.pending==0,"queued map travel executes only after the native damage ledger is settled");
            check(a0.unit===owners[0] && a1.unit===owners[1] && a0.unit.ggControl && a1.unit.ggControl && a1.epoch==2,
               "time-triggered map travel retains independent player identity and controls");
            SceneChecks.picture(access,"time-journey-host.png");s.link.send({type:"time-journey-finish"});finish();
         }
      }
   }
}
