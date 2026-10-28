"""Keep the sustained workload/gates unchanged; use exact installed field5 as baseline."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'experimental/b-field-sustained-bench/qualify.py'
spec = importlib.util.spec_from_file_location('field8_sustained_qualification', BASE)
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
q.PINNED['baseline'] = {
    'build': 'build/ab/b190-scalar04-build',
    'candidate_sha256': 'f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07',
    'native': 'build/ab/native-hooks-021/pfe.swf',
    'native_sha256': 'eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063',
}
original_freeze = q.freeze


def freeze(candidate):
    plan = original_freeze(candidate)
    for source in (Path(__file__).resolve(), BASE):
        plan['artifacts'][q.rel(source)] = q.sha(source)
    return plan


q.freeze = freeze
if __name__ == '__main__':
    raise SystemExit(q.main())
