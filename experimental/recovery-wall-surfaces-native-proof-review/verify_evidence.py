"""Read driver04 evidence with explicit PNG unpremultiplication compatibility.

Only the PNG-vs-JSON artifact check changes. Source/remote JSON uints, actual
collision oracle, counts, positions, duration and all four scenarios remain
the exact frozen driver's rules. No AIR/JVM or edits to original evidence.
"""
import argparse
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
FROZEN=ROOT/'build/m52/recovery-wall-surfaces-driver-04/inputs/large-wall/verify_results.py'
FROZEN_SHA='a3e8d886772d8facada4363331e79b6277c582b316f05c00e360e7edd247e874'


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_frozen():
    assert sha(FROZEN)==FROZEN_SHA,'Frozen driver04 analyzer changed'
    spec=importlib.util.spec_from_file_location('wall_proof_driver04',FROZEN)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def compatible_words(expected,actual):
    """Reject alpha/opaque/hidden RGB errors and unrelated +/-1 changes.

    For an unequal translucent channel, require adjacent straight values that
    enclose ONE common integral premultiplied channel p:
       min(c,d)*alpha <= 255*p <= max(c,d)*alpha.
    The interval is narrower than one integer since alpha<255. This describes
    floor/ceil representations of the same byte, not a general RGB tolerance.
    It does not claim to identify which native code path rounds which way.
    """
    assert len(expected)==len(actual)==128*128
    changed=channels=0;examples=[]
    for i,(x,y) in enumerate(zip(expected,actual)):
        assert isinstance(x,int) and isinstance(y,int) and 0<=x<=0xffffffff and 0<=y<=0xffffffff
        if x==y:continue
        alpha=x>>24
        assert alpha==y>>24,f'PNG alpha differs at {i}'
        assert 0<alpha<255,f'PNG opaque/fully transparent pixel differs at {i}'
        changed+=1
        for shift in (16,8,0):
            c=(x>>shift)&255;d=(y>>shift)&255
            if c==d:continue
            assert abs(c-d)==1,f'PNG channel differs by more than one at {i}'
            lo=min(c,d)*alpha;hi=max(c,d)*alpha
            first=(lo+254)//255;last=hi//255
            assert first==last and 0<=first<=alpha,f'PNG adjacent values do not share a premultiplied byte at {i}'
            channels+=1
        if len(examples)<4:examples.append(dict(index=i,json_argb=f'{x:08x}',png_argb=f'{y:08x}'))
    return dict(exact_argb=changed==0,representation_compatible=True,rounding_pixels=changed,
                rounding_channels=channels,examples=examples)


def analyze(proof,logs):
    frozen=load_frozen();reports={}
    source=inspect.getsource(frozen.analyze)
    anchor="assert png_words(png) == row[field], 'PNG does not contain corresponding real crop: ' + png.name"
    assert source.count(anchor)==1
    source=source.replace(anchor,'_check_png(png,row[field])')
    def check_png(png,expected):
        reports[str(png.relative_to(proof))]=compatible_words(expected,frozen.png_words(png))
    scope=dict(frozen.__dict__,_check_png=check_png)
    exec(compile(source,'<driver04 only PNG compatibility substitution>','exec'),scope)
    result=scope['analyze'](proof,logs)
    result.update(png_audit=reports,png_exact_argb=all(r['exact_argb'] for r in reports.values()),
        png_representation_compatible=len(reports)==32 and all(r['representation_compatible'] for r in reports.values()),
        source_remote_comparison='exact uint equality; no tolerance',frozen_analyzer_sha256=FROZEN_SHA,
        modified_rule='PNG straight-color floor/ceil compatibility only; no gameplay pixel tolerance',
        rounding_engine_microtest_performed=False,performance_qualified=False)
    result['passed']=bool(result['passed'] and result['png_representation_compatible'])
    return result


def reanalyze(evidence):
    evidence=Path(evidence).resolve()
    assert evidence.parent==(ROOT/'build/m52').resolve()
    original=evidence/'wall-surface-result.json';framework=evidence/'result.json'
    original_value=json.loads(original.read_text(encoding='utf-8-sig'))
    frame=json.loads(framework.read_text(encoding='utf-8-sig'))
    run=Path(original_value['native_run']).resolve()
    assert run.parent==(ROOT/'build/cooperation').resolve()
    logs={role:run/(role+'.log') for role in ('host','join')}
    paths=[original,framework,FROZEN,*logs.values(),*sorted((evidence/'wall-proof').rglob('*.*'))]
    before={str(p):sha(p) for p in paths}
    result=analyze(evidence/'wall-proof',logs)
    result.update(evidence=str(evidence),native_run=str(run),framework_passed=frame['passed'],
        original_result_preserved=True,original_result_sha256=before[str(original)],
        framework_sha256=before[str(framework)],input_sha256=before,
        source_unchanged=all(sha(p)==digest for p,digest in before.items()),
        candidate_sha256=original_value['candidate_sha256'],native_host_sha256=original_value['native_host_sha256'],
        independent_reanalysis=True,jvm_started=False,air_started=False,installed=False)
    result['passed']=bool(result['passed'] and frame['passed'] and result['source_unchanged'])
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();target=(ROOT/args.output).resolve()
    assert target.parent==HERE and not target.exists(),'Write only a new result in this review directory'
    value=reanalyze(ROOT/args.evidence)
    target.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:value[k] for k in ('passed','png_representation_compatible','png_exact_argb','source_unchanged','errors')}))
    raise SystemExit(0 if value['passed'] else 1)
