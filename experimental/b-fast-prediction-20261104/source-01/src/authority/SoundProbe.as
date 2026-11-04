package authority {
   import flash.media.SoundChannel;
   /** Actual native gun input and native sound resources, including preparation
    * channels with explicit stop and per-listener UI/room routing. */
   public final class SoundProbe extends Probe {
      private var ready:Boolean=false,peerReady:Boolean=false,begin:int=-1,doneTick:int=-1;
      private var prep:SoundChannel,prepId:uint=0,quiet:SoundChannel;
      private var events:uint=0,guns:uint=0,stops:uint=0,ui:uint=0,wrongUI:uint=0;
      private var startedChannels:uint=0,seen:Object={};
      public function SoundProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && value.type=="sound-ready")peerReady=true;
         if(!host && value.type=="sound-begin")begin=value.tick;
         if(!host && value.type=="sound-end")doneTick=value.tick;
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         var elapsed:int=begin<0?-1:(host?session.runtime.tick:RConnectMod.instance.replica.lastTick)-begin;
         if(elapsed>=5 && elapsed<65)frame.buttons=Commands.FIRE;
         frame.aimX=950;frame.aimY=access.world.gg.Y-55;return frame;
      }
      private function confirmed(frame:Object):void {
         if(frame.audio==null)return;
         for each(var event:Object in frame.audio.events) {
            ++events;
            if(event.stop){++stops;continue;}
            check(!seen[event.id],"native sound starts once per authoritative event "+event.id);seen[event.id]=true;
            if(event.name=="lmg_s")++guns;
            if(event.name=="pip1")++ui;
            if(event.name=="pip2")++wrongUI;
            if(RConnectMod.instance.replica.sound.output.channelFor(event.id)!=null)++startedChannels;
         }
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready){ready=true;replica.confirmed=confirmed;RConnectMod.instance.link.send({type:"sound-ready"});}
            if(doneTick>=0 && replica.displayFrame.tick>=doneTick) {
               check(guns>6 && startedChannels>6,"join plays real native gun SoundChannels from confirmed actions",{guns:guns,channels:startedChannels});
               check(stops>0 && replica.sound.output.stops>0,"native preparation stop reaches join output",{events:stops,stopped:replica.sound.output.stops});
               check(ui==1 && wrongUI==0,"personal UI sound is routed only to its own listener",{own:ui,other:wrongUI});
               check(replica.sound.output.loops>0,"join starts native continuous sound resources",{loops:replica.sound.output.loops});
               finish();
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready) {
            ready=true;var fy:Number=ProbeArena.floor(access.world.loc);
            for each(var actor:PlayerActor in session.actors){actor.unit.setLocPos(300+actor.id*150,fy);actor.unit.currentWeapon.hold=100;actor.unit.invulner=true;}
         }
         if(begin<0 && peerReady){begin=session.runtime.tick;session.link.send({type:"sound-begin",tick:begin});}
         if(begin<0)return;
         var elapsed:int=session.runtime.tick-begin,snd:Class=access.definition("fe.Snd"),remote:PlayerActor=session.actors[1];
         if(elapsed==70) {
            check(session.runtime.spawnsByPlayer[0]>0 && session.runtime.spawnsByPlayer[1]>0,"sound fixture uses both players' real native gun execution");
            access.scope.run(remote.context,function():void {prep=snd["ps"]("bfg_p",remote.unit.X,remote.unit.Y,0);});
            check(prep!=null,"host returns the original native SoundChannel type for a preparation sound");
         }
         if(elapsed==76){check(prep!=null && prep.position>0,"native preparation channel advances real playback time");if(prep!=null)snd["rconnectStopChannel"](prep);}
         if(elapsed>=85 && elapsed<115)access.scope.run(remote.context,function():void {snd["pshum"]("vortex",.8);});
         if(elapsed==120) {
            access.scope.run(remote.context,function():void {quiet=snd["ps"]("pip1");});
            check(quiet!=null && quiet.soundTransform.volume==0,"remote personal UI keeps host audio silent while retaining native channel lifetime");
            snd["ps"]("pip2");
         }
         if(elapsed>=155) {
            check(session.sound.capturedStops>0 && session.sound.output.stops>0,"host observes actual native sound stop path");
            check(session.sound.output.loops>0,"host retains native continuous sound output");
            session.link.send({type:"sound-end",tick:session.runtime.tick});finish();
         }
      }
   }
}
