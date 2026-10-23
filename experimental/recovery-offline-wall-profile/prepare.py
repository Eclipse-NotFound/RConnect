"""Prepare an opt-in, source-only wall profiler from the exact EB365 freeze.

No compiler, game process, configuration, release file, or other mod is touched.
Run once to materialize the two-file overlay and provenance; later --verify only.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
MOD = HERE.parents[1]
BASE = MOD / "build/m52/recovery-offline-production-01"
EXPECTED = {
    "RConnectMod.swf": "eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee",
    "src/rconnect/game/GameBridge.as": "c6b8aba21735ce4becb9c6ac398f4024b15bb02694386c51159bb667144cb4aa",
    "src/rconnect/game/WallImpactVisuals.as": "e1125fa1865598705c1753fd8e49ede037cd16936a680a7a078c4cf9b5ac5a34",
    "prepared.json": "c15ee493fdfeb804a2dd39c9710b3127c7ba7f458efd238f6fab8443eea6d5e7",
    "compile.json": "da37c6c00d922df3b900b9b3e4ac4e086a4dd3309989b49d28eaaf8772ae671d",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(text, old, new, operations):
    if text.count(old) != 1:
        raise RuntimeError("Non-unique diagnostic anchor: " + old[:100])
    operations.append((old, new))
    return text.replace(old, new, 1)


def game_overlay(text, ops):
    def rep(old, new):
        nonlocal text
        text = replace_once(text, old, new, ops)

    rep("         _wall.observe(loc);\n         if(gg!=null)_ports.observe",
        """         if(_wall.profileEnabled)
         {
            var wallStarted:int=getTimer();
            try {_wall.observe(loc);}
            finally {_wall.profileFrameEnd(false,getTimer()-wallStarted);}
         }
         else _wall.observe(loc);
         if(gg!=null)_ports.observe""")
    rep("         if(!roomHold)_wall.before(loc);",
        """         if(!roomHold)
         {
            if(_wall.profileEnabled)
            {
               var wallStarted:int=getTimer();
               try {_wall.before(loc);}
               finally {_wall.profileFrameEnd(true,getTimer()-wallStarted);}
            }
            else _wall.before(loc);
         }""")
    rep("      private var _wallLand:Object;",
        """      private var _wallLand:Object;
      // Diagnostic overlay only. Resetting counters never resets wall history.
      public function wallProfileStart():void {_wall.profileStart();}
      public function wallProfileRead():Object {return _wall.profileRead();}
      public function wallProfileStop():Object {return _wall.profileStop();}""")
    return text


PROFILE_API = """
      // Opt-in aggregate diagnostics; independent of room/session/wall state.
      private var _wallProfile:Object=null;
      private var _wallProfileEnabled:Boolean=false;
      public function get profileEnabled():Boolean {return _wallProfileEnabled;}
      public function profileStart():void
      {
         _wallProfile={startedAtMs:getTimer(),stoppedAtMs:0,
            frameBeforeCalls:0,frameBeforeMs:0,frameBeforeMaxMs:0,
            frameObserveCalls:0,frameObserveMs:0,frameObserveMaxMs:0,
            beforeCalls:0,beforeNoFront:0,beforeRebuildAttempts:0,beforeRebuildCompleted:0,tileSnapshotCells:0,
            cloneAttempts:0,cloneSucceeded:0,cloneFailed:0,clonePixels:0,
            observeCalls:0,observeActive:0,objectChainVisited:0,objectChainLimitHits:0,
            projectileObjects:0,candidatesAvailable:0,carriedCandidates:0,tilesSupplied:0,
            workCellsVisited:0,nonSolidWorkCells:0,cellCompareCalls:0,changedCells:0,
            redrawCalls:0,roleChangedCalls:0,resetCalls:0};
         _wallProfileEnabled=true;
      }
      public function profileRead():Object
      {
         var out:Object={schema:"rc-eb365-wall-profile-r1",enabled:_wallProfileEnabled,started:_wallProfile!=null};
         if(_wallProfile==null)return out;
         for(var key:String in _wallProfile)out[key]=_wallProfile[key];
         out.sampledAtMs=getTimer();
         out.windowMs=(_wallProfileEnabled?out.sampledAtMs:out.stoppedAtMs)-out.startedAtMs;
         return out;
      }
      public function profileStop():Object
      {
         if(_wallProfileEnabled)_wallProfile.stoppedAtMs=getTimer();
         _wallProfileEnabled=false;
         return profileRead();
      }
      // Called after the ending timestamp: accumulation is outside that timer.
      public function profileFrameEnd(isBefore:Boolean,elapsed:int):void
      {
         var p:Object=_wallProfileEnabled?_wallProfile:null;
         if(p==null)return;
         if(isBefore)
         {
            p.frameBeforeCalls++;p.frameBeforeMs+=elapsed;
            if(elapsed>p.frameBeforeMaxMs)p.frameBeforeMaxMs=elapsed;
         }
         else
         {
            p.frameObserveCalls++;p.frameObserveMs+=elapsed;
            if(elapsed>p.frameObserveMaxMs)p.frameObserveMaxMs=elapsed;
         }
      }
"""


def wall_overlay(text, ops):
    def rep(old, new):
        nonlocal text
        text = replace_once(text, old, new, ops)

    rep("   import flash.utils.Dictionary;", "   import flash.utils.Dictionary;\n   import flash.utils.getTimer;")
    rep("      public var dirty:Boolean=false;", "      public var dirty:Boolean=false;\n" + PROFILE_API)
    rep("""      public function before(loc:Object):void
      {
         var b:BitmapData=front(loc);
         if(b==null)return;
         if(active!==loc || bitmap!==b || shadow==null)
         {
            if(shadow!=null)shadow.dispose();""",
        """      public function before(loc:Object):void
      {
         var p:Object=_wallProfileEnabled?_wallProfile:null;
         if(p!=null)p.beforeCalls++;
         var b:BitmapData=front(loc);
         if(b==null) {if(p!=null)p.beforeNoFront++;return;}
         if(active!==loc || bitmap!==b || shadow==null)
         {
            if(p!=null)p.beforeRebuildAttempts++;
            if(shadow!=null)shadow.dispose();""")
    rep("""               tileState[id(x,y)]={h:Number(loc.space[x][y].hp),p:Number(loc.space[x][y].phis)};
         }
      }""",
        """               tileState[id(x,y)]={h:Number(loc.space[x][y].hp),p:Number(loc.space[x][y].phis)};
            if(p!=null) {p.beforeRebuildCompleted++;p.tileSnapshotCells+=Number(x)*Number(y);}
         }
      }""")
    rep("""      private function copyFront(loc:Object,b:BitmapData,where:String):BitmapData
      {
         try {return b.clone();}
         catch(error:Error)
         {
            if(bitmapDiagnostics++<4)""",
        """      private function copyFront(loc:Object,b:BitmapData,where:String):BitmapData
      {
         var p:Object=_wallProfileEnabled?_wallProfile:null;
         if(p!=null)p.cloneAttempts++;
         try
         {
            var copy:BitmapData=b.clone();
            if(p!=null) {p.cloneSucceeded++;p.clonePixels+=Number(copy.width)*Number(copy.height);}
            return copy;
         }
         catch(error:Error)
         {
            if(p!=null)p.cloneFailed++;
            if(bitmapDiagnostics++<4)""")
    rep("""      public function observe(loc:Object,tiles:Array=null):void
      {
         before(loc);
         if(loc!==active || shadow==null || front(loc)!==bitmap)return;
         var work:Object={},objects:Array=[],visited:Dictionary=new Dictionary(true);""",
        """      public function observe(loc:Object,tiles:Array=null):void
      {
         var p:Object=_wallProfileEnabled?_wallProfile:null;
         if(p!=null)p.observeCalls++;
         before(loc);
         if(loc!==active || shadow==null || front(loc)!==bitmap)return;
         if(p!=null) {p.observeActive++;if(tiles!=null)p.tilesSupplied+=tiles.length;}
         var work:Object={},objects:Array=[],visited:Dictionary=new Dictionary(true);""")
    rep("""         // PhisBullet can remove itself in the contact frame. Its real object""",
        """         // Count the existing traversal guard, without adding work per object.
         if(p!=null)
         {
            p.objectChainVisited+=guard>10000?10000:guard;
            if(o!=null && guard>10000)p.objectChainLimitHits++;
            p.projectileObjects+=objects.length;
         }
         // PhisBullet can remove itself in the contact frame. Its real object""")
    rep("""         for each(o in tracked)if(!visited[o])candidates.push(o);
         for each(o in candidates)""",
        """         for each(o in tracked)if(!visited[o])candidates.push(o);
         if(p!=null) {p.candidatesAvailable+=candidates.length;p.carriedCandidates+=candidates.length-objects.length;}
         for each(o in candidates)""")
    rep("""         for(k in work)
         {
            var xy:Array=k.split(",");tx=int(xy[0]);ty=int(xy[1]);""",
        """         for(k in work)
         {
            if(p!=null)p.workCellsVisited++;
            var xy:Array=k.split(",");tx=int(xy[0]);ty=int(xy[1]);""")
    rep("""            if(!solid(loc,tx,ty)) {discard(loc,k);shadow.copyPixels(bitmap,rect(tx,ty,bitmap),new Point(tx*CELL,ty*CELL));continue;}""",
        """            if(!solid(loc,tx,ty)) {if(p!=null)p.nonSolidWorkCells++;discard(loc,k);shadow.copyPixels(bitmap,rect(tx,ty,bitmap),new Point(tx*CELL,ty*CELL));continue;}""")
    rep("""         var difference:*=scratchA.compare(scratchB);
         if(!(difference is BitmapData))return;
         var d:BitmapData=difference as BitmapData;""",
        """         var p:Object=_wallProfileEnabled?_wallProfile:null;
         if(p!=null)p.cellCompareCalls++;
         var difference:*=scratchA.compare(scratchB);
         if(!(difference is BitmapData))return;
         if(p!=null)p.changedCells++;
         var d:BitmapData=difference as BitmapData;""")
    rep("""      public function redraw(loc:Object):void
      {
         var b:BitmapData=front(loc);if(b==null)return;""",
        """      public function redraw(loc:Object):void
      {
         if(_wallProfileEnabled)_wallProfile.redrawCalls++;
         var b:BitmapData=front(loc);if(b==null)return;""")
    rep("""      public function roleChanged(loc:Object):void
      {
         var s:Object=state(loc);""",
        """      public function roleChanged(loc:Object):void
      {
         if(_wallProfileEnabled)_wallProfile.roleChangedCalls++;
         var s:Object=state(loc);""")
    rep("""      public function reset():void
      {
         if(shadow!=null)shadow.dispose();""",
        """      public function reset():void
      {
         if(_wallProfileEnabled)_wallProfile.resetCalls++;
         if(shadow!=null)shadow.dispose();""")
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    for rel, expected in EXPECTED.items():
        if sha((BASE / rel).read_bytes()) != expected:
            raise RuntimeError("Frozen input changed: " + rel)
    outputs = {}
    patches = []
    operations_count = {}
    for rel, transform in [("src/rconnect/game/GameBridge.as", game_overlay),
                           ("src/rconnect/game/WallImpactVisuals.as", wall_overlay)]:
        raw = (BASE / rel).read_bytes()
        eol = "\r\n" if b"\r\n" in raw else "\n"
        old = raw.decode("utf-8").replace("\r\n", "\n")
        ops = []
        new = transform(old, ops)
        back = new
        for previous, changed in reversed(ops):
            if back.count(changed) != 1:
                raise RuntimeError("Reverse diagnostic anchor is ambiguous")
            back = back.replace(changed, previous, 1)
        if back.replace("\n", eol).encode("utf-8") != raw:
            raise RuntimeError("Diagnostic additions do not reverse to exact base")
        outputs[rel] = new.replace("\n", eol).encode("utf-8")
        operations_count[rel] = len(ops)
        patches.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                       fromfile="EB365/" + rel, tofile="wall-profile-r1/" + rel))
    outputs["profile.patch"] = "".join(patches).encode("utf-8")
    manifest = {
        "schema": "rc-eb365-wall-profile-source-r1",
        "scope": "diagnostic source overlay only; not compiled, run, or deployed",
        "base": str(BASE), "base_proof": EXPECTED,
        "all_base_as_sources": {p.relative_to(BASE).as_posix(): sha(p.read_bytes())
                                for p in sorted((BASE / "src").rglob("*.as"))},
        "source_overlay": [r for r in outputs if r.endswith(".as")],
        "diagnostic_operations": operations_count,
        "exact_base_restored_when_diagnostic_operations_reversed": True,
        "outputs": {r: sha(b) for r, b in outputs.items()},
        "compiled": False, "runtime_validated": False, "deployable": False,
    }
    outputs["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    for rel, data in outputs.items():
        target = HERE / rel
        if args.verify:
            if target.read_bytes() != data:
                raise RuntimeError("Diagnostic output differs: " + rel)
        else:
            if target.exists():
                raise RuntimeError("Refusing to overwrite prepared file: " + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    print(json.dumps({"verified" if args.verify else "prepared": True,
                      "overlay_sources": len(manifest["source_overlay"]),
                      "base_as_sources": len(manifest["all_base_as_sources"]),
                      "outputs": manifest["outputs"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
