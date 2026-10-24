"""Write only this directory's text expansion, exact diff and input pins."""
from pathlib import Path
import ast,difflib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('hidden_only_prepare_entry',HERE/'run.py')
entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
def main():
    assert sys.argv[1:]==[]
    text=entry.adapted();ast.parse(text)
    for p in HERE.glob('*.py'):ast.parse(p.read_text('utf8'))
    with (HERE/'adapted-hidden.py.txt').open('x',encoding='utf8',newline='\n') as f:f.write(text)
    diff=''.join(difflib.unified_diff(entry.SOURCE.read_text('utf8').splitlines(True),text.splitlines(True),
        fromfile='original/run_hidden_v3.py',tofile='native-ui/hidden-only.py'))
    with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
    # Admission belongs to the actual bundle, not source-only readiness. Its
    # exact digest is fixed in run.py and bundle() puts the real file in pins.
    paths=[entry.SOURCE,entry.UI/'run.py',entry.UI/'source-manifest.json',entry.SHARED]
    assert entry.sha(entry.ADMISSION)==entry.ADMISSION_SHA
    m=dict(kind='native-loading-hidden-only-v1',adaptations=7,
        files={p.name:entry.sha(p) for p in sorted(HERE.iterdir()) if p.is_file()},
        inputs={str(p):entry.sha(p) for p in paths},compiled=False,air_started=False)
    with (HERE/'source-manifest.json').open('x',encoding='utf8',newline='\n') as f:json.dump(m,f,indent=2);f.write('\n')
    entry.source_inputs();print('Source binding prepared; no JVM/AIR or runtime writes')
if __name__=='__main__':main()
