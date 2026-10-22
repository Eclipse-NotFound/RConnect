"""Exact external driver admission, for the root-owned native runner adapter."""
from pathlib import Path
import hashlib,importlib.util,json,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=HERE.parent/'recovery-early-revisit-frozen-rv'
sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('paint_driver_original_inputs',BASE/'native_inputs.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha=original.sha;read=original.read;installation=original.installation
KIND='scene-native-input-early-paint-driver'

def verify_tools():
    original.verify_tools()
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    contract=read(Path(pins['paint_contract']))
    assert contract['diagnostic_only'] is True and contract['production_files_changed'] is False
    assert contract['original_host_sha256']==original.HOST_SHA
    assert contract['changed_methods']==['sceneEnsure']
    assert contract['added_fields']==['rconnectPaintTimingBridge','rconnectPaintTimingFaults']
    assert sha(Path(pins['paint_source']))==contract['prepared_source_sha256']
    return pins

def verify_driver(path,meta,scenario):
    pins=verify_tools();base,old=original.verify_original_driver()
    assert scenario=='scene' and meta['kind']==KIND
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['diagnostic_kind']=='ensure-work' and meta['sand_mode']=='bridge'
    assert meta['installation_unchanged'] is True and installation()==meta['installation_before']
    assert meta['original_scene_driver_manifest']==original.DRIVER12_MANIFEST
    assert meta['original_early_driver_manifest']==sha(base/'prepared.json')
    assert meta['paint_contract_sha256']==sha(pins['paint_contract'])
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    assert read(path/'original-prepared.json')==old
    for n in meta['copied_original_files']:
        assert n!='tests/FirstRasterSceneProbe.as' and sha(path/n)==old['files'][n],n
    for n in ('FirstRasterSceneProbe.as','PaintTimingBuffer.as'):
        assert sha(path/'tests'/n)==sha(HERE/'tests'/n),n
    return meta
