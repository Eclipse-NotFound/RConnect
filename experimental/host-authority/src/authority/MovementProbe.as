package authority {
   import flash.utils.getTimer;
   /** Compare bounded movement math to actual native walking, braking and
    * reversal; independently inspect the join's visible response and resets. */
   public final class MovementProbe extends Probe {
      private var ready:Boolean=false,peerReady:Boolean=false,begin:int=-1,doneTick:int=-1;
      private var previous:Object,samples:int=0,mismatches:int=0,maxError:Number=0,starts:Number=0;
      private var leadSamples:int=0,maxLead:Number=0,unsafeLead:int=0,groundSamples:int=0;
      public function MovementProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(v:Object):void {
         if(host && v.type=="move-ready")peerReady=true;
         if(!host && v.type=="move-begin")begin=v.tick;
         if(!host && v.type=="move-end")doneTick=v.tick;
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         var tick:int=host?session==null?0:session.runtime.tick:RConnectMod.instance.replica==null?0:RConnectMod.instance.replica.lastTick;
         var t:int=tick-begin;
         if(!host && begin>=0) {
            if(t>=10 && t<70)frame.buttons=Commands.RIGHT;
            if(t>=70 && t<130)frame.buttons=Commands.LEFT;
            if(t>=165 && t<166)frame.buttons=Commands.JUMP;
            if(t>=205 && t<245)frame.buttons=Commands.RIGHT|Commands.FIRE;
         }
         frame.aimX=1000;frame.aimY=access.world.gg.Y-45;return frame;
      }
      private function compare(session:HostSession):void {
         var g:Object=session.actors[1].unit,current:Object=GroundMotion.capture(g);
         if(begin>=0 && current!=null)++groundSamples;
         if(previous!=null && current!=null && session.runtime.tick-begin<155) {
            var expected:Object=GroundMotion.advance(previous,g.walk<0?Commands.LEFT:g.walk>0?Commands.RIGHT:0);
            if(expected!=null) {
               ++samples;var error:Number=Math.max(Math.abs(expected.x-g.X),Math.abs(expected.dx-g.dx));
               maxError=Math.max(maxError,error);
               if(error>.00001){++mismatches;if(mismatches<=4)Log.write("movement-native-mismatch",{before:previous,expected:expected,actual:current});}
            }
         }
         previous=current;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready){ready=true;RConnectMod.instance.link.send({type:"move-ready"});}
            var p:MovementPrediction=replica.prediction;
            if(Math.abs(p.lead)>.01)++leadSamples;maxLead=Math.max(maxLead,Math.abs(p.lead));
            if(begin>=0 && replica.lastTick-begin>210 && replica.lastTick-begin<245 && Math.abs(p.lead)>.001)++unsafeLead;
            if(doneTick>=0 && replica.displayFrame.tick>=doneTick) {
               check(p.applications>30 && leadSamples>10,"join replays bounded own movement before confirmation",{applications:p.applications,moving:leadSamples,maxLead:maxLead});
               check(maxLead<=24.001 && unsafeLead==0,"movement lead stays bounded and clears during real firing",{maxLead:maxLead,unsafe:unsafeLead});
               check(Math.abs(access.world.gg.X-replica.lastFrame.players[1].x)<.01,"stopped player converges to confirmed native position");
               check(access.world.onPause,"movement preview never resumes the client combat world");finish();
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready) {
            ready=true;var fy:Number=ProbeArena.floor(access.world.loc);
            for each(var a:PlayerActor in session.actors){a.unit.setLocPos(300+300*a.id,fy);a.unit.dx=a.unit.dy=0;a.unit.invulner=true;}
            var publish:Function=session.runtime.afterStep;
            session.runtime.afterStep=function():void {compare(session);publish();};starts=session.actors[1].unit.X;
         }
         if(begin<0 && peerReady){begin=session.runtime.tick;session.link.send({type:"move-begin",tick:begin});}
         if(begin<0)return;
         if(session.runtime.tick-begin>=280) {
            check(samples>90 && mismatches==0,"movement subset matches actual native acceleration, reversal and braking",{samples:samples,mismatches:mismatches,maxError:maxError,ground:groundSamples});
            check(session.runtime.spawnsByPlayer[1]>0,"unsafe prediction test actually executes the join's native gun");
            check(session.actors[0].unit.X==300,"join prediction and controls never move the host");
            session.link.send({type:"move-end",tick:session.runtime.tick});finish();
         }
      }
   }
}
