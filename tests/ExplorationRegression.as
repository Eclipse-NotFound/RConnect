package
{
   import rconnect.core.Log;
   import rconnect.game.ExplorationSync;
   import flash.display.BitmapData;
   public class ExplorationRegression
   {
      private static var failed:int;
      private static var passed:int;
      private static function check(ok:Boolean, name:String):void
      {
         if(ok) passed++; else failed++;
         Log.d("COOP " + (ok ? "PASS " : "FAIL ") + "exploration " + name);
      }
      public static function run(mod:RConnectMod):void
      {
         failed=passed=0;
         var grid:Object={spaceX:5,spaceY:3,space:[]};
         for(var x:int=0;x<5;x++) { grid.space[x]=[]; for(var y:int=0;y<3;y++) grid.space[x][y]={visi:0}; }
         grid.space[4][2].visi=1;
         var rows:Array=ExplorationSync.nativeRows(grid);
         check(rows.length==3 && rows[2].length==85 && rows[2].substr(68,17)=="fffffffffffffffff",
            "rectangular bottom-right tile uses space[x][y]");
         grid.space[4][2].visi=0;
         grid.retDark=false; grid.grafon={lightBmp:new BitmapData(8,6,true,0xff000000)};
         ExplorationSync.paintNative(grid,rows);
         check(grid.grafon.lightBmp.getPixel32(4,3)==0 && grid.grafon.lightBmp.getPixel32(3,3)==0xff000000,
            "native shared terrain paints full brightness at correct bitmap offset");
         check(grid.space[4][2].visi==0,"native visual overlay does not grant interaction light");
         grid.retDark=true;grid.grafon.lightBmp.fillRect(grid.grafon.lightBmp.rect,0xff000000);
         ExplorationSync.paintNative(grid,rows);
         check(grid.grafon.lightBmp.getPixel32(4,3)==0xff000000,"native retDark rule preserved");
         grid.grafon.lightBmp.dispose();
         grid.space[3][1].visi=1;
         check(ExplorationSync.nativeRows(grid)[1].charAt(51)=="f","ongoing exploration is recollected");
         check(!ExplorationSync.validRows(["f"],5,3),"truncated rows rejected");
         check(!ExplorationSync.validRows(rows,3,5),"equal-area wrong shape rejected");
         check(!ExplorationSync.validRows(rows,201,3),"oversize rejected");
         var malformed:Array=rows.concat(); malformed[0]="Z"+rows[0].substr(1);
         check(!ExplorationSync.validRows(malformed,5,3),"invalid encoding rejected before apply");
         var union:Array=ExplorationSync.unionRows(["51000000000000000"],["a2000000000000000"]);
         check(union[0]=="a3000000000000000","brightness max and complementary subcell union");
         check(ExplorationSync.unionRows(union,["00000000000000000"])[0]==union[0],"later empty snapshot retains memory");
         var sync:ExplorationSync=mod.exploration;
         var enabled:* = mod.config.getValue("sharedExploration");
         try
         {
            mod.config.setValue("sharedExploration","1");
            sync.resetLink();
            var p:Object=sync.packet();
            check(p!=null,"live room snapshot available");
            if(p==null) return;
            var wire:Object=JSON.parse(JSON.stringify(p));
            wire.epoch="test-peer"; wire.to="stale";
            check(!sync.receive(wire),"room-instance handshake required");
            wire.to=p.epoch;
            var native:Number=mod.game.loc.space[1][1].visi;
            var target:Number=mod.game.loc.space[1][1].t_visi;
            check(sync.receive(wire),"acknowledged live room accepted");
            var delta:Object=JSON.parse(JSON.stringify(wire));
            delete delta.rows;delta.changes=[[1,p.rows[1]]];
            check(sync.receive(delta),"validated row delta applies after full baseline");
            delta.changes=[[1,p.rows[1]],[1,p.rows[1]]];
            check(!sync.receive(delta),"duplicate delta rows rejected atomically");
            delta.changes=[[p.height,p.rows[1]]];
            check(!sync.receive(delta),"out of range delta row rejected");
            delta.changes=[[1,"broken"]];
            check(!sync.receive(delta),"truncated delta rejected");
            delta.changes=[[1,p.rows[1]]];delta.epoch="different-peer";
            check(!sync.receive(delta),"delta cannot reuse a different room-instance baseline");
            check(mod.game.loc.space[1][1].visi===native && mod.game.loc.space[1][1].t_visi===target,
               "sharing leaves native interaction light unchanged");
            wire.room=p.room+"other";
            check(!sync.receive(wire),"different map identity rejected");
            wire.room=p.room;
            mod.config.setValue("sharedExploration","0");
            check(!sync.receive(wire),"local receive switch rejects new knowledge");
            sync.resetLink();
            delta.epoch="test-peer";
            check(!sync.receive(delta),"delta requires a fresh full baseline after reset");
            var disabled:Object=sync.packet();
            check(disabled!=null,"disabled receiver still shares with enabled teammate");
            check(disabled!=null && JSON.stringify(disabled.rows)==JSON.stringify(p.rows),"acquired map survives toggle and link reset");
            mod.config.setValue("sharedExploration","1");
            check(!sync.receive(wire),"old session token cannot write after reset");
            var carrier:Object=mod.main.getChildByName("RVExplorationAPI");
            if(carrier!=null)
            {
               check(carrier.api.version===1 && carrier.api.merge(mod.game.loc,p.rows)===true,
                  "real optional RV API accepts cross-domain data");
               check(carrier.api.merge(mod.game.loc,["broken"])===false,"RV API rejects malformed data");
            }
            else check(true,"native fallback runs without RV installed");
         }
         finally { mod.config.setValue("sharedExploration",enabled); sync.resetLink(); }
         Log.d("COOP EXPLORATION DONE passed="+passed+" failed="+failed);
      }
   }
}
