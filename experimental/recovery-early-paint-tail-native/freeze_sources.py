"""Root-only freeze after review; no compiler/AIR. Refuses existing freeze."""
from pathlib import Path
import json
import baseline,check,sampler_admission
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'recovery-early-paint-aggregate'
HOST_SOURCE=HERE.parent/'recovery-early-paint-timing-v3'
def main():
    out=HERE/'inputs.json';assert not out.exists() and not (HERE/'sampler-inputs.json').exists()
    check.check();baseline.verify_tools()
    sampler=sampler_admission.scan_inputs()
    originals={}
    for manifest in (BASE/'inputs.json',BASE/'runtime-inputs.json'):
        pin=baseline.read(manifest);originals[str(manifest)]=baseline.sha(manifest)
        originals.update(pin['originals'])
        originals.update({str(BASE/n):h for n,h in pin['sources'].items()})
    origin=baseline.read(HERE/'source-origin.json');originals.update(origin['originals'])
    originals[origin['helper_manifest']]=origin['helper_manifest_sha256']
    originals.update(sampler_admission.verify_component())
    originals.update({row['path']:row['sha256'] for row in sampler['files']})
    originals[sampler['manifest']]=sampler['manifest_sha256']
    for path,digest in originals.items():assert baseline.sha(path)==digest,path
    (HERE/'sampler-inputs.json').write_text(json.dumps(sampler,indent=2)+'\n',encoding='utf-8')
    own=[p for p in HERE.iterdir() if p.is_file() and p.name not in ('inputs.json','runtime-inputs.json')]
    own+=sorted((HERE/'tests').glob('*.as'))
    pins=dict(sources={p.relative_to(HERE).as_posix():baseline.sha(p) for p in own},originals=originals,
        paint_contract=str(HOST_SOURCE/'prepared.json'),paint_source=str(HOST_SOURCE/'src/fe/graph/Grafon.as'),
        diagnostic_only=True,compiled=False,performance_qualified=False)
    out.write_text(json.dumps(pins,indent=2)+'\n',encoding='utf-8');print(out)
if __name__=='__main__':main()
