"""Exact lamp diagnostic binding; unchanged three trips, private runner and limits."""
from pathlib import Path
import argparse, ast, difflib, hashlib, importlib.util, json, os, struct, sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
PARENT = HERE.parent
ROOT = HERE.parents[2]
M52 = ROOT / 'build/m52'
DRIVER = M52 / 'goal-ordinary-lamp-diagnostic-driver-01'
HOST = M52 / 'goal-ordinary-lamp-host-03'
PRODUCT = M52 / 'goal-ordinary-lamp-product-01'
DRIVER_SHA = '370f9d58d048665ad8e5f7d8e347d35c8879a7902e8ca6a8fe751d8752fb99a7'
HOST_SHA = '7b3cae6fe2d187fe05b94991ee81e8cb150371a9cc6be5738c7f00e45bc49b84'
MARKER = 'LAMP RASTER PROBE DONE '
SURFACES = ('front', 'back', 'back2', 'water', 'sats')
IMAGES = tuple('first-' + name + '-' + side + '.png' for name in SURFACES for side in ('before', 'after')) + ('native-alloff.png', 'native-allon.png')
LABELS = (
    'nonempty first native random room sampled',
    'four native layers and sats exactly match same-event native redraw',
    'world room player lamps physics and membership unchanged by redraw',
    'exactly one native redraw and original camera restored',
    'real native alloff observed by subsequent LAD callback',
    'real native allon observed by subsequent LAD callback',
    'only owned bitmap clones disposed and actual images saved',
    'no diagnostic errors',
)
PINS = {
    PARENT / 'run.py': 'c3a0a36d2ab28e4dd7200463a21fb37b9924df395697987fa79b0d693d6e3652',
    PARENT / 'source-manifest.json': 'c20133bbe417eb6bddbfdf6bc2f1afa085b6be71fa0310a0881afeaa241e84af',
    PARENT / 'diagnostic-build.py': '74fccc7726f39fabf06b26e178ceb3ba850d7f3f61654d79c07e2cb835fdd307',
    PARENT / 'diagnostic-src/source-manifest.json': '5e92b51563e349b621ed0f5e0da0180993030410e3ddd5a65911b0b1365524d4',
    DRIVER / 'prepared.json': '95fa79ec94449c1f56cc88f2542ec138f5edcae90b51d60ce5a3b53f8c6cf595',
    DRIVER / 'compile.json': '52a7637011998eebcc250da79b3cef1e7616956b6dbf5499a85edef372a8c6a8',
    HOST / 'runtime-admission.json': 'e08a39a170353ffe1acc6a77457aa89f56be7a61c393bdd8b11bbe7f64cfb205',
}
OLD_GUARD = '("native-loading-observer.json", "native-loading-terminal.png", "LightAndDarkness.log")'
NEW_GUARD = '("native-loading-observer.json", "native-loading-terminal.png", "LightAndDarkness.log", "ordinary-lamp")'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text('utf-8-sig'))
def save(p, value):
    with Path(p).open('x', encoding='utf8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2); stream.write('\n')
def load(p, name):
    spec = importlib.util.spec_from_file_location(name, p)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module
def expanded(base, recipe):
    text = base.expanded(recipe)
    assert text.count(OLD_GUARD) == 1
    text = text.replace(OLD_GUARD, NEW_GUARD, 1)
    ast.parse(text); return text
def source_check():
    for path, digest in PINS.items(): assert sha(path) == digest, str(path)
    base = load(PARENT / 'run.py', 'lamp_diagnostic_parent')
    pins, env, recipe = base.source_check()
    m = read(HERE / 'source-manifest.json')
    assert m['kind'] == 'ordinary-lamp-diagnostic-native-v1' and m['replacements'] == 1
    assert m['original'] == {str(p): h for p, h in PINS.items()}
    for name, digest in m['files'].items():
        assert sha(HERE / name) == digest, name
        pins[str(HERE / name)] = digest
    assert (HERE / 'adapted-ordinary.py.txt').read_text('utf8') == expanded(base, recipe)
    pins.update({str(p): h for p, h in PINS.items()})
    pins[str(HERE / 'source-manifest.json')] = sha(HERE / 'source-manifest.json')
    return base, env, recipe, pins
def bundle(base, env, pins):
    # Preserve the true old 877B/9C/2DB0 proof, then independently admit the
    # actual new host, LAD product and four-source 370F diagnostic driver.
    options = argparse.Namespace(arm='candidate', lamp_host=HOST, lamp_product=PRODUCT)
    b, ui = base.selected_bundle(options, env, pins)
    assert b['host'] == HOST and b['host_receipt']['candidate_sha256'] == HOST_SHA
    proof = load(PARENT / 'diagnostic-build.py', 'lamp_diagnostic_actual_builder').verify(DRIVER)
    assert proof['verified'] is True and proof['diagnosticOnly'] is True and proof['performanceQualified'] is False
    assert proof['build_environment'] == b['installation']
    assert proof['artifacts']['timing/EffectsDriver.swf'] == DRIVER_SHA
    assert proof['artifacts']['timing/EffectsHarness.swf'] == b['driver_proof']['artifacts']['timing/EffectsHarness.swf']
    assert proof['source_proof']['source_count'] == 4 and proof['source_proof']['additionalChecksPerRole'] == 8
    b['pins'].update(proof['inputs'])
    for name in ('prepared.json', 'compile.json', 'timing/EffectsDriver.swf', 'timing/EffectsHarness.swf'):
        b['pins'][str(DRIVER / name)] = sha(DRIVER / name)
    b.update(driver=DRIVER, driver_proof=proof)
    return b, ui
def collect(output, out, settings, roles):
    receipt = dict(before_copy_cleanup=True, roles={}, errors=[])
    assert roles == ['host', 'join'] and set(settings) == set(roles)
    for role in roles:
        appid = 'pfe-modsettings-rconnect-coop-' + role + '-' + output.name
        storage = Path(os.environ['APPDATA']).resolve() / appid / 'Local Store'
        assert settings[role]['app_id'] == appid and Path(settings[role]['preference']).parent == storage
        dest = out / 'observer' / role / 'ordinary-lamp'
        dest.mkdir(parents=True)
        receipt['roles'][role] = dict(app_id=appid, files={})
        for name in ('result.json',) + IMAGES:
            source, target = storage / 'ordinary-lamp' / name, dest / name
            try:
                raw = source.read_bytes()
                with target.open('xb') as stream: stream.write(raw)
                assert sha(source) == sha(target)
                receipt['roles'][role]['files'][name] = dict(source=str(source), copied=str(target), sha256=sha(target), bytes=len(raw))
            except Exception as error: receipt['errors'].append(role + ' ' + name + ': ' + repr(error))
    save(out / 'lamp-diagnostic-collected.json', receipt)
    assert not receipt['errors'], receipt['errors']
def png(path, row):
    raw = path.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n' and raw[12:16] == b'IHDR'
    assert raw[-12:] == b'\x00\x00\x00\x00IEND\xaeB`\x82'
    width, height = struct.unpack('>II', raw[16:24])
    assert 0 < width * height <= 24000000
    assert (width, height, len(raw)) == (row['width'], row['height'], row['bytes'])
    return dict(sha256=sha(path), width=width, height=height, bytes=len(raw))
def validate(out, run, roles, settings, result):
    collection = read(out / 'lamp-diagnostic-collected.json')
    assert collection['before_copy_cleanup'] is True and not collection['errors']
    assert set(collection['roles']) == set(roles) == {'host', 'join'}
    proofs = {}
    for role in roles:
        folder = out / 'observer' / role / 'ordinary-lamp'; doc = read(folder / 'result.json')
        assert doc['kind'] == 'ordinary-lamp-native-raster-diagnostic-v1' and doc['appId'] == settings[role]['app_id'] and doc['role'] == role
        assert doc['passed'] is True and doc['complete'] is True
        assert doc['diagnosticOnly'] is True and doc['performanceQualified'] is False and doc['optimizationPathProven'] is False
        assert doc['color_buffer_directly_observed'] is False and doc['faultCount'] == 0 and doc['faults'] == []
        assert [c['label'] for c in doc['checks']] == list(LABELS) and all(c['passed'] is True for c in doc['checks'])
        first = doc['first']; assert first['complete'] is True and first['round'] == 0 and first['exit'] == 19 and first['land'] == 'random_mane'
        assert first['lampCount'] > 0 and first['color_buffer_directly_observed'] is False
        assert [c['surface'] for c in first['comparisons']] == list(SURFACES)
        assert all(c['equal'] is True and c['compareCode'] == 0 and c['beforeId'] > 0 and c['afterId'] > 0 for c in first['comparisons'])
        assert first['stateUnchanged'] is True and first['before'] == first['after']
        state = first['before']; assert state['errorVisible'] is False
        assert all(type(state[k]) is int and state[k] > 0 for k in ('world', 'game', 'loc', 'player', 'grafon'))
        assert len(state['tiles']) == 1200 and len(state['lamps']) == first['lampCount']
        for key in ('bo', 'holder', 'proxy'):
            assert len({l[key] for l in state['lamps']}) == first['lampCount'] and all(l[key] > 0 for l in state['lamps'])
        assert first['cameraRestored'] is True and first['cameraBefore'] == first['cameraAfter'] and first['redrawDelta'] == 1
        for name, powered in (('off', False), ('on', True)):
            switched = doc[name]
            assert switched['complete'] is True and switched['observed'] >= switched['requested']
            assert len(switched['before']) == len(switched['after']) > 0
            for before, after in zip(switched['before'], switched['after']):
                assert all(before[k] == after[k] for k in ('bo', 'holder', 'proxy', 'hp'))
                assert after['powered'] is powered and after['nativeFrame'] == after['frame'] and after['proxyHp'] == after['hp']
        assert doc['ownedClones'] > 0 and doc['disposedClones'] == doc['ownedClones']
        assert len(doc['images']) == 12 and len({r['name'] for r in doc['images']}) == 12
        image_rows = {r['name']: r for r in doc['images']}; assert set(image_rows) == set(IMAGES)
        images = {name: png(folder / name, image_rows[name]) for name in IMAGES}
        assert set(collection['roles'][role]['files']) == {'result.json', *IMAGES}
        for name, row in collection['roles'][role]['files'].items():
            assert sha(folder / name) == row['sha256'] and (folder / name).stat().st_size == row['bytes']
        text = (run / (role + '.log')).read_text('utf-8-sig')
        markers = ['COOP EFFECTS DONE travel-timing ' + role, 'NATIVE LOADING PROBE DONE ' + role, MARKER + role]
        assert all(text.count(m) == 1 for m in markers) and text.index(markers[0]) < text.index(markers[1]) < text.index(markers[2])
        assert 'LAMP RASTER PROBE FAULT ' not in text and 'LAMP RASTER PROBE OUTPUT FAILED' not in text
        logged = [json.loads(line.split('LAMP RASTER PROBE RESULT ', 1)[1]) for line in text.splitlines() if line.startswith('LAMP RASTER PROBE RESULT ')]
        assert len(logged) == 1 and logged[0] == dict(role=role, passed=True, checks=doc['checks'], faultCount=0, images=12)
        proofs[role] = dict(result_sha256=sha(folder / 'result.json'), checks=8, lampCount=first['lampCount'], images=images,
                            same_event_native_surfaces_equal=True, local_native_switches_observed=True)
    result.update(lamp_diagnostic_passed=True, lamp_diagnostic=proofs,
                  lamp_diagnostic_collection_sha256=sha(out / 'lamp-diagnostic-collected.json'),
                  performance_qualified=False, optimization_path_proven=False,
                  lamp_visual_qualified=False, lamp_visual_limit='Exact native buffers and local switches only; screenshots require review; no direct colorBmp, rollback or network switch proof.')
def prepare_source():
    assert not (HERE / 'source-manifest.json').exists(), 'Do not rewrite frozen inputs'
    base = load(PARENT / 'run.py', 'lamp_diagnostic_prepare_parent')
    _, _, recipe = base.source_check()
    text = expanded(base, recipe)
    with (HERE / 'adapted-ordinary.py.txt').open('x', encoding='utf8', newline='\n') as stream: stream.write(text)
    diff = ''.join(difflib.unified_diff(base.expanded(recipe).splitlines(True), text.splitlines(True), fromfile='frozen-lamp/adapted-ordinary.py.txt', tofile='lamp-diagnostic/adapted-ordinary.py.txt'))
    with (HERE / 'source.diff').open('x', encoding='utf8', newline='\n') as stream: stream.write(diff)
    save(HERE / 'source-manifest.json', dict(kind='ordinary-lamp-diagnostic-native-v1', replacements=1,
         original={str(p): h for p, h in PINS.items()}, files={name: sha(HERE / name) for name in ('run.py', 'README.md', 'adapted-ordinary.py.txt', 'source.diff')},
         air_started=False, installed=False, diagnosticOnly=True, performanceQualified=False))
    source_check()
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    modes = ap.add_mutually_exclusive_group(); modes.add_argument('--prepare-source', action='store_true'); modes.add_argument('--source-check', action='store_true'); modes.add_argument('--check', action='store_true')
    ap.add_argument('--output', type=Path); ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args(); assert args.registry_wait >= 0
    if args.prepare_source:
        assert args.output is None; prepare_source(); print('Diagnostic text prepared; no AIR'); return 0
    base, env, recipe, pins = source_check()
    if args.source_check:
        assert args.output is None; print('Diagnostic source verified; no AIR'); return 0
    if args.check: assert args.output is None
    else:
        assert args.output is not None
        output = (ROOT / args.output).resolve()
        assert output.parent == M52 and output.name.startswith('goal-ordinary-lamp-diagnostic-native-') and not output.exists()
    b, ui = bundle(base, env, pins)
    def current():
        _, _, _, checked = source_check(); assert checked == pins
        return bundle(base, env, pins)[0]
    def inputs(path):
        value = current(); assert path == value['product']; return value['meta'], value['compile'], value['pins']
    def bridge(host_path, before, sandy):
        value = current(); assert host_path == HOST and before == value['installation'] and sandy is False
        return dict(host=str(HOST / 'pfe.swf'), host_sha256=HOST_SHA, sandy=None, sandy_sha256=None,
                    lad=str(value['lad']), lad_sha256=value['lad_sha256'], pins=value['pins'], scope='native-test-only',
                    diagnosticOnly=True, performance_qualified=False, lamp_visual_qualified=False,
                    build_environment=value['build_environment'], runtime_environment=value['runtime_environment'],
                    diagnostic_build_environment=value['driver_proof']['build_environment'])
    def collect_all(output, out, settings, roles):
        try: ui['collect_observer'](output, out, settings, roles)
        finally:
            try: base.collect_lad(output, out, settings, roles)
            finally: collect(output, out, settings, roles)
    def validate_all(out, run, roles, settings, result):
        ui['validate_observer'](out, run, roles, settings, result)
        base.lamp_evidence(out, roles, result)
        validate(out, run, roles, settings, result)
        result.update(diagnosticOnly=True, host_sha256=HOST_SHA, lad_sha256=b['lad_sha256'], diagnostic_driver_sha256=DRIVER_SHA)
    ns = {'__file__': str(recipe.ORDINARY), '__name__': 'lamp_diagnostic_bound_ordinary'}
    exec(compile(expanded(base, recipe), str(HERE / 'adapted-ordinary.py.txt'), 'exec'), ns)
    ns.update(inputs=inputs, ui_bridge=bridge, UI_HOST=HOST, PROBE_DONE=MARKER,
              DRIVER=DRIVER, DRIVER_SHA=DRIVER_SHA, RUNNER=base.OLD / 'private_runner.py',
              collect_observer=collect_all, validate_observer=validate_all)
    prior = sys.argv
    sys.argv = [str(HERE / 'run.py'), '--product', str(base.UI_PRODUCT), '--mode', 'dual', '--registry-wait', str(args.registry_wait)]
    sys.argv += ['--check'] if args.check else ['--output', str(args.output)]
    try: return ns['main']()
    finally: sys.argv = prior

if __name__ == '__main__':
    raise SystemExit(main())
