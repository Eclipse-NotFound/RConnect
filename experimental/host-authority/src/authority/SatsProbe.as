package authority {
   import flash.utils.getTimer;
   import flash.filters.GlowFilter;
   /** Uses the real client SATS menu and the real host queue/cost execution. */
   public final class SatsProbe extends Probe {
      private var ready:Boolean=false,phase:int=0,at:int=0,freezeTick:uint=0,resumeTick:uint=0;
      private var target:Object,targetY:Number,startHp:Number,initialOd:Number,initialAmmo:int;
      private var frozen:Boolean=true,queued:Boolean=false,refreshes:uint=0;
      private var repetitions:int=1,cycle:int=0;
      private var nextCycle:int=-1,nextCycleTick:uint=0,allCyclesFinished:Boolean=false;
      private var traceAt:int=0;
      public function SatsProbe(a:NativeAccess,h:Boolean,repetitions:int=1){super(a,h);this.repetitions=repetitions;}
      override public function message(value:Object):void {
         if(!host && value.type=="sats-next-cycle"){nextCycle=value.cycle;nextCycleTick=value.tick;}
         if(!host && value.type=="sats-all-cycles-finished")allCyclesFinished=true;
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;
         // Preserve InputSource's native SATS plan and release request.
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var w:Object=access.world;
         if(getTimer()-traceAt>=3000) {
            traceAt=getTimer();
            var state:Object={phase:phase,cycle:cycle,allStat:w.allStat,onPause:w.onPause,
               sats:w.sats.active,pip:w.pip.active,stand:w.stand.active,gui:w.gui.guiPause,menu:w.mm.active,
               queue:w.sats.que.length};
            if(session!=null && session.active) {
               state.tick=session.runtime.tick;state.paused=session.pause.paused;state.remote=session.pause.remote;
               state.remoteMenus=session.pause.remoteMenus;state.remoteSats=session.pause.remoteSats;
               state.seq=session.inputs[1].accepted;state.inputAge=getTimer()-session.inputs[1].lastAt;
               state.actorQueue=session.actors[1].context.sats.que.length;
            }
            if(replica!=null && replica.lastFrame!=null) {
               state.tick=replica.lastFrame.tick;state.paused=replica.lastFrame.paused;
               state.frames=replica.frames;state.actionAck=replica.lastFrame.players[1].actionAck;
            }
            Log.write("sats-cycle-state",state);
         }
         if(host) {
            if(session==null || !session.active)return;
            var b:PlayerActor=session.actors[1],tick:uint=session.runtime.tick;
            if(!ready) {
               SatsActions.observed=function(result:Object):void {Log.write("sats-host-plan",result);};
               ready=true;var room:Object=b.unit.loc,y:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((y+1)/40);
               for each(var old:Object in room.units)if(old!=null && !old.player){old.disabled=true;old.remVisual();}
               for(var x:int=8;x<28;x++)for(var z:int=row-6;z<=row;z++) {
                  var t:Object=room.space[x][z];t.phis=z==row?1:0;t.visi=t.t_visi=1;t.water=0;
                  t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=z*40;t.phY2=(z+1)*40;
                  t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
                  if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
               }
               room.black=room.mirror=false;
               // The fixture changes an existing dark room into a fully lit
               // arena, so initialize every tile just like a native lit room.
               for(x=0;x<room.spaceX;x++)for(z=0;z<room.spaceY;z++)room.space[x][z].visi=room.space[x][z].t_visi=1;
               session.actors[0].unit.setPos(400,y);b.unit.setPos(600,y);
               access.scope.run(b.context,function():void {
                  var Type:Class=access.definition("fe.unit.UnitZombie");target=new Type("1",100,<unit tr="1" dig="0"/>,null);
                  target.putLoc(room,800,y);room.units.push(target);room.addObj(target);target.addVisual();target.setVisPos();target.animate();
                  target.hp=target.maxhp=10000;target.skin=target.armor=target.dexter=target.dodge=0;
                  target.invulner=target.disabled=target.trigDis=false;target.doop=true;target.lootIsDrop=true;target.xp=0;
                  target.vision=0;target.oduplenie=10000;target.stun=10000;
               });
               targetY=y;startHp=target.hp;b.context.sats.od=b.unit.pers.maxOd;b.context.sats.odd=0;
               initialOd=b.context.sats.od;initialAmmo=b.unit.currentWeapon.hold+b.unit.invent.items[b.unit.currentWeapon.ammo].kol;
            }
            if(phase==0 && session.pause.paused) {phase=1;freezeTick=tick;at=getTimer();}
            if(phase==1) {
               frozen=frozen && tick==freezeTick;
               if(!session.pause.paused) {
                  phase=2;resumeTick=tick;
                  check(frozen && getTimer()-at>=800,"client SATS holds the exact host simulation tick until release",{tick:freezeTick,ms:getTimer()-at});
               }
            }
            queued=queued || b.context.sats.que.length>0;
            if(phase==2 && session.lastFrame.projectileEvents.length>0)Log.write("sats-shot-evidence",{
               target:NativeFields.capture(target),aim:[b.unit.celX,b.unit.celY],shots:session.lastFrame.projectileEvents});
            if(phase==2 && tick>resumeTick+100) {
               check(session.pause.epoch==2*(cycle+1) && !session.pause.paused,"one shared pause and one resume boundary per cycle "+cycle);
               check(queued && b.context.sats.od<initialOd,"client's native SATS plan consumes the owning host actor's action points once",{before:initialOd,after:b.context.sats.od});
               check(b.unit.currentWeapon.hold+b.unit.invent.items[b.unit.currentWeapon.ammo].kol<initialAmmo && target.hp<startHp,
                  "SATS resumes with native host bullets and native enemy damage",{before:startHp,after:target.hp});
               check(w.gg===session.actors[0].unit && w.sats===session.actors[0].context.sats,"remote SATS does not replace host controls");
               if(cycle+1>=repetitions) {
                  if(repetitions>1)session.link.send({type:"sats-all-cycles-finished"});finish();
               }else {
                  ++cycle;phase=0;frozen=true;queued=false;
                  // Native shots really knock the target off this small arena.
                  // Reposition only between rounds, after the damage assertion;
                  // the next round must observe that new confirmed position.
                  target.setPos(800,targetY);target.dx=target.dy=0;
                  target.setVisPos();target.stun=10000;
                  b.context.sats.od=b.unit.pers.maxOd;b.context.sats.odd=0;
                  initialOd=b.context.sats.od;startHp=target.hp;
                  initialAmmo=b.unit.currentWeapon.hold+b.unit.invent.items[b.unit.currentWeapon.ammo].kol;
                  session.link.send({type:"sats-next-cycle",cycle:cycle,tick:tick+1});
               }
            }
            return;
         }
         if(replica==null || replica.lastFrame==null)return;
         var f:Object=replica.lastFrame;
         if(phase==0 && f.tick>55) {
            phase=1;w.sats.onoff(1);check(w.sats.active,"join opens its real native SATS menu");
         }
         if(phase==1 && f.paused && replica.satsRefreshes>0) {
            phase=2;freezeTick=f.tick;at=getTimer();refreshes=replica.satsRefreshes;
            var unique:Object={},duplicates:int=0,positions:Boolean=true,chosen:Object=null;
            for each(var u:Object in w.sats.units) {
               var id:uint=replica.scene.keyFor(u.u);if(unique[id])++duplicates;unique[id]=true;
               positions=positions && Math.abs(u.v.x-u.u.vis.x)<.01 && Math.abs(u.v.y-u.u.vis.y)<.01;
               if(!u.u.player && u.u.sost<3 && !u.u.disabled)chosen=u;
            }
            check(chosen!=null && duplicates==0 && positions,"SATS has one outline per confirmed enemy at its frozen native position",{units:w.sats.units.length,duplicates:duplicates});
            var evidence:Array=[];
            for each(var candidate:Object in w.loc.units)if(candidate!=null && !candidate.player && !candidate.disabled)
               evidence.push({id:candidate.id,sost:candidate.sost,isSats:candidate.isSats,invis:candidate.invis,
                  meet:w.gg.isMeet(candidate),look:w.gg.look(candidate),tile:candidate.getTileVisi(),x:candidate.X,y:candidate.Y});
            Log.write("sats-target-evidence",{targets:evidence,eye:[w.gg.eyeX,w.gg.eyeY],position:[w.gg.X,w.gg.Y]});
            if(chosen!=null){for each(u in w.sats.units)u.du.filters=[];chosen.du.filters=[new GlowFilter()];w.sats.setCel();queued=true;}
            SceneChecks.picture(access,"sats-confirmed-"+cycle+".png");
         }
         if(phase==2) {
            frozen=frozen && f.tick==freezeTick;
            if(getTimer()-at>1400) {
               check(frozen && replica.satsRefreshes==refreshes,"confirmed SATS remains still without repeatedly rebuilding its target list");
               check(queued && w.sats.que.length>0,"join retains its native queued target while paused");
               w.sats.onoff(-1);phase=3;
               Log.write("sats-local-closed",{active:w.sats.active,queue:w.sats.que.length,
                  menus:SharedPause.menus(w),requested:SharedPause.requested(w)});
            }
         }
         if(phase==3 && !f.paused && f.tick>freezeTick+80) {
            check(f.pauseEpoch==2*(cycle+1) && !w.sats.active,"join leaves SATS at the same authoritative resume boundary cycle "+cycle);
            check(w.onPause && f.spawnsByPlayer[1]>0,"join replays confirmed SATS bullets without simulating another battle");
            SceneChecks.picture(access,"sats-resumed-"+cycle+".png");
            if(repetitions==1)finish();else phase=4;
         }
         // A burst of delayed confirmations can deliver the next-cycle notice
         // before observe() has checked the previous cycle's displayed resume.
         if(phase==4 && nextCycle>=0 && f.tick>=nextCycleTick){cycle=nextCycle;nextCycle=-1;phase=0;frozen=true;queued=false;}
         if(phase==4 && allCyclesFinished) {
            check(cycle+1==repetitions,"every repeated SATS pause and resume was checked on the displayed timeline");finish();
         }
      }
   }
}
