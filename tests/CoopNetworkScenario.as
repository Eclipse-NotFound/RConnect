package
{
   import rconnect.core.Log;
   import rconnect.game.GameBridge;

   /** Actual native Box objects, exercised across the TCP session, not fixtures. */
   public class CoopNetworkScenario
   {
      private var host:Boolean;
      private var setup:Boolean=false;
      private var changed:Boolean=false;
      private var checked:Boolean=false;
      private var finished:Boolean=false;
      private var door:Object;
      private var script:Object;
      private var box:Object;
      private var enemies:Array=[];
      private var enemyChecked:Boolean=false;
      private var shot:Boolean=false;
      private var damageChecked:Boolean=false;
      private var killed:Boolean=false;
      private var localTarget:Object;
      public function CoopNetworkScenario(isHost:Boolean) { host=isHost; }
      private function check(ok:Boolean,name:String):void
      {
         Log.d("COOP "+(ok ? "PASS " : "FAIL ")+"network "+name);
      }
      private function make(mod:RConnectMod,id:String,x:int):Object
      {
         var cls:Class=mod.main["loaderInfo"]["applicationDomain"]["getDefinition"]("fe.loc.Box") as Class;
         var b:Object=new cls(mod.game.loc,id,x,640);
         if(Number(b.door)>0) b.initDoor();
         mod.game.loc.objs.push(b); mod.game.loc.addObj(b);
         return b;
      }
      private function find(mod:RConnectMod,id:String):Object
      {
         for each(var b:Object in mod.game.loc.objs) if(String(b.id)==id) return b;
         return null;
      }
      public function tick(mod:RConnectMod,n:int):void
      {
         if(host && !setup && n>=25)
         {
            setup=true;
            door=make(mod,"door1",700);
            script=make(mod,"window1",900);
            box=make(mod,"case",1100);
            var uc:Class=mod.main["loaderInfo"]["applicationDomain"]["getDefinition"]("fe.unit.UnitSlaver") as Class;
            for(var z:int=0;z<2;z++)
            {
               var enemy:Object=new uc("slaver1",100,<unit/>,null);
               enemy.putLoc(mod.game.loc,440+z*100,640);
               mod.game.loc.addObj(enemy); mod.game.loc.units.push(enemy);
               enemy.hp=enemy.maxhp=500;
               enemy.skin=10; enemy.armor=20; enemy.marmor=20;
               enemy.armor_hp=500; enemy.armor_qual=1;
               enemy.shithp=0; enemy.allVulnerMult=1; enemy.opt={};
               for(var vi:int=0;vi<20;vi++) enemy.vulner[vi]=1;
               enemy.disabled=true; enemy.animate(); enemies.push(enemy);
            }
            // This scenario deliberately exercises a door without Interact.
            script.inter=null;
            Log.d("COOP native scene ready door="+door.door+" window="+script.door+" phis="+script.phis);
         }
         if(host && setup && !changed && n>=50)
         {
            changed=true;
            door.inter.setAct("open",1);
            script.setDoor(true);
            box.X+=70;
            Log.d("COOP native scene host changed");
         }
         if(!host && !checked && n>=55)
         {
            checked=true;
            door=find(mod,"door1"); script=find(mod,"window1"); box=find(mod,"case");
            check(door!=null && script!=null && box!=null,"new native objects injected");
            check(door!=null && door.inter.open,"native door open received");
            check(script!=null && script.tiles.length>0 && script.tiles[0].phis==0,"native script door open received");
            if(door!=null) door.inter.setAct("open",0);
            if(script!=null)
            {
               script.setDoor(false);
               Log.d("COOP script close local phis="+script.phis+" tile="+script.tiles[0].phis+" inter="+script.inter);
            }
            if(box!=null) box.die(-1);
         }
         if(!host && !enemyChecked && n>=40)
         {
            enemyChecked=true;
            var count:int=0, drawn:int=0;
            for each(var unit:Object in mod.game.loc.units)
            {
               if(unit.id!="slaver1") continue;
               if(localTarget==null || unit.X<localTarget.X) localTarget=unit;
               count++;
               var px:int=EnemyRegression.pixels(unit.vis);
               Log.d("ENEMY network alpha="+unit.vis.alpha+" visible="+unit.vis.visible+" parent="+(unit.vis.parent!=null)+" mask="+unit.vis.mask+" pixels="+px);
               if(unit.vis.parent!=null && unit.vis.visible && unit.vis.alpha>0 && px>0) drawn++;
            }
            check(count==2,"two equal-id native enemies received");
            check(drawn==2,"both enemy sprites rendered after real vision frames");
         }
         if(!host && !shot && n>=45 && localTarget!=null)
         {
            shot=true;
            var oldTestDam:Boolean=mod.game.world.testDam;
            mod.game.world.testDam=true;
            CombatRegression.shoot(mod,localTarget.X,localTarget.Y-localTarget.scY*0.5,60);
            mod.game.world.testDam=oldTestDam;
            check(Math.abs(localTarget.hp-470)<0.01,"native shot predicts armor-adjusted damage");
         }
         if(host && !damageChecked && n>=78)
         {
            damageChecked=true;
            check(Math.abs(enemies[0].hp-470)<0.01,"native client shot reaches host without duplicate mitigation");
            check(enemies[1].hp==500,"native client shot leaves equal-id neighbor untouched");
            check(enemies[0].armor_hp==440,"client armor wear reaches host");
         }
         if(!host && !killed && n>=70 && localTarget!=null)
         {
            killed=true;
            check(Math.abs(localTarget.hp-470)<0.01,"host damage snapshot converges without repeated hits");
            var countLoot:int=mod.game.loc.objs.length;
            CombatRegression.shoot(mod,localTarget.X,localTarget.Y-localTarget.scY*0.5,5000);
            check(localTarget.hp<=0 && localTarget.sost<3 && mod.game.loc.objs.length==countLoot,
               "lethal client shot waits for host death and loot");
         }
         if(host && !finished && n>=100)
         {
            finished=true;
            check(door!=null && !door.inter.open,"native join close returned");
            check(script!=null && script.tiles[0].phis!=0,"native script close returned");
            check(box!=null && box.dead,"native join destruction returned");
            check(enemies[0].sost>=3 && enemies[0].hp<=0,"lethal client shot runs native host death");
            Log.d("COOP NETWORK DONE host");
         }
         if(!host && checked && !finished && n>=90)
         {
            finished=true;
            check(door!=null && !door.inter.open,"native close stays converged");
            check(localTarget!=null && localTarget.sost>=3,"host death snapshot reaches joiner");
            Log.d("COOP NETWORK DONE join");
         }
      }
   }
}
