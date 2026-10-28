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
      // AllData 1.02's non-explosive energy impact emitters. These clips have no
      // random displacement or motion. Flame and actual explosions are separate.
      private static const FLARES:Object={plasma:"flPlasma",plasma1:"flPlasma",plasma2:"flPlasma2",
         blump:"flLaser",laser:"flLaser",laser2:"flLaser2",laser3:"flPlasma2",
         spark:"flSpark",sparkl:"flSparkl",dray:"flDray",telebullet:"visualTeleFlare",ice:"visualIceFlare"};
      private static const CLIPS:Object={flPlasma:true,flPlasma2:true,flLaser:true,flLaser2:true,
         flSpark:true,flSparkl:true,flDray:true,visualTeleFlare:true,visualIceFlare:true};
      private static const RETAIN_MS:int=1000;
      private static const MAX_EVENTS:int=96;
      private var sources:Dictionary=new Dictionary(true);
      private var claimed:Dictionary=new Dictionary(true);
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
               if(CLIPS[cls]===true) {
                  if(parts[cls]==null)parts[cls]=[];
                  parts[cls].push(o);
               }
            } else if(cls=="fe.weapon::Bullet" || cls=="fe.weapon::SmartBullet" || cls=="fe.weapon::PhisBullet") {
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
            if(get(b,"babah")!==true)continue;
            var clip:String=String(FLARES[String(get(b,"flare"))]);
            var available:Array=parts[clip] as Array;
            if(available==null)continue;
            for each(var p:Object in available) {
               if(claimed[p]!=null || get(p,"in_chain")!==true)continue;
               // These native emitters do not jitter their position. Require a
               // real matching Part, not simply an ended projectile at a wall.
               if(Math.abs(Number(get(p,"X"))-Number(get(b,"X")))>.01 ||
                  Math.abs(Number(get(p,"Y"))-Number(get(b,"Y")))>.01)continue;
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
               if(Number(fresh[fresh.length-1].at)>=Number(old[old.length-1].at) && !(int(a.s.end)>0 && int(s.end)==0))a.s=s;
               a.offset=offset;a.updated=now;continue;
            }
            if(id<=last)continue;
            last=id;
            a={s:s,loc:loc,main:main,vis:null,offset:offset,delay:delay,motion:motion,updated:now,
               state:state,id:id,shown:null,shownAt:-1};
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
            var time:Number=a.motion!=null?a.motion.sourceTime:NaN;
            if(!isFinite(time))time=now-Number(a.offset)-Number(a.delay);
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
         pauseAt=value?getTimer():-1;
      }
      private function remove(index:int):void {
         var a:Object=active[index],v:DisplayObject=a.vis as DisplayObject;
         if(v!=null && v.parent!=null)v.parent.removeChild(v);
         delete a.state.records[String(a.id)];active.splice(index,1);
      }
      public function reset():void {
         while(active.length>0)remove(active.length-1);
         channels=new Dictionary(true);sources=new Dictionary(true);claimed=new Dictionary(true);
         chainLoc=null;chainStamp=-1;bullets=new Dictionary(true);parts={};
      }
      public function get count():int {return active.length;}
   }
}
