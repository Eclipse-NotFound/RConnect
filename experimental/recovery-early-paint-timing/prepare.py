"""Prepare one diagnostic-only Grafon source; never compile or install."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / 'build/m52/recovery-early-host-01'
HOST_SHA = '2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29'
SOURCE_SHA = 'e6b4142462c1187388c4bb9c8151dd6c2605ce4e4b9fedd421cf4749c54bd7a0'
SOURCE = BASE / 'after/scripts/fe/graph/Grafon.as'
TARGET = HERE / 'src/fe/graph/Grafon.as'

OLD = '''      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void
      {
         if(this.rconnectRasterWaiting())
         {
            return;
         }
         if(this.scenePreload && this.sceneResident == Math.ceil(this.loc.limX / this.sceneSide) * Math.ceil(this.loc.limY / this.sceneSide))
         {
            return;
         }
         if(this.scenePreload)
         {
            this.scenePreloadAll();
            return;
         }
         this.sceneEnsureUpcoming(left,top,width,height);
      }'''

NEW = '''      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void
      {
         if(this.rconnectRasterWaiting())
         {
            return;
         }
         if(this.scenePreload && this.sceneResident == Math.ceil(this.loc.limX / this.sceneSide) * Math.ceil(this.loc.limY / this.sceneSide))
         {
            return;
         }
         // Diagnostic host only: retain the subscriber and identities for this
         // exact invocation. Nothing is allocated when there is no subscriber.
         var paintObserver:Function = rconnectPaintTimingBridge;
         var paintWorld:Object;
         var paintGame:Object;
         var paintLoc:Location;
         var paintStarted:int;
         var paintStartedWall:Number;
         var paintResident:int;
         var paintPreload:Boolean;
         var paintWorldRenderer:Boolean;
         var paintWorldLoc:Boolean;
         if(paintObserver != null)
         {
            try
            {
               paintWorld = World.w;
               paintGame = paintWorld != null ? paintWorld.game : null;
               paintLoc = this.loc;
               paintWorldRenderer = paintWorld != null && paintWorld.grafon === this;
               paintWorldLoc = paintWorld != null && paintWorld.loc === paintLoc;
               paintResident = this.sceneResident;
               paintPreload = this.scenePreload;
               paintStartedWall = new Date().time;
               paintStarted = int(getTimer());
            }
            catch(paintCaptureError:*)
            {
               ++rconnectPaintTimingFaults;
               paintObserver = null;
            }
         }
         var paintCompleted:Boolean = false;
         try
         {
            if(this.scenePreload)
            {
               this.scenePreloadAll();
               paintCompleted = true;
               return;
            }
            this.sceneEnsureUpcoming(left,top,width,height);
            paintCompleted = true;
         }
         finally
         {
            if(paintObserver != null)
            {
               // Both end clocks precede allocation and the external callback.
               // Catch the entire observer path so it cannot replace an error
               // thrown by either original drawing branch.
               try
               {
                  var paintFinished:int = int(getTimer());
                  var paintFinishedWall:Number = new Date().time;
                  paintObserver(this,paintWorld,paintGame,paintLoc,{
                     phase:"ensure-work",
                     preload:paintPreload,
                     initial:initial,
                     left:left,
                     top:top,
                     width:width,
                     height:height,
                     started:paintStarted,
                     finished:paintFinished,
                     startedWall:paintStartedWall,
                     finishedWall:paintFinishedWall,
                     residentBefore:paintResident,
                     residentAfter:this.sceneResident,
                     completed:paintCompleted,
                     sameWorld:World.w === paintWorld,
                     sameGame:World.w != null && World.w.game === paintGame,
                     sameLoc:this.loc === paintLoc,
                     worldRendererAtStart:paintWorldRenderer,
                     worldRendererAtEnd:World.w != null && World.w.grafon === this,
                     worldLocAtStart:paintWorldLoc,
                     worldLocAtEnd:World.w != null && World.w.loc === paintLoc
                  });
               }
               catch(paintObserverError:*)
               {
                  ++rconnectPaintTimingFaults;
               }
            }
         }
      }'''

SLOT = '      public static var rconnectRasterBridge:Function = null;'
ADDED = SLOT + '\n      \n      public static var rconnectPaintTimingBridge:Function = null;\n      \n      public static var rconnectPaintTimingFaults:uint = 0;'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def transform(data):
    assert sha(data) == SOURCE_SHA, 'Only the precise exported Grafon is accepted'
    text = data.decode('utf-8').replace('\r\n', '\n')
    assert text.count(OLD) == 1 and text.count(SLOT) == 1
    return text.replace(SLOT, ADDED, 1).replace(OLD, NEW, 1).replace('\n', '\r\n').encode('utf-8')

def main():
    assert sha((BASE / 'pfe.swf').read_bytes()) == HOST_SHA
    before = SOURCE.read_bytes()
    after = transform(before)
    if TARGET.exists():
        assert TARGET.read_bytes() == after, 'Never overwrite a changed prepared source'
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_bytes(after)
    patch = ''.join(difflib.unified_diff(before.decode('utf-8').splitlines(True), after.decode('utf-8').splitlines(True), fromfile='2D415D/Grafon.as', tofile='diagnostic/Grafon.as'))
    (HERE / 'Grafon.patch').write_text(patch, encoding='utf-8', newline='')
    manifest = dict(diagnostic_only=True, compiled=False, runtime_qualified=False, performance_qualified=False,
                    original_host=str(BASE / 'pfe.swf'), original_host_sha256=HOST_SHA,
                    original_source=str(SOURCE), original_source_sha256=SOURCE_SHA,
                    prepared_source_sha256=sha(after), changed_methods=['sceneEnsure'],
                    added_fields=['rconnectPaintTimingBridge', 'rconnectPaintTimingFaults'], production_files_changed=False)
    (HERE / 'prepared.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(manifest, ensure_ascii=False))

if __name__ == '__main__':
    main()
