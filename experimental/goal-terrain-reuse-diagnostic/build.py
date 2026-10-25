"""Exact diagnostic binding; the v5 bounded compiler is otherwise unchanged."""
from pathlib import Path
import importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
def load(p,n):
 s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def verify(output):
 p=load(HERE/'prepare.py','terrain_diagnostic_verify');manifest=p.verify();out=Path(output).resolve()
 assert out.parent==p.ROOT/'build/m52'
 meta,receipt=[p.read(out/n) for n in ('prepared.json','compile.json')]
 assert meta['kind']=='terrain-reuse-diagnostic-overlay' and meta['diagnostic_only'] is True
 assert meta['performance_qualified'] is False and receipt['diagnostic_only'] is True and receipt['performance_qualified'] is False
 assert meta['base_sha256']==p.BASE_SHA and meta['version']==p.VERSION
 assert meta['overlay_manifest_sha256']==p.sha(HERE/'source-manifest.json')
 assert meta['recipe_sha256']==p.sha(HERE/'bounded-build.py.txt')
 assert meta['source']==manifest['candidate_source']==p.inventory(out/'src')
 assert meta['inputs']==p.read(p.BASE/'prepared.json')['inputs']==p.inventory(out/'tools')
 assert all(receipt[k] is True for k in ('compiled','installation_unchanged','sources_unchanged'))
 assert receipt['air_started'] is False and receipt['installed'] is False
 assert len(receipt['commands'])==2 and all(c['exit_code']==0 and type(c['pid']) is int for c in receipt['commands'])
 assert meta['installation_before']==receipt['installation_before']==receipt['installation_after']
 assert len(meta['installation_before'])==22 and meta['installation_before']['mods/Rconnect/release/RConnectMod.swf']==p.INSTALLED_SHA
 assert p.sha(out/'RConnectMod.swf')==receipt['candidate_sha256']!=p.BASE_SHA
 return dict(receipt,diagnostic_only=True,performance_qualified=False)
def main():
 p=load(HERE/'prepare.py','terrain_diagnostic_prepare');manifest=p.verify()
 absent=object();prior=sys.modules.get('prepare',absent);argv,path=sys.argv[:],sys.path[:]
 try:
  sys.modules['prepare']=p
  bounded=types.ModuleType('terrain_diagnostic_bounded');bounded.__file__=str(HERE/'bounded-build.py.txt')
  exec(compile((HERE/'bounded-build.py.txt').read_text('utf8'),bounded.__file__,'exec'),bounded.__dict__)
  assert bounded.BASE==p.BASE and bounded.HERE==HERE and bounded.sha is p.sha
  current=bounded.installation();assert len(current)==22 and current['mods/Rconnect/release/RConnectMod.swf']==p.INSTALLED_SHA
  if sys.argv[1:]==['--check']:
   print(json.dumps(dict(checked=True,DIAGNOSTIC_ONLY=True,current_inputs=22,source_base_sha256=p.BASE_SHA,
    installed_base_sha256=p.INSTALLED_SHA,compiled=False,air_started=False,performance_qualified=False)))
  else:bounded.main()
 finally:
  sys.argv,sys.path[:]=argv,path
  if prior is absent:sys.modules.pop('prepare',None)
  else:sys.modules['prepare']=prior
  p.verify()
if __name__=='__main__':main()
