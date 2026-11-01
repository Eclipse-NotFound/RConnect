"""Read-only ABAB evaluation. Reuses the unchanged sustained workload and gates."""
from pathlib import Path
import argparse, importlib.util, json, sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
def load(name,p):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
q=load('unchanged_sustained_checks',ROOT/'experimental/b-field-sustained-bench/qualify.py')
d=load('readonly_package_checks',ROOT/'experimental/b-field8-validation/transaction.py')

def evaluate(series):
 series=d.path(series);p=d.read(series);require=d.require
 require(p['kind']=='b-sustained-same-environment-comparison' and p.get('passed') and p['order']=='ABAB','Complete ABAB series required')
 require(p['seconds']==60 and p['profile'] is False,'Clean 60 second phases required')
 prepared_path=d.path(p['preparation']);prepared=d.read(prepared_path)
 require(d.sha(prepared_path)==p['preparation_sha256'],'Preparation changed')
 require(prepared['full_environment_sha256']==p['environment_sha256'],'Wrong environment')
 driver=d.read(d.path(prepared['driver'])/'build-input.json')
 d.verify(d.path(prepared['driver']),driver['sources']);d.verify(d.path(prepared['driver']),driver['files'])
 pins={d.rel(series):d.sha(series),d.rel(prepared_path):d.sha(prepared_path)}
 for name,h in p['tools'].items():require(d.sha(name)==h,'Benchmark tool changed: '+name)
 builds={label:d.build_info(choice['path'],pins) for label,choice in p['choices'].items()}
 for label,b in builds.items():require(b['candidate_sha256']==p['choices'][label]['sha256'] and b['source_id']==p['choices'][label]['source'],'Build identity mismatch')
 # Exact installed B baseline; only the reviewed display/capture changes.
 a=d.read(d.path(p['choices']['A']['path'])/'build-input.json')['sources']
 b=d.read(d.path(p['choices']['B']['path'])/'build-input.json')['sources']
 changes={k for k in set(a)|set(b) if a.get(k)!=b.get(k)}
 require(changes=={'src/authority/BuildInfo.as','src/authority/FrameDelta.as','src/authority/PoseTween.as','src/authority/ReplicaScene.as','src/authority/SceneSnapshot.as','src/authority/ui/HudModel.as','src/authority/ui/NetHud.as','src/authority/NativeFields.as','src/RConnectMod.as'},'Comparison contains unrelated code changes')
 require(builds['A']['candidate_sha256']=='a382e94f66fa22e008c1a056871a6634bdf4915e1e84a9b2b9a3de0347818386' and builds['B']['version']=='B3-0.1-entry1','Wrong installed baseline or candidate version')
 runs=[];ids=set();previous_end=None;scenes={}
 for ordinal,row in enumerate(p['results']):
  require(row['label']=='ABAB'[ordinal] and row['passed'],'Wrong comparison order')
  folder=d.path(row['path']);r=d.read(folder/'result.json');label=row['label'];build=builds[label]
  require(r.get('complete') and r.get('passed') and not r.get('error') and not r.get('diagnostic_only'),'Failed/incomplete run')
  require(r['seconds']==60 and r['profile'] is False and r['private_desktop'] is True,'Measurement settings changed')
  require(r['environment_sha256']==p['environment_sha256'] and r['preparation_sha256']==p['preparation_sha256'],'Environment differs')
  require(r['native_sha256']==p['native_sha256'] and r['candidate_sha256']==build['candidate_sha256'] and r['candidate_source']==build['source_id'],'Binary tuple differs')
  require(r['tool_sha256']==p['tools'] and d.sha(folder/'runner.py')==p['tools'][str(ROOT/'experimental/b-field-client-integration/bench-environment.py')],'Runner differs')
  require(r['driver_sha256']==prepared['driver_sha256'] and r['driver_source']==driver['source_id'],'Workload driver differs')
  machine=d.read(folder/'machine.json');require(machine,'Missing machine samples')
  require(all(q.number(v.get('time')) and q.number(v.get('free_gib')) and v['free_gib']>=.5 for v in machine),'Invalid machine/memory evidence')
  require(all(b['time']>a['time'] for a,b in zip(machine,machine[1:])),'Machine time reversed')
  require(previous_end is None or previous_end<machine[0]['time'],'Runs overlap/out of order');previous_end=machine[-1]['time']
  workload=[];playback={};hashes={}
  require(set(r['roles'])=={'host','join'},'Both sides required')
  for role,e in r['roles'].items():
   require(e['done'] and not e['fatal'] and not e['runtime_changes'],'Role failed/runtime changed')
   require(e['appid'].startswith('pfe-modsettings-rconnect-b-ab-'+role+'-') and e['appid'] not in ids,'AIR identity reused');ids.add(e['appid'])
   files=d.canonical(e['files']);expected=d.canonical(prepared['roles'][role]['files'])
   for name,h in expected.items():
    if name not in q.MUTABLE_RUNTIME:require(files.get(name)==h,'Unrelated runtime changed: '+name)
   require(files['pfe.swf']==p['native_sha256'] and files['mods/rconnect/release/rconnectmod.swf']==build['candidate_sha256'],'Runtime tuple differs')
   require(files['mods/rconnect/release/config.txt']==q.windows_json_hash(e['config']),'Configuration bytes differ')
   config=dict(prepared['test_config']);config.update(experimental=True,role=role,session=e['config']['session'],port=e['config']['port'],autoGame=True,land='rbl',probe=True,scenario='stress',stressExternal=True)
   require(e['config']==config,'Unrelated config changed')
   bench=q.log_events(folder/role/'ABBench.log');game=q.log_events(folder/role/'RConnect-B.log')
   require(not any(v['kind'] in ('FATAL','error') for v in game),'Runtime error')
   boot=d.one(game,'boot');require(boot['source']==build['source_id'] and boot['version']==build['version'] and boot['role']==role and boot['session']==config['session'],'Loaded identity differs')
   current_scene=q.verify_log_results(bench,e,role,driver)
   if role not in scenes:scenes[role]=current_scene
   require(current_scene==scenes[role],'Scene or frame rate changed')
   for phase,value in enumerate(e['results']):
    workload.append(q.phase_workload(value,role,phase))
    if role=='join':
     samples=value['samples'];delays=sorted(v['delay'] for v in samples)
     playback[str(phase)]=dict(underflow_increase=samples[-1]['underflows']-samples[0]['underflows'],
      mean_target_delay_ms=sum(delays)/len(delays),p95_target_delay_ms=delays[int(len(delays)*.95)],max_target_delay_ms=max(delays),
      max_frame_interval_ms=max(value['intervals']),empty_buffer_samples=sum(v['queued']==0 for v in samples))
  for f in folder.rglob('*'):
   if f.is_file():hashes[f.relative_to(folder).as_posix()]=d.sha(f)
  runs.append(dict(group='baseline' if label=='A' else 'candidate',path=d.rel(folder),workload=workload,hashes=hashes,playback=playback,machine_first=machine[0]['time'],machine_last=machine[-1]['time']))
 require(len(runs)==4 and len(ids)==8,'Four distinct dual runs required')
 comparisons=q.compare(runs);qualified=all(v['repeatable'] and v['no_material_regression'] for v in comparisons)
 return dict(schema='b-current-environment-sustained-1',valid_inputs=True,qualified=qualified,no_material_regression=qualified,gates=q.GATES,
  candidate_sha256=builds['B']['candidate_sha256'],source=builds['B']['source_id'],baseline=builds['A'],candidate=builds['B'],
  series=d.rel(series),series_sha256=d.sha(series),environment_sha256=p['environment_sha256'],native_sha256=p['native_sha256'],
  comparisons=comparisons,inputs=runs,qualifier_sha256=d.sha(__file__),workload_checker_sha256=d.sha(q.__file__),
  scope='Stage frame intervals in the same default environment. Not GPU output or input-to-display latency.')

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--series',required=True);ap.add_argument('--out',required=True);a=ap.parse_args();out=d.path(a.out)
 d.require(not out.exists(),'Keep previous results immutable')
 try:r=evaluate(a.series)
 except (ValueError,KeyError,TypeError,OSError) as e:r=dict(valid_inputs=False,qualified=False,error=str(e),gates=q.GATES,qualifier_sha256=d.sha(__file__))
 out.write_bytes(d.encode(r));print(json.dumps({k:r[k] for k in ('valid_inputs','qualified','error') if k in r}));sys.exit(0 if r['qualified'] else 1)
