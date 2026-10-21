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
            pending.push({s:s,loc:loc,main:main,offset:offset,delay:delay,motion:motion,received:now});
            if(pending.length>512)pending.shift();
         }
      }
      public function tick(loc:Object,now:int):void {
         if(pauseAt>=0)now=Math.min(now,pauseAt);
         for(var i:int=pending.length-1;i>=0;i--) {
            var a:Object=pending[i],time:Number=a.motion==null?NaN:a.motion.sourceTime;
            if(a.loc!==loc || now-int(a.received)>15000){pending.splice(i,1);continue;}
            if(!isFinite(time))time=now-Number(a.offset)-Number(a.delay);
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
               a.offset=Number(a.offset)+elapsed;a.received=int(a.received)+elapsed;
            }
            pauseAt=-1;
         }
      }
      public function reset():void {channels=new Dictionary(true);pending=[];pauseAt=-1;}
   }
}
