package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.Event;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.CombatStateProbe;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   /** Differential tests execute native damage and the production mirror seam.
    * Run in the host of an isolated connected pair; no source substitutions. */
   public class CombatStateTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),mod:RConnectMod,host:Boolean,done:Boolean=false;
      public function CombatStateTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"state "+label);}
      private function spawn(name:String,id:String,xml:XML,x:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new cls(id,100,xml,null);
         u.putLoc(mod.game.loc,x,mod.game.gg.Y);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.xp=0;u.hp=u.maxhp=2000;return u;
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(done || mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null
            || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(!host){done=true;timer.stop();Log.d("COOP EFFECTS DONE state join");return;}
         done=true;timer.stop();
         try {run();}catch(err:*){check(false,"uncaught "+err+" "+(err is Error?Error(err).getStackTrace():""));}
         Log.d("COOP EFFECTS DONE state host");
      }
      private function run():void {
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
         b.world=mod.game.world;b.loc=mod.game.loc;b.gg=mod.game.gg;b.freezeAI=true;
         var g:Object=b.gg,w:Object=b.world;w.testDam=true;g.invulner=true;
         var z:Object=spawn("UnitZombie","1",<unit tr="1" dig="0"/>,g.X+90);
         z.stay=true;z.dx=3;CombatStateProbe.ai(z as Unit,3);z.animate();
         var h:Number=z.hp,sy:Number=z.scY;
         var gun:NativeTestGun=new NativeTestGun(g as Unit);var gw:Object=gun;
         gw.setPers(g,g.pers);gw.damage=60;gw.critCh=0;
         z.disabled=false;gun.fireAt(z,true);var nativeLoss:Number=h-z.hp;z.hp=h;z.disabled=true;
         check(nativeLoss>0,"native LMG damages awake ghoul loss="+nativeLoss);
         // Exercise the real JSON boundary as well as native collision. An
         // in-process array copy hides XMLList resistance corruption.
         var list:Array=JSON.parse(JSON.stringify(b.readUnitsSnapshot())) as Array;
         // An independently generated client room may still have this ghoul buried.
         // This is the native burrow collision/state shape, before an awake host update.
         z.scY=0;z.invis=true;z.setPos(z.X,z.Y);CombatStateProbe.ai(z as Unit,5);
         b.applyUnitsSync(list);b.tickFrozenAnims();
         check(z.scY==sy && z.Y2-z.Y1>0,"awake ghoul restores client collision height host="+sy+" local="+z.scY);
         var proxy:Object;for each(var u:Object in b.loc.units)if(u.id=="rconnect_hit_zombie1")proxy=u;
         check(proxy!=null,"awake ghoul collision receiver exists");
         gun.fireAt(z,true);var mirrorLoss:Number=h-z.hp;
         check(Math.abs(mirrorLoss-nativeLoss)<0.001,"LMG native/mirror ghoul loss matches native="+nativeLoss+" mirror="+mirrorLoss);
         b.scanAndReportDamage();
         var bat:Object=spawn("UnitBat","1",<unit tr="1"/>,g.X+180);
         CombatStateProbe.ai(bat as Unit,3);bat.animate();list=JSON.parse(JSON.stringify(b.readUnitsSnapshot())) as Array;
         var flying:String=bat.vis.osn.currentLabel;
         CombatStateProbe.ai(bat as Unit,0);bat.animState="";bat.animate();
         b.applyUnitsSync(list);b.tickFrozenAnims();
         check(bat.vis.osn.currentLabel==flying && flying=="fly","bloodwing flying pose survives resting client state actual="+bat.vis.osn.currentLabel);
         b.roomRole(true);bat.animate();
         check(bat.vis.osn.currentLabel==flying,"bloodwing stays flying when native authority resumes actual="+bat.vis.osn.currentLabel);
         // Compare native local-player damage with the real host-ghost HP relay.
         g.invulner=false;g.hp=1000;g.maxhp=1000;g.skin=8;g.armor_qual=0;g.allVulnerMult=1;
         g.vulner[4]=0.25;g.vulner[0]=1;
         var snap:Object=b.readSnapshot();b.updateRemote(77,snap,"damage fixture");
         var ghost:Object=b.getRemoteGhost(77);check(ghost!=null,"native remote combat body created");
         g.damage(60,4,null,false);var expected:Number=1000-g.hp;g.hp=1000;
         ghost.damage(60,4,null,false);var relayed:Number=b.scanGhostHp(77);
         var bridge:Object=b;
         if("readRemoteHits" in bridge)bridge.applyPlayerHits(bridge.readRemoteHits(77));
         else g.damage(relayed,0,null,false);
         check(Math.abs((1000-g.hp)-expected)<0.001,"incoming native/relay damage matches native="+expected+" relay="+(1000-g.hp)+" packet="+relayed);
         b.removeRemote(77);g.invulner=true;
         var boxClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
         var door:Object=new boxClass(b.loc,"door1",700,640);door.initDoor();
         var cabinet:Object=new boxClass(b.loc,"case",900,640);
         b.loc.addObj(door);b.loc.objs.push(door);b.loc.addObj(cabinet);b.loc.objs.push(cabinet);
         door.inter.setAct("lock",3);
         b.reconcileObjs(b.readObjsSnapshot());
         // Native search uses loot=1; restored/remote loot may use 2. Both mean
         // opened and must acknowledge the same local interaction.
         door.inter.setAct("open",1);cabinet.inter.setAct("loot",1);
         var scene:Array=b.readObjsSnapshot();
         door.inter.setAct("open",0);door.inter.setAct("lock",3);cabinet.setVisState("close");
         b.reconcileObjs(scene);
         check(door.inter.open,"door begins opening on the first authoritative update");
         check(cabinet.vis.currentLabel=="open","cabinet immediately displays native opened state");
         var restarts:int=0;
         var constructed:Function=function(e:Event):void{restarts++;};
         cabinet.vis.addEventListener(Event.FRAME_CONSTRUCTED,constructed);
         for(var replay:int=0;replay<6;replay++)b.reconcileObjs(scene);
         cabinet.vis.removeEventListener(Event.FRAME_CONSTRUCTED,constructed);
         check(restarts==0,"repeated scene snapshots do not reconstruct cabinet animation frames");
         var echo:Object=b.scanObjReports();
         check(echo==null || echo.ist.length==0,"host opening a locked door does not create a false unlock report");
         door.inter.setAct("open",0);
         var report:Object=b.scanObjReports(),found:Boolean=false;
         if(report!=null)for each(var event:Object in report.ist)if(event.id=="door1" && event.o===0)found=true;
         check(found,"local door close is reported on the first scan");
         b.reconcileObjs(scene);
         check(!door.inter.open,"old host snapshot cannot restart a pending local door action");
         b.applyObjReports(report);b.reconcileObjs(b.readObjsSnapshot());
         report=b.scanObjReports();
         check(report==null || report.ist.length==0,"acknowledged interaction stops echoing including cabinet loot");
         door.inter.setAct("lock",3);b.reconcileObjs(b.readObjsSnapshot());
         door.inter.setAct("open",1);report=b.scanObjReports();found=false;
         if(report!=null)for each(event in report.ist)if(event.id=="door1" && event.o===1 && event.l===0)found=true;
         check(found,"local opening reports both the door action and native unlock");
         b.applyObjReports(report);b.reconcileObjs(b.readObjsSnapshot());report=b.scanObjReports();
         check(report==null || report.ist.length==0,"open-door echo acknowledges unlock although wire omits lock field");
         // Baseline timing at this seam includes indexing, animation and proxy upkeep.
         for(var i:int=0;i<38;i++)spawn("UnitBat","1",<unit tr="1"/>,g.X+180);
         list=b.readUnitsSnapshot();var start:int=getTimer();
         for(i=0;i<12;i++){b.applyUnitsSync(list);b.tickFrozenAnims();}
         Log.d("COOP METRIC state enemies="+list.length+" snapshotBytes="+JSON.stringify(list).length+" apply12ms="+(getTimer()-start));
         b.endSession();
         // Native puzzle boxes register a visual-less hit receiver in units,
         // but never in the draw/step chain. It belongs to its box.
         cabinet.bindUnit("4");var receiver:Object=cabinet.un;b.loc.units.push(receiver);
         var checkpoint:Object=JSON.parse(JSON.stringify(b.checkpoint()));
         var independent:Boolean=false;
         for each(var entry:Object in checkpoint.units)if(entry.cls=="fe.unit::VirtualUnit")independent=true;
         check(!independent,"box hit receiver is excluded from independent enemy checkpoints");
         b.reconcileWorld(checkpoint.units,true);
         check(b.loc.units.indexOf(receiver)>=0 && receiver.owner===cabinet,"enemy reconciliation preserves box-owned collision receiver");
         var restored:Boolean=true;
         try {b.restoreCheckpoint(checkpoint,true,true);w.redrawLoc();}
         catch(roomError:Error){restored=false;Log.d("COOP PROBE room constructor "+roomError.getStackTrace());}
         check(restored && b.loc.units.indexOf(receiver)>=0 && !receiver.in_chain,"authority checkpoint keeps box receiver outside native draw chain");
         if(restored) {
            b.restoreCheckpoint(checkpoint,false,true);w.redrawLoc();
            check(b.loc.units.indexOf(receiver)>=0 && receiver.owner===cabinet,"mirror checkpoint preserves receiver and original owner");
            check(receiver.damage(5,0)==0 && receiver.damage(5,4)==1,"box receiver keeps native damage-type filtering after transfer");
         } else {check(false,"mirror checkpoint unavailable after construction failure");check(false,"box receiver filtering unavailable after construction failure");}
         b.endSession();
      }
   }
}
