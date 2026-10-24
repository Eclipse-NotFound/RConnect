"""V2: reuse exact successful donor02 import/export; four new registered FFDec calls.

New source/retention wiring only. Shared registration/memory policy, ABC decoder,
exact raw-tag splicer and runtime remain the existing implementations.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, shutil, subprocess, sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
def load(name,p):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
source=load('current_first_raster_prepare',HERE/'prepare.py')
retain=load('current_first_raster_retention_v2',HERE/'retain_v2.py')
history=load('first_raster_donor02_original_builder',HERE/'build.py')
DONOR=ROOT/'build/m52/recovery-room-first-raster-host-current-02'
DONOR_BUILD_SHA='660871ac69348fb0f08b43629377f28a34e953452dfb9881775837d7a1991383'
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,FFDEC
sys.path.insert(0,str(ROOT/'tools/validation'))
from runtime_memory import snapshot,wait_owned
from run_security_terminals import installation
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
DEFAULT=ROOT/'build/m52/recovery-room-first-raster-host-current-03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def target(p):
 p=Path(p);p=(p if p.is_absolute() else ROOT/p).resolve()
 assert p.parent==ROOT/'build/m52' and p.name.startswith('recovery-room-first-raster-host-current-')
 return p
def donor():
 assert sha(DONOR/'build.json')==DONOR_BUILD_SHA
 p=history.frozen(DONOR);r=read(DONOR/'build.json')
 assert r['compiled'] is True and r['validated'] is False and r['build_checks_passed'] is False
 assert r['error_type']=='AssertionError' and r['error']=='Target requires unreviewed method/class/slot relocation'
 assert r['installation_unchanged'] and r['inputs_unchanged'] and not r['air_started'] and not r['installed']
 assert r['inputs']==p['inputs'] and r['prepared_sha256']==sha(DONOR/'prepared.json')
 assert r['installation_before']==r['installation_after']==p['installation_before']
 assert len(r['commands'])==2 and all(x['exit_code']==0 and x['reaped'] for x in r['commands'])
 assert all({k:x[k] for k in ('name','argv')}==v for x,v in zip(r['commands'],p['commands'][:2]))
 for name,h in r['artifacts'].items():assert sha(DONOR/name)==h,name
 assert r['artifacts']['donor.xml']=='7782b131496f38f47ef8ef5e702a504641b1c61603f08a72fdb352923ea9ac4f'
 assert r['artifacts']['donor.swf']=='75d7f5c553f32c356f1a39c168e54a8daf8a42f6726c62877538361004680ca6'
 return dict(path=str(DONOR),build_sha256=DONOR_BUILD_SHA,prepared_sha256=sha(DONOR/'prepared.json'),
  donor_xml_sha256=r['artifacts']['donor.xml'],donor_swf_sha256=r['artifacts']['donor.swf'],
  commands=r['commands'],original_result_passed=False,original_failure_preserved=True,source_imports=p['imports'])

def pins():
 meta=source.verify();result=dict(meta['inputs']);donor()
 manifest=read(HERE/'v2-manifest.json')
 for name,h in manifest['files'].items():assert sha(HERE/name)==h;result[str(HERE/name)]=h
 result[str(HERE/'v2-manifest.json')]=sha(HERE/'v2-manifest.json')
 old=read(DONOR/'build.json')
 for name,h in old['artifacts'].items():result[str(DONOR/name)]=h
 result[str(DONOR/'build.json')]=DONOR_BUILD_SHA
 for name in ('prepare.py','retain.py','build.py','source-manifest.json','README.md'):
  result[str(HERE/name)]=sha(HERE/name)
 for name,h in meta['files'].items():result[str(HERE/name)]=h
 for p in (JAVA,FFDEC,ROOT/'tools/host_authority/common.py',ROOT/'tools/validation/runtime_memory.py',
  ROOT/'tools/validation/run_security_terminals.py',GAME/'mods/ModLoader/tools/test_registry.py',retain.SUPPORT,retain.support.SUPPORT):result[str(p)]=sha(p)
 assert sha(retain.SUPPORT)=='c422c540490d553e6a21415b9cdb4232f287069b4b1f18a075e51d224a59268e'
 return result
def commands(out):
 names=','.join(source.CLASSES)
 rows=[('serialize',['-xml2swf',out/'retained.xml',out/'serialized.swf']),
  ('final-xml',['-swf2xml',out/'pfe.swf',out/'final.xml']),
  ('readback',['-selectclass',names,'-export','script',out/'readback',out/'pfe.swf']),
  ('pcode',['-format','script:pcode','-selectclass',names,'-export','script',out/'pcode',out/'pfe.swf'])]
 return [dict(name=n,argv=[str(JAVA),'-Dfile.encoding=UTF-8','-Duser.language=en','-Duser.country=US','-Xmx512m','-jar',str(FFDEC),*map(str,a)]) for n,a in rows]
def prepare(out):
 assert not out.exists(),'Preserve prior build evidence';inputs=pins();before=installation()
 assert len(before)==22 and before['pfe.swf']==source.HOST_SHA
 out.mkdir()
 for cls in source.CLASSES:
  rel=source.paths(cls);p=out/'import'/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((HERE/'import'/rel).read_bytes())
 meta=dict(kind='current-first-raster-host',base_sha256=source.HOST_SHA,base_xml_sha256=sha(source.BASE_XML),
  inputs=inputs,installation_before=before,imports={source.paths(c).as_posix():sha(out/'import'/source.paths(c)) for c in source.CLASSES},
  historical_donor=donor(),commands=commands(out),compiled=False,validated=False,air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False)
 save(out/'prepared.json',meta);return meta
def frozen(out):
 meta=read(out/'prepared.json');assert meta['inputs']==pins() and meta['historical_donor']==donor()
 assert meta['base_sha256']==source.HOST_SHA and meta['commands']==commands(out)
 assert meta['imports']=={source.paths(c).as_posix():sha(out/'import'/source.paths(c)) for c in source.CLASSES}
 assert len(list((out/'import').rglob('*.as')))==3
 return meta
def build(out,wait):
 meta=prepare(out) if not out.exists() else frozen(out)
 assert not(out/'build.json').exists(),'Do not rerun failed/final build'
 before=meta['installation_before'];assert installation()==before
 prepared_sha=sha(out/'prepared.json')
 result=dict(kind='current-first-raster-host-build',base_sha256=source.HOST_SHA,prepared_sha256=prepared_sha,
  compiled=True,validated=False,build_checks_passed=False,air_started=False,installed=False,historical_donor=donor(),
  gameplay_qualified=False,performance_qualified=False,installation_before=before,commands=[],inputs=meta['inputs'])
 failure=None
 try:
  with Registration(owner='RConnect / 当前宿主首绘桥',resource='game',purpose='A796 retained 3-class bridge; no AIR/install',run_dir=out,evidence=out/'prepared.json',wait=wait) as reg:
   assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before XML retainer'
   save(out/'retain.json',retain.retain(source.BASE_XML,DONOR/'donor.xml',out/'retained.xml'))
   for command in meta['commands']:
    assert frozen(out)==meta and installation()==before and sha(out/'prepared.json')==prepared_sha
    memory=snapshot();save(out/(command['name']+'-memory-before.json'),memory)
    assert memory['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
    row=dict(command,pid=None,exit_code=None,reaped=False);result['commands'].append(row);p=None
    with (out/(command['name']+'.log')).open('x',encoding='utf-8') as log:
     try:
      reg.before_launch('FFDec '+command['name'])
      p=subprocess.Popen(command['argv'],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
      row['pid']=p.pid;reg.child(p.pid);row['exit_code']=wait_owned(p,300,out/(command['name']+'-memory.json'))
     finally:
      if p is not None:
       if p.poll() is None:p.kill()
       p.wait();row['reaped']=p.poll() is not None
      reg.child_stopped()
    assert row['exit_code']==0 and row['reaped'],row
    log=(out/(command['name']+'.log')).read_text(encoding='utf-8',errors='replace')
    assert not any(x in log for x in ('SEVERE:','Unknown preprocessor instruction','Exception in thread','Export error')),command['name']
    if command['name']=='serialize':save(out/'splice.json',retain.splice(source.HOST,out/'serialized.swf',out/'pfe.swf'))
    if command['name']=='final-xml':save(out/'method-audit.json',retain.audit(source.BASE_XML,out/'final.xml',out/'retained.xml'))
   for cls in source.CLASSES:
    for base,suffix in [('readback','.as'),('pcode','.pcode')]:assert (out/base/'scripts'/source.paths(cls).with_suffix(suffix)).is_file()
   proof=read(out/'method-audit.json');assert proof['passed'] and proof['exact_retained_roundtrip']
   result.update(candidate_sha256=sha(out/'pfe.swf'),build_checks_passed=True,validated=True,
    validation_scope='Exact bytecode/member/resource preservation and explicit bridge bindings only; native testing remains',
    method_audit=proof,retain=read(out/'retain.json'),splice=read(out/'splice.json'),readback_path=str(out/'readback/scripts'),pcode_path=str(out/'pcode/scripts'))
   reg.outcome='passed';reg.note='Three-class source/retained bytecode audit passed; no AIR or gameplay/performance qualification'
 except BaseException as e:failure=e;result.update(error_type=type(e).__name__,error=str(e),validated=False,build_checks_passed=False)
 finally:
  try:
   result['installation_after']=installation();result['installation_unchanged']=result['installation_after']==before
   result['inputs_unchanged']=pins()==meta['inputs'] and sha(out/'prepared.json')==prepared_sha
   assert result['installation_unchanged'] and result['inputs_unchanged'],'Inputs or installation changed'
  except BaseException as e:failure=failure or e;result.update(validated=False,build_checks_passed=False,final_error=str(e))
  result['artifacts']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}
  save(out/'build.json',result)
 if failure:raise failure
 return verify(out)
def verify(output):
 """Read-only API. Historic build proof is distinct from native qualification."""
 out=target(output);meta=frozen(out);r=read(out/'build.json')
 assert r['base_sha256']==source.HOST_SHA and r['prepared_sha256']==sha(out/'prepared.json') and r['inputs']==meta['inputs']
 assert r['compiled'] and r['validated'] and r['build_checks_passed'] and r['inputs_unchanged'] and r['installation_unchanged']
 assert r['installation_before']==r['installation_after']==meta['installation_before']
 assert r['historical_donor']==meta['historical_donor']==donor()
 assert len(r['commands'])==4 and all(x['exit_code']==0 and x['reaped'] for x in r['commands'])
 assert all({k:x[k] for k in ('name','argv')}==expected for x,expected in zip(r['commands'],meta['commands']))
 for p,h in r['artifacts'].items():assert sha(out/p)==h,p
 assert r['candidate_sha256']==sha(out/'pfe.swf')
 assert r['method_audit']==read(out/'method-audit.json') and r['retain']==read(out/'retain.json') and r['splice']==read(out/'splice.json')
 assert r['method_audit']['passed'] and r['method_audit']['exact_retained_roundtrip'] and r['retain']['passed'] and r['splice']['rawResourcesPreserved']
 assert r['retain']['retained_xml_sha256']==sha(out/'retained.xml') and r['retain']['donor_xml_sha256']==sha(DONOR/'donor.xml')
 assert not any(r[k] for k in ('air_started','installed','gameplay_qualified','performance_qualified'))
 return r
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=DEFAULT);g=ap.add_mutually_exclusive_group(required=True)
 for n in ('check','prepare','build','verify'):g.add_argument('--'+n,action='store_true')
 ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args();out=target(a.output)
 if a.check:value=dict(passed=True,input_count=len(pins()),java_started=False)
 elif a.prepare:value=prepare(out)
 elif a.build:value=build(out,a.registry_wait)
 else:value=verify(out)
 print(json.dumps({k:v for k,v in value.items() if k in ('passed','input_count','java_started','base_sha256','candidate_sha256','compiled','validated','build_checks_passed')},ensure_ascii=False))
if __name__=='__main__':main()
