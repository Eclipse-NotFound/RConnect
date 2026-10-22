"""Exact early-travel2 candidate; same native host, Sand and frozen RV."""
from pathlib import Path
import importlib.util, json, sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=HERE.parent/'recovery-early-revisit-frozen-rv'
sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('early_exit_original_inputs',BASE/'native_inputs.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha=original.sha
frozen_vision=original.frozen_vision
RV_KEY,RV_OLD,RV_NEW=original.RV_KEY,original.RV_OLD,original.RV_NEW

def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))

def verify_tools():
    original.verify_tools()
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    return pins

def audit(candidate):
    pins=verify_tools()
    assert candidate.resolve()==Path(pins['candidate']).resolve()
    meta=original.original_audit(candidate)
    assert sha(candidate/'prepared.json')==pins['candidate_manifest']
    assert meta['sha256']==pins['candidate_sha256'] and meta['version']=='0.2.24-early-travel2'
    old=original.audit(original.CANDIDATE)
    assert set(old['source'])==set(meta['source'])
    changed=sorted(n for n in meta['source'] if meta['source'][n]!=old['source'][n])
    assert changed==['RConnectMod.as','rconnect/core/RoomSync.as'],changed
    assert meta['inputs']==old['inputs']
    return meta

def sandy_input(mode):verify_tools();return original.sandy_input(mode)
def host_input(path,installed):verify_tools();return original.host_input(path,installed)
def verify_host_intent(path,intent,installed):
    verify_tools();original.verify_host_intent(path,intent,installed)
    audit(Path(read(HERE/'inputs.json')['candidate']))

def verify_driver(path,meta,scenario):
    verify_tools()
    if meta['kind']=='scene-native-input-early-revisit-frozen-rv-driver':
        return original.verify_driver(path,meta,scenario)
    assert scenario=='scene'
    exact,old=original.verify_original_driver()
    assert path.resolve()==exact.resolve() and meta==old
    assert meta['compiled'] is True and meta['diagnostic_only'] is False
