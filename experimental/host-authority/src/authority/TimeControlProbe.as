package authority {
   import flash.events.KeyboardEvent;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.getTimer;
   /** Real keys and native impacts; never invoke the private single-player driver. */
   public final class TimeControlProbe extends Probe {
      private var ready:Boolean=false,peer:Boolean=false,phase:int=0,round:int=0,pauseAt:int=0;
      private var target:Object,hp:Number=0,start:Object,frozen:Object,endAmmo:Array,endSteps:Array,endMana:Array;
      private var special:Boolean=false;
      private var fy:Number=0,joinFrames:uint=0,seenRecord:Boolean=false,seenReplay:Boolean=false;
      private var film:Object={},refs:Object={},observed:Object={},replaySamples:int=0,replayErrors:int=0,viewSamples:int=0,viewErrors:int=0;
      private var replayPause:Boolean=false,replayFreeze:Object,replayFreezeAt:int=0,replayClosed:Boolean=false;
      private var pictures:Object={};
      public function TimeControlProbe(a:NativeAccess,h:Boolean,special:Boolean=false){super(a,h);this.special=special;}
      private function key():void {
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,220));
         access.world.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,220));
      }
      override public function input(f:Object,s:HostSession):Object {
         var actions:Array=[];for each(var a:Object in f.actions)if(a.type=="native" && a.key=="sandyToggle")actions.push(a);
         f.actions=actions;f.buttons=0;f.aimX=850;f.aimY=fy-55;
         var state:Object=host?access.time==null?null:access.time.snapshot(false):RConnectMod.instance.replica==null?null:
            RConnectMod.instance.replica.lastFrame==null?null:RConnectMod.instance.replica.lastFrame.timeControl;
         if(state!=null && state.phase=="record") {
            if(state.recorded>=10 && state.recorded<65)f.buttons=special && !host?Commands.MAGIC:Commands.FIRE;
            else if(state.recorded>=80 && state.recorded<110)f.buttons=int(state.recorded/10)%2==0?Commands.LEFT:Commands.RIGHT;
         }
         return f;
      }
      override public function message(v:Object):void {
         if(host && v.type=="time-ready")peer=true;
         if(!host && v.type=="time-setup"){fy=v.floor;joinFrames=RConnectMod.instance.replica.frames;}
         if(!host && v.type=="time-toggle")key();
         if(!host && v.type=="time-open")access.world.sats.onoff(1);
         if(!host && v.type=="time-close")access.world.sats.onoff(-1);
         if(!host && v.type=="time-reference"){refs[v.presentation]=v;compare(v.presentation);}
         if(!host && v.type=="time-finish") {
            check(seenRecord && seenReplay && RConnectMod.instance.replica.frames>joinFrames+40,
               "joining screen receives both shared time phases and continuous confirmations");
            check(viewSamples>8 && viewErrors==0,"joining replay matches both native player bodies and gun pixels",{samples:viewSamples,errors:viewErrors});finish();
         }
      }
      private function ammo(s:HostSession):Array {
         var values:Array=[];for each(var a:PlayerActor in s.actors){var g:Object=a.unit,w:Object=g.currentWeapon;values.push(w.hold+g.invent.items[w.ammo].kol);}return values;
      }
      private function beginRound(s:HostSession):void {
         hp=target.hp;phase=1;
         replayPause=replayClosed=false;replayFreeze=null;
         start={rooms:s.runtime.roomSteps,steps:[s.actors[0].steps,s.actors[1].steps],queued:access.time.hits.queued,applied:access.time.hits.applied};
         if(special)for each(var actor:PlayerActor in s.actors)access.scope.run(actor.context,function():void {
            var g:Object=actor.unit,Weapon:Class=access.definition("fe.weapon.Weapon");
            g.pers.setForcLevel(60);g.pers.skills.energy=g.pers.skills.magic=100;g.pers.setParameters();
            g.mana=g.maxmana=10000;g.pers.manaHP=10000;g.pers.spellsPoss=1;
            var id:String=actor.id==0?(round==0?"lasr":"plar"):(round==0?"lightning":"mray");
            var gun:Object=Weapon["create"](g,id,0);gun.setPers(g,g.pers);gun.hp=gun.maxhp;gun.respect=0;gun.loc=g.loc;gun.setNull();
            g.invent.weapons[id]=gun;
            if(actor.id==0){g.currentWeapon.remVisual();g.currentWeapon=gun;g.childObjs[0]=gun;g.invent.cWeaponId=id;gun.addVisual();}
            else {if(g.magicWeapon!=null)g.magicWeapon.remVisual();g.magicWeapon=gun;g.invent.fav[30]=id;gun.addVisual2();}
         });
         for each(var a:PlayerActor in s.actors){a.unit.currentWeapon.hold=100;a.unit.invent.items[a.unit.currentWeapon.ammo].kol=100;}
         if(round==0)key();else s.link.send({type:"time-toggle"});
      }
      private function pixels(display:DisplayObject):Object {
         if(display==null)return null;
         // Compare the actual affine drawing, not Flash's cached rotation/
         // scale decomposition, which changes after an equivalent matrix set.
         var affine:Matrix=display.transform.matrix;
         var r:Rectangle=display.getBounds(display.parent==null?display:display.parent),x:int=Math.floor(r.x),y:int=Math.floor(r.y);
         var bmp:BitmapData=new BitmapData(Math.max(1,Math.ceil(r.right)-x),Math.max(1,Math.ceil(r.bottom)-y),true,0);
         bmp.draw(display,new Matrix(affine.a,affine.b,affine.c,affine.d,affine.tx-x,affine.ty-y),display.transform.colorTransform);var h:uint=2166136261;
         for each(var p:uint in bmp.getVector(bmp.rect))h=uint((h^p)*16777619);bmp.dispose();
         return {matrix:[affine.a,affine.b,affine.c,affine.d,affine.tx,affine.ty],pixels:h};
      }
      private function visuals(s:HostSession=null):Array {
         var out:Array=[];
         for(var i:int=0;i<2;i++) {
            var g:Object=host?s.actors[i].unit:displayedPlayer(i);
            out.push({x:g==null?null:g.X,y:g==null?null:g.Y,body:pixels(g==null?null:g.vis),
               facing:g==null?null:g.storona,width:g==null?null:g.scX,height:g==null?null:g.scY,
               gun:pixels(host?g.currentWeapon.vis:RConnectMod.instance.replica.weaponDisplay(i))});
         }return out;
      }
      private function captured(s:HostSession):void {
         var time:TimeBridge=access.time,key:String=time.cycle+":"+time.recorded;
         if(time.phase=="record" && film[key]==null)film[key]=visuals(s);
         if(time.phase=="replay") {
            var actual:Array=visuals(s),expected:Array=film[time.cycle+":"+time.replayed];++replaySamples;
            if(expected==null || JSON.stringify(actual)!=JSON.stringify(expected)) {
               ++replayErrors;if(replayErrors==1)Log.write("time-native-pixel-diff",{actual:actual,expected:expected,frame:time.replayed,history:time.history.inspect(),deferred:s.runtime.deferredPresentations});
            }
            s.link.send({type:"time-reference",tick:s.runtime.tick,presentation:s.presentations,visual:actual});
         }
      }
      private function confirmed(frame:Object):void {
         if(frame.timeControl!=null && frame.timeControl.phase=="replay"){observed[frame.presentation]=visuals();compare(frame.presentation);}
      }
      private function compare(tick:uint):void {
         if(refs[tick]==null || observed[tick]==null)return;++viewSamples;
         if(signature(refs[tick].visual)!=signature(observed[tick])) {
            ++viewErrors;if(viewErrors==1)Log.write("time-join-pixel-diff",{wanted:refs[tick].visual,actual:observed[tick],tick:tick});
         }
         delete refs[tick];delete observed[tick];
      }
      private function signature(values:Array):String {
         var ordered:Array=[];for each(var v:Object in values)ordered.push([v.x,v.y,v.facing,v.width,v.height,
            v.body==null?null:[v.body.matrix,v.body.pixels],v.gun==null?null:[v.gun.matrix,v.gun.pixels]]);
         return JSON.stringify(ordered);
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null)return;
            if(!ready){ready=true;r.confirmed=confirmed;RConnectMod.instance.link.send({type:"time-ready"});}
            if(r.displayFrame.timeControl!=null){seenRecord=seenRecord || r.displayFrame.timeControl.phase=="record";seenReplay=seenReplay || r.displayFrame.timeControl.phase=="replay";
               if(r.displayFrame.paused)picture(r.displayFrame.timeControl);}
            return;
         }
         if(s==null || !s.active || !peer || s.runtime.tick<30)return;
         if(!ready) {
            ready=true;check(access.time!=null,"independent shared time-control API is attached");
            if(access.time==null){s.link.send({type:"time-finish"});finish();return;}
            var previous:Function=s.runtime.afterStep;s.runtime.afterStep=function():void {previous();captured(s);};
            fy=ProbeArena.floor(access.world.loc);
            for each(var a:PlayerActor in s.actors){a.unit.setLocPos(400+a.id*180,fy);a.unit.invulner=true;}
            var Type:Class=access.definition("fe.unit.UnitZombie");target=new Type("1",100,<unit tr="1" dig="0"/>,null);
            target.putLoc(access.world.loc,850,fy);access.world.loc.units.push(target);target.addVisual();target.setVisPos();
            target.hp=target.maxhp=100000;target.skin=target.armor=target.dexter=target.dodge=0;
            target.invulner=target.disabled=target.trigDis=false;target.doop=true;target.lootIsDrop=true;target.xp=0;target.stun=10000;
            target.scX=50;target.scY=100;target.setPos(850,fy);target.animate();
            s.pause.policySats=true;s.link.send({type:"time-setup",floor:fy});beginRound(s);return;
         }
         var time:TimeBridge=access.time,now:int=getTimer();
         if(s.pause.paused)picture(time.snapshot(true));
         if(phase==1 && time.phase=="record" && time.recorded>=40) {
            check(time.initiator==round,"either player's real hotkey starts one host time clock",time.snapshot(false));
            check(s.actors[0].steps-start.steps[0]>=time.recorded && s.actors[1].steps-start.steps[1]>=time.recorded && s.runtime.roomSteps-start.rooms<time.recorded/2,
               "both native players run full speed while their occupied world runs slowly",
               {time:time.recorded,world:s.runtime.roomSteps-start.rooms,actors:[s.actors[0].steps-start.steps[0],s.actors[1].steps-start.steps[1]]});
            s.link.send({type:"time-open"});phase=2;
         }
         if(phase==2 && s.pause.paused){phase=3;pauseAt=now;frozen={tick:s.runtime.tick,frame:time.recorded,hp:target.hp,steps:[s.actors[0].steps,s.actors[1].steps]};}
         if(phase==3 && now-pauseAt>=1000) {
            check(s.runtime.tick==frozen.tick && time.recorded==frozen.frame && target.hp==frozen.hp &&
               s.actors[0].steps==frozen.steps[0] && s.actors[1].steps==frozen.steps[1],"shared SATS freezes the shared time clock and both real players");
            s.link.send({type:"time-close"});phase=4;
         }
         if(phase==4 && time.phase=="record" && time.recorded>=125) {
            check(time.hits.queued>start.queued && target.hp==hp,"native impacts wait until replay before taking health",{queued:time.hits.queued-start.queued,before:hp,after:target.hp});
            check(s.runtime.spawnsByPlayer[0]>0 && s.runtime.spawnsByPlayer[1]>0,"both players produce native projectiles during time control");
            if(round==0)key();else s.link.send({type:"time-toggle"});phase=5;
         }
         if(phase==5 && time.phase=="replay"){endAmmo=ammo(s);endMana=[s.actors[0].unit.mana,s.actors[1].unit.mana];endSteps=[s.actors[0].steps,s.actors[1].steps];phase=6;}
         if(phase==6 && time.phase=="replay" && time.replayed>=20 && !replayPause){replayPause=true;s.link.send({type:"time-open"});}
         if(phase==6 && replayPause && !replayClosed && s.pause.paused) {
            if(replayFreeze==null){replayFreezeAt=now;replayFreeze={tick:s.runtime.tick,frame:time.replayed,hp:target.hp,visual:JSON.stringify(visuals(s))};}
            else if(now-replayFreezeAt>=1000) {
               check(s.runtime.tick==replayFreeze.tick && time.replayed==replayFreeze.frame && target.hp==replayFreeze.hp && JSON.stringify(visuals(s))==replayFreeze.visual,
                  "shared SATS freezes replay motion, native pictures and deferred damage together");
               replayClosed=true;s.link.send({type:"time-close"});
            }
         }
         if(phase==6 && time.phase=="idle") {
            var released:Object=time.history.inspect();
            check(released.frames==0 && released.layers==0 && released.copies==0 && released.bindings.length==0,
               "completed replay releases all recorded frames and borrowed display bindings");
            check(replayClosed,"replay resumes after the confirmed shared SATS pause");
            check(target.hp<hp && time.hits.applied>start.applied && time.hits.pending==0,"replay consumes the deferred native hits once",{before:hp,after:target.hp,applied:time.hits.applied-start.applied,pending:time.hits.pending});
            check(JSON.stringify(ammo(s))==JSON.stringify(endAmmo),"replay spends neither player's ammunition twice");
            check(s.actors[0].unit.mana==endMana[0] && s.actors[1].unit.mana==endMana[1],"replay spends neither player's mana twice");
            check(s.actors[0].steps==endSteps[0] && s.actors[1].steps==endSteps[1],"replay does not run a second player simulation");
            if(++round<2)beginRound(s);else {
               check(replaySamples>8 && replayErrors==0,"native replay reproduces the recorded bodies and guns without stepping them",{samples:replaySamples,errors:replayErrors,deferred:s.runtime.deferredPresentations});
               check(access.world.gg===s.actors[0].unit && access.scope.depth==0 && !s.pause.paused,"shared time round trips restore the host's player context");
               s.link.send({type:"time-finish"});finish();
            }
         }
      }
      private function picture(time:Object):void {
         var key:String=String(time.cycle)+"-"+time.phase;if(pictures[key])return;pictures[key]=true;
         SceneChecks.picture(access,"time-pause-"+key+".png");
      }
   }
}
