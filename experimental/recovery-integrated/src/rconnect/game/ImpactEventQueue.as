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
            delete state.seen[String(state.order.shift().seq)];
         }
         for each(var event:Object in events) {
            if(event==null)continue;
            var s:Object=event.impact!=null?event.impact:(event.flight==null?null:event.flight.impact);
            if(s==null)continue;
            var key:String=String(event.seq);
            if(state.seen[key] || !isFinite(Number(s.at)) || !(s.groups is Array))continue;
            state.seen[key]=true;state.order.push({seq:event.seq,at:now});
            // Retain the channel only while its bounded pending hit exists.
            // forget(owner) drops the weapon map; without this reference a
            // weak channel key could disappear before pause/resume shifts it.
            pending.push({s:s,loc:loc,main:main,clock:state,received:now,channel:channel});
            if(pending.length>512)pending.shift();
         }
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
            if(time-Number(a.s.at)<=15000)BallisticImpactVisuals.play(a.main,a.loc,a.s);
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
      public function forget(channel:Object,now:int):void {
         var state:Object=channels[channel];if(state==null)return;
         ProjectileFrameStream.detachClock(state,pauseAt>=0?Math.min(now,pauseAt):now);
      }
      public function reset():void {channels=new Dictionary(true);pending=[];pauseAt=-1;}
   }
}
