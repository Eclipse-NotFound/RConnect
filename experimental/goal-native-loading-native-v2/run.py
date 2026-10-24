"""Frozen native-UI outputs, with explicit historical-build/current-RV separation."""
from pathlib import Path
import ast,difflib,hashlib,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.with_name('goal-native-loading-native')
SOURCE=OLD/'run.py'
SOURCE_SHA='6600386fc24dfba7db84512d1d6ec11b44a386a1eb4f4782950f62d69e726c24'
OLD_MANIFEST_SHA='346ccb12820fb9b45cc743fbff7ffe2c396db1d46ef746c70bcaf00855169da6'
V2=HERE.with_name('goal-native-loading-host-build-v2')
V2_PINS={
 'build_host.py':'f9a46da85f45765d8a3a2f481648379c7cbd39e921d0704ab365d771928f2d54',
 'activation_slots.py':'c8fc48cc206f70f238ac770cd098594debbf9964b160bf84bb32a10224cc280f',
 'proof.diff':'fcca1bee040ba8fc905fc0e788fc4a2872ef71f1e3bd05fbc6ca615b237c2d7d',
 'README.md':'bafbf8577caeb300d3f44e2800ba06b62b11928ffba6f0ff79747bcfcf8befc3'}
PRODUCT_SHA='9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
DRIVER_SHA='877b05dacfca220f69345c3f83b4d8d2cc7796d6d03ea6389682fef7061d474a'
PROBE=HERE.with_name('goal-native-loading-probe')
BASE_BUILDER=HERE.with_name('goal-three-issues-native')
HISTORICAL_ENV=BASE_BUILDER/'environment.json'
RV_RECEIPT=ROOT.parent/'RealisticVision/knowledge/experiments/combat-render-d44-20261025/deployment/receipt.json'
RV_KEY='mods/RealisticVision/release/RealisticVisionMod.swf'
RV_OLD='bf4ac9cd87272b03fae7ec22ee67d045f037362f412ee801cad3f9ba9fe3afef'
RV_NEW='638e2d408e2cf46683c41114f75773829a1b4417d74bffe9d08855a4fe343710'
ENVIRONMENT_PINS={
 str(BASE_BUILDER/'build.py'):'8b85f7e63f4b6f4294ef25eef928f21fa5949fb06f521b6e3eaf6d662dc94944',
 str(HISTORICAL_ENV):'6f2a70bbe43d6729903a0ba2577d0687206442e684d74b787b96ee2cde8eebd0',
 str(PROBE/'build.py'):'a909caa2a815253d84212d6191a85d413ecf2c4499f18dcc03d9704e127aa125',
 str(PROBE/'adapted-build.py.txt'):'409dcedb7e939b4ad7d5986d2b81a0a51f4067fd627c1defd70899b3ee60aeda',
 str(RV_RECEIPT):'bb713983b87cd23f238774d484480c3582384da56c2fcd0cccb282d3363d379f'}
EDITS=(
 ("load(UI_BUILD/'build_host.py','ui_runtime_host_builder')",
  "load(V2_HOST_BUILDER,'ui_runtime_host_builder_v2')"),
 ("    ap.add_argument('--host',type=Path,default=Path('build/m52/goal-native-loading-host-01'))",
  "    ap.add_argument('--host',type=Path,default=Path('build/m52/goal-native-loading-host-03'))"),
 ("    pc=pb.verify(product);hc=hb.verify(host);dc=db.verify(driver)",
  "    pc=pb.verify(product);hc=hb.verify(host);dc=verify_historical_probe(db,driver)"),
 ("    assert before==pm['installation_before']==hc['installation_before']==dc['installation']",
  "    assert pm['installation_before']==hc['installation_before']==dc['build_environment']\n"
  "    assert before==dc['runtime_environment']\n"
  "    verify_environment_change(pm['installation_before'],before)"))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
def function_text(path,name):
    text=Path(path).read_text('utf8');tree=ast.parse(text)
    nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert len(nodes)==1
    return ''.join(text.splitlines(True)[nodes[0].lineno-1:nodes[0].end_lineno])
def probe_sources():
    # These are the original complete functions, not replacement test models.
    for path,digest in ENVIRONMENT_PINS.items():assert sha(path)==digest,path
    base=function_text(BASE_BUILDER/'build.py','inputs')
    base=once(base," env=read(HERE/'environment.json'); assert installed()==env['installation']",
              " env=read(HERE/'environment.json'); verify_environment_change(env['installation'],installed())")
    inputs=function_text(PROBE/'build.py','inputs')
    verify=function_text(PROBE/'adapted-build.py.txt','verify')
    verify=once(verify," assert m['inputs']==inputs() and m['installation_before']==c['installation_before']==c['installation_after']==installed()",
                " assert m['inputs']==inputs() and m['installation_before']==c['installation_before']==c['installation_after']\n"
                " verify_environment_change(m['installation_before'],installed())")
    verify=once(verify,"compile_sha256=sha(out/'compile.json'),installation=installed(),smoothnessQualified=False)",
                "compile_sha256=sha(out/'compile.json'),build_environment=m['installation_before'],runtime_environment=installed(),smoothnessQualified=False)")
    return base,inputs,verify
def probe_expansion():
    labels=('base historical inputs','unchanged probe inputs','historical probe verify')
    return '\n\n'.join('# '+label+'\n'+text for label,text in zip(labels,probe_sources()))
def verify_environment_change(historical,current):
    assert sha(HISTORICAL_ENV)==ENVIRONMENT_PINS[str(HISTORICAL_ENV)]
    assert sha(RV_RECEIPT)==ENVIRONMENT_PINS[str(RV_RECEIPT)]
    env=read(HERE/'runtime-environment.json');receipt=read(RV_RECEIPT)
    assert env['kind']=='native-loading-runtime-rv03310' and env['rv_receipt_sha256']==sha(RV_RECEIPT)
    assert historical==env['build_environment']==read(HISTORICAL_ENV)['installation']
    assert current==env['runtime_environment'] and len(current)==len(historical)==22
    assert set(current)==set(historical)
    assert {p for p in current if current[p]!=historical[p]}=={RV_KEY}
    assert historical[RV_KEY]==RV_OLD and current[RV_KEY]==RV_NEW
    assert receipt['old']==RV_OLD and receipt['new']==RV_NEW and receipt['result']=='PASS'
    assert receipt['descriptor_removed'] is True and receipt['own_process_closed'] is True
    for p,h in receipt['before'].items():
        if p in historical:assert historical[p]==current[p]==h,p
        else:
            actual=(ROOT.parents[1]/p).resolve()
            assert actual.is_relative_to(ROOT.parents[1]) and sha(actual)==h,p
    return dict(build_environment=historical,runtime_environment=current,
                changes={RV_KEY:dict(before=RV_OLD,after=RV_NEW)},
                receipt=str(RV_RECEIPT),receipt_sha256=sha(RV_RECEIPT))
def verify_historical_probe(module,out):
    base_text,inputs_text,verify_text=probe_sources()
    assert Path(module.__file__).resolve()==PROBE/'build.py'
    assert Path(module.base.__file__).resolve()==BASE_BUILDER/'build.py'
    assert module.adapted_source()==(PROBE/'adapted-build.py.txt').read_text('utf8')
    base_scope=dict(vars(module.base),verify_environment_change=verify_environment_change)
    exec(compile(base_text,str(HERE/'adapted-probe.py.txt')+':base','exec'),base_scope)
    # A private global namespace changes only the call to the historical inputs
    # verifier. No original module, installed() function or receipt is replaced.
    input_scope=dict(vars(module),base=types.SimpleNamespace(inputs=base_scope['inputs']))
    exec(compile(inputs_text,str(HERE/'adapted-probe.py.txt')+':inputs','exec'),input_scope)
    verify_scope=dict(module.delegate,inputs=input_scope['inputs'],verify_environment_change=verify_environment_change)
    exec(compile(verify_text,str(HERE/'adapted-probe.py.txt')+':verify','exec'),verify_scope)
    return verify_scope['verify'](out)
def adapted():
    assert sha(SOURCE)==SOURCE_SHA and sha(OLD/'source-manifest.json')==OLD_MANIFEST_SHA
    text=SOURCE.read_text('utf8')
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text
def exact_pins():
    text=adapted();m=read(HERE/'source-manifest.json')
    assert m['kind']=='native-loading-runtime-host-verifier-v2' and m['replacements']==len(EDITS)==4
    assert m['original_sha256']==SOURCE_SHA and m['original_manifest_sha256']==OLD_MANIFEST_SHA
    assert m['host_verifier']==V2_PINS
    assert (HERE/'adapted-entry.py.txt').read_text('utf8')==text
    assert (HERE/'adapted-probe.py.txt').read_text('utf8')==probe_expansion()
    assert m['environment_pins']==ENVIRONMENT_PINS and m['probe_replacements']==3
    paths={str(SOURCE):SOURCE_SHA,str(OLD/'source-manifest.json'):OLD_MANIFEST_SHA}
    paths.update(ENVIRONMENT_PINS)
    historical=read(HISTORICAL_ENV)['installation']
    for p,h in read(RV_RECEIPT)['before'].items():
        if p not in historical:
            actual=(ROOT.parents[1]/p).resolve()
            assert actual.is_relative_to(ROOT.parents[1]) and sha(actual)==h,p
            paths[str(actual)]=h
    for name,digest in V2_PINS.items():
        assert sha(V2/name)==digest,name
        paths[str(V2/name)]=digest
    for name,digest in m['files'].items():
        assert sha(HERE/name)==digest,name
        paths[str(HERE/name)]=digest
    paths[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
    return paths
def main():
    pins=exact_pins()
    if sys.argv[1:]==['--source-check']:
        print(json.dumps(dict(source_checked=True,actual_outputs_checked=False,xml_parsed=False,air_started=False)))
        return 0
    namespace={'__file__':str(SOURCE),'__name__':'native_loading_runtime_host_v2','V2_HOST_BUILDER':V2/'build_host.py',
               'verify_historical_probe':verify_historical_probe,'verify_environment_change':verify_environment_change}
    exec(compile(adapted(),str(HERE/'adapted-entry.py.txt'),'exec'),namespace)
    original_bundle=namespace['bundle']
    def bundle():
        current=exact_pins();assert current==pins
        value=original_bundle() # Genuine product/probe verification and actual v2 host.verify.
        assert value['product']==ROOT/'build/m52/goal-native-loading-product-01'
        assert value['compile']['candidate_sha256']==PRODUCT_SHA
        assert value['driver']==ROOT/'build/m52/goal-native-loading-probe-driver-01'
        assert value['driver_proof']['artifacts']['timing/EffectsDriver.swf']==DRIVER_SHA
        environment=verify_environment_change(value['meta']['installation_before'],value['installation'])
        value.update(environment)
        value['pins'].update(current)
        return value
    namespace['bundle']=bundle
    original_bridge=namespace['ui_bridge']
    def ui_bridge(host_path,before,sandy):
        value=original_bridge(host_path,before,sandy)
        value.update(verify_environment_change(read(HISTORICAL_ENV)['installation'],before))
        return value
    namespace['ui_bridge']=ui_bridge
    return namespace['main']()
if __name__=='__main__':raise SystemExit(main())
