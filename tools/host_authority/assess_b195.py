"""Read-only assessment of the predeclared B190/B195 four-trial qualification.

Preserves the original wall-clock ammo warnings, records native reload evidence
separately, and never deploys or grants functional qualification.
"""
import json
import statistics
from common import ROOT, read, save, sha, verify_files
from run_probe import records
from analyze_ab_bench import summarize
from audit_checkpoint import RuntimeFiles, require
from archive_evidence import blob_data


def reload_windows(data):
    result = []
    samples = data['samples']
    for start in range(0, len(samples)-5, 5):
        window = samples[start:start+6]
        for player, (before, after) in enumerate(zip(window[0]['ammo'], window[-1]['ammo'])):
            if before > after:
                continue
            weapons = [v['weapons'][player] for v in window]
            progress = any(a['reload'] > b['reload'] >= 0
                           for a, b in zip(weapons, weapons[1:]))
            resumed = any(v['ammo'][player] < before for v in samples[start+6:])
            result.append(dict(player=player, startMs=window[0]['ms'], endMs=window[-1]['ms'],
                reload=[v['reload'] for v in weapons], hold=[v['hold'] for v in weapons],
                nativeReloadProgress=progress, laterPaidShot=resumed,
                explained=progress and resumed))
    return result


def main():
    out = ROOT/'build/ab/qualification-195-performance.json'
    if out.exists():
        raise FileExistsError('Retain the original assessment')
    seen, runs, geometry, workload_errors = {}, [], [], []
    for index, build in enumerate((190, 195, 195, 190), 1):
        folder = ROOT/('build/ab/qualification-195-perf-%02d-%d' % (index, build))
        receipt = read(folder/'run.json')
        candidate = ROOT/('build/ab/b3-build-'+str(build))
        built = read(candidate/'build-input.json')
        require(receipt['complete'] and receipt['installation_unchanged']
                and receipt['owned_processes_exited'], 'Incomplete or unprotected run')
        runtime = RuntimeFiles(folder, seen)
        for name, digest in receipt['build_manifests'].items():
            directory = ROOT/'build/ab'/name
            manifest_path = directory/('native-input.json' if name.startswith('native-') else 'build-input.json')
            require(sha(manifest_path) == digest, 'Frozen manifest changed')
            verify_files(directory, read(manifest_path)['sources'])
        values = summarize(folder)
        values['build'] = build
        values['reloadReview'] = {}
        values['hostShotAccountingErrors'] = []
        for role, metadata in receipt['roles'].items():
            require(metadata['done'] and metadata['runtime_unchanged']
                    and metadata['candidate_sha256'] == built['candidate_sha256'], 'Wrong or changed runtime')
            for name, digest in metadata['files'].items():
                runtime.check(role+'/'+name, digest)
            bench = folder/role/'ab-bench.json'
            if bench.exists():
                config = read(bench)
            else:
                entry = runtime.entries[(role+'/ab-bench.json').casefold()]
                config = json.loads(blob_data(runtime.store, entry['sha256']))
            require(config['profile'] is False and config['seconds'] == 60
                    and config['variant'] == 'B' and config['role'] == role, 'Different benchmark options')
            log = folder/'evidence'/role/'ABBench.log'
            events = records(log)
            values['reloadReview'][role] = []
            for event in events:
                if event['kind'] != 'result':
                    continue
                data = event['data']
                require(data['timings'] is None, 'Unexpected profiling overhead')
                reviews = reload_windows(data)
                values['reloadReview'][role].append(dict(phase=data['phase'], windows=reviews))
                if any(not w['explained'] for w in reviews):
                    workload_errors.append(folder.name+'/'+role+': unexplained ammo window')
                if role == 'host':
                    for a, b in zip(data['samples'], data['samples'][1:]):
                        for player in (0, 1):
                            if a['ammo'][player]-b['ammo'][player] != b['shots'][player]-a['shots'][player]:
                                values['hostShotAccountingErrors'].append([data['phase'],player,a['ms'],b['ms']])
            for path in (folder/'evidence'/role).glob('*.log'):
                if any(v['kind'] in ('error', 'FATAL', 'fatal') for v in records(path)):
                    workload_errors.append(folder.name+'/'+role+': runtime error in '+path.name)
        for name, digest in receipt['protected_after'].items():
            require(sha(ROOT.parents[1]/name) == digest, 'Installed input changed')
        workload_errors.extend(folder.name+': '+e for e in values['errors']
                               if 'five-sample window' not in e)
        if values['hostShotAccountingErrors']:
            workload_errors.append(folder.name+': host shot accounting mismatch')
        geometry.extend(json.dumps(v,sort_keys=True) for group in values['geometry'].values() for v in group)
        runs.append(values)
    require(len(set(geometry)) == 1, 'Room/window geometry changed')
    require(len({r['driver'] for r in runs}) == 1, 'Different external driver')
    comparisons, reasons = [], []
    for role in ('host', 'join'):
        for count in (8, 80):
            rows = {build:[next(x for x in r['rows'] if x['role']==role and x['enemies']==count)
                          for r in runs if r['build']==build] for build in (190,195)}
            for metric in ('meanMs', 'p95Ms'):
                values = {build:[x[metric] for x in group] for build,group in rows.items()}
                ratio = statistics.median(values[195])/statistics.median(values[190])
                variation = {build:max(v)/min(v) for build,v in values.items()}
                comparisons.append(dict(role=role,enemies=count,metric=metric,values=values,
                                        candidateRatio=ratio,repeatRatio=variation))
                if ratio > 1.15:
                    reasons.append('%s/%d/%s: candidate median worsened over 15%%' % (role,count,metric))
                if any(v > 1.20 for v in variation.values()):
                    reasons.append('%s/%d/%s: same-build repeat varied over 20%%' % (role,count,metric))
    result = dict(runs=runs,comparisons=comparisons,byteIntegrityPassed=True,
        originalAmmoWarningsPreserved=True,workloadErrors=workload_errors,performanceReasons=reasons,
        performanceGatePassed=not reasons and not workload_errors,
        releaseGateComplete=False,uniqueRuntimeBlobsVerified=len(seen),scriptSha256=sha(__file__),
        limitations=['Frame cadence, not GPU presentation or end-to-end input latency',
                     'Real native reload windows reviewed separately; old warnings are not erased',
                     'Variable background load; this is not isolated algorithm timing',
                     'Functional and sustained stability evidence required separately'])
    save(out,result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('runs','comparisons')},ensure_ascii=False))


if __name__ == '__main__':
    main()
