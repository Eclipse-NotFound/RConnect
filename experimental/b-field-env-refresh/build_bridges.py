"""Compile the three pinned independent sources, with owned-process checks."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
sys.path.insert(0,str(HERE));from environment import swf_strings,BRIDGES
sys.path.insert(0,str(RC/'tools/host_authority'));from common import JAVA,SDK,FFDEC
sys.path.insert(0,str(RC/'tools/validation'));from runtime_memory import snapshot,wait_owned
from run_security_terminals import installation
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'));from test_registry import Registration
SOURCES={'TDFCMod':HERE/'bridge-sources-02/TDFC','SandevistanMod':HERE/'bridge-sources-02/Sandevistan','PermanentInjuryMod':HERE/'injury-sources-01'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):
 with p.open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def inputs():
 result={}
 for name,src in SOURCES.items():
  prep=read(src/'prepared.json');files=prep['sources']
  for p,h in files.items():
   if sha(src/p)!=h:raise ValueError('Changed source '+str(src/p))
  for p,h in prep['compiler'].items():
   if sha(p)!=h:raise ValueError('Changed compiler '+p)
  result[name]={'prepared_sha256':sha(src/'prepared.json'),'sources':files,'compiler':prep['compiler']}
 return result
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',default='bridge-build-01');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
 out=(HERE/a.output).resolve()
 if not out.is_relative_to(HERE) or out==HERE:raise ValueError('Only independent output directory')
 if out.exists():raise FileExistsError('Use a fresh build record')
 out.mkdir();(out/'tool-home').mkdir();before=installation();pins=inputs();save(out/'prepared.json',pins);result={'compiled':False,'installed':False,'runtime_qualified':False,'modules':{},'commands':[]};failure=None
 try:
  with Registration(owner='RConnect B / refreshed independent bridges',resource='game',purpose='Compile pinned TDFC scene2, Sandy keybind and PI authority sources; no AIR',run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as reg:
   for name,src in SOURCES.items():
    if (src/(name+'.swf')).exists():raise FileExistsError('Do not overwrite a previously built candidate: '+name)
    prep=read(src/'prepared.json');commands=list(prep['commands'])
    commands.append([str(JAVA),'-Xmx512m','-jar',str(FFDEC),'-dumpAS3',str(src/(name+'.swf'))])
    for i,command in enumerate(commands):
     if inputs()!=pins:raise ValueError('Frozen input changed')
     m=snapshot();save(out/(name+'-'+str(i)+'-memory-before.json'),m)
     if m['free_commit_bytes']<1024**3:raise RuntimeError('Less than 1GiB commit headroom')
     logpath=out/(name+'-'+str(i)+'.log');process=None;record={'module':name,'argv':command};result['commands'].append(record)
     with logpath.open('x',encoding='utf-8') as log:
      try:
       reg.before_launch(name+' compile/inspect '+str(i));process=subprocess.Popen(command,cwd=src,env=dict(os.environ,AIR_HOME=str(SDK),APPDATA=str(out/'tool-home')),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW);reg.child(process.pid)
       record['exit_code']=wait_owned(process,180,out/(name+'-'+str(i)+'-memory.json'))
      finally:
       if process is not None:
        if process.poll() is None:process.kill()
        process.wait()
       reg.child_stopped()
     if record['exit_code']!=0:raise RuntimeError('Compile/inspect failed: '+str(logpath))
    cls=logpath.read_text(encoding='utf-8',errors='replace');names={line.split()[0] for line in cls.splitlines() if line.strip()}
    allowed={'fe.serv.SandyHighFpsClock'} if name=='SandevistanMod' else set()
    if name not in names or any(c.startswith('fe.') and c not in allowed for c in names):raise ValueError('Invalid game class isolation: '+name)
    if 'AccessDeniedException' in cls or 'SEVERE:' in cls:raise ValueError('FFDec inspection error: '+name)
    artifact=src/(name+'.swf')
    if not all(swf_strings(artifact,BRIDGES[name]).values()):raise ValueError('Authority API missing: '+name)
    result['modules'][name]={'path':str(artifact),'sha256':sha(artifact),'authority_api':1,'source_sha256':sha(src/'prepared.json'),'class_list_sha256':sha(logpath)}
   result['compiled']=True;reg.outcome='passed';reg.note='Three candidates compile/API/class isolation passed; runtime not tested'
 except BaseException as e:failure=e;result.update(error=str(e),error_type=type(e).__name__)
 finally:
  result['installation_unchanged']=installation()==before;result['inputs_unchanged']=inputs()==pins
  if not result['installation_unchanged'] or not result['inputs_unchanged']:failure=failure or RuntimeError('Installation/input changed')
  save(out/'build.json',result)
 if failure:raise failure
 print(json.dumps(result['modules'],ensure_ascii=False,indent=2))
if __name__=='__main__':main()
