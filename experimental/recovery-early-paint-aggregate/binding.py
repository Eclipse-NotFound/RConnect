"""Source-only exact aggregate driver binding; runtime admission is separate."""
from pathlib import Path
import baseline
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
KIND='scene-native-input-early-paint-aggregate-driver'
DIAGNOSTIC_KIND='ensure-work-aggregate-v1'
original=baseline.original
sha=baseline.sha;read=baseline.read;installation=baseline.installation
HOST_SOURCE=HERE.parent/'recovery-early-paint-timing-v3'
HOST_V2=HERE.parent/'recovery-early-paint-timing-v2'
HOST_SOURCE_SHA='eb487597d89073d61e1dffc7789c46130379c45276a9fde5f180008d87e0f960'
PROBE_SHA='a1e5298292f33aa30dee4f827eb89d39270b1ae181c086ae3ff67b8c83f593e7'

def verify_tools():
    baseline.verify_tools()
    assert (HERE/'inputs.json').is_file(),'Aggregate source inputs are not frozen'
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    assert pins['diagnostic_only'] is True and pins['performance_qualified'] is False
    assert sha(HOST_SOURCE/'src/fe/graph/Grafon.as')==HOST_SOURCE_SHA
    assert sha(HERE/'tests/FirstRasterSceneProbe.as')==PROBE_SHA
    return pins

def verify_driver(path,meta,scenario):
    verify_tools();base,old=original.verify_original_driver()
    assert scenario=='scene' and meta['kind']==KIND and meta['diagnostic_kind']==DIAGNOSTIC_KIND
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['sand_mode']=='bridge' and meta['installation_unchanged'] is True
    baseline.assert_current(installation(),meta['installation_before'])
    assert meta['original_scene_driver_manifest']==original.DRIVER12_MANIFEST
    assert meta['original_early_driver_manifest']==sha(base/'prepared.json')
    assert meta['paint_host_source_sha256']==HOST_SOURCE_SHA
    assert meta['paint_contract_sha256']==sha(HOST_SOURCE/'prepared.json')
    assert meta['runtime_tested'] is False and meta['performance_qualified'] is False
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    assert read(path/'original-prepared.json')==old
    for n in meta['copied_original_files']:
        assert n!='tests/FirstRasterSceneProbe.as' and sha(path/n)==old['files'][n],n
    for n in ('FirstRasterSceneProbe.as','PaintTimingBuffer.as'):
        assert sha(path/'tests'/n)==sha(HERE/'tests'/n),n
    assert sha(path/'aggregate-inputs.json')==sha(HERE/'inputs.json')
    return meta
