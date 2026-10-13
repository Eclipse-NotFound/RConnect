package authority {
   import flash.utils.getQualifiedClassName;
   /** Real special weapons through normal B input, without testInstance. */
   public final class MswProbe extends Probe {
      private var cases:Array=["pointer-safe","pointer-peer","laser-enemy","laser-peer","flash","smart","launcher"];
      private var phase:int=-1,begin:int=-1,peerReady:int=-1,ending:int=-1,sent:int=-1,owner:int;
      private var ready:Boolean=false,waiting:Boolean=false,report:Object;
      private var aimX:Number=0,aimY:Number=0,target:Object,shooter:PlayerActor,initial:Array;
      private var litTicks:int=0,lastTick:int=-1,parts:int=0,blinded:Boolean=false,locked:Boolean=false,flashSeen:Boolean=false;
      private var clientSamples:int=0,clientErrors:int=0;
      private var initialSpawns:int=0,initialFlash:int=0;
      private var stagedAt:int=0;
      private var directEye:Boolean=false;
      private var pointerClick:int=0;
      public function MswProbe(a:NativeAccess,h:Boolean,sweep:Boolean=false){super(a,h);if(sweep)cases=["pointer-sweep-safe","pointer-sweep-peer"];}
      private function kind():String{return phase<0?"":cases[int(phase/2)];}
      override public function message(v:Object):void {
         if(host && v.type=="msw-ready")peerReady=v.phase;
         if(host && v.type=="msw-report")report=v;
         if(!host && v.type=="msw-phase"){phase=v.phase;owner=v.owner;aimX=v.x;aimY=v.y;begin=ending=-1;clientSamples=clientErrors=0;pointerClick=0;}
         if(!host && v.type=="msw-go"){begin=v.tick;aimX=v.x;aimY=v.y;}
         if(!host && v.type=="msw-end")ending=v.tick;
         if(!host && v.type=="msw-finish")finish();
      }
      override public function input(f:Object,s:HostSession):Object {
         f.buttons=0;f.actions=[];
         if(f.msw!=null) {
            var c:Object=f.msw.settings;c.pointerRate=host?1:3;c.laserAmmo=host?1:2;c.laserAssist=false;c.laserNonFront=false;
            c.laserDuration=c.pointerDuration=3;c.smartEnabled=kind()=="smart";c.smartAcquire=.1;
            c.wallHits=kind()=="launcher"?2:0;c.flashFuse=.6;c.flashDuration=2;c.flashHold=.3;c.flashFade=1;
         }
         if(phase<0 || begin<0)return f;
         f.aimX=aimX;f.aimY=aimY;
         var elapsed:int=(host?s.runtime.tick:RConnectMod.instance.replica.lastTick)-begin;
         if((host?0:1)!=owner)return f;
         if(kind().indexOf("sweep")>=0)f.aimY=aimY+(elapsed<40?-160:235);
         if(kind().indexOf("pointer")==0) {
            // Confirmations can jump over a short host-tick window. Emit each
            // real press once after its deadline, with a separate local input
            // frame for release. Commands preserves the transmitted edge.
            if(pointerClick==1 || pointerClick==3)++pointerClick;
            else if(pointerClick==0 && elapsed>=15 || pointerClick==2 && elapsed>=65){f.buttons=Commands.FIRE;++pointerClick;}
         }
         else if(kind()=="flash"){if(elapsed>=20 && elapsed<30)f.buttons=Commands.GRENADE;}
         else if(elapsed>=25 && elapsed<31)f.buttons=Commands.FIRE;
         return f;
      }
      private function energy(s:HostSession,id:int):Number {
         var state:Object=access.weapons.snapshot(id).state;
         return Number(s.actors[id].unit.invent.items.batt.kol)+Number(state.msw_pointer_charge_v1 || 0);
      }
      private function blind(u:Object):Boolean {for each(var e:Object in u.effects)if(e.id=="blindness" && !e.vse)return true;return false;}
      private function start(s:HostSession,index:int):void {
         phase=index;owner=phase%2;shooter=s.actors[owner];begin=peerReady=-1;waiting=false;report=null;
         stagedAt=s.runtime.tick;
         litTicks=parts=pointerClick=0;blinded=locked=flashSeen=directEye=false;initial=[];
         var fy:Number=ProbeArena.floor(shooter.unit.loc,25);
         RConnectMod.instance.preferences.setValue("friendlyFire",kind().indexOf("peer")>=0 || kind()=="flash"?"1":"0");RConnectMod.instance.applyPreferences();
         for each(var a:PlayerActor in s.actors)access.scope.run(a.context,function():void {
            var g:Object=a.unit;g.pers.skills.explosives=100;g.pers.setParameters();g.remEffect("blindness");g.setLocPos(a.id==owner?400:700,fy);g.dx=g.dy=0;
            g.invulner=true;g.ggControl=true;g.hp=g.maxhp=10000;g.shithp=0;g.stun=g.t_culd=0;
            g.storona=a.id==owner?1:-1;g.invent.items.batt.kol=100;g.invent.items.gren40.kol=100;
         });
         var id:String=kind().indexOf("pointer")==0?"mswlaserpointer":kind().indexOf("laser")==0?"mswdazzler":kind()=="launcher"?"mswglau":"lmg";
         access.scope.run(shooter.context,function():void {
            var g:Object=shooter.unit,wp:Object=g.invent.weapons[id];
            if(wp==null)throw new Error("MSW did not provision real weapon: "+id);
            // Selecting the already equipped gun is vanilla's holster action.
            if(g.currentWeapon!==wp)g.changeWeapon(id,true);
            if(g.currentWeapon!==wp)throw new Error("Native MSW fixture equip rejected: "+id);
            g.work="";g.t_work=0;wp.loc=g.loc;wp.setPers(g,g.pers);wp.hp=wp.maxhp;wp.hold=12;
            if(kind()=="flash"){g.invent.items.mswflash.kol=20;g.throwWeapon=g.invent.weapons.mswflash;g.invent.fav[29]="mswflash";}
         });
         target=s.actors[1-owner].unit;
         if(kind()=="laser-enemy" || kind()=="smart") {
            s.actors[1-owner].unit.setLocPos(160,fy);
            var Type:Class=access.definition("fe.unit.UnitZombie");target=new Type("1",10,<unit tr="1" dig="0"/>,null);
            target.putLoc(shooter.unit.loc,750,fy);shooter.unit.loc.units.push(target);shooter.unit.loc.addObj(target);
            target.hp=10000;target.stun=10000;target.fixed=true;target.storona=-1;target.addVisual();
         }
         // MSW lives in a separate loader domain. Its independent read-only
         // diagnostic reports the real visible eye without exposing classes.
         var point:Object=access.weapons.inspectTarget(target).eye;
         aimX=kind()=="launcher"?1000:kind()=="flash"?590:point.x;aimY=kind()=="flash"?fy-10:point.y;
         s.link.send({type:"msw-phase",phase:phase,owner:owner,x:aimX,y:aimY});
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null || phase<0)return;
            if(sent!=phase){sent=phase;RConnectMod.instance.link.send({type:"msw-ready",phase:phase});}
            var f:Object=r.displayFrame,msw:Object=f.character.msw;
            if(msw!=null){++clientSamples;for(var k:String in msw.state)if(msw.state[k]!==access.world.game.triggers[k])++clientErrors;}
            if(ending>=0 && f.tick>=ending) {
               check(clientSamples>30 && clientErrors==0,"MSW confirmed personal state "+kind()+" owner "+owner,{samples:clientSamples,errors:clientErrors});
               check(access.weapons.inspect().role=="join" && access.weapons.inspect().actors==0,"join owns no authoritative MSW execution services");
               RConnectMod.instance.link.send({type:"msw-report",phase:phase});ending=-1;
            }return;
         }
         if(s==null || !s.active)return;
         if(!ready){ready=true;check(access.weapons!=null && access.weapons.inspect().actors==2,"MSW API registers two native actors");start(s,0);return;}
         if(begin<0 && peerReady==phase && s.runtime.tick-stagedAt>=20) {
            begin=s.runtime.tick;lastTick=begin;
            if(kind()!="launcher" && kind()!="flash") {
               var eye:Object=access.weapons.inspectTarget(target).eye;aimX=eye.x;aimY=eye.y;
            }
            for(var id:int=0;id<2;id++)initial.push({energy:energy(s,id),ammo:s.actors[id].unit.currentWeapon.hold,hp:s.actors[id].unit.hp});
            initialSpawns=s.runtime.spawnsFor(shooter.unit);
            var prior:Array=access.weapons.snapshot(1-owner).flash;
            initialFlash=prior.length==0?0:prior[prior.length-1].id;
            s.link.send({type:"msw-go",tick:begin,x:aimX,y:aimY});
         }
         if(begin<0)return;
         var elapsed:int=s.runtime.tick-begin,state:Object=access.weapons.snapshot(owner);
         if(elapsed==25 || elapsed==31)Log.write("msw-shot-context",{phase:phase,aim:[aimX,aimY],eye:access.weapons.inspectTarget(target),
            target:NativeFields.capture(target),weapon:NativeFields.capture(shooter.unit.currentWeapon)});
         if(s.runtime.tick!=lastTick){lastTick=s.runtime.tick;if(state.pointer)++litTicks;}
         blinded=blinded || (target.player?blind(target):target.vision==0);
         if(kind().indexOf("sweep")>=0 && state.pointer) {
            var lastHit:String=access.weapons.inspect().diagnostics[String(owner)].pointerLastHit;
            directEye=directEye || lastHit=="blind" || lastHit=="ineligible";
         }
         if(state.smart!=null)for each(var lock:Object in state.smart.locks)if(lock.target!=null)locked=true;
         for each(var exposure:Object in access.weapons.snapshot(1-owner).flash)if(exposure.id>initialFlash)flashSeen=true;
         for(var o:Object=shooter.unit.loc.firstObj;o!=null;o=o.nobj)if(o.vis!=null && (getQualifiedClassName(o).indexOf("MSW")>=0 || o.vis.name=="MSWLaserBeam"))++parts;
         if(elapsed>=130 && !waiting) {
            waiting=true;var delta:Number=initial[owner].energy-energy(s,owner);
            if(kind().indexOf("pointer")==0) {
               check(litTicks>20 && Math.abs(delta-litTicks/30*(owner==0?1:3))<.15,"pointer pays its own configured rate and illuminated time",{ticks:litTicks,energy:delta});
               check(!state.pointer,"two native pointer clicks leave the owned light off",{phase:phase,owner:owner,lit:state.pointer,ticks:litTicks});
               check(Math.abs(initial[1-owner].energy-energy(s,1-owner))<.0001,"peer battery and prepaid remainder are independent",
                  {phase:phase,initial:initial[1-owner].energy,actual:energy(s,1-owner),peerPointer:access.weapons.snapshot(1-owner).pointer});
            }
            if(kind().indexOf("safe")>=0)check(!blinded,"friendly fire off rejects real pointer eye exposure");
            if(kind().indexOf("peer")>=0)check(blinded && target.ggControl,"friendly optics restrict sight and retain player control");
            if(kind().indexOf("sweep")>=0)check(!directEye,"fast sweep's endpoint rays do not directly hit a visible eye",{directEye:directEye,blinded:blinded});
            if(kind()=="laser-enemy")check(blinded && parts>0,"native dazzler creates beam and enemy blindness");
            if(kind().indexOf("laser")==0)check(initial[owner].ammo-shooter.unit.currentWeapon.hold==(owner==0?1:2),"dazzler spends firing player's configured ammo once");
            if(kind()=="flash")check(flashSeen && parts>0,"native flash throw produces peer exposure and world pulse");
            if(kind()=="smart")check(locked && s.runtime.spawnsFor(shooter.unit)>initialSpawns,"own smart lock and native shots execute on host");
            if(kind()=="launcher")check(s.runtime.spawnsFor(shooter.unit)>initialSpawns && shooter.unit.currentWeapon.hold<initial[owner].ammo,"programmable launcher fires in owning native context",
               {nativeSkill:shooter.unit.pers.getWeapLevel(shooter.unit.currentWeapon.skill),required:shooter.unit.currentWeapon.lvl,spawns:s.runtime.spawnsFor(shooter.unit)-initialSpawns,ammo:[initial[owner].ammo,shooter.unit.currentWeapon.hold]});
            var diagnostic:Object=access.weapons.inspect(),errors:Object={};
            for(var who:String in diagnostic.diagnostics)for(var field:String in diagnostic.diagnostics[who])
               if(/error/i.test(field) && diagnostic.diagnostics[who][field])errors[who+":"+field]=diagnostic.diagnostics[who][field];
            check(JSON.stringify(errors)=="{}","MSW services report no suppressed runtime error",errors);
            Log.write("msw-diagnostics",diagnostic);s.link.send({type:"msw-end",tick:s.runtime.tick});
         }
         if(waiting && report!=null && report.phase==phase) {
            if(phase+1<cases.length*2)start(s,phase+1);else{s.link.send({type:"msw-finish"});finish();}
         }
      }
   }
}
