"""Prepare diagnostic source only. No JVM, AIR, production changes or deployment."""
from pathlib import Path
import difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-room-current-driver-01'
ORIGINAL={
 'RoomTravelTimingTestDoc.as':'226001bfb880363615c98d697ef0b1ea224545f749123b14987160f91e0998e3',
 'A22RoomMetrics.as':'314823fd0fcd04e71277dcd3e8ee1a647317e611c5ff7b8fb0e7058c25179d6e'}
HOOKS=(
 ('      private var metrics:A22RoomMetrics;',
  '      private var metrics:A22RoomMetrics;\n      private var loadingProbe:NativeLoadingProbe;'),
 ('         if(metrics==null)metrics=new A22RoomMetrics(mod);',
  '         if(metrics==null)metrics=new A22RoomMetrics(mod);\n         if(loadingProbe==null)loadingProbe=new NativeLoadingProbe(mod);'),
 ('         Log.d("TRAVEL CLOCK "+JSON.stringify({started:at,round:round,target:target}));',
  '         Log.d("TRAVEL CLOCK "+JSON.stringify({started:at,round:round,target:target}));\n         if(loadingProbe!=null)loadingProbe.begin(round,target,at);'),
 ('               reported=true;localResult=result();Log.d("TRAVEL RESULT "+JSON.stringify(localResult));',
  '               reported=true;localResult=result();Log.d("TRAVEL RESULT "+JSON.stringify(localResult));\n               if(loadingProbe!=null)loadingProbe.completed(round,int(localResult.at));'),
 ('         Log.d("COOP EFFECTS DONE travel-timing "+(host?"host":"join"));',
  '         if(loadingProbe!=null)loadingProbe.finish();\n         Log.d("COOP EFFECTS DONE travel-timing "+(host?"host":"join"));'))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text('utf-8-sig'))
def sources():
    for name,digest in ORIGINAL.items(): assert sha(BASE/'tests'/name)==digest,name
    text=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf8')
    for old,new in HOOKS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    reversed_text=text
    for old,new in reversed(HOOKS):
        assert reversed_text.count(new)==1,new
        reversed_text=reversed_text.replace(new,old,1)
    assert reversed_text==(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf8')
    return {'RoomTravelTimingTestDoc.as':text,'A22RoomMetrics.as':(BASE/'tests/A22RoomMetrics.as').read_text('utf8')}
def diff_text():
    result=''
    for name,text in sources().items():
        old=(BASE/'tests'/name).read_text('utf8')
        result+=''.join(difflib.unified_diff(old.splitlines(True),text.splitlines(True),
          fromfile='current-driver-01/tests/'+name,tofile='loading-observer/tests/'+name))
    observer=(HERE/'tests/NativeLoadingProbe.as').read_text('utf8')
    return result+''.join(difflib.unified_diff([],observer.splitlines(True),
      fromfile='/dev/null',tofile='loading-observer/tests/NativeLoadingProbe.as'))
def check():
    for name,text in sources().items(): assert (HERE/'tests'/name).read_text('utf8')==text,name
    assert (HERE/'tests/A22RoomMetrics.as').read_bytes()==(BASE/'tests/A22RoomMetrics.as').read_bytes()
    m=read(HERE/'source-manifest.json')
    assert m['kind']=='native-loading-observer-v1'
    assert m['sources']=={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))}
    assert m['prepare_sha256']==sha(__file__) and m['diff_sha256']==sha(HERE/'source.diff')
    assert (HERE/'source.diff').read_text('utf8')==diff_text()
    assert m['original']=={str(BASE/'tests'/n):h for n,h in ORIGINAL.items()}
    assert m['original_driver_prepared_sha256']==sha(BASE/'prepared.json')=='34364016738c79140b8354769e7e0c1d1980b31368d4e50e7c20e45fa2ba075e'
    assert m['hook_count']==len(HOOKS)==5
    return m
def main():
    if sys.argv[1:]==['--check']:
        check();print('Source-only check passed; no JVM/AIR');return
    assert sys.argv[1:]==[]
    for name,text in sources().items():
        with (HERE/'tests'/name).open('x',encoding='utf8',newline='\n') as f:f.write(text)
    diff=diff_text()
    with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
    m=dict(kind='native-loading-observer-v1',prepare_sha256=sha(__file__),diff_sha256=sha(HERE/'source.diff'),
      original={str(BASE/'tests'/n):h for n,h in ORIGINAL.items()},
      original_driver_prepared_sha256=sha(BASE/'prepared.json'),
      sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))},
      hook_count=len(HOOKS),original_assertions_preserved=True,original_done_preserved=True,
      compiled=False,air_started=False,performanceQualified=False)
    with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,indent=2);f.write('\n')
    check()
if __name__=='__main__':main()
