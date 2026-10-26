"""Diagnostic-only UI clock observer. Original runner, timeout and assertions unchanged."""
import argparse
import shutil
from pathlib import Path
import run as original

def main():
    ap=argparse.ArgumentParser()
    for key in ('workspace','preparation','candidate','native','result'):ap.add_argument('--'+key,required=True)
    args=ap.parse_args();result=original.inside_build(original.ROOT/args.result)
    save=original.save
    def observed_save(path,value):
        if Path(path).name=='startup-test.json':
            if value['scenario']!='ui':raise ValueError('UI only')
            value['clockTrace']=True
        if Path(path)==result/'result.json':
            value['diagnostic_only']=True
            value['ui_observer_wrapper_sha256']=original.sha(__file__)
        save(path,value)
    original.save=observed_save
    try:
        return original.run(original.inside_build(original.ROOT/args.workspace),'ui',original.ROOT/args.candidate,
                            result,args.preparation,original.ROOT/args.native)
    finally:
        original.save=save
        if result.exists():shutil.copy2(__file__,result/'ui-observer-runner.py')

if __name__=='__main__':raise SystemExit(main())
