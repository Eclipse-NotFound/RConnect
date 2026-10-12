package authority {
   import flash.filters.GlowFilter;
   import flash.utils.getTimer;
   /** Real player input drives native enemy lifting, limits and release.
    * The fixture never moves a target after its initial placement. */
   public final class EnemyGrabsProbe extends Probe {
      private static const CASES:Array=["host-regrab","join-regrab","throw","resistance","200-mana",
         "mana-empty","heavy","immune","199-mana","host-first","join-first","paused-hold","target-dies","local-menu"];
      private var ready:Boolean=false,phase:int=-1,owner:int=1,begin:int=-1,peerReady:int=-1,ending:int=-1;
      private var target:Object,second:Object,fy:Number,targetKey:uint=0,secondKey:uint=0;
      private var sent:int=-1,waiting:Boolean=false,report:Object,refs:Object={},counts:Object;
      private var held:int=0,otherHeld:int=0,secondHeld:int=0,thrown:int=0,minY:Number,manaBefore:Number;
      private var manaChanged:Boolean=false,menuOpened:Boolean=false,menuClosed:Boolean=false,menuAt:int=0;
      private var pauseRef:Object,pausedSamples:int=0,pauseStill:Boolean=true;
      private var killed:Boolean=false,localMenuFirst:int=-1,localMenuLast:int=-1;
      public function EnemyGrabsProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(v:Object):void {
         if(host && v.type=="enemy-grab-ready")peerReady=v.phase;
         if(host && v.type=="enemy-grab-report")report=v;
         if(!host && v.type=="enemy-grab-phase") {
            phase=v.phase;owner=v.owner;fy=v.floor;targetKey=v.target;secondKey=v.second;begin=ending=-1;refs={};
            counts={samples:0,missing:0,position:0,state:0,glow:0,held:0,ui:0};menuOpened=menuClosed=false;
         }
         if(!host && v.type=="enemy-grab-go")begin=v.tick;
         if(!host && v.type=="enemy-grab-reference")refs[v.tick]=v;
         if(!host && v.type=="enemy-grab-end")ending=v.tick;
         if(!host && v.type=="enemy-grab-finish")finish();
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         if(phase<0 || !isFinite(fy))return frame;
         frame.aimX=700;frame.aimY=fy-35;
         if(begin<0)return frame;
         var elapsed:int=(host?session.runtime.tick:RConnectMod.instance.replica.lastTick)-begin,id:int=host?0:1;
         if(id==owner) {
            if(elapsed>=18 && elapsed<23 || (phase<2 || phase==4 || phase>=9) && elapsed>=125 && elapsed<130)frame.buttons=Commands.TELE;
            if(elapsed>=30 && elapsed<125){frame.aimX=720;frame.aimY=fy-150;}
            if(phase==2 && elapsed>=80 && elapsed<85)frame.buttons=Commands.ACTION;
            if((phase<2 || phase==12) && elapsed>=140) {
               frame.aimX=820;frame.aimY=elapsed<160?fy-35:fy-150;
               if(elapsed>=145 && elapsed<150 || elapsed>=195 && elapsed<200)frame.buttons=Commands.TELE;
            }
         }else if((phase==9 || phase==10) && elapsed>=55 && elapsed<60) {
            var body:Object=host?target:RConnectMod.instance.replica.scene.units[targetKey].unit;
            frame.aimX=body.X;frame.aimY=body.Y-body.scY*.5;frame.buttons=Commands.TELE;
         }
         return frame;
      }
      private function hasGlow(unit:Object):Boolean {
         if(unit.vis==null)return false;
         for each(var f:Object in unit.vis.filters)if(f is GlowFilter)return true;return false;
      }
      private function source(session:HostSession):void {
         if(begin<0 || waiting)return;
         var g:Object=session.actors[owner].unit,other:Object=session.actors[1-owner].unit;
         if(g.teleObj===target)++held;if(other.teleObj===target)++otherHeld;
         if(g.teleObj===second)++secondHeld;if(target.t_throw>0)++thrown;minY=Math.min(minY,target.Y);
         session.link.send({type:"enemy-grab-reference",phase:phase,tick:session.runtime.tick,
            target:targetKey,x:target.X,y:target.Y,levit:target.levit,glow:hasGlow(target),
            held:g.teleObj===target,ui:owner==1 && g.teleObj!=null?{x:g.teleObj.X,y:g.teleObj.Y,mass:g.teleObj.massa,name:g.teleObj.nazv}:null});
      }
      private function confirmed(frame:Object):void {
         var ref:Object=refs[frame.tick];if(ref==null || ref.phase!=phase)return;
         var replica:ClientReplica=RConnectMod.instance.replica,record:Object=replica.scene.units[ref.target];
         ++counts.samples;if(ref.held)++counts.held;
         if(record==null){++counts.missing;return;}
         var body:Object=record.unit;
         if(Math.abs(body.X-ref.x)>.06 || Math.abs(body.Y-ref.y)>.06)++counts.position;
         if(body.levit!=ref.levit)++counts.state;
         if(hasGlow(body)!=ref.glow)++counts.glow;
         var info:Object=access.world.gg.teleObj;
         if(ref.ui!=null) {
            if(info==null || info.in_chain || info.vis!=null || Math.abs(info.X-ref.ui.x)>.06 || Math.abs(info.Y-ref.ui.y)>.06 ||
               info.massa!=ref.ui.mass || info.nazv!=ref.ui.name)++counts.ui;
         }else if(info!=null)++counts.ui;
      }
      private function enemy(session:HostSession,x:Number):Object {
         var Type:Class=access.definition("fe.unit.UnitRaider"),u:Object=new Type("1",10,<unit weap="lmg"/>,null),room:Object=session.actors[0].unit.loc;
         u.putLoc(room,x,fy);room.units.push(u);room.addObj(u);u.addVisual();u.setVisPos();u.animate();
         u.controlOn=false;u.invulner=true;u.doop=true;u.lootIsDrop=true;u.xp=0;
         u.hp=u.maxhp=10000;u.levitPoss=true;u.levit_max=10000;return u;
      }
      private function start(session:HostSession,index:int):void {
         phase=index;owner=index==0 || index==9?0:1;begin=peerReady=-1;waiting=false;report=null;
         held=otherHeld=secondHeld=thrown=pausedSamples=0;manaChanged=false;pauseRef=null;pauseStill=true;
         killed=false;localMenuFirst=localMenuLast=-1;
         for each(var a:PlayerActor in session.actors)a.unit.dropTeleObj();
         fy=ProbeArena.floor(session.actors[0].unit.loc);minY=fy;
         for each(a in session.actors)access.scope.run(a.context,function():void {
            var g:Object=a.unit;g.setLocPos(400+a.id*50,fy);g.dx=g.dy=0;g.invulner=true;
            g.pers.skills.tele=5;g.pers.setParameters();g.mana=g.maxmana=10000;g.dmana=0;
            g.pers.recMana=g.pers.recManaMin=0;g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;
            g.pers.unitLevitMult=1;g.pers.telemaster=1;g.pers.telePorog=0;g.pers.teleMult=1;g.pers.allDManaMult=1;
            g.pers.teleMana=0;g.pers.throwForce=12;g.pers.throwDmagic=2;g.pers.throwDmanaMult=0;g.pers.spellsPoss=1;
         });
         access.scope.run(session.actors[owner].context,function():void {target=enemy(session,700);second=enemy(session,820);});
         if(index==3)target.levit_max=18;
         if(index==6)target.massa=1100;
         if(index==7)target.levitPoss=false;
         if(index==4 || index==8)session.actors[owner].unit.mana=index==4?200:199;
         manaBefore=session.actors[owner].unit.mana;
         session.pause.policyMenus=index==11;
         targetKey=session.sceneId(target);secondKey=session.sceneId(second);
         session.link.send({type:"enemy-grab-phase",phase:phase,owner:owner,floor:fy,target:targetKey,second:secondKey});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready){ready=true;replica.confirmed=confirmed;}
            if(phase>=0 && sent!=phase){sent=phase;RConnectMod.instance.link.send({type:"enemy-grab-ready",phase:phase});}
            if((phase==11 || phase==13) && begin>=0 && replica.lastTick-begin>=55 && !menuOpened) {
               menuOpened=true;menuAt=getTimer();access.world.pip.onoff(5);
            }
            if(menuOpened && !menuClosed && getTimer()-menuAt>=1200){menuClosed=true;access.world.pip.onoff(-1);}
            if(ending>=0 && replica.displayFrame.tick>=ending) {
               check(counts.samples>80 && counts.missing==0 && counts.position==0 && counts.state==0,
                  "native held-enemy state is reproduced on its confirmed timeline: "+CASES[phase],counts);
               check(counts.glow==0 && counts.ui==0,"native glow and held-target UI match without a second physical object: "+CASES[phase],counts);
               check(access.world.gg.teleObj==null,"release clears join's native target label and throw-arrow reference: "+CASES[phase]);
               RConnectMod.instance.link.send({type:"enemy-grab-report",phase:phase});ending=-1;
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready) {
            ready=true;var publish:Function=session.runtime.afterStep;
            session.runtime.afterStep=function():void{source(session);publish();};start(session,0);return;
         }
         if(begin<0 && peerReady==phase){begin=session.runtime.tick;session.link.send({type:"enemy-grab-go",tick:begin});}
         if(begin<0)return;
         var elapsed:int=session.runtime.tick-begin,g:Object=session.actors[owner].unit;
         if(phase==5 && elapsed>=70 && !manaChanged){g.mana=0;g.dmana=0;manaChanged=true;}
         if(phase==12 && elapsed>=75 && !killed) {
            killed=true;target.invulner=false;
            access.scope.run(session.actors[owner].context,function():void{target.damage(100000,0,null,true);});
         }
         if(phase==13 && session.pause.remoteMenus) {
            if(localMenuFirst<0)localMenuFirst=session.runtime.tick;localMenuLast=session.runtime.tick;
         }
         if(phase==11 && session.pause.paused) {
            if(pauseRef==null)pauseRef={tick:session.runtime.tick,y:target.Y,mana:g.mana,resistance:target.levit_r};
            ++pausedSamples;pauseStill=pauseStill && session.runtime.tick==pauseRef.tick && target.Y==pauseRef.y &&
               g.mana==pauseRef.mana && target.levit_r==pauseRef.resistance;
         }
         if(elapsed>=225 && !waiting) {
            waiting=true;var rejected:Boolean=phase>=6 && phase<=8;
            check(rejected?held==0:held>5,"native grab eligibility: "+CASES[phase],{held:held,mana:manaBefore,mass:target.massa});
            if(!rejected)check(minY<fy-10 && g.mana<manaBefore,"native forces lift the enemy and spend the caster's own mana: "+CASES[phase],{rise:fy-minY,mana:g.mana});
            check(otherHeld==0,"another player never steals an accepted hold: "+CASES[phase],{competingHoldSteps:otherHeld});
            if(phase<2 || phase==12)check(secondHeld>15,"release permits a fresh grab of a different enemy: "+CASES[phase],{secondHeld:secondHeld});
            if(phase==12)check(killed && target.hp<=0 && target.sost>=3,
               "native target death during lifting does not prevent a subsequent fresh selection");
            if(phase==13)check(localMenuFirst>=0 && localMenuLast>localMenuFirst+3 && !session.pause.paused,
               "a local-only menu leaves the authoritative hold clock running until normal release",{first:localMenuFirst,last:localMenuLast});
            if(phase==2)check(thrown>0,"real action input throws the enemy through native collision lifetime",{throwSteps:thrown});
            if(phase==3)check(held<60,"enemy's native resistance ends the hold before the manual release");
            if(phase==5)check(held<85,"empty mana ends the native hold before the manual release");
            if(phase==11)check(pausedSamples>3 && pauseStill && !session.pause.paused && session.pause.epoch==2,
               "shared native menu freezes and resumes held enemy, resistance and caster mana",{samples:pausedSamples});
            check(g.teleObj==null && target.levit==0 && second.levit==0 && !hasGlow(target) && !hasGlow(second),
               "released enemies have no stale owner, levitation or halo: "+CASES[phase]);
            session.link.send({type:"enemy-grab-end",tick:session.runtime.tick});
         }
         if(waiting && report!=null && report.phase==phase) {
            if(phase+1<CASES.length)start(session,phase+1);
            else {session.pause.policyMenus=false;session.link.send({type:"enemy-grab-finish"});finish();}
         }
      }
   }
}
