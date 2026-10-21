"""Thin scene12/E159 adapter; only candidate audit and reason collection differ."""
import argparse
import json
from pathlib import Path
import re
import sys
import prepare as recipe

HERE,ROOT=recipe.HERE,recipe.ROOT
_saved=sys.modules.get('generate')
sys.modules['generate']=recipe.load('view_run_legacy_generator',recipe.LEGACY/'generate.py')
try: adapter=recipe.load('view_run_legacy_adapter',recipe.LEGACY/'run_native.py')
finally:
    if _saved is None:sys.modules.pop('generate',None)
    else:sys.modules['generate']=_saved
adapter.HERE=HERE
adapter.diagnostic_prepare=recipe


def audit(candidate):
    assert candidate.resolve()==adapter.CANDIDATE.resolve()
    meta=recipe.verify(candidate)
    assert meta['compiled'] is True and meta['kind']==recipe.KIND
    assert meta['scene_driver']['manifest_sha256']==adapter.DRIVER_MANIFEST_SHA
    return meta


_fingerprints=adapter.fingerprints
def fingerprints(validate=True):
    result=_fingerprints(validate)
    result['tools'][str(Path(__file__).resolve())]=adapter.sha(Path(__file__))
    result['tools'][str(recipe.LEGACY/'prepare.py')]=adapter.sha(recipe.LEGACY/'prepare.py')
    return result


def collect_rows(out,raw,old_runs):
    run_id=raw.get('run') if raw else None
    if not run_id and (out/'runner.log').is_file():
        ids=re.findall(r'^OUTPUT .*?([0-9a-f]{10})\s*$',(out/'runner.log').read_text(encoding='utf-8',errors='replace'),re.M)
        if len(ids)==1:run_id=ids[0]
    result=dict(run=run_id,rows={},parse_errors=[],logs={})
    if not run_id:return result
    assert re.fullmatch('[0-9a-f]{10}',run_id) and run_id not in old_runs
    for role in ('host','join'):
        path=adapter.ROOT/'build/cooperation'/run_id/(role+'.log');result['rows'][role]=[]
        if not path.is_file():continue
        result['logs'][role]=adapter.sha(path)
        for number,line in enumerate(path.read_text(encoding='utf-8-sig',errors='replace').splitlines(),1):
            if not line.startswith('RConnectViewReason '):continue
            try:
                value=json.loads(line[len('RConnectViewReason '):])
                if not isinstance(value,dict):raise ValueError('Reason must be an object')
                result['rows'][role].append(value)
            except ValueError as error:result['parse_errors'].append(dict(role=role,line=number,error=str(error),text=line))
    return result


def rows_complete(evidence):
    if evidence['parse_errors']:return False
    for role,rows in evidence['rows'].items():
        for row in rows:
            if not (row.get('diagnosticOnly') is True and row.get('performanceQualified') is False
                and row.get('stage') in ('construct','unchanged') and row.get('outcome') in ('failure','success')
                and isinstance(row.get('scope'),str) and isinstance(row.get('field'),str)
                and type(row.get('id')) is int and row['id']>0 and type(row.get('at')) is int):return False
    # Host may only capture/commit; it need not construct a RoomTerrainView.
    # Initial base join may add an earlier row. The unchanged scene12 then runs
    # large first entry, base return, and the same large-room revisit.
    rows=evidence['rows'].get('join',[])
    return len(rows)>=3 and [(r.get('width'),r.get('height')) for r in rows[-3:]]==[(240,125),(48,25),(240,125)]


adapter.audit=audit
adapter.fingerprints=fingerprints
adapter.collect_rows=collect_rows
adapter.rows_complete=rows_complete


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--registry-wait',type=float,default=900);args=ap.parse_args()
    adapter.CANDIDATE=(ROOT/args.candidate).resolve()
    assert adapter.CANDIDATE.parent==adapter.M52
    # Reuse the exact existing registered scene12 runner, 600s budget, E159,
    # memory/exclusive-AIR guards, 22 inputs, and original result preservation.
    return adapter.run((ROOT/args.output).resolve(),args.registry_wait)


if __name__=='__main__':raise SystemExit(main())
