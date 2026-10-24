"""v5's two supervised compiler calls, exact 78C plus two frozen UI sources."""
from pathlib import Path
import argparse, json, shutil, subprocess, sys, types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import inputs as source
ROOT=source.ROOT;HERE=source.HERE;sha=source.sha;read=source.read;save=source.save;inventory=source.inventory
sys.path.insert(0,str(ROOT/'tools/validation'))
from runtime_memory import snapshot,wait_owned
from run_security_terminals import installation
sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'))
from test_registry import Registration
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=ROOT.parent/'Sandevistan/build/tools/flexsdk'
DEFAULT=ROOT/'build/m52/goal-native-loading-product-01'
def target(p):
 p=Path(p);p=(p if p.is_absolute() else ROOT/p).resolve()
 assert p.parent==ROOT/'build/m52' and p.name.startswith('goal-native-loading-product-')
 return p
def pins():
 result=source.pins()
 for p in (JAVA,SDK/'lib/compc.jar',SDK/'lib/mxmlc.jar',ROOT/'experimental/recovery-room-production-v5/build.py',
           ROOT/'tools/validation/runtime_memory.py',ROOT/'tools/validation/run_security_terminals.py',ROOT.parent/'ModLoader/tools/test_registry.py'):
  result[str(p)]=sha(p)
 return result
def prepare(out):
 assert not out.exists(),'Preserve old outputs';inputs=pins();before=source.current();receipt=source.reviewed()
 shutil.copytree(source.BASE/'src',out/'src');shutil.copytree(source.BASE/'tools',out/'tools')
 for rel in receipt['product_overlay']:shutil.copyfile(source.UI/'src'/rel,out/'src'/rel)
 meta=dict(kind='native-loading-ui-product',version=receipt['version'],base_sha256=source.PRODUCT_SHA,source=inventory(out/'src'),
           inputs=inventory(out/'tools'),reviewed_inputs=inputs,installation_before=before,overlay_manifest_sha256=source.MANIFEST_SHA,
           compiled=False,installed=False,air_started=False)
 save(out/'prepared.json',meta);return meta
def frozen(out):
 meta=read(out/'prepared.json');assert meta['base_sha256']==source.PRODUCT_SHA and meta['reviewed_inputs']==pins()
 assert meta['source']==inventory(out/'src') and meta['inputs']==inventory(out/'tools')
 original=read(source.BASE/'prepared.json')['source'];overlay=source.reviewed()['product_overlay']
 assert meta['source']==original|overlay and len(meta['source'])==len(original)
 return meta
def build(out,wait):
 meta=prepare(out) if not out.exists() else frozen(out)
 assert not(out/'compile.json').exists(),'Never overwrite final/failed receipt'
 before=source.current();assert before==meta['installation_before'];prepared_sha=sha(out/'prepared.json')
 result=dict(compiled=False,commands=[],installation_before=before,prepared_sha256=prepared_sha,air_started=False,installed=False,
             gameplay_qualified=False,performance_qualified=False);failure=None
 try:
  with Registration(owner='RConnect / 原生加载显示',resource='game',purpose='nativeui1 exact 78C product compile',run_dir=out,evidence=out/'prepared.json',wait=wait) as reg:
   assert source.current()==before and frozen(out)==meta
   module=source.load('native_ui_product_compiler',out/'tools/build_mod.py')
   with (out/'compile.log').open('x',encoding='utf-8') as log:
    def owned(command,env=None,check=False):
     assert len(result['commands'])<2 and command[0]==str(JAVA) and '-Xmx384m' in command
     assert snapshot()['free_commit_bytes']>=1024**3
     assert Path(command[command.index('-jar')+1]).resolve() in ((SDK/'lib/compc.jar').resolve(),(SDK/'lib/mxmlc.jar').resolve())
     assert installation()==before
     reg.before_launch('isolated native UI compiler')
     row=dict(command=command,pid=None,exit_code=None,reaped=False);result['commands'].append(row);process=None
     try:
      process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
      reg.child(process.pid);row['pid']=process.pid
      row['exit_code']=wait_owned(process,300,out/('memory-'+str(len(result['commands']))+'.json'))
     finally:
      if process is not None:
       if process.poll() is None:process.kill()
       process.wait();row['reaped']=process.poll() is not None
      reg.child_stopped()
     if check and row['exit_code']:raise subprocess.CalledProcessError(row['exit_code'],command)
     return subprocess.CompletedProcess(command,row['exit_code'])
    module.subprocess=types.SimpleNamespace(run=owned)
    old_argv=sys.argv
    try:
     sys.argv=[str(out/'tools/build_mod.py'),'--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
     module.main()
    finally:sys.argv=old_argv
   assert len(result['commands'])==2 and all(c['exit_code']==0 and c['reaped'] for c in result['commands'])
   assert frozen(out)==meta and installation()==before
   result.update(compiled=True,candidate_sha256=sha(out/'RConnectMod.swf'))
   reg.outcome='passed';reg.note='Isolated product compiled only; native paired host testing remains'
 except BaseException as e:failure=e;result.update(error_type=type(e).__name__,error=str(e))
 finally:
  try:
   result['installation_after']=installation();result['installation_unchanged']=before==result['installation_after']
   result['sources_unchanged']=frozen(out)==meta and sha(out/'prepared.json')==prepared_sha
   assert result['installation_unchanged'] and result['sources_unchanged']
  except BaseException as e:failure=failure or e;result.update(validation_error=str(e),sources_unchanged=False)
  result['artifacts']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}
  save(out/'compile.json',result)
 if failure:raise failure
 return verify(out)
def verify(output):
 out=target(output);meta=frozen(out);r=read(out/'compile.json')
 assert r['compiled'] and r['installation_unchanged'] and r['sources_unchanged']
 assert r['prepared_sha256']==sha(out/'prepared.json') and r['installation_before']==r['installation_after']==meta['installation_before']
 assert len(r['commands'])==2 and all(x['exit_code']==0 and x['reaped'] for x in r['commands'])
 assert r['candidate_sha256']==sha(out/'RConnectMod.swf')
 for p,h in r['artifacts'].items():assert sha(out/p)==h,p
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
 print(json.dumps({k:v for k,v in value.items() if k in ('passed','input_count','java_started','base_sha256','candidate_sha256','compiled')},ensure_ascii=False))
if __name__=='__main__':main()
