"""Read-only independent check of the first early host's preserved failure.

The only additional equivalence is one uninitialized function-local declaration
hoisted by FFDec in unchanged World.init2. All executable statements stay exact.
No compiler, AIR, installed writes or gameplay/performance qualification.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from baseline import assert_current

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / 'experimental/recovery-early-travel/prepare_host.py'
spec = importlib.util.spec_from_file_location('early_recipe', SOURCE)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
HOST = ROOT / 'build/m52/recovery-early-host-01'
PIN = '2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29'


def check_init(before, after):
    old = h.token(before)
    new = h.token(after)
    start = 'internalfunctioninit2():*{'
    declaration = 'var_loc1_:*=0;'
    assert old.startswith(start) and old.count(declaration) == 1
    prefix = old.split(declaration)[0]
    assert '_loc1_' not in prefix, 'No earlier read of the moved local is allowed'
    expected = old.replace(start, start + 'var_loc1_:*;', 1)
    expected = expected.replace(declaration, '_loc1_=0;', 1)
    assert new == expected, 'Only this declaration relocation is equivalent'


def check_negatives(before, after):
    check_init(before, after)
    mutations = [
        after.replace('_loc1_ = 0;', '_loc1_ = 1;', 1),
        after.replace('var _loc1_:*;', 'var _loc1_:int;', 1),
        after.replace('var _loc1_:*;', 'var _loc1_:* = 0;', 1),
        after.replace('this.saveKol', 'this.autoSaveN', 1),
    ]
    for modified in mutations:
        assert modified != after
        try:
            check_init(before, modified)
        except AssertionError:
            pass
        else:
            raise AssertionError('Changed executable statement/declaration accepted')
    return 5


def verify():
    meta = h.read(HOST / 'prepared.json')
    assert meta['compiled'] and not meta['validated']
    assert meta['error'] == "('fe.World', 'init2')"
    assert meta['kind'] == 'isolated-early-travel-host'
    assert meta['candidate_sha256'] == h.sha(HOST / 'pfe.swf') == PIN
    assert meta['base_sha256'] == h.PIN and h.sha(h.BASE / 'pfe.swf') == h.PIN
    assert meta['source_unchanged'] and meta['installation_unchanged']
    assert not any(meta[k] for k in ('air_started', 'installed', 'gameplay_qualified', 'performance_qualified'))
    assert meta['patched_classes'] == list(h.PATCHED)
    for path, digest in meta['inputs'].items():
        assert h.sha(path) == digest, path
    for path, digest in meta['readback_files'].items():
        assert h.sha(HOST / path) == digest, path
    assert set(meta['import_sources']) == {'fe/World.as', 'fe/loc/Game.as'}
    assert {p.relative_to(HOST / 'import').as_posix() for p in (HOST / 'import').rglob('*.as')} == set(meta['import_sources'])
    for path, digest in meta['import_sources'].items():
        assert h.sha(HOST / 'import' / path) == digest

    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from prepare_recovery_native_travel import normalized, movie_header
    from run_security_terminals import installation
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    from patch_native import swf_tags
    installed = installation()
    assert_current(installed,meta['installation_before'])
    checked = {}
    for cls in h.PATCHED:
        rel = Path(*cls.split('.')).with_suffix('.as')
        before = h.text(HOST / 'before/scripts' / rel)
        after = h.text(HOST / 'after/scripts' / rel)
        expected = h.text(HOST / 'import' / rel)
        assert normalized(before) == normalized(h.text(h.BASE / 'after/scripts' / rel))
        if cls == 'fe.World':
            b = h.methods(before)['init2']
            a = h.methods(after)['init2']
            checks = check_negatives(b, a)
            assert after.count(a) == 1
            # The complete init2 equivalence was checked above, not ignored.
            after = after.replace(a, b, 1)
        h.verify_readback(cls, before, after, expected)
        checked[cls] = len(h.methods(after))
    representatives = {}
    for cls in h.REPRESENTATIVES:
        rel = Path(*cls.split('.')).with_suffix('.as')
        a = normalized(h.text(HOST / 'before/scripts' / rel))
        b = normalized(h.text(HOST / 'after/scripts' / rel))
        assert a == b, cls
        representatives[cls] = hashlib.sha256(a.encode()).hexdigest()
    before, after = swf_tags(h.BASE / 'pfe.swf'), swf_tags(HOST / 'pfe.swf')
    assert len(before) == len(after)
    changed = []
    for i, (b, a) in enumerate(zip(before, after)):
        assert a[0] == b[0]
        if a != b:
            assert a[0] in (72, 82)
            changed.append(i)
    assert changed and movie_header(h.BASE / 'pfe.swf') == movie_header(HOST / 'pfe.swf')
    assert normalized(h.text(HOST / 'before-classes.txt')) == normalized(h.text(HOST / 'after-classes.txt'))
    for name in ('before.log', 'import.log', 'after.log', 'before-classes.txt', 'after-classes.txt'):
        for path in (HOST / name, HOST / (name + '.stderr.log')):
            assert not any(x in h.text(path) for x in ('SEVERE:', 'Unknown preprocessor instruction', 'Exception in thread')), path
    assert installation() == installed
    return dict(kind='isolated-early-host-independent-recheck', validated=True,
        candidate_sha256=PIN, base_sha256=h.PIN,
        manifest_sha256=h.sha(HOST / 'prepared.json'), recipe_sha256=h.sha(__file__),
        source_handoff_sha256=h.sha(h.HERE / 'handoff.json'), original_failed_receipt_preserved=True,
        method_counts=checked, declaration_equivalence_and_negative_checks=checks,
        representative_normalized_sha256=representatives, changed_code_tags=changed,
        non_code_tags_unchanged=True, movie_header_unchanged=True, class_list_unchanged=True,
        installation_unchanged=True, gameplay_qualified=False, performance_qualified=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = (ROOT / args.output).resolve()
    assert output.parent == ROOT / 'build/m52' and not output.exists()
    receipt = verify()
    output.mkdir()
    h.save(output / 'receipt.json', receipt)
    print(json.dumps(receipt, ensure_ascii=False))
