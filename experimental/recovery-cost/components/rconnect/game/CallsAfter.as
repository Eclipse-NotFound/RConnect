package rconnect.game { public class CallsAfter {
public var loc:Object;public var _wall:Object;public var _terrain:Object;
public function readTilePatch():Array {var list:Array=_terrain.hostPatch(loc);_wall.observe(loc,list);return list;}
public function scanTileReports():Object {
         var report:Object=_terrain.report(loc);_wall.observe(loc,report==null?null:report.tiles as Array);
         var paint:Object=_wall.report(loc,false);
         if(paint!=null){if(report==null)report={tiles:[]};report.wall=paint;}
         return report;
      }
public function readWallPaint(observeNow:Boolean=true):Array {return _wall.snapshot(loc,observeNow);}
// This segment is extracted verbatim from Session; envelope/native terrain are fixtures.
public function hostPair():Object{var mod:Object={game:this};var usMsg:Object={};
               var tpatch:Array = mod.game.readTilePatch();
               if(tpatch != null)
               {
                  usMsg.tilePatch = tpatch;
               }
               // readTilePatch just observed native contacts and this terrain delta.
               usMsg.wallPaint=mod.game.readWallPaint(false);
return usMsg;}
}}
