"""ACC -> early World/Game only, registered existing FFDec toolchain.

--build is explicit. Default merely freezes sources/commands in a new m52 dir.
No AIR, installed writes, SWF/resource cloning or compiler copies.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
BASE=ROOT/'build/m52/recovery-wall-surfaces-host-01'
PIN='acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd'
PATCHED=('fe.World','fe.loc.Game')
REPRESENTATIVES=('MainFE','fe.graph.Grafon','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def text(p):return Path(p).read_text(encoding='utf-8-sig')
def save(p,x):Path(p).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def token(s):
    pieces=re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?\*/|\s+|\w+|[^\w\s]',s)
    return ''.join(x for x in pieces if not x.isspace() and not x.startswith('//') and not x.startswith('/*'))
def methods(s):
    out={}
    for m in re.finditer(r'(?:public|private|protected|internal)\s+(?:(?:static|override)\s+)*function\s+((?:get\s+|set\s+)?\w+)\([^\n]*\)[^{]*\{',s):
        i=m.end();depth=1
        while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
        name=m[1];assert name not in out,name;out[name]=s[m.start():i]
    return out
def verify_readback(cls,before,after,expected):
    b,a,e=methods(before),methods(after),methods(expected)
    assert set(a)==set(e),('class method set',cls)
    if cls=='fe.World':
        assert set(e)-set(b)=={'rconnectLoadingHold','rconnectCancelLoading'}
        changed={'step','exitStep','rconnectLoadingHold','rconnectCancelLoading'}
        for n in a:
            got=token(a[n]);want=token(e[n] if n in changed else b[n])
            if n=='rconnectCancelLoading':
                call='Game.rconnectTravelBridge("cancel-load",this.game,null);'
                # FFDec normally braces this one newly added single statement.
                # No other branch/body or method is normalized.
                got=got.replace('if(Game.rconnectTravelBridge!=null){'+call+'}',
                    'if(Game.rconnectTravelBridge!=null)'+call)
            assert got==want,(cls,n)
    else:
        assert set(a)==set(b)
        for n in a:
            if n!='enterToCurLand':assert token(a[n])==token(b[n]),(cls,n)
        tail='if(rconnectTravelBridge!=null)rconnectTravelBridge("constructed",this,null);'
        bracket='if(rconnectTravelBridge!=null){rconnectTravelBridge("constructed",this,null);}'
        got=token(a['enterToCurLand']);want=token(e['enterToCurLand'])
        assert got.replace(bracket,tail)==want,('exact Game tail/body',cls)
        assert 'publicstaticconstrconnectEarlyTravelVersion:int=1;' in token(after)
    assert '§§' not in after,cls
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output',type=Path);ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
    frozen=read(HERE/'handoff.json');assert frozen['status']=='source-frozen-awaiting-native-qualification'
    assert all(sha(HERE/p)==h for p,h in frozen['files'].items())
    prior=read(ROOT/'build/m52/recovery-wall-surfaces-host-recheck-01/receipt.json')
    assert prior['validated'] and prior['candidate_sha256']==PIN and sha(BASE/'pfe.swf')==PIN
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from prepare_recovery_native_travel import normalized,movie_header
    from run_security_terminals import installation
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,FFDEC
    from patch_native import swf_tags
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    inputs={str(p):sha(p) for p in (BASE/'pfe.swf',BASE/'prepared.json',HERE/'handoff.json',Path(__file__),
        ROOT/'build/m52/recovery-wall-surfaces-host-recheck-01/receipt.json',JAVA,FFDEC,
        ROOT/'tools/validation/prepare_recovery_native_travel.py',ROOT/'tools/validation/run_security_terminals.py',
        ROOT/'tools/host_authority/common.py',ROOT/'tools/host_authority/patch_native.py',GAME/'mods/ModLoader/tools/test_registry.py')}
    installed=installation();assert len(installed)==22
    imports={};out.mkdir()
    for cls in PATCHED:
        rel=Path(*cls.split('.')).with_suffix('.as');src=HERE/'host-import'/rel
        ref=BASE/'after/scripts'/rel;inputs[str(src)]=sha(src);inputs[str(ref)]=sha(ref)
        assert '§§' not in text(src)
        p=out/'import'/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(src.read_bytes());imports[rel.as_posix()]=sha(p)
        verify_readback(cls,text(ref),text(src),text(src))
    names=','.join((*PATCHED,*REPRESENTATIVES))
    commands=[(['-selectclass',names,'-export','script',out/'before',BASE/'pfe.swf'],'before.log'),
        (['-importScript',BASE/'pfe.swf',out/'pfe.swf',out/'import'],'import.log'),
        (['-selectclass',names,'-export','script',out/'after',out/'pfe.swf'],'after.log'),
        (['-dumpAS3',BASE/'pfe.swf'],'before-classes.txt'),(['-dumpAS3',out/'pfe.swf'],'after-classes.txt')]
    result={'kind':'isolated-early-travel-host','base_sha256':PIN,'patched_classes':list(PATCHED),'inputs':inputs,
        'import_sources':imports,'installation_before':installed,'compiled':False,'validated':False,'air_started':False,
        'installed':False,'gameplay_qualified':False,'performance_qualified':False,'audit_limit':'exact selected source methods, representatives, class list/header/non-code tags; not all ABC semantics'}
    save(out/'commands.json',[[str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)] for args,_ in commands]);save(out/'prepared.json',result)
    def verify():
        assert all(sha(Path(p))==h for p,h in inputs.items())
        assert all(sha(out/'import'/p)==h for p,h in imports.items())
        assert installation()==installed
    if not a.build:print(out);return
    try:
        with Registration(owner='RConnect / 共同旅行提前交付宿主',resource='game',purpose='ACC World/Game only; no AIR',run_dir=out,evidence=out/'prepared.json',wait=a.registry_wait) as reg:
            for args,name in commands:
                verify();process=None
                with (out/name).open('x',encoding='utf-8') as log,(out/(name+'.stderr.log')).open('x',encoding='utf-8') as err:
                    try:
                        reg.before_launch('FFDec '+name);process=subprocess.Popen([str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)],cwd=out,stdout=log,stderr=err)
                        reg.child(process.pid);assert process.wait(timeout=300)==0,name
                    finally:
                        if process is not None and process.poll() is None:process.kill();process.wait()
                        reg.child_stopped()
                for p in (out/name,out/(name+'.stderr.log')):assert not any(x in text(p) for x in ('SEVERE:','Unknown preprocessor instruction','Exception in thread')),p
                if name=='import.log':result.update(compiled=True,candidate_sha256=sha(out/'pfe.swf'))
            for cls in PATCHED:
                rel=Path(*cls.split('.')).with_suffix('.as')
                assert normalized(text(out/'before/scripts'/rel))==normalized(text(BASE/'after/scripts'/rel))
                verify_readback(cls,text(out/'before/scripts'/rel),text(out/'after/scripts'/rel),text(out/'import'/rel))
            representatives={}
            for cls in REPRESENTATIVES:
                rel=Path(*cls.split('.')).with_suffix('.as');b=normalized(text(out/'before/scripts'/rel));c=normalized(text(out/'after/scripts'/rel))
                assert b==c,cls;representatives[cls]=hashlib.sha256(b.encode()).hexdigest()
            before,after=swf_tags(BASE/'pfe.swf'),swf_tags(out/'pfe.swf');assert len(before)==len(after);changed=[]
            for i,(b,c) in enumerate(zip(before,after)):
                assert b[0]==c[0]
                if b!=c:assert b[0] in (72,82);changed.append(i)
            assert changed and movie_header(BASE/'pfe.swf')==movie_header(out/'pfe.swf')
            assert normalized(text(out/'before-classes.txt'))==normalized(text(out/'after-classes.txt'))
            verify();result.update(validated=True,representative_normalized_sha256=representatives,changed_code_tags=changed,
                non_code_tags_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True)
            reg.outcome='passed';reg.note='two-class compile and exact selected readback only; no native gameplay/performance claim'
    except BaseException as error:result.update(validated=False,error=str(error));raise
    finally:
        result['installation_unchanged']=installation()==installed
        result['source_unchanged']=all(sha(Path(p))==h for p,h in inputs.items())
        if not result['installation_unchanged'] or not result['source_unchanged']:result['validated']=False
        result['readback_files']={p.relative_to(out).as_posix():sha(p) for sub in ('before','after') for p in (out/sub).rglob('*') if p.is_file()}
        save(out/'prepared.json',result)
    assert result['validated'];print(out)
if __name__=='__main__':main()
