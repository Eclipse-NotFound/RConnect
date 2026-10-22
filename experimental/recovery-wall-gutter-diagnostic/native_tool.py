"""Reuse the exact existing wall runner; new external observations only.

Original framework/result and ordinary wall result are preserved. Diagnostic
completion never qualifies this driver, candidate or timing as production.
"""
import importlib.util
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
ORIGINAL=ROOT/'experimental/recovery-wall-surfaces-native/native_tool.py'
spec=importlib.util.spec_from_file_location('wall_native_original',ORIGINAL)
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
assert base.prepare.sha(ORIGINAL)=='3516f0a9a1daa1290391908b74d91ba9cad159bcd049ff5cdb6d2a461984cb5f'
base.HERE=HERE
old_tools=base.tools


def tools():
    result=old_tools()
    for name in ('native_tool.py','analyze_diagnostic.py','generate.py','actor-inputs.json'):
        path=HERE/name;result[str(path)]=base.prepare.sha(path)
    result[str(ORIGINAL)]=base.prepare.sha(ORIGINAL)
    return result


base.tools=tools


def main():
    mode=sys.argv[1];out=(ROOT/Path(sys.argv[sys.argv.index('--output')+1])).resolve()
    inputs=json.loads((HERE/'diagnostic-inputs.json').read_text(encoding='utf-8'))
    assert all(base.prepare.sha(Path(path))==digest for path,digest in inputs['inputs'].items()),'Diagnostic references changed'
    if mode=='run':
        candidate=(ROOT/Path(sys.argv[sys.argv.index('--candidate')+1])).resolve()
        assert candidate==ROOT/'build/m52/recovery-18','This diagnostic is pinned to actual recovery18'
        assert base.prepare.sha(candidate/'RConnectMod.swf')==inputs['candidate_sha256']
        host=(ROOT/Path(sys.argv[sys.argv.index('--game-candidate')+1])).resolve()
        assert host==base.WALL_HOST,'Explicit audited ACC host required'
    code=base.main()
    if mode=='prepare':
        meta=base.prepare.read(out/'prepared.json')
        meta['extension']['diagnostic_only']=True
        meta['extension']['gameplay_qualified']=meta['extension']['performance_qualified']=False
        base.prepare.save(out/'prepared.json',meta);return code
    framework=out/'result.json';prior=base.prepare.sha(framework)
    result=dict(diagnostic_only=True,diagnostic_checks_passed=False,gameplay_qualified=False,
        performance_qualified=False,original_wrapper_exit=code,framework_sha256=prior)
    try:
        import analyze_diagnostic
        result.update(analyze_diagnostic.analyze(out))
    except Exception as error:result['error']=repr(error)
    assert base.prepare.sha(framework)==prior,'Preserve original framework result bytes'
    result['original_wall_result_sha256']=base.prepare.sha(out/'wall-surface-result.json')
    base.prepare.save(out/'gutter-diagnostic-result.json',result)
    print(json.dumps({key:result[key] for key in ('diagnostic_only','diagnostic_checks_passed','gameplay_qualified','performance_qualified')}))
    return 0 if result['diagnostic_checks_passed'] else 1


if __name__=='__main__':raise SystemExit(main())
