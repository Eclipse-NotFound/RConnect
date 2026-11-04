package authority {
   /** Native player death must not reactivate the retained room's dead hazards. */
   public final class LifecycleProbe extends Probe {
      private var start:uint=0,ready:Boolean=false,phase:int=0,dead:Array=[],birth:int=0;
      private var savedRoom:Object,hostRoom:Object,hostUnit:Object;
      public function LifecycleProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;frame.actions=[];return frame;}
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;
            if(f.players[1].epoch>=2 && f.character.body.ggControl && f.tick>390) {
               var ghosts:int=0;
               for each(var s:Object in f.scene.units)if((s.cls.indexOf("UnitTurret")>=0 || s.cls.indexOf("UnitMsp")>=0) && !NativeFields.get(s,"disabled") && NativeFields.get(s,"sost")<3)++ghosts;
               check(f.players[1].hp>0 && access.world.gg.ggControl,"join returns from native death to a controllable confirmed body");
               check(ghosts==0,"join does not resurrect killed turrets or spider mines after player revival",{ghosts:ghosts});
               check(f.players[0].epoch==1 && f.players[1].epoch==2,"only the dead player's incarnation changes");
               SceneChecks.picture(access,"lifecycle-revived.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var tick:uint=session.runtime.tick,a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1];
         if(!ready) {
            ready=true;start=tick;birth=b.epoch;savedRoom=b.unit.loc;hostRoom=a.unit.loc;hostUnit=a.unit;
            for each(var old:Object in savedRoom.units)if(old!=null && !old.player){old.disabled=true;old.remVisual();}
            // Isolate revival from the new random layout's shafts and traps.
            // Native death, room identity and hazard corpses remain real.
            var floorY:Number=Math.floor((savedRoom.limY-120)/40)*40-1,row:int=int((floorY+1)/40);
            for(var x:int=8;x<30;x++)for(var y:int=row-6;y<=row;y++) {
               var t:Object=savedRoom.space[x][y];t.phis=y==row?1:0;t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
               t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
               if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
            }
            a.unit.setPos(400,floorY);b.unit.setPos(600,floorY);
            b.spawn={room:savedRoom,x:b.unit.X,y:b.unit.Y};b.unit.pers.currentCP=null;
            access.scope.run(b.context,function():void {
               for each(var name:String in ["fe.unit.UnitTurret","fe.unit.UnitMsp"]) {
                  var Type:Class=access.definition(name),u:Object=new Type(name.indexOf("Turret")>=0?"land":"1",10,<unit tr="1"/>,null);
                  u.putLoc(savedRoom,b.unit.X+500,b.unit.Y);savedRoom.units.push(u);savedRoom.addObj(u);u.addVisual();
                  u.damage(100000,0,null,true);dead.push(u);
               }
            });
         }
         if(phase==0 && tick-start>50) {
            phase=1;
            check(dead[0].sost>=3 && dead[1].sost>=3,"native turret and spider mine are killed before player death");
            var beforeHP:Number=a.unit.hp;
            access.scope.run(b.context,function():void {b.unit.damage(100000,0,null,true);});
            check(b.deathTicks==300 && !b.unit.ggControl && a.unit.hp==beforeHP,"native remote death starts only its own lifecycle");
         }
         if(phase==1 && tick-start>370) {
            phase=2;
            check(b.epoch==birth+1 && b.unit.hp>0 && b.unit.ggControl,"remote native resurrection restores control and advances one incarnation");
            check(b.unit.loc===savedRoom && a.unit===hostUnit && a.unit.loc===hostRoom && access.world.gg===hostUnit,
               "respawn retains native room identity and host camera ownership");
            check(dead[0].sost>=3 && dead[1].sost>=3 && dead[0].hp<=0 && dead[1].hp<=0,"respawn never resets dead native hazard state");
            var oldInput:Object={session:session.session,player:1,room:session.inputs[1].room,roomEpoch:session.inputs[1].roomEpoch,
               epoch:birth,weaponEpoch:b.weaponEpoch,seq:session.inputs[1].accepted+1,buttons:Commands.FIRE,aimX:1,aimY:1,actions:[]};
            check(session.inputs[1].accept(oldInput,0)=="identity","pre-death fire input cannot affect the revived actor");
         }
         if(tick-start>420)finish();
      }
   }
}
