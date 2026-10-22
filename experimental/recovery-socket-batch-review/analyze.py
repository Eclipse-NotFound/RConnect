"""Summarize completed external socket observations without changing evidence."""
import argparse
import hashlib
import json
from pathlib import Path


def summarize(path):
    raw = path.read_bytes()
    source = json.loads(raw)
    report = dict(source=str(path), sha256=hashlib.sha256(raw).hexdigest(),
                  run=source.get('run'), collected=source.get('collected'),
                  performance_qualified=False, roles={})
    for role, data in source.get('roles', {}).items():
        stages = []
        for index in range(7):
            phase = data['phases'].get('load'+str(index), {})
            full = phase.get('fullPerBatchHistogram', {})
            stages.append(dict(phase=index, batches=phase.get('batches'),
                messages=phase.get('messages'), full=phase.get('full'), fast=phase.get('fast'),
                multiple_full_batches=sum(n for k, n in full.items() if k not in ('0', '1')),
                batch_ms=phase.get('batchMs'), dispatch_ms=phase.get('dispatchMs'),
                max_batch_ms=phase.get('maxMs'),
                observer_ms=sum(phase.get(k, 0) for k in ('preObserveMs', 'metadataMs', 'postObserveMs')),
                full_stats={k: phase.get('fullStats', {}).get(k) for k in ('packets', 'units', 'wallCells', 'wallChars')},
                fast_stats={k: phase.get('fastStats', {}).get(k) for k in ('packets', 'units', 'wallCells', 'wallChars')},
                full_histogram=full))
        longest = []
        for batch in data['longest']:
            longest.append(dict(id=batch['id'], phase=batch['startContext']['density'],
                frame=batch['startContext']['frame'], duration=batch['duration'],
                messages=batch['messages'], full=batch['full'], fast=batch['fast'],
                dispatch_ms=batch['dispatchMs'], metadata_ms=batch['metadataMs'],
                rows=[{k: row.get(k) for k in ('type', 'dispatchMs', 'units', 'wallCells',
                      'wallChars', 'tick', 'sampleMin', 'sampleMax')} for row in batch['rows']]))
        report['roles'][role] = dict(valid=data['valid_dispatch_observation'],
            faults=data['faults'], orphan_messages=data['orphanMessages'],
            dropped_rows=data['rowsDropped'], stages=stages, longest=longest,
            runtime_errors=data['actual_runtime_errors'], original_failures=data['original_coop_failures'])
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('path', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = summarize(args.path)
    if args.output:
        with args.output.open('x', encoding='utf-8') as stream:
            json.dump(result, stream, indent=2, ensure_ascii=False)
    # Only concise statistics on stdout; detailed rows remain in the new report.
    print(json.dumps(dict(run=result['run'], collected=result['collected'],
        roles={role: dict(valid=row['valid'], stages=row['stages'],
                         longest=row['longest'][:3], runtime_errors=row['runtime_errors'])
               for role, row in result['roles'].items()}), ensure_ascii=False))
