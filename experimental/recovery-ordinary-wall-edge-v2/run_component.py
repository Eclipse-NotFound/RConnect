"""Run the frozen v2 fixture via the original registry-backed runner. Root only."""
from pathlib import Path
import argparse,subprocess,sys
import prepare
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();prepare.verify()
 out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
 code=subprocess.call([sys.executable,'-B','-X','utf8',str(ROOT/'tools/validation/run_recovery_component.py'),
  '--source',str(HERE/'components'),'--entry','WallSurfaceChecks.as','--expected',str(prepare.EXPECTED),'--output',str(out)],cwd=ROOT)
 prepare.verify();return code
if __name__=='__main__':raise SystemExit(main())
