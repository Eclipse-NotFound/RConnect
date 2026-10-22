"""Retain the refused RV6593 run; new output admits the verified RV83 update only."""
from pathlib import Path
import hashlib,json,sys
import baseline
HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent/'recovery-paint-native-cpu/run.py'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    assert sha(SOURCE)=='ac8188dee173abe0e96aab609f050bebecf98a7434ab405c9059cb1a373f027e'
    own={p.name:sha(p) for p in sorted(HERE.glob('*.py'))}
    scope=dict(__file__=__file__,__name__='rv83_unchanged_cpu_outer')
    text=SOURCE.read_text(encoding='utf-8-sig')
    try:
        exec(compile(text,str(SOURCE),'exec'),scope);scope['main']()
    finally:
        unchanged=own=={p.name:sha(p) for p in sorted(HERE.glob('*.py'))}
        if '--output' in sys.argv:
            out=(HERE.parents[1]/sys.argv[sys.argv.index('--output')+1]).resolve()
            if out.parent==HERE.parents[1]/'build/m52' and out.is_dir():
                receipt=dict(source_unchanged=unchanged,own_sources=own,
                    previous_installed_rv='6593ee35008a898bd2d2b1189693a17bd0767c387697bcbee73a387f8fd6ec06',
                    admitted_installed_rv=baseline.RV_NEW,runtime_rv=baseline.RV_OLD,
                    source_runner_sha256=sha(SOURCE),diagnostic_only=True,performance_qualified=False)
                (out/'rv83-admission.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        assert unchanged,'New admission source changed during run'
if __name__=='__main__':main()

