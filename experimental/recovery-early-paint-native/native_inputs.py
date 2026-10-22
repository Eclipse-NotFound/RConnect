"""Exact early2 / paint-v2 / Sand003 / frozen RV diagnostic admission."""
from pathlib import Path
import hashlib,importlib.util,json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1];M52=ROOT/'build/m52'
EXIT=HERE.parent/'recovery-early-exit-native'
DRIVER=HERE.parent/'recovery-early-paint-driver-v2'
HOST=M52/'recovery-early-paint-host-03'
REVIEW=M52/'recovery-early-paint-host-recheck-03/receipt.json'
REJECTED_REVIEW=M52/'recovery-early-paint-host-recheck-02/receipt.json'
HOST_SHA='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
RC_SHA='d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3'
SOURCE_SHA='eb487597d89073d61e1dffc7789c46130379c45276a9fde5f180008d87e0f960'
HOST_SOURCE=HERE.parent/'recovery-early-paint-timing-v3'
QUALIFICATION_FIELDS=('compiled','source_readback_passed','pcode_bindings_passed',
    'exception_cfg_passed','validated','installation_unchanged','source_unchanged')

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result

early=load('paint_native_frozen_early_exit_inputs',EXIT/'native_inputs.py')
driver=load('paint_native_frozen_v2_driver_binding',DRIVER/'binding.py')
profile=load('paint_native_frozen_profile_audit',driver.V1/'audit_profile.py')
paint_audit_log=profile.audit_log
installation=early.original.installation
RV_KEY,RV_OLD,RV_NEW=early.RV_KEY,early.RV_OLD,early.RV_NEW

def verify_tools():
    early.verify_tools();driver.verify_tools()
    assert (HERE/'inputs.json').is_file(),'Diagnostic runtime admission is not frozen; AIR prohibited'
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    assert pins['candidate_sha256']==RC_SHA and pins['host_sha256']==HOST_SHA
    assert pins['host_source_sha256']==SOURCE_SHA
    compatibility()
    return pins

def compatibility():
    return load('paint_native_exact_source_compatibility',HERE/'source_compat.py').verify()

def qualified_review(value):
    assert all(value.get(k) is True for k in QUALIFICATION_FIELDS),'Independent native review is not qualified'

def audit(candidate):
    verify_tools();meta=early.audit(candidate)
    assert meta['sha256']==RC_SHA
    return meta

def sandy_input(mode):
    verify_tools();assert mode=='bridge'
    return early.sandy_input(mode)

def frozen_vision():
    verify_tools();return early.frozen_vision()

def file_map(mapping,base):
    assert isinstance(mapping,dict) and mapping,'Empty evidence map cannot qualify native host'
    result={}
    for n,h in mapping.items():
        path=Path(n);path=path if path.is_absolute() else base/path
        assert sha(path)==h,str(path)
        result[str(path.resolve())]=h
    return result

def validate_host(path,installed,expected_receipt_sha):
    """Independent exact result review is required; a compiled SWF alone fails."""
    assert path.resolve()==HOST.resolve()
    assert isinstance(HOST_SHA,str) and len(HOST_SHA)==64,'Final actual host03 hash is not bound; AIR prohibited'
    assert REVIEW.is_file(),'Independent host readback / p-code / exception CFG receipt missing; AIR prohibited'
    assert sha(REVIEW)==expected_receipt_sha,'Independent host review differs from frozen admission'
    result=read(REVIEW);meta=read(HOST/'prepared.json')
    qualified_review(result)
    assert result['candidate_sha256']==sha(HOST/'pfe.swf')==HOST_SHA
    assert result['builder_manifest_sha256']==sha(HOST/'prepared.json')
    assert meta['compiled'] is True and meta['source_readback_passed'] is True
    assert meta['pcode_syntax_passed'] is True
    # The builder records syntax only. Actual binding and CFG qualification
    # must come from the independent exact receipt above, never relabel it.
    assert meta['candidate_sha256']==HOST_SHA and meta['diagnostic_only'] is True
    assert meta['installation_unchanged'] is True and meta['source_unchanged'] is True
    assert meta['base_sha256']==early.original.HOST_SHA and meta['patched_classes']==['fe.graph.Grafon']
    assert meta['import_sources']=={'fe/graph/Grafon.as':SOURCE_SHA}
    assert sha(HOST/'import/fe/graph/Grafon.as')==SOURCE_SHA
    sources=file_map(meta['inputs'],HOST)
    readbacks=file_map(meta['readback_files'],HOST)
    reviewed_inputs=file_map(result['inputs'],HOST)
    reviewed_readbacks=file_map(result['readback_files'],HOST)
    assert set(reviewed_readbacks.values()) >= {
        sha(HOST/'after/scripts/fe/graph/Grafon.as'),sha(HOST/'pcode/scripts/fe/graph/Grafon.pcode')
    },'Independent review must pin actual Grafon readback and p-code'
    assert sha(HOST/'pfe.swf') in reviewed_inputs.values(),'Independent review must pin actual compiled SWF'
    assert installation()==installed and len(installed)==22
    # Retain the old exact 2D baseline audit; the new host is independently reviewed above.
    base=early.original.host_input(early.original.HOST,installed)
    early.sandy_input('bridge');early.frozen_vision()
    contract=compatibility()
    return dict(directory=str(HOST),candidate_sha256=HOST_SHA,
        manifest_sha256=sha(HOST/'prepared.json'),recheck=str(REVIEW),recheck_sha256=expected_receipt_sha,
        original_sha256=installed['pfe.swf'],source_inputs_unchanged=True,
        diagnostic_only=True,performance_qualified=False,builder_validated=meta['validated'],
        independent_diagnostic_validated=True,base=base,
        unchanged_driver_contract=contract),{**sources,**readbacks,**reviewed_inputs,**reviewed_readbacks}

def host_input(path,installed):
    pins=verify_tools()
    value,_=validate_host(path,installed,pins['host_review_sha256'])
    return value

def verify_host_intent(path,intent,installed):
    assert host_input(path,installed)==intent
    early.audit(Path(read(EXIT/'inputs.json')['candidate']))

def verify_driver(path,meta,scenario):
    pins=verify_tools()
    assert path.resolve()==Path(pins['driver']).resolve()
    assert sha(path/'prepared.json')==pins['driver_manifest_sha256']
    assert sha(path/'scene/EffectsDriver.swf')==pins['driver_sha256']
    return driver.verify_driver(path,meta,scenario)
