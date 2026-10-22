"""Root freezes final aggregate source inputs after joint review; no build or AIR."""
from pathlib import Path
import json
from binding import HERE,HOST_SOURCE,original,baseline,sha
OWN=('generate.py','binding.py','prepare.py','audit_profile.py','check.py','audit_checks.py',
     'component_static.py','freeze_sources.py','README.md','baseline.py',
     'tests/FirstRasterSceneProbe.as','tests/PaintTimingBuffer.as','tests/PaintTimingBufferChecks.as')
def main():
    out=HERE/'inputs.json';assert not out.exists(),'Never overwrite frozen aggregate inputs'
    baseline.verify_tools();base,old=original.verify_original_driver();baseline.sandy_input('bridge')
    originals=[base/'prepared.json',HERE.parent/'recovery-early-paint-driver/inputs.json',HERE.parent/'recovery-early-paint-driver/prepare.py',
        HERE.parent/'recovery-early-paint-driver/tests/FirstRasterSceneProbe.as',HOST_SOURCE/'handoff.json']
    originals += [HOST_SOURCE/n for n in baseline.read(HOST_SOURCE/'handoff.json')['files']]
    originals += [base/'tests'/n for n in ('FirstRasterSceneProbe.as','RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as')]
    pins=dict(sources={n:sha(HERE/n) for n in OWN},originals={str(p):sha(p) for p in originals},
        paint_contract=str(HOST_SOURCE/'prepared.json'),paint_source=str(HOST_SOURCE/'src/fe/graph/Grafon.as'),
        diagnostic_only=True,compiled=False,performance_qualified=False)
    out.write_text(json.dumps(pins,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(out)
if __name__=='__main__':main()
