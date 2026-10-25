"""DIAGNOSTIC_ONLY product binding over the unchanged nativeui2 onlyRC loading run."""
from pathlib import Path
import hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.with_name('goal-native-ui-jump-loading')/'run.py'
PRODUCT=ROOT/'build/m52/goal-terrain-reuse-diagnostic-product-01'
COMPILED={'prepared.json':'7e3c721db247cbfd7ac92cf96ffb990bce8e6be9b26ff8a8a94db230b857816e',
 'compile.json':'b6f2cc7bb2135a60c933527480a65baf0c36b3c51ffdbdd800ee0c95575e493d',
 'RConnectMod.swf':'677644650c93ec7a5cd481e3ff5245acef6bb807d15c2c90b15df4c7da2c13cb'}
PINS={OLD:'2e74195a952852eed6d1008cfb21aa837f8fcbb8d7e4ff863d90a03d8f42d73e',
 HERE/'prepare.py':'ce3921fedc65fd10a14631c836ed059b9725741d00c4357cd7f8c10794e940ac',
 HERE/'build.py':'387e01710a6c5e249c0bc5377b2ab1460be42eb324bb65f16a295f2e2a53b4bf',
 HERE/'source-manifest.json':'232c667b68ac890cbd12b021e92cffa9333d44b714b894d6c0830eaec68a14ff'}
PREFIX='RConnectTerrainReuse DIAGNOSTIC_ONLY '
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
 s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
for path,digest in PINS.items():assert sha(path)==digest,str(path)
parent=load(OLD,'terrain_diagnostic_nativeui2_parent')
builder=load(HERE/'build.py','terrain_diagnostic_actual_build')
source=load(HERE/'prepare.py','terrain_diagnostic_actual_source')
original_source=parent.source_check;original_bundle=parent.candidate_bundle;original_validate=parent.validate_only_rc
def source_check():
 for path,digest in PINS.items():assert sha(path)==digest,str(path)
 pins=original_source();manifest=source.verify()
 pins.update({str(path):digest for path,digest in PINS.items()})
 pins.update(manifest['inputs'])
 pins.update({str(HERE/name):digest for name,digest in manifest['files'].items()})
 pins[str(Path(__file__).resolve())]=sha(__file__)
 return pins
def candidate_bundle():
 # Retain actual 5325/1640/2DB0 evidence; do not pretend it is this diagnostic SWF.
 original=original_bundle();pins=source_check()
 for name,digest in COMPILED.items():
  path=PRODUCT/name
  if not path.is_file():raise parent.parent.builder.base.NotReady('Actual diagnostic compile evidence missing: '+str(path))
  assert sha(path)==digest,name;pins[str(path)]=digest
 compiled=builder.verify(PRODUCT);meta=read(PRODUCT/'prepared.json')
 assert meta['installation_before']==compiled['installation_before']==compiled['installation_after']==original['installation']
 assert meta['version']=='0.2.24-nativeui2' and meta['base_sha256']==parent.PRODUCT_SHA
 assert compiled['candidate_sha256']==COMPILED['RConnectMod.swf']!=parent.PRODUCT_SHA
 pins.update(original['pins'])
 for directory,table in ((PRODUCT/'src',meta['source']),(PRODUCT/'tools',meta['inputs'])):
  pins.update({str(directory/name):digest for name,digest in table.items()})
 return dict(original,meta=meta,compile=compiled,pins=pins,product=PRODUCT,
  diagnostic_only=True,performance_qualified=False,source_product_sha256=parent.PRODUCT_SHA)
def validate_only_rc(out,run,roles,settings,result):
 original_validate(out,run,roles,settings,result)
 evidence={};valid=True
 for role in roles:
  text=(run/(role+'.log')).read_text('utf-8-sig')
  rows=[json.loads(line.split(PREFIX,1)[1]) for line in text.splitlines() if PREFIX in line]
  for row in rows:
   assert row['schema']=='terrain-reuse-first-rejection-v1' and row['DIAGNOSTIC_ONLY'] is True
   assert row['appId']=='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
   assert row['complete'] is True and row['performanceQualified'] is False
   assert row['faultCount']==0 and row['faults']==[]
   assert type(row['reuseGuardDirty']) is bool
   if row['first'] is not None:
    first=row['first'];assert all(k in first for k in ('stage','field','expected','actual','x','y','index'))
   elif row['reuseGuardDirty'] is True:
    assert row['viewCreated'] is True and row['constructorValid'] is True and row['unchangedCalled'] is True and row['reused'] is True
  evidence[role]=dict(log_sha256=sha(run/(role+'.log')),count=len(rows),rows=rows)
  if role=='join' and not rows:valid=False
 record=out/'terrain-reuse-diagnostic.json'
 with record.open('x',encoding='utf8') as stream:
  json.dump(dict(diagnostic_only=True,performance_qualified=False,roles=evidence),stream,ensure_ascii=False,indent=2)
 result.update(diagnostic_only=True,performance_qualified=False,qualified_for_deployment=False,
  diagnostic_samples_ready=valid,diagnostic_sha256=sha(record),diagnostic_product_sha256=COMPILED['RConnectMod.swf'])
 assert valid,'No completed joining-side terrain diagnostic evidence'
def main():
 assert '--prepare-source' not in sys.argv,'Frozen parents must not be rewritten'
 parent.source_check=source_check;parent.candidate_bundle=candidate_bundle;parent.validate_only_rc=validate_only_rc
 return parent.main()
if __name__=='__main__':raise SystemExit(main())
