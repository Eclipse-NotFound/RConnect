"""Exact recovery13/FD92 inputs for the unchanged native test execution path."""
from pathlib import Path
import json
from audit_room_entry_candidate import audit as original_audit
from reverify_host import verify as reverify,sha,ROOT,M52,HOST,HOST_SHA

CANDIDATE=M52/'recovery-13'
CANDIDATE_SHA='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
RECHECK=M52/'recovery-first-raster-host-recheck-03/receipt.json'
DRIVER12=M52/'room-travel-driver-12'
DRIVER12_MANIFEST='3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784'
def verify_tools():
    here=Path(__file__).resolve().parent
    pins=json.loads((here/'runner-inputs.json').read_text(encoding='utf-8'))
    for path,digest in ((ROOT/'tools/validation/run_room_travel_timing.py',pins['original_wrapper_sha256']),
        (ROOT/'tools/run_coop_regression.py',pins['native_runner_sha256']),(here/'run_native.py',pins['derived_runner_sha256']),
        (here/'native_inputs.py',pins['adapter_sha256'])):assert sha(path)==digest,path
def verify_driver(path,meta,scenario):
    if scenario=='entry-room':
        assert path.resolve()==DRIVER12.resolve() and sha(path/'prepared.json')==DRIVER12_MANIFEST
    else:
        assert scenario=='scene' and meta.get('kind')=='scene-native-input-first-raster-driver'
        assert meta.get('compiled') is True and meta.get('external') is True
        assert meta.get('require_seed_raster') is True and meta.get('diagnostic_only') is False
        assert meta.get('original_scene_driver_manifest')==DRIVER12_MANIFEST
        assert meta.get('installation_unchanged') is True
        for name,digest in meta['source_inputs'].items():assert sha(Path(name))==digest,name
    for name,digest in meta['files'].items():assert sha(path/name)==digest,name
def audit(candidate):
    verify_tools()
    assert candidate.resolve()==CANDIDATE.resolve(),'Only frozen recovery13 is accepted'
    result=original_audit(candidate)
    assert result['sha256']==sha(candidate/'RConnectMod.swf')==CANDIDATE_SHA
    return result
def host_input(candidate,installed):
    assert candidate.resolve()==HOST.resolve(),'Only host03 FD92 is accepted'
    verified=reverify();record=json.loads(RECHECK.read_text(encoding='utf-8-sig'))
    assert verified==record,'Independent host recheck no longer matches actual evidence'
    assert installed==verified['installation'] and len(installed)==22
    return dict(directory=str(HOST),candidate_sha256=HOST_SHA,manifest_sha256=sha(HOST/'prepared.json'),
        recheck_sha256=sha(RECHECK),recheck=str(RECHECK),original_sha256=installed['pfe.swf'],
        source_inputs_unchanged=True,host_files=verified['host_files'])
def verify_host_intent(candidate,intent,installed):
    assert host_input(candidate,installed)==intent
    audit(CANDIDATE)
