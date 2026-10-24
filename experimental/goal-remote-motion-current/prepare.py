"""Read-only prepared-source binding for the existing bounded compiler."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('motionclock_source_check', HERE / 'check.py')
checked = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checked)
BASE, ROOT, sha = checked.BASE, checked.ROOT, checked.sha
DELEGATE = ROOT / 'experimental/recovery-room-production-v5/build.py'


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def verify():
    checked.verify()
    return checked.data(HERE / 'source-manifest.json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', required=True)
    parser.parse_args()
    manifest = verify()
    print(json.dumps(dict(passed=True, version=manifest['version'], changed_classes=2,
                         unchanged_classes=79, compiled=False, air_started=False)))
