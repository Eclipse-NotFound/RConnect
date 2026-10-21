"""Freeze exact recovery11 + sparse first-raster overlay. No deploy or AIR.

--build explicitly uses the existing frozen build_mod.py under test_registry.
"""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-11'
PIN='cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {x.relative_to(p).as_posix():sha(x) for x in sorted(p.rglob('*')) if x.is_file()}
def verify_proposal():
    m=read(HERE/'integration.json');b=read(BASE/'prepared.json')
    assert b['compiled'] and b['sha256']==PIN==sha(BASE/'RConnectMod.swf')
    assert inventory(BASE/'src')==b['source'] and inventory(BASE/'tools')==b['inputs']
    for n,h in m['inputs'].items():assert sha(ROOT/n)==h,n
    for n,h in m['overlays'].items():assert sha(HERE/n)==h,n
    assert len(m['overlays'])==6
    return m,b
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('output',type=Path);p.add_argument('--build',action='store_true')
    p.add_argument('--version',default='0.2.24-recovery11-raster1');p.add_argument('--registry-wait',type=float,default=900)
    a=p.parse_args();out=(ROOT/a.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists(),'Use a fresh build/m52 folder'
    m,b=verify_proposal();assert a.version.startswith('0.2.24-') and len(a.version)<80
    shutil.copytree(BASE/'src',out/'src');shutil.copytree(BASE/'tools',out/'tools')
    for name in m['overlays']:
        source=HERE/name
        if source.is_relative_to(HERE/'src'):
            target=out/'src'/source.relative_to(HERE/'src');target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
    source=out/'src/RConnectMod.as';s=source.read_text(encoding='utf-8-sig')
    old='VERSION:String = "0.2.24-recovery11"';assert s.count(old)==1
    source.write_text(s.replace(old,'VERSION:String = '+json.dumps(a.version),1),encoding='utf-8',newline='\n')
    for name in ('integration.json','proposal.patch','README.md','generate.py','prepare.py'):
        target=out/'proposal'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(HERE/name,target)
    meta=dict(kind='isolated-first-raster',version=a.version,base='build/m52/recovery-11',base_sha256=PIN,
              source=inventory(out/'src'),inputs=inventory(out/'tools'),proposal=inventory(out/'proposal'),
              compiled=False,runtime_tested=False,installed=False,gameplay_qualified=False,performance_qualified=False)
    save(out/'prepared.json',meta)
    if a.build:
        sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK
        sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'));from test_registry import Registration
        sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
        before=installation();meta['installation_before']=before
        def verify():
            verify_proposal()
            assert inventory(out/'src')==meta['source'] and inventory(out/'tools')==meta['inputs']
            assert inventory(out/'proposal')==meta['proposal'] and installation()==before
        with Registration(owner='RConnect / 首次栅格隔离编译',resource='game',purpose=a.version+' no AIR or deploy',
                          run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as record:
            command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
                     '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
            verify();save(out/'build-command.json',command)
            with (out/'compile.log').open('x',encoding='utf-8') as log:
                process=None
                try:
                    record.before_launch('First raster production compile')
                    process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)))
                    record.child(process.pid);meta['compile_exit']=process.wait(timeout=240)
                finally:
                    if process is not None and process.poll() is None:process.kill();process.wait()
                    record.child_stopped()
            verify();meta['installed_unchanged']=installation()==before
            if meta['compile_exit']==0:meta.update(compiled=True,sha256=sha(out/'RConnectMod.swf'),candidate_sha256=sha(out/'RConnectMod.swf'))
            save(out/'prepared.json',meta);assert meta['compiled'],'Compile failed; preserve evidence'
            record.outcome='passed';record.note='Only compile passed; native behavior and performance untested'
    print(out)
if __name__=='__main__':main()
