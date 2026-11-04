package authority {
   /** Bounded replay of this player's unacknowledged movement intent. Packet
    * count is never simulation time: replay uses measured host step duration.
    * No native step/attack, inventory, enemy or collision mutation runs here. */
   public final class MovementPrediction {
      private var pending:Array=[],anchor:Object,frame:Object,held:Object;
      private var identity:String="",arrival:Number=0,stepMS:Number=1000/30,lastFrame:Object;
      public var applications:uint=0,resets:uint=0,corrections:uint=0;
      public var lead:Number=0,maxLead:Number=0,lastX:Number=NaN;
      public function record(input:Object,now:Number):void {
         var key:String=keyFor(input);
         if(identity!==key){clear();identity=key;}
         pending.push({seq:input.seq,at:now,buttons:input.buttons,
            safe:input.actions.length==0 && !input.pause && !input.pauseMenus && !input.pauseSats && (input.buttons&~3)==0});
         if(pending.length>64){clear();identity=key;}
      }
      public function confirm(value:Object,now:Number):void {
         held=null;
         var state:Object=value.players[1],key:String=keyFor(state);
         if(identity!==key){clear();identity=key;}
         if(lastFrame!=null && lastFrame.players[1].positionEpoch!=state.positionEpoch)clear();
         if(lastFrame!=null && value.tick>lastFrame.tick && value.time>lastFrame.time && !value.paused && !lastFrame.paused) {
            var sample:Number=(value.time-lastFrame.time)/(value.tick-lastFrame.tick);
            if(sample>=10 && sample<=200)stepMS=stepMS*.8+sample*.2;
         }
         lastFrame=value;frame=value;arrival=now;
         while(pending.length>0 && pending[0].seq<=state.ack)anchor=pending.shift();
         if(value.paused || state.motion==null){anchor=null;pending=[];++resets;}
      }
      private function keyFor(v:Object):String {return v.room+":"+v.roomEpoch+":"+v.epoch+":"+v.weaponEpoch;}
      public function clear():void {pending=[];anchor=null;frame=null;lastFrame=null;held=null;lastX=NaN;lead=0;++resets;}
      private function reject():Object {held=null;return null;}
      public function sample(now:Number,display:Object,terrainRevision:uint,localPause:Boolean):Object {
         lead=0;
         if(frame==null || anchor==null || !anchor.safe || localPause || frame.paused || display==null ||
            frame.room!==display.room || frame.pauseEpoch!=display.pauseEpoch ||
            frame.players[1].positionEpoch!=display.players[1].positionEpoch ||
            keyFor(frame.players[1])!==keyFor(display.players[1]) || frame.scene.terrainRevision!=terrainRevision)return reject();
         var source:Object=frame.players[1],motion:Object=source.motion;
         if(motion==null || keyFor(source)!==identity)return reject();
         for each(var input:Object in pending)if(!input.safe)return reject();
         // A late confirmation stops prediction, not the picture already shown.
         // Freeze only a safe sample from this exact confirmation: falling back
         // to delayed playback here visibly pulled the player/camera backwards.
         // No extra movement is simulated; all original identity, terrain,
         // pause and input checks above still invalidate the held picture.
         // The 150 ms hold boundary is a stated contract (BPredictChecks): widen
         // only the bounded lead inside this window, never the cutoff itself.
         if(now-arrival>150) {
            if(held!=null)lead=held.x-source.x;
            return held;
         }
         // Midpoint is an estimate, not a claim about synchronized process clocks.
         var base:Number=anchor.at+Math.max(0,arrival-anchor.at)*.5;
         // Five native steps of lead keeps the local avatar responsive when the
         // host publishes at 11-15 fps in dense combat. The host still owns every
         // authoritative correction: this only replays already-sent safe input.
         var elapsed:Number=Math.max(0,Math.min(150,stepMS*5,now-base)),time:Number=0,buttons:int=anchor.buttons,index:int=0;
         var remaining:Number=elapsed,moved:Object=motion;
         while(remaining>0) {
            var duration:Number=Math.min(stepMS,remaining),end:Number=base+time+duration;
            while(index<pending.length && pending[index].at<=end){buttons=pending[index].buttons;++index;}
            var next:Object=GroundMotion.advance(moved,buttons);if(next==null)return reject();
            if(duration<stepMS){next.x=moved.x+(next.x-moved.x)*duration/stepMS;}
            moved=next;remaining-=duration;time+=duration;
         }
         lead=moved.x-source.x;maxLead=Math.max(maxLead,Math.abs(lead));++applications;
         if(isFinite(lastX) && Math.abs(lastX-moved.x)>12)++corrections;lastX=moved.x;
         var out:Object=PoseTween.copy(source);out.x=moved.x;out.native=PoseTween.copy(source.native);
         // Keep confirmed velocity/action fields. Only the rendered location and
         // local camera/selection geometry follow this prediction.
         for each(var k:String in ["X","X1","X2","eyeX"])if(out.native[k] is Number)out.native[k]+=lead;
         out.visual=shift(source.visual,lead);
         if(source.weapon!=null){out.weapon=PoseTween.copy(source.weapon);out.weapon.x+=lead;out.weapon.visual=shift(source.weapon.visual,lead);}
         held=out;return out;
      }
      private function shift(value:Object,dx:Number):Object {
         if(value==null)return null;var out:Object=PoseTween.copy(value);out.x+=dx;
         if(value.m!=null){out.m=value.m.concat();out.m[4]+=dx;}return out;
      }
   }
}
