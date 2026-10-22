"""Read-only complete-cell correlation, retaining the outside-crop failure."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUN=ROOT/'build/m52/recovery18-wall-gutter-native-01'
MODULE=ROOT/'experimental/recovery-wall-gutter-diagnostic/analyze_diagnostic.py'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    spec=importlib.util.spec_from_file_location('frozen_gutter_analysis',MODULE)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    inputs=[RUN/'wall-proof'/role/'round-2-proof.json' for role in ('host','join')]
    inputs += [RUN/'result.json',RUN/'gutter-diagnostic-result.json',RUN/'wall-surface-result.json',MODULE,
        ROOT/'experimental/recovery-wall-surfaces-native-proof-review/recovery18-gutter-reanalysis-01.json']
    fingerprints={str(p):sha(p) for p in inputs}
    a,b=[json.loads(p.read_text(encoding='utf-8-sig')) for p in inputs[:2]]
    ga,gb=a['gutterDiagnostic'],b['gutterDiagnostic']
    baseline_and_hits=[]
    for snap in ga['snapshots']:
        assert snap['kind'] in ('baseline','native-after-hits')
        assert len(snap['surfaces'])==4
        values=[s['words'] for s in snap['surfaces']]
        assert all(s['cut']==ga['cell'] for s in snap['surfaces'])
        diff=[i for i in range(1600) if len({v[i] for v in values})>1]
        baseline_and_hits.append(dict(seq=snap['seq'],kind=snap['kind'],wall=snap['wall'],
            surfaces=4,world_pixels=1600,core_gutter_disagreements=diff))
    versions={};all_packets=[]
    for packet in gb['packets']:
        assert packet['rawUnchanged'] and packet['cells']==packet['afterCells'] and len(packet['cells'])==1
        c=packet['cells'][0];words=module.decode(c['d'])
        matches=[s['seq'] for s in ga['snapshots'] if all(s['surfaces'][0]['words'][i]==v for i,v in words.items())]
        after=gb['snapshots'][packet['after']]
        wrong=[dict(order=s['order'],index=i,actual=f'{s["words"][i]:08x}',wire=f'{v:08x}')
            for s in after['surfaces'] for i,v in words.items() if s['words'][i]!=v]
        row=dict(seq=packet['seq'],wall=packet['wall'],version=c['v'],pixels=len(words),
            exact_source_snapshot_matches=matches,receiver_wrong=wrong,
            wire_d_sha256=hashlib.sha256(c['d'].encode('ascii')).hexdigest())
        all_packets.append(row)
        if c['v'] in versions:assert versions[c['v']]['wire_d_sha256']==row['wire_d_sha256']
        else:versions[c['v']]=row
    differences=[]
    for index,(source,remote) in enumerate(zip(a['finalNative'],b['finalNative'])):
        if source==remote:continue
        x=a['area']['x']+index%128;y=a['area']['y']+index//128
        frames={}
        for role,row in (('host',a),('join',b)):
            changes=[];value=row['baseline'][index]
            for frame in row['frames']:
                sparse=dict(zip(frame['native'][::2],frame['native'][1::2]))
                next_value=sparse.get(index,row['baseline'][index])
                if next_value!=value:changes.append(dict(at=frame['at'],wall=frame['wall'],argb=f'{next_value:08x}'));value=next_value
            frames[role]=dict(baseline=f'{row["baseline"][index]:08x}',changes=changes,final=f'{row["finalNative"][index]:08x}')
        differences.append(dict(index=index,x=x,y=y,cell=[x//40,y//40],
            observed=ga['cell']['x']<=x<ga['cell']['x']+40 and ga['cell']['y']<=y<ga['cell']['y']+40,
            source=f'{source:08x}',remote=f'{remote:08x}',render=frames))
    assert fingerprints=={str(p):sha(p) for p in inputs}
    result=dict(diagnostic_only=True,gameplay_qualified=False,performance_qualified=False,inputs=fingerprints,
        input_bytes_unchanged=True,source_snapshots=baseline_and_hits,
        actual_wire_packets=all_packets,unique_versions=list(versions.values()),final_mismatches=differences,
        root_cause_confirmed=False,production_fix_justified=False,
        limitation='Complete-cell equality does not cover the actual differing pixel outside cell16,111. Native callback order and any intervening writes remain unobserved.')
    out=HERE/'review.json';assert not out.exists();out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(source_snapshots=len(baseline_and_hits),packets=len(all_packets),versions=len(versions),
        discrepancies=differences,root_cause_confirmed=False),ensure_ascii=False))


if __name__=='__main__':main()
