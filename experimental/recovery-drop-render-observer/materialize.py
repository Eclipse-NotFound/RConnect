"""AS/text-only external observer assembly. Never launches compiler or AIR."""
from pathlib import Path
import difflib, hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/motion2-continuity-drivers-01'
PIN='2e998334580505028b9fa58d3daa6067e3eaa92d3df313db4ecfeeba26a8e6f9'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def changes():
    blob=(HERE/'observer.as.txt').read_text('utf-8')
    old='                  lootArrivals.push({received:getTimer(),sample:received.sampleTime,x:received.x,y:received.y,stay:received.stay});'
    return [
      ('      public function PresentationContinuityTestDoc(',blob+'\n      public function PresentationContinuityTestDoc('),
      ('         ++renderFrame;if(phase=="done")return;\n','         ++renderFrame;if(phase=="done")return;\n         observeDropEnter();\n'),
      (old,'               {\n'+old+'\n                  observeDropArrival(received,int(lootArrivals[lootArrivals.length-1].received));\n               }'),
      ('         if(lastRender==renderFrame||phase=="done")return;lastRender=renderFrame;\n',
       '         observeDropRender();\n         if(lastRender==renderFrame||phase=="done")return;lastRender=renderFrame;\n'),
      ('         Log.d("COOP EFFECTS DONE continuity "+(host?"host":"join"));',
       '         exportDropObserver();\n         Log.d("COOP EFFECTS DONE continuity "+(host?"host":"join"));')]

def expected():
    source=BASE/'tests/PresentationContinuityTestDoc.as'
    assert sha(source)==PIN
    raw=source.read_bytes();newline='\r\n' if b'\r\n' in raw else '\n'
    before=raw.decode('utf-8');after=before
    edits=[(old.replace('\n',newline),new.replace('\n',newline)) for old,new in changes()]
    for old,new in edits:
        assert after.count(old)==1,old[:80]
        after=after.replace(old,new)
    restored=after
    for old,new in reversed(edits):
        assert restored.count(new)==1
        restored=restored.replace(new,old)
    assert restored.encode()==raw
    return before,after

def main():
    before,after=expected()
    tests=HERE/'tests';tests.mkdir(exist_ok=True)
    (tests/'PresentationContinuityTestDoc.as').write_bytes(after.encode())
    for name in ['MotionCadenceRegression.as','DropMotionBurstRegression.as']:
        (tests/name).write_bytes((BASE/'tests'/name).read_bytes())
    (HERE/'observer.patch').write_bytes(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
        fromfile='motion2/PresentationContinuityTestDoc.as',tofile='drop-observer/PresentationContinuityTestDoc.as')).encode())
    source_meta=json.loads((BASE/'prepared.json').read_text('utf-8-sig'))
    receipt=json.loads((ROOT/'experimental/recovery-pause-native-driver/inputs.json').read_text('utf-8-sig'))
    external={k.replace('pause-timing/','continuity/'):v for k,v in receipt['external'].items()}
    originals={str(BASE/'prepared.json'):sha(BASE/'prepared.json')}
    for f in tests.glob('*.as'):
        origin=BASE/'tests'/f.name;originals[str(origin)]=sha(origin)
        assert originals[str(origin)]==source_meta['files']['tests/'+f.name]
    selected=[ROOT/'tools/validation/runtime_memory.py',ROOT.parent/'ModLoader/tools/test_registry.py',
        ROOT/'experimental/recovery-formal-policy-control/run_motion_comparison.py',
        ROOT/'experimental/recovery-formal-policy-control/policy_evidence.py',
        ROOT/'tools/run_coop_regression.py']
    originals.update({str(p):sha(p) for p in selected})
    originals.update({v:receipt['originals'][v] for v in external.values()})
    for n,h in receipt['originals'].items():
        if Path(n).name in ['java.exe','mxmlc.jar','air-config.xml','airglobal.swc']:originals[n]=h
    save(HERE/'inputs.json',{'kind':'recovery-drop-render-observer','base':str(BASE),'source_sha256':PIN,
        'base_manifest_sha256':sha(BASE/'prepared.json'),'tests':{'tests/'+p.name:sha(p) for p in tests.glob('*.as')},
        'external':external,'toolchain':receipt['toolchain'],'originals':originals,
        'binary_hash_source':'Existing compiled receipts; actual binary bytes rechecked by prepare before build.',
        'local':{p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='inputs.json'},
        'original_source_restored_by_removing_exact_insertions':True,'compiled':False,'air_started':False,
        'diagnostic_only':True,'performance_qualified':False})
    print(json.dumps({'as_files':3,'source_restored':True,'compiled':False,'air_started':False}))
if __name__=='__main__':main()
