"""Reuse the exact outer tail diagnostic; new runner only reads owned process CPU."""
from pathlib import Path
import argparse,hashlib,json,sys
HERE=Path(__file__).resolve().parent;TAIL=HERE.parent/'recovery-early-paint-tail-native'
sys.path.insert(0,str(TAIL));sys.path.insert(0,str(HERE))
def main():
    parser=argparse.ArgumentParser(add_help=False);parser.add_argument('--output')
    options,_=parser.parse_known_args()
    root=HERE.parents[1]
    output=(root/options.output).resolve() if options.output else None
    writable=output is not None and output.parent==root/'build/m52' and not output.exists()
    try:
        source=TAIL/'run_native.py'
        assert hashlib.sha256(source.read_bytes()).hexdigest()=='b7dc05f1e10cd388bcec328a161461abaa7c2b6c8c154c0e2fd90bf9b51bfb8b'
        text=source.read_text(encoding='utf-8-sig')
        old='        from runtime_adapter import outer_source'
        assert text.count(old)==1
        text=text.replace(old,old+',verify_inputs\n        verify_inputs()',1)
        scope=dict(__file__=__file__,__name__='native_cpu_unchanged_outer_tail')
        exec(compile(text,str(source),'exec'),scope);scope['main']()
    except BaseException as error:
        if isinstance(error,SystemExit) and error.code in (None,0):raise
        if writable:
            output.mkdir(exist_ok=True)
            receipt=dict(passed=False,error_type=type(error).__name__,error=str(error),
                diagnostic_only=True,performance_qualified=False,
                note='Source admission or inherited run failure; preserved original evidence determines whether AIR began')
            for name in ('error.json','result.json'):
                if not (output/name).exists():(output/name).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        raise
if __name__=='__main__':main()
