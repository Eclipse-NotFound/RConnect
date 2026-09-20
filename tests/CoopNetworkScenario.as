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
               count++;
               var px:int=EnemyRegression.pixels(unit.vis);
               Log.d("ENEMY network alpha="+unit.vis.alpha+" visible="+unit.vis.visible+" parent="+(unit.vis.parent!=null)+" mask="+unit.vis.mask+" pixels="+px);
               if(unit.vis.parent!=null && unit.vis.visible && unit.vis.alpha>0 && px>0) drawn++;
            }
            check(count==2,"two equal-id native enemies received");
            check(drawn==2,"both enemy sprites rendered after real vision frames");
         }
         if(host && !finished && n>=95)
         {
            finished=true;
            check(door!=null && !door.inter.open,"native join close returned");
            check(script!=null && script.tiles[0].phis!=0,"native script close returned");
            check(box!=null && box.dead,"native join destruction returned");
            Log.d("COOP NETWORK DONE host");
         }
         if(!host && checked && !finished && n>=90)
         {
            finished=true;
            check(door!=null && !door.inter.open,"native close stays converged");
            Log.d("COOP NETWORK DONE join");
         }
      }
   }
}
