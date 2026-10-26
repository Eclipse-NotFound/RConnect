"""Isolated native020 build recipe. Only --build launches registered FFDec JVMs.

--check is read-only. --prepare freezes the three donor files in a new B build
directory. No AIR, installed SWF, release directory or other mod is written.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, shutil, subprocess, sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
sys.path.insert(0,str(HERE))
import native_retain as retain
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from common import JAVA,FFDEC
sys.path.insert(0,str(ROOT/'tools/validation'))
from runtime_memory import snapshot,wait_owned
from run_security_terminals import installation
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
BASE=retain.BASE;BASE_SHA=retain.BASE_SHA;CLASSES=retain.CLASSES
DEFAULT=ROOT/'build/ab/native-hooks-020'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):
 with Path(p).open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def target(p):
 p=Path(p);p=(p if p.is_absolute() else ROOT/p).resolve()
 assert p.parent==ROOT/'build/ab' and p.name.startswith('native-hooks-') and p!=BASE.parent
 return p
def rel(cls):return Path(*cls.split('.')).with_suffix('.as')
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}
def pins():
 assert sha(BASE)==BASE_SHA,'Exact native019 is required'
 manifest=read(HERE/'source-manifest.json')
 assert set(manifest['native'])=={rel(c).as_posix() for c in CLASSES}
 result={str(BASE):BASE_SHA}
 for name,row in manifest['native'].items():
  original=BASE.parent/'verified/scripts'/name;donor=HERE/'native-source'/name
  assert sha(original)==row['baseline'] and sha(donor)==row['overlay'],name
  result[str(original)]=row['baseline'];result[str(donor)]=row['overlay']
 for p in (HERE/'source-manifest.json',HERE/'native_build.py',HERE/'native_retain.py',HERE/'prepare_overlay.py',
           retain.SUPPORT,retain.support.SUPPORT,ROOT/'experimental/recovery-ordinary-method-transplant/method_transplant.py',
           ROOT/'experimental/recovery-room-first-raster-host-current/prepare.py',
           ROOT/'experimental/recovery-room-first-raster-host-current/activation_slots.py',
           JAVA,FFDEC,ROOT/'tools/host_authority/common.py',ROOT/'tools/validation/runtime_memory.py',
           ROOT/'tools/validation/run_security_terminals.py',GAME/'mods/ModLoader/tools/test_registry.py'):
  result[str(p)]=sha(p)
 return result
def commands(out):
 rows=[('base-xml',['-swf2xml',BASE,out/'base.xml']),
       ('import',['-importScript',BASE,out/'donor.swf',out/'import']),
       ('donor-xml',['-swf2xml',out/'donor.swf',out/'donor.xml']),
       ('serialize',['-xml2swf',out/'retained.xml',out/'serialized.swf']),
       ('final-xml',['-swf2xml',out/'pfe.swf',out/'final.xml']),
       ('readback',['-selectclass',','.join(CLASSES),'-export','script',out/'verified',out/'pfe.swf'])]
 return [dict(name=n,argv=[str(JAVA),'-Dfile.encoding=UTF-8','-Duser.language=en','-Duser.country=US',
                          '-Xmx768m','-jar',str(FFDEC),*map(str,args)]) for n,args in rows]
def prepare(out):
 assert not out.exists(),'Use a fresh native-hooks directory; retain prior evidence'
 inputs=pins();before=installation();out.mkdir()
 for cls in CLASSES:
  path=out/'import'/rel(cls);path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes((HERE/'native-source'/rel(cls)).read_bytes())
 meta=dict(kind='b-security-native-retained',baseline=str(BASE),base_sha256=BASE_SHA,inputs=inputs,
           imports=inventory(out/'import'),installation_before=before,commands=commands(out),java_started=False,air_started=False,installed=False)
 save(out/'prepared.json',meta);return meta
def frozen(out):
 meta=read(out/'prepared.json');assert meta['base_sha256']==BASE_SHA and meta['inputs']==pins()
 assert meta['imports']==inventory(out/'import') and len(meta['imports'])==3
 assert meta['commands']==commands(out);return meta
def build(out,wait):
 meta=prepare(out) if not out.exists() else frozen(out)
 assert not(out/'build.json').exists(),'Do not reuse a completed/failed build directory'
 before=meta['installation_before'];assert installation()==before
 assert shutil.disk_usage(out).free>=1024**3,'Less than 1 GiB of free disk before XML build'
 prepared_sha=sha(out/'prepared.json');failure=None
 result=dict(kind='b-security-native-retained-build',base_sha256=BASE_SHA,prepared_sha256=prepared_sha,inputs=meta['inputs'],
             compiled=False,build_checks_passed=False,air_started=False,installed=False,runtime_validated=False,commands=[],installation_before=before)
 try:
  with Registration(owner='RConnect B / 安保终端原生接口',resource='game',purpose='native019 retained security helpers/prefixes; no AIR or installation',
                    run_dir=out,evidence=out/'prepared.json',wait=wait) as reg:
   for command in meta['commands']:
    assert frozen(out)==meta and sha(out/'prepared.json')==prepared_sha and installation()==before
    memory=snapshot();save(out/(command['name']+'-memory-before.json'),memory)
    assert memory['free_commit_bytes']>=1024**3,'Less than 1 GiB of commit headroom'
    row=dict(command,pid=None,exit_code=None,reaped=False);result['commands'].append(row);process=None
    with (out/(command['name']+'.log')).open('x',encoding='utf-8') as log:
     try:
      reg.before_launch('FFDec '+command['name'])
      process=subprocess.Popen(command['argv'],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
      row['pid']=process.pid;reg.child(process.pid);row['exit_code']=wait_owned(process,480,out/(command['name']+'-memory.json'))
     finally:
      if process is not None:
       if process.poll() is None:process.kill()
       process.wait();row['reaped']=process.poll() is not None
      reg.child_stopped()
    assert row['exit_code']==0 and row['reaped'],row
    log=(out/(command['name']+'.log')).read_text(encoding='utf-8',errors='replace')
    assert not any(s in log for s in ('SEVERE:','Unknown preprocessor instruction','Exception in thread','Export error')),command['name']
    if command['name']=='base-xml':result['base_xml_sha256']=sha(out/'base.xml')
    if command['name']=='import':result['compiled']=True
    if command['name']=='donor-xml':save(out/'retain.json',retain.retain(out/'base.xml',out/'donor.xml',out/'retained.xml'))
    if command['name']=='serialize':save(out/'splice.json',retain.splice(BASE,out/'serialized.swf',out/'pfe.swf'))
    if command['name']=='final-xml':save(out/'method-audit.json',retain.audit(out/'base.xml',out/'final.xml',out/'retained.xml'))
   for cls in CLASSES:assert (out/'verified/scripts'/rel(cls)).is_file()
   proof=read(out/'method-audit.json');assert proof['passed'] and proof['exact_retained_roundtrip']
   result.update(candidate_sha256=sha(out/'pfe.swf'),build_checks_passed=True,method_audit=proof,
                 retain=read(out/'retain.json'),splice=read(out/'splice.json'),
                 qualification='Exact retained bytecode/resources and helper interfaces only; native game testing still required')
   reg.outcome='passed';reg.note='Native019 methods/resources preserved; B security hooks built; no AIR/runtime qualification'
 except BaseException as e:failure=e;result.update(error_type=type(e).__name__,error=str(e),build_checks_passed=False)
 finally:
  try:
   result['installation_after']=installation();result['installation_unchanged']=result['installation_after']==before
   result['inputs_unchanged']=pins()==meta['inputs'] and sha(out/'prepared.json')==prepared_sha
   assert result['installation_unchanged'] and result['inputs_unchanged'],'Installation or pinned inputs changed'
  except BaseException as e:failure=failure or e;result.update(build_checks_passed=False,final_error=str(e))
  result['artifacts']=inventory(out);save(out/'build.json',result)
 if failure:raise failure
 return verify(out)
def verify(out):
 meta=frozen(out);r=read(out/'build.json')
 assert r['compiled'] and r['build_checks_passed'] and r['installation_unchanged'] and r['inputs_unchanged']
 assert r['base_sha256']==BASE_SHA and r['prepared_sha256']==sha(out/'prepared.json') and r['inputs']==meta['inputs']
 assert r['installation_before']==r['installation_after']==meta['installation_before']
 assert len(r['commands'])==len(meta['commands']) and all(x['exit_code']==0 and x['reaped'] for x in r['commands'])
 assert all({k:x[k] for k in ('name','argv')}==expected for x,expected in zip(r['commands'],meta['commands']))
 for p,h in r['artifacts'].items():assert sha(out/p)==h,p
 assert r['candidate_sha256']==sha(out/'pfe.swf') and r['base_xml_sha256']==sha(out/'base.xml')
 assert r['method_audit']==read(out/'method-audit.json') and r['retain']==read(out/'retain.json') and r['splice']==read(out/'splice.json')
 assert r['method_audit']['passed'] and r['retain']['passed'] and r['splice']['raw_resources_preserved']
 assert all(not r[k] for k in ('air_started','installed','runtime_validated'))
 return r
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=DEFAULT)
 modes=parser.add_mutually_exclusive_group(required=True)
 for key in ('check','prepare','build','verify'):modes.add_argument('--'+key,action='store_true')
 parser.add_argument('--registry-wait',type=float,default=900);args=parser.parse_args();out=target(args.output)
 if args.check:value=dict(passed=True,input_count=len(pins()),java_started=False)
 elif args.prepare:value=prepare(out)
 elif args.build:value=build(out,args.registry_wait)
 else:value=verify(out)
 print(json.dumps({k:v for k,v in value.items() if k in ('passed','input_count','java_started','base_sha256','candidate_sha256','compiled','build_checks_passed')},ensure_ascii=False))
if __name__=='__main__':main()
