package authority {
   import flash.utils.getTimer;
   import flash.events.MouseEvent;
   /** Personal state through normal input, paused menus, room travel and leave. */
   public final class MswLifecycleProbe extends Probe {
      private static const CHARGE:String="msw_pointer_charge_v1",MARK:String="b_msw_own_journey";
      private var phase:int=0,begin:int=0,pauseFrames:int=0,oldPlayer:Object,initial:Array,oldClocks:Object;
      private var pauseTick:int,clocks:Array,baseFlash:Number,saveAsked:Boolean=false,saveDone:Boolean=false;
      private var leavingAt:int=0,localFrames:int=0,legacyEnergy:Number,legacyLit:Boolean=false;
      private var requestAt:int=0;
      public function MswLifecycleProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function prepare():void {
         super.prepare();var w:Object=access.world;
         w.game.triggers[CHARGE]=host?.25:.75;w.game.triggers[MARK]=host?11:22;w.invent.items.batt.kol=20;
      }
      override public function input(f:Object,s:HostSession):Object {f.buttons=0;return f;}
      override public function message(v:Object):void {
         if(!host && v.type=="msw-life-give")check(RConnectMod.instance.requestWeaponAction("flashGive"),"join submits the public MSW supply action");
         if(!host && v.type=="msw-life-pause")access.world.pip.onoff(1);
         if(!host && v.type=="msw-life-resume")access.world.pip.onoff(-1);
         if(!host && v.type=="msw-life-save"){saveAsked=true;access.world.saveGame(1);}
         if(host && v.type=="msw-life-saved")saveDone=true;
         if(!host && v.type=="msw-life-leave"){phase=8;RConnectMod.instance.leaveSession();}
      }
      private function amount(g:Object):Number{return Number(g.invent.items.mswflash.kol);}
      private function charge(s:HostSession,id:int):Number{return Number(access.weapons.snapshot(id).state[CHARGE]);}
      private function sameCharges(s:HostSession):Boolean{return Math.abs(charge(s,0)-.25)<1e-9 && Math.abs(charge(s,1)-.75)<1e-9;}
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;var m:RConnectMod=RConnectMod.instance,w:Object=access.world;
         if(oldPlayer!=null && m.role==""){afterLeave();return;}
         if(!host) {
            if(r==null || r.lastFrame==null)return;
            if(oldPlayer==null){oldPlayer=w.gg;baseFlash=amount(w.gg);}
            if(saveAsked && !saveDone && w.getSave(1)!=null && w.getSave(1).est==1) {
               saveDone=true;var d:Object=w.getSave(1);
               check(d.game.triggers[CHARGE]==.75,"native join save retains its own prepaid energy");
               check(d.invent.items.mswflash==baseFlash+10,"native join save contains both confirmed supplies exactly once",{before:baseFlash,saved:d.invent.items.mswflash});
               m.link.send({type:"msw-life-saved"});
            }return;
         }
         if(s==null || !s.active)return;
         var tick:int=s.runtime.tick;
         if(phase==0 && tick>25) {
            oldPlayer=w.gg;initial=[amount(s.actors[0].unit),amount(s.actors[1].unit)];baseFlash=initial[0];begin=tick;phase=1;
            check(sameCharges(s),"distinct MSW profile remainders survive authority registration");
            requestAt=getTimer();
            check(m.requestWeaponAction("flashGive"),"host submits the public MSW supply action");s.link.send({type:"msw-life-give"});
         }
         if(phase==1 && tick-begin>45 && (amount(s.actors[0].unit)>=initial[0]+5 && amount(s.actors[1].unit)>=initial[1]+5 || getTimer()-requestAt>20000)) {
            check(amount(s.actors[0].unit)==initial[0]+5 && amount(s.actors[1].unit)==initial[1]+5,"each reliable supply request changes only its owner's native inventory once",
               {before:initial,after:[amount(s.actors[0].unit),amount(s.actors[1].unit)],wait:getTimer()-requestAt});
            m.preferences.setValue("pauseMenus","1");m.applyPreferences();phase=2;s.link.send({type:"msw-life-pause"});
         }
         if(phase==2 && s.pause.paused) {
            if(pauseFrames++==0){pauseTick=tick;clocks=[access.weapons.snapshot(0).clock,access.weapons.snapshot(1).clock];
               requestAt=getTimer();
               m.requestWeaponAction("flashGive");s.link.send({type:"msw-life-give"});}
            if(pauseFrames>=60 && (amount(s.actors[0].unit)>=initial[0]+10 && amount(s.actors[1].unit)>=initial[1]+10 || getTimer()-requestAt>20000)) {
               check(tick==pauseTick && access.weapons.snapshot(0).clock==clocks[0] && access.weapons.snapshot(1).clock==clocks[1],"shared menu pause stops both MSW execution clocks");
               check(amount(s.actors[0].unit)==initial[0]+10 && amount(s.actors[1].unit)==initial[1]+10,"paused UI supplies commit once without advancing weapon simulation");
               check(sameCharges(s),"paused menu actions do not consume either pointer battery");
               phase=3;begin=tick;s.link.send({type:"msw-life-resume"});
            }
         }
         if(phase==3 && tick-begin>30) {
            var home:Object,back:Object;
            for each(var column:Array in w.land.locs)for each(var row:Array in column)
               if(row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky){home=row[0];back=row[1];break;}
            if(home==null)throw new Error("MSW lifecycle requires a foreground/background pair");
            oldClocks=access.weapons.inspect().clocks;
            s.runtime.transfers.relocate(s.actors[0],home,400,ProbeArena.floor(home));
            s.runtime.transfers.relocate(s.actors[1],back,500,ProbeArena.floor(back));
            s.runtime.rooms.showHost();begin=tick;phase=4;
         }
         if(phase==4 && tick-begin>50) {
            var view:Object=access.weapons.inspect();
            check(s.actors[0].unit.loc!==s.actors[1].unit.loc && view.players[0].room!=view.players[1].room,"split players use distinct native MSW room services");
            var frozen:Boolean=true,empty:int=0;
            for(var key:String in oldClocks)if(key!=String(view.players[0].room) && key!=String(view.players[1].room)){++empty;frozen=frozen && oldClocks[key]==view.clocks[key];}
            check(empty>0 && frozen,"unoccupied MSW room clocks stop while both occupied rooms run");
            check(sameCharges(s),"room handoffs retain both independent prepaid remainders");
            for each(var a:PlayerActor in s.actors)a.unit.pers.healAll();
            w.game.gotoLand("rbl",null,true);phase=5;begin=tick;
         }
         if(phase==5 && tick-begin>45 && w.t_exit==0 && w.land.act.id=="rbl" && s.actors[1].unit.loc===w.loc) {
            check(access.weapons.inspect().rooms==1,"whole-map travel releases departed MSW room services");
            check(sameCharges(s),"whole-map travel preserves personal optical weapon state");
            phase=6;s.link.send({type:"msw-life-save"});
         }
         if(phase==6 && saveDone){phase=8;s.link.send({type:"msw-life-leave"});}
      }
      private function afterLeave():void {
         var w:Object=access.world;
         if(leavingAt==0)leavingAt=getTimer();
         if(getTimer()-leavingAt>60000){check(false,"offline native weapon test completes within its bounded deadline",{phase:phase,work:w.gg.work,room:w.loc.id,exit:w.t_exit,pip:w.pip.active});finish();return;}
         // A native personal save opens Pip. Continue through its real close
         // action before waiting for a weapon change or a travel transition.
         if(w.pip.active)w.pip.onoff(-1);
         if(w.clickReq==1)w.ctr.onMouseDown1(new MouseEvent(MouseEvent.MOUSE_DOWN));
         if(!w.gg.ggControl && (w.gui.vis.dial.visible || w.gui.vis.inform.visible)){w.ctr.keyPressed=true;return;}
         if(w.t_exit>0 || !w.gg.ggControl || w.gg.work!="")return;
         if(phase==8) {
            check(access.weapons==null,"leaving detaches the independent MSW lease");
            check(w.game.triggers[CHARGE]==(host?.25:.75),"return to own journey carries the latest personal MSW state");
            check(w.game.triggers[MARK]==(host?11:22),"MSW carry does not import the other player's journey triggers");
            check(amount(w.gg)==baseFlash+10,"return to own journey retains confirmed native supplies");
            // Vanilla deliberately forbids weapon input in the home base.
            // Start a real expedition before testing the detached callbacks.
            phase=9;w.game.beginMission("random_mane");return;
         }
         if(phase==9) {
            if(w.land.act.id!="random_mane" || w.game.curLandId!="random_mane" || w.loc.base)return;
            if(w.gg.currentWeapon==null || w.gg.currentWeapon.id!="mswlaserpointer")w.gg.changeWeapon("mswlaserpointer",true);
            legacyEnergy=Number(w.invent.items.batt.kol)+Number(w.game.triggers[CHARGE]);phase=10;localFrames=0;
         }
         if(phase==10) {
            ++localFrames;w.ctr.keyAttack=localFrames==2 || localFrames==16;
            var energy:Number=Number(w.invent.items.batt.kol)+Number(w.game.triggers[CHARGE]);legacyLit=legacyLit || energy<legacyEnergy-.001;
            if(localFrames>=25){check(legacyLit && energy<legacyEnergy,"original MSW input and energy execution resume after B detaches",
               {before:legacyEnergy,after:energy,weapon:NativeAccess.get(w.gg.currentWeapon,"id"),base:w.loc.base,work:w.gg.work});finish();}
         }
      }
   }
}
