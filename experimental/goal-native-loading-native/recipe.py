"""Exact textual adaptations of two frozen entries; no process execution."""
from pathlib import Path
import difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
ORDINARY=HERE.parent/'goal-ordinary-loading/run.py'
SHARED=ROOT/'tools/run_coop_regression.py'
ORDINARY_SHA='5613e8bca191116797bac42af1d7054cfe99516dd5a32d8f1b44168d896b3502'
SHARED_SHA='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
MARKER='NATIVE LOADING PROBE DONE '
RUNNER_EDITS=(
 ("    ap.add_argument('--seconds',type=int,default=115)",
  "    ap.add_argument('--seconds',type=int,default=115)\n    ap.add_argument('--done',default=None,help='Additional per-role completion prefix; original DONE still required')",1),
 ("                if args.effects: complete=complete and 'COOP EFFECTS DONE' in content",
  "                if args.effects: complete=complete and 'COOP EFFECTS DONE' in content and (args.done is None or args.done+role in content)",1))
ORDINARY_EDITS=(
 ('    ap.set_defaults(raster_host=None, sandy_bridge=False, diagnostic_driver=None)',
  '    ap.set_defaults(raster_host=str(UI_HOST), sandy_bridge=False, diagnostic_driver=None)',1),
 ('    from bridge_inputs import verify as verify_bridge','    verify_bridge = ui_bridge',1),
 ("               '--registry-wait', str(args.registry_wait)]",
  "               '--registry-wait', str(args.registry_wait), '--done', PROBE_DONE]",1),
 ("        assert native.all_mods and native.effects and native.solo == (args.mode == 'solo')",
  "        assert native.all_mods and native.effects and native.solo == (args.mode == 'solo')\n        assert not native.solo and native.seconds == 600 and native.done == PROBE_DONE",1),
 ('                    assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()',
  '                    assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()\n                    assert all(not (preference.parent/name).exists() for name in ("native-loading-observer.json", "native-loading-terminal.png"))',1),
 ('        def after_stopped():\n            try:\n                if settings:',
  '        def after_stopped():\n            try:\n                collect_observer(output, out, settings, roles)\n                if settings:',1),
 ("        memory = read(run_path/'memory-timeline.json')",
  "        assert {role: result['roles'][role]['checks'] for role in roles} == {'host': 23, 'join': 12}\n        validate_observer(out, run_path, roles, settings, result)\n        memory = read(run_path/'memory-timeline.json')",1))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def adapt(path,digest,edits):
    assert sha(path)==digest,path
    text=path.read_text('utf8')
    for old,new,count in edits:
        assert text.count(old)==count,old
        text=text.replace(old,new)
    return text
def runner_source():return adapt(SHARED,SHARED_SHA,RUNNER_EDITS)
def ordinary_source():return adapt(ORDINARY,ORDINARY_SHA,ORDINARY_EDITS)
def check():
    m=read(HERE/'source-manifest.json')
    assert m['kind']=='native-loading-observer-runtime-v1'
    for name,digest in m['files'].items():assert sha(HERE/name)==digest,name
    for name,digest in m['original'].items():assert sha(name)==digest,name
    assert (HERE/'adapted-runner.py.txt').read_text('utf8')==runner_source()
    assert (HERE/'adapted-ordinary.py.txt').read_text('utf8')==ordinary_source()
    assert m['shared_replacements']==len(RUNNER_EDITS)==2 and m['ordinary_replacements']==len(ORDINARY_EDITS)==7
    return m
def main():
    if sys.argv[1:]==['--check']:
        check();print('Static adapter verified; no AIR/JVM');return
    assert sys.argv[1:]==[]
    diff=''
    for name,path,digest,edits in [('adapted-runner.py.txt',SHARED,SHARED_SHA,RUNNER_EDITS),
                                  ('adapted-ordinary.py.txt',ORDINARY,ORDINARY_SHA,ORDINARY_EDITS)]:
        text=adapt(path,digest,edits)
        with (HERE/name).open('x',encoding='utf8',newline='\n') as f:f.write(text)
        diff+=''.join(difflib.unified_diff(path.read_text('utf8').splitlines(True),text.splitlines(True),
                     fromfile=str(path),tofile=name))
    with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
    paths=[ORDINARY,SHARED,HERE.parent/'goal-native-loading-probe/build.py',HERE.parent/'goal-native-loading-probe/source-manifest.json',
           HERE.parent/'goal-native-loading-build/build_product.py',HERE.parent/'goal-native-loading-build/build_host.py']
    m=dict(kind='native-loading-observer-runtime-v1',shared_replacements=len(RUNNER_EDITS),ordinary_replacements=len(ORDINARY_EDITS),
           files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.iterdir()) if p.is_file()},
           original={str(p):sha(p) for p in paths},air_started=False,installed=False)
    with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,indent=2);f.write('\n')
    check()
if __name__=='__main__':main()
