"""Unchanged twelve-round hidden-room checks, explicitly rebound to nativeui1."""
from pathlib import Path
import ast,difflib,hashlib,importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1];M52=ROOT/'build/m52'
SOURCE=HERE.with_name('recovery-room-repair-review')/'run_hidden_v3.py'
SOURCE_SHA='7cf2fcbc2ff8235635cba11e0298d7c8cb23d405f1914042eab30313f5351eef'
UI=HERE.with_name('goal-native-loading-native-v2')
UI_SHA='a5b2ce70fcef52bd5960715fb0d29289f5124acf5139387db92e30aefc1782f3'
UI_MANIFEST_SHA='7d62b3d6e7f159bdf91427a3543027bab7f5069628364c25ce09d5a4710dc840'
PRODUCT=M52/'goal-native-loading-product-01';HOST_DIR=M52/'goal-native-loading-host-03'
CANDIDATE='9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
HOST='2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
ADMISSION=HOST_DIR/'runtime-admission.json'
ADMISSION_SHA='4fda39f7ed42338c9f3a7d88bfa35e17e86ea36694bab8bf99e74ac445175ade'
SHARED=ROOT/'tools/run_coop_regression.py'
SHARED_SHA='7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
VERSION='0.2.24-nativeui1'
PREFERENCE=b'{"nativeEnabled":false}'
TELEMETRY=GAME/'mods/ModLoader/release/telemetry.json'
class NotReady(Exception):pass
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def save(p,value):
    with Path(p).open('x',encoding='utf8') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
def adapted():
    assert sha(SOURCE)==SOURCE_SHA
    text=SOURCE.read_text('utf8')
    text=once(text,'from current_rv_verifier import ROOT,M52,GAME,RUNNER,installation,sha,read,save,evidence\nimport current_rv_verifier as current_runtime',
              '# Explicit current UI binding supplied by this independent adapter.')
    start=text.index('PRODUCT=M52/');end=text.index('ARTIFACTS=',start)
    text=text[:start]+"OLD=M52/'a22-testpack-15-04'\nDRIVER=OLD/'build/driver-qualified-hidden'\n"+text[end:]
    start=text.index('def preflight():\n');end=text.index(' # Historical proof validates',start)
    text=text[:start]+'def preflight():\n before,pins=hidden_preflight()\n'+text[end:]
    text=once(text,'assert out.parent==M52 and not out.exists()',
              "assert out.parent==M52 and out.name.startswith('goal-native-loading-hidden-') and not out.exists()")
    text=once(text," save(out/'intent.json',dict(command=command,inputs=pins,installation=before,",
              " command += ['--game-candidate',str(HOST_DIR/'pfe.swf')]\n save(out/'intent.json',dict(command=command,inputs=pins,installation=before,")
    text=once(text,'runtime_admission=evidence(),recompiled=False,no_game_override=True,no_other_mod_override=True',
              'runtime_admission=ui_evidence(),recompiled=False,no_game_override=False,no_other_mod_override=True')
    text=once(text,"  memory=read(run/'memory-timeline.json');",
              "  validate_private_settings(run,out)\n  memory=read(run/'memory-timeline.json');")
    return text
def source_inputs():
    m=read(HERE/'source-manifest.json')
    assert m['kind']=='native-loading-hidden-only-v1' and m['adaptations']==7
    assert sha(SOURCE)==SOURCE_SHA and sha(UI/'run.py')==UI_SHA and sha(UI/'source-manifest.json')==UI_MANIFEST_SHA
    assert sha(SHARED)==SHARED_SHA
    for p,h in m['inputs'].items():assert sha(p)==h,p
    for p,h in m['files'].items():assert sha(HERE/p)==h,p
    assert (HERE/'adapted-hidden.py.txt').read_text('utf8')==adapted()
    pins=dict(m['inputs']);pins.update({str(HERE/p):h for p,h in m['files'].items()})
    pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json');return pins
def ui_bundle():
    pins=source_inputs()
    if not ADMISSION.is_file():raise NotReady('Missing actual UI runtime admission: '+str(ADMISSION))
    assert sha(ADMISSION)==ADMISSION_SHA
    ui=load(UI/'run.py','hidden_only_actual_ui_binding');ui_pins=ui.exact_pins()
    namespace={'__file__':str(ui.SOURCE),'__name__':'hidden_only_actual_ui_bundle','V2_HOST_BUILDER':ui.V2/'build_host.py',
               'verify_historical_probe':ui.verify_historical_probe,'verify_environment_change':ui.verify_environment_change}
    exec(compile(ui.adapted(),str(UI/'adapted-entry.py.txt'),'exec'),namespace)
    namespace['OPTIONS']=types.SimpleNamespace(product=PRODUCT,host=HOST_DIR,
        drivers=M52/'goal-native-loading-probe-driver-01',admission=ADMISSION)
    try:b=namespace['bundle']()
    except namespace['NotReady'] as error:raise NotReady(str(error)) from error
    assert b['product']==PRODUCT and b['host']==HOST_DIR and b['compile']['candidate_sha256']==CANDIDATE
    assert b['host_receipt']['candidate_sha256']==HOST and b['driver_proof']['artifacts']['timing/EffectsDriver.swf']==ui.DRIVER_SHA
    b.update(ui.verify_environment_change(b['meta']['installation_before'],b['installation']))
    b['pins'].update(ui_pins);b['pins'].update(pins);return b
def installation():
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from run_security_terminals import installation as actual_installation
    return actual_installation()
def hidden_preflight():
    b=ui_bundle();assert installation()==b['runtime_environment']
    return b['installation'],dict(b['pins'])
def ui_evidence():
    b=ui_bundle()
    return dict(product_sha256=CANDIDATE,host_sha256=HOST,admission=str(ADMISSION),admission_sha256=sha(ADMISSION),
                build_environment=b['build_environment'],runtime_environment=b['runtime_environment'],
                historical_driver_proof='a22-testpack-15-04 / 73d75eff59',scope='native-test-only',installed=False)
def validate_private_settings(run,out):
    before=read(out/'private-settings-before.json');after=read(out/'private-settings-after.json')
    assert before['before_any_air'] is True and after['before_copy_cleanup'] is True
    assert after['unchanged'] is True and not after['errors']
    assert before['run']==str(run) and after['run']==str(run)
    assert set(before['roles'])==set(after['roles'])=={'host','join'}
    for role,row in before['roles'].items():
        assert row['app_id']=='pfe-modsettings-rconnect-coop-'+role+'-'+run.name
        assert after['roles'][role]['preference_sha256']==row['preference_sha256']==hashlib.sha256(PREFERENCE).hexdigest()
        assert after['roles'][role]['telemetry_sha256']==row['telemetry_sha256']==sha(TELEMETRY)
    assert before['input_sha256']==sha(run/'input.json')
def main():
    source_inputs()
    if sys.argv[1:]==['--source-check']:
        ast.parse(adapted());print(json.dumps(dict(source_checked=True,air_started=False)));return 0
    namespace={'__file__':str(SOURCE),'__name__':'hidden_only_adapted_original',
        'ROOT':ROOT,'M52':M52,'GAME':GAME,'RUNNER':HERE/'launcher.py','PRODUCT':PRODUCT,'HOST_DIR':HOST_DIR,
        'VERSION':VERSION,'CANDIDATE':CANDIDATE,'HOST':HOST,'installation':installation,'sha':sha,'read':read,'save':save,
        'hidden_preflight':hidden_preflight,'ui_evidence':ui_evidence,'validate_private_settings':validate_private_settings}
    exec(compile(adapted(),str(HERE/'adapted-hidden.py.txt'),'exec'),namespace)
    try:return namespace['main']()
    except NotReady as error:
        print(json.dumps(dict(ready=False,checked=False,air_started=False,reason=str(error))));return 2
if __name__=='__main__':raise SystemExit(main())
