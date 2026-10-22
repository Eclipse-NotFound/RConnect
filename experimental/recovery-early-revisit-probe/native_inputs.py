"""Reuse exact binary/install checks, accepting only this frozen diagnostic driver."""
from pathlib import Path
import importlib.util,hashlib,json
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'recovery-early-sandy-native'
spec=importlib.util.spec_from_file_location('early_revisit_original_inputs',BASE/'native_inputs.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
sha=original.sha
def verify_tools():
    original.verify_tools()
    pins=original.read(HERE/'inputs.json')
    for name,h in pins['originals'].items():assert sha(name)==h,name
    for name,h in pins['sources'].items():assert sha(HERE/name)==h,name
def audit(path):verify_tools();return original.audit(path)
def host_input(path,installed):verify_tools();return original.host_input(path,installed)
def verify_host_intent(path,intent,installed):verify_tools();return original.verify_host_intent(path,intent,installed)
def sandy_input(mode):verify_tools();return original.sandy_input(mode)
def verify_driver(path,meta,scenario):
    verify_tools()
    assert scenario=='scene' and meta['kind']=='scene-native-input-early-revisit-driver'
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['diagnostic_kind']=='early-revisit' and meta['sand_mode']=='bridge'
    assert meta['installation_unchanged'] is True
    assert meta['original_scene_driver_manifest']==original.DRIVER12_MANIFEST
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    base=original.read(path/'original-prepared.json')
    assert sha(path/'original-prepared.json')==meta['original_early_driver_manifest']
    assert base['compiled'] is False and base['diagnostic_only'] is False
    assert base['kind']=='scene-native-input-early-sandy-driver' and base['sand_mode']=='bridge'
    for n,h in base['source_inputs'].items():assert sha(n)==h,n
    for n,h in base['files'].items():
        if n!='tests/FirstRasterSceneProbe.as':assert sha(path/n)==h,n
    assert sha(path/'tests/FirstRasterSceneProbe.as')==sha(HERE/'tests/FirstRasterSceneProbe.as')
