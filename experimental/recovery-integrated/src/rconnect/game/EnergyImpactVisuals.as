package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Records the real short-lived Part emitted by Bullet.popadalo. Receiving
    * creates display clips only; it cannot hit terrain, damage units or emit
    * another Part. In particular, bullet expiry is not evidence of an impact.
    *
    * Source: observeWeapon(w, stamp) each native frame, capture(w) in a gun
    * snapshot. Receiver: receive(channel, gun.impacts, ...), tick/setPaused/reset
    * alongside ProjectileVisuals. The source and receiver use separate instances.
    */
   public class EnergyImpactVisuals {
      // AllData 1.02's non-explosive impact emitters. Most are stationary;
      // the flame flare needs a fresh-particle match within its native jitter.
      private static const FLARES:Object={plasma:"flPlasma",plasma1:"flPlasma",plasma2:"flPlasma2",
         blump:"flLaser",laser:"flLaser",laser2:"flLaser2",laser3:"flPlasma2",
         spark:"flSpark",sparkl:"flSparkl",dray:"flDray",telebullet:"visualTeleFlare",ice:"visualIceFlare",
         plevok:"flPlevok",pinkplevok:"flPinkPlevok",bum:"visualBum",bumn:"visualBumNecro",buma:"visualBumAcid",
         flame:"visualFlame",arson:"visualFlame",flare:"visualFlare"};
      private static const CLIPS:Object={flPlasma:true,flPlasma2:true,flLaser:true,flLaser2:true,
         flSpark:true,flSparkl:true,flDray:true,visualTeleFlare:true,visualIceFlare:true,
         flPlevok:true,flPinkPlevok:true,visualBum:true,visualBumNecro:true,visualBumAcid:true,visualFlame:true,visualFlare:true};
      private static const RETAIN_MS:int=1000;
      private static const MAX_EVENTS:int=96;
      private var sources:Dictionary=new Dictionary(true);
      private var claimed:Dictionary=new Dictionary(true);
      private var checkedHits:Dictionary=new Dictionary(true);
      private var chainLoc:Object,chainStamp:int=-1,bullets:Dictionary=new Dictionary(true),parts:Object={};
      private var serial:int=0;
      private var channels:Dictionary=new Dictionary(true),active:Array=[],errors:Object={};
      private var pauseAt:int=-1;

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}

      /** Scan once per room/frame, including every pellet rather than weapon.b
       * (which is only the last projectile of native multi-shot weapons). */
      private function scan(loc:Object,stamp:int):void {
         if(loc===chainLoc && stamp==chainStamp)return;
         chainLoc=loc;chainStamp=stamp;bullets=new Dictionary(true);parts={};
         var o:Object=get(loc,"firstObj");
         for(var guard:int=0;o!=null && guard++<10000;o=get(o,"nobj")) {
            var cls:String=getQualifiedClassName(o);
            if(cls=="fe.graph::Part") {
               var v:DisplayObject=get(o,"vis") as DisplayObject;
               if(v==null)continue;
               cls=getQualifiedClassName(v);
               if(CLIPS[cls]===true && get(o,"in_chain")===true && Number(o.mliv)-Number(o.liv)<=1) {
                  // Only native particles born in this simulation step can be
                  // attributed to a newly ended bullet. Spatial buckets avoid
                  // each rapid-fire impact walking all room effects.
                  var cell:String=cls+":"+int(Math.floor(Number(o.X)/32))+":"+int(Math.floor(Number(o.Y)/32));
                  if(parts[cell]==null)parts[cell]=[];
                  parts[cell].push(o);
               }
            } else if(cls=="fe.weapon::Bullet" || cls=="fe.weapon::SmartBullet") {
               // PhisBullet overrides popadalo and never emits Bullet's flare.
               var w:Object=get(o,"weap");
               if(w!=null && FLARES[String(get(o,"flare"))]!=null && Number(get(o,"explRadius"))==0) {
                  if(bullets[w]==null)bullets[w]=[];
                  bullets[w].push(o);
               }
            }
         }
      }

      public function observeWeapon(w:Object,stamp:int):void {
         if(w==null || stamp<=0)return;
         // Ordinary bullets and melee swings do not need another chain scan.
         if(FLARES[String(get(w,"flare"))]==null && sources[w]==null)return;
         var loc:Object=get(w,"loc");
         if(loc==null)loc=get(get(w,"owner"),"loc");
         if(loc==null)return;
         var list:Array=sources[w] as Array;
         if(list==null)list=sources[w]=[];
         scan(loc,stamp);
         var candidates:Array=bullets[w] as Array;
         if(candidates!=null)for each(var b:Object in candidates) {
            if(get(b,"babah")!==true || checkedHits[b])continue;
            checkedHits[b]=true;
            // An expired bullet sharing coordinates with an older flash is
            // not a collision. The native Part alone does not establish it.
            if(get(b,"tilehit")!==true && !(get(b,"parr") is Array && b.parr.length>0))continue;
            var clip:String=String(FLARES[String(get(b,"flare"))]);
            var moving:Boolean=clip=="visualFlame";
            var nearest:Object=null,best:Number=Infinity;
            var cx:int=int(Math.floor(Number(b.X)/32)),cy:int=int(Math.floor(Number(b.Y)/32));
            for(var ix:int=cx-1;ix<=cx+1;ix++)for(var iy:int=cy-1;iy<=cy+1;iy++)
               for each(var candidate:Object in parts[clip+":"+ix+":"+iy]) {
                  if(claimed[candidate] || get(candidate,"in_chain")!==true)continue;
                  var dx:Number=Number(candidate.X)-Number(b.X),dy:Number=Number(candidate.Y)-Number(b.Y);
                  if(Math.abs(dx)>(moving?14:.01) || Math.abs(dy)>(moving?14:.01))continue;
                  var distance:Number=dx*dx+dy*dy;
                  if(distance<best){nearest=candidate;best=distance;}
               }
            if(nearest!=null) {
               // Bullet.popadalo emits exactly one flare. Multiple bullets at
               // the same point each claim one actual native particle.
               var p:Object=nearest;
               var record:Object={part:p,loc:loc,wire:{id:++serial,cls:clip,layer:int(get(p,"sloy")),
                  blend:String(p.vis.blendMode),frames:[],end:0}};
               // A weak-key value must not reference its own Part key: that
               // would retain expired particles after the replay window closes.
               claimed[p]=true;list.push(record);
            }
         }
         for each(record in list) {
            var wire:Object=record.wire;
            if(int(wire.end)>0)continue;
            p=record.part;
            if(get(p,"in_chain")!==true || get(p,"loc")!==record.loc) {wire.end=stamp;continue;}
            var visual:DisplayObject=get(p,"vis") as DisplayObject;
            if(visual==null) {wire.end=stamp;continue;}
            var color:ColorTransform=visual.transform.colorTransform;
            var point:Object={at:stamp,x:visual.x,y:visual.y,r:visual.rotation,sx:visual.scaleX,sy:visual.scaleY,
               a:visual.alpha,f:visual is MovieClip?MovieClip(visual).currentFrame:1,v:visual.visible,
               c:[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,
                  color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset]};
            var frames:Array=wire.frames as Array;
            if(frames.length>0 && Number(frames[frames.length-1].at)==stamp)frames[frames.length-1]=point;
            else frames.push(point);
            if(frames.length>64)frames.shift();
         }
         for(var i:int=list.length-1;i>=0;i--)
            if(int(list[i].wire.end)>0 && stamp-int(list[i].wire.end)>RETAIN_MS)list.splice(i,1);
         while(list.length>MAX_EVENTS)list.shift();
      }

      public function capture(w:Object):Array {
         var out:Array=[],list:Array=sources[w] as Array;
         if(list!=null)for each(var record:Object in list)if(record.wire.frames.length>0)out.push(record.wire);
         return out;
      }
      public function hasPending(w:Object):Boolean {
         var list:Array=sources[w] as Array;return list!=null && list.length>0;
      }

      /** Frequent effects packets carry only new/revised native samples; the
       * ordinary capture remains cumulative for recovery. */
      public function captureDelta(w:Object):Array {
         var out:Array=[],list:Array=sources[w] as Array;
         if(list==null)return out;
         for each(var record:Object in list) {
            var wire:Object=record.wire,all:Array=wire.frames as Array;
            if(all==null || all.length==0)continue;
            var points:Array=ProjectileFrameStream.after(all,record.fastAt==null?Number.NEGATIVE_INFINITY:Number(record.fastAt));
            if(record.fastPoint!=null)for each(var revised:Object in all)
               if(Number(revised.at)==Number(record.fastAt) && !ProjectileFrameStream.samePoint(revised,record.fastPoint)) {points.unshift(revised);break;}
            var ending:Boolean=int(wire.end)>0 && int(record.fastEnd)!=int(wire.end);
            if(points.length==0 && !ending)continue;
            // A terminal-only packet still supplies one known pose, allowing
            // a missed initial packet to recover without inventing artwork.
            if(points.length==0)points.push(all[all.length-1]);
            out.push({id:wire.id,cls:wire.cls,layer:wire.layer,blend:wire.blend,frames:points,end:wire.end,delta:true});
            record.fastPoint=points[points.length-1];record.fastAt=record.fastPoint.at;record.fastEnd=wire.end;
         }
         return out;
      }

      /** channel is the same per-weapon stream identity as ProjectileVisuals.
       * This must run even when no new shot sequence arrives: a hit normally
       * happens after the shot was first sent, and may outlive its bullet. */
      public function receive(channel:Object,events:Array,loc:Object,main:Object,offset:Number,delay:Number,
         motion:RemoteMotion=null):void {
         if(channel==null || events==null || loc==null || main==null)return;
         var state:Object=channels[channel];
         if(state==null)state=channels[channel]={last:0,records:{}};
         var last:int=int(state.last),now:int=getTimer();
         for each(var s:Object in events) {
            if(s==null || CLIPS[String(s.cls)]!==true || !(s.frames is Array) || s.frames.length==0)continue;
            var id:int=int(s.id),a:Object=state.records[String(id)];
            if(a!=null) {
               var old:Array=a.s.frames as Array,fresh:Array=s.frames as Array;
               if(Number(fresh[fresh.length-1].at)>=Number(old[old.length-1].at) && !(int(a.s.end)>0 && int(s.end)==0)) {
                  var merged:Object={};for(var field:String in s)merged[field]=s[field];
                  merged.frames=ProjectileFrameStream.merge(old,fresh);a.s=merged;
               }
               ProjectileFrameStream.receiveClock(a,motion,offset,delay,now);a.updated=now;continue;
            }
            if(id<=last)continue;
            last=id;
            a={s:s,loc:loc,main:main,vis:null,offset:offset,delay:delay,motion:motion,updated:now,
               state:state,id:id,shown:null,shownAt:-1};
            ProjectileFrameStream.receiveClock(a,motion,offset,delay,now);
            state.records[String(id)]=a;active.push(a);
            if(active.length>256)remove(0);
         }
         state.last=last;
      }

      public function tick(loc:Object,now:int=-1):void {
         if(now<0)now=getTimer();
         if(pauseAt>=0)now=Math.min(now,pauseAt);
         for(var i:int=active.length-1;i>=0;i--) {
            var a:Object=active[i],s:Object=a.s;
            if(a.loc!==loc) {remove(i);continue;}
            var time:Number=ProjectileFrameStream.sourceTime(a,now);
            var ended:Boolean=int(s.end)>0 && time>=Number(s.end);
            // Do not replay stale history after a long stall. The ordinary
            // stale-stream limit also covers events whose ending never arrives.
            if((ended && time-Number(s.end)>RETAIN_MS) || now-int(a.updated)>15000) {remove(i);continue;}
            var frames:Array=s.frames as Array;
            if(time<Number(frames[0].at))continue;
            var point:Object=frames[0];
            for each(var p:Object in frames) {if(Number(p.at)>time)break;point=p;}
            if(ended) {
               // A 67ms flash can fall entirely between two display frames.
               // Show its real first pose once, then only its final known pose
               // if different. Never enqueue every skipped 19ms sample.
               var finalPoint:Object=frames[frames.length-1];
               if(a.shown==null)point=frames[0];
               // GameBridge ticks at ENTER_FRAME and RENDER with the same
               // presentationTime. A second call is not a rendered frame.
               else if(now<=int(a.shownAt))point=a.shown;
               else if(!samePose(a.shown,finalPoint))point=finalPoint;
               else {remove(i);continue;}
            }
            try {
               var world:Object=a.main.loaderInfo.applicationDomain.getDefinition("fe.World").w;
               var layer:DisplayObjectContainer=world.grafon.visObjs[Math.max(0,Math.min(4,int(s.layer)))] as DisplayObjectContainer;
               if(layer==null)continue;
               var v:MovieClip=a.vis as MovieClip;
               if(v==null) {
                  var cls:Class=a.main.loaderInfo.applicationDomain.getDefinition(String(s.cls)) as Class;
                  v=new cls() as MovieClip;
                  if(v==null) {remove(i);continue;}
                  a.vis=v;v.stop();v.blendMode=String(s.blend);
               }
               if(v.parent!==layer)layer.addChild(v);
               if(v.currentFrame!=int(point.f))v.gotoAndStop(Math.max(1,Math.min(v.totalFrames,int(point.f))));
               v.x=Number(point.x);v.y=Number(point.y);v.rotation=Number(point.r);
               v.scaleX=Number(point.sx);v.scaleY=Number(point.sy);v.alpha=Number(point.a);v.visible=point.v===true;
               var c:Array=point.c as Array;
               if(c!=null && c.length==8)v.transform.colorTransform=new ColorTransform(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7]);
               a.shown=point;a.shownAt=Math.max(int(a.shownAt),now);
            } catch(e:*) {
               if(!errors[String(s.cls)]) {errors[String(s.cls)]=true;Log.d("RConnectGame: energy impact "+s.cls+" failed: "+e);}
               remove(i);
            }
         }
      }

      /** Repeated source samples with identical artwork do not earn an extra
       * recovery frame. Timestamp is intentionally not a visual property. */
      private static function samePose(a:Object,b:Object):Boolean {
         if(a==null || b==null)return false;
         for each(var key:String in ["x","y","r","sx","sy","a","f","v"])
            if(a[key]!==b[key])return false;
         var ca:Array=a.c as Array,cb:Array=b.c as Array;
         if(ca==null || cb==null)return ca==null && cb==null;
         if(ca.length!=cb.length)return false;
         for(var i:int=0;i<ca.length;i++)if(ca[i]!==cb[i])return false;
         return true;
      }

      public function setPaused(value:Boolean):void {
         if(value==(pauseAt>=0))return;
         var now:int=getTimer();
         if(value)pauseAt=now;
         else {
            for each(var a:Object in active)ProjectileFrameStream.shiftClock(a,now-Math.max(pauseAt,int(a.clockAt)));
            pauseAt=-1;
         }
      }
      private function remove(index:int):void {
         var a:Object=active[index],v:DisplayObject=a.vis as DisplayObject;
         if(v!=null && v.parent!=null)v.parent.removeChild(v);
         delete a.state.records[String(a.id)];active.splice(index,1);
      }
      public function reset():void {
         while(active.length>0)remove(active.length-1);
         channels=new Dictionary(true);sources=new Dictionary(true);claimed=new Dictionary(true);checkedHits=new Dictionary(true);
         chainLoc=null;chainStamp=-1;bullets=new Dictionary(true);parts={};
      }
      public function get count():int {return active.length;}
   }
}
