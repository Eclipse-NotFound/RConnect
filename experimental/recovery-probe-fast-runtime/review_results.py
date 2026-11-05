"""Validate the generic component output and show raw paired microbench scale.

No extrapolation from synthetic rows to whole-frame CPU. A promising result
only warrants later native investigation; noise/adverse paths mean shelve.
"""
import argparse
import json
from pathlib import Path
import statistics

from prepare import HERE, ROOT, EXPECTED_BRIDGE, sha

NAMES=['native slots','existing fast slots','generic/display misses','Proxy protected',
       'unmatched Pt path','mixed fixture, not measured game weights']


def review(folder):
    receipt=json.loads((folder/'receipt.json').read_text(encoding='utf-8-sig'))
    raw=json.loads((folder/'component-result.json').read_text(encoding='utf-8-sig'))
    intent=json.loads((folder/'intent.json').read_text(encoding='utf-8-sig'))
    assert receipt['passed'] and receipt['source_unchanged'] and receipt['installation_unchanged']
    assert receipt['component_sha256']==sha(folder/'Checks.swf')
    expected={p.relative_to(HERE/'components').as_posix():sha(p)
              for p in sorted((HERE/'components').rglob('*.as'))}
    assert intent['sources']==expected
    assert all(sha(folder/'src'/p)==h for p,h in expected.items())
    assert raw['passed'] and raw['failed']==0 and all(x['passed'] for x in raw['assertions'])
    assert raw['baselineGameBridgeSHA']==EXPECTED_BRIDGE and raw['benchmarkEnabled'] is True
    assert raw['abBaPairsPerGroup']==6 and raw['warmupReadsPerPath']==10000 and raw['allocationReadsPerPath']==20000
    assert [b['name'] for b in raw['benchmarks']]==NAMES
    summary=[]
    for group in raw['benchmarks']:
        pairs=group['pairs']
        assert group['iterations']==60000 and len(pairs)==6
        assert [p['order'] for p in pairs]==['before-after','after-before']*3
        a=[p['beforeMs'] for p in pairs];b=[p['afterMs'] for p in pairs]
        assert all(isinstance(t,int) and t>=0 for t in a+b)
        gains=[x-y for x,y in zip(a,b)]
        row=dict(name=group['name'],reads_per_sample=60000,raw_before_ms=a,raw_after_ms=b,
            paired_savings_ms=gains,median_before_ms=statistics.median(a),median_after_ms=statistics.median(b),
            median_paired_savings_ms=statistics.median(gains),faster_pairs=sum(g>0 for g in gains),
            allocation_samples_before=group['allocBefore'],allocation_samples_after=group['allocAfter'])
        row['median_paired_savings_microseconds_per_probe']=round(row['median_paired_savings_ms']*1000/60000,6)
        summary.append(row)
    native,mixed=summary[0],summary[-1]
    adverse=[g['name'] for g in summary[1:5] if g['median_paired_savings_ms'] < -2 or g['faster_pairs']==0 and g['median_paired_savings_ms']<0]
    noisy=[g['name'] for g in (native,mixed) if g['median_paired_savings_ms']<=2 or g['faster_pairs']<5]
    return dict(groups=summary,adverse_paths=adverse,noisy_or_unconvincing_paths=noisy,
        recommendation='shelve' if adverse or noisy else 'only consider a separately controlled native measurement',
        performance_qualified=False,synthetic_mixed_weights=True,
        criteria='Conservative screening only: >2ms paired median and >=5/6 faster on native/mixed; reject material fallback regression.',
        allocation_boundary='Sampler observations only; zero samples are not proof of zero allocations.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--result',type=Path,required=True)
    args=parser.parse_args()
    folder=(ROOT/args.result).resolve()
    assert folder.parent==ROOT/'build/m52'
    print(json.dumps(review(folder),ensure_ascii=False,indent=2))
