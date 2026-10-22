"""Thin ordinary-room binding over the existing audited large-wall runner.
Keep the existing native entry/log names so all established DONE/error gates apply.
Only the fixture, candidate baseline, kind/purpose and exact ACC default change.
"""
from pathlib import Path
import importlib.util, inspect, sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'experimental/recovery-wall-surfaces-native/native_tool.py'
PIN='3516f0a9a1daa1290391908b74d91ba9cad159bcd049ff5cdb6d2a461984cb5f'
spec=importlib.util.spec_from_file_location('ordinary_existing_wall_runner',BASE)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
assert shared.prepare.sha(BASE)==PIN
shared.HERE=HERE
shared.BASE14_SHA='746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93'
shared.prepare.ENTRIES[shared.ENTRY]=(4,600,'普通房真实原生墙痕：双向轻机枪/速射等离子、持久前景精确像素')
prior_tools=shared.tools
def tools():
 value=prior_tools()
 for p in (Path(__file__),HERE/'prepare_sources.py',HERE/'check_offline.py',
           ROOT/'experimental/recovery-wall-surfaces-native-proof-review/verify_evidence.py',
           ROOT/'build/m52/recovery-wall-surfaces-driver-04/inputs/large-wall/verify_results.py'):
  value[str(p)]=shared.prepare.sha(p)
 return value
shared.tools=tools

def adapted_main():
 source=inspect.getsource(shared.main)
 edits=[
  ("default=HOST_DIR,help='Exact audited host directory; default FD92, explicit wall host ACC only'",
   "default=WALL_HOST,help='Only the exact independently audited ACC host directory is accepted'",1),
  ("ROOT/'build/m52/recovery-14/src'", "ROOT/'build/m52/recovery-22/src'",1),
  ("'large-native-wall-surfaces'", "'ordinary-native-wall-surfaces'",3),
  ("assert drivers.parent==candidate.parent==(ROOT/'build/m52').resolve()",
   "assert drivers.parent==candidate.parent==(ROOT/'build/m52').resolve()\n    assert candidate==(ROOT/'build/m52/recovery-22').resolve() and prepare.sha(candidate/'RConnectMod.swf')==BASE14_SHA",1),
  ("host_dir=(ROOT/args.game_candidate).resolve();native_host=host_evidence(host_dir)",
   "host_dir=(ROOT/args.game_candidate).resolve()\n    assert host_dir==WALL_HOST.resolve(), 'This fixture requires the exact ACC host'\n    native_host=host_evidence(host_dir)",1),
 ]
 for before,after,count in edits:
  assert source.count(before)==count,before
  source=source.replace(before,after)
 env=dict(shared.__dict__)
 exec(compile(source,'<ordinary wall exact bindings>','exec'),env)
 return env['main'],source

if __name__=='__main__':raise SystemExit(adapted_main()[0]())
