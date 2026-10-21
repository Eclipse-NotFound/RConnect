"""Freeze/build recovery13 with only seed ticket creation disabled; no deployment."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-13'
PIN='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
VERSION='0.2.24-recovery13-seed-off'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {q.relative_to(p).as_posix():sha(q) for q in sorted(p.rglob('*')) if q.is_file()}
def base_ok():
 m=read(BASE/'prepared.json');assert m['compiled'] and m['sha256']==PIN==sha(BASE/'RConnectMod.swf')
 assert inventory(BASE/'src')==m['source'] and inventory(BASE/'tools')==m['inputs']
 return m
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output');ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900)
 a=ap.parse_args();out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
 base_ok();proposal=read(HERE/'integration.json')
 assert proposal['base_sha256']==PIN and len(proposal['overlay'])==1
 for n,h in proposal['overlay'].items():assert sha(HERE/n)==h
 shutil.copytree(BASE/'src',out/'src');shutil.copytree(BASE/'tools',out/'tools')
 shutil.copyfile(HERE/'src/rconnect/core/RoomSync.as',out/'src/rconnect/core/RoomSync.as')
 p=out/'src/RConnectMod.as';s=p.read_text(encoding='utf-8-sig');old='VERSION:String = "0.2.24-recovery13"';assert s.count(old)==1
 p.write_text(s.replace(old,'VERSION:String = '+json.dumps(VERSION),1),encoding='utf-8',newline='\n')
 (out/'proposal').mkdir()
 for name in ('prepare.py','generate.py','integration.json','proposal.patch'):shutil.copyfile(HERE/name,out/'proposal'/name)
 meta=dict(kind='isolated-seed-raster-control',base='build/m52/recovery-13',base_sha256=PIN,version=VERSION,
    source=inventory(out/'src'),inputs=inventory(out/'tools'),proposal=inventory(out/'proposal'),compiled=False,seed_gate=False,
    runtime_tested=False,installed=False,performance_qualified=False)
 save(out/'prepared.json',meta)
 if a.build:
  sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
  sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'));from test_registry import Registration
  sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
  before=installation();meta['installation_before']=before
  def verify():
   base_ok();assert inventory(out/'src')==meta['source'] and inventory(out/'tools')==meta['inputs'] and inventory(out/'proposal')==meta['proposal'] and installation()==before
  with Registration(owner='RConnect / seed首绘单变量对照',resource='game',purpose=VERSION+' compile only',run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as rec:
   command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
   verify();save(out/'build-command.json',command);process=None
   try:
    with (out/'compile.log').open('x',encoding='utf-8') as log:
     rec.before_launch('Seed raster control compile');process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)))
     rec.child(process.pid);meta['compile_exit']=process.wait(timeout=240)
   finally:
    if process is not None and process.poll() is None:process.kill();process.wait()
    rec.child_stopped()
   verify();meta['installed_unchanged']=True
   if meta['compile_exit']==0:meta.update(compiled=True,sha256=sha(out/'RConnectMod.swf'))
   save(out/'prepared.json',meta);assert meta['compiled'],'Compile failed; preserve output'
   rec.outcome='passed';rec.note='Compile only; no gameplay or timing qualification'
 print(out)
if __name__=='__main__':main()
