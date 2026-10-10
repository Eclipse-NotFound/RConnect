package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.RConnectAnimationAccess;
   import fe.weapon.Bullet;
   import fe.weapon.RConnectProjectileAccess;

   /** Source-only native presentation recorder. The session declares which
    * streams have a consumer; capture never simulates weapons or projectiles.
    * Retain an unsent ending while subscribed, including delayed network ticks.
    * Offline capture stops; an independent room retains only its recent ending
    * window for a possible handoff, never every past unpublished shot. */
   public class WeaponCapture {
      private var hostShots:Dictionary=new Dictionary(true);
      private var weaponsByOwner:Dictionary=new Dictionary(true),ownerIndexAt:int=-1;
      private var shotStream:int=0,frameTime:int=0,scannedAt:int=-1,scannedLoc:Object;
      private var frameBullets:Dictionary=new Dictionary(true);
      private var energyImpacts:EnergyImpactVisuals=new EnergyImpactVisuals();
      private var recordPlayer:Boolean=true,recordEnemies:Boolean=true;
      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}

      public function recording(player:Boolean,enemies:Boolean):void {
         if(player==recordPlayer && enemies==recordEnemies)return;
         // Subscription changes coincide with session boundaries. Room-role
         // changes separately reset both recorder and receiver as one lifecycle.
         reset();recordPlayer=player;recordEnemies=enemies;
      }

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
         // Index once per source frame. Looking through every known gun for
         // each enemy made the ordinary 80-unit path quadratic even at rest.
         if(ownerIndexAt!=frameTime) {
            weaponsByOwner=new Dictionary(true);ownerIndexAt=frameTime;
            for(var known:Object in hostShots) {
               var owner:Object=get(known,"owner");if(owner==null)continue;
               if(weaponsByOwner[owner]==null)weaponsByOwner[owner]=[];
               weaponsByOwner[owner].push(known);
            }
         }
         var retained:Array=weaponsByOwner[u] as Array;
         if(retained!=null)for each(var previous:Object in retained)
            if(get(previous,"owner")===u && get(previous,"loc")===get(u,"loc")
               && (hostShots[previous].events.length>0 || energyImpacts.retains(previous)) && list.indexOf(previous)<0)list.push(previous);
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
         if(!recordPlayer)return;
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

      public function observePlayer(u:Object,stamp:int=0):void {
         if(!recordPlayer)return;
         frameTime=stamp>0?stamp:getTimer();scanBullets(get(u,"loc"),frameTime);
         for each(var w:Object in weaponList(u))if(get(w,"kol_shoot")!=null)observeWeapon(w,frameTime,true);
         energyImpacts.observeSpells(u,frameTime);
      }
      public function captureSpells(u:Object):Array {return energyImpacts.capture(u);}

      /** Refresh already-observed NPC clips after Flash advances frame scripts.
       * Reuse the chain index; no second unit/weapon discovery or AI step. */
      public function observeFinal(loc:Object,stamp:int):void {
         if(!recordPlayer || loc==null || stamp<=0)return;
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
            ownerIndexAt=-1;
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
         var owner:Object=get(w,"owner");
         if(r.owner!==owner){r.owner=owner;ownerIndexAt=-1;}
         var recording:Boolean=recordPlayer;
         var bullets:Array=!recording || frameBullets[w]==null?[]:frameBullets[w].concat();
         if(recording && bullet!=null && bullets.indexOf(bullet)<0)bullets.push(bullet);
         for each(var native:Object in bullets)if(!r.seen[native] && get(native,"loc")===get(w,"loc")) {
            r.seen[native]=true;
            r.events.push({seq:++r.serial,at:frameTime>0?frameTime:getTimer(),bullet:native,
               recorded:true,frames:[],sampled:0,end:0,endSentAt:0,explosion:null,explosions:[],impact:null,impactChecked:false,pulse:-1});
         }
         if(stamp>0)for each(var shot:Object in r.events) {
            // Retention exists to deliver the immutable final state. Sampling
            // a detached Bullet for another 700 ms only resends hidden poses,
            // inflates every burst, and can evict real flight from the buffer.
            if(int(shot.end)>0)continue;
            if(!shot.impactChecked && get(shot.bullet,"babah")===true) {
               shot.impactChecked=true;
               shot.impact=BallisticImpactVisuals.capture(shot.bullet,stamp);
               if(shot.impact!=null)shot.impact.at=stamp;
            }
            if(shot.explosion==null && get(shot.bullet,"isExpl")===true){
               shot.explosion=ProjectileExplosionVisuals.capture(shot.bullet);
               if(shot.explosion!=null){shot.explosion.at=stamp;shot.explosions.push(shot.explosion);}
            } else if(shot.explosion!=null) {
               var pulse:int=RConnectProjectileAccess.remaining(shot.bullet as Bullet);
               var period:int=int(get(shot.bullet,"explPeriod"));
               if(pulse>0 && period>0 && pulse%period==1 && pulse!=int(shot.pulse)) {
                  var effect:Object=ProjectileExplosionVisuals.capture(shot.bullet,true);
                  if(effect!=null){effect.at=stamp;shot.explosions.push(effect);}
               }
               shot.pulse=pulse;
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
               ||(!player && !recordEnemies && int(event.end)>0 && getTimer()-int(event.end)>700)
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
            var count:int=observeWeapon(w,0,playerDisplay),events:Array=[];
            for each(var shot:Object in hostShots[w].events) {
               var flight:Object=ProjectileVisuals.capture(shot.bullet);
               if(flight!=null && shot.recorded){
                  flight.frames=shot.frames;flight.end=shot.end;flight.explosion=shot.explosion;
                  flight.explosions=shot.explosions;flight.impact=shot.impact;
               }
               // Retire after capture even if native removal already discarded
               // the clip. A null flight is still a consumed sequence number.
               // Before this capture, a delayed timer must not lose the ending.
               if(int(shot.end)>0 && int(shot.endSentAt)==0)shot.endSentAt=getTimer();
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

      public function reset():void {
         energyImpacts.reset();BallisticImpactVisuals.reset();MeleeVisuals.resetObserved();
         hostShots=new Dictionary(true);
         weaponsByOwner=new Dictionary(true);ownerIndexAt=-1;
         frameBullets=new Dictionary(true);scannedAt=-1;scannedLoc=null;frameTime=0;
      }
   }
}
