"""Verified B-only local update plus discoverable launchers; preserves saves and A."""
from pathlib import Path
import argparse, importlib.util, json, os, shutil, sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; RC=HERE.parents[1]; GAME=RC.parents[1]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
d=load('entry_transaction',RC/'experimental/b-field8-validation/transaction.py')
q=load('entry_qualifier',HERE/'qualify.py')
P=d.PLAYABLE
BASE='a382e94f66fa22e008c1a056871a6634bdf4915e1e84a9b2b9a3de0347818386'
MANUAL='aef3ccc85c7cb5d9ae581e100258140bbc637ddc618b0ba118ea206e7b0ae098'
HOST='d851eb9e68d38abd335916dd91e08de3f1660945b49f382691a188adc7c8c295'
NATIVE='3b1b77d3f6de08e5b31bb03883da6900b3656e497a4749305133019d0377ed83'
def rel(p):
    p=p.resolve();d.require(p.is_relative_to(GAME),'Target outside game workspace');return p.relative_to(GAME).as_posix()
def batch(path):return path.read_text(encoding='utf-8').replace('\r\n','\n').replace('\n','\r\n').encode('utf-8')
def test(path,build,pins):
    path=d.path(path);v=d.read(path);d.pinned(path,pins)
    d.require(v.get('passed') and v.get('complete') and v.get('runtime_unchanged') and v.get('private_desktop') and not v.get('error'),'Incomplete functional test')
    d.require(v['candidate_sha256']==build['candidate_sha256'],'Different tested body')
    files=d.canonical(v['runtime_files']);d.require(files['pfe.swf']==NATIVE,'Different native host')
    d.require(d.pinned(path.parent/'runner.py',pins)==v['runner_sha256'],'Executed runner changed')
    for role,entry in v['roles'].items():
        d.require(entry['done'] and entry['failed']==0 and not entry['fatal'] and entry['passed']>0,'Failed role')
        d.verify(path.parent,entry['logs'],pins)
        events=d.events(path.parent/(role+'.BStartupDriver.log'))
        d.require(sum(e['kind']=='PASS' for e in events)==entry['passed'] and not any(e['kind']=='FAIL' for e in events),'Assertion count differs')
        loaded=d.one(events,'installed');d.require(loaded['source']==build['source_id'] and loaded['version']==build['version'],'Loaded version differs')
    return dict(scenario=v['scenario'],path=d.rel(path),sha256=d.sha(path),checks={k:e['passed'] for k,e in v['roles'].items()})
def check(a):
    manifest=d.package();d.require(d.sha(P/'manual-input.json')==MANUAL and manifest['candidate_sha256']==BASE,'Installed B changed')
    d.require(d.sha(P/'game/pfe.swf')==NATIVE and d.sha(GAME/'adl64.exe')==HOST,'Native/AIR host changed')
    pins={};build=d.build_info(a.candidate,pins);d.require(build['version']=='B3-0.1-entry1','Unexpected candidate version')
    archive=HERE/a.snapshot/'source-manifest.json';saved=d.read(archive);d.pinned(archive,pins)
    d.require(saved['source_id']==build['source_id'] and saved['build_manifest_sha256']==build['manifest_sha256'],'Source archive mismatch')
    parent=HERE/'source-parent/source-manifest.json';base=d.read(parent)
    d.require(d.pinned(parent,pins)==saved['parent_sha256'],'Source parent manifest changed')
    d.verify(parent.parent,base['sources'],pins)
    d.require(dict(base['sources'],**saved['overlay'])==saved['sources'],'Incomplete source overlay')
    d.verify(archive.parent,saved['overlay'],pins)
    prep=d.path(a.preparation);prepared=d.read(prep);d.pinned(prep,pins)
    source=Path(prepared['compiler_command'][-1]);d.require(d.pinned(source,pins)==prepared['driver'],'Observer source changed');d.verify(source.parent,prepared['helpers'],pins)
    records=[]
    for item in a.tests:
        v=d.read(d.path(item));d.require(v['preparation_sha256']==d.sha(prep),'Wrong observer preparation')
        actual_files=d.canonical(v['runtime_files'])
        for name,h in d.canonical(prepared['files']).items():
            if name not in d.RUNTIME_MUTABLE:d.require(actual_files.get(name)==h,'Different dependency: '+name)
        records.append(test(item,build,pins))
    d.require({'ui','textmotion','enemies'}<={v['scenario'] for v in records},'Missing affected behavior tests')
    performance=d.path(a.performance);score=d.read(performance)
    d.require(score==q.evaluate(score['series']) and score['qualified'],'Performance evidence mismatch/regression')
    d.require(score['candidate_sha256']==build['candidate_sha256'],'Wrong measured body');d.pinned(performance,pins)
    notes=HERE/'README-player.txt';d.pinned(notes,pins)
    contents={P/d.RC:(RC/build['path']/'RConnectMod.swf').read_bytes(),P/'README.txt':notes.read_bytes()}
    launchers=HERE/'launchers'
    for name in ['Player-1.cmd','Player-2.cmd']:contents[P/name]=batch(launchers/name)
    contents[RC/'tools/launch-b.cmd']=batch(launchers/'launch-b.cmd')
    for name in ['RConnect-B.cmd','RConnect-B-Player-1.cmd','RConnect-B-Player-2.cmd']:contents[GAME/name]=batch(launchers/name)
    for source in launchers.glob('*.cmd'):d.pinned(source,pins)
    for p in contents:
        if p not in [P/d.RC,P/'README.txt',P/'Player-1.cmd',P/'Player-2.cmd']:
            d.require(not p.exists(),'New launcher target already exists: '+str(p))
    for name in manifest['files']:
        if name.lower()=='mods/rconnect/release/rconnectmod.swf':manifest['files'][name]=build['candidate_sha256']
    manifest.update(source_id=build['source_id'],candidate_sha256=build['candidate_sha256'],candidate_manifest_sha256=build['manifest_sha256'],readme_sha256=d.digest(contents[P/'README.txt']),baseline_manifest_sha256=MANUAL,
                    local_field_gate_complete=True,environment_body_override=dict(path=d.RC,sha256=build['candidate_sha256']),
                    quick_launchers={rel(p):d.digest(v) for p,v in contents.items() if p.suffix=='.cmd'},launch_host=dict(path='adl64.exe',sha256=HOST))
    for entry in manifest['launchers']:entry['launcher_sha256']=d.digest(contents[P/entry['launcher']])
    contents[P/'manual-input.json']=d.encode(manifest)
    contents[P/'playable-validation.json']=d.encode(dict(experimental_only=True,candidate_ready_for_manual_testing=True,local_field_gate_complete=True,formal_release_gate_complete=False,
        candidate_sha256=build['candidate_sha256'],source_id=build['source_id'],field_tests=records,performance=d.rel(performance),manual_manifest_sha256=d.digest(contents[P/'manual-input.json']),
        verification_scope='Exact-byte functional/performance tests; same native host and dependencies. New launchers use the verified root AIR host with unchanged player descriptors.',
        limitations=['Existing windows must be restarted.','Stage intervals are not input-to-display latency; dense combat may still stutter.']))
    d.pinned(Path(__file__),pins);d.pinned(HERE/'qualify.py',pins)
    preserved={name:h for name,h in manifest['files'].items() if name.lower()!='mods/rconnect/release/rconnectmod.swf'}
    for entry in manifest['launchers']:d.require(d.sha(P/entry['descriptor'])==entry['descriptor_sha256'],'Player identity changed')
    return dict(build=build,tests=records,performance=score['comparisons'],evidence=pins,preserved=preserved,root_witness=d.root_game_snapshot()),contents
def install(a):
    out=d.path(a.transaction);d.require(out.parent==RC/'build/ab' and out.name.startswith('b-entry-deploy-') and not out.exists(),'New B transaction required')
    with d.package_lock():
        gate,contents=check(a);out.mkdir();before={rel(p):d.sha(p) if p.exists() else None for p in contents}
        for p in contents:
            if p.exists():backup=out/'before'/rel(p);backup.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,backup)
        receipt=dict(gate,status='prepared',created=d.utc(),before=before,after={rel(p):d.digest(v) for p,v in contents.items()})
        d.atomic_write(out/'deployment.json',d.encode(receipt));shutil.copy2(__file__,out/'release-executed.py')
        done=[]
        try:
            d.verify(RC,gate['evidence']);d.verify(P/'game',gate['preserved'])
            for p,value in contents.items():
                old=before[rel(p)]
                d.require((not p.exists()) if old is None else d.sha(p)==old,'Concurrent target edit')
                d.atomic_write(p,value,old);done.append(p)
            d.package();d.check_root_game(gate['root_witness']);d.verify(P/'game',gate['preserved'])
            d.require(all(d.sha(GAME/k)==h for k,h in receipt['after'].items()),'Readback mismatch')
            receipt.update(status='verified',finished=d.utc());d.atomic_write(out/'deployment.json',d.encode(receipt))
        except Exception as error:
            receipt.update(status='rollback_required',error=str(error));d.atomic_write(out/'deployment.json',d.encode(receipt))
            for p in reversed(done):
                name=rel(p);d.require(d.sha(p)==receipt['after'][name],'Concurrent change blocks rollback')
                if before[name] is None:p.unlink()
                else:d.atomic_write(p,(out/'before'/name).read_bytes(),receipt['after'][name])
            receipt['status']='rolled_back';d.atomic_write(out/'deployment.json',d.encode(receipt));raise
    return dict(status='verified',transaction=d.rel(out),candidate=gate['build'])
def main():
    ap=argparse.ArgumentParser();ap.add_argument('action',choices=['check','install']);ap.add_argument('--candidate',required=True);ap.add_argument('--snapshot',required=True)
    ap.add_argument('--preparation',required=True);ap.add_argument('--tests',nargs='+',required=True);ap.add_argument('--performance',required=True);ap.add_argument('--transaction')
    a=ap.parse_args()
    if a.action=='install':result=install(a)
    else:gate,contents=check(a);result=dict(status='ready',targets=[rel(p) for p in contents],build=gate['build'])
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
