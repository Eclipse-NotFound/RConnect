"""Rebind the proven only-RC single compiler; all process and memory code reused."""
from pathlib import Path
import hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.parent/'goal-rconnect-only-loading/build.py'
OLD_SHA='09edaf5a150364157a92129f57850283df1040cb6efebc1c906cebeae79c3755'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p,n):
    s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
assert sha(OLD)==OLD_SHA
parent=load(OLD,'nativeui2_loading_single_build');base=parent.base
parent.HERE=HERE;parent.source=load(HERE/'prepare.py','nativeui2_loading_source')
base.SOURCE=HERE;base.KIND='native-ui-jump-loading-driver-v1'
def inputs():
    assert sha(OLD)==OLD_SHA
    pins,proof,sources=parent.inputs()
    pins.update(proof['derived_driver_inputs']);pins[str(Path(__file__).resolve())]=sha(__file__)
    return pins,proof,sources
def output_path(p):
    out=(ROOT/p).resolve();assert out.parent==M52 and out.name.startswith('goal-native-ui-jump-loading-driver-');return out
base.inputs=inputs;base.output_path=output_path
def verify(output):return base.verify(output)
def main():
    if '--build' in sys.argv and '--output' not in sys.argv:sys.argv+=['--output',str(M52/'goal-native-ui-jump-loading-driver-01')]
    return base.main()
if __name__=='__main__':
    try:main()
    except (FileNotFoundError,base.NotReady) as e:
        print(json.dumps(dict(ready=False,status='not-ready',error=str(e))));raise SystemExit(2)
