package authority {
   import flash.utils.getQualifiedClassName;
   public final class MinesProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=0,fy:Number=0,hidden:Object,placed:Object,ready:Boolean=false;
      private var displayed:Boolean=false,disarmSeen:Boolean=false,hostStock:int,joinStock:int;
      private var loose:Object;
      public function MinesProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && begin>=0 && session!=null)tick=session.runtime.tick-begin;
         if(!host && begin>=0)frame.probeStart=begin;
         frame.actions=[];frame.buttons=!host && tick>=95 && tick<195?Commands.ACTION:0;
         frame.aimX=750;frame.aimY=fy-7;
         if(!host && tick>=225 && tick<325 && loose!=null){frame.buttons=Commands.ACTION;frame.aimX=loose.x;frame.aimY=loose.y-loose.h/2;}
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;fy=f.players[1].y;
            loose=null;for each(var effect:Object in f.scene.effects)if(effect.loot!=null && effect.loot.id=="mine")loose=effect.loot;
            for each(var rec:Object in replica.scene.units)if(getQualifiedClassName(rec.unit)=="fe.unit::Mine" && rec.unit.X>=700 && rec.unit.isVis)
               displayed=displayed || rec.unit.vis!=null && rec.unit.vis.parent!=null && rec.unit.vis.visible && rec.unit.vis.alpha>.9;
            if(tick>345) {
               check(displayed,"joining player renders a mine revealed beyond the host's line of sight");
               check(access.world.invent.items.mine.kol==1,"join receives the one native disarmed mine pickup");
               SceneChecks.picture(access,"mine-joining-exploration.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=a.unit.loc;
         if(!ready) {
            ready=true;fy=ProbeArena.floor(room,10);a.unit.setLocPos(200,fy);b.unit.setLocPos(700,fy);
            access.scope.run(b.context,function():void {b.unit.pers.skills.explosives=20;b.unit.pers.setParameters();});
            var Mine:Class=access.definition("fe.unit.Mine");
            access.scope.run(b.context,function():void {
               hidden=new Mine("mine");hidden.putLoc(room,850,fy);room.addObj(hidden);room.units.push(hidden);
               hidden.fixed=true;hidden.sens=0;hidden.oduplenie=0;hidden.setVis(false);hidden.addVisual();
            });
            a.unit.invent.items.mine.kol=3;b.unit.invent.items.mine.kol=0;hostStock=3;joinStock=0;
            session.combat.enabled=true;
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         if(phase==0 && tick>60) {
            phase=1;
            var hostSees:Boolean=Boolean(access.scope.run(a.context,function():Boolean{return a.unit.lookInvis(hidden);}));
            var joinSees:Boolean=Boolean(access.scope.run(b.context,function():Boolean{return b.unit.lookInvis(hidden);}));
            check(!hostSees && joinSees && hidden.isVis,"native mine detection uses the joining occupant beyond a blocking wall",{host:hostSees,join:joinSees,revealed:hidden.isVis});
            hidden.disabled=true;hidden.remVisual();
            access.scope.run(a.context,function():void {
               var Weapon:Class=access.definition("fe.weapon.Weapon"),weapon:Object=Weapon["create"](a.unit,"mine",0);
               var old:Object=a.unit.currentWeapon;weapon.setPers(a.unit,a.unit.pers);weapon.lvl=0;weapon.addVisual();a.unit.currentWeapon=weapon;
               a.unit.celX=240;a.unit.celY=fy;weapon.step();weapon.attack(true);weapon.step();weapon.remVisual();a.unit.currentWeapon=old;
               for each(var u:Object in room.units)if(NativeAccess.get(u,"rconnectOwner")===a.unit)placed=u;
            });
            check(placed!=null && placed.rconnectOwner===a.unit,"host places a real mine with its native owner");
            if(placed!=null){placed.setPos(750,fy);placed.dx=placed.dy=0;placed.fixed=true;placed.sens=0;placed.reloadTime=0;placed.oduplenie=0;placed.setVis(true);}
         }
         if(placed!=null && b.unit.actionObj===placed.inter)disarmSeen=true;
         if(phase==1 && tick>210) {
            phase=2;check(disarmSeen && placed!=null && placed.sost==4 && placed.disabled,"join completes the original mine-disarming action on a teammate's mine",
               {started:disarmSeen,state:placed==null?null:placed.sost,skill:b.unit.pers.remine});
            b.unit.setLocPos(750,fy);
         }
         if(phase==2 && tick>335) {
            phase=3;check(a.unit.invent.items.mine.kol==hostStock-1 && b.unit.invent.items.mine.kol==joinStock+1,
               "disarming and picking up transfers exactly one mine between independent bags",{host:a.unit.invent.items.mine.kol,join:b.unit.invent.items.mine.kol});
            check(access.world.gg===a.unit && access.scope.depth==0,"mine discovery and disarming restore the host's player context");
         }
         if(tick>365)finish();
      }
   }
}
