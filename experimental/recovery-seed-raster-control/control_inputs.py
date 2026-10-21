"""Strict on/off source identity and independent external-intent validation."""
import hashlib,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52';BASE=M52/'recovery-13'
sys.path.insert(0,str(ROOT/'tools/validation'));from audit_room_entry_candidate import audit as base_audit
sys.path.insert(0,str(ROOT/'experimental/recovery-first-raster-native'))
from reverify_host import verify as host_verify,HOST,HOST_SHA
PIN='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def inventory(p):return {q.relative_to(p).as_posix():sha(q) for q in sorted(p.rglob('*')) if q.is_file()}
def verify_tools():
 pins=read(HERE/'adapter-inputs.json')
 for n,h in pins['files'].items():assert sha(HERE/n)==h,n
 assert sha(ROOT/'tools/run_coop_regression.py')==pins['common_runtime_sha256']
 assert sha(ROOT/'tools/validation/run_room_travel_timing.py')==pins['common_wrapper_sha256']
def audit(candidate,expect):
 verify_tools();b=base_audit(BASE);assert b['sha256']==PIN
 if expect=='on':assert candidate==BASE;return b
 assert expect=='off' and candidate.parent==M52 and candidate!=BASE
 m=read(candidate/'prepared.json');assert m['kind']=='isolated-seed-raster-control' and m['seed_gate'] is False and m['base_sha256']==PIN
 assert m['compiled'] and sha(candidate/'RConnectMod.swf')==m['sha256']
 assert inventory(candidate/'src')==m['source'] and inventory(candidate/'tools')==m['inputs'] and inventory(candidate/'proposal')==m['proposal']
 assert m['inputs']==b['inputs'] and set(m['source'])==set(b['source'])
 changed={n for n in b['source'] if b['source'][n]!=m['source'][n]};assert changed=={'RConnectMod.as','rconnect/core/RoomSync.as'}
 old=(BASE/'src/rconnect/core/RoomSync.as').read_text(encoding='utf-8-sig');off=(candidate/'src/rconnect/core/RoomSync.as').read_text(encoding='utf-8-sig')
 REPLACED='            return firstRaster.open(w,l,g,seedRaster.id);'
 REPLACEMENT='            return null; // Isolated control: seed identity/anchor/restore remain; native raster runs normally.'
 assert old.count(REPLACED)==1 and off==old.replace(REPLACED,REPLACEMENT,1)
 old=(BASE/'src/RConnectMod.as').read_text(encoding='utf-8-sig');off=(candidate/'src/RConnectMod.as').read_text(encoding='utf-8-sig')
 assert off==old.replace('VERSION:String = "0.2.24-recovery13"','VERSION:String = "0.2.24-recovery13-seed-off"',1)
 return m
def host_input(path,installed):
 assert path==HOST;v=host_verify();receipt=M52/'recovery-first-raster-host-recheck-03/receipt.json';assert v==read(receipt) and installed==v['installation'] and len(installed)==22
 return dict(directory=str(HOST),candidate_sha256=HOST_SHA,manifest_sha256=sha(HOST/'prepared.json'),recheck_sha256=sha(receipt),source_inputs_unchanged=True,original_sha256=installed['pfe.swf'])
def verify_host_intent(path,intent,installed):assert host_input(path,installed)==intent
def verify_driver(path,meta,scenario):
 assert scenario=='scene' and meta['kind']=='scene-seed-gate-comparison-driver' and meta['compiled'] and meta['explicit_intent'] and meta['same_driver_both_modes']
 for n,h in meta['files'].items():assert sha(path/n)==h,n
 for n,h in meta['source_inputs'].items():assert sha(n)==h,n
def validate_gate_result(result,intent,run,binding):
 actual=read(run/'run.json');digest=sha(binding/'seed-gate-intent.json');valid=True
 for role,value in result.get('roles',{}).items():
  errors=[];rows=value.get('rows',[])
  if actual['inputs'][role].get('seed_gate_intent')!=digest:errors.append('copied gate intent fingerprint differs')
  logs=(run/(role+'.log')).read_text(encoding='utf-8-sig').splitlines()
  declared=[json.loads(x.split('SEED GATE INTENT ',1)[1]) for x in logs if x.startswith('SEED GATE INTENT ')]
  if declared!=[intent]:errors.append('actual driver did not read exactly the declared gate intent')
  if len(rows)!=3:errors.append('gate proof requires three original travel results')
  for row in rows:
   expect=intent['expectSeedTicket'] and role=='join' and not row['solo'] and row['target']=='random_mane'
   proof=row.get('rasterEvidence',{});tickets=proof.get('tickets',[])
   if row.get('seedGateIntent')!=intent or proof.get('callbackAvailable') is not True or proof.get('expected') is not expect or proof.get('passed') is not True or len(tickets)!=(1 if expect else 0):errors.append('explicit gate/ticket evidence differs in round '+str(row.get('round')))
   for ticket in tickets:
    if ticket.get('initialWaiting') is not True or ticket.get('initialUnpainted') is not True or ticket.get('firstReleased',-1)<ticket['at'] or ticket.get('firstPainted',-1)<ticket['firstReleased']:errors.append('ticket never completed its real pending raster')
  value['errors']+=errors;valid=valid and not errors
 result['seed_gate_intent']=intent;result['seed_gate_evidence_valid']=valid;result['passed']=result['passed'] and valid
