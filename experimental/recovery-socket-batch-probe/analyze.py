"""Bounded socket-dispatch evidence, never a performance/release gate."""
import hashlib
import json
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'SOCKET BATCH PROFILE '


def validate(row, role):
    assert row['role'] == role and row['diagnosticOnly'] is True
    assert row['performanceQualified'] is False and row['wireSendTimeAvailable'] is False
    assert len(row['longest']) <= 16
    assert set(row['phases']) <= {'outside', *(f'load{i}' for i in range(7))}
    for batch in row['longest']:
        assert batch['startContext']['phase'] == 'load'
        assert 0 <= batch['startContext']['density'] <= 6 and len(batch['rows']) <= 64
        assert batch['duration'] == batch['stop']-batch['start'] >= 0
        assert batch['messages'] == sum(batch['types'].values())
        assert batch['full'] == batch['types'].get('unitsync', 0)
        assert batch['fast'] == batch['types'].get('worldstate', 0)
        for item in batch['rows']:
            assert item['stop'] is not None and item['dispatchMs'] == item['stop']-item['dispatchStart'] >= 0
    return all(row.get(k) == 0 for k in ('open', 'orphanMessages', 'missingEnd', 'nestedData',
        'nestedMessage', 'faults', 'attachFailures', 'metadataTruncated')) and bool(row['attachments']) and \
        all(x['socketUnchanged'] for x in row['attachments']) and \
        all(row['phases'].get(f'load{i}', {}).get('batches', 0)>0 for i in range(7))


def analyze(out):
    result=json.loads((out/'result.json').read_text('utf-8-sig'))
    run=ROOT/'build/cooperation'/result['run']
    report=dict(run=result['run'], diagnostic_only=True, performance_qualified=False, release_qualified=False,
        installed_unchanged=result['installation_unchanged'], exclusive=result['exclusive_air_confirmed'],
        vision_templates_confirmed=result.get('vision_templates_confirmed') is True,
        vision_templates_unchanged=result.get('vision_templates_unchanged') is True, roles={})
    for role in ('host', 'join'):
        path=run/(role+'.log')
        lines=path.read_text('utf-8-sig').splitlines()
        payloads=[json.loads(x[len(PREFIX):]) for x in lines if x.startswith(PREFIX)]
        assert len(payloads)==1, f'{role}: missing or repeated socket summary'
        row=payloads[0]
        row['valid_dispatch_observation']=validate(row,role)
        row['log_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        outside=[x for x in lines if not x.startswith(PREFIX)]
        row['original_coop_failures']=[x for x in outside if 'COOP FAIL' in x]
        row['actual_runtime_errors']=[x for x in outside if re.search(
            r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory)\b',x,re.I)]
        report['roles'][role]=row
    report['collected']=all(x['valid_dispatch_observation'] for x in report['roles'].values())
    return report
