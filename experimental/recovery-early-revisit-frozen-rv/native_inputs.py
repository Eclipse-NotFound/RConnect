"""Strict early1/2D415D and CEC6/A-hold identities, not deployment approval."""
from pathlib import Path
import hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1];M52=ROOT/'build/m52'
sys.path.insert(0,str(ROOT/'tools/validation'))
from audit_room_entry_candidate import audit as original_audit
from run_security_terminals import installation
from baseline import assert_current,frozen_vision,RV_KEY,RV_OLD,RV_NEW

CANDIDATE=M52/'recovery-early-compile-01'
RC_SHA='10b249871b6d6189f4fab4705dd8d4dae4db619d9b3159972010e8e24791fae6'
HOST=M52/'recovery-early-host-01'
HOST_SHA='2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29'
SAND=ROOT.parent/'Sandevistan/build/out/a-travel-hold-20261022-003'
SAND_SHA='3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c'
CEC6='cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942'
DRIVER12=M52/'room-travel-driver-12'
DRIVER12_MANIFEST='3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def verify_tools():
    pins=read(HERE/'inputs.json')
    for name,digest in pins['sources'].items():assert sha(HERE/name)==digest,name
    for name,digest in pins['originals'].items():assert sha(name)==digest,name
def sandy_input(mode):
    verify_tools()
    assert mode in ('bridge','legacy')
    installed=installation();assert len(installed)==22
    assert installed['mods/Sandevistan/release/SandevistanMod.swf']==CEC6
    intent=read(SAND/'intent.json');receipt=read(SAND/'receipt.json')
    assert intent['original_candidate']==CEC6 and intent['b_interface_included'] is False
    assert receipt['compiled'] is True and receipt['exit_code']==0 and receipt['inputs_unchanged'] is True
    assert receipt['candidate_sha256']==sha(SAND/'SandevistanMod.swf')==SAND_SHA
    assert Path(receipt['candidate']).resolve()==(SAND/'SandevistanMod.swf').resolve()
    assert_current(installed,intent['installation_before'])
    frozen_vision()
    for name,digest in intent['inputs'].items():assert sha(name)==digest,name
    for name,digest in intent['sources'].items():assert sha(SAND/'frozen'/name)==digest,name
    path=SAND/'SandevistanMod.swf' if mode=='bridge' else ROOT.parent/'Sandevistan/release/SandevistanMod.swf'
    return dict(mode=mode,candidate=str(path),candidate_sha256=sha(path),
        receipt_sha256=sha(SAND/'receipt.json'),intent_sha256=sha(SAND/'intent.json'),
        original_sha256=CEC6,contract='sandy-travel-hold/1' if mode=='bridge' else None,
        runtime_qualified=False)
def audit(candidate):
    verify_tools();assert candidate.resolve()==CANDIDATE.resolve()
    meta=original_audit(candidate)
    assert meta['sha256']==sha(candidate/'RConnectMod.swf')==RC_SHA
    return meta
def host_input(candidate,installed):
    verify_tools();assert candidate.resolve()==HOST.resolve()
    recipe=HERE/'host_recheck.py'
    spec=importlib.util.spec_from_file_location('early_native_host_check',recipe)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    actual=module.verify();receipt=M52/'recovery-early-host-recheck-01/receipt.json'
    prior=read(receipt)
    assert prior['recipe_sha256']==sha(ROOT/'experimental/recovery-early-host-review/recheck.py')
    prior=dict(prior);prior['recipe_sha256']=sha(recipe)
    assert actual==prior and actual['validated'] is True
    assert actual['candidate_sha256']==sha(HOST/'pfe.swf')==HOST_SHA
    assert installation()==installed and len(installed)==22
    return dict(directory=str(HOST),candidate_sha256=HOST_SHA,
        manifest_sha256=sha(HOST/'prepared.json'),recheck=str(receipt),recheck_sha256=sha(receipt),
        original_sha256=installed['pfe.swf'],source_inputs_unchanged=True)
def verify_host_intent(candidate,intent,installed):
    assert host_input(candidate,installed)==intent
    audit(CANDIDATE)
def verify_original_driver():
    path=M52/'recovery-early-sandy-scene-driver-01'
    pins=read(HERE/'inputs.json');assert sha(path/'prepared.json')==pins['driver_manifest']
    meta=read(path/'prepared.json')
    assert meta['kind']=='scene-native-input-early-sandy-driver' and meta['compiled'] is True
    assert meta['sand_mode']=='bridge' and meta['diagnostic_only'] is False
    assert_current(installation(),meta['installation_before'])
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    return path,meta

def verify_driver(path,meta,scenario):
    verify_tools();base,old=verify_original_driver()
    assert scenario=='scene' and meta['kind']=='scene-native-input-early-revisit-frozen-rv-driver'
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['diagnostic_kind']=='early-revisit' and meta['sand_mode']=='bridge'
    assert meta['installation_unchanged'] is True and installation()==meta['installation_before']
    assert meta['original_scene_driver_manifest']==DRIVER12_MANIFEST
    assert meta['original_early_driver_manifest']==sha(base/'prepared.json')
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    assert read(path/'original-prepared.json')==old
    for n in meta['copied_original_files']:
        assert n!='tests/FirstRasterSceneProbe.as' and sha(path/n)==old['files'][n],n
    probe=HERE.parent/'recovery-early-revisit-probe/tests/FirstRasterSceneProbe.as'
    assert sha(path/'tests/FirstRasterSceneProbe.as')==sha(probe)
