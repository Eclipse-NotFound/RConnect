"""Thin, exact v2 host binding over the frozen paint observer and original gates."""
from pathlib import Path
import importlib.util

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
V1=HERE.parent/'recovery-early-paint-driver'
HOST_V2=HERE.parent/'recovery-early-paint-timing-v2'
V1_INPUTS_SHA='34bbabd1ef0759e8a126fbf1b926ff39be523fce83470ae5544bbe5d1c32cceb'
KIND='scene-native-input-early-paint-driver-v2'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

v1=load('frozen_paint_driver_v1_binding',V1/'binding.py')
original=v1.original
sha=v1.sha;read=v1.read;installation=v1.installation

def verify_tools():
    assert sha(V1/'inputs.json')==V1_INPUTS_SHA
    prior=v1.verify_tools()
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    meta=read(pins['paint_contract'])
    assert meta['diagnostic_only'] is True and meta['compiled'] is False
    assert meta['runtime_qualified'] is False and meta['performance_qualified'] is False
    assert meta['original_host_sha256']==original.HOST_SHA
    assert meta['prior_diagnostic_source_sha256']==sha(prior['paint_source'])
    assert meta['modified_logic_methods']==['sceneEnsure']
    assert meta['import_only_restoration']=={'sceneDrawSteps':['j++;','i++;']}
    assert meta['pseudo_instructions_remaining']==0 and meta['contract_changed'] is False
    assert meta['original_failed_output_preserved'] is True and meta['acc_after_equals_2d_after'] is True
    assert sha(pins['paint_source'])==meta['prepared_source_sha256']
    return pins

def preparation_bindings():
    """Same frozen recipe and AS; add v2 provenance and change only host binding."""
    pins=verify_tools();prior=v1.verify_tools()
    extra={str(HERE/'inputs.json'):sha(HERE/'inputs.json')}
    extra.update({str(HERE/n):h for n,h in pins['sources'].items()})
    extra.update(pins['originals'])
    return dict(prior,sources=prior['sources'],originals={**prior['originals'],**extra},
        paint_contract=pins['paint_contract'],paint_source=pins['paint_source'])

def verify_driver(path,meta,scenario):
    pins=verify_tools();base,old=original.verify_original_driver()
    assert scenario=='scene' and meta['kind']==KIND
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['diagnostic_kind']=='ensure-work' and meta['sand_mode']=='bridge'
    assert meta['installation_unchanged'] is True and installation()==meta['installation_before']
    assert meta['original_scene_driver_manifest']==original.DRIVER12_MANIFEST
    assert meta['original_early_driver_manifest']==sha(base/'prepared.json')
    assert meta['paint_contract_sha256']==sha(pins['paint_contract'])
    assert meta['paint_host_source_sha256']==sha(pins['paint_source'])
    assert meta['runtime_tested'] is False and meta['performance_qualified'] is False
    assert meta['source_inputs'][str(HERE/'inputs.json')]==sha(HERE/'inputs.json')
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    assert read(path/'original-prepared.json')==old
    for n in meta['copied_original_files']:
        assert n!='tests/FirstRasterSceneProbe.as' and sha(path/n)==old['files'][n],n
    for n in ('FirstRasterSceneProbe.as','PaintTimingBuffer.as'):
        assert sha(path/'tests'/n)==sha(V1/'tests'/n),n
    assert sha(path/'paint-inputs.json')==V1_INPUTS_SHA
    return meta
