"""Root-owned positive control: exactly one compiler-mode substitution."""
from pathlib import Path
import argparse,hashlib,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
ORIGINAL=ROOT/'tools/validation/run_recovery_component.py'
ORIGINAL_SHA='9952aeeaa37f6eead636cceff9f25fabff3045671d3c4cbb60c326909d1e572d'
OLD="'-debug=true', '-source-path='"
NEW="'-debug=false', '-optimize=true', '-source-path='"

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source():
    assert sha(ORIGINAL)==ORIGINAL_SHA
    text=ORIGINAL.read_text(encoding='utf-8-sig');assert text.count(OLD)==1
    return text.replace(OLD,NEW,1)
def verify():
    pins=json.loads((HERE/'handoff.json').read_text(encoding='utf-8'))
    for name,digest in pins['files'].items():assert sha(HERE/name)==digest,name
    for name,digest in pins['originals'].items():assert sha(name)==digest,name
    return pins
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True);parser.add_argument('--registry-wait',type=float,default=900)
    args=parser.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    pins=verify();text=source();arguments=sys.argv[:]
    sys.path.insert(0,str(ROOT/'tools/validation'))
    sys.argv=[str(ORIGINAL),'--source',str(HERE/'component'),'--entry','SamplerPositiveDoc.as',
        '--output',str(out),'--expected','1','--registry-wait',str(args.registry_wait)]
    proof=dict(wrapper_sha256=sha(__file__),handoff_sha256=sha(HERE/'handoff.json'),original=str(ORIGINAL),
        original_sha256=ORIGINAL_SHA,adapted_source_sha256=hashlib.sha256(text.encode('utf-8')).hexdigest(),
        edits=[dict(old=OLD,new=NEW)],diagnostic_only=True,performance_qualified=False)
    try:
        scope=dict(__file__=str(ORIGINAL),__name__='paint_positive_frozen_component_runner')
        exec(compile(text,str(ORIGINAL),'exec'),scope);scope['main']()
        verify()
    finally:
        sys.argv=arguments
        if out.is_dir():
            proof['own_sources_unchanged']=all(sha(HERE/n)==h for n,h in pins['files'].items())
            (out/'positive-adaptation.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
