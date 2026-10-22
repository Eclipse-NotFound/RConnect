"""Unchanged lifecycle launch/cleanup with exact nonzero-cooldown result checks."""
from pathlib import Path
import json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def adapted_source():
    from native_inputs import OLD,sha,once
    source=OLD/'run.py'
    assert sha(source)=='73204601e09ccf070cc39544479837a8b1495463c82f739f010aa895a879003c'
    text=source.read_text(encoding='utf-8-sig')
    for old,new in (
        ('CANDIDATE,HOST\n','CANDIDATE,HOST,frozen_vision,audit_row,config_bytes,CONFIG,baseline\n'),
        ("'--sandy-candidate',sand['candidate'],'--all-mods'","'--sandy-candidate',sand['candidate'],'--vision-candidate',str(frozen_vision()),'--all-mods'"),
        ("row['checks']==41","row['checks']==43"),
        ("valid=valid and row['functionOnly'] is True and row['performanceQualified'] is False",
         "valid=valid and row['functionOnly'] is True and row['performanceQualified'] is False\n            valid=valid and audit_row(row)"),
        ("assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']",
         "assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']\n"
         "        assert modules['mods/realisticvision/release/realisticvisionmod.swf']==baseline.RV_OLD\n"
         "        copied=run/'configuration/host/mods/Sandevistan/release/config.txt'\n"
         "        assert copied.read_bytes()==config_bytes(CONFIG.read_bytes())\n"
         "        assert read(run/'installation-gate.json')['passed'] is True"),
        ("if __name__=='__main__':main()",'')):
        text=once(text,old,new)
    return text
def main():
    # A source/admission rejection must retain an honest result in a new output.
    import argparse
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True)
    a,_=ap.parse_known_args();out=(ROOT/a.output).resolve()
    assert out.parent==(ROOT/'build/m52').resolve() and not out.exists()
    try:
        scope=dict(__file__=__file__,__name__='cooldown_lifecycle_outer')
        exec(compile(adapted_source(),str(HERE/'run.py'),'exec'),scope)
        scope['main']()
    except BaseException as e:
        if isinstance(e,SystemExit) and e.code in (None,0):return
        out.mkdir(exist_ok=True)
        failure=dict(passed=False,error_type=type(e).__name__,error=str(e),function_only=True,performance_qualified=False)
        (out/'error.json').write_text(json.dumps(failure,indent=2)+'\n',encoding='utf-8')
        if not (out/'result.json').exists():(out/'result.json').write_text(json.dumps(failure,indent=2)+'\n',encoding='utf-8')
        raise
if __name__=='__main__':main()
