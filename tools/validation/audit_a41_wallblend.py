"""Read-only proof for the A41 comparison cache on CS 0.7, not deployment approval."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from audit_a40_wallblend import COUNTS, verify_run
from prepare_a40_wallblend import optimized, replace_once
from release_a22_map import ROOT, sha, read, require

PREPARED = 'ced7b87907d1d4659dc8a3ca4f25289932769f5b3acf5f5f7ee8b73257ed8a75'
FROZEN = '034def4228b08f30280a10793aee9cbdf6b4478a5df26951bf6caa207c96aa42'
HOST = '2a4662488ba3b690eb23acfe4b79aca3f0d9ae114e5e2dee7595af3cabffb3ea'
# The first four complete runs remain valid. Coverage lost its runner before
# recording an exit, so it and the not-yet-started suites need new evidence.
ATTEMPTS = {kind: ('memory-stable-01' if kind in ('Harness', 'Destruction')
                   else 'session-recovery-04') for kind in COUNTS}


def verify_memory(folder, require_exit=False):
    memory = read(folder/'memory-timeline.json')
    require(read(folder/'memory-before.json')['free_commit_bytes'] >= 6*1024**3
            and memory['reason'] is None and memory['rows']
            and min(row['free_commit_bytes'] for row in memory['rows']) >= 512*1024**2,
            'Native test was under memory pressure: '+str(folder))
    if require_exit:
        require(memory.get('exit_code') == 0 and memory.get('process_returncode') == 0,
                'Missing successful process exit: '+str(folder))
    return sha(folder/'memory-timeline.json')


def audit(candidate):
    candidate = Path(candidate).resolve()
    out = candidate.parent
    require(out.parent == ROOT/'build/m52' and candidate.name == 'WallBlendMod.swf',
            'Unexpected candidate path')
    require(sha(out/'prepared.json') == PREPARED and sha(out/'frozen.json') == FROZEN,
            'Not the reviewed A41 component')
    m = read(out/'prepared.json')
    require(m['frozen_sha256'] == FROZEN and m['baseline_version'] == '0.5.6-scene'
            and m['version'] == '0.5.7-scene', 'Component lineage changed')
    require(sha(candidate) == m['candidate_sha256'] and sha(out/'control.swf') == m['baseline_sha256'],
            'Production bytes changed')
    for name, digest in {**m['source'], **m['baseline_source'], **m['inputs'], **m['provenance']}.items():
        path = (out/name).resolve()
        require(path.is_relative_to(out) and sha(path) == digest, 'Frozen input changed: '+name)
    require(sha(Path(__file__).with_name('prepare_a40_wallblend.py')) ==
            sha(out/'provenance/prepare_a40_wallblend.py'), 'Comparison recipe changed')
    expected_changes = {'WallBlendMod.as', 'wallblend/BackgroundBlendLayer.as', 'wallblend/BlendLayer.as'}
    require(set(m['changed']) == expected_changes and
            set(m['source']) == {'src/'+n for n in m['parent_source']}, 'Source scope changed')
    for name, digest in m['parent_source'].items():
        old, new = out/'baseline-src'/name, out/'src'/name
        require(sha(old) == digest, 'Baseline source changed: '+name)
        if name not in expected_changes:
            require(sha(new) == digest, 'CS drawing code changed: '+name)
        else:
            text = old.read_text(encoding='utf-8-sig')
            expected = (replace_once(text, '"0.5.6-scene"', '"0.5.7-scene"') if name == 'WallBlendMod.as'
                        else optimized(text, Path(name).name))
            require(new.read_text(encoding='utf-8') == expected, 'Unreviewed transformation: '+name)
    check = read(out/'checks/WallKeyChecks-result.json')
    require(check['exit'] == 0 and check['passed'] == 15 and check['failed'] == 0 and check['complete']
            and check['installation_unchanged'] and check['prepared_sha256'] == PREPARED
            and check['candidate_sha256'] == m['candidate_sha256'], 'Semantic check incomplete')
    log = out/'checks/WallKeyChecks.log'
    require(sha(log) == check['log_sha256'] and 'COMPLETE exactComparisons=4859' in log.read_text(encoding='utf-8'),
            'Raw semantic result changed')
    require(sha(out/'checks/WallKeyChecks.swf') == check['swf_sha256'] == m['tests']['WallKeyChecks.swf'],
            'Semantic driver changed')
    native = out/'native'
    nm = read(native/'prepared.json')
    require(nm['candidate'] == m['candidate_sha256'] and nm['control'] == m['baseline_sha256']
            and nm['assets']['pfe.swf'] == HOST, 'Native production input mismatch')
    for name, row in nm['records'].items():
        require(sha(native/name) == row['adapted'], 'Native fixture changed: '+name)
    for name, digest in nm['swfs'].items():
        require(sha(native/name) == digest, 'Native driver changed: '+name)
    earlier = native/'evidence/candidate/Harness'
    original_failure = read(earlier/'receipt.json')
    require(original_failure['exit'] == 0xc0000005 and not original_failure['passed']
            and 'out of memory' in (earlier/'stdout.log').read_text(encoding='utf-8'),
            'Original memory-pressure failure was not preserved')
    require((earlier/'environment-failure.json').is_file(), 'Missing resource exhaustion evidence')
    interrupted = native/'evidence/memory-stable-01/control/Coverage'
    recovered = read(interrupted/'interrupted-run.json')
    require(recovered['qualified'] is False and recovered['exit_code'] is None
            and recovered['raw_native_passed'] is True and recovered['raw_native_assertions'] == 373
            and not (interrupted/'receipt.json').exists(), 'Interrupted run was reclassified')
    for name, digest in recovered['recovered'].items():
        path = (interrupted/name).resolve()
        require(path.parent == interrupted.resolve() and sha(path) == digest,
                'Recovered evidence changed: '+name)
    blocked = {}
    for attempt in ('session-recovery-02', 'session-recovery-03'):
        folder = native/'evidence'/attempt/'control/Coverage'
        require(read(folder/'memory-before.json')['free_commit_bytes'] < 6*1024**3
                and not (folder/'intent.json').exists(), 'Blocked preflight was reclassified')
        blocked[attempt] = sha(folder/'memory-before.json')
    runs = {}
    for role in ('control', 'candidate'):
        for kind, count in COUNTS.items():
            attempt = ATTEMPTS[kind]
            folder = native/'evidence'/attempt/role/kind
            intent = read(folder/'intent.json')
            require(intent['prepared'] == sha(native/'prepared.json') and intent['mod'] == nm[role]
                    and intent['host'] == HOST
                    and intent['attempt'] == attempt
                    and intent['harness'] == nm['swfs'][role+'/WallBlend'+kind+'.swf'], 'Native run mismatch')
            runs[role+'/'+kind] = verify_run(folder, count)
            runs[role+'/'+kind]['attempt'] = attempt
            runs[role+'/'+kind]['memory_sha256'] = verify_memory(folder, attempt != 'memory-stable-01')
    pair = out/'paired-01'
    pm = read(pair/'prepared.json')
    require(pm['parent_native'] == sha(native/'prepared.json'), 'Same-scene parent changed')
    for name, digest in pm['inputs'].items():
        require(sha(pair/name) == digest, 'Same-scene source changed: '+name)
    require(sha(pair/'WallNativePair.swf') == pm['swf'], 'Same-scene driver changed')
    evidence = pair/'evidence'
    require(read(evidence/'intent.json')['prepared'] == sha(pair/'prepared.json'), 'Same-scene intent changed')
    runs['same-scene'] = verify_run(evidence, 231)
    runs['same-scene']['memory_sha256'] = verify_memory(evidence, True)
    images = read(evidence/'receipt.json')['images']
    old_names = sorted(n for n in images if '-old-' in n)
    require(len(images) == 76 and len(old_names) == 38
            and set(images) == set(old_names) | {n.replace('-old-', '-new-') for n in old_names},
            'Incomplete original PNG set')
    pairs = []
    for name in old_names:
        with Image.open(evidence/name) as a, Image.open(evidence/name.replace('-old-', '-new-')) as b:
            before, after = a.convert('RGBA'), b.convert('RGBA')
            require(before.size == after.size and before.tobytes() == after.tobytes(),
                    'Same-scene pixel difference: '+name)
            pairs.append(dict(name=name, size=list(before.size), equal=True,
                              pixel_sha256=hashlib.sha256(before.tobytes()).hexdigest()))
    return dict(component_passed=True, deployment_qualified=False,
                prepared_sha256=PREPARED, candidate_sha256=m['candidate_sha256'],
                baseline_sha256=m['baseline_sha256'], host_sha256=HOST,
                semantic_groups=15, exact_comparisons=4859, runs=runs, exact_pixel_pairs=pairs,
                original_failure_sha256=sha(earlier/'receipt.json'),
                environment_failure_sha256=sha(earlier/'environment-failure.json'),
                interrupted_run_sha256=sha(interrupted/'interrupted-run.json'),
                blocked_preflight_sha256=blocked,
                remaining='Exact final runtime; unchanged joint density and continuity gates; final functional regression and normal-loader smoke.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.candidate), ensure_ascii=False, indent=2))
