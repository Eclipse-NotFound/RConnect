package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Native Q/alicorn teleport presentation, never another teleport simulation.
    * The two observation calls bracket UnitPlayer's real control/step. A release
    * or a coordinate jump alone is not success: require a new native visualTele
    * at the requested landing point. Wire events survive several snapshots.
    * Receive/tick follows the same source clock as the peer and its weapon.
    */
   public class TeleportVisuals {
      private static const RETAIN_MS:int=1500;
      private static const MAX_EVENTS:int=16;
      private var sources:Dictionary=new Dictionary(true);
      private var streamSerial:int=0;
      private var channels:Object={};
      private var active:Array=[];
      private var paused:Boolean=false;
      private var pauseAt:int=-1;
      private var errors:Object={};

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function arrival(p:Object):Boolean {
         return getQualifiedClassName(p)=="fe.graph::Part" &&
            get(p,"in_chain")===true && getQualifiedClassName(get(p,"vis"))=="visualTele";
      }
      private function source(u:Object):Object {
         var r:Object=sources[u];
         if(r==null)r=sources[u]={stream:++streamSerial,seq:0,events:[],before:null,stamp:0};
         return r;
      }

      /** Before native World.step; call after any input injection in tests.
       * A chain scan is needed only on a possible cast/release frame, rather
       * than for every unit or during ordinary walking. Native portTime/mana/
       * collision/visibility rules still run in UnitPlayer without intervention.
       */
      public function beforeNativeStep(u:Object,world:Object,stamp:int,roomKey:String,epoch:int):void {
         if(u==null || world==null)return;
         var r:Object=source(u),ctr:Object=get(u,"ctr"),loc:Object=get(u,"loc");
         r.before=null;
         if(paused || int(get(world,"allStat"))!=1 || loc==null || get(loc,"active")!==true)return;
         var released:Boolean=Number(get(u,"t_port"))>0 && get(ctr,"keyTele")!==true;
         var alicorn:Boolean=get(world,"alicorn")===true && get(ctr,"keyPunch")===true;
         if(!released && !alicorn)return;
         var seen:Dictionary=new Dictionary(true),p:Object=get(loc,"firstObj");
         for(var guard:int=0;p!=null && guard++<16384;p=get(p,"nobj"))if(arrival(p))seen[p]=true;
         var x:Number=Number(get(u,"X")),y:Number=Number(get(u,"Y"));
         var scX:Number=Number(get(u,"scX")),scY:Number=Number(get(u,"scY"));
         var aimX:Number=Number(get(world,"celX")),aimY:Number=Number(get(world,"celY"));
         if(!isFinite(x+y+scX+scY+aimX+aimY) || scX<=0 || scY<=0)return;
         // World.tileX/tileY are both 40 in the supported 1.02 native contract.
         r.before={loc:loc,seen:seen,x:x,y:y,scX:scX,scY:scY,
            wantedX:Math.round(aimX/40)*40,wantedY:Math.round(aimY/40+1)*40-1,
            at:stamp,roomKey:roomKey,roomEpoch:epoch};
      }

      /** After native step, before receive-side cosmetic emitters are ticked. */
      public function observe(u:Object,stamp:int,roomKey:String,epoch:int):void {
         if(u==null)return;
         var r:Object=source(u),before:Object=r.before;r.before=null;r.stamp=stamp;
         for(var i:int=r.events.length-1;i>=0;i--)
            if(stamp-Number(r.events[i].at)>RETAIN_MS)r.events.splice(i,1);
         if(before==null || int(before.at)!=stamp || before.loc!==get(u,"loc") ||
            before.roomKey!=roomKey || int(before.roomEpoch)!=epoch)return;
         var loc:Object=before.loc,p:Object=get(loc,"firstObj"),marker:Object;
         for(var guard:int=0;p!=null && guard++<16384;p=get(p,"nobj")) {
            if(!arrival(p) || before.seen[p]===true)continue;
            if(Math.abs(Number(get(p,"X"))-Number(before.wantedX))>.01 ||
               Math.abs(Number(get(p,"Y"))-(Number(before.wantedY)-Number(before.scY)/2))>.01)continue;
            marker=p;break;
         }
         if(marker==null)return;
         var x:Number=Number(get(u,"X")),y:Number=Number(get(u,"Y"));
         // Unit.run follows control/teleport. The observed player must actually
         // be at the requested destination, allowing its small native movement.
         if(!isFinite(x+y) || Math.abs(x-Number(before.wantedX))>12 ||
            Math.abs(y-Number(before.wantedY))>12)return;
         r.events.push({seq:++r.seq,at:stamp,fromX:before.x,fromY:before.y,
            toX:Number(get(marker,"X")),toY:Number(get(marker,"Y"))+Number(before.scY)/2,
            postX:x,postY:y,scX:before.scX,scY:before.scY,roomKey:roomKey,roomEpoch:epoch});
         while(r.events.length>MAX_EVENTS)r.events.shift();
      }

      public function capture(u:Object):Object {
         if(u==null)return null;
         var r:Object=sources[u];
         return r==null?null:{stream:r.stream,sampleTime:r.stamp,events:r.events.concat()};
      }

      /** A peer id remains stable when its native ghost is restyled/recreated.
       * Thus recreation and repeated world broadcasts cannot replay a cast.
       * Off-room events advance the high-water mark without producing visuals.
       */
      public function receive(id:int,state:Object,loc:Object,main:Object,motion:RemoteMotion,
         roomKey:String,epoch:int):void {
         if(state==null || !(state.events is Array) || !isFinite(Number(state.sampleTime)) || loc==null || main==null)return;
         var stream:int=int(state.stream);if(stream<=0)return;
         var c:Object=channels[String(id)];
         if(c!=null && stream<int(c.stream))return;
         if(c==null || int(c.stream)!=stream) {
            removePeer(id,true);c=channels[String(id)]={stream:stream,last:0};
         }
         var now:int=getTimer(),offset:Number=now-Number(state.sampleTime);
         for each(var e:Object in state.events) {
            if(!valid(e) || int(e.seq)<=int(c.last))continue;
            c.last=int(e.seq);
            if(String(e.roomKey)!=roomKey || int(e.roomEpoch)!=epoch)continue;
            active.push({id:id,state:e,loc:loc,main:main,motion:motion,offset:offset,
               born:now,played:false,parts:[],stopped:new Dictionary(true)});
            if(active.length>64)remove(0);
         }
      }

      private static function valid(e:Object):Boolean {
         if(e==null || int(e.seq)<=0 || !isFinite(Number(e.at)))return false;
         for each(var k:String in ["fromX","fromY","toX","toY","postX","postY","scX","scY"])
            if(e[k]==null || !isFinite(Number(e[k])))return false;
         return Number(e.scX)>0 && Number(e.scY)>0 && Number(e.scX)<=1000 && Number(e.scY)<=1000;
      }

      /** Consume an off-room player's current event numbers without queuing
       * visuals. Returning to its room must not resurrect a recently buffered
       * cast. Call before the room-mismatch early return in updateRemote. */
      public function discard(id:int,state:Object):void {
         clearPeerEffects(id);
         if(state==null || !(state.events is Array) || int(state.stream)<=0)return;
         var c:Object=channels[String(id)],stream:int=int(state.stream);
         if(c!=null && stream<int(c.stream))return;
         if(c==null || int(c.stream)!=stream)c=channels[String(id)]={stream:stream,last:0};
         for each(var e:Object in state.events)if(valid(e))c.last=Math.max(int(c.last),int(e.seq));
      }

      public function tick(loc:Object,now:int=-1,roomKey:String=null,epoch:int=-1):void {
         if(now<0)now=getTimer();
         for(var i:int=active.length-1;i>=0;i--) {
            var a:Object=active[i];
            if(a.loc!==loc || (roomKey!=null && String(a.state.roomKey)!=roomKey) ||
               (epoch>=0 && int(a.state.roomEpoch)!=epoch) || (!paused && now-int(a.born)>15000)) {remove(i);continue;}
            if(!a.played) {
               var time:Number=a.motion==null?NaN:a.motion.sourceTime;
               if(!isFinite(time))time=(paused?Math.min(now,pauseAt):now)-Number(a.offset)-100;
               if(time<Number(a.state.at))continue;
               try {play(a);a.played=true;}
               catch(err:*) {
                  if(!errors[String(a.id)]) {errors[String(a.id)]=true;Log.d("RConnectGame: teleport visual failed: "+err);}
                  remove(i);continue;
               }
            }
            var alive:Boolean=false;
            for each(var p:Object in a.parts)if(get(p,"in_chain")===true && get(p,"loc")===a.loc) {
               alive=true;
               var v:DisplayObject=get(p,"vis") as DisplayObject;
               if(v!=null && v.stage!==get(a.main,"stage"))p.addVisual();
               pausePart(a,p,paused);
            }
            if(a.played && !alive)remove(i);
         }
      }

      private function play(a:Object):void {
         var e:Object=a.state,loc:Object=a.loc,tail:Object=get(loc,"lastObj");
         var emitter:Object=a.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         try {
            emitter.emit("tele",loc,Number(e.fromX),Number(e.fromY)-Number(e.scY)/2,
               {rx:Number(e.scX),ry:Number(e.scY),kol:30});
            emitter.emit("teleport",loc,Number(e.toX),Number(e.toY)-Number(e.scY)/2);
         } finally {
            // Only the cosmetic Parts made by these synchronous emits are ours.
            // Tracking them permits immediate teardown on leave/endSession,
            // including a paused world whose native Part lifetime cannot elapse.
            var p:Object=tail==null?get(loc,"firstObj"):get(tail,"nobj");
            for(var guard:int=0;p!=null && guard++<64;p=get(p,"nobj")) {
               if(getQualifiedClassName(p)=="fe.graph::Part") {
                  a.parts.push(p);pausePart(a,p,paused);
               }
            }
         }
         // Sound is not part of this visual replay. Do not call Unit.teleport,
         // change mana, drop held objects, settle damage or move the camera.
      }

      private function pausePart(a:Object,p:Object,value:Boolean):void {
         var v:MovieClip=get(p,"vis") as MovieClip;
         if(v==null)return;
         if(value) {
            if(a.stopped[v]==null) {a.stopped[v]=v.isPlaying;v.stop();}
         } else if(a.stopped[v]!=null) {
            if(a.stopped[v]===true)v.play();delete a.stopped[v];
         }
      }
      public function setPaused(value:Boolean):void {
         if(value==paused)return;
         var now:int=getTimer();
         if(value)pauseAt=now;
         else {
            for each(var pending:Object in active) {
               var elapsed:int=now-Math.max(pauseAt,int(pending.born));
               pending.born=int(pending.born)+elapsed;
               pending.offset=Number(pending.offset)+elapsed;
            }
            pauseAt=-1;
         }
         paused=value;
         for each(var a:Object in active)for each(var p:Object in a.parts)
            if(get(p,"in_chain")===true)pausePart(a,p,value);
      }
      private function remove(index:int):void {
         var a:Object=active[index];
         for each(var p:Object in a.parts)if(get(p,"in_chain")===true && get(p,"loc")===a.loc)
            try {p.setNull();}catch(err:*) {}
         active.splice(index,1);
      }
      public function clearPeerEffects(id:int):void {
         for(var i:int=active.length-1;i>=0;i--)if(int(active[i].id)==id)remove(i);
      }
      /** Ghost removal is also used during native body recreation. Preserve
       * event high-water marks by default so its next repeated snapshot cannot
       * replay a cast. Session reset forgets all; a genuinely new source stream
       * explicitly forgets this id before its first event is accepted. */
      public function removePeer(id:int,forget:Boolean=false):void {
         clearPeerEffects(id);
         if(forget)delete channels[String(id)];
      }
      public function reset():void {
         while(active.length>0)remove(active.length-1);
         channels={};sources=new Dictionary(true);paused=false;pauseAt=-1;errors={};
         // Do not reuse stream ids within this helper's lifetime.
      }
      public function get count():int {return active.length;}

      /** Return a positional segment split by actual native teleport events.
       * No history/state mutation. Ordinary intervals return null. The caller
       * selects snapshot before/after for pose and weapons, bypasses its cubic
       * curve for x/y, and retains its existing cursor/delay. Multiple casts in
       * one network interval keep each real departure/arrival discontinuity.
       */
      public static function split(a:Object,b:Object,time:Number):Object {
         if(a==null || b==null || b.port==null || !(b.port.events is Array))return null;
         var first:Number=Number(a.sampleTime),last:Number=Number(b.sampleTime);
         if(!isFinite(first+last+time) || last<=first)return null;
         var x0:Number=Number(a.x),y0:Number=Number(a.y),x1:Number=Number(b.x),y1:Number=Number(b.y);
         var t0:Number=first,t1:Number=last,found:Boolean=false,after:Boolean=false,edge:Number=NaN;
         for each(var e:Object in b.port.events) {
            if(!valid(e) || Number(e.at)<=first || Number(e.at)>last ||
               String(e.roomKey)!=String(b.roomKey) || int(e.roomEpoch)!=int(b.roomEpoch))continue;
            found=true;edge=Number(e.at);
            if(time<Number(e.at)) {x1=Number(e.fromX);y1=Number(e.fromY);t1=Number(e.at);break;}
            x0=Number(e.postX);y0=Number(e.postY);t0=Number(e.at);after=true;
         }
         if(!found)return null;
         var t:Number=t1>t0?Math.max(0,Math.min(1,(time-t0)/(t1-t0))):1;
         return {x:x0+(x1-x0)*t,y:y0+(y1-y0)*t,after:after,at:edge,snapshot:after?b:a};
      }
   }
}
