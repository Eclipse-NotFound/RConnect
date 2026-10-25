"""Only the 908D passive probe's expected UI version changes; text preparation."""
from pathlib import Path
import difflib,hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.parent/'goal-rconnect-only-loading';BASE=ROOT/'build/m52/goal-rconnect-only-loading-driver-01'
PINS={OLD/'prepare.py':'f837761c441b28acf7a62b1459476fe96af5f9cc177a176f4dde8430025f7870',
      OLD/'build.py':'09edaf5a150364157a92129f57850283df1040cb6efebc1c906cebeae79c3755',
      OLD/'source-manifest.json':'2b836f0061114bfa73897c7fa1a899afc83d0360964c7ed6cd404727aad7a304',
      BASE/'prepared.json':'bf010c1c72d8f298d6fde9ac8020280c22ba52c91064e2ff77707ec316e9ee48',
      BASE/'compile.json':'43585b0e7aa9f3970cde0f70cee518a1689563f4346af9a5755458953d01d6e4',
      BASE/'timing/EffectsDriver.swf':'908df50519b96ff1299335bfa4a1da89a6efc193e0c214292eb77314714ee01c'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
    s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def expected():
    for p,h in PINS.items():assert sha(p)==h,str(p)
    source=load(OLD/'prepare.py','nativeui2_loading_parent_source').verify()
    proof=load(OLD/'build.py','nativeui2_loading_parent_build').verify(BASE)
    texts={n:(BASE/'tests'/n).read_text('utf8') for n in source['sources']}
    for n,h in source['sources'].items():assert sha(BASE/'tests'/n)==h
    old='expectedUi=productVersion=="0.2.24-nativeui1";strictUi=expectedUi&&!solo;'
    assert texts['NativeLoadingProbe.as'].count(old)==1
    texts['NativeLoadingProbe.as']=texts['NativeLoadingProbe.as'].replace(old,old.replace('nativeui1','nativeui2'),1)
    diff=''.join(''.join(difflib.unified_diff((BASE/'tests'/n).read_text('utf8').splitlines(True),v.splitlines(True),
        fromfile='compiled908D/tests/'+n,tofile='nativeui2/tests/'+n)) for n,v in texts.items())
    pins={str(p):h for p,h in PINS.items()}|proof['inputs']
    for n in ('prepared.json','compile.json','timing/EffectsDriver.swf','timing/EffectsHarness.swf'):
        pins[str(BASE/n)]=sha(BASE/n)
    manifest=dict(kind='native-ui-jump-loading-source-v1',source_count=3,prepare_sha256=sha(__file__),
        sources={n:hashlib.sha256(v.encode('utf8')).hexdigest() for n,v in texts.items()},
        original_sources=source['original_sources'],derived_sources=source['sources'],derived_driver_inputs=pins,
        derived_driver_sha256=PINS[BASE/'timing/EffectsDriver.swf'],
        source_diff_sha256=hashlib.sha256(diff.encode('utf8')).hexdigest(),
        runtime_environment=source['runtime_environment'],expected_version='0.2.24-nativeui2',
        travelChecksDual={'host':23,'join':12},travelChecksSolo={'host':11},uiChecksDualCandidate=11,
        observationChecksSolo=8,compiled=False,air_started=False)
    return texts,diff,manifest
def verify():
    texts,diff,m=expected();assert read(HERE/'source-manifest.json')==m
    assert (HERE/'source.diff').read_text('utf8')==diff
    assert {p.name:sha(p) for p in (HERE/'tests').iterdir() if p.is_file()}==m['sources']
    for n,v in texts.items():assert (HERE/'tests'/n).read_text('utf8')==v
    for n in ('RoomTravelTimingTestDoc.as','A22RoomMetrics.as'):
        assert (HERE/'tests'/n).read_bytes()==(BASE/'tests'/n).read_bytes()
    return m
def main():
    assert sys.argv[1:] in (['--prepare'],['--check'])
    if sys.argv[1:]==['--prepare']:
        texts,diff,m=expected();(HERE/'tests').mkdir(exist_ok=True)
        for n,v in texts.items():
            with (HERE/'tests'/n).open('x',encoding='utf8',newline='\n') as f:f.write(v)
        with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
        with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,ensure_ascii=False,indent=2);f.write('\n')
    verify();print('nativeui2 loading source verified; one expected-version edit; no Java/AIR')
if __name__=='__main__':main()
