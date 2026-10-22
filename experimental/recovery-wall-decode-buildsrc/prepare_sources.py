"""Reuse source-freezing helpers: exact recovery20 plus two tested decode classes.
Only AS/text preparation. Formal compiler remains tools/validation/prepare_recovery.py.
"""
from pathlib import Path
import difflib,importlib.util,json,shutil,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
HELPER=ROOT/'experimental/recovery-wall-encode-buildsrc/prepare_sources.py'
spec=importlib.util.spec_from_file_location('reviewed_source_freeze',HELPER)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
sha,read,save,inventory=shared.sha,shared.read,shared.save,shared.inventory
BASE=ROOT/'build/m52/recovery-20';OVERLAY=ROOT/'experimental/recovery-wall-decode-fast'
COMPONENT=ROOT/'build/m52/recovery-wall-decode-fast-component-01'
BASE_SHA='0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5'
OVERLAY_HANDOFF='609956e7c78bf045be74245cf5bdd2369a55c40929d734c9b3c991468cebb937'
COMPONENT_SHA='c57507991c9d0258735b9df62bc101ed98445c408856f51ca881b9cc7be7909a'
FILES=['rconnect/net/WallCellCodec.as','rconnect/game/WallImpactVisuals.as']
VERSION='0.2.24-recovery21'
def verify():
 integrated=read(HERE/'integration.json');actual=inventory(HERE/'src')
 assert actual=={r['path']:r['sha256'] for r in integrated['source']}
 for path,digest in integrated['input_sources'].items():assert sha(Path(path))==digest,path
 base=read(BASE/'prepared.json')['source'];assert len(base)==len(actual)==90
 changed={p for p in set(base)|set(actual) if base.get(p)!=actual.get(p)}
 assert changed==set(FILES+['RConnectMod.as']),changed
 for name in FILES:assert sha(HERE/'src'/name)==sha(OVERLAY/'src'/name)
 before=(BASE/'src/RConnectMod.as').read_bytes();after=(HERE/'src/RConnectMod.as').read_bytes()
 assert before.count(b'0.2.24-recovery20')==1
 assert after==before.replace(b'0.2.24-recovery20',VERSION.encode('ascii'))
 assert (HERE/'ancestor-integration.json').read_bytes()==(BASE/'integration.json').read_bytes()
 for path,digest in integrated['patches'].items():assert sha(HERE/path)==digest,path
 assert not integrated['static_errors'] and integrated['version']==VERSION
 wall=(HERE/'src'/FILES[1]).read_text(encoding='utf-8-sig')
 assert 'b.setPixel32(x,y,color);' in wall and 'b.setPixel32(x,y,uint(c.values[key]));' in wall
 assert 'b.setPixel32(x,y,NativeWallColor.setter(color));' not in wall
 return dict(passed=True,base_files=90,output_files=90,unchanged_base_files=87,changed=sorted(changed),
  class_overlays_byte_exact=True,version_only_entry_change=True,small_room_setters_included=False,
  component_assertions=67,component_failed=0,JVMStarted=False,AIRStarted=False,compiled=False,
  native_game_tested=False,performance_qualified=False)
def main():
 assert not (HERE/'src').exists(),'Complete snapshot exists; use --verify, do not overwrite'
 assert sha(BASE/'RConnectMod.swf')==BASE_SHA
 assert sha(OVERLAY/'handoff.json')==OVERLAY_HANDOFF
 for path,digest in read(OVERLAY/'handoff.json')['files'].items():assert sha(OVERLAY/path)==digest,path
 overlay_spec=importlib.util.spec_from_file_location('tested_decode_overlay',OVERLAY/'prepare.py')
 overlay=importlib.util.module_from_spec(overlay_spec);overlay_spec.loader.exec_module(overlay);overlay.verify()
 base=read(BASE/'prepared.json');assert base['version']=='0.2.24-recovery20'
 assert inventory(BASE/'src')==base['source'] and len(base['source'])==90
 assert sha(BASE/'integration.json')==base['integration_sha256']
 receipt=read(COMPONENT/'receipt.json');raw=read(COMPONENT/'component-result.json');intent=read(COMPONENT/'intent.json')
 assert receipt['passed'] is True and receipt['observed_checks']==67 and receipt['checks_failed']==0
 assert receipt['installation_unchanged'] and receipt['source_unchanged'] and receipt['exit_code']==0
 assert len(raw['assertions'])==67 and all(r['passed'] is True for r in raw['assertions'])
 assert raw['passed'] is True and raw['failed']==0 and raw['native_game_test'] is False
 assert sha(COMPONENT/'Checks.swf')==receipt['component_sha256']==COMPONENT_SHA
 assert intent['expected']==67
 assert inventory(OVERLAY/'components')==intent['sources']==inventory(COMPONENT/'src')
 inputs=[BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'integration.json',OVERLAY/'handoff.json',
  OVERLAY/'inputs.json',OVERLAY/'prepare.py',COMPONENT/'receipt.json',COMPONENT/'component-result.json',
  COMPONENT/'intent.json',COMPONENT/'Checks.swf',HELPER,Path(__file__),ROOT/'tools/validation/prepare_recovery.py']
 inputs.extend(BASE/'src'/name for name in base['source'])
 inputs.extend(COMPONENT/'src'/name for name in intent['sources'])
 inputs.extend(OVERLAY/'src'/name for name in FILES)
 pinned={str(p):sha(p) for p in inputs}
 shutil.copytree(BASE/'src',HERE/'src')
 for name in FILES:shutil.copyfile(OVERLAY/'src'/name,HERE/'src'/name)
 entry=HERE/'src/RConnectMod.as';data=entry.read_bytes();assert data.count(b'0.2.24-recovery20')==1
 entry.write_bytes(data.replace(b'0.2.24-recovery20',VERSION.encode('ascii')))
 shutil.copyfile(BASE/'integration.json',HERE/'ancestor-integration.json')
 for name,target in [(FILES[0],'codec-unpack.patch'),(FILES[1],'W1-validation.patch'),('RConnectMod.as','version.patch')]:
  diff=difflib.unified_diff((BASE/'src'/name).read_text(encoding='utf-8-sig').splitlines(True),
   (HERE/'src'/name).read_text(encoding='utf-8-sig').splitlines(True),fromfile='recovery20/src/'+name,tofile='recovery21/src/'+name)
  (HERE/target).write_text(''.join(diff),encoding='utf-8',newline='\n')
 rows=raw['measurements']['abba']['blocks'];assert len(rows)==24
 summary={}
 for pair in ('ascii_and_word_write','validated_W1_only','combined'):
  selected=[r for r in rows if r['pair']==pair]
  assert [r['side'] for r in selected]==['control','candidate','candidate','control']*2
  summary[pair]={side:[sum(c['ms'] for c in r['corpora']) for r in selected if r['side']==side] for side in ('control','candidate')}
 review=dict(directory=str(COMPONENT),assertions=67,failed=0,component_sha256=COMPONENT_SHA,
  receipt_sha256=sha(COMPONENT/'receipt.json'),result_sha256=sha(COMPONENT/'component-result.json'),
  original_inputs_sha256=sha(COMPONENT/'intent.json'),installation_unchanged=True,source_unchanged=True,
  full_production_classes_compared=True,abba_full_decode_ms=summary,native_game_test=False,performance_qualified=False,
  assertion_labels=[r['label'] for r in raw['assertions']])
 save(HERE/'component-review.json',review)
 sources=inventory(HERE/'src')
 integration=dict(version=VERSION,compiled=False,runtime_tested=False,diagnostic_only=False,
  baseline='build/m52/recovery-20',baseline_sha256=BASE_SHA,baseline_manifest_sha256=sha(BASE/'prepared.json'),
  ancestor_integration_sha256=sha(BASE/'integration.json'),ancestor_integration_copy='ancestor-integration.json',input_sources=pinned,
  layers=[dict(name='two-tested-wall-decode-subitems',source='experimental/recovery-wall-decode-fast/src',source_handoff_sha256=OVERLAY_HANDOFF,
   files=[dict(path=name,ancestor_sha256=base['source'][name],sha256=sources[name],merge='exact tested overlay bytes') for name in FILES])],
  version_change=dict(path='RConnectMod.as',old='0.2.24-recovery20',new=VERSION),
  patches={name:sha(HERE/name) for name in ('codec-unpack.patch','W1-validation.patch','version.patch')},
  component=review,source=[dict(path=name,sha256=digest) for name,digest in sources.items()],static_errors=[],
  unchanged_class_count=87,complete_class_count=90,small_room_setters_included=False,native_game_tested=False,performance_qualified=False,installed=False)
 save(HERE/'integration.json',integration);checks=verify();save(HERE/'static-checks.json',checks)
 print(json.dumps(checks,ensure_ascii=False));print('integration_sha256='+sha(HERE/'integration.json'))
if __name__=='__main__':
 if '--verify' in sys.argv:print(json.dumps(verify(),ensure_ascii=False))
 else:main()
