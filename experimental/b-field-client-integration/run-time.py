"""Run the existing native time-control probe through an isolated field driver.
Does not edit the frozen performance runner or any production candidate.
"""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/host_authority/field2_driver'))
from run import run,inside_build,read
ap=argparse.ArgumentParser();ap.add_argument('--preparation',required=True);ap.add_argument('--result',required=True);a=ap.parse_args()
out=inside_build(ROOT/a.result)
run(ROOT/'build/ab/b-field2-runtime-01','timecontrol',ROOT/'build/ab/b-clientenv-bridge-07-build/RConnectMod.swf',out,a.preparation,
    ROOT/'experimental/b-field-env-refresh/overlay-03/pfe.swf')
sys.exit(0 if read(out/'result.json').get('passed') else 1)
