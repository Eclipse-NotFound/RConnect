"""Prepare/run PI's selective native021 candidate build. Never install or run AIR.

--prepare only records commands and input fingerprints. --build additionally
uses the shared build/test registry, memory guard, bounded owned processes and
exact unrelated SWF tag verification. A failed donor/anchor leaves all evidence.
"""
from pathlib import Path
import argparse,hashlib,json,os,struct,subprocess,sys,zlib
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority'))
from common import FFDEC
sys.path.insert(0,str(RC/'tools/validation'))
from runtime_memory import snapshot,wait_owned
from run_security_terminals import installation
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
JAVA=Path('D:/Program Files/Adobe Animate 2024/jre/bin/java.exe')
JAVAC=JAVA.with_name('javac.exe')
NODE=Path('C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe')
BASE=RC/'build/ab/native-hooks-021/pfe.swf'
BASE_SHA='eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063'
CLASSES=['fe.World','fe.unit.Pers','fe.unit.UnitPlayer','fe.unit.Unit','fe.unit.Invent','fe.weapon.Weapon','fe.weapon.Bullet','fe.unit.Spell','fe.weapon.WMagic','fe.inter.PipPageMed']
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):
 with p.open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def pins(src):
 if sha(BASE)!=BASE_SHA:raise ValueError('Exact native021 is required')
 return {str(p):sha(p) for p in (BASE,src/'patch-native.cjs',src/'MethodPatch.java',JAVA,JAVAC,NODE,FFDEC,Path(__file__))}
def commands(src,out):
 def ff(*args):return [str(JAVA),'-Xms32m','-Xmx768m','-XX:+UseSerialGC','-Dfile.encoding=UTF-8','-Duser.language=en','-Duser.country=US','-jar',str(FFDEC),*map(str,args)]
 return [dict(name='export',argv=ff('-selectclass',','.join(CLASSES),'-export','script',out/'host',BASE)),
  dict(name='prepare-source',argv=[str(NODE),str(src/'patch-native.cjs'),str(out)]),
  dict(name='donor',argv=ff('-importScript',BASE,out/'candidate/donor.swf',out/'candidate/scripts')),
  dict(name='javac',argv=[str(JAVAC),'-classpath',str(FFDEC.parent/'lib/*'),'-d',str(out/'classes'),str(src/'MethodPatch.java')]),
  dict(name='transplant',argv=[str(JAVA),'-Xms32m','-Xmx768m','-XX:+UseSerialGC','-Drconnect.pi.outputRoot='+str(out),
   '-classpath',str(out/'classes')+';'+str(FFDEC.parent/'lib/*'),'MethodPatch',str(BASE),str(out/'candidate/donor.swf'),str(out/'candidate/pfe.swf'),str(out/'methods.tsv')]),
  dict(name='readback',argv=ff('-selectclass',','.join(CLASSES),'-export','script',out/'verified',out/'candidate/pfe.swf'))]
def prepare(src,out):
 if out.exists():raise FileExistsError('Use a new native job directory')
 data=dict(kind='b-injury-native-job',inputs=pins(src),source=str(src),commands=commands(src,out),installation_before=installation(),compiled=False,installed=False)
 out.mkdir(parents=True);(out/'classes').mkdir();(out/'tool-home').mkdir();save(out/'prepared.json',data);return data
def tags(p):
 b=p.read_bytes();body=zlib.decompress(b[8:]) if b[:3]==b'CWS' else b[8:]
 if b[:3] not in (b'CWS',b'FWS'):raise ValueError('Unsupported SWF encoding')
 rect_bytes=(5+4*(body[0]>>3)+7)//8;pos=rect_bytes+4;result=[]
 while pos<len(body):
  h=struct.unpack_from('<H',body,pos)[0];pos+=2;n=h&63;kind=h>>6
  if n==63:n=struct.unpack_from('<I',body,pos)[0];pos+=4
  result.append((kind,body[pos:pos+n]));pos+=n
  if kind==0:break
 return body[:rect_bytes+4],result
def resource_audit(candidate):
 ah,a=tags(BASE);bh,b=tags(candidate)
 if ah!=bh or [x[0] for x in a]!=[x[0] for x in b]:raise ValueError('SWF header/tag order changed')
 changed=[i for i,(x,y) in enumerate(zip(a,b)) if x!=y]
 if not changed or any(a[i][0] not in (72,82) for i in changed):raise ValueError('Non-code game resources changed')
 return dict(raw_resources_preserved=True,tag_count=len(a),changed_abc_tags=changed)
def build(src,out,wait):
 meta=prepare(src,out) if not out.exists() else read(out/'prepared.json')
 if meta['inputs']!=pins(src) or meta['commands']!=commands(src,out):raise ValueError('Prepared inputs changed')
 if (out/'build.json').exists():raise FileExistsError('A completed/failed job is immutable')
 result=dict(compiled=False,installed=False,runtime_qualified=False,commands=[]);failure=None
 try:
  with Registration(owner='RConnect B / PI environment',resource='game',purpose='PI native021 selective candidate; no AIR or installation',run_dir=out,evidence=out/'prepared.json',wait=wait) as reg:
   for row in meta['commands']:
    if pins(src)!=meta['inputs']:raise ValueError('Input changed during build')
    m=snapshot();save(out/(row['name']+'-memory-before.json'),m)
    if m['free_commit_bytes']<1024**3:raise RuntimeError('Less than 1 GiB commit headroom')
    process=None;record=dict(row);result['commands'].append(record)
    with (out/(row['name']+'.log')).open('x',encoding='utf-8') as log:
     try:
      reg.before_launch(row['name']);process=subprocess.Popen(row['argv'],cwd=out,env=dict(os.environ,APPDATA=str(out/'tool-home')),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);reg.child(process.pid)
      record['exit_code']=wait_owned(process,480,out/(row['name']+'-memory.json'))
     finally:
      if process is not None:
       if process.poll() is None:process.kill()
       process.wait()
      reg.child_stopped()
    if record['exit_code']!=0:raise RuntimeError('Build stage failed: '+row['name'])
    text=(out/(row['name']+'.log')).read_text(encoding='utf-8',errors='replace')
    if any(s in text for s in ('SEVERE:','Exception in thread','Export error','Unknown preprocessor instruction')):raise RuntimeError('Compiler/decompiler reported failure: '+row['name'])
   proof=read(out/'candidate/verification.json')
   if not proof.get('readback') or proof.get('transplantedMethods')!=26:raise ValueError('Incomplete selective PI method verification')
   result.update(compiled=True,candidate_sha256=sha(out/'candidate/pfe.swf'),method_proof=proof,resource_proof=resource_audit(out/'candidate/pfe.swf'))
   reg.outcome='passed';reg.note='Candidate bytecode/resource checks only; PI/B game validation still required'
 except BaseException as e:failure=e;result.update(error=str(e),error_type=type(e).__name__)
 finally:
  result['installation_unchanged']=installation()==meta['installation_before'];result['inputs_unchanged']=pins(src)==meta['inputs']
  if not result['installation_unchanged'] or not result['inputs_unchanged']:failure=failure or RuntimeError('Installation or inputs changed')
  save(out/'build.json',result)
 if failure:raise failure
 return result
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--sources',default='injury-sources-01');ap.add_argument('--job',default='native-01');ap.add_argument('--registry-wait',type=float,default=900)
 mode=ap.add_mutually_exclusive_group(required=True);mode.add_argument('--prepare',action='store_true');mode.add_argument('--build',action='store_true');a=ap.parse_args()
 src=(HERE/a.sources).resolve();out=(src/a.job).resolve()
 if not src.is_relative_to(HERE) or src==HERE or not out.is_relative_to(src) or out==src:raise ValueError('Only independent PI source/job directories are allowed')
 r=prepare(src,out) if a.prepare else build(src,out,a.registry_wait)
 print(json.dumps({k:v for k,v in r.items() if k in ('kind','compiled','candidate_sha256','installed','runtime_qualified')},ensure_ascii=False))
if __name__=='__main__':main()
