package rconnect.game
{
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import fe.unit.Unit;
   import fe.weapon.Bullet;
   import fe.unit.RConnectAnimationAccess;

   /** Plays native display objects without Weapon.step/actions or Unit.die.
    * Those methods also create bullets, loot, XP and scripts on a second world. */
   public class UnitPresentation
   {
      private var states:Dictionary = new Dictionary();
      private var hostShots:Dictionary = new Dictionary(true);
      private var errors:Object = {};
      private var shotStream:int=0;
      private var frameTime:int=0;
      private var scannedAt:int=-1,scannedLoc:Object;
      private var frameBullets:Dictionary=new Dictionary(true);
      private var telekinesis:TelekinesisVisuals=new TelekinesisVisuals();
      private var energyImpacts:EnergyImpactVisuals=new EnergyImpactVisuals();
      private var melee:MeleeVisuals=new MeleeVisuals();
      private var burning:BurnVisuals=new BurnVisuals();

      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}

      private function weaponList(u:Object):Array
      {
         var children:Array=get(u,"childObjs") as Array;
         var list:Array=children==null?[]:children.concat();
         var current:Object=get(u,"currentWeapon");
         if(current!=null && list.indexOf(current)<0) list.push(current);
         var thrown:Object=get(u,"throwWeapon");
         if(thrown!=null && list.indexOf(thrown)<0)list.push(thrown);
         var magic:Object=get(u,"magicWeapon");
         if(magic!=null && list.indexOf(magic)<0)list.push(magic);
         // Changing guns must not orphan the previous gun's flying grenade,
         // missile or final impact. These entries carry effects only.
         for(var previous:Object in hostShots)
            if(get(previous,"owner")===u && get(previous,"loc")===get(u,"loc")
               && hostShots[previous].events.length>0 && list.indexOf(previous)<0)list.push(previous);
         return list;
      }

      /** A shotgun/burst leaves only its final bullet in Weapon.b. Index the
       * native chain once per frame, rather than scanning it once per gun. */
      private function scanBullets(loc:Object,stamp:int):void {
         if(loc===scannedLoc&&stamp==scannedAt)return;
         scannedLoc=loc;scannedAt=stamp;frameBullets=new Dictionary(true);
         var o:Object=get(loc,"firstObj");
         for(var guard:int=0;o!=null&&guard++<16384;o=get(o,"nobj")) {
            if(!(o is Bullet))continue;
            var w:Object=get(o,"weap");if(w==null)continue;
            if(frameBullets[w]==null)frameBullets[w]=[];
            frameBullets[w].push(o);
         }
      }

      /** kol_shoot resets when a burst ends. Observe every game frame and
       * retain our own event count, including bullets fired between snapshots. */
      public function observe(loc:Object,stamp:int=0):void
      {
         frameTime=stamp>0?stamp:getTimer();
         scanBullets(loc,frameTime);
         var units:Array=get(loc,"units") as Array;if(units==null) return;
         for each(var u:Object in units)
         {
            if(int(get(u,"fraction"))>=100) continue;
            if(int(get(u,"sost"))<3)RConnectAnimationAccess.observe(u as Unit);
            // A dead shooter can still have a beam fading in the native chain.
            // Its final display frames and end must reach the receiver too.
            for each(var w:Object in weaponList(u)) if(get(w,"kol_shoot")!=null) observeWeapon(w,frameTime);
         }
      }

      public function observePlayer(u:Object,stamp:int=0):void {frameTime=stamp>0?stamp:getTimer();scanBullets(get(u,"loc"),frameTime);for each(var w:Object in weaponList(u))if(get(w,"kol_shoot")!=null)observeWeapon(w,frameTime,true);}

      /** Refresh already-observed NPC clips after Flash advances frame scripts.
       * Reuse the chain index; no second unit/weapon discovery or AI step. */
      public function observeFinal(loc:Object,stamp:int):void {
         if(loc==null || stamp<=0)return;
         frameTime=stamp;
         for(var w:Object in hostShots) {
            var owner:Object=get(w,"owner");
            if(get(owner,"loc")===loc && int(get(owner,"fraction"))<100)observeWeapon(w,stamp);
         }
      }

      private function observeWeapon(w:Object,stamp:int=0,player:Boolean=false):int
      {
         if(stamp>0){MeleeVisuals.observe(get(w,"owner"),w,stamp);energyImpacts.observeWeapon(w,stamp);}
         var n:int=int(get(w,"kol_shoot")),bullet:Object=get(w,"b"),ammo:Number=Number(get(w,"hold"));
         var r:Object=hostShots[w];
         if(r==null){
            r=hostShots[w]={stream:++shotStream,n:n,bullet:bullet,ammo:ammo,total:0,serial:0,events:[],seen:new Dictionary(true)};
            if(bullet!=null && get(bullet,"in_chain")!=true && n==0)r.seen[bullet]=true;
         }
         else
         {
            var delta:int=n>=int(r.n)?n-int(r.n):n;
            if(bullet!=null && bullet!==r.bullet) delta=Math.max(delta,1);
            if(isFinite(ammo) && ammo<Number(r.ammo))
               delta=Math.max(delta,Math.ceil((Number(r.ammo)-ammo)/Math.max(1,Number(get(w,"rashod")))));
            r.total+=delta;r.n=n;r.bullet=bullet;r.ammo=ammo;
         }
         var bullets:Array=frameBullets[w]==null?[]:frameBullets[w].concat();
         if(bullet!=null && bullets.indexOf(bullet)<0)bullets.push(bullet);
         for each(var native:Object in bullets)if(!r.seen[native] && get(native,"loc")===get(w,"loc")) {
            r.seen[native]=true;
            r.events.push({seq:++r.serial,at:frameTime>0?frameTime:getTimer(),bullet:native,
               recorded:player||ProjectileVisuals.usesNativeFrames(native),frames:[],sampled:0,end:0,endSentAt:0,explosion:null});
         }
         if(stamp>0)for each(var shot:Object in r.events) {
            if(shot.explosion==null && get(shot.bullet,"isExpl")===true){
               shot.explosion=ProjectileExplosionVisuals.capture(shot.bullet);
               if(shot.explosion!=null)shot.explosion.at=stamp;
            }
            if(!shot.recorded)continue;
            var point:Object=ProjectileVisuals.beamFrame(shot.bullet,stamp);
            if(point!=null){
               if(int(shot.sampled)==stamp&&shot.frames.length>0)shot.frames[shot.frames.length-1]=point;
               else shot.frames.push(point);
               if(shot.frames.length>64)shot.frames.shift();
            }
            shot.sampled=stamp;
            if(get(shot.bullet,"in_chain")!=true && int(shot.end)==0)shot.end=stamp;
         }
         // Retain the final state for a full send window after native removal.
         // Measuring only from birth can discard end before a delayed world
         // snapshot sends it, leaving the last visible frame on the joiner.
         // A live grenade can outlast the send window by seconds. Retire only
         // ended records, without letting a long-lived first shot pin the rest.
         for(var i:int=r.events.length-1;i>=0;i--){
            var event:Object=r.events[i];
            if((int(event.end)>0&&int(event.endSentAt)>0&&getTimer()-int(event.endSentAt)>700)
               ||(!event.recorded&&getTimer()-int(event.at)>700))r.events.splice(i,1);
         }
         return int(r.total);
      }

      public function capture(u:Object,playerDisplay:Boolean=false):Array
      {
         var result:Array=[],list:Array=weaponList(u),current:Object=get(u,"currentWeapon");
         for(var i:int=0;i<list.length;i++)
         {
            var w:Object=list[i];
            if(w==null || get(w,"kol_shoot")==null) continue;
            var count:int=observeWeapon(w),events:Array=[];
            for each(var shot:Object in hostShots[w].events) {
               var flight:Object=ProjectileVisuals.capture(shot.bullet);
               if(flight!=null && shot.recorded){
                  flight.frames=shot.frames;flight.end=shot.end;flight.explosion=shot.explosion;
                  // Rendering can block the network timer for longer than the
                  // retention window. An unsent ending must never be pruned.
                  if(int(shot.end)>0 && int(shot.endSentAt)==0)shot.endSentAt=getTimer();
               }
               events.push({seq:shot.seq,at:shot.at,flight:flight});
            }
            var children:Array=get(u,"childObjs") as Array;
            var effectsOnly:Boolean=w!==current && w!==get(u,"throwWeapon") && w!==get(u,"magicWeapon") && (children==null || children.indexOf(w)<0);
            result.push({stream:hostShots[w].stream,slot:i,id:String(get(w,"id")),variant:int(get(w,"variant")),main:w===current,events:events,effectsOnly:effectsOnly,
               sampleTime:frameTime>0?frameTime:getTimer(),aura:TelekinesisVisuals.captureWeapon(w),
               display:playerDisplay?WeaponDisplay.capture(u,w):null,
               melee:MeleeVisuals.capture(u,w),impacts:energyImpacts.capture(w),
               shots:count,ox:Number(get(w,"X"))-Number(get(u,"X")),
               oy:Number(get(w,"Y"))-Number(get(u,"Y")),rot:Number(get(w,"rot")),
               prep:int(get(w,"t_prep")),reload:int(get(w,"t_reload")),
               cadence:Math.max(16,Number(get(w,"rapid"))*1000/30)});
         }
         return result;
      }

      public function apply(u:Object,snapshot:Object,main:Object,motion:RemoteMotion=null):void
      {
         try
         {
            var rec:Object=states[u];
            if(rec==null)
            {
               var children:Array=get(u,"childObjs") as Array;
               rec=states[u]={sost:int(snapshot.sost),guns:{},originalChildren:children==null?null:children.concat(),
                  originalCurrent:get(u,"currentWeapon"),created:[],styles:new Dictionary()};
            }
            var old:int=rec.sost;rec.sost=int(snapshot.sost);
            rec.clock=motion;
            rec.burning=snapshot.burning===true;rec.main=main;
            RConnectAnimationAccess.receive(u as Unit,snapshot.pose,String(snapshot.anim),rec.pose);
            rec.pose=snapshot.pose;
            rec.body=snapshot.body;
            if(rec.sost>=3)
            {
               if(old<3 && rec.death!=null && rec.death.armed)
                  DeathVisuals.play(main,u.loc,snapshot.death || rec.death,Number(snapshot.x),Number(snapshot.y)-3);
               if(old<3 && rec.sost==4)
               {
                  // Native UnitDron.expl is metal + miniexpl. Use only the particle
                  // emitter for other machines too; arbitrary expl overrides can hurt/spawn.
                  var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
                  if(int(get(u,"mat"))==1)
                  {
                     emitter.emit("metal",u.loc,u.X,u.Y-Number(get(u,"scY"))/2,{kol:4});
                     emitter.emit("miniexpl",u.loc,u.X,u.Y-Number(get(u,"scY"))/2);
                  }
                  else if(int(get(u,"blood"))>0)
                     emitter.emit(int(get(u,"blood"))==2?"gblood":"blood",u.loc,u.X,u.Y-Number(get(u,"scY"))/2,{kol:4});
                  Log.d("RConnectGame: mirror death effect '"+u.id+"'");
               }
               enforceDeath(u,rec.sost);
               return;
            }
            rec.death=snapshot.death;
            if(rec.body!=null)TurretDisplay.receive(u,rec.body);
            if(!(snapshot.weapons is Array)) return;
            for each(var s:Object in snapshot.weapons)
            {
               if(s.effectsOnly===true)continue;
               var gun:Object=rec.guns[String(s.slot)];
               if(gun==null || gun.id!=s.id || gun.variant!=s.variant)
               {
                  if(gun!=null) {melee.forget(gun.weapon);telekinesis.forgetWeapon(gun.weapon);gun.weapon.remVisual();}
                  var local:Array=get(u,"childObjs") as Array;
                  var weapon:Object=s.main===true?get(u,"currentWeapon"):(local==null?null:local[int(s.slot)]);
                  if(weapon==null || String(get(weapon,"id"))!=s.id || int(get(weapon,"variant"))!=int(s.variant))
                  {
                     var factory:Object=main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
                     var replacement:Object=factory.create(u,String(s.id),int(s.variant));
                     if(replacement==null) continue;
                     if(weapon!=null) weapon.remVisual();
                     if(local==null) local=u.childObjs=[];
                     var index:int=local.indexOf(weapon);
                     if(index>=0) local[index]=replacement;else local.push(replacement);
                     if(s.main===true) u.currentWeapon=replacement;
                     weapon=replacement;rec.created.push(weapon);
                  }
                  gun=rec.guns[String(s.slot)]={id:s.id,variant:s.variant,weapon:weapon,shots:int(s.shots),queue:0,next:0,flash:0,reload:0};
                  var originalVis:Object=get(weapon,"vis");
                  if(originalVis!=null && rec.styles[originalVis]==null)
                     rec.styles[originalVis]={alpha:originalVis.alpha,visible:originalVis.visible};
               }
               var delta:int=int(s.shots)-int(gun.shots);
               if(delta>0) gun.queue=Math.min(8,int(gun.queue)+delta);
               var now:int=getTimer(),prev:Object=gun.motion;
               gun.motion={x:prev==null?Number(s.ox):Number(gun.weapon.X)-Number(u.X),
                  y:prev==null?Number(s.oy):Number(gun.weapon.Y)-Number(u.Y),
                  r:prev==null?Number(s.rot):Number(gun.weapon.rot),at:now,
                  duration:prev==null?0:Math.max(50,Math.min(600,now-int(prev.at)))};
               gun.shots=int(s.shots);gun.snapshot=s;
               if(int(s.reload)>0 && int(gun.reload)<=0) play(gun.weapon,"reload");
               gun.reload=int(s.reload);
            }
            tick(u);
         }
         catch(e:*) {failed(u,e);}
      }

      private function play(w:Object,label:String):void
      {
         var vis:MovieClip=get(w,"vis") as MovieClip;
         if(vis==null) return;
         for each(var item:Object in vis.currentLabels)
            if(item.name==label) {vis.gotoAndPlay(label);return;}
      }

      public function tick(u:Object):void
      {
         var rec:Object=states[u];if(rec==null) return;
         try
         {
            RConnectAnimationAccess.effects(u as Unit);
            if(rec.sost>=3) {enforceDeath(u,rec.sost);return;}
            burning.present(rec.main,u,rec.burning===true);
            for each(var gun:Object in rec.guns)
            {
               var w:Object=gun.weapon,s:Object=gun.snapshot;
               if(s==null) continue;
               var v:Object=get(w,"vis");
               if(v!=null && (v.parent==null || (get(get(u,"vis"),"stage")!=null && v.stage!==u.vis.stage))) w.addVisual();
               var m:Object=gun.motion;
               var elapsed:int=getTimer()-int(m.at),p:Number=m.duration>0?Math.min(1,elapsed/m.duration):1;
               var angle:Number=Number(s.rot)-Number(m.r);
               while(angle>Math.PI)angle-=Math.PI*2;
               while(angle<-Math.PI)angle+=Math.PI*2;
               w.X=Number(u.X)+Number(m.x)+(Number(s.ox)-Number(m.x))*p;
               w.Y=Number(u.Y)+Number(m.y)+(Number(s.oy)-Number(m.y))*p;
               w.rot=Number(m.r)+angle*p;
               w.t_prep=Math.max(0,int(s.prep)-int(elapsed*30/1000));
               w.t_reload=Math.max(0,int(s.reload)-int(elapsed*30/1000));
               if(gun.queue>0 && getTimer()>=int(gun.next))
               {
                  gun.queue--;gun.next=getTimer()+(s.cadence==null?80:Math.max(16,Math.min(250,Number(s.cadence))));gun.flash=3;
                  play(w,"shoot");
                  if(rec.body!=null && rec.body.kind=="turret")TurretDisplay.fire(u);
               }
               w.t_shoot=gun.flash;
               if(gun.flash>0) gun.flash--;
               // animate updates aim and position only. Never call step/actions/attack.
               w.animate();
               telekinesis.weapon(w,s.aura);
               if(v!=null && get(u,"vis")!=null)
               {
                  v.visible=u.vis.visible;v.alpha=u.vis.alpha;
               }
               melee.apply(u,w,s.melee,rec.clock==null?NaN:rec.clock.sourceTime);
            }
            if(rec.body!=null)TurretDisplay.present(u,rec.body);
         }
         catch(e:*) {failed(u,e);}
      }

      public function animateBody(u:Object):void
      {
         var rec:Object=states[u];
         if(rec!=null && rec.body!=null && rec.body.kind=="turret")return;
         if(rec==null || !RConnectAnimationAccess.tick(u as Unit,rec.pose))u.animate();
      }

      public function enforce(u:Object):void
      {
         var rec:Object=states[u];
         if(rec!=null && rec.sost>=3) enforceDeath(u,rec.sost);
      }

      private function enforceDeath(u:Object,sost:int):void
      {
         if(sost>=4) {
            // A destroyed machine must leave Location.firstObj as well as the
            // display tree, or drawAllObjs revives its picture after respawn.
            var room:Object=get(u,"loc");if(room!=null)room.remObj(u);
            u.remVisual();
         }
         else
         {
            var children:Array=get(u,"childObjs") as Array;
            if(children!=null) for each(var child:Object in children) if(child!=null) child.remVisual();
            var bar:Object=get(u,"hpbar");if(bar!=null && bar.parent!=null) bar.parent.removeChild(bar);
         }
      }

      public function reset():void
      {
         telekinesis.reset();
         energyImpacts.reset();melee.reset();MeleeVisuals.resetObserved();
         burning.reset();
         for(var u:Object in states)
         {
            var rec:Object=states[u];
            try
            {
               for(var v:Object in rec.styles) {v.alpha=rec.styles[v].alpha;v.visible=rec.styles[v].visible;}
               if(!rec.created.length) continue;
               for each(var w:Object in rec.created) w.remVisual();
               u.childObjs=rec.originalChildren;u.currentWeapon=rec.originalCurrent;
               if(int(u.sost)<3 && rec.originalChildren!=null)
                  for each(w in rec.originalChildren) if(w!=null && get(w,"vis")!=null) w.addVisual();
            }
            catch(e:*) {failed(u,e);}
         }
         RConnectAnimationAccess.reset();
         states=new Dictionary();
         hostShots=new Dictionary(true);
         frameBullets=new Dictionary(true);scannedAt=-1;scannedLoc=null;
         frameTime=0;
      }

      private function failed(u:Object,e:*):void
      {
         var id:String=String(get(u,"id"));if(errors[id]) return;errors[id]=true;
         var stack:String=e is Error?(e as Error).getStackTrace():null;
         Log.d("RConnectGame: unit effects '"+id+"' failed: "+(stack==null?e:stack));
      }
   }
}
