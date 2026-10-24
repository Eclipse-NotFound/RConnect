"""Text-only exact-source preparation; never starts Java/AIR or installs files."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-room-production-05'
HOST=ROOT/'build/m52/recovery-room-first-raster-current-source-02/source/scripts/fe/World.as'
HOST_SHA='f9b5d270ad95a223ca37b0e339dcee1380856dff6254a5b1a0d9b12d997aaf16'
PRODUCT_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
VIEW_SHA='4cb479f39262f631b834c6290f78fcaec3b3cc102bb56f9886a71791a05efe0b'
METHODS=['resizeScreen','loadGame','ativateLoc','setLoadScreen','offLoadScreen','showScene','unshowScene','endgame']

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def text(p):return p.read_bytes().decode('utf-8-sig').replace('\r\n','\n')
def put(p,s):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_bytes(s.encode('utf-8'))
def check_inputs():
    if sha(HOST)!=HOST_SHA or sha(BASE/'RConnectMod.swf')!=PRODUCT_SHA or sha(BASE/'src/rconnect/ui/RoomEntryView.as')!=VIEW_SHA:
        raise RuntimeError('Exact frozen baseline changed')

def generate():
    check_inputs()
    before=text(HOST)
    fragment=text(HERE/'WorldLoadingLease.fragment.as')
    marker='   public class World\n   {\n'
    if before.count(marker)!=1:raise RuntimeError('World class marker not unique')
    after=before.replace(marker,marker+fragment+'\n',1)
    for name in METHODS:
        needle='function '+name+'('
        if after.count(needle)!=1:raise RuntimeError('Native method not unique: '+name)
        body=after.index('\n      {',after.index(needle))+len('\n      {')
        after=after[:body]+'\n         this.rconnectUiNativeDisplay();'+after[body:]
    needle='function newGame('
    if after.count(needle)!=1:raise RuntimeError('Native newGame not unique')
    body=after.index('\n      {',after.index(needle))+len('\n      {')
    after=after[:body]+'\n         this.rconnectUiNativeDisplay(true);'+after[body:]
    needle='               this.pip.noAct = false;\n            }\n            if(this.t_exit == 1)'
    if after.count(needle)!=1:raise RuntimeError('Native exit16 boundary not unique')
    after=after.replace(needle,'               this.pip.noAct = false;\n               this.rconnectUiAfterExitDisplay();\n            }\n            if(this.t_exit == 1)',1)
    put(HERE/'host/fe/World.as',after)
    version=text(BASE/'src/RConnectMod.as')
    if version.count('0.2.24-roomfix5')!=1:raise RuntimeError('Unexpected version')
    put(HERE/'src/RConnectMod.as',version.replace('0.2.24-roomfix5','0.2.24-nativeui1'))
    fixture=text(HERE/'fixtures/FakeNativeLoadingWorld.prefix.txt')+fragment+text(HERE/'fixtures/FakeNativeLoadingWorld.suffix.txt')
    put(HERE/'tests/FakeNativeLoadingWorld.as',fixture)
    put(HERE/'tests/rconnect/ui/RoomEntryView.as',text(HERE/'src/rconnect/ui/RoomEntryView.as'))
    diffs=[]
    for label,old,new in [('host/fe/World.as',before,after),('src/rconnect/ui/RoomEntryView.as',text(BASE/'src/rconnect/ui/RoomEntryView.as'),text(HERE/'src/rconnect/ui/RoomEntryView.as')),('src/RConnectMod.as',text(BASE/'src/RConnectMod.as'),text(HERE/'src/RConnectMod.as'))]:
        diffs.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='baseline/'+label,tofile='candidate/'+label))
    put(HERE/'source.diff',''.join(diffs))
    meta={'kind':'native-loading-ui-source-candidate','version':'0.2.24-nativeui1','base_product_sha256':PRODUCT_SHA,
          'base_host_sha256':'a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7',
          'baseline_world_source_sha256':HOST_SHA,'native_writer_hooks':METHODS,'native_wait_handoff_hook':'newGame','compiled':False,'runtime_validated':False,
          'product_overlay':{str(p.relative_to(HERE/'src')).replace('\\','/'):sha(p) for p in sorted((HERE/'src').rglob('*.as'))},
          'host_source_sha256':sha(HERE/'host/fe/World.as'),
          'inputs':{str(p.relative_to(HERE)).replace('\\','/'):sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix in ('.as','.py','.txt')},
          'source_diff_sha256':sha(HERE/'source.diff')}
    put(HERE/'source-manifest.json',json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
    return verify()

def verify():
    check_inputs()
    meta=json.loads((HERE/'source-manifest.json').read_text(encoding='utf-8'))
    for p,h in meta['inputs'].items():
        if sha(HERE/p)!=h:raise RuntimeError('Candidate source changed: '+p)
    after=text(HERE/'host/fe/World.as')
    fragment=text(HERE/'WorldLoadingLease.fragment.as')
    stripped=after.replace(fragment+'\n','',1)
    if stripped.count('         this.rconnectUiNativeDisplay();\n')!=len(METHODS):raise RuntimeError('Native writer hook count')
    stripped=stripped.replace('         this.rconnectUiNativeDisplay();\n','')
    if stripped.count('         this.rconnectUiNativeDisplay(true);\n')!=1:raise RuntimeError('Native new-game handoff count')
    stripped=stripped.replace('         this.rconnectUiNativeDisplay(true);\n','')
    if stripped.count('               this.rconnectUiAfterExitDisplay();\n')!=1:raise RuntimeError('Native tail hook count')
    stripped=stripped.replace('               this.rconnectUiAfterExitDisplay();\n','')
    if stripped!=text(HOST):raise RuntimeError('Original native logic did not round trip exactly')
    if text(HERE/'src/RConnectMod.as').replace('0.2.24-nativeui1','0.2.24-roomfix5')!=text(BASE/'src/RConnectMod.as'):raise RuntimeError('Unexpected product entry change')
    view=text(HERE/'src/rconnect/ui/RoomEntryView.as')
    if any(x in view for x in ('Sprite','new factory','graphics.','addChild','setLoadScreen','onPause','controlOn','controlOff')):raise RuntimeError('Adapter owns native display/control')
    if any(x in fragment for x in ('Math.random','setLoadScreen(','offLoadScreen(','controlOn(','controlOff(','onPause =','t_exit =','gotoAndStop','new Sprite','addChild')):raise RuntimeError('Lease changed gameplay/artwork selection')
    if sha(HERE/'source.diff')!=meta['source_diff_sha256']:raise RuntimeError('Diff changed')
    if text(HERE/'tests/rconnect/ui/RoomEntryView.as')!=view:raise RuntimeError('Component adapter differs')
    if text(HERE/'tests/FakeNativeLoadingWorld.as')!=text(HERE/'fixtures/FakeNativeLoadingWorld.prefix.txt')+fragment+text(HERE/'fixtures/FakeNativeLoadingWorld.suffix.txt'):raise RuntimeError('Component helper differs')
    return {'source_passed':True,'compiled':False,'runtime_validated':False,'manifest_sha256':sha(HERE/'source-manifest.json'),'host_source_sha256':sha(HERE/'host/fe/World.as')}

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--generate',action='store_true');ap.add_argument('--check',action='store_true');a=ap.parse_args()
    print(json.dumps(generate() if a.generate else verify(),ensure_ascii=False))
