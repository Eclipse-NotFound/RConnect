"""Freeze exact recovery21 plus its tested two final ordinary-wall setters.
Only AS/text preparation; the existing formal compiler remains the sole entry.
"""
from pathlib import Path
import difflib, importlib.util, json, shutil, sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
HELPER = ROOT / 'experimental/recovery-wall-encode-buildsrc/prepare_sources.py'
spec = importlib.util.spec_from_file_location('reviewed_source_freeze', HELPER)
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)
sha, read, save, inventory = shared.sha, shared.read, shared.save, shared.inventory
BASE = ROOT / 'build/m52/recovery-21'
OVERLAY = ROOT / 'experimental/recovery21-small-wall-component'
COMPONENT = ROOT / 'build/m52/recovery21-small-wall-component-01'
BASE_SHA = '9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba'
OVERLAY_HANDOFF = '0af11fe8ea666131664a687b82ccb1228ce2097f8cce3fccdff9a668b7472ba7'
COMPONENT_SHA = 'c456e3fae4f692ab5de2252886698032025656fec6e47b301ed559059a649dd0'
WALL = 'rconnect/game/WallImpactVisuals.as'
VERSION = '0.2.24-recovery22'
OLD_VERSION = b'0.2.24-recovery21'
SETTERS = (
    (b'b.setPixel32(x,y,color);', b'b.setPixel32(x,y,NativeWallColor.setter(color));'),
    (b'b.setPixel32(x,y,uint(c.values[key]));', b'b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));'),
)


def exact_wall(before):
    for old, new in SETTERS:
        assert before.count(old) == 1 and new not in before
        before = before.replace(old, new, 1)
    return before


def verify():
    integrated = read(HERE / 'integration.json')
    actual = inventory(HERE / 'src')
    assert actual == {r['path']: r['sha256'] for r in integrated['source']}
    for path, digest in integrated['input_sources'].items():
        assert sha(Path(path)) == digest, path
    base = read(BASE / 'prepared.json')['source']
    assert inventory(BASE / 'src') == base and len(base) == len(actual) == 90
    assert all(name.endswith('.as') for name in actual)
    changed = {p for p in set(base) | set(actual) if base.get(p) != actual.get(p)}
    assert changed == {WALL, 'RConnectMod.as'}, changed
    after = (HERE / 'src' / WALL).read_bytes()
    assert after == (OVERLAY / 'src' / WALL).read_bytes() == (COMPONENT / 'src' / WALL).read_bytes()
    assert after == exact_wall((BASE / 'src' / WALL).read_bytes())
    before = (BASE / 'src/RConnectMod.as').read_bytes()
    assert before.count(OLD_VERSION) == 1
    assert (HERE / 'src/RConnectMod.as').read_bytes() == before.replace(OLD_VERSION, VERSION.encode('ascii'))
    assert (HERE / 'ancestor-integration.json').read_bytes() == (BASE / 'integration.json').read_bytes()
    for path, digest in integrated['patches'].items():
        assert sha(HERE / path) == digest, path
    assert read(HERE / 'component-review.json') == integrated['component']
    assert not integrated['static_errors'] and integrated['version'] == VERSION
    return dict(passed=True, base_files=90, output_files=90, unchanged_base_files=88,
        changed=sorted(changed), class_overlay_byte_exact=True, exact_final_setter_changes=2,
        decode_optimizations_preserved=True, version_only_entry_change=True,
        component_assertions=85, component_failed=0, JVMStarted=False, AIRStarted=False,
        compiled=False, native_game_tested=False, performance_qualified=False, installed=False)


def main():
    assert not (HERE / 'src').exists(), 'Complete snapshot exists; use --verify, do not overwrite'
    assert sha(BASE / 'RConnectMod.swf') == BASE_SHA
    assert sha(OVERLAY / 'handoff.json') == OVERLAY_HANDOFF
    for path, digest in read(OVERLAY / 'handoff.json')['files'].items():
        assert sha(OVERLAY / path) == digest, path
    overlay_spec = importlib.util.spec_from_file_location('tested_small_wall_overlay', OVERLAY / 'prepare.py')
    overlay = importlib.util.module_from_spec(overlay_spec)
    overlay_spec.loader.exec_module(overlay)
    overlay.verify()
    base = read(BASE / 'prepared.json')
    assert base['compiled'] and base['version'] == OLD_VERSION.decode('ascii') and base['sha256'] == BASE_SHA
    assert inventory(BASE / 'src') == base['source'] and len(base['source']) == 90
    assert sha(BASE / 'integration.json') == base['integration_sha256']
    receipt = read(COMPONENT / 'receipt.json')
    raw = read(COMPONENT / 'component-result.json')
    intent = read(COMPONENT / 'intent.json')
    assert receipt['passed'] is True and receipt['observed_checks'] == 85 and receipt['checks_failed'] == 0
    assert receipt['installation_unchanged'] and receipt['source_unchanged'] and receipt['exit_code'] == 0
    assert receipt['native_game_test'] is False and receipt['performance_qualified'] is False
    assert raw['count'] == len(raw['assertions']) == 85 and all(r['passed'] is True for r in raw['assertions'])
    assert raw['passed'] is True and raw['failed'] == 0
    assert sha(COMPONENT / 'Checks.swf') == receipt['component_sha256'] == COMPONENT_SHA
    assert intent['expected'] == 85
    assert inventory(OVERLAY / 'components') == intent['sources'] == inventory(COMPONENT / 'src')
    assert (OVERLAY / 'src' / WALL).read_bytes() == exact_wall((BASE / 'src' / WALL).read_bytes())
    inputs = [BASE / 'RConnectMod.swf', BASE / 'prepared.json', BASE / 'integration.json',
        OVERLAY / 'handoff.json', OVERLAY / 'inputs.json', OVERLAY / 'prepare.py',
        COMPONENT / 'receipt.json', COMPONENT / 'component-result.json', COMPONENT / 'intent.json',
        COMPONENT / 'Checks.swf', HELPER, Path(__file__), ROOT / 'tools/validation/prepare_recovery.py']
    inputs.extend(BASE / 'src' / name for name in base['source'])
    inputs.extend(COMPONENT / 'src' / name for name in intent['sources'])
    inputs.extend(OVERLAY / 'components' / name for name in intent['sources'])
    inputs.append(OVERLAY / 'src' / WALL)
    pinned = {str(p): sha(p) for p in inputs}
    shutil.copytree(BASE / 'src', HERE / 'src')
    shutil.copyfile(OVERLAY / 'src' / WALL, HERE / 'src' / WALL)
    entry = HERE / 'src/RConnectMod.as'
    data = entry.read_bytes()
    assert data.count(OLD_VERSION) == 1
    entry.write_bytes(data.replace(OLD_VERSION, VERSION.encode('ascii')))
    shutil.copyfile(BASE / 'integration.json', HERE / 'ancestor-integration.json')
    for name, target in [(WALL, 'two-setters.patch'), ('RConnectMod.as', 'version.patch')]:
        diff = difflib.unified_diff((BASE / 'src' / name).read_text(encoding='utf-8-sig').splitlines(True),
            (HERE / 'src' / name).read_text(encoding='utf-8-sig').splitlines(True),
            fromfile='recovery21/src/' + name, tofile='recovery22/src/' + name)
        (HERE / target).write_text(''.join(diff), encoding='utf-8', newline='\n')
    review = dict(directory=str(COMPONENT), assertions=85, failed=0, component_sha256=COMPONENT_SHA,
        receipt_sha256=sha(COMPONENT / 'receipt.json'), result_sha256=sha(COMPONENT / 'component-result.json'),
        original_inputs_sha256=sha(COMPONENT / 'intent.json'), installation_unchanged=True, source_unchanged=True,
        exact_tested_wall_class_sha256=sha(COMPONENT / 'src' / WALL),
        production_dependency_classes_byte_exact=True, native_game_test=False, performance_qualified=False,
        assertion_labels=[r['label'] for r in raw['assertions']])
    save(HERE / 'component-review.json', review)
    sources = inventory(HERE / 'src')
    integration = dict(version=VERSION, compiled=False, runtime_tested=False, diagnostic_only=False,
        baseline='build/m52/recovery-21', baseline_sha256=BASE_SHA, baseline_manifest_sha256=sha(BASE / 'prepared.json'),
        ancestor_integration_sha256=sha(BASE / 'integration.json'), ancestor_integration_copy='ancestor-integration.json',
        input_sources=pinned, layers=[dict(name='tested-ordinary-wall-final-color-setters',
            source='experimental/recovery21-small-wall-component/src', source_handoff_sha256=OVERLAY_HANDOFF,
            files=[dict(path=WALL, ancestor_sha256=base['source'][WALL], sha256=sources[WALL], merge='exact tested overlay bytes')])],
        version_change=dict(path='RConnectMod.as', old=OLD_VERSION.decode('ascii'), new=VERSION),
        patches={name: sha(HERE / name) for name in ('two-setters.patch', 'version.patch')}, component=review,
        source=[dict(path=name, sha256=digest) for name, digest in sources.items()], static_errors=[],
        unchanged_class_count=88, complete_class_count=90, small_room_setters_included=True,
        native_game_tested=False, performance_qualified=False, installed=False)
    save(HERE / 'integration.json', integration)
    checks = verify()
    save(HERE / 'static-checks.json', checks)
    print(json.dumps(checks, ensure_ascii=False))
    print('integration_sha256=' + sha(HERE / 'integration.json'))


if __name__ == '__main__':
    if '--verify' in sys.argv:
        print(json.dumps(verify(), ensure_ascii=False))
    else:
        main()
