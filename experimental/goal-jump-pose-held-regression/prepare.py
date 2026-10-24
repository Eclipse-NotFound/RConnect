"""Freeze this thin binding only; never compile or start AIR."""
from pathlib import Path
import ast,difflib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('jumppose_held_text_prepare',HERE/'run.py')
entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
def main():
 assert sys.argv[1:]==[]
 original=entry.legacy();before=original.expanded_run();after=entry.expanded_run(original);ast.parse(after)
 sources={'adapted-run.py.txt':after,'source.diff':''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
   fromfile='selfecho/adapted-run.py.txt',tofile='jumppose-held/adapted-run.py.txt'))}
 for n,text in sources.items():
  with (HERE/n).open('x',encoding='utf8',newline='\n') as f:f.write(text)
 manifest=dict(kind='jump-pose-held-existing-driver-v1',run_replacements=1,
  files={p.name:entry.sha(p) for p in sorted(HERE.iterdir()) if p.is_file()},
  inputs={str(p):h for p,h in entry.PINS.items()},candidate_build=entry.COMPILED_PINS,
  compiled=False,air_started=False,performanceQualified=False,smoothnessQualified=False)
 with (HERE/'source-manifest.json').open('x',encoding='utf8',newline='\n') as f:json.dump(manifest,f,indent=2);f.write('\n')
 entry.inputs(original);print('Frozen text binding; no new driver, JVM or AIR')
if __name__=='__main__':main()
