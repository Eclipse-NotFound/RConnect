package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real native death countdown -> checkpoint -> resurrection -> room visit.
    * Inspect the native linked display objects too, not just loc.units. */
   public class RespawnRoomTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,links:Dictionary=new Dictionary(),timer:Timer=new Timer(100);
      private var phase:String="boot",at:int=getTimer(),ready:Boolean=false,round:int=0;
      private var origin:Object,away:Object,turret:Object,mine:Object,deadSeen:Boolean=false;
      private var nativeTurret:Object,nativeMine:Object;
      private var fixtureX:Number=NaN,fixtureY:Number=NaN;
      public function RespawnRoomTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(v:Boolean,s:String):void {Log.d("COOP "+(v?"PASS ":"FAIL ")+"respawn-room "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("RESPAWN PHASE "+(host?"host ":"join ")+s);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="respawn-room-test";p.op=op;if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function klass(n:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(n) as Class;}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function info(l:Object):Object {return {landX:l.landX,landY:l.landY,landZ:l.landZ,landProb:l.landProb,key:mod.game.roomKey(l)};}
      private function fixture(hp:int):Object {
         for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&u.maxhp==hp)return u;return null;
      }
      private function installCheckpoint():void {
         mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();
         var g:Object=mod.game.gg,l:Object=mod.game.loc,cp:Object=l.cp;
         g.invulner=true;g.transp=true;g.pers.healAll();
         if(cp==null){cp=l.createObj("checkpoint","checkpoint",int(g.X/40),int(g.Y/40)-1);l.cp=cp;}
         cp.activate();check(g.pers.currentCP===cp,"native checkpoint activation belongs to this room");
      }
      private function createEnemies():void {
         var l:Object=mod.game.loc,g:Object=mod.game.gg,c:Class=klass("fe.unit.UnitTurret");
         if(host){fixtureX=g.X+120;fixtureY=g.Y;}
         turret=new c("land",12,<unit tr="3"/>,null);turret.putLoc(l,fixtureX,fixtureY);l.addObj(turret);l.units.push(turret);
         turret.maxhp=turret.hp=54331;turret.disabled=host;turret.doop=true;turret.xp=0;turret.lootIsDrop=true;
         c=klass("fe.unit.UnitMsp");mine=new c("1",12,<unit tr="1"/>,null);mine.putLoc(l,fixtureX+70,fixtureY);l.addObj(mine);l.units.push(mine);
         mine.maxhp=mine.hp=54332;mine.disabled=host;mine.doop=true;mine.xp=0;mine.lootIsDrop=true;
         nativeTurret=turret;nativeMine=mine;
         turret.isVis=mine.isVis=true;turret.vis.visible=mine.vis.visible=true;
      }
      private function inspect(label:String):void {
         var seen:Array=[],l:Object=mod.game.loc;
         for(var u:Object=l.firstObj;u!=null;u=u.nobj)if(u is Object&&(GameBridge.probe(u,"maxhp")==54331||GameBridge.probe(u,"maxhp")==54332)) {
            var v:Object=GameBridge.probe(u,"vis"),visible:Boolean=v!=null&&v.visible&&v.stage!=null;
            seen.push({hp:u.hp,sost:u.sost,inUnits:l.units.indexOf(u)>=0,visible:visible,id:u.id});
            check(u.sost>=3,"killed "+u.id+" never becomes alive "+label);
            check(!visible,"removed machine has no orphan visible body "+u.id+" "+label);
         }
         for each(u in l.units)if(u.maxhp==54331||u.maxhp==54332)check(u.sost>=3,"unit table contains no live killed fixture "+label);
         Log.d("RESPAWN INSPECT "+JSON.stringify({role:host?"host":"join",label:label,room:mod.game.roomKey(),seen:seen}));
      }
      private function die():void {
         deadSeen=false;mod.game.gg.die(-1);
         check(mod.game.world.t_die>0&&mod.game.gg.sost==2,"native player death countdown starts");change("dying");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="respawn-room-test")return;
         try {
            if(host&&p.op=="ready")ready=true;
            else if(!host&&p.op=="setup"){origin=p.origin;away=p.away;fixtureX=p.x;fixtureY=p.y;installCheckpoint();createEnemies();gather();change("find");}
            else if(host&&p.op=="found") {
               check(turret!=null&&mine!=null,"native turret and spider mine present before kill");
               turret.disabled=false;mine.disabled=false;turret.hp=mine.hp=0;turret.die();mine.die();
               check(turret.sost>=3&&mine.sost>=3,"native deaths complete on authority");send("killed");change("killed");
            } else if(!host&&p.op=="killed")change("wait-death");
            else if(host&&p.op=="revived") {
               inspect("join revived");send("away");change("wait-away");
            } else if(!host&&p.op=="away") {TravelGuard.follow(mod.game,away);change("away");}
            else if(host&&p.op=="away-ready") {send("return");change("wait-return");}
            else if(!host&&p.op=="return") {TravelGuard.follow(mod.game,origin);change("return");}
            else if(host&&p.op=="returned") {
               if(round==0){round=1;send("die-away");change("wait-second");}else{send("done");finish();}
            } else if(!host&&p.op=="die-away") {round=1;TravelGuard.follow(mod.game,away);change("die-away");}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var link:TcpLink in mod.session.server.clients)watch(link);else if(!host)watch(mod.session.link);
         try {
            if(phase=="done")return;if(getTimer()-at>90000){check(false,"timeout "+phase);send("done");finish();return;}
            var g:Object=mod.game.gg;g.invulner=true;g.transp=true;
            if(host){g.disabled=true;g.dx=g.dy=0;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&ready) {
                  origin=info(mod.game.loc);
                  for each(var column:Array in mod.game.world.land.locs)if(column!=null)for each(var row:Array in column)if(row!=null)
                     for each(var room:Object in row)if(room!=null&&!TravelGuard.restricted(room)&&mod.game.roomKey(room)!=origin.key){away=info(room);break;}
                  check(away!=null,"ordinary second room exists");installCheckpoint();createEnemies();send("setup",{origin:origin,away:away,x:fixtureX,y:fixtureY});change("wait-found");
               }else if(!host)send("ready");
            } else if(!host&&phase=="find"&&getTimer()-at>1000&&(turret=fixture(54331))!=null&&(mine=fixture(54332))!=null) {
               check(turret===nativeTurret&&mine===nativeMine,"authority pairs with original joining native objects");
               check(turret.sost<3&&mine.sost<3,"both native machine mirrors exist before death");send("found");change("wait-kill");
            } else if(!host&&phase=="wait-death"&&getTimer()-at>2200) {inspect("before respawn");die();}
            else if(!host&&phase=="dying") {
               if(mod.game.world.t_die>0)deadSeen=true;
               if(deadSeen&&mod.game.world.t_die==0&&g.sost==1&&stable()&&getTimer()-at>1000) {
                  check(mod.game.roomKey()==origin.key,"native resurrection returns to original checkpoint room");
                  check(g.ggControl,"native resurrection restores own controls");gather();change("inspect-respawn");
               }
            } else if(!host&&phase=="inspect-respawn"&&getTimer()-at>1200) {inspect("after respawn");send("revived");change("wait-away");
            } else if(!host&&phase=="away"&&stable()&&mod.game.roomKey()==away.key&&getTimer()-at>1200){send("away-ready");change("wait-return");}
            else if(!host&&phase=="return"&&stable()&&mod.game.roomKey()==origin.key&&getTimer()-at>1400){gather();change("inspect-return");}
            else if(!host&&phase=="inspect-return"&&getTimer()-at>1200){inspect("revisit");send("returned");change("wait-next");}
            else if(!host&&phase=="die-away"&&stable()&&mod.game.roomKey()==away.key&&getTimer()-at>1200)die();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {if(phase=="done")return;change("done");timer.stop();Log.d("COOP EFFECTS DONE respawn-room");}
      private function gather():void {mod.game.gg.setPos(fixtureX-100,fixtureY);mod.game.gg.setVisPos();}
   }
}
