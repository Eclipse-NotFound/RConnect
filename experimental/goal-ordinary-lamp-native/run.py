"""Paired ordinary-room LAD trial; unchanged native UI driver and checks."""
from pathlib import Path
import argparse, ast, difflib, hashlib, importlib.util, json, os, re, sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = HERE.with_name('goal-native-loading-native')
ENV = HERE.with_name('goal-native-loading-native-v2')
M52 = ROOT/'build/m52'
UI_PRODUCT = M52/'goal-native-loading-product-01'
UI_HOST = M52/'goal-native-loading-host-03'
DRIVER = M52/'goal-native-loading-probe-driver-01'
LAD_BUILD = HERE.with_name('goal-ordinary-lamp-product-build')
HOST_BUILD = HERE.with_name('goal-ordinary-lamp-host-build')
LAD_KEY = 'mods/LightAndDarkness/release/LightAndDarknessMod.swf'
LAD_BASE = '8adba6914df5aada4df12a646b6c22df4b95b9630a55dd05ca7f713621c7e3ef'
LAD_CANDIDATE = '8a127c99a49afb23d31b0889f833f56a1b50d7f52bb7abe49c3fad774c26c923'
HOST_BASE = '2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
RC_SHA = '9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
DRIVER_SHA = '877b05dacfca220f69345c3f83b4d8d2cc7796d6d03ea6389682fef7061d474a'


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text('utf-8-sig'))
def save(p, value):
    with Path(p).open('x', encoding='utf8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2); stream.write('\n')
def load(p, name):
    spec = importlib.util.spec_from_file_location(name, p)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


# The original shared runner has no module-candidate argument. Extend only the
# ordinary entry's existing isolated-copy branch and its actual module audit.
EDITS = (
    ("        if bridge is not None and bridge['sandy'] is not None:",
     "        if bridge is not None and (bridge['sandy'] is not None or bridge.get('lad') is not None):"),
    ("                if source.resolve() == GAME/'mods/Sandevistan/release/SandevistanMod.swf':",
     "                if source.resolve() == GAME/'mods/Sandevistan/release/SandevistanMod.swf' and bridge['sandy'] is not None:"),
    ("                return original_shutil.copy2(source, destination, *copy_args, **copy_kwargs)",
     "                if source.resolve() == GAME/'mods/LightAndDarkness/release/LightAndDarknessMod.swf' and bridge.get('lad') is not None:\n"
     "                    assert destination.resolve() == output/'frozen/mods/LightAndDarkness/release/LightAndDarknessMod.swf'\n"
     "                    assert not copied and sha(source) == before['mods/LightAndDarkness/release/LightAndDarknessMod.swf']\n"
     "                    source = Path(bridge['lad']); assert sha(source) == bridge['lad_sha256']\n"
     "                    copied.append(str(destination))\n"
     "                return original_shutil.copy2(source, destination, *copy_args, **copy_kwargs)"),
    ("                assert value == expected\n            for name, value in values.get('mod_assets', {}).items():",
     "                if name == 'mods/lightanddarkness/release/lightanddarknessmod.swf' and bridge.get('lad') is not None:\n"
     "                    expected = bridge['lad_sha256']\n"
     "                assert value == expected\n            for name, value in values.get('mod_assets', {}).items():"),
    ('                    assert all(not (preference.parent/name).exists() for name in ("native-loading-observer.json", "native-loading-terminal.png"))',
     '                    assert all(not (preference.parent/name).exists() for name in ("native-loading-observer.json", "native-loading-terminal.png", "LightAndDarkness.log"))'),
)


def expanded(recipe):
    text = recipe.ordinary_source()
    for old, new in EDITS:
        assert text.count(old) == 1, old
        text = text.replace(old, new, 1)
    ast.parse(text)
    return text


def source_check():
    m = read(HERE/'source-manifest.json')
    assert m['kind'] == 'ordinary-lamp-native-entry-v1' and m['ordinary_replacements'] == len(EDITS) == 5
    pins = {}
    for name, digest in m['inputs'].items():
        assert sha(name) == digest, name
        pins[name] = digest
    for name, digest in m['files'].items():
        assert sha(HERE/name) == digest, name
        pins[str(HERE/name)] = digest
    pins[str(HERE/'source-manifest.json')] = sha(HERE/'source-manifest.json')
    env = load(ENV/'run.py', 'ordinary_lamp_environment')
    pins.update(env.exact_pins())
    recipe = load(OLD/'recipe.py', 'ordinary_lamp_original_recipe')
    recipe.check()
    assert (HERE/'adapted-ordinary.py.txt').read_text('utf8') == expanded(recipe)
    return pins, env, recipe


def baseline_bundle(env):
    # Execute the already reviewed v2 expansion with its real original __file__.
    # Its historical and actual installations remain independently checked.
    ns = {'__file__': str(OLD/'run.py'), '__name__': 'ordinary_lamp_ui_baseline',
          'V2_HOST_BUILDER': env.V2/'build_host.py',
          'verify_historical_probe': env.verify_historical_probe,
          'verify_environment_change': env.verify_environment_change}
    exec(compile(env.adapted(), str(ENV/'adapted-entry.py.txt'), 'exec'), ns)
    ns['OPTIONS'] = argparse.Namespace(product=UI_PRODUCT, host=UI_HOST, drivers=DRIVER, admission=None)
    b = ns['bundle']()
    assert b['product'] == UI_PRODUCT and b['compile']['candidate_sha256'] == RC_SHA
    assert b['host'] == UI_HOST and b['host_receipt']['candidate_sha256'] == HOST_BASE
    assert b['driver'] == DRIVER and b['driver_proof']['artifacts']['timing/EffectsDriver.swf'] == DRIVER_SHA
    b.update(env.verify_environment_change(b['meta']['installation_before'], b['installation']))
    b['pins'].update(env.exact_pins())
    return b, ns


def admission(host, built):
    path = host/'runtime-admission.json'
    a = read(path)
    assert a['kind'] == 'ordinary-lamp-host-runtime-admission'
    assert a['validated'] is True and a['scope'] == 'native-test-only' and a['installed'] is False
    assert a['base_sha256'] == HOST_BASE and a['candidate_sha256'] == built['candidate_sha256']
    assert a['build_manifest_sha256'] == sha(host/'build.json')
    pins = {str(Path(p).resolve()): h for p, h in a['inputs'].items()}
    assert len(pins) == len(a['inputs'])
    for p, h in pins.items(): assert sha(p) == h, p
    semantic = Path(a['semantic_review']).resolve()
    required = [host/'pfe.swf', host/'build.json', host/'method-audit.json',
                host/'readback/scripts/fe/graph/Grafon.as', host/'pcode/scripts/fe/graph/Grafon.pcode', semantic]
    assert semantic.is_file() and semantic != path
    assert all(pins.get(str(p.resolve())) == sha(p) for p in required)
    pins[str(path)] = sha(path)
    return a, pins


def selected_bundle(options, env, pins):
    b, ui = baseline_bundle(env)
    b['pins'].update(pins)
    b.update(lad=None, lad_sha256=LAD_BASE, arm=options.arm)
    assert b['installation'][LAD_KEY] == LAD_BASE
    if options.arm == 'candidate':
        host, product = options.lamp_host, options.lamp_product
        required = [host/'build.json', host/'prepared.json', host/'pfe.swf', host/'runtime-admission.json',
                    product/'build.json', product/'prepared.json', product/'LightAndDarknessMod.swf']
        missing = [str(p) for p in required if not p.is_file()]
        if missing: raise ui['NotReady']('Missing actual lamp candidate or independent admission: '+json.dumps(missing))
        hb = load(HOST_BUILD/'build.py', 'ordinary_lamp_actual_host')
        pb = load(LAD_BUILD/'build.py', 'ordinary_lamp_actual_product')
        hc, pc = hb.verify(host), pb.verify(product)
        assert hc['compiled'] is True and hc['build_checks_passed'] is True and hc['validated'] is False
        assert hc['base_sha256'] == HOST_BASE and hc['splice']['rawResourcesPreserved'] is True
        assert hc['method_audit']['world_ui_bodies_byte_exact'] is True
        assert pc['passed'] is True and pc['compiled'] is True and pc['class_check_passed'] is True
        assert pc['candidate_sha256'] == LAD_CANDIDATE and len(pc['classes']) == 23
        assert hc['installation_before'] == hc['installation_after'] == pc['installation_before'] == pc['installation_after'] == b['installation']
        a, apins = admission(host, hc)
        b['pins'].update(apins); b['pins'].update(hc['inputs'])
        for folder, built in ((host, hc), (product, pc)):
            b['pins'][str(folder/'build.json')] = sha(folder/'build.json')
            for name, digest in built['artifacts'].items():
                assert sha(folder/name) == digest, name
                b['pins'][str(folder/name)] = digest
        b.update(host=host, host_receipt=hc, lamp_admission=a, lad=product/'LightAndDarknessMod.swf',
                 lad_sha256=pc['candidate_sha256'], lamp_product=pc,
                 lamp_build_environment=pc['installation_before'], lamp_host_build_environment=hc['installation_before'])
    return b, ui


def collect_lad(output, out, settings, roles):
    receipt = dict(before_copy_cleanup=True, roles={}, errors=[])
    for role in roles:
        appid = 'pfe-modsettings-rconnect-coop-'+role+'-'+output.name
        assert settings[role]['app_id'] == appid
        source = Path(settings[role]['preference']).parent/'LightAndDarkness.log'
        assert source.parent == Path(os.environ['APPDATA']).resolve()/appid/'Local Store'
        dest = out/'observer'/role/'LightAndDarkness.log'
        try:
            data = source.read_bytes()
            with dest.open('xb') as stream: stream.write(data)
            assert sha(dest) == sha(source)
            receipt['roles'][role] = dict(source=str(source), copied=str(dest), sha256=sha(dest), bytes=len(data))
        except Exception as error: receipt['errors'].append(role+': '+repr(error))
    save(out/'lamp-collected.json', receipt)
    assert not receipt['errors'], receipt['errors']


def parse_lad(path):
    text = path.read_text('utf-8-sig')
    assert text.count('[LightAndDarkness] v0.7.0 loaded') == 1
    errors = re.findall(r'\[LightAndDarkness\] (?:INITIAL_RASTER_PREPARE_FAILED|FRAME_ERROR|ATTACH_FAILED|PREPARE_FAILED|RESTORE_FAILED|SAVE_REJECT)[^\r\n]*', text)
    assert not errors, errors
    attached = re.findall(r'\[LightAndDarkness\] ATTACH room=(.*?) lamps=(\d+) beforeRaster=(\w+) state=(.*)', text)
    assert attached, 'No actual LAD attach logged: '+str(path)
    bakes = re.findall(r'\[LightAndDarkness\] BAKE ms=(\d+) preserved=(\d+)', text)
    return dict(log_sha256=sha(path), attaches=[dict(room=r, lamps=int(n), beforeRaster=f, state=s) for r,n,f,s in attached],
                bakes=[dict(milliseconds=int(ms), preserved_pixels=int(n)) for ms,n in bakes],
                any_lamps=any(int(n)>0 for _,n,_,_ in attached))


def lamp_evidence(out, roles, result):
    collection = read(out/'lamp-collected.json')
    assert collection['before_copy_cleanup'] is True and not collection['errors']
    assert set(collection['roles']) == set(roles)
    summary = {}
    for role in roles:
        path = out/'observer'/role/'LightAndDarkness.log'
        assert sha(path) == collection['roles'][role]['sha256']
        summary[role] = parse_lad(path)
        summary[role]['terminal_png_sha256'] = sha(out/'observer'/role/'native-loading-terminal.png')
    result.update(lamp_log_evidence=summary, lamp_visual_qualified=False, optimization_path_proven=False,
                  performance_qualified=False, lamp_collection_sha256=sha(out/'lamp-collected.json'),
                  lamp_evidence_limit='Original terminal PNG only; no first-raster fixture state/pixels or ticket consumption measurement. Logs use coarse wall-clock timestamps.')


def adopt_baseline(path, env):
    """Read the root's genuine old-v2 result; do not change it or rerun it."""
    assert path.parent == M52 and path.name == 'goal-native-loading-native-lamp-baseline-01'
    b,ui = baseline_bundle(env)
    result, intent = read(path/'result.json'), read(path/'intent.json')
    assert all(result[k] is True for k in ('passed','observer_passed','installation_unchanged','inputs_unchanged'))
    assert result['mode'] == 'dual' and result['candidate_sha256'] == RC_SHA
    assert intent['installation'] == b['installation'] and intent['candidate_sha256'] == RC_SHA
    assert intent['bridge']['host_sha256'] == HOST_BASE and intent['bridge']['sandy'] is None
    assert intent['inputs'] == b['pins']
    for name, digest in intent['inputs'].items(): assert sha(name) == digest, name
    run = Path(result['run']).resolve()
    assert run.parent == ROOT/'build/cooperation' and re.fullmatch('[0-9a-f]{10}', run.name)
    assert sha(run/'run.json') == result['run_sha256'] and sha(run/'input.json') == result['input_sha256']
    native = read(run/'run.json')
    assert native['sha256'] == RC_SHA and native['solo'] is False
    assert native['input_manifest_sha256'] == sha(run/'input.json')
    assert read(run/'registry-result.json')['passed'] is True
    assert result['exit_code'] == 0 and result['supplemental_errors'] == []
    assert {r:v['checks'] for r,v in result['roles'].items()} == {'host':23,'join':12}
    for role in ('host','join'):
        actual=native['inputs'][role]
        assert actual['game'] == HOST_BASE and actual['production'] == RC_SHA and actual['driver'] == DRIVER_SHA
        assert actual['modules'][next(k for k in actual['modules'] if k.replace('\\','/').lower()==LAD_KEY.lower())] == LAD_BASE
        log=run/(role+'.log'); assert sha(log)==result['roles'][role]['log_sha256']
        text=log.read_text('utf-8-sig')
        assert not re.search(r'^COOP FAIL |handoff timed out|TRAVEL CONFIG ERROR',text,re.M)
        rows=[json.loads(line.split('TRAVEL RESULT ',1)[1]) for line in text.splitlines() if line.startswith('TRAVEL RESULT ')]
        assert rows==result['roles'][role]['rows'] and [r['round'] for r in rows]==[0,1,2]
    memory=read(run/'memory-timeline.json')
    assert not memory['stopped_for_pressure'] and not memory['stopped_for_overlap']
    assert memory['minimum_commit_bytes']==512*1024**2 and not read(run/'air-before.json')
    assert all(not (run/n).exists() for n in ('host','join','frozen'))
    settings=read(path/'supplemental-input.json')['roles']
    ui['validate_observer'](path,run,['host','join'],settings,dict(result))
    lamps={role:parse_lad(run/'module-logs'/role/'LightAndDarkness.log') for role in ('host','join')}
    return dict(adopted_existing_baseline=True,air_started=False,original_result_unchanged=True,
                result=str(path/'result.json'),result_sha256=sha(path/'result.json'),run=str(run),
                checks={'host':23,'join':12},observer_checks={'host':11,'join':11},
                travel={role:result['roles'][role]['rows'] for role in ('host','join')},lamp_logs=lamps,
                lamp_visual_qualified=False,performance_qualified=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--arm', choices=['baseline','candidate'], default='baseline')
    ap.add_argument('--lamp-host', type=Path, default=M52/'goal-ordinary-lamp-host-02')
    ap.add_argument('--lamp-product', type=Path, default=M52/'goal-ordinary-lamp-product-01')
    ap.add_argument('--output', type=Path); ap.add_argument('--registry-wait', type=float, default=900)
    g=ap.add_mutually_exclusive_group(); g.add_argument('--source-check',action='store_true'); g.add_argument('--check',action='store_true')
    g.add_argument('--adopt-baseline',type=Path)
    options=ap.parse_args(); assert options.registry_wait>=0
    for name,prefix in (('lamp_host','goal-ordinary-lamp-host-'),('lamp_product','goal-ordinary-lamp-product-')):
        path=(ROOT/getattr(options,name)).resolve(); assert path.parent==M52 and path.name.startswith(prefix)
        setattr(options,name,path)
    if options.source_check or options.check or options.adopt_baseline: assert options.output is None
    else:
        assert options.output is not None
        output=(ROOT/options.output).resolve()
        assert output.parent==M52 and output.name.startswith('goal-ordinary-lamp-native-'+options.arm+'-') and not output.exists()
    pins,env,recipe=source_check()
    if options.source_check:
        print(json.dumps(dict(source_checked=True, actual_outputs_checked=False, air_started=False))); return 0
    if options.adopt_baseline:
        assert options.arm=='baseline'
        print(json.dumps(adopt_baseline((ROOT/options.adopt_baseline).resolve(),env),ensure_ascii=False)); return 0
    try: b,ui=selected_bundle(options,env,pins)
    except Exception as error:
        if not isinstance(error,FileNotFoundError) and type(error).__name__!='NotReady': raise
        # Missing real receipts are not replaced with a successful old admission.
        print(json.dumps(dict(ready=False,air_started=False,reason=repr(error)))); return 2
    def current_bundle():
        current,_,_=source_check(); assert current==pins
        return selected_bundle(options,env,pins)[0]
    def inputs(path):
        value=current_bundle(); assert path==value['product']
        return value['meta'],value['compile'],value['pins']
    def bridge(host_path,before,sandy):
        value=current_bundle(); assert host_path==value['host'] and before==value['installation'] and sandy is False
        return dict(host=str(value['host']/'pfe.swf'),host_sha256=value['host_receipt']['candidate_sha256'],
                    sandy=None,sandy_sha256=None,lad=None if value['lad'] is None else str(value['lad']),lad_sha256=value['lad_sha256'],
                    pins=value['pins'],scope='native-test-only',arm=options.arm,
                    build_environment=value['build_environment'],runtime_environment=value['runtime_environment'],
                    lamp_build_environment=value.get('lamp_build_environment'),lamp_host_build_environment=value.get('lamp_host_build_environment'),
                    ui_baseline_host_sha256=HOST_BASE,performance_qualified=False,lamp_visual_qualified=False)
    def collect(output,out,settings,roles):
        try: ui['collect_observer'](output,out,settings,roles)
        finally: collect_lad(output,out,settings,roles)
    def validate(out,run_path,roles,settings,result):
        ui['validate_observer'](out,run_path,roles,settings,result)
        lamp_evidence(out,roles,result)
        result.update(arm=options.arm,host_sha256=b['host_receipt']['candidate_sha256'],lad_sha256=b['lad_sha256'])
    ns={'__file__':str(recipe.ORDINARY),'__name__':'ordinary_lamp_bound_original'}
    exec(compile(expanded(recipe),str(HERE/'adapted-ordinary.py.txt'),'exec'),ns)
    ns.update(inputs=inputs,ui_bridge=bridge,UI_HOST=b['host'],PROBE_DONE=recipe.MARKER,
              DRIVER=b['driver'],DRIVER_SHA=DRIVER_SHA,RUNNER=OLD/'private_runner.py',
              collect_observer=collect,validate_observer=validate)
    prior=sys.argv
    sys.argv=[str(HERE/'run.py'),'--product',str(UI_PRODUCT),'--mode','dual','--registry-wait',str(options.registry_wait)]
    if options.check: sys.argv+=['--check']
    else: sys.argv+=['--output',str(options.output)]
    try:return ns['main']()
    finally:sys.argv=prior


if __name__=='__main__': raise SystemExit(main())
