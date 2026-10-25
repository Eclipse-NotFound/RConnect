"""One existing bounded mxmlc invocation, rebound to the three only-RC sources."""
from pathlib import Path
import hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.parent/'goal-ordinary-lamp-native/diagnostic-build.py'
OLD_SHA='74fccc7726f39fabf06b26e178ceb3ba850d7f3f61654d79c07e2cb835fdd307'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
    s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
assert sha(OLD)==OLD_SHA
base=load(OLD,'only_rc_bounded_compiler')
source=load(HERE/'prepare.py','only_rc_loading_source')
base.SOURCE=HERE;base.KIND='only-rconnect-loading-driver-v1'

def inputs():
    assert sha(OLD)==OLD_SHA
    proof=source.verify();assert proof['source_count']==3
    old,original=read(base.BASE/'compile.json'),read(base.BASE/'prepared.json')
    assert old['compiled'] and old['inputs_unchanged'] and old['error'] is None and old['validation_error'] is None
    assert old['prepared_sha256']==sha(base.BASE/'prepared.json') and len(old['commands'])==1
    assert old['commands'][0]['command']==base.command(base.BASE) and old['commands'][0]['exit_code']==0 and old['commands'][0]['reaped']
    paths=[Path(__file__),OLD,HERE/'prepare.py',HERE/'source-manifest.json',HERE/'source.diff',HERE/'README.md',
           base.BASE/'prepared.json',base.BASE/'compile.json']
    paths += [HERE/'tests'/n for n in proof['sources']]+[base.BASE/'tests'/n for n in proof['original_sources']]
    for p,h in base.PINS.items():
        if p.parent==base.BASE or p.is_relative_to(base.ROOT/'tools') or p.is_relative_to(base.GAME/'mods/ModLoader/tools'):
            assert sha(p)==h;paths.append(p)
    for n,h in base.DEPENDENCIES.items():assert sha(base.BASE/n)==original['files'][n]==h;paths.append(base.BASE/n)
    for p in (base.JAVA,base.SDK/'lib/mxmlc.jar',base.SDK/'frameworks/air-config.xml',base.SDK/'frameworks/libs/air/airglobal.swc'):
        assert sha(p)==original['inputs'][str(p)];paths.append(p)
    sources=base.inventory(HERE/'tests');assert sources==proof['sources'] and len(sources)==3
    return {str(p.resolve()):sha(p) for p in sorted(set(paths))},proof,sources

def output_path(p):
    out=(ROOT/p).resolve()
    assert out.parent==M52 and out.name.startswith('goal-rconnect-only-loading-driver-'),out
    return out
base.inputs=inputs;base.output_path=output_path
def verify(output):return base.verify(output)
def main():
    if '--build' in sys.argv and '--output' not in sys.argv:sys.argv+=['--output',str(M52/'goal-rconnect-only-loading-driver-01')]
    return base.main()
if __name__=='__main__':
    try:main()
    except (FileNotFoundError,base.NotReady) as e:
        print(json.dumps(dict(ready=False,status='not-ready',error=str(e))));raise SystemExit(2)
