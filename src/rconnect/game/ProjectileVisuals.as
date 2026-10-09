package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   /** Pure display copies: no Bullet, collision, damage or ammunition changes. */
   public class ProjectileVisuals {
      private var seen:Dictionary=new Dictionary(true),active:Array=[],errors:Object={};
      private var pauseAt:int=-1;
      private var energyImpacts:EnergyImpactVisuals=new EnergyImpactVisuals();
      public function setPaused(value:Boolean):void {
         energyImpacts.setPaused(value);
         if(value==(pauseAt>=0))return;
         var now:int=getTimer();
         if(value)pauseAt=now;
         else {
            // Ordinary cosmetics use local elapsed time; native beam samples
            // retain real source timestamps and resume on their newest frame.
            for each(var a:Object in active)a.at=int(a.at)+now-Math.max(pauseAt,int(a.at));
            pauseAt=-1;
         }
      }
      public static function capture(b:Object):Object {
         if(b==null || GameBridge.probe(b,"vis")==null)return null;
         return {cls:getQualifiedClassName(b.vis),x:b.begx,y:b.begy,ex:b.X,ey:b.Y,
            dx:b.dx,dy:b.dy,ddy:b.ddy,rot:b.rot,vel:b.vel,spring:b.spring,
            ended:b.babah || !b.in_chain,blend:b.vis.blendMode};
      }
      /** Alicorn lightning is spring=1, not a laser beam. Reproduce its real
       * display trajectory/lifetime instead of the short endpoint approximation.
       * Keep ordinary bullet packets small; only these native effects need this. */
      public static function usesNativeFrames(b:Object):Boolean {
         if(Number(GameBridge.probe(b,"explRadius"))>0 || getQualifiedClassName(b)=="fe.weapon::PhisBullet")return true;
         if(int(GameBridge.probe(b,"spring"))>=2)return true;
         var v:Object=GameBridge.probe(b,"vis");
         if(v==null)return false;
         var cls:String=getQualifiedClassName(v);
         return cls=="visbullightning" || cls=="visbullightning2" || Number(GameBridge.probe(b,"flame"))>0
            || cls=="visbulflame" || cls=="visbulflame2" || cls=="visbuldflame";
      }
      /** Sample the native display after its real simulation frame. An effect
       * can finish before the next world packet; its final endpoint alone is
       * not enough to reconstruct its visible lifetime, path or muzzle. */
      public static function beamFrame(b:Object,stamp:int):Object {
         var v:DisplayObject=GameBridge.probe(b,"vis") as DisplayObject;
         if(v==null)return null;
         var laser:Object=GameBridge.probe(v,"laser");
         return {at:stamp,x:v.x,y:v.y,rot:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,
            f:v is MovieClip?MovieClip(v).currentFrame:1,v:v.visible && v.stage!=null,
            ls:laser==null?1:Number(laser.scaleX),lf:laser is MovieClip?MovieClip(laser).currentFrame:1};
      }
      public function receiveSpells(owner:Object,events:Array,main:Object,motion:RemoteMotion):void {
         energyImpacts.receive(owner,events,GameBridge.probe(owner,"loc"),main,0,100,motion);
      }
      public function receive(owner:Object,guns:Array,main:Object,player:Boolean=false,motion:RemoteMotion=null):void {
         if(owner==null || guns==null)return;
         var slots:Object=seen[owner];if(slots==null)slots=seen[owner]={};
         for each(var gun:Object in guns) {
            // A switched-away weapon moves to an effects-only list slot.
            // Its source stream still owns the same in-flight projectiles.
            var key:String=String(gun.id)+":"+String(gun.variant)+":"+String(gun.stream);
            var channel:Object=slots[key];
            var now:int=getTimer(),source:Number=Number(gun.sampleTime);
            if(!isFinite(source))source=now;
            if(channel==null)channel=slots[key]={last:0,records:{},offset:now-source};
            channel.offset=Math.min(Number(channel.offset),now-source);
            energyImpacts.receive(channel,gun.impacts as Array,GameBridge.probe(owner,"loc"),main,channel.offset,player?100:300,motion);
            var last:int=int(channel.last);
            for each(var event:Object in gun.events) {
               var existing:Object=channel.records[String(event.seq)];
               if(int(event.seq)<=last) {
                  if(existing!=null && existing.beam && event.flight!=null){existing.s=event.flight;existing.updated=now;}
                  continue;
               }
               last=int(event.seq);var s:Object=event.flight;if(s==null)continue;
               try {
                  var cls:Class=main.loaderInfo.applicationDomain.getDefinition(String(s.cls)) as Class;
                  var world:Object=GameBridge.probe(owner,"loc");
                  var grafon:Object=main.loaderInfo.applicationDomain.getDefinition("fe.World").w.grafon;
                  var layer:DisplayObjectContainer=grafon.visObjs[2] as DisplayObjectContainer;
                  if(layer==null)continue;
                  var initialTime:Number=motion!=null?motion.sourceTime:NaN;
                  if(!isFinite(initialTime))initialTime=now-Number(channel.offset)-(player?100:300);
                  var rec:Object={vis:null,cls:cls,s:s,at:now,loc:world,grafon:grafon,main:main,exploded:false,explosions:0,impacted:false,last:0,
                     beam:s.frames is Array,offset:channel.offset,delay:player?100:300,channel:channel,seq:event.seq,motion:motion,updated:now,
                     previousTime:initialTime,renderedBeam:false,recoveryPoint:null,recoveryAt:0,recoveryRenderedAt:-1};
                  channel.records[String(event.seq)]=rec;
                  if(!rec.beam)createVisual(rec);
                  active.push(rec);
                  if(rec.beam && motion!=null && (s.cls=="visbulflame" || s.cls=="visbulflame2" || s.cls=="visbuldflame")) {
                     rec.rateHeld=true;motion.retainRate(rec);
                  }
                  if(active.length>160)remove(0);
                  // Player muzzle animation is consumed by WeaponDisplay on
                  // the same buffered sample as gun identity, flip and aim.
               } catch(e:*) {if(!errors[String(s.cls)]){errors[String(s.cls)]=true;Log.d("RConnectGame: projectile visual "+s.cls+" failed: "+e);}}
            }
            channel.last=last;
         }
      }
      private function createVisual(a:Object):DisplayObject {
         var cls:Class=a.cls as Class,v:DisplayObject=new cls() as DisplayObject;
         if(v==null)return null;
         if(v is MovieClip){if(a.beam)MovieClip(v).gotoAndStop(1);else MovieClip(v).play();}
         v.blendMode=String(a.s.blend);v.rotation=Number(a.s.rot)*180/Math.PI;
         v.x=Number(a.s.x);v.y=Number(a.s.y);v.visible=true;
         a.grafon.visObjs[2].addChild(v);a.vis=v;return v;
      }
      public function tick(loc:Object,now:int=-1,finalFrame:Boolean=false):void {
         if(now<0)now=getTimer();
         if(pauseAt>=0)now=Math.min(now,pauseAt);
         energyImpacts.tick(loc,now,finalFrame);
         for(var i:int=active.length-1;i>=0;i--) {
            var a:Object=active[i],s:Object=a.s,v:DisplayObject=a.vis;
            var age:Number=Math.max(0,now-int(a.at))/1000,frames:Number=age*30;
            if(a.loc!==loc){remove(i);continue;}
            if(a.beam) {if(!tickBeam(a,now,finalFrame))remove(i);continue;}
            if(age>(s.ended?0.16:2.5) || v==null){remove(i);continue;}
            if(v.parent!==a.grafon.visObjs[2])a.grafon.visObjs[2].addChild(v);
            var x:Number=Number(s.x)+Number(s.dx)*frames;
            var y:Number=Number(s.y)+Number(s.dy)*frames+Number(s.ddy)*frames*frames/2;
            if(s.ended) {var p:Number=Math.min(1,age/0.08);x=Number(s.x)+(Number(s.ex)-Number(s.x))*p;y=Number(s.y)+(Number(s.ey)-Number(s.y))*p;}
            else {
               // Stop cosmetic projectiles at the first native solid tile too.
               var tile:Object=loc.getAbsTile(x,y);
               if(tile==null || (tile.phis==1 && x>=tile.phX1 && x<=tile.phX2 && y>=tile.phY1 && y<=tile.phY2)){remove(i);continue;}
            }
            v.x=x;v.y=y;
            var laser:Object=GameBridge.probe(v,"laser");
            if(laser!=null && int(s.spring)>=2)laser.scaleX=Math.sqrt((x-s.x)*(x-s.x)+(y-s.y)*(y-s.y))/100;
            else if(int(s.spring)==1 && Number(s.vel)>100)v.scaleX=Number(s.vel)/100;
            v.alpha=s.ended?Math.max(0,1-age/0.16):1;
         }
      }
      private function tickBeam(a:Object,now:int,finalFrame:Boolean):Boolean {
         var s:Object=a.s,list:Array=s.frames as Array,time:Number=a.motion!=null?a.motion.sourceTime:NaN;
         if(!isFinite(time))time=now-Number(a.offset)-Number(a.delay);
         var previousTime:Number=Number(a.previousTime);a.previousTime=time;
         if(!a.impacted && s.impact!=null && time>=Number(s.impact.at)) {
            a.impacted=true;BallisticImpactVisuals.play(a.main,a.loc,s.impact);
         }
         if(s.explosions is Array) {
            while(int(a.explosions)<s.explosions.length && time>=Number(s.explosions[int(a.explosions)].at)) {
               ProjectileExplosionVisuals.play(a.main,a.loc,s.explosions[int(a.explosions)]);a.explosions++;
            }
         } else if(!a.exploded&&s.explosion!=null&&time>=Number(s.explosion.at)) {
            a.exploded=true;ProjectileExplosionVisuals.play(a.main,a.loc,s.explosion);
         }
         if(now-int(a.updated)>15000)return false;
         var point:Object,next:Object=null,p:Object;
         if(int(s.end)>0 && time>=Number(s.end)) {
            // One slow display frame can cross a whole already-queued laser
            // pulse. Preserve one real native frame instead of silently losing
            // the shot. Never resurrect received history, an already rendered
            // pulse, a paused-world ending, or an old (>600ms) effect.
            if(a.recoveryPoint==null && !a.renderedBeam && int(s.spring)>=2 && pauseAt<0
               && isFinite(previousTime) && previousTime<Number(s.end) && time-Number(s.end)<=600) {
               for each(p in list)
                  if(Number(p.at)<Number(s.end) && p.v!==false && Number(p.a)>.05 && Number(p.ls)>0)
                     a.recoveryPoint=p;
               if(a.recoveryPoint!=null)a.recoveryAt=now;
            }
            if(a.recoveryPoint==null || pauseAt>=0 || now-int(a.recoveryAt)>250
               || int(a.recoveryRenderedAt)>=0 && now>int(a.recoveryRenderedAt))return false;
            point=a.recoveryPoint;
         } else {
            if(list==null || list.length==0 || time<Number(list[0].at))return true;
            point=list[0];
            for each(p in list){if(Number(p.at)>time){next=p;break;}point=p;}
         }
         var v:DisplayObject=a.vis as DisplayObject;if(v==null)v=createVisual(a);
         if(v==null)return false;
         if(v.parent!==a.grafon.visObjs[2])a.grafon.visObjs[2].addChild(v);
         if(v is MovieClip && MovieClip(v).currentFrame!=int(point.f))MovieClip(v).gotoAndStop(int(point.f));
         v.x=Number(point.x);v.y=Number(point.y);v.rotation=Number(point.rot);
         v.scaleX=Number(point.sx);v.scaleY=Number(point.sy);v.alpha=Number(point.a);v.visible=point.v!==false;
         // Interpolate only the received flight segment, never across an impact
         // pose, teleport or beam/flame's authored geometry. This removes a
         // repeated-frame/large-step cadence when display and source clocks differ.
         if(next!=null && point.v!==false && next.v!==false && int(s.spring)<2 && s.cls!="visbullightning" && s.cls!="visbullightning2"
            && s.cls!="visbulflame" && s.cls!="visbulflame2" && s.cls!="visbuldflame"
            && int(point.f)==int(next.f) && Number(point.sx)==Number(next.sx) && Number(point.sy)==Number(next.sy)) {
            var span:Number=Number(next.at)-Number(point.at);
            var t:Number=span>0?Math.max(0,Math.min(1,(time-Number(point.at))/span)):0;
            v.x+= (Number(next.x)-Number(point.x))*t;v.y+=(Number(next.y)-Number(point.y))*t;
            var angle:Number=(Number(next.rot)-Number(point.rot)+540)%360-180;
            v.rotation=Number(point.rot)+angle*t;
         }
         var laser:Object=GameBridge.probe(v,"laser");
         if(laser!=null){laser.scaleX=Number(point.ls);if(laser is MovieClip && MovieClip(laser).currentFrame!=int(point.lf))MovieClip(laser).gotoAndStop(int(point.lf));}
         if(finalFrame && v.visible && v.alpha>.05 && (laser==null || Number(point.ls)>0)) {
            a.renderedBeam=true;
            if(a.recoveryPoint!=null)a.recoveryRenderedAt=now;
         }
         return true;
      }
      private function remove(i:int):void {var a:Object=active[i],v:DisplayObject=a.vis;if(a.rateHeld && a.motion!=null)a.motion.releaseRate(a);if(v!=null && v.parent!=null)v.parent.removeChild(v);delete a.channel.records[String(a.seq)];active.splice(i,1);}
      public function forget(owner:Object):void {
         var slots:Object=seen[owner];if(slots==null)return;
         for(var i:int=active.length-1;i>=0;i--)
            for each(var channel:Object in slots)if(active[i].channel===channel){remove(i);break;}
         delete seen[owner];
      }
      public function reset():void {while(active.length)remove(active.length-1);seen=new Dictionary(true);energyImpacts.reset();}
      public function get count():int {return active.length;}
   }
}
