"""Repair only the component control class name, never production source."""
from pathlib import Path
import argparse, difflib, hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
ORIGINAL=ROOT/'experimental/recovery-pause-flush/components'
BASE=ROOT/'build/m52/recovery-22/src/rconnect/core/CoopPause.as'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--materialize',action='store_true');args=ap.parse_args()
    raw=BASE.read_bytes()
    assert sha(BASE)=='dd3428e87665d53dde470e36dadb37389f9819f5a00b48a9add154f1505662f9'
    replacements=[(b'public class CoopPause',b'public class ControlCoopPause'),
                  (b'public function CoopPause(s:Session)',b'public function ControlCoopPause(s:Session)')]
    fixed=raw
    for before,after in replacements:
        assert fixed.count(before)==1
        fixed=fixed.replace(before,after)
    restored=fixed
    for before,after in reversed(replacements):restored=restored.replace(after,before)
    assert restored==raw
    assert b'game.setCoopPaused(value)' in fixed and b'setControlCoopPaused' not in fixed
    files={p.relative_to(ORIGINAL).as_posix():p.read_bytes() for p in ORIGINAL.rglob('*.as')}
    files['rconnect/core/ControlCoopPause.as']=fixed
    for name,data in files.items():
        target=HERE/'components'/name
        if args.materialize:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        assert target.read_bytes()==data,name
    previous=(ORIGINAL/'rconnect/core/ControlCoopPause.as').read_text('utf-8')
    delta=''.join(difflib.unified_diff(previous.splitlines(True),fixed.decode('utf-8').splitlines(True),
        fromfile='component01/ControlCoopPause.as',tofile='component-v2/ControlCoopPause.as'))
    if args.materialize:(HERE/'component-fix.patch').write_text(delta,encoding='utf-8')
    assert (HERE/'component-fix.patch').read_text('utf-8')==delta
    unchanged=[name for name,data in files.items() if data==(ORIGINAL/name).read_bytes()]
    assert len(unchanged)==len(files)-1
    assert (HERE/'components/PauseFlushChecks.as').read_bytes()==(ORIGINAL/'PauseFlushChecks.as').read_bytes()
    manifest={'base_sha256':sha(BASE),'source_components':str(ORIGINAL),
        'originals':{p.relative_to(ORIGINAL).as_posix():sha(p) for p in ORIGINAL.rglob('*.as')},
        'component_count':len(files),'unchanged_components':len(unchanged),'expected_assertions':50,
        'compiled':False,'air_started':False,'production_modified':False,
        'control_restores_exact_recovery22':True,
        'files':{p.relative_to(HERE).as_posix():sha(p) for p in HERE.rglob('*') if p.is_file() and p.name!='inputs.json'}}
    (HERE/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ['component_count','unchanged_components','expected_assertions','control_restores_exact_recovery22','compiled','air_started']}))
if __name__=='__main__':main()
