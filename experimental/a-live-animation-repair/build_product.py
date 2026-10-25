"""Compile the animation-only overlay on exact installed 78C; no deployment."""
from pathlib import Path
import difflib,json,os,shutil,subprocess,sys
from build_probe import ROOT,GAME,JAVA,SDK,sha,save,installation,snapshot,wait_owned,Registration
BASE=ROOT/'build/m52/recovery-room-production-05';HERE=Path(__file__).resolve().parent
def inventory(p):return {n.relative_to(p).as_posix():sha(n) for n in sorted(p.rglob('*')) if n.is_file()}
def main():
 out=(ROOT/sys.argv[1]).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
 old=json.loads((BASE/'prepared.json').read_text('utf8'))
 assert inventory(BASE/'src')==old['source'] and sha(BASE/'RConnectMod.swf')=='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
 assert sha(BASE/'build/GameCombatStubs.swc')=='34db11009c05ae038394a0cf43ca93454301c5e60277922992268776b39329cd'
 before=installation();assert before['mods/Rconnect/release/RConnectMod.swf']==sha(BASE/'RConnectMod.swf')
 overlay=inventory(HERE/'src');shutil.copytree(BASE/'src',out/'src')
 diff=''
 for rel in overlay:
  original=(BASE/'src'/rel).read_text('utf8').splitlines(True)
  new=(HERE/'src'/rel).read_text('utf8').splitlines(True)
  diff+=''.join(difflib.unified_diff(original,new,fromfile='78C/'+rel,tofile='animfix1/'+rel))
  shutil.copyfile(HERE/'src'/rel,out/'src'/rel)
 (out/'source.diff').write_text(diff,encoding='utf8')
 shutil.copyfile(BASE/'build/GameCombatStubs.swc',out/'GameCombatStubs.swc')
 command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
  '-swf-version=38','-debug=false','-optimize=true','-warnings=true','-source-path='+str(out/'src'),
  '-external-library-path+='+str(out/'GameCombatStubs.swc'),'-output='+str(out/'RConnectMod.swf'),str(out/'src/RConnectDoc.as')]
 meta=dict(base_sha256=sha(BASE/'RConnectMod.swf'),overlay=overlay,source=inventory(out/'src'),stub_sha256=sha(out/'GameCombatStubs.swc'),
  recipe_sha256=sha(__file__),installation_before=before,command=command)
 save(out/'prepared.json',meta);result=dict(compiled=False,pid=None,exit_code=None,reaped=False,installed=False,air_started=False)
 try:
  with Registration(owner='RConnect / 动画修复',purpose='78C animation-only candidate compile',run_dir=out,evidence=out/'compile.json',wait=900) as reg:
   assert snapshot()['free_commit_bytes']>=1024**3;proc=None
   try:
    reg.before_launch('One AIR compiler, existing unchanged native stubs')
    with (out/'compile.log').open('x',encoding='utf8') as log:
     proc=subprocess.Popen(command,cwd=out,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
     result['pid']=proc.pid;reg.child(proc.pid);result['exit_code']=wait_owned(proc,300,out/'compile-memory.json')
    assert result['exit_code']==0,'Read compile.log'
   finally:
    if proc is not None:
     if proc.poll() is None:proc.kill()
     proc.wait();result['reaped']=True;reg.child_stopped()
   assert inventory(out/'src')==meta['source'] and inventory(HERE/'src')==overlay and installation()==before
   result.update(compiled=True,candidate_sha256=sha(out/'RConnectMod.swf'));reg.outcome='passed'
   reg.note='Compilation only; native animation/performance still require tests'
 finally:
  result['installation_after']=installation();result['installation_unchanged']=before==result['installation_after'];save(out/'compile.json',result)
 print(json.dumps({k:v for k,v in result.items() if k!='installation_after'}))
if __name__=='__main__':main()
