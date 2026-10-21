package rconnect.game { public class CallsBefore {
public var loc:Object;public var _wall:Object;public var _terrain:Object;
public function readTilePatch():Array {var list:Array=_terrain.hostPatch(loc);_wall.observe(loc,list);return list;}
public function scanTileReports():Object {
         var report:Object=_terrain.report(loc);_wall.observe(loc,report==null?null:report.tiles as Array);
         var paint:Object=_wall.report(loc);
         if(paint!=null){if(report==null)report={tiles:[]};report.wall=paint;}
         return report;
      }
public function readWallPaint():Array {return _wall.snapshot(loc);}
// This segment is extracted verbatim from Session; envelope/native terrain are fixtures.
public function hostPair():Object{var mod:Object={game:this};var usMsg:Object={};
               var tpatch:Array = mod.game.readTilePatch();
               if(tpatch != null)
               {
                  usMsg.tilePatch = tpatch;
               }
               usMsg.wallPaint=mod.game.readWallPaint();
return usMsg;}
}}
