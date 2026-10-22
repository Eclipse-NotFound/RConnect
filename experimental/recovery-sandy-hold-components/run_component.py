"""Thin root-only adapter to the existing shared-registry component runner."""
from pathlib import Path
import argparse, subprocess, sys
import prepare
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
 prepare.verify()
 out=(ROOT/a.output).resolve()
 assert out.parent==ROOT/'build/m52' and not out.exists()
 try:
  return subprocess.call([sys.executable,'-B','-X','utf8',str(ROOT/'tools/validation/run_recovery_component.py'),
   '--source',str(HERE/'components'),'--entry','SandyTravelHoldChecks.as',
   '--expected',str(prepare.EXPECTED),'--output',str(out)],cwd=ROOT)
 finally:prepare.verify()

if __name__=='__main__':raise SystemExit(main())
