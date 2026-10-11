package authority {
   import flash.utils.getTimer;
   import flash.system.System;
   /** Native live enemies and real sustained shooting; records rather than invents a performance pass gate. */
   public final class StressProbe extends Probe {
      private var ready:Boolean=false,begin:int=-1,startTick:uint=0,lastAt:int=0,lastMemory:int=0;
      private var samples:Array=[],frames:uint=0,baselineShots:uint=0;
      private var preparedAt:int=0;
      public function StressProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function prepare():void {super.prepare();Timing.enabled=true;}
      override public function message(value:Object):void {
         if(host && value.type=="stress-ready" && begin<0){begin=getTimer();startTick=RConnectMod.instance.host.runtime.tick;Timing.reset();}
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=begin>=0?Commands.FIRE:0;
         frame.aimX=access.world.gg.X+380;frame.aimY=access.world.gg.Y-45;return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var now:int=getTimer(),w:Object=access.world;
         if(host) {
            if(session==null || !session.active)return;
            if(!ready) {
               ready=true;var y:Number=ProbeArena.floor(w.loc),Type:Class=access.definition("fe.unit.UnitZombie");
               for each(var a:PlayerActor in session.actors) {
                  a.unit.setLocPos(250+a.id*80,y);a.unit.invulner=true;
                  a.unit.currentWeapon.hold=1000;a.unit.invent.items[a.unit.currentWeapon.ammo].kol=10000;
               }
               for(var i:int=0;i<80;i++) {
                  var u:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
                  u.putLoc(w.loc,Math.min(w.loc.limX-100,650+(i%20)*35),y-int(i/20)*100);
                  w.loc.units.push(u);w.loc.addObj(u);u.addVisual();u.disabled=false;u.invulner=true;
                  u.hp=u.maxhp=10000;u.lootIsDrop=true;u.xp=0;u.setVisPos();
               }
               w.loc.isRebuild=true;preparedAt=now;return;
            }
         }else {
            if(replica==null || replica.displayFrame==null || replica.displayFrame.scene.units.length!=80)return;
            if(!ready){ready=true;preparedAt=now;}
            if(begin<0 && now-preparedAt>=2500) {
               begin=now;startTick=replica.displayFrame.tick;Timing.reset();
               RConnectMod.instance.link.send({type:"stress-ready"});
            }
         }
         if(begin<0)return;
         ++frames;if(lastAt>0)Timing.record("display.interval",now-lastAt);lastAt=now;
         if(now-lastMemory>2000) {
            lastMemory=now;samples.push({ms:now-begin,heapBytes:System.totalMemory,
               queued:host?0:replica.clock.queued,steps:host?session.runtime.tick:replica.displayFrame.tick,
               effects:host?session.lastFrame.scene.effects.length:replica.displayFrame.scene.effects.length,
               projectiles:host?session.lastFrame.projectiles.length:replica.displayFrame.projectiles.length});
         }
         if(now-begin<20000)return;
         var f:Object=host?session.lastFrame:replica.displayFrame;
         check(f.scene.units.length==80,"stress run retains 80 real native enemy identities");
         check(f.spawnsByPlayer[0]>0 && f.spawnsByPlayer[1]>0,"both players fire native projectiles throughout the loaded scene",{shots:f.spawnsByPlayer});
         check(f.tick>startTick+30,"host continues authoritative simulation under the dense scene",{advanced:f.tick-startTick,elapsedMs:now-begin});
         Log.write("stress-measurements",{elapsedMs:now-begin,screenFrames:frames,hostSteps:f.tick-startTick,
            timings:Timing.snapshot(),memory:samples,note:"Profiling baseline, not a performance acceptance gate or long-session proof."});
         var sizes:Array=[];
         for each(var effect:Object in f.scene.effects)sizes.push({clip:effect.clip,name:effect.name,characters:JSON.stringify(effect).length,vector:effect.pose==null?null:PlainData.copy(effect.pose.vector)});
         sizes.sortOn("characters",Array.NUMERIC|Array.DESCENDING);
         for each(var big:Object in sizes)if(big.vector!=null)for each(var recipe:Object in big.vector)if(recipe.bytes!=null)recipe.bytes="length="+recipe.bytes.length;
         Log.write("stress-payload",{sceneCharacters:JSON.stringify(f.scene).length,effects:sizes.slice(0,12),
            firstUnitCharacters:f.scene.units.length==0?0:JSON.stringify(f.scene.units[0]).length});
         SceneChecks.picture(access,"dense-native-enemies.png");finish();Timing.enabled=false;
      }
   }
}
