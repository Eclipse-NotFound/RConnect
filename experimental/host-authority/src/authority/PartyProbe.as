package authority {
   import flash.utils.getQualifiedClassName;
   /** Real pet calls, native background exits and native joint challenge entry. */
   public final class PartyProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=0,home:Object,back:Object,challengeRoom:Object,challengeId:String;
      private var ground:Array=[],pets:Array=[],sentinel:Object,initialOwner:Object,backVisits:int=0;
      private var sawSplit:Boolean=false,sawTogether:Boolean=false,sawChallenge:Boolean=false,sawPet:Boolean=false;
      public function PartyProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && begin>=0 && session!=null)tick=session.runtime.tick-begin;
         if(!host && begin>=0)frame.probeStart=begin;
         frame.buttons=0;frame.actions=[];
         frame.settings.follow=host?tick>=40 && tick<160:tick>=180 && tick<260;
         return frame;
      }
      private function exit(actor:PlayerActor,y:Number):void {
         actor.context.t_battle=actor.context.transitionCooldown=0;actor.unit.loc.t_alarm=0;
         if(actor.id==0)access.world.t_battle=0;
         access.scope.run(actor.context,function():void {check(actor.unit.outLoc(5,500,y),"native background exit accepted for player "+actor.id);});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;
            sawSplit=sawSplit || f.players[0].room!==f.players[1].room;
            sawTogether=sawTogether || tick>65 && f.players[0].room===f.players[1].room;
            sawChallenge=sawChallenge || f.scene.fields.landProb!="";
            var pet:Object=replica.scene.petFor(1);
            if(pet!=null && pet.vis!=null && pet.vis.parent!=null) {
               sawPet=true;
               if(access.world.gg.pet!==pet)check(false,"join pet HUD points to its confirmed native pet");
            }
            if(tick>405) {
               check(sawSplit && sawTogether && sawChallenge,"join confirms ordinary separation, following and joint challenge travel");
               check(sawPet,"join displays its own confirmed pet and binds its HUD to that entity");
               check(f.players[0].epoch==1 && f.players[1].epoch==1,"party actions keep both original player incarnations");
               SceneChecks.picture(access,"party-follow-pets.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],r:RoomRuntime=session.runtime,land:Object=access.world.land;
         if(home==null) {
            initialOwner=a.unit;
            for each(var col:Array in land.locs)for each(var row:Array in col)if(row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky){home=row[0];back=row[1];break;}
            if(home==null)throw new Error("Party probe requires a native foreground/background pair");
            ground=[ProbeArena.floor(home),ProbeArena.floor(back)];home.petOn=back.petOn=true;
            r.transfers.relocate(a,home,400,ground[0]);r.transfers.relocate(b,home,550,ground[0]);r.rooms.showHost();
            var Zombie:Class=access.definition("fe.unit.UnitZombie");
            access.scope.run(a.context,function():void {
               sentinel=new Zombie("zombie",10,<unit/>,null);sentinel.putLoc(home,1000,ground[0]);sentinel.disabled=true;home.units.push(sentinel);
            });
            for each(var actor:PlayerActor in session.actors)access.scope.run(actor.context,function():void {
               actor.unit.callPet(actor.id==0?"phoenix":"owl",true);pets.push(actor.unit.pet);
            });
            check(home.units.indexOf(sentinel)>=0 && home.units.indexOf(a.unit)>=0 && home.units.indexOf(b.unit)>=0,
               "native pet summon preserves both players and an existing enemy roster");
            check(pets[0]!=null && pets[1]!=null && pets[0]!==pets[1],"each player summons its own native pet");
            for each(var candidate:Object in land.listLocs)if(candidate.landProb!="" && candidate.prob!=null){challengeRoom=candidate;break;}
            if(challengeRoom==null) {
               for each(var xml:XML in access.world.game.probs["prob"].allroom.room) {
                  land.buildProb(String(xml.@name));
                  var grid:Array=land.probs[String(xml.@name)];
                  if(grid!=null && grid[0][0][0].prob!=null){challengeRoom=grid[0][0][0];break;}
               }
            }
            if(challengeRoom==null)throw new Error("Native challenge fixture unavailable");
            challengeId=challengeRoom.landProb;return;
         }
         if(begin<0)return;tick=r.tick-begin;
         if(phase==0 && tick>60){phase=1;exit(b,ground[1]);}
         if(phase==1 && tick>90) {
            phase=2;check(a.unit.loc===back && b.unit.loc===back && access.world.gg===initialOwner && a.unit.ggControl,
               "host follows join through a background door while retaining its own controlled player");
            for(var i:int=0;i<2;i++)check(pets[i].loc===back && back.units.indexOf(pets[i])>=0 && !pets[i].in_chain,
               "pet follows its owner and remains outside the once-per-room object chain player "+i);
            check(back.units.indexOf(a.unit)>=0 && back.units.indexOf(b.unit)>=0,"pet arrival does not replace either player");
         }
         if(phase==2 && tick>165){phase=3;exit(b,ground[0]);}
         if(phase==3 && tick>195){phase=4;check(a.unit.loc===back && b.unit.loc===home,"turning follow off allows ordinary independent rooms");exit(a,ground[0]);}
         if(phase==4 && tick>220){phase=5;exit(a,ground[1]);}
         if(phase==5 && tick>250) {
            phase=6;check(a.unit.loc===back && b.unit.loc===back,"joining player follows the host's next ordinary room change");
            access.scope.run(b.context,function():void {land.gotoProb(challengeId);});
         }
         if(phase==6 && tick>280) {
            phase=7;check(a.unit.loc===back && b.unit.loc===back,"join cannot independently start a native challenge");
            challengeRoom.broom=true;
            access.scope.run(a.context,function():void {land.gotoProb(challengeId);});
         }
         if(phase==7 && tick>315) {
            phase=8;check(a.unit.loc===challengeRoom && b.unit.loc===challengeRoom && !challengeRoom.broom,
               "host starts a shared native challenge and runs its original entry logic");
            access.scope.run(a.context,function():void {land.gotoProb("");});
         }
         if(phase==8 && tick>350) {
            phase=9;check(a.unit.loc===back && b.unit.loc===back && access.world.gg===initialOwner && a.unit.ggControl && b.unit.ggControl,
               "native challenge return restores the party without replacing player controls");
            check(pets[0].loc===back && pets[1].loc===back && !pets[0].in_chain && !pets[1].in_chain,
               "both pets survive challenge round trip without duplicate stepping");
            check(home.units.indexOf(sentinel)>=0 && sentinel.hp>0,"party travel never overwrites an unrelated retained enemy");
         }
         if(tick>425)finish();
      }
   }
}
