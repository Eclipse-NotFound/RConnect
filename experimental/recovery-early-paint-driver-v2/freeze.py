"""Freeze the small adapter only after the v2 native diagnostic handoff exists."""
import json
from binding import HERE,V1,HOST_V2,V1_INPUTS_SHA,sha,read

def main():
    assert sha(V1/'inputs.json')==V1_INPUTS_SHA
    handoff=read(HOST_V2/'handoff.json')
    for n,h in handoff['files'].items():assert sha(HOST_V2/n)==h,n
    originals=[V1/'inputs.json',HOST_V2/'handoff.json']
    originals += [HOST_V2/n for n in handoff['files']]
    sources=[p for p in HERE.iterdir() if p.is_file() and p.name!='inputs.json']
    meta=dict(sources={p.name:sha(p) for p in sources},
        originals={str(p):sha(p) for p in originals},
        paint_contract=str(HOST_V2/'prepared.json'),paint_source=str(HOST_V2/'src/fe/graph/Grafon.as'),
        observer_sources=str(V1/'inputs.json'),diagnostic_only=True,compiled=False,performance_qualified=False)
    output=HERE/'inputs.json';assert not output.exists(),'Do not alter frozen admission'
    output.write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(output)

if __name__=='__main__':main()
