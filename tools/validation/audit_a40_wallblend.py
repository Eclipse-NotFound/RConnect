"""Read-only audit of the approved A40 WallBlend component, not a release gate.

The separate-process image differences remain recorded. The strict image proof
uses both production binaries on the same native scene. Joint RConnect density
and continuity gates are still required before installation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

from release_a22_map import ROOT, sha, read, require
import prepare_a40_wallblend as recipe


PREPARED = 'd5cdc6e61b096414a68e7b50c36037a99476d89e3e519653781194cb5cc15d4d'
COUNTS = {'Harness': 43, 'Destruction': 54, 'Coverage': 373, 'Scene': 30, 'Field': 25}


def verify_run(folder, count):
    receipt, result = read(folder/'receipt.json'), read(folder/'result.json')
    require(receipt['exit'] == 0 and receipt['passed'] is True
            and receipt['checks'] == count and not receipt['failures']
            and not receipt['installation_changes'], 'Incomplete component run: '+str(folder))
    require(result['passed'] is True and len(result['assertions']) == count
            and all(item['passed'] is True for item in result['assertions']),
            'Raw assertions differ: '+str(folder))
    stdout = (folder/'stdout.log').read_text(encoding='utf-8', errors='replace')
    require(re.search(r'\b(?:Error\s*#\d+|TypeError|ReferenceError|RangeError|VerifyError|uncaught|out of memory)\b',
                      stdout, re.I) is None, 'Native exception: '+str(folder))
    for name, digest in receipt['images'].items():
        path = (folder/name).resolve()
        require(path.parent == folder.resolve() and sha(path) == digest, 'Image changed: '+name)
    return dict(receipt_sha256=sha(folder/'receipt.json'), result_sha256=sha(folder/'result.json'),
                intent_sha256=sha(folder/'intent.json'), checks=count)


def audit(candidate):
    candidate = Path(candidate).resolve()
    require(candidate.parent.parent == ROOT/'build/m52' and candidate.name == 'WallBlendMod.swf',
            'Unexpected WallBlend candidate path')
    out = candidate.parent
    require(sha(out/'prepared.json') == PREPARED, 'Not the reviewed A40 component')
    m = read(out/'prepared.json')
    require(sha(recipe.__file__) == m['preparer_sha256'], 'Reviewed transformation recipe changed')
    require(sha(candidate) == m['candidate_sha256'] and sha(out/'control.swf') == m['baseline_sha256'],
            'Production bytes changed')
    for name, digest in {**m['source'], **m['inputs']}.items():
        require(sha(out/name) == digest, 'Frozen component input changed: '+name)
    upstream_changes = {}
    require(set(m['source']) == {'src/'+name for name in m['parent_source']}, 'Source inventory changed')
    require(set(m['changed']) == {'WallBlendMod.as', 'wallblend/BackgroundBlendLayer.as',
                                  'wallblend/BlendLayer.as'}, 'Scope changed')
    for name, digest in m['parent_source'].items():
        source = recipe.BASE/name
        current = sha(source)
        if current != digest:
            upstream_changes[name] = dict(frozen=digest, current=current)
        # The generated CS tree is mutable. The pinned preparation above binds
        # the reviewed transform and every frozen source byte; a later CS edit
        # must be reported for release coordination, not used as its preimage.
        if name not in m['changed']:
            require(m['source']['src/'+name] == digest, 'Unapproved component change: '+name)
    check = read(out/'checks/WallKeyChecks-result.json')
    require(check['exit'] == 0 and check['passed'] == 15 and check['failed'] == 0 and check['complete']
            and check['installation_unchanged'] and check['prepared_sha256'] == PREPARED
            and check['candidate_sha256'] == m['candidate_sha256'], 'Semantic checks incomplete')
    require(sha(out/'checks/WallKeyChecks.swf') == check['swf_sha256'] == m['tests']['WallKeyChecks.swf'],
            'Semantic driver changed')
    native = out/'native'
    nm = read(native/'prepared.json')
    require(nm['candidate'] == m['candidate_sha256'] and nm['control'] == m['baseline_sha256'],
            'Native suite production mismatch')
    for name, row in nm['records'].items():
        require(sha(native/name) == row['adapted'], 'Native test source changed: '+name)
    for name, digest in nm['swfs'].items():
        require(sha(native/name) == digest, 'Native driver changed: '+name)
    runs = {}
    for role in ('control', 'candidate'):
        for kind, count in COUNTS.items():
            folder = native/'evidence'/role/kind
            intent = read(folder/'intent.json')
            require(intent['prepared'] == sha(native/'prepared.json') and intent['mod'] == nm[role]
                    and intent['harness'] == nm['swfs'][role+'/WallBlend'+kind+'.swf'], 'Native input mismatch')
            runs[role+'/'+kind] = verify_run(folder, count)
    pair = out/'paired-04'
    pm = read(pair/'prepared.json')
    require(pm['parent_native'] == sha(native/'prepared.json'), 'Same-scene parent changed')
    for name, digest in pm['inputs'].items():
        require(sha(pair/name) == digest, 'Same-scene source changed: '+name)
    evidence = pair/'evidence'
    require(read(evidence/'intent.json')['prepared'] == sha(pair/'prepared.json'), 'Same-scene intent changed')
    runs['same-scene'] = verify_run(evidence, 231)
    pixels = read(evidence/'pixel-audit.json')
    require(pixels['passed'] is True and len(pixels['pairs']) == 38, 'Incomplete image proof')
    require(len(read(evidence/'receipt.json')['images']) == 76, 'Incomplete original PNGs')
    for row in pixels['pairs']:
        old, new = evidence/row['name'], evidence/row['name'].replace('-old-', '-new-')
        require(old != new and old.parent == new.parent == evidence, 'Invalid image pair')
        with Image.open(old) as a, Image.open(new) as b:
            before, after = a.convert('RGBA'), b.convert('RGBA')
            require(row['equal'] and list(before.size) == row['size'] == list(after.size)
                    and before.tobytes() == after.tobytes()
                    and hashlib.sha256(before.tobytes()).hexdigest() == row['pixel_sha256'],
                    'Same-scene pixels differ: '+old.name)
    earlier = native/'pixel-comparison-all.json'
    require(read(earlier)['passed'] is False, 'Original separate-process failure was overwritten')
    return dict(component_passed=True, deployment_qualified=False, candidate_sha256=m['candidate_sha256'],
                baseline_sha256=m['baseline_sha256'], prepared_sha256=PREPARED, runs=runs,
                exact_pixel_pairs=38, semantic_groups=15,
                upstream_source_changes=upstream_changes,
                semantic_receipt_sha256=sha(out/'checks/WallKeyChecks-result.json'),
                pixel_receipt_sha256=sha(evidence/'pixel-audit.json'),
                earlier_pixel_failure_sha256=sha(earlier),
                remaining='Resolve any upstream source changes with its owner; unchanged joint density and continuity gates; final exact-combination regression and normal-loader smoke.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.candidate), ensure_ascii=False, indent=2))
