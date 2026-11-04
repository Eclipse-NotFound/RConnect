package authority {
   /** Four real grab/throw/collision trials, both victims and both consent values. */
   public final class ThrowProbe extends Probe {
      private var tick:int=0,begin:int=-1,trial:int=-1,checked:int=-1,fy:Number=0,initialHP:Number=0,armCount:uint=0;
      private var ready:Boolean=false,held:Boolean=false,airborne:Boolean=false,seenClientThrow:Boolean=false;
      public function ThrowProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && session!=null && begin>=0)tick=session.runtime.tick-begin;
         if(!host && begin>=0)frame.probeStart=begin;
         var part:int=int(tick/170),within:int=tick%170,shooter:int=part<2?1:0;
         frame.actions=[];frame.buttons=0;frame.aimX=400;frame.aimY=fy-35;
         frame.settings={allowGrab:true,struggle:false,thrownDamage:part%2==1,follow:false};
         if(begin>=0 && (host?0:1)==shooter) {
            if(within>=20 && within<24)frame.buttons=Commands.TELE;
            if(within>=60 && within<64)frame.buttons=Commands.ACTION;
         }
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;fy=f.players[1].y;
            if(f.players[0].native.t_throw>0 || f.players[1].native.t_throw>0)seenClientThrow=true;
            if(tick>690) {
               check(seenClientThrow,"join displays a confirmed native teammate throw");
               check(f.players[0].hp<10000 && f.players[1].hp<10000,"both victims confirm enabled native impact damage");
               finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var room:Object=session.actors[0].unit.loc,actor:PlayerActor;
         if(!ready) {
            ready=true;fy=Math.floor((room.limY-120)/40)*40-1;var row:int=int((fy+1)/40);
            for each(var u:Object in room.units)if(u!=null && !u.player){u.disabled=true;u.remVisual();}
            for(var x:int=6;x<28;x++)for(var y:int=row-6;y<=row;y++) {
               var t:Object=room.space[x][y];t.phis=(y==row || x==7)?1:0;t.visi=t.t_visi=1;t.water=0;t.shelf=false;
               t.diagon=t.stair=0;t.door=t.trap=null;t.indestruct=true;
               t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
               if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
            }
            room.black=false;
            for each(actor in session.actors)access.scope.run(actor.context,function():void {
               actor.unit.pers.skills.tele=5;actor.unit.pers.perks.telethrow=1;actor.unit.pers.setParameters();
               actor.unit.hp=actor.unit.maxhp=10000;actor.unit.mana=actor.unit.maxmana=10000;actor.unit.invulner=false;
               actor.unit.damWall=0;actor.unit.setPos(actor.id==0?400:600,fy);
            });
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         var part:int=int(tick/170),within:int=tick%170;
         if(part>=4){if(tick>710)finish();return;}
         var victim:PlayerActor=session.actors[part<2?0:1],holder:PlayerActor=session.actors[1-victim.id];
         if(trial!=part) {
            trial=part;held=airborne=false;initialHP=victim.unit.hp;armCount=session.grips.flights.armed;
            for each(actor in session.actors) {
               actor.unit.dropTeleObj();actor.unit.t_throw=0;actor.unit.stun=0;actor.unit.dx=actor.unit.dy=0;
               actor.unit.setPos(actor===victim?400:600,fy);
            }
         }
         held=held || holder.unit.teleObj===victim.unit;
         airborne=airborne || victim.unit.t_throw>0;
         if(within>125 && checked!=part) {
            checked=part;
            check(held && airborne && session.grips.flights.armed>armCount,"native grab and throw execute trial "+part,
               {held:held,airborne:airborne,armed:session.grips.flights.armed,force:holder.unit.pers.throwForce});
            check(victim.unit.t_throw==0 && victim.unit.X<365,"native wall collision terminates the throw trial "+part,
               {x:victim.unit.X,t:victim.unit.t_throw});
            check(part%2==0?victim.unit.hp==initialHP:victim.unit.hp<initialHP,"personal impact permission controls only the thrown victim trial "+part,
               {before:initialHP,after:victim.unit.hp,allowed:victim.personal.thrownDamage});
            check(victim.unit.damWall==0,"temporary impact coefficient restores after native physics trial "+part);
         }
      }
   }
}
