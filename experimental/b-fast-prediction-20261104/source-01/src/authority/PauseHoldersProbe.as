package authority {
   import flash.utils.getTimer;
   /** Two independent native UI holders. The first close must not resume the
    * world; the last close must resume both the simulation and its playback. */
   public final class PauseHoldersProbe extends Probe {
      private var ready:Boolean=false,peerReady:Boolean=false,phase:int=0,round:int=0,at:int=0;
      private var freezeTick:uint=0,resumeTick:uint=0,peerOpen:Boolean=false,peerClosed:Boolean=false;
      private var frozen:Boolean=true,shownFreeze:Boolean=false,shownResume:Boolean=false;
      private var seenTick:uint=0;
      public function PauseHoldersProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;return frame;}
      private function menu(open:Boolean,sats:Boolean):void {
         if(sats)access.world.sats.onoff(open?1:-1);else access.world.pip.onoff(open?5:-1);
      }
      override public function message(v:Object):void {
         if(host) {
            if(v.type=="holders-ready")peerReady=true;
            if(v.type=="holders-opened" && v.round==round)peerOpen=true;
            if(v.type=="holders-closed" && v.round==round)peerClosed=true;
            if(v.type=="holders-resumed" && v.round==round)shownResume=true;
         }else {
            if(v.type=="holders-open") {
               round=v.round;shownFreeze=shownResume=false;phase=1;
               menu(true,round==0);
               check(round==0?access.world.sats.active:access.world.pip.active,"joining native UI opens for overlapping pause round "+round);
               RConnectMod.instance.link.send({type:"holders-opened",round:round});
            }
            if(v.type=="holders-close") {
               menu(false,round==0);phase=2;
               RConnectMod.instance.link.send({type:"holders-closed",round:round});
            }
            if(v.type=="holders-finish")finish();
         }
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null)return;
            if(!ready){ready=true;RConnectMod.instance.link.send({type:"holders-ready"});}
            if(phase>0 && r.displayFrame.paused) {
               if(!shownFreeze){shownFreeze=true;seenTick=r.displayFrame.tick;}
               else if(r.displayFrame.tick!=seenTick){check(false,"overlapping pause keeps one exact displayed tick");seenTick=r.displayFrame.tick;}
            }
            if(phase==2 && shownFreeze && !r.displayFrame.paused && r.displayFrame.tick>seenTick+10 && !shownResume) {
               shownResume=true;check(true,"joining playback resumes only after both native UI holders close round "+round);
               RConnectMod.instance.link.send({type:"holders-resumed",round:round});
            }
            return;
         }
         if(s==null || !s.active || !peerReady)return;
         var now:int=getTimer(),tick:uint=s.runtime.tick;
         if(phase==0) {
            s.pause.policyMenus=s.pause.policySats=true;
            if(!ready) {
               ready=true;var fy:Number=ProbeArena.floor(access.world.loc);
               for each(var a:PlayerActor in s.actors){a.unit.setLocPos(400+a.id*200,fy);a.unit.invulner=true;}
            }
            peerOpen=peerClosed=shownResume=false;frozen=true;
            menu(true,round==1);phase=1;return;
         }
         if(phase==1 && s.pause.paused) {
            freezeTick=tick;phase=2;at=now;
            s.link.send({type:"holders-open",round:round});
         }
         if(phase>=2 && phase<=4)frozen=frozen && tick==freezeTick;
         if(phase==2 && peerOpen && (round==0?s.pause.remoteSats:s.pause.remoteMenus) && now-at>=800) {
            phase=3;at=now;
            if(round==0)menu(false,false);else s.link.send({type:"holders-close",round:round});
         }
         if(phase==3 && now-at>=900 && (round==0 || peerClosed && !s.pause.remoteMenus)) {
            check(frozen && s.pause.paused,"closing the first holder leaves the host world frozen round "+round,
               {tick:tick,expected:freezeTick,hostMenu:SharedPause.menus(access.world),hostSats:access.world.sats.active,
                remoteMenu:s.pause.remoteMenus,remoteSats:s.pause.remoteSats});
            phase=4;
            if(round==0)s.link.send({type:"holders-close",round:round});else menu(false,true);
         }
         if(phase==4 && !s.pause.paused) {phase=5;resumeTick=tick;}
         if(phase==5 && shownResume && tick>=resumeTick+20) {
            check(s.pause.epoch==2*(round+1) && !s.pause.paused && !SharedPause.requested(access.world),
               "two UI holders create one freeze and one resume boundary round "+round,{epoch:s.pause.epoch});
            check(access.world.gg===s.actors[0].unit && access.scope.depth==0,"overlapping native menus return the host's own controls round "+round);
            if(++round<2){phase=0;return;}
            s.pause.policyMenus=s.pause.policySats=false;s.link.send({type:"holders-finish"});finish();
         }
      }
   }
}
