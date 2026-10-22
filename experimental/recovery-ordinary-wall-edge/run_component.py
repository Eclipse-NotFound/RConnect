"""Thin entry to the existing registered AIR component runner; root invokes it."""
from pathlib import Path
import argparse,subprocess,sys
import prepare
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);args=p.parse_args()
 prepare.verify()
 output=(ROOT/args.output).resolve()
 assert output.parent==ROOT/'build/m52' and not output.exists()
 code=subprocess.call([sys.executable,'-B','-X','utf8',str(ROOT/'tools/validation/run_recovery_component.py'),
  '--source',str(HERE/'components'),'--entry','WallSurfaceChecks.as','--expected',str(prepare.EXPECTED),'--output',str(output)],cwd=ROOT)
 prepare.verify()
 return code
if __name__=='__main__':raise SystemExit(main())
