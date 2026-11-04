package authority {
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.utils.getTimer;
   /** Normal Leave must finish pending native hits before detaching the clock. */
   public final class TimeExitProbe extends Probe {
      private var replay:Boolean,ready:Boolean=false,peer:Boolean=false,phase:int=0,started:int=0;
      private var target:Object,initialHP:Number=0,fy:Number=0,oldPlayer:Object;
      private var bridge:TimeBridge,history:TimeHistory,ledger:DeferredHits;
      private var leaveAt:int=0,offlineAt:int=0,offlineFrames:int=0,oldX:Number=0;
      private var requested:Boolean=false;
      public function TimeExitProbe(a:NativeAccess,h:Boolean,replay:Boolean){super(a,h);this.replay=replay;}
      private function key():void {
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,220));
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,220));
      }
      override public function input(f:Object,s:HostSession):Object {
         var actions:Array=[];for each(var a:Object in f.actions)if(a.type=="native" && a.key=="sandyToggle")actions.push(a);
         f.actions=actions;f.buttons=0;f.aimX=850;f.aimY=fy-55;
         var time:Object=host?access.time==null?null:access.time.snapshot(false):RConnectMod.instance.replica==null?null:
            RConnectMod.instance.replica.lastFrame==null?null:RConnectMod.instance.replica.lastFrame.timeControl;
         if(time!=null && time.phase=="record" && time.recorded>=8 && time.recorded<55)f.buttons=Commands.FIRE;
         return f;
      }
      override public function message(v:Object):void {
         if(host && v.type=="time-exit-ready")peer=true;
         if(!host && v.type=="time-exit-setup")fy=v.floor;
         if(!host && v.type=="time-exit-leave") {
            requested=true;leaveAt=getTimer();RConnectMod.instance.leaveSession();
            check(RConnectMod.instance.role=="join" && access.time!=null,
               "normal leave waits for pending time-control results before detaching");
         }
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         var m:RConnectMod=RConnectMod.instance,w:Object=access.world;
         if(oldPlayer!=null && m.role==""){afterLeave();return;}
         if(!host) {
            if(r==null || r.displayFrame==null)return;
            if(!ready){ready=true;oldPlayer=w.gg;bridge=access.time;m.link.send({type:"time-exit-ready"});}
            if(requested && getTimer()-leaveAt>30000){check(false,"graceful time-control leave completes within its deadline");finish();}
            return;
         }
         if(s==null || !s.active || !peer || s.runtime.tick<30)return;
         if(!ready) {
            ready=true;oldPlayer=w.gg;bridge=access.time;ledger=bridge.hits;
            fy=ProbeArena.floor(w.loc);
            for each(var actor:PlayerActor in s.actors) {
               actor.unit.setLocPos(400+actor.id*180,fy);actor.unit.invulner=true;
               actor.unit.currentWeapon.hold=100;actor.unit.invent.items[actor.unit.currentWeapon.ammo].kol=100;
            }
            var Type:Class=access.definition("fe.unit.UnitZombie");target=new Type("1",100,<unit tr="1" dig="0"/>,null);
            target.putLoc(w.loc,850,fy);w.loc.units.push(target);target.addVisual();target.setVisPos();
            target.hp=target.maxhp=100000;target.skin=target.armor=target.dexter=target.dodge=0;
            target.invulner=target.disabled=target.trigDis=false;target.doop=true;target.lootIsDrop=true;target.xp=0;target.stun=10000;
            target.scX=50;target.scY=100;target.setPos(850,fy);target.animate();initialHP=target.hp;
            s.link.send({type:"time-exit-setup",floor:fy});key();phase=1;return;
         }
         if(phase==1 && bridge.phase=="record" && bridge.recorded>=75) {
            history=bridge.history;check(ledger.pending>0 && target.hp==initialHP,"leave fixture contains real unconsumed native hits");
            if(replay){key();phase=2;}else {s.link.send({type:"time-exit-leave"});phase=3;}
         }
         if(phase==2 && bridge.phase=="replay" && bridge.replayed>=20) {
            check(ledger.pending>0 && history.inspect().layers>0,"leave is requested while historical display layers are borrowed");
            s.link.send({type:"time-exit-leave"});phase=3;
         }
      }
      private function afterLeave():void {
         var w:Object=access.world,m:RConnectMod=RConnectMod.instance;
         if(offlineAt==0)offlineAt=getTimer();
         if(getTimer()-offlineAt>60000){check(false,"returned single-player game becomes controllable");finish();return;}
         if(w.pip.active)w.pip.onoff(-1);
         if(w.clickReq==1)w.ctr.onMouseDown1(new MouseEvent(MouseEvent.MOUSE_DOWN));
         if(!w.gg.ggControl && (w.gui.vis.dial.visible || w.gui.vis.inform.visible)){w.ctr.keyPressed=true;return;}
         if(w.t_exit>0 || !w.gg.ggControl || w.gg.work!="")return;
         if(offlineFrames++==0) {
            check(access.time==null && bridge.phase=="idle" && bridge.history==null,
               "leaving releases the shared time-control clock and replay displays");
            check(access.definition("fe.unit.Unit")["rconnectDeferDamage"]==null &&
               access.definition("fe.loc.Location")["rconnectPlayerStep"]==null,
               "leaving restores the original native damage and scheduling callbacks");
            if(host) {
               var released:Object=history.inspect();
               check(ledger.pending==0 && ledger.applied>0 && target.hp<initialHP,
                  "normal leave settles previously recorded hits before returning to the host journey",
                  {applied:ledger.applied,pending:ledger.pending,before:initialHP,after:target.hp});
               check(released.frames==0 && released.layers==0 && released.copies==0 && released.bindings.length==0,
                  "normal leave retains no recorded frames, display clones or borrowed bindings");
            }
            check(host?w.gg===oldPlayer:w.gg!==oldPlayer,"each side returns to its own native player and journey");
            check(w.gg.loc===w.loc && w.gui.gg===w.gg && w.invent.gg===w.gg && access.scope.depth==0,
               "post-replay leave restores native world, room, UI and inventory ownership");
            check(!w.onPause && w.gg.vis!=null && w.gg.vis.parent!=null && w.gg.hp>0,
               "returned native game is alive, visible and unpaused");
            oldX=w.gg.X;
         }
         w.ctr.keyRight=offlineFrames<12;
         if(offlineFrames>=20){check(w.gg.ggControl && m.host==null && m.replica==null,
            "native control remains available after resumed single-player frames");SceneChecks.picture(access,"time-exit-own-journey.png");finish();}
      }
   }
}
