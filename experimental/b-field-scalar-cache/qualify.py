"""Reuse unchanged sustained workload/gates, with installed field22 as the exact baseline."""
from pathlib import Path
import importlib.util

ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'experimental/b-field-sustained-bench/qualify.py'
spec=importlib.util.spec_from_file_location('sustained_qualification',base)
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.PINNED['baseline']={
 'build':'build/ab/b190-field22-build',
 'candidate_sha256':'3706828fd10cf30c133826d17fd8cef939444f790a33a70d58c2a2b0779c90bf',
 'native':'build/ab/native-hooks-021/pfe.swf',
 'native_sha256':'eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063',
}
original_freeze=q.freeze
def freeze(candidate):
 plan=original_freeze(candidate)
 for path in (Path(__file__).resolve(),base):plan['artifacts'][q.rel(path)]=q.sha(path)
 return plan
q.freeze=freeze
if __name__=='__main__':raise SystemExit(q.main())
