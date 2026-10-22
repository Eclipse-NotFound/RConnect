"""Prepare/build a fresh diagnostic host with ONLY Grafon imported.

Default writes sources/commands/manifest, never starts JVM. --build is for the
root integrator only. No AIR/install; actual exception CFG remains reviewable.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
import prepare
import check

HERE=Path(__file__).resolve().parent;ROOT=prepare.ROOT;GAME=ROOT.parents[1]
REPRESENTATIVES=('MainFE','fe.World','fe.loc.Game','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def text(p):return Path(p).read_text(encoding='utf-8-sig')
def save(p,x):Path(p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path);ap.add_argument('--build',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
    check.verify_source(prepare.TARGET.read_bytes())
    assert sha(prepare.BASE/'pfe.swf')==prepare.HOST_SHA
    prior=ROOT/'build/m52/recovery-early-host-recheck-01/receipt.json'
    assert read(prior)['validated'] and read(prior)['candidate_sha256']==prepare.HOST_SHA
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from prepare_recovery_native_travel import normalized,movie_header
    from runtime_memory import snapshot,wait_owned
    from run_security_terminals import installation
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,FFDEC
    from patch_native import swf_tags
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    inputs={str(p):sha(p) for p in (prepare.BASE/'pfe.swf',prepare.BASE/'prepared.json',prepare.SOURCE,
        prepare.TARGET,HERE/'prepared.json',HERE/'prepare.py',HERE/'check.py',Path(__file__),prior,JAVA,FFDEC,
        ROOT/'experimental/recovery-early-travel/prepare_host.py',
        ROOT/'tools/validation/prepare_recovery_native_travel.py',ROOT/'tools/validation/runtime_memory.py',
        ROOT/'tools/validation/run_security_terminals.py',ROOT/'tools/host_authority/common.py',
        ROOT/'tools/host_authority/patch_native.py',GAME/'mods/ModLoader/tools/test_registry.py')}
    inputs.update({str(p):sha(p) for p in (prepare.ACC_SOURCE,prepare.ACC/'pfe.swf',
        prepare.ACC/'after/scripts/fe/graph/Grafon.as',prepare.ACC/'prepared.json',prepare.V1/'handoff.json',
        ROOT/'build/m52/recovery-early-paint-host-01/prepared.json',
        ROOT/'build/m52/recovery-early-paint-host-01/import.log.stderr.log')})
    inputs.update({str(prepare.V1/p):h for p,h in prepare.frozen_v1()['files'].items()})
    inputs.update({str(prepare.V2/p):h for p,h in prepare.frozen_v2()['files'].items()})
    inputs.update({str(p):sha(p) for p in (prepare.V2/'handoff.json',prepare.REJECTED,
        prepare.REJECTED_HOST/'prepared.json',prepare.REJECTED_HOST/'pfe.swf')})
    installed=installation();assert len(installed)==22
    out.mkdir();dest=out/'import/fe/graph/Grafon.as';dest.parent.mkdir(parents=True);dest.write_bytes(prepare.TARGET.read_bytes())
    names=','.join(('fe.graph.Grafon',*REPRESENTATIVES))
    commands=[(['-selectclass',names,'-export','script',out/'before',prepare.BASE/'pfe.swf'],'before.log'),
        (['-importScript',prepare.BASE/'pfe.swf',out/'pfe.swf',out/'import'],'import.log'),
        (['-selectclass',names,'-export','script',out/'after',out/'pfe.swf'],'after.log'),
        (['-format','script:pcode','-selectclass','fe.graph.Grafon','-export','script',out/'pcode',out/'pfe.swf'],'pcode.log'),
        (['-dumpAS3',prepare.BASE/'pfe.swf'],'before-classes.txt'),(['-dumpAS3',out/'pfe.swf'],'after-classes.txt')]
    result=dict(kind='diagnostic-only-early-paint-host-v3',diagnostic_only=True,base_sha256=prepare.HOST_SHA,
        explicit_error_propagation_and_exact_water_restoration=read(HERE/'prepared.json'),
        patched_classes=['fe.graph.Grafon'],inputs=inputs,import_sources={'fe/graph/Grafon.as':sha(dest)},
        installation_before=installed,compiled=False,source_readback_passed=False,pcode_syntax_passed=False,pcode_bindings_passed=False,
        validated=False,air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
        exception_semantics_review_required=True,binding_semantics_review_required=True,
        audit_limit='exact source plus 15 explicit declaration hoists/21 key quotes; representative classes/class list/non-code tags; timer spelling compared to unchanged calls; actual binding scopes and exception CFG require review')
    save(out/'commands.json',[[str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)] for args,_ in commands])
    save(out/'prepared.json',result)
    def verify():
        assert all(sha(Path(p))==h for p,h in inputs.items())
        assert sha(dest)==result['import_sources']['fe/graph/Grafon.as']
        assert installation()==installed
    if not a.build:print(out);return
    try:
        with Registration(owner='RConnect / 提前加载绘制诊断构建',resource='game',purpose='2D host Grafon sceneEnsure only; no AIR/deployment',run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as reg:
            for args,name in commands:
                verify();mem=snapshot();save(out/(name+'.memory-before.json'),mem)
                assert mem['free_commit_bytes']>=1024**3,'Less than 1 GiB for bounded compilation'
                process=None
                with (out/name).open('x',encoding='utf-8') as log,(out/(name+'.stderr.log')).open('x',encoding='utf-8') as err:
                    try:
                        reg.before_launch('FFDec '+name)
                        process=subprocess.Popen([str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)],cwd=out,stdout=log,stderr=err)
                        reg.child(process.pid);status=wait_owned(process,300,out/(name+'.memory-timeline.json'))
                        assert status==0,(name,status)
                    finally:
                        if process is not None and process.poll() is None:process.kill();process.wait()
                        reg.child_stopped()
                for p in (out/name,out/(name+'.stderr.log')):
                    assert not any(s in text(p) for s in ('SEVERE:','Unknown preprocessor instruction','Exception in thread')),p
                if name=='import.log':result.update(compiled=True,candidate_sha256=sha(out/'pfe.swf'))
            rel=Path('fe/graph/Grafon.as')
            assert normalized(text(out/'before/scripts'/rel))==normalized(text(prepare.SOURCE))
            result['source_readback']=check.verify_readback(text(out/'before/scripts'/rel),text(out/'after/scripts'/rel),text(dest))
            result['source_readback_passed']=True
            pcode_path=out/'pcode/scripts/fe/graph/Grafon.pcode'
            facts,body=check.pcode_facts(text(pcode_path));result['pcode']=facts
            (out/'sceneEnsure.pcode').write_text(body,encoding='utf-8');result['pcode_syntax_passed']=True
            representatives={}
            for cls in REPRESENTATIVES:
                rel=Path(*cls.split('.')).with_suffix('.as')
                b=normalized(text(out/'before/scripts'/rel));c=normalized(text(out/'after/scripts'/rel))
                assert b==c,cls;representatives[cls]=hashlib.sha256(b.encode()).hexdigest()
            before,after=swf_tags(prepare.BASE/'pfe.swf'),swf_tags(out/'pfe.swf');assert len(before)==len(after)
            changed=[]
            for i,(b,c) in enumerate(zip(before,after)):
                assert b[0]==c[0]
                if b!=c:assert b[0] in (72,82);changed.append(i)
            assert changed and movie_header(prepare.BASE/'pfe.swf')==movie_header(out/'pfe.swf')
            assert normalized(text(out/'before-classes.txt'))==normalized(text(out/'after-classes.txt'))
            verify();result.update(representative_normalized_sha256=representatives,changed_code_tags=changed,
                non_code_tags_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True)
            # Explicit catch/rethrow is NOT authorized by lexical equality or
            # by finding a throw opcode. Preserve actual CFG/binding review.
            reg.note='compiled/readback and p-code shape only; actual binding scopes and exception CFG review remain'
    except BaseException as error:result.update(error=str(error));raise
    finally:
        result['installation_unchanged']=installation()==installed
        result['source_unchanged']=all(sha(Path(p))==h for p,h in inputs.items())
        result['readback_files']={p.relative_to(out).as_posix():sha(p) for sub in ('before','after','pcode') for p in (out/sub).rglob('*') if p.is_file()}
        save(out/'prepared.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('inputs','installation_before','readback_files')},ensure_ascii=False))

if __name__=='__main__':main()
