"""Root entry; exact source/runtime freeze and exclusive known sampler required."""
from pathlib import Path
import argparse,json,sys
def main():
    parser=argparse.ArgumentParser(add_help=False);parser.add_argument('--output')
    options,_=parser.parse_known_args()
    root=Path(__file__).resolve().parents[2]
    output=(root/options.output).resolve() if options.output else None
    writable=output is not None and output.parent==root/'build/m52' and not output.exists()
    try:
        from native_inputs import verify_tools,paint_audit_log
        from runtime_adapter import outer_source
        verify_tools()
        scope=dict(__file__=__file__,__name__='tail_early_native_adapter',paint_audit_log=paint_audit_log)
        exec(compile(outer_source(),__file__,'exec'),scope);scope['main']()
    except BaseException as error:
        if isinstance(error,SystemExit) and error.code in (None,0):raise
        if writable:
            output.mkdir(exist_ok=True)
            receipt=dict(passed=False,error_type=type(error).__name__,error=str(error),
                diagnostic_only=True,performance_qualified=False,
                note='Original result/logs retained; inspect runner output for whether AIR began')
            (output/'error.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
            if not (output/'result.json').exists():
                (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        raise
if __name__=='__main__':main()
