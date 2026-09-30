package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.system.ApplicationDomain;
   import fe.unit.Unit;
   import fe.unit.CombatStateProbe;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   /** Native interactions, with the exact candidate loaded externally. */
   public class GameplayGapTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var t:Timer=new Timer(200),mod:RConnectMod,host:Boolean;
      public function GameplayGapTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"gameplay "+label);}
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         t.stop();
         if(host)try {run();}catch(err:Error){check(false,"uncaught "+err+" "+err.getStackTrace());}
         Log.d("COOP EFFECTS DONE gameplay "+(host?"host":"join"));
      }
      private function run():void {
         var b:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
         b.world=mod.game.world;b.loc=mod.game.loc;b.gg=mod.game.gg;
         var g:Object=b.gg,w:Object=b.world,ad:Object=mod.main.loaderInfo.applicationDomain;
         var oldX:Number=g.X,oldY:Number=g.Y;
         w.testDam=true;g.invulner=false;g.disabled=true;
         var snap:Object=b.readSnapshot();snap.x=800;snap.y=600;
         b.updateRemote(77,snap,"native gameplay");var ghost:Object=b.getRemoteGhost(77);
         g.setPos(1400,600);
         var cls:Class=ad.getDefinition("fe.unit.Mine") as Class;
         var mine:Object=new cls("mine",1,null,null);mine.putLoc(b.loc,800,600);b.loc.addObj(mine);b.loc.units.push(mine);
         mine.stay=true;mine.oduplenie=0;
         for(var i:int=0;i<32 && CombatStateProbe.state(mine as Unit)==1;i++)mine.control();
         check(CombatStateProbe.state(mine as Unit)==2,"remote player triggers native mine state="+CombatStateProbe.state(mine as Unit)+" trap="+ghost.activateTrap+" fraction="+mine.fraction);
         b.loc.remObj(mine);b.loc.units.splice(b.loc.units.indexOf(mine),1);
         // Keep native sight inputs. A visible player at 400px must not be
         // discarded by a multiplayer-only short-range cap.
         cls=ad.getDefinition("fe.unit.UnitTurret") as Class;
         var turret:Object=new cls("land",1,<unit tr="1" vis="right"/>,null);
         turret.putLoc(b.loc,400,600);b.loc.addObj(turret);b.loc.units.push(turret);
         turret.eyeX=400;turret.eyeY=570;turret.vAngle=0;turret.storona=1;turret.oduplenie=0;
         var sight:Number=turret.look(ghost,true);b.loc.detecting=false;b.redirectNearbyAggro();
         Log.d("COOP PROBE gameplay turret="+[turret.fraction,turret.disabled,turret.sost,turret.hp,turret.overLook,turret.look(ghost,turret.overLook),turret.priorUnit===ghost,turret.celUnit===ghost,ghost.hp,ghost.disabled,ghost.doop,ghost.player]);
         check(sight>0.5 && turret.findCel(true) && turret.celUnit===ghost,"visible turret detects remote player at native range sight="+sight);
         check(b.loc.detecting,"seeing remote player marks the room detected for native XP rules");
         turret.setCel(null);turret.priorUnit=null;turret.vKonus=1;turret.vAngle=Math.PI;
         b.redirectNearbyAggro();check(turret.celUnit==null,"remote player outside native cone is not forced into a target");
         b.loc.remObj(turret);b.loc.units.splice(b.loc.units.indexOf(turret),1);
         cls=ad.getDefinition("fe.unit.UnitMerc") as Class;
         var merc:Object=new cls("1",100,<unit tr="1"/>,null);merc.putLoc(b.loc,600,600);b.loc.addObj(merc);b.loc.units.push(merc);
         merc.eyeX=600;merc.eyeY=570;merc.storona=1;merc.vAngle=0;merc.oduplenie=0;
         b.redirectNearbyAggro();
         check(merc.celUnit===ghost && CombatStateProbe.aware(merc as Unit),"griffon remembers the detected remote player as a player threat");
         merc.control();
         check(CombatStateProbe.state(merc as Unit)>1,"newly visible remote target enters native griffon reaction before patrol resumes");
         b.loc.remObj(merc);b.loc.units.splice(b.loc.units.indexOf(merc),1);b.removeRemote(77);
         // Real collection: call the same toTake/step sequence as the interaction
         // menu and let the production snapshot race against the moving pickup.
         g.setPos(800,600);g.isTake=25;w.hardInv=false;
         cls=ad.getDefinition("fe.serv.Item") as Class;
         var item:Object=new cls(null,"kofe",1);
         var data:Object={k:"L#901",b:"kofe",item:item.save(),x:830,y:600-g.scY/2,suction:false};
         b.roomRole(false);b.applyLootSync([data]);var lo:Object,cur:Object=b.loc.firstObj;
         while(cur!=null){if(GameBridge.probe(cur,"item")!=null && cur.item.id=="kofe")lo=cur;cur=cur.nobj;}
         var before:int=int(GameBridge.probe(w.invent.items["kofe"],"kol"));
         check(lo!=null,"host drop exists on receiving side");
         for(i=0;i<80;i++){lo.step();if(i%6==0)b.applyLootSync([data]);}
         var report:Object=b.scanLootReports(),bridge:Object=b;
         var requested:Boolean=report!=null && report.picked.length>0;
         if(requested && "applyLootReceipt" in bridge) {
            check(int(GameBridge.probe(w.invent.items["kofe"],"kol"))==before,"inventory waits for owner decision");
            var receipt:Object={results:[{k:report.picked[0].k,token:report.picked[0].token,ok:true,item:data.item}]};
            bridge.applyLootReceipt(receipt);bridge.applyLootReceipt(receipt);
         }
         var after:int=int(GameBridge.probe(w.invent.items["kofe"],"kol"));
         Log.d("COOP PROBE gameplay loot="+[lo.X,lo.Y,lo.dx,lo.dy,lo.auto2,lo.vsos,g.X,g.Y,g.isTake,g.rat]+" requests="+JSON.stringify(report));
         check(after==before+1,"holding pickup collects remote drop exactly once before="+before+" after="+after+" auto="+lo.auto);
         check(requested,"pickup produces authoritative removal request");
         var weaponData:Object={tip:"weapon",id:"lmg",kol:1,sost:0.37,variant:1,lvl:3,barter:2,trig:null,multHP:0.4};
         b.applyLootSync([{k:"L#902",b:"lmg^1",item:weaponData,x:830,y:570,suction:false}]);
         cur=b.loc.firstObj;var weaponDrop:Object;
         while(cur!=null){if(GameBridge.probe(cur,"item")!=null && cur.item.id=="lmg")weaponDrop=cur;cur=cur.nobj;}
         check(weaponDrop!=null && weaponDrop.item.sost==0.37 && weaponDrop.item.variant==1 && weaponDrop.item.multHP==0.4,
            "remote equipment preserves variant, fractional condition and broken-container multiplier");
         if(weaponDrop!=null) {
            weaponDrop.take(true);report=b.scanLootReports();
            for each(var claim:Object in report.picked)if(claim.k=="L#902") {
               weaponDrop.item.sost=0.98;
               var grant:Object={results:[{k:claim.k,token:claim.token,ok:true,item:weaponData}]};
               b.applyLootReceipt(grant);b.applyLootReceipt(grant);
               var ownedGun:Object=w.invent.weapons.lmg,expectedHp:int=Math.round(Number(weaponDrop.item.xml.char[1].@maxhp)*0.37*0.4);
               check(ownedGun!=null && ownedGun.variant==1 && ownedGun.hp==expectedHp,
                  "equipment inventory uses the owner receipt once hp="+(ownedGun==null?-1:ownedGun.hp)+" expected="+expectedHp);
            }
         }
         b.roomRole(true);
         cls=ad.getDefinition("fe.serv.Item") as Class;
         var rolledItem:Object=new cls("weapon","lmg",1,1);
         rolledItem.sost=0.37;rolledItem.multHP=0.4;rolledItem.shpun=2;
         cls=ad.getDefinition("fe.loc.Loot") as Class;
         var nativeDrop:Object=new cls(b.loc,rolledItem,920,570,false,false,true),capturedDrop:Object;
         for each(var captured:Object in b.readLootSync())if(captured.item.id=="lmg" && captured.x==920)capturedDrop=captured;
         check(capturedDrop!=null && capturedDrop.item.sost==0.37 && capturedDrop.item.multHP==0.4 && capturedDrop.item.shpun==2,
            "owner snapshot retains native rolled equipment and broken-container state");
         b.loc.remObj(nativeDrop);
         cls=ad.getDefinition("fe.loc.Box") as Class;
         var box:Object=new cls(b.loc,"case",900,600,<obj cont="custom"><item id="kofe" kol="2"/></obj>,null);
         b.loc.addObj(box);b.loc.objs.push(box);
         var boxes:Array=b.readObjsSnapshot(),boxData:Object;
         for each(var entry:Object in boxes)if(entry.id=="case" && entry.x==900)boxData=entry;
         var req:Object={ist:[{k:boxData.k,id:"case",x:900,y:600,t:2}]};
         b.applyObjReports(req);var first:Array=b.readLootSync();b.applyObjReports(req);var second:Array=b.readLootSync();
         check(first!=null && first.length>0,"join container action generates real host drops");
         check(first!=null && second.length==first.length,"repeated container request does not duplicate drops");
         cls=ad.getDefinition("fe.unit.UnitAlicorn") as Class;
         var ali:Object=new cls("1",100,<unit tr="1"/>,null);
         ali.putLoc(b.loc,1000,600);b.loc.addObj(ali);b.loc.units.push(ali);ali.shithp=300;
         var units:Array=JSON.parse(JSON.stringify(b.readUnitsSnapshot())) as Array;
         var shield:Object=CombatStateProbe.shield(ali as Unit);shield.visible=false;
         b.freezeAI=true;b.applyUnitsSync(units);b.tickFrozenAnims();
         check(shield.visible,"alicorn shield is rendered from authoritative state");
         b.roomRole(true);
         var oldGun:Object=g.currentWeapon,oldChildren:Object=g.childObjs;
         var gun:NativeTestGun=new NativeTestGun(g as Unit),gunObject:Object=gun;
         gunObject.setPers(g,g.pers);g.currentWeapon=gun;g.childObjs=[gun];b.readSnapshot();
         gun.fireAt(ali,true);var firing:Object=b.readSnapshot();b.updateRemote(78,firing,"firing fixture");
         check(int(GameBridge.probe(b,"projectileVisualCount"))>0,"remote player shot creates a display projectile");
         b.removeRemote(78);g.currentWeapon=oldGun;g.childObjs=oldChildren;
         if(ApplicationDomain.currentDomain.hasDefinition("rconnect.game.WorldProgress")) {
            cls=ApplicationDomain.currentDomain.getDefinition("rconnect.game.WorldProgress") as Class;
            var source:Object=new cls(b),receiver:Object=new cls(b);
            var bonus:Object=b.loc.createObj("xp","bonus",27,14,<obj code="m39_xp" uid="m39_xp"/>);
            b.loc.unXp=10;b.loc.maxXp=b.loc.kolXp=1;
            source.prepare();var layout:Object=source.capture(b.loc);
            layout.bonuses[layout.bonuses.length-1].x=1120;source.restore(layout);
            bonus=b.loc.bonuses[b.loc.bonuses.length-1];
            check(bonus.X==1120 && b.loc.saves.indexOf(bonus)>=0 && b.loc.land.uidObjs.m39_xp===bonus,"XP layout replacement preserves native save and script references");
            source.scan();receiver.scan();bonus=b.loc.bonuses[b.loc.bonuses.length-1];bonus.take();var events:Array=source.scan();
            check(events.length==1 && events[0].reward==10,"native XP activation publishes its reward");
            bonus.sost=1;bonus.liv=1000000;b.loc.kolXp=1;
            var xp:int=w.pers.xpCur;receiver.receive(events);receiver.receive(events);
            check(w.pers.xpCur==xp+10 && bonus.sost==2,"XP reward arrives once and map point becomes collected");
            bonus.sost=1;bonus.liv=1000000;b.loc.kolXp=1;b.loc.maxXp=2;b.loc.summXp=7;b.loc.detecting=false;
            source.reset();source.scan();xp=w.pers.xpCur;bonus.take();events=source.scan();
            check(events.length==1 && events[0].reward==27 && w.pers.xpCur==xp+27 && b.loc.summXp==0,
               "last undetected XP point shares the native completion and stealth reward");
            var finishedLayout:Object=source.capture(b.loc);b.loc.detecting=true;b.loc.summXp=99;b.loc.kolXp=1;
            source.restore(finishedLayout);
            check(!b.loc.detecting && b.loc.summXp==0 && b.loc.kolXp==0,
               "room handoff preserves detection and remaining XP counters");
            source.reset();receiver.reset();
            var cp:Object=b.loc.createObj("checkpoint","checkpoint",29,14,<obj code="m39_cp" uid="m39_cp"/>);
            source.scan();receiver.scan();
            cp.active=2;events=source.scan();cp.active=0;
            var previousCP:Object=w.pers.currentCP;receiver.receive(events);
            check(cp.active==1 && cp.inter.active,"teammate checkpoint is unlocked for local activation");
            check(w.pers.currentCP===previousCP,"remote unlock preserves local save/respawn selection");
         }
         b.loc.remObj(ali);b.loc.units.splice(b.loc.units.indexOf(ali),1);
         for each(var cleanup:Object in [box,bonus,cp])if(cleanup!=null) {
            b.loc.remObj(cleanup);
            for each(var cleanupList:Array in [b.loc.objs,b.loc.bonuses,b.loc.acts,b.loc.saves]) {
               var ix:int=cleanupList.indexOf(cleanup);if(ix>=0)cleanupList.splice(ix,1);
            }
            if(cleanup.uid!=null && b.loc.land.uidObjs[cleanup.uid]===cleanup)delete b.loc.land.uidObjs[cleanup.uid];
         }
         b.endSession();g.setPos(oldX,oldY);g.disabled=false;g.invulner=true;
      }
   }
}
