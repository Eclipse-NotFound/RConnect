package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;

   /** An impact may arrive after its projectile was already removed, or after
    * a later shot. Keep its own identity, independent of flight presentation. */
   public class ImpactEventQueue {
      private var channels:Dictionary=new Dictionary(true),pending:Array=[];
      private var pauseAt:int=-1;
      public function receive(channel:Object,events:Array,loc:Object,main:Object,offset:Number,
         delay:Number,motion:RemoteMotion):void {
         if(channel==null || events==null || loc==null || main==null)return;
         var now:int=getTimer(),state:Object=channels[channel];
         if(state==null)state=channels[channel]={seen:{},order:[]};
         ProjectileFrameStream.receiveClock(state,motion,offset,delay,now);
         // Source events remain on the wire for 700 ms. Keep receipt identities
         // much longer, but bound their lifetime and avoid retaining the channel.
         while(state.order.length>0 && (now-int(state.order[0].at)>15000 || state.order.length>2048)) {
            delete state.seen[String(state.order.shift().key)];
         }
         for each(var event:Object in events) {
            if(event==null)continue;
            var hit:Object=event.impact!=null?event.impact:(event.flight==null?null:event.flight.impact);
            var explosion:Object=event.explosion!=null?event.explosion:(event.flight==null?null:event.flight.explosion);
            if(hit!=null && hit.groups is Array)
               enqueue(state,channel,event.seq,"hit",hit,loc,main,now);
            if(explosion!=null && isFinite(Number(explosion.x)) && isFinite(Number(explosion.y)))
               enqueue(state,channel,event.seq,"explosion",explosion,loc,main,now);
         }
      }
      private function enqueue(state:Object,channel:Object,seq:*,kind:String,s:Object,loc:Object,main:Object,now:int):void {
         if(!isFinite(Number(s.at)))return;
         // One shot may have both a ballistic impact and a real detonation.
         // Keep separate identities, but share the same bounded source clock.
         var key:String=kind+":"+String(seq);
         if(state.seen[key])return;
         state.seen[key]=true;state.order.push({key:key,at:now});
         // Matches recovery-detach's bounded channel retention. Its forget()
         // method must be preserved when this delta is merged on recovery05.
         pending.push({s:s,kind:kind,loc:loc,main:main,clock:state,received:now,channel:channel});
         if(pending.length>512)pending.shift();
      }
      public function tick(loc:Object,now:int):void {
         if(pauseAt>=0)now=Math.min(now,pauseAt);
         for(var i:int=pending.length-1;i>=0;i--) {
            var a:Object=pending[i],time:Number=ProjectileFrameStream.sourceTime(a.clock,now);
            if(a.loc!==loc || now-int(a.received)>15000){pending.splice(i,1);continue;}
            if(time<Number(a.s.at))continue;
            pending.splice(i,1);
            // A final-state packet can skip the entire short flight. Show its
            // confirmed impact once, but never revive a stale room's effects.
            if(time-Number(a.s.at)<=15000) {
               if(a.kind=="explosion")ProjectileExplosionVisuals.play(a.main,a.loc,a.s);
               else BallisticImpactVisuals.play(a.main,a.loc,a.s);
            }
         }
      }
      public function setPaused(value:Boolean):void {
         if(value==(pauseAt>=0))return;
         var now:int=getTimer();
         if(value)pauseAt=now;
         else {
            for each(var a:Object in pending) {
               var elapsed:int=now-Math.max(pauseAt,int(a.received));
               a.received=int(a.received)+elapsed;
            }
            for each(var state:Object in channels)ProjectileFrameStream.shiftClock(state,now-Math.max(pauseAt,int(state.clockAt)));
            pauseAt=-1;
         }
      }
      public function reset():void {channels=new Dictionary(true);pending=[];pauseAt=-1;}
   }
}
