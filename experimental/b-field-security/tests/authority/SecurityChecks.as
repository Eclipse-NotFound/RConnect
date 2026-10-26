package authority {
   /** Destructive fixture ONLY for an explicitly enabled, isolated B probe.
    * Call once after both native players are assembled in the same room.
    * It exercises real native Interact.act/allAct/hack/findCel and hit policy.
    * It does not establish real projectile, UI, revisit or timing qualification. */
   public final class SecurityChecks {
      private static var session:HostSession,check:Function,room:Object,fixtures:Array;
      private static function fixture():Object {
         var Box:Class=session.access.definition("fe.loc.Box"),Turret:Class=session.access.definition("fe.unit.UnitTurret");
         var a:Object=session.actors[0].unit;
         var box:Object=new Box(room,"term1",a.X+60,a.Y);
         box.inter.lock=3;box.inter.lockLevel=1;box.inter.lockAtt=-100;box.inter.at_once=0;box.inter.update();
         room.objs.push(box);room.addObj(box);
         var turret:Object=new Turret("",100,<unit tr="1" vis="right"/>,null);
         turret.id="b-security-check-"+fixtures.length;turret.putLoc(room,a.X+100,a.Y);
         turret.fixed=turret.stay=true;turret.doop=false;turret.lootIsDrop=true;turret.xp=17;
         turret.hp=turret.maxhp=1000;turret.vision=500;turret.overLook=true;turret.oduplenie=0;
         turret.vKonus=0;turret.eyeX=turret.X;turret.eyeY=turret.Y-30;
         room.units.push(turret);room.addObj(turret);
         var f:Object={box:box,turret:turret};fixtures.push(f);return f;
      }
      private static function queue(f:Object,id:int,success:Boolean=true):void {
         var actor:PlayerActor=session.actors[id],inter:Object=f.box.inter;
         session.access.scope.run(actor.context,function():void {
            session.security.player(actor,function():void {
               inter.unlock=success?100:0;inter.master=success?100:0;
               inter.is_ready=true;inter.is_act=true;
            });
         });
      }
      private static function act(f:Object,id:int,success:Boolean=true):void {
         queue(f,id,success);session.security.stepObject(room,f.box);
      }
      private static function unlockAndActivate(f:Object,id:int):void {act(f,id);act(f,id);}
      private static function view(f:Object,id:int):Object{return session.security.capture(f.box.inter,id);}
      private static function finishFixture(f:Object):void {
         for each(var o:Object in [f.box,f.turret]) {
            o.remVisual();room.remObj(o);if("disabled" in o)o.disabled=true;
            var list:Array=o===f.box?room.objs:room.units,index:int=list.indexOf(o);
            if(index>=0)list.splice(index,1);
         }
      }
      private static function samePermission(f:Object,host:Boolean,join:Boolean,label:String):void {
         check(session.security.permission(f.turret,session.actors[0].unit)===host &&
               session.security.permission(f.turret,session.actors[1].unit)===join,label);
      }
      public static function run(s:HostSession,assertion:Function):void {
         if(!RConnectMod.instance.config.probe || s==null || !s.active || s.actors.length!=2)
            throw new Error("SecurityChecks requires an explicit isolated active B probe");
         session=s;check=assertion;room=s.actors[0].unit.loc;fixtures=[];
         if(s.actors[1].unit.loc!==room)throw new Error("Security checks require a common fixture room");
         var defaults:Boolean=s.security.shared,old:Array=[],actor:PlayerActor;
         for each(actor in s.actors)old.push({skill:actor.unit.pers.security,attempts:actor.unit.pers.hackAtt,
            invulner:actor.unit.invulner,obs:actor.unit.obs,x:actor.unit.X,y:actor.unit.Y});
         var fy:Number=ProbeArena.floor(room),f:Object,Unit:Class=s.access.definition("fe.unit.Unit");
         try {
            s.security.resetWorld();check(defaults,"security defaults to shared hacking in fresh probe preferences");
            for each(actor in s.actors) {
               actor.unit.setLocPos(400+actor.id*40,fy);actor.unit.invulner=false;
               actor.unit.obs=actor.unit.maxObs;actor.unit.pers.security=0;
               actor.unit.pers.hackAtt=actor.id==0?7:3;
            }
            s.security.shared=false;f=fixture();act(f,0,false);
            check(view(f,0).lockAtt==6 && view(f,1).lockAtt==-100,"host failed attempt does not spend join attempts");
            act(f,1,false);
            check(view(f,0).lockAtt==6 && view(f,1).lockAtt==2,"join attempt uses join hackAtt and preserves host counter");
            var steps:int=0,wrapper:Object={inter:f.box.inter,step:function():void{++steps;f.box.step();}};
            queue(f,0);queue(f,1);s.security.stepObject(room,wrapper);
            check(steps==1 && view(f,0).lock==0 && view(f,1).lock==0,"two completed personal hacks consume one physical object step");
            finishFixture(f);

            f=fixture();unlockAndActivate(f,1);
            samePermission(f,false,true,"individual low-skill join activation protects only join");
            check(!f.turret.rconnectSecurityState().sleep && !f.turret.rconnectSecurityState().reprog,
                  "individual low-skill hack does not globally sleep the turret");
            check(view(f,0).lock>0 && view(f,1).lock==0,"personal terminal lock is presented separately");
            check(!Unit["rconnectHitPolicy"](f.turret,s.actors[1].unit,true,"test") &&
                  Unit["rconnectHitPolicy"](f.turret,s.actors[0].unit,false,"test"),
                  "real installed hit policy blocks protected join and allows unprotected host");
            s.security.shared=true;act(f,1);
            samePermission(f,false,true,"switching to shared then reusing old activation does not retroshare");
            s.security.shared=false;unlockAndActivate(f,0);
            samePermission(f,true,true,"other player can independently earn existing turret permission");
            check(f.turret.rconnectSecurityState().sleep,"two low-skill personal grants allow native global sleep");
            finishFixture(f);

            s.security.shared=true;f=fixture();unlockAndActivate(f,1);
            samePermission(f,true,true,"shared join activation protects both real players");
            check(view(f,0).lock==0 && view(f,1).lock==0 && f.turret.rconnectSecurityState().sleep,
                  "shared low-skill activation unlocks both personal terminals and sleeps turret");
            s.security.shared=false;s.security.player(s.actors[1],function():void{});
            samePermission(f,true,true,"switching to individual preserves earned shared permission");
            finishFixture(f);

            for(var skill:int=1;skill<=2;skill++) {
               s.security.shared=false;s.actors[1].unit.pers.security=skill;s.actors[0].unit.pers.security=0;
               f=fixture();unlockAndActivate(f,1);
               samePermission(f,false,true,"skill "+skill+" join activation remains individual");
               check(f.turret.rconnectSecurityState().reprog && f.turret.fraction==100 && f.turret.xp==0,
                     "join pers.security "+skill+" executes native reprogram and consumes native XP exactly once");
               check(Unit["rconnectHitPolicy"](s.actors[0].unit,f.turret,false,"test"),
                     "unprotected player may counterattack reprogrammed same-faction turret "+skill);
               f.turret.priorUnit=f.turret.celUnit=s.actors[1].unit;
               s.access.scope.run(s.actors[0].context,function():void {f.turret.findCel(true);});
               check(f.turret.celUnit===s.actors[0].unit && f.turret.priorUnit!==s.actors[1].unit,
                     "native findCel clears protected target and detects unprotected real player "+skill);
               finishFixture(f);
            }
            s.security.shared=false;f=fixture();f.turret.hack(0);unlockAndActivate(f,1);
            check(s.security.permission(f.turret,s.actors[0].unit)===null && f.turret.rconnectSecurityState().sleep,
                  "saved or scripted global sleep is not narrowed into personal access");finishFixture(f);
            check(s.access.scope.depth==0 && s.access.world.gg===s.actors[0].unit && s.access.world.pers===s.actors[0].unit.pers,
                  "security native calls restore host world and character context");
         } finally {
            for each(f in fixtures)finishFixture(f);
            for each(actor in s.actors) {
               var original:Object=old[actor.id];actor.unit.pers.security=original.skill;actor.unit.pers.hackAtt=original.attempts;
               actor.unit.invulner=original.invulner;actor.unit.obs=original.obs;
            }
            s.security.shared=defaults;s.security.resetWorld();session=null;check=null;room=null;fixtures=null;
         }
      }
   }
}
