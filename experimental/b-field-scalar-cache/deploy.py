"""Exact field22 -> scalar04 gate; reuse original five-file transaction and rollback code."""
from pathlib import Path
import importlib.util
ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
d=load('field_transaction',ROOT/'experimental/b-field-deployment/deploy.py')
q=load('scalar_qualification',ROOT/'experimental/b-field-scalar-cache/qualify.py').q
BASE=ROOT/'build/ab/b190-field22-build'
CANDIDATE=ROOT/'build/ab/b190-scalar04-build'
BASE_HASH='3706828fd10cf30c133826d17fd8cef939444f790a33a70d58c2a2b0779c90bf'
CANDIDATE_HASH='f9e542f6d64fef707c41563558365a3d90562dbc346f3be6cf84f968062b7c07'

def performance(report_path,build,pins):
 report_path=d.path(report_path);result=d.read(report_path)
 d.require(result.get('schema')==q.REPORT_SCHEMA and result.get('gates')==d.PERFORMANCE_GATES,'Unexpected workload or thresholds')
 d.require(all(result.get(k) is True for k in ('valid_inputs','qualified','no_material_regression')),'Performance qualification failed')
 d.require(result['candidate_sha256']==build['candidate_sha256'] and result['source']==build['source_id'],'Wrong performance candidate')
 d.require(result['combinations']['baseline']['candidate_sha256']==BASE_HASH and
  result['combinations']['baseline']['native_sha256']==d.NEW_NATIVE and result['combinations']['candidate']['native_sha256']==d.NEW_NATIVE,'Wrong comparison tuple')
 d.require(d.pinned(Path(q.__file__),pins)==result['qualifier_sha256'],'Qualifier changed')
 plan=d.path(result['plan']['path']);d.require(d.pinned(plan,pins)==result['plan']['sha256'],'Plan changed')
 groups={g:[d.path(x['path']) for x in result['inputs'] if x['group']==g] for g in ('baseline','candidate')}
 d.require(q.evaluate(plan,groups['baseline'],groups['candidate'])==result,'Archived performance cannot be reproduced')
 for name,value in d.read(plan)['artifacts'].items():d.require(d.pinned(d.path(name),pins)==value,'Frozen performance input changed')
 for run in result['inputs']:d.verify(d.path(run['path']),run['hashes'],pins)
 return dict(path=d.rel(report_path),sha256=d.pinned(report_path,pins),qualifier_sha256=result['qualifier_sha256'],
  schema=result['schema'],workload='Sustained LMG 1000-round test magazine; field22/native021 baseline',plan=result['plan'])

def preflight(args):
 pins,ids={},set();manifest=d.package();base=d.build_info(BASE,pins)
 d.require(base['candidate_sha256']==BASE_HASH and base['version']=='B3-0.1-field4','Baseline differs')
 d.require(manifest['source_id']==base['source_id'] and manifest['candidate_sha256']==BASE_HASH and
  d.sha(d.PLAYABLE/d.RC)==BASE_HASH and d.sha(d.PLAYABLE/'game/pfe.swf')==d.NEW_NATIVE,'Installed package no longer field22')
 d.require(base['version'] in (d.PLAYABLE/'README.txt').read_text(encoding='utf-8-sig'),'Installed label differs')
 d.require(d.path(args.candidate)==CANDIDATE,'Only reviewed scalar04 candidate is allowed')
 candidate=d.build_info(CANDIDATE,pins)
 d.require(candidate['candidate_sha256']==CANDIDATE_HASH and candidate['version']=='B3-0.1-field5','Candidate differs')
 old=d.read(BASE/'build-input.json')['sources'];new=d.read(CANDIDATE/'build-input.json')['sources']
 d.require(set(old)==set(new),'Source inventory changed')
 changed={name for name in old if old[name]!=new[name]}
 d.require(changed=={'src/authority/BuildInfo.as','src/authority/NativeFields.as','src/RConnectMod.as'},'Unexpected product source changes')
 a=(BASE/'src/authority/NativeFields.as').read_text(encoding='utf-8')
 expected=a.replace('schema={names:[],modes:[]};','schema={names:new Vector.<String>(),modes:new Vector.<int>()};').replace(
  'var names:Array=schema.names,modes:Array=schema.modes;\n         for(var index:int=0;index<names.length;index++)',
  'var names:Vector.<String>=schema.names,modes:Vector.<int>=schema.modes;\n         var length:int=names.length;\n         for(var index:int=0;index<length;index++)')
 d.require(expected==(CANDIDATE/'src/authority/NativeFields.as').read_text(encoding='utf-8'),'Scalar change exceeds reviewed scope')
 d.require((BASE/'src/RConnectMod.as').read_text(encoding='utf-8').replace('B3-0.1-field4','B3-0.1-field5')==
  (CANDIDATE/'src/RConnectMod.as').read_text(encoding='utf-8'),'Unexpected change outside scalar capture')
 check_build=ROOT/'build/ab/b190-scalar03-check-build'
 check_manifest=d.read(check_build/'build-input.json');d.verify(check_build,check_manifest['sources'],pins)
 d.pinned(check_build/'build-input.json',pins)
 d.require(d.pinned(check_build/'RConnectMod.swf',pins)==check_manifest['candidate_sha256']==
  '9cb3604e006ef7b0425c87766fab666ba02056cb56dfe218f22f12f5b8be0553','Micro test build bytes changed')
 d.require(check_manifest['sources']['src/authority/NativeFields.as']==new['src/authority/NativeFields.as'],'Micro test did not exercise exact scalar code')
 micro=ROOT/'build/ab/b-scalar03-micro-01';mr=d.read(micro/'result.json');d.pinned(micro/'result.json',pins)
 d.require(mr['passed'] and mr['candidate_sha256']==check_manifest['candidate_sha256'],'Scalar micro test failed or differs')
 for role in ('host','join'):d.verify(micro,mr['roles'][role]['logs'],pins)
 native=d.native_proof(pins);tests,preparations=d.assignments(args.test),d.assignments(args.preparation)
 mh=d.sha(d.PLAYABLE/'manual-input.json')
 records=[d.test_evidence(tests[s],preparations[s],s,candidate,manifest,mh,pins,used_appids=ids) for s in d.CORE]
 perf=performance(args.performance,candidate,pins);notes=d.path(args.notes)
 d.require(notes.read_text(encoding='utf-8-sig').strip(),'Empty notes');d.pinned(notes,pins);d.pinned(Path(__file__),pins)
 return dict(schema=d.SCHEMA,checked_utc=d.utc(),candidate=candidate,baseline=base,native=native,tests=records,
  performance=perf,notes=d.rel(notes),evidence=pins,before={name:d.sha(d.PLAYABLE/name) for name in d.NAMES},
  manifest=manifest,appids=sorted(ids),script_sha256=d.sha(d.__file__))
d.preflight=preflight
if __name__=='__main__':d.main()
