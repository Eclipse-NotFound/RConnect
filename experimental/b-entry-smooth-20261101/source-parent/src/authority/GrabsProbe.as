package authority {
   /** Native right-click grab/release and per-player consent/struggle. */
   public final class GrabsProbe extends Probe {
      private var tick:uint=0,begin:int=-1,ready:Boolean=false,phase:int=0,fy:Number=0;
      private var clientHeld:Boolean=false,clientGlow:Boolean=false;
      public function GrabsProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && session!=null && begin>=0)tick=session.runtime.tick-begin;
         if(!host && begin>=0)frame.probeStart=begin;
         frame.actions=[];frame.buttons=0;frame.aimX=400;frame.aimY=fy-35;
         frame.settings={allowGrab:host && tick>=45 && tick<230,struggle:tick<110,thrownDamage:false,follow:false};
         if(begin<0)return frame;
         if(!host && (tick==20 || tick==60 || tick==125 || tick==185 || tick==215))frame.buttons=Commands.TELE;
         // Hold a source tick interval so a skipped display tick cannot drop a press.
         if(!host && (tick>=20&&tick<23 || tick>=60&&tick<63 || tick>=125&&tick<128 || tick>=185&&tick<188 || tick>=215&&tick<218))frame.buttons=Commands.TELE;
         if(host && (tick>=85&&tick<88 || tick>=155&&tick<165))frame.buttons=Commands.LEFT;
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;fy=f.players[1].y;
            if(f.players[0].native.levit>=2){clientHeld=true;clientGlow=clientGlow || f.players[0].visual.filters.length>0;}
            if(tick>255) {
               check(clientHeld && clientGlow,"join sees the confirmed native held teammate and its telekinetic halo");
               check(f.players[0].native.levit==0 && !f.players[0].personal.allowGrab,"join confirms personal consent revocation releases the held player");
               SceneChecks.picture(access,"grabs-released.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=a.unit.loc;
         if(!ready) {
            ready=true;fy=Math.floor((room.limY-120)/40)*40-1;var row:int=int((fy+1)/40);
            for each(var old:Object in room.units)if(old!=null && !old.player){old.disabled=true;old.remVisual();}
            for(var x:int=6;x<28;x++)for(var y:int=row-6;y<=row;y++) {
               var t:Object=room.space[x][y];t.phis=y==row?1:0;t.visi=t.t_visi=1;t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
               t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
               if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
            }
            room.black=false;a.unit.setPos(400,fy);b.unit.setPos(600,fy);
            for each(var actor:PlayerActor in session.actors) {
               // Native telekinesis rank zero lifts 0.6; a pony weighs 1.
               // Give this fixture the real learned skill, not a bypass of mass.
               access.scope.run(actor.context,function():void {
                  actor.unit.pers.skills.tele=2;actor.unit.pers.setParameters();
                  actor.unit.mana=actor.unit.maxmana=10000;
               });
            }
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         if(tick>=58 && tick<=68 || tick>=123 && tick<=130)Log.write("grab-diagnostic",{tick:tick,buttons:session.inputs[1].buttons,
            aim:[session.inputs[1].aimX,session.inputs[1].aimY],host:[a.unit.X,a.unit.Y,a.unit.X1,a.unit.X2,a.unit.Y1,a.unit.Y2],
            eligibility:[a.unit.levitPoss,a.unit.massa,a.unit.prior,a.unit.isVis,a.unit.invis,a.unit.disabled,a.unit.sost],
            join:[b.unit.X,b.unit.Y,b.unit.mana,b.unit.pers.maxTeleMassa,b.unit.pers.teleDist,b.unit.ggControl,b.unit.work,b.unit.rat],
            held:b.unit.teleObj==null?null:b.unit.teleObj.id,line:room.isLine(b.unit.X,b.unit.Y-b.unit.scY*.75,a.unit.X,a.unit.Y-a.unit.scY/2)});
         if(phase==0 && tick>35){phase=1;check(b.unit.teleObj!==a.unit,"personal grab permission defaults off");}
         if(phase==1 && tick>75){phase=2;check(b.unit.teleObj===a.unit && a.unit.levit>=2,"join's native grab holds the consenting real host actor");}
         if(phase==2 && tick>100){phase=3;check(b.unit.teleObj==null && a.unit.levit==0,"enabled WASD struggle releases the native grab");a.unit.setPos(400,fy);}
         if(phase==3 && tick>170){phase=4;check(b.unit.teleObj===a.unit && a.unit.levit>=2,"disabled struggle keeps the real actor held while movement is pressed");}
         if(phase==4 && tick>200){phase=5;check(b.unit.teleObj==null,"a new native telekinesis press releases the old target");a.unit.setPos(400,fy);}
         if(phase==5 && tick>225){phase=6;check(b.unit.teleObj===a.unit,"released target can be grabbed again with a fresh press");}
         if(phase==6 && tick>245){phase=7;check(b.unit.teleObj==null && a.unit.levit==0,"revoking personal permission immediately drops an active grab");}
         if(tick>270)finish();
      }
   }
}
