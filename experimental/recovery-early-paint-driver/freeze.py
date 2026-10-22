"""Freeze this new driver against the separately reviewed paint host source."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    contract=HERE.parent/'recovery-early-paint-timing'
    base=ROOT/'build/m52/recovery-early-sandy-scene-driver-01'
    originals=[base/'prepared.json',contract/'prepared.json',contract/'src/fe/graph/Grafon.as',
        HERE.parent/'recovery-early-revisit-frozen-rv/inputs.json',
        HERE.parent/'recovery-early-revisit-frozen-rv/native_inputs.py']
    originals += [base/'tests'/n for n in ('FirstRasterSceneProbe.as','RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as')]
    sources=[p for p in HERE.rglob('*') if p.is_file() and p.name!='inputs.json']
    pins=dict(sources={p.relative_to(HERE).as_posix():sha(p) for p in sources},
        originals={str(p):sha(p) for p in originals},paint_contract=str(contract/'prepared.json'),
        paint_source=str(contract/'src/fe/graph/Grafon.as'),diagnostic_only=True,
        compiled=False,performance_qualified=False)
    out=HERE/'inputs.json';assert not out.exists(),'Do not alter frozen admission'
    out.write_text(json.dumps(pins,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(out)
if __name__=='__main__':main()
