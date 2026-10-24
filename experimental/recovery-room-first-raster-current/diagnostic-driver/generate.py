"""Generate only external metrics glue; keep native travel stimuli byte exact."""
from pathlib import Path
import argparse, difflib, hashlib, json, sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = ROOT/'build/m52/recovery-room-scene-driver-02/tests'
PRODUCT = ROOT/'build/m52/recovery-room-first-raster-product-01/src/rconnect/core'
INPUTS = {
    BASE/'RoomTravelTimingTestDoc.as': '226001bfb880363615c98d697ef0b1ea224545f749123b14987160f91e0998e3',
    BASE/'RoomTravelSceneTestDoc.as': '4192ba6668a9927ab08d8fa931a535106d425e2732d749cccd15cea42ef43d06',
    BASE/'A22RoomMetrics.as': '314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e',
    ROOT/'experimental/recovery-early-sandy-native/tests/FirstRasterSceneProbe.as':
        '785e63b0c315941a81fccb5fc17832a10543fe83545435905ef9ff6ce7f7c789',
    ROOT/'build/m52/recovery-room-first-raster-current-source-02/source/scripts/fe/graph/Grafon.as':
        '667d4295f417e67dbc7298a082e5b409cdba5a4c3b61c0104a0840bbd9b12540',
    PRODUCT/'RoomSync.as': 'dcf929fb066dc1d807c18176cb4a27485604a1582fc6580c8459d27d697c8ccf',
    PRODUCT/'EarlyTravelGate.as': '544d61b428ca0e3b3daf603eb0a8c8546fc01a64d22834c73f7d90d323f6a814',
}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def generated():
    for path, digest in INPUTS.items():
        assert sha(path) == digest, str(path)
    metrics = (BASE/'A22RoomMetrics.as').read_bytes()
    changes = [
        (b'      private var lastRoomOp:String="",lastPeerPhase:String="";\n',
         b'      private var lastRoomOp:String="",lastPeerPhase:String="";\n      private var raster:FirstRasterSceneProbe;\n'),
        (b'         mod=m;mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100006);',
         b'         mod=m;raster=new FirstRasterSceneProbe(mod);mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100006);'),
        (b'      private function before(e:NetMessageEvent):void {\n',
         b'      private function before(e:NetMessageEvent):void {\n         raster.before(e);\n'),
        (b'         var p:Object=e.data,now:int=getTimer(),began:int=starts[e];delete starts[e];\n',
         b'         var p:Object=e.data,now:int=getTimer(),began:int=starts[e];delete starts[e];\n         raster.after(e);\n'),
        (b'            peerPhaseSource:"last received room-test message, not local fixture phase"}));\n',
         b'            peerPhaseSource:"last received room-test message, not local fixture phase"}));\n         raster.finish();\n'),
    ]
    original = metrics
    for before, after in changes:
        assert metrics.count(before) == 1
        metrics = metrics.replace(before, after)
    restored = metrics
    for before, after in reversed(changes):
        assert restored.count(after) == 1
        restored = restored.replace(after, before)
    assert restored == original
    return {name: (BASE/name).read_bytes() for name in ('RoomTravelTimingTestDoc.as', 'RoomTravelSceneTestDoc.as')} | {
        'A22RoomMetrics.as': metrics,
        'FirstRasterSceneProbe.as': (HERE/'tests/FirstRasterSceneProbe.as').read_bytes(),
    }

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    files = generated()
    chunks = []
    for name in ('A22RoomMetrics.as', 'FirstRasterSceneProbe.as'):
        before = (BASE/name).read_text(encoding='utf-8') if (BASE/name).exists() else ''
        after = files[name].decode('utf-8').replace('\r\n', '\n')
        chunks.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile='scene-driver02/tests/'+name if before else '/dev/null', tofile='diagnostic-driver/tests/'+name))
    diff = ''.join(chunks).encode('utf-8')
    meta = dict(kind='first-raster-current-four-node-v1', compiled=False, air_started=False,
        diagnosticOnly=True, performanceQualified=False, unchanged_stimuli=['RoomTravelTimingTestDoc.as', 'RoomTravelSceneTestDoc.as'],
        sources={name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())},
        inputs={str(path): digest for path, digest in INPUTS.items()}, generator_sha256=sha(__file__),
        source_diff_sha256=hashlib.sha256(diff).hexdigest())
    if args.check:
        assert json.loads((HERE/'source-manifest.json').read_text(encoding='utf-8')) == meta
        assert (HERE/'source.diff').read_bytes() == diff
        assert {p.name for p in (HERE/'tests').iterdir() if p.is_file()} == set(files)
        for name, data in files.items():
            assert (HERE/'tests'/name).read_bytes() == data
    else:
        for name, data in files.items():
            (HERE/'tests'/name).write_bytes(data)
        (HERE/'source.diff').write_bytes(diff)
        (HERE/'source-manifest.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(checked=True, mode='check' if args.check else 'prepare-sources', sources=meta['sources'],
        manifest_sha256=sha(HERE/'source-manifest.json'), compiled=False, air_started=False)))

if __name__ == '__main__':
    main()
