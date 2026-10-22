"""Reuse the existing 85-check preparer, bound to this isolated output directory.
Exact recovery21 plus only the two final ordinary-wall setters. No JVM/AIR.
"""
from pathlib import Path
import difflib,hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-21'
OLD=ROOT/'experimental/recovery-wall-small-color/components'
ACTUAL=ROOT/'build/m52/recovery-wall-small-color-component-01'
HELPER=ROOT/'experimental/recovery-wall-decode-fast/prepare_color_components.py'
PIN='9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba'
OLD_COMPONENT='ff968f6112981832baf16fe84d6e3bdb03528348406a8f0d10373b2f3beb583b'
WALL='rconnect/game/WallImpactVisuals.as'
NAMES=(WALL,'rconnect/net/WallCellCodec.as','rconnect/net/RoomCodec.as','rconnect/game/WallSurfaceBridge.as','rconnect/game/NativeWallColor.as')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,value):Path(p).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {x.relative_to(p).as_posix():sha(x) for x in sorted(p.rglob('*')) if x.is_file()}
def patched(data):
 for before,after in [(b'b.setPixel32(x,y,color);',b'b.setPixel32(x,y,NativeWallColor.setter(color));'),
  (b'b.setPixel32(x,y,uint(c.values[key]));',b'b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));')]:
  assert data.count(before)==1 and after not in data
  data=data.replace(before,after,1)
 return data
def verify():
 m=read(HERE/'inputs.json')
 for p,h in m['inputs'].items():assert sha(p)==h,p
 assert inventory(HERE/'components')==m['components']
 assert inventory(HERE/'src')==m['overlay'] and set(m['overlay'])=={WALL}
 before=(BASE/'src'/WALL).read_bytes();after=patched(before)
 assert (HERE/'src'/WALL).read_bytes()==after==(HERE/'components'/WALL).read_bytes()
 for name in NAMES[1:]:assert (HERE/'components'/name).read_bytes()==(BASE/'src'/name).read_bytes(),name
 for name in m['components']:
  if name not in NAMES:assert (HERE/'components'/name).read_bytes()==(OLD/name).read_bytes(),name
 assert b'if(!binary)for(var i:int=0;i<words.length;i+=2)' in after
 assert sha(HERE/'components/WallSurfaceChecks.as')==sha(ACTUAL/'src/WallSurfaceChecks.as')
 assert inventory(BASE/'src')==read(BASE/'prepared.json')['source']
 return dict(passed=True,baseline_version='0.2.24-recovery21',overlay_files=1,exact_final_setter_changes=2,
  unchanged_test_assertions=85,decode_optimizations_preserved=True,dependency_classes_byte_exact=True,
  complete_candidate_created=False,compiled=False,air_started=False,performance_qualified=False)
def main():
 assert not (HERE/'components').exists() and not (HERE/'src').exists(),'Use --verify for an existing snapshot'
 meta=read(BASE/'prepared.json');assert meta['compiled'] and meta['sha256']==PIN==sha(BASE/'RConnectMod.swf')
 assert meta['version']=='0.2.24-recovery21' and inventory(BASE/'src')==meta['source'] and len(meta['source'])==90
 r=read(ACTUAL/'receipt.json');raw=read(ACTUAL/'component-result.json');intent=read(ACTUAL/'intent.json')
 assert r['passed'] and r['observed_checks']==85 and r['checks_failed']==0 and r['exit_code']==0
 assert r['installation_unchanged'] and r['source_unchanged']
 assert raw['passed'] and raw['failed']==0 and len(raw['assertions'])==85 and all(a['passed'] is True for a in raw['assertions'])
 assert sha(ACTUAL/'Checks.swf')==OLD_COMPONENT==r['component_sha256']
 assert inventory(OLD)==intent['sources']==inventory(ACTUAL/'src') and intent['expected']==85
 inputs=[Path(__file__),HELPER,HELPER.parent/'prepare.py',HELPER.parent/'inputs.json',BASE/'prepared.json',BASE/'RConnectMod.swf',
  ACTUAL/'receipt.json',ACTUAL/'component-result.json',ACTUAL/'intent.json',ACTUAL/'Checks.swf',ROOT/'tools/validation/run_recovery_component.py']
 inputs.extend(BASE/'src'/name for name in NAMES)
 inputs.extend(OLD/name for name in intent['sources']);inputs.extend(ACTUAL/'src'/name for name in intent['sources'])
 pinned={str(p):sha(p) for p in inputs}
 # The reviewed helper is reused verbatim; its output containment check is
 # explicitly rebound to this task's permitted, fresh experimental directory.
 sys.path.insert(0,str(HELPER.parent))
 spec=importlib.util.spec_from_file_location('existing_small_color_preparer',HELPER)
 helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper);helper.HERE=HERE
 previous=sys.argv
 try:
  sys.argv=[str(HELPER),'--source',str(BASE/'src'),'--output',str(HERE/'components')];helper.main()
 finally:sys.argv=previous
 # Preserve accurate21 bytes, including line endings, for all dependencies.
 for name in NAMES:
  data=(BASE/'src'/name).read_bytes()
  (HERE/'components'/name).write_bytes(patched(data) if name==WALL else data)
 before=(BASE/'src'/WALL).read_bytes();after=patched(before)
 target=HERE/'src'/WALL;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(after)
 helper_manifest=read(HERE/'components-inputs.json');helper_manifest['files']=inventory(HERE/'components')
 helper_manifest['accurate21_bytes_preserved']=True;save(HERE/'components-inputs.json',helper_manifest)
 (HERE/'two-setters.patch').write_text(''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),
  fromfile='accurate21/'+WALL,tofile='accurate21-plus-two-setters/'+WALL)),encoding='utf-8')
 save(HERE/'inputs.json',dict(baseline_sha256=PIN,inputs=pinned,components=inventory(HERE/'components'),overlay=inventory(HERE/'src'),
  original_component_sha256=OLD_COMPONENT,original_actual_checks=85,expected_checks=85,compiled=False,air_started=False,
  performance_qualified=False,complete_candidate_created=False))
 result=verify();save(HERE/'static-checks.json',result);print(json.dumps(result))
if __name__=='__main__':
 if '--verify' in sys.argv:print(json.dumps(verify()))
 else:main()
