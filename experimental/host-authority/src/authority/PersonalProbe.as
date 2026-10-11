package authority {
   /** Native menu intents, checkpoint unlock and two actual isolated save slots. */
   public final class PersonalProbe extends Probe {
      private var begin:int=-1,tick:uint=0,phase:int=0,ready:Boolean=false,point:Object,fy:Number;
      private var initialHost:Object,initialJoin:Object;
      public function PersonalProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;if(!host && begin>=0)frame.probeStart=begin;return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var w:Object=access.world;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;
            if(phase==0 && tick>35){phase=1;w.pers.addSkill("tele",2,true);}
            if(phase==1 && tick>70){phase=2;w.invent.favItem("r32",1);w.gg.changeWeapon("r32");}
            if(phase==2 && tick>140){phase=3;w.invent.usePotion("pot0",0);}
            if(phase==3 && tick>180){phase=4;w.saveGame(2);}
            if(phase==4 && tick>340) {
               phase=5;
               var saved:Object=w.getSave(2),auto:Object=w.getSave(w.autoSaveN);
               check(saved!=null && saved.est==1 && saved.invent.items.kofe==9 && saved.pers.skills.tele==2,
                  "join manual native slot contains its confirmed personal bag and learned skill",{slot:2,saved:saved==null?null:saved.est});
               check(auto!=null && auto.pers!=null && auto.pers.cp=="b-personal-fixture" && auto.invent.items.kofe==9,
                  "join native checkpoint autosave uses its own character");
               check(w.pers.currentCPCode=="b-personal-fixture" && w.gg.currentWeapon.id=="r32" && w.invent.fav[1]=="r32",
                  "join menus and HUD show confirmed checkpoint, weapon and favorite");
               SceneChecks.picture(access,"personal-confirmed.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=b.unit.loc;
         if(!ready) {
            ready=true;fy=Math.floor((room.limY-120)/40)*40-1;var row:int=int((fy+1)/40);
            for each(var oldUnit:Object in room.units)if(oldUnit!=null && !oldUnit.player){oldUnit.disabled=true;oldUnit.remVisual();}
            for(var x:int=1;x<room.spaceX-1;x++)for(var y:int=1;y<=row;y++) {
               var t:Object=room.space[x][y];t.phis=y==row?1:0;t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
               t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;t.visi=t.t_visi=1;
               if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
            }
            a.unit.setLocPos(200,fy);b.unit.setLocPos(500,fy);room.black=false;
            for each(var actor:PlayerActor in session.actors)access.scope.run(actor.context,function():void {
               actor.unit.invent.items.kofe.kol=actor.id==0?5:9;
               actor.unit.invent.items.pot0.kol=3;actor.unit.invent.addWeapon("r32");
               actor.unit.pers.skillPoint=10;actor.unit.pers.skills.tele=0;
            });
            initialHost={skill:a.unit.pers.skills.tele,points:a.unit.pers.skillPoint,pots:a.unit.invent.items.pot0.kol};
            initialJoin={points:b.unit.pers.skillPoint,pots:b.unit.invent.items.pot0.kol};
            var CheckPoint:Class=access.definition("fe.loc.CheckPoint");
            point=new CheckPoint(room,"checkpoint",650,fy,<obj/>,null);point.code="b-personal-fixture";
            // Native objs is Box-only (Unit.checkShelf casts every entry).
            room.acts.push(point);room.addObj(point);point.addVisual();
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         if(phase==0 && tick>115) {
            phase=1;
            check(b.unit.pers.skills.tele==2 && b.unit.pers.skillPoint==initialJoin.points-2 && b.unit.pers.maxTeleMassa>=1,
               "native join skill purchase executes once in its own host context");
            check(a.unit.pers.skills.tele==initialHost.skill && a.unit.pers.skillPoint==initialHost.points,
               "join skill purchase leaves host progression unchanged");
         }
         if(phase==1 && tick>220) {
            phase=2;
            check(b.unit.currentWeapon.id=="r32" && a.unit.currentWeapon.id=="lmg" && b.weaponEpoch>1 && session.inputs[1].weaponEpoch==b.weaponEpoch,
               "native menu equip updates the actual weapon incarnation without replacing host equipment");
            check(b.unit.invent.items.pot0.kol==initialJoin.pots-1 && a.unit.invent.items.pot0.kol==initialHost.pots,
               "native joining potion use spends only one item in its own bag");
            check(w.getSave(2)==null || w.getSave(2).est!=1,"remote manual save never writes the host's matching slot");
            b.unit.setLocPos(650,fy);
         }
         if(phase==2 && tick>325) {
            phase=3;
            check(point.active==2 && a.unit.pers.currentCP===point && b.unit.pers.currentCP===point,
               "a joining player activates one native checkpoint and both players retain it");
            var data:Object=w.getSave(w.autoSaveN);
            check(data!=null && data.pers!=null && data.pers.cp==point.code && data.invent.items.kofe==5,
               "shared checkpoint stores the host's own character in its native slot");
            check(access.scope.depth==0 && w.gg===a.unit,"personal UI and save operations restore host ownership");
         }
         if(tick>365)finish();
      }
   }
}
