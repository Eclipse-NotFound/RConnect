package
{
   import flash.events.Event;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.ObjectIdentity;
   public class CoopRegression
   {
      private static var passed:int;
      private static var failed:int;
      private static function check(ok:Boolean, name:String):void
      {
         if(ok) passed++; else failed++;
         Log.d("COOP " + (ok ? "PASS " : "FAIL ") + name);
      }
      private static function box(id:String, x:int, script:Boolean = false):Object
      {
         var b:Object = {id:id, X:x, Y:100, wall:1, door:1, door_opac:1,
            hp:50, dead:false, tiles:[{phis:1}], levit:0, fracLevit:0};
         b.setDoor = function(open:Boolean):void { b.tiles[0].phis = open ? 0 : 1; };
         b.die = function(code:int):void { b.dead = true; b.tiles[0].phis = 0; };
         if(!script)
         {
            var iv:Object = {open:false, lock:0, autoClose:0, loot:0};
            iv.save = function(o:Object):void { o.loot = iv.loot; };
            iv.setAct = function(k:String, v:int):void
            {
               if(k == "open") { iv.open = v == 1; b.setDoor(iv.open); if(iv.open) iv.lock = 0; }
               if(k == "lock") iv.lock = v;
               if(k == "loot") iv.loot = v;
            };
            b.inter = iv;
         }
         return b;
      }
      private static function bridge():GameBridge
      {
         var b:GameBridge = new GameBridge({stage:null});
         b.world = {}; b.loc = {objs:[], units:[]};
         return b;
      }
      public static function run(mod:RConnectMod):void
      {
         passed = failed = 0;
         var host:GameBridge = bridge(), join:GameBridge = bridge();
         var h1:Object = box("door1",100), h2:Object = box("door1",180);
         var j1:Object = box("door1",100), j2:Object = box("door1",180);
         host.loc.objs = [h1,h2]; join.loc.objs = [j2,j1];
         h2.inter.setAct("open",1);
         for(var i:int=0;i<14;i++) join.reconcileObjs(host.readObjsSnapshot());
         check(!j1.inter.open && j2.inter.open, "duplicate doors independent open");
         h1.X=185; h2.X=90;
         h1.inter.setAct("open",1); h2.inter.setAct("open",0);
         for(i=0;i<14;i++) join.reconcileObjs(host.readObjsSnapshot());
         check(j1.inter.open && !j2.inter.open, "identity survives crossing positions");
         var snap:Array=host.readObjsSnapshot();
         host.applyObjReports({ist:[{k:snap[0].k,id:"door1",x:100,y:100,o:0,l:3,t:0}]});
         check(!h1.inter.open && h1.inter.lock==3, "join close and lock routed by key");
         host.applyObjReports({ist:[{k:snap[0].k,id:"door1",x:100,y:100,o:0,l:0,t:0}]});
         check(h1.inter.lock==0, "join unlock zero propagated");
         var hs:Object=box("window1",300,true), js:Object=box("window1",300,true);
         host.loc.objs.push(hs); join.loc.objs.push(js);
         join.reconcileObjs(host.readObjsSnapshot());
         hs.setDoor(true); join.reconcileObjs(host.readObjsSnapshot());
         check(js.tiles[0].phis==0, "script door host open");
         js.setDoor(false);
         join.reconcileObjs(host.readObjsSnapshot());
         js.tiles[0].phis=0; // Other synchronization can overwrite tiles before the report.
         host.applyObjReports(join.scanObjReports());
         join.reconcileObjs(host.readObjsSnapshot());
         check(hs.tiles[0].phis==1 && js.tiles[0].phis==1, "script door join close survives old snapshot");
         js.die(-1); host.applyObjReports(join.scanObjReports());
         join.reconcileObjs(host.readObjsSnapshot());
         check(hs.dead && hs.tiles[0].phis==0, "join door destruction clears tiles");
         check(join.scanObjReports()==null, "scene acknowledgements converge");
         var idx:ObjectIdentity=new ObjectIdentity();
         idx.enter(host.loc); idx.key(h1); idx.enter({});
         check(idx.known(h1)=="", "room identity reset");

         var freezeBridge:GameBridge=bridge();
         freezeBridge.freezeAI=true;
         var active:Object={id:"active",X:-100000,Y:-100000,disabled:false,setVisPos:function():void {}};
         var paused:Object={id:"paused",X:-100000,Y:-100000,disabled:true,setVisPos:function():void {}};
         freezeBridge.loc.units=[active,paused];
         var frozen:Object=freezeBridge.applyUnitsSync([
            {id:"active",x:-100000,y:-100000},{id:"paused",x:-100000,y:-100000}]);
         check(frozen.matched==2 && active.disabled && paused.disabled,"existing units frozen during cooperation");
         freezeBridge.loc={objs:[],units:[]};
         freezeBridge.applyUnitsSync([]);
         freezeBridge.endSession();
         check(!active.disabled && paused.disabled,"leave restores original AI across visited rooms");

         var moverH:Object=box("case",500), moverJ:Object=box("case",500);
         moverH.door=moverJ.door=0; moverH.wall=moverJ.wall=0;
         moverJ.loc=join.loc; moverJ.scX=moverJ.scY=20;
         moverH.loc=host.loc;
         moverJ.runVis=function():void {};
         host.loc.objs.push(moverH); join.loc.objs.push(moverJ);
         join.reconcileObjs(host.readObjsSnapshot());
         moverH.X=620; moverH.levit=1;
         join.reconcileObjs(host.readObjsSnapshot()); join.tickBoxTweens();
         check(moverJ.X>500 && moverJ.X<620, "telekinesis interpolates intermediate position");
         check(join.scanObjReports()==null, "interpolation does not report false local movement");
         moverJ.levit=1; moverJ.X=680; join.tickBoxTweens();
         check(moverJ.X==680,"local hold wins over pending interpolation");
         host.applyObjReports(join.scanObjReports()); host.tickBoxTweens();
         check(moverH.X==620,"host own hold not overwritten by remote move");
         moverJ.levit=0; moverH.levit=0;

         var real:GameBridge=mod.game;
         var sample:Object=real.readSnapshot();
         var gb:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main["loaderInfo"]});
         gb.world=real.world; gb.loc=real.loc; gb.gg=real.gg; gb.freezeAI=true;
         var list:Array=gb.readUnitsSnapshot();
         var x:Number=sample.x, y:Number=sample.y;
         list.push({id:"alicorn2",cls:"fe.unit::UnitAlicorn",tr:2,x:x+90,y:y,hp:200,sost:1,fraction:1,anim:"stay"});
         list.push({id:"mine",cls:"fe.unit::Mine",tr:2,x:x+120,y:y,hp:20,sost:1,fraction:1,anim:"stay"});
         list.push({id:"bossalicorn",cls:"fe.unit::UnitBossAlicorn",tr:1,x:x+160,y:y,hp:600,sost:1,fraction:1,anim:"stay"});
         gb.reconcileWorld(list);
         var ids:Object={};
         for each(var u:Object in gb.loc.units) ids[String(u.id)]=u;
         check(ids.alicorn2!=null, "real alicorn variant constructor");
         check(ids.mine!=null, "real mine constructor without unit XML");
         check(ids.bossalicorn!=null, "real boss constructor");
         var r:Object=gb.applyUnitsSync(list);
         check(r.matched==r.total, "real injected units mirror");
         var shown:Object=ids.alicorn2;
         var hideLate:Function=function(e:Event):void { shown.vis.visible=false; };
         mod.stage.addEventListener(Event.ENTER_FRAME,hideLate);
         mod.stage.dispatchEvent(new Event(Event.ENTER_FRAME));
         mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
         check(shown.vis.visible,"visibility wins over later registered ENTER_FRAME hider");
         mod.stage.removeEventListener(Event.ENTER_FRAME,hideLate);
         shown.remVisual();
         mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
         check(shown.vis.parent!=null,"orphan mirrored visual reattached");
         var osn:Object=GameBridge.probe(GameBridge.probe(real.gg,"vis"),"osn");
         var savedOuter:int=osn.currentFrame;
         osn.gotoAndStop("stay"); osn.body.gotoAndStop(2);
         sample=real.readSnapshot(); gb.updateRemote(901,sample,"CoopTest");
         var ghost:Object=gb.getRemoteGhost(901);
         check(ghost!=null && ghost.vis.osn.body.currentFrame==2,"nested sitting body frame mirrored");
         osn.gotoAndStop("walk"); osn.body.gotoAndStop(5);
         sample=real.readSnapshot(); gb.updateRemote(901,sample,"CoopTest");
         check(ghost.vis.osn.currentFrame==osn.currentFrame && ghost.vis.osn.body.currentFrame==5,
            "moving body timeline mirrored");
         var oldVis:Object=ghost.vis;
         var changed:Object=real.readSnapshot(); changed.ap.cFur=Number(changed.ap.cFur)+1;
         gb.updateRemote(901,changed,"CoopTest");
         check(ghost.vis!==oldVis && ghost.vis.parent!=null && oldVis.parent==null,"restyle replaces displayed visual");
         osn.gotoAndStop(savedOuter); gb.endSession();
         check(gb.getRemoteGhost(901)==null,"leave removes remote avatar");
         shown.vis.visible=false;
         mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
         check(!shown.vis.visible,"leave stops forced visibility");
         for each(var special:String in ["alicorn2","mine","bossalicorn"])
         {
            var unit:Object=ids[special];
            check(real.loc.units.indexOf(unit)<0,"leave removes injected "+special);
         }
         // Same-type overlapping Loot must retain stack identity and all entries.
         var ad:Object=mod.main["loaderInfo"]["applicationDomain"];
         var itemClass:Class=ad.getDefinition("fe.serv.Item") as Class;
         var lootClass:Class=ad.getDefinition("fe.loc.Loot") as Class;
         var created:Array=[];
         var lootBridge:GameBridge=new GameBridge({stage:null,loaderInfo:mod.main["loaderInfo"]});
         lootBridge.world=real.world; lootBridge.loc=real.loc; lootBridge.gg=real.gg;
         for(i=1;i<=65;i++)
         {
            var item:Object=new itemClass(null,"kofe",i);
            created.push(new lootClass(real.loc,item,1200,640,false,false,false));
         }
         var lootList:Array=lootBridge.readLootSync();
         check(lootList.length>=65,"all 65 ground items included");
         var stack:Object=lootList[lootList.length-1];
         check(stack.item.kol==65,"ground item stack metadata preserved");
         // Reverse host order, then claim the overlapping local objects by metadata.
         var lootJoin:GameBridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main["loaderInfo"]});
         lootJoin.world=real.world; lootJoin.loc=real.loc; lootJoin.gg=real.gg;
         lootList.reverse(); lootJoin.applyLootSync(lootList);
         created[64].X+=70;
         var lootReport:Object=lootJoin.scanLootReports();
         var correct:Boolean=false;
         if(lootReport!=null) for each(var move:Object in lootReport.moved)
            if(move.k==stack.k) correct=true;
         check(correct,"overlapping stacks retain distinct keys");
         var extra:Object=JSON.parse(JSON.stringify(stack));
         extra.k="new-stack"; extra.x=1500; extra.item.kol=77;
         lootList.push(extra); lootJoin.applyLootSync(lootList);
         var cur:Object=real.loc.firstObj;
         var injected:Object=null;
         while(cur!=null)
         {
            var curItem:Object=GameBridge.probe(cur,"item");
            if(curItem!=null && curItem.kol==77) { injected=cur; break; }
            cur=cur.nobj;
         }
         check(injected!=null,"new remote ground stack retains quantity");
         if(injected!=null)
         {
            var before:Number=injected.X;
            extra.x=before-80; extra.suction=true;
            lootJoin.applyLootSync(lootList);
            lootJoin.applyUnitsSync(real.readUnitsSnapshot());
            mod.stage.dispatchEvent(new Event(Event.EXIT_FRAME));
            check(injected.X<before && injected.X>before-80,"remote pickup movement interpolated");
            check(injected.item.kol==77,"pickup animation does not award or consume inventory");
         }
         if(injected!=null) created.push(injected);
         for each(var drop:Object in created) real.loc.remObj(drop);
         lootBridge.endSession(); lootJoin.endSession();
         Log.d("COOP DONE passed="+passed+" failed="+failed);
      }
   }
}
