package testdriver {
   import authority.*;
   import flash.utils.getTimer;
   import flash.system.System;
   /** External stimulus only: original B190 game/actor/wire/render bytes stay intact. */
   public class ContinuousStressProbe extends Probe {
      private var ready:Boolean=false,begin:int=-1,preparedAt:int,lastAt:int=0,lastMemory:int=0,frames:int=0;
      private var startTick:uint=0,pressFrames:int=0,duration:int,samples:Array=[],initialShots:Array;
      private var startAmmo:Array,windows:Array=[],repairs:uint=0,fixtureSource:String;
      public function ContinuousStressProbe(a:NativeAccess,h:Boolean,seconds:Number,source:String) {
         super(a,h);fixtureSource=source;if(seconds<20 || seconds>1800)throw new Error("Bounded stress duration required");duration=int(seconds*1000);
      }
      override public function prepare():void {super.prepare();Timing.enabled=true;Log.write("continuous-stress-fixture",{source:fixtureSource,seconds:duration/1000,
         stimulus:"Release every 30 generated local frames; native reload and native ammo remain active; fixture restores weapon durability and suppresses random jams."});}
      override public function message(v:Object):void {
         if(host && v.type=="continuous-stress-ready" && begin<0){begin=getTimer();startTick=current().tick;initialShots=current().spawnsByPlayer.concat();Timing.reset();}
      }
      override public function input(f:Object,s:HostSession):Object {
         f.buttons=0;f.actions=[];
         if(begin>=0){++pressFrames;f.buttons=pressFrames%30==0?0:8;}
         f.aimX=access.world.gg.X+380;f.aimY=access.world.gg.Y-45;return f;
      }
      private function current():Object {
         return frame;
      }
      private var frame:Object;
      public static var send:Function;
      private function sendReady():void {send({type:"continuous-stress-ready"});}
      private function ammo(s:HostSession):Array {
         var values:Array=[];for each(var a:Object in s.actors){var w:Object=a.unit.currentWeapon;values.push(w.hold+a.unit.invent.items[w.ammo].kol);}return values;
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;var now:int=getTimer(),w:Object=access.world;
         if(host) {
            if(s==null || !s.active || s.lastFrame==null)return;frame=s.lastFrame;
            if(!ready) {
               ready=true;var y:Number=ProbeArena.floor(w.loc),Type:Class=access.definition("fe.unit.UnitZombie");
               for each(var a:Object in s.actors) {
                  a.unit.setLocPos(250+a.id*80,y);a.unit.invulner=true;
                  a.unit.currentWeapon.hold=a.unit.currentWeapon.holder;a.unit.invent.items[a.unit.currentWeapon.ammo].kol=10000;
               }
               startAmmo=ammo(s);
               for(var i:int=0;i<80;i++) {
                  var u:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
                  u.putLoc(w.loc,Math.min(w.loc.limX-100,650+(i%20)*35),y-int(i/20)*100);
                  w.loc.units.push(u);w.loc.addObj(u);u.addVisual();u.disabled=false;u.invulner=true;
                  u.hp=u.maxhp=10000;u.lootIsDrop=true;u.xp=0;u.setVisPos();
               }
               w.loc.isRebuild=true;preparedAt=now;return;
            }
            for each(a in s.actors) {
               if(a.unit.currentWeapon.hp<a.unit.currentWeapon.maxhp){a.unit.currentWeapon.hp=a.unit.currentWeapon.maxhp;++repairs;}
               a.unit.pers.jammedMult=0;
            }
         }else {
            if(r==null || r.displayFrame==null || r.displayFrame.scene.units.length!=80)return;frame=r.displayFrame;
            if(!ready){ready=true;preparedAt=now;}
            if(begin<0 && now-preparedAt>=2500){begin=now;startTick=frame.tick;initialShots=frame.spawnsByPlayer.concat();Timing.reset();sendReady();}
         }
         if(begin<0)return;
         ++frames;if(lastAt>0)Timing.record("display.interval",now-lastAt);lastAt=now;
         var elapsed:int=now-begin,minute:int=Math.min(int(elapsed/60000),int(Math.ceil(duration/60000))-1);
         if(windows[minute]==null)windows[minute]={first:frame.spawnsByPlayer.concat(),last:frame.spawnsByPlayer.concat()};
         else windows[minute].last=frame.spawnsByPlayer.concat();
         if(now-lastMemory>2000) {
            lastMemory=now;samples.push({ms:elapsed,heapBytes:System.totalMemory,queued:host?0:r.clock.queued,
               steps:frame.tick,playbackDelay:host?0:r.clock.delay,underflows:host?0:r.clock.underflows,
               effects:frame.scene.effects.length,projectiles:frame.projectiles.length,shots:frame.spawnsByPlayer.concat()});
         }
         if(elapsed<duration)return;
         check(frame.scene.units.length==80,"continuous stress retains 80 real native enemy identities");
         for(i=0;i<windows.length;i++) {
            var v:Object=windows[i];check(v!=null && v.last[0]>v.first[0] && v.last[1]>v.first[1],
               "both native players produce new projectiles in measured minute "+i,v);
         }
         check(windows.length==Math.ceil(duration/60000),"every measured minute is covered by shooting observations");
         if(host) {
            var remaining:Array=ammo(s),paid:Array=[];
            for(i=0;i<2;i++){paid[i]=startAmmo[i]-remaining[i];check(paid[i]==frame.spawnsByPlayer[i]-initialShots[i],
               "continuous native reload spends one real round per projectile for player "+i,{paid:paid[i],shots:frame.spawnsByPlayer[i]-initialShots[i]});}
         }
         check(frame.tick>startTick+30,"continuous dense combat keeps native simulation advancing",{steps:frame.tick-startTick,elapsedMs:elapsed});
         Log.write("stress-measurements",{elapsedMs:elapsed,screenFrames:frames,hostSteps:frame.tick-startTick,timings:Timing.snapshot(),memory:samples,
            shootingWindows:windows,repairs:repairs,note:"External paced fire fixture. Not an A/B performance proof or indefinite-session proof."});
         SceneChecks.picture(access,"dense-continuous-native-enemies.png");finish();Timing.enabled=false;
      }
   }
}
