"""Exact old ordinary-room runner, new driver verification, separate CPU receipt."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, sys, traceback
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
import build
from analyze import cpu_summary
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
SOURCE=HERE.parent/'goal-three-issues-native/run.py'
SOURCE_SHA='2dc340ab793e95fec7abab6d3061a789255d6b0afe861036b96ee654ac36ed12'
assert build.sha(SOURCE)==SOURCE_SHA
ns={'__file__':str(SOURCE),'__name__':'goal_cpu_original_native_runner'}
exec(compile(SOURCE.read_text('utf8'),str(SOURCE),'exec'),ns)
ns['CASES']={'native-jump':ns['CASES']['native-jump']}
_product=ns['product']
def baseline_product(path):
    assert Path(path).resolve()==build.PRODUCT,'This diagnostic binds only actual 78C baseline'
    return _product(path)
ns['product']=baseline_product

def main():
    # The original parser, checks, run_registered wrapper and shared runner still run.
    peek=argparse.ArgumentParser(add_help=False)
    peek.add_argument('--output',type=Path);peek.add_argument('--check',action='store_true')
    a,_=peek.parse_known_args()
    exit_code=ns['main']()
    if a.check:return exit_code
    assert a.output is not None
    out=(ROOT/a.output).resolve()
    assert out.parent==ROOT/'build/m52'
    report=dict(kind='ordinary-native-jump-cpu-qualification-v1',passed=False,roles={},
      original_functional_passed=False,diagnostic_complete=False,performanceQualified=False,smoothnessQualified=False)
    try:
        original=build.read(out/'result.json')
        report.update(original_result_sha256=build.sha(out/'result.json'),
          original_functional_passed=original['passed'] is True,original_exit_code=exit_code)
        settings=build.read(out/'supplemental-input.json')['roles']
        run=Path(original['run']);assert run.parent==ROOT/'build/cooperation'
        for role in ('host','join'):
            appid='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
            assert settings[role]['app_id']==appid
            storage=Path(os.environ['APPDATA']).resolve()/appid/'Local Store'
            raw=storage/'native-jump-cpu.json'
            assert raw.is_file() and 0<raw.stat().st_size<=8*1024*1024
            dest=out/(role+'-cpu-raw.json')
            with dest.open('xb') as f:f.write(raw.read_bytes())
            data=build.read(dest)
            motion=build.read(out/(role+'-measurements.json'))
            assert len(motion)==1 and len(data['profiles'])==1
            profile=data['profiles'][0]
            assert profile['measurementStartedAt']==motion[0]['startedAt']
            assert profile['measurementEndedAt']<=motion[0]['endedAt']
            summary=cpu_summary(data,role,appid)
            build.save(out/(role+'-cpu-summary.json'),summary)
            report['roles'][role]=dict(raw_sha256=build.sha(dest),
              summary_sha256=build.sha(out/(role+'-cpu-summary.json')),cpu_samples=summary['cpu_samples'],
              diagnostic_complete=True,application_id=appid)
        assert original['passed'] is True and exit_code==0,'Original native assertions or cleanup failed'
        build.inputs()
        report.update(passed=True,diagnostic_complete=True)
    except BaseException as error:
        report.update(error=repr(error),traceback=traceback.format_exc())
    build.save(out/'cpu-result.json',report)
    print(json.dumps({k:report.get(k) for k in ('passed','original_functional_passed','diagnostic_complete','error')}))
    return 0 if report['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
