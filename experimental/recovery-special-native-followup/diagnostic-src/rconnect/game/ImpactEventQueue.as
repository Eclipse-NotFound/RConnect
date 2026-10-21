package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;

   /** An impact may arrive after its projectile was already removed, or after
    * a later shot. Keep its own identity, independent of flight presentation. */
   public class ImpactEventQueue {
      private var channels:Dictionary=new Dictionary(true),pending:Array=[];
      private var pauseAt:int=-1;
      // Diagnostic copy only. Disabled in normal operation; no hot-path I/O.
      private static var diagEnabled:Boolean=false,diagRows:Array=[],diagHead:int=0,diagDropped:int=0;
      private static var diagIds:Dictionary=new Dictionary(true),diagNext:int=0;
      public static function beginDiagnostics():void {
         diagRows=[];diagHead=diagDropped=diagNext=0;diagIds=new Dictionary(true);diagEnabled=true;
      }
      public static function endDiagnostics():Object {
         diagEnabled=false;
         return {rows:diagRows.slice(diagHead).concat(diagRows.slice(0,diagHead)),dropped:diagDropped};
      }
      private static function identity(o:Object):int {
         if(o==null)return 0;if(!diagIds[o])diagIds[o]=++diagNext;return int(diagIds[o]);
      }
      private static function partCount(loc:Object):int {
         var n:int=0,guard:int=0;
         for(var p:Object=GameBridge.probe(loc,"firstObj");p!=null&&guard++<10000;p=GameBridge.probe(p,"nobj"))
            if(getQualifiedClassName(p)=="fe.graph::Part")n++;
         return n;
      }
      private static function diagnostic(kind:String,a:Object,current:Object,now:int,extra:Object=null):Object {
         if(!diagEnabled)return null;
         var row:Object={kind:kind,actualNow:getTimer(),effectiveNow:now};
         try {
            row.sourceTime=ProjectileFrameStream.sourceTime(a.clock,now);row.eventAt=a.s.at;
            row.seq=a.seq;row.received=a.received;row.loc=identity(a.loc);row.currentLoc=identity(current);
            row.sameLoc=a.loc===current;row.locActive=GameBridge.probe(a.loc,"active");
            row.main=identity(a.main);row.mainClass=getQualifiedClassName(a.main);
            row.motion=identity(a.clock.motion);row.pauseAt=a.pauseAt;
            if(extra!=null)for(var key:String in extra)row[key]=extra[key];
            if(kind=="play-before" || kind=="play-after") {
               var ad:Object=a.main.loaderInfo.applicationDomain;
               var emitter:Object=ad.getDefinition("fe.graph.Emitter"),world:Object=ad.getDefinition("fe.World").w;
               var recipe:Object=emitter.arr.expl;
               row.parts=partCount(a.loc);row.kol2=emitter.kol2;row.maxParts=world.maxParts;
               if(extra!=null&&extra.partsBefore!=null)row.newParts=row.parts-Number(extra.partsBefore);
               row.worldLocSame=world.loc===a.loc;row.explExists=recipe!=null;
               row.explImp=recipe==null?null:recipe.imp;row.explMaxkol=recipe==null?null:recipe.maxkol;
            }
         }catch(diagnosticError:Error){row.diagnosticError=diagnosticError.message;}
         if(diagRows.length<128)diagRows.push(row);
         else{diagRows[diagHead]=row;diagHead=(diagHead+1)%128;diagDropped++;}
         return row;
      }
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
            if(diagEnabled&&explosion!=null&&!state.seen["explosion:"+String(event.seq)])
               diagnostic("receive",{s:explosion,clock:state,received:now,seq:event.seq,loc:loc,main:main,pauseAt:pauseAt},loc,now);
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
         if(diagEnabled&&kind=="explosion")pending[pending.length-1].seq=seq;
         if(pending.length>512) {
            if(diagEnabled&&pending[0].kind=="explosion")diagnostic("drop",pending[0],loc,now,{reason:"queue-capacity",pauseAt:pauseAt});
            pending.shift();
         }
      }
      public function tick(loc:Object,now:int):void {
         if(pauseAt>=0)now=Math.min(now,pauseAt);
         for(var i:int=pending.length-1;i>=0;i--) {
            var a:Object=pending[i],time:Number=ProjectileFrameStream.sourceTime(a.clock,now);
            if(a.loc!==loc || now-int(a.received)>15000){
               if(diagEnabled&&a.kind=="explosion")diagnostic("drop",a,loc,now,{reason:a.loc!==loc?"other-room":"expired",pauseAt:pauseAt});
               pending.splice(i,1);continue;
            }
            if(time<Number(a.s.at)) {
               if(diagEnabled&&a.kind=="explosion"&&(a.diagWaitAt==null||getTimer()-int(a.diagWaitAt)>=100)) {
                  a.diagWaitAt=getTimer();diagnostic("wait",a,loc,now,{pauseAt:pauseAt});
               }
               continue;
            }
            pending.splice(i,1);
            // A final-state packet can skip the entire short flight. Show its
            // confirmed impact once, but never revive a stale room's effects.
            if(time-Number(a.s.at)<=15000) {
               if(a.kind=="explosion") {
                  var beforeRow:Object=diagEnabled?diagnostic("play-before",a,loc,now,{pauseAt:pauseAt}):null;
                  // The real production invocation stays outside diagnostic
                  // error handling. Its exception, if any, still propagates.
                  ProjectileExplosionVisuals.play(a.main,a.loc,a.s);
                  if(diagEnabled)diagnostic("play-after",a,loc,now,{pauseAt:pauseAt,partsBefore:beforeRow==null?null:beforeRow.parts});
               }
               else BallisticImpactVisuals.play(a.main,a.loc,a.s);
            }
            else if(diagEnabled&&a.kind=="explosion")diagnostic("drop",a,loc,now,{reason:"source-too-late",pauseAt:pauseAt});
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
