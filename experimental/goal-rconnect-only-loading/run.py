"""Only RConnect enabled; one unchanged three-trip sequence, two honest UI contracts."""
from pathlib import Path
import argparse,ast,difflib,hashlib,importlib.util,json,struct,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
ORDINARY=HERE.parent/'goal-ordinary-loading/run.py'
ORDINARY_SHA='5613e8bca191116797bac42af1d7054cfe99516dd5a32d8f1b44168d896b3502'
ENV=HERE.parent/'goal-native-loading-native-v2/run.py'
ENV_SHA='a5b2ce70fcef52bd5960715fb0d29289f5124acf5139387db92e30aefc1782f3'
BASE=M52/'recovery-room-production-05';UI=M52/'goal-native-loading-product-01'
UI_HOST=M52/'goal-native-loading-host-03';DRIVER=M52/'goal-rconnect-only-loading-driver-01'
BASE_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
UI_SHA='9c8536a70d2aed5fd76fbaaaabcef509bea3775e0d21cdc22e0df382b7cafaf6'
MARKER='NATIVE LOADING PROBE DONE '
OPTIONS=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def save(p,value):
    with Path(p).open('x',encoding='utf8') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
def load(p,n):
    spec=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def once(t,o,n):
    assert t.count(o)==1,o
    return t.replace(o,n,1)
def function_text(path,name):
    text=path.read_text('utf8');nodes=[n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert len(nodes)==1;n=nodes[0]
    return ''.join(text.splitlines(True)[n.lineno-1:n.end_lineno])
selector=load(HERE/'selector.py','only_rc_selector_recipe')
builder=load(HERE/'build.py','only_rc_driver_build')
source=load(HERE/'prepare.py','only_rc_source_prepare')
assert sha(ENV)==ENV_SHA and sha(ORDINARY)==ORDINARY_SHA
env=load(ENV,'only_rc_historical_environment')
original_ui=HERE.parent/'goal-native-loading-native/run.py'
recipe=load(original_ui.parent/'recipe.py','only_rc_original_done_recipe')

def ordinary_text():
    text=ORDINARY.read_text('utf8');assert sha(ORDINARY)==ORDINARY_SHA
    changes=[
      ('    ap.set_defaults(raster_host=None, sandy_bridge=False, diagnostic_driver=None)',
       '    ap.set_defaults(raster_host=SELECTED_HOST, sandy_bridge=False, diagnostic_driver=None)'),
      ('    from bridge_inputs import verify as verify_bridge','    verify_bridge = selected_bridge'),
      ("               '--registry-wait', str(args.registry_wait)]","               '--registry-wait', str(args.registry_wait), '--done', PROBE_DONE]"),
      ("        assert native.all_mods and native.effects and native.solo == (args.mode == 'solo')",
       "        assert native.all_mods and native.effects and native.solo == (args.mode == 'solo')\n        assert native.seconds == 600 and native.done == PROBE_DONE"),
      ('            if not settings:',"            if not settings and detail != 'Private module selection only; no AIR':"),
      ('                assert not record.children and not record.launching',
       "                selection_process = read(output/'selection/launcher-process.json')\n"
       "                assert selection_process['air_launch'] is False and selection_process['exit_code'] == 0\n"
       "                assert len(record.children) == 1 and record.children[0]['pid'] == selection_process['pid']\n"
       "                from test_registry import gone\n                assert not record.launching and gone(record.children[0])"),
      ('                    assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()',
       '                    assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()\n'
       '                    assert all(not (preference.parent/n).exists() for n in ("native-loading-observer.json","native-loading-terminal.png"))'),
      ('        def after_stopped():\n            try:\n                if settings:',
       '        def after_stopped():\n            try:\n                if settings: collect_observer(output,out,settings,roles)\n                if settings:'),
      ("        memory = read(run_path/'memory-timeline.json')",
       "        validate_only_rc(out,run_path,roles,settings,result)\n        memory = read(run_path/'memory-timeline.json')")]
    for old,new in changes:text=once(text,old,new)
    return text

def observation_texts():
    assert sha(original_ui)==env.SOURCE_SHA
    collect=function_text(original_ui,'collect_observer')
    collect=once(collect,"    assert roles==['host','join'] and set(settings)==set(roles)",
                         "    assert roles in (['host'],['host','join']) and set(settings)==set(roles)")
    validate=function_text(original_ui,'validate_observer')
    validate=once(validate,"    proofs={}\n", "    proofs={}\n    strict=OPTIONS.arm=='ui' and OPTIONS.mode=='dual'\n")
    validate=once(validate,"    for role in roles:\n", "    if not strict:zero=('faultCount','dropped','identityChanges','parentChanges')\n    for role in roles:\n")
    validate=once(validate,"        assert len(doc['checks'])==11 and all(c['passed'] is True for c in doc['checks'])\n        assert len({c['label'] for c in doc['checks']})==11",
        "        assert doc['productVersion']==('0.2.24-nativeui1' if OPTIONS.arm=='ui' else '0.2.24-roomfix5')\n"
        "        assert doc['solo'] is (OPTIONS.mode=='solo') and doc['uiContractRequired'] is strict\n"
        "        assert doc['uiContractQualified'] is strict and len(doc['uiChecks'])==11\n"
        "        assert len(doc['checks'])==(11 if strict else 8) and all(c['passed'] is True for c in doc['checks'])\n"
        "        assert len({c['label'] for c in doc['checks']})==len(doc['checks'])\n"
        "        if strict:assert doc['checks']==doc['uiChecks']\n"
        "        else:\n            assert doc['checks'][:7]==[doc['uiChecks'][i] for i in (0,1,2,5,8,9,10)]\n"
        "            assert doc['checks'][7]['label']=='actual native loading observed without claiming the UI bridge'")
    validate=once(validate,"        assert sum(r['eligible'] is True for r in rows)==doc['eligibleCount']>0",
                         "        assert sum(r['eligible'] is True for r in rows)==doc['eligibleCount']\n        if strict:assert doc['eligibleCount']>0")
    validate=once(validate,"            assert row['supported'] is True and row['nativeFaults']==0 and not row['copies']",
                         "            if strict:assert row['supported'] is True and row['nativeFaults']==0 and not row['copies']")
    validate=once(validate,"            if row['eligible']:","            if strict and row['eligible']:")
    validate=once(validate,"        assert doc['terminalTree']['visited']>0 and doc['terminalTree']['copies']==[]",
                         "        assert doc['terminalTree']['visited']>0\n        if strict:assert doc['terminalTree']['copies']==[]")
    validate=once(validate,"                          checks=11,renderCount=doc['renderCount']",
                         "                          checks=len(doc['checks']),uiContractQualified=strict,renderCount=doc['renderCount']")
    return collect,validate

def expansions():
    texts=selector.source_texts();texts['adapted-ordinary.py.txt']=ordinary_text()
    texts['adapted-observer.py.txt']='\n\n'.join(observation_texts())
    return texts

def source_check():
    source.verify();recipe.check();env.exact_pins()
    m=read(HERE/'runtime-manifest.json')
    assert m['kind']=='only-rconnect-loading-runtime-v1' and m['enabled']==['RConnectMod']
    for n,h in m['files'].items():assert sha(HERE/n)==h,n
    for p,h in m['original'].items():assert sha(p)==h,p
    for n,text in expansions().items():assert (HERE/n).read_text('utf8')==text,n
    assert m['ordinary_replacements']==9 and m['shared_replacements']==4
    return {str(HERE/n):h for n,h in m['files'].items()}|m['original']|{str(HERE/'runtime-manifest.json'):sha(HERE/'runtime-manifest.json')}

def ui_bundle():
    # Genuine UI v2 checks: original build environments, real current environment,
    # actual compiled outputs and the root's independent host admission are retained.
    namespace={'__file__':str(env.SOURCE),'__name__':'only_rc_actual_ui_bundle',
      'V2_HOST_BUILDER':env.V2/'build_host.py','verify_historical_probe':env.verify_historical_probe,
      'verify_environment_change':env.verify_environment_change}
    exec(compile(env.adapted(),str(env.HERE/'adapted-entry.py.txt'),'exec'),namespace)
    namespace['OPTIONS']=types.SimpleNamespace(product=UI,host=UI_HOST,
        drivers=M52/'goal-native-loading-probe-driver-01',admission=None)
    value=namespace['bundle']()
    assert value['compile']['candidate_sha256']==UI_SHA and value['host_receipt']['candidate_sha256']==selector.HOST_SHA
    value['pins'].update(env.exact_pins())
    return value

def bundle():
    pins=source_check();old=load(ORDINARY,'only_rc_original_ordinary')
    baseline,baseline_compile,oldpins=old.inputs(BASE);pins.update(oldpins)
    before=old.installed()
    environment=env.verify_environment_change(env.read(env.HISTORICAL_ENV)['installation'],before)
    assert before==source.verify()['runtime_environment']
    proof=builder.verify(DRIVER);pins.update(proof['inputs'])
    assert proof['build_environment']==before
    for n in ('prepared.json','compile.json','timing/EffectsDriver.swf','timing/EffectsHarness.swf'):pins[str(DRIVER/n)]=sha(DRIVER/n)
    if OPTIONS.arm=='ui':
        actual=ui_bundle();pins.update(actual['pins']);meta,compiled=actual['meta'],actual['compile']
        bridge=dict(host=str(UI_HOST/'pfe.swf'),host_sha256=selector.HOST_SHA,sandy=None,sandy_sha256=None,
                    pins=actual['pins'],scope='native-test-only',base_sha256=old.installed()['pfe.swf'])
        product=UI
    else:meta,compiled,bridge,product=baseline,baseline_compile,None,BASE
    assert compiled['candidate_sha256']==(UI_SHA if OPTIONS.arm=='ui' else BASE_SHA)
    return dict(meta=meta,compile=compiled,pins=pins,installation=before,environment=environment,
                driver_proof=proof,bridge=bridge,product=product)

def collect_observer(*args):
    space=dict(sha=sha,read=read,save=save,Path=Path,json=json,struct=struct,OPTIONS=OPTIONS,recipe=recipe)
    import os
    space['os']=os
    exec(compile(observation_texts()[0],str(HERE/'adapted-observer.py.txt'),'exec'),space)
    return space['collect_observer'](*args)

def validate_only_rc(out,run,roles,settings,result):
    expected={'host':11} if OPTIONS.mode=='solo' else {'host':23,'join':12}
    assert {r:result['roles'][r]['checks'] for r in roles}==expected
    selected=read(run/'reduced-selection-result.json')
    assert selected['passed'] is True and selected['original_framework_passed'] is True
    assert selected['enabled']==['RConnectMod'] and set(selected['disabled'])==selector.DISABLED
    assert set(selected['roles'])==set(roles)
    receipt=run/'selection/selection-input.json'
    assert Path(selected['selection_receipt']).resolve()==receipt and sha(receipt)==selected['selection_receipt_sha256']
    for role in roles:
        s=selected['roles'][role]
        assert s['passed'] is True and s['requested']==s['ok']==['RConnectMod'] and s['err']==[]
        assert sha(run/'selection'/(role+'-ModLoader.sol'))==s['status_sha256']
        text=(run/(role+'.log')).read_text('utf-8-sig')
        assert 'ContinuousScene is explicitly not loaded' in text and 'TRAVEL CONFIG ERROR' not in text
        for row in result['roles'][role]['rows']:
            v=row['entranceView'];assert v['playerX']==row['x'] and v['playerY']==row['y']
            assert v['stageWidth']>0 and v['stageHeight']>0
            assert all(type(v[k]) in (int,float) for k in v)
    space=dict(sha=sha,read=read,save=save,Path=Path,json=json,struct=struct,OPTIONS=OPTIONS,recipe=recipe)
    exec(compile(observation_texts()[1],str(HERE/'adapted-observer.py.txt'),'exec'),space)
    space['validate_observer'](out,run,roles,settings,result)
    result.update(enabled=['RConnectMod'],selection_result_sha256=sha(run/'reduced-selection-result.json'),
        ui_contract_qualified=OPTIONS.arm=='ui' and OPTIONS.mode=='dual',
        performance_qualified=False,entrance_comparison='Compare matching entrance and viewport only; equal seed does not fix native spawn randomness')

def main():
    global OPTIONS
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--arm',choices=['baseline','ui'],default='baseline');ap.add_argument('--mode',choices=['solo','dual'],default='dual')
    ap.add_argument('--check',action='store_true');ap.add_argument('--source-check',action='store_true');ap.add_argument('--prepare-source',action='store_true')
    ap.add_argument('--output',type=Path);ap.add_argument('--registry-wait',type=float,default=900)
    OPTIONS=ap.parse_args();assert OPTIONS.registry_wait>=0
    if OPTIONS.prepare_source:
        for n,text in expansions().items():
            with (HERE/n).open('x',encoding='utf8',newline='\n') as f:f.write(text)
        originals={str(ORDINARY):ORDINARY_SHA,str(ENV):ENV_SHA,str(selector.OLD):selector.OLD_SHA}
        originals.update(env.exact_pins());originals.update({str(p):h for p,h in selector.module().PINS.items()})
        save(HERE/'runtime-manifest.json',dict(kind='only-rconnect-loading-runtime-v1',enabled=['RConnectMod'],
             ordinary_replacements=9,shared_replacements=4,
             files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix!='.pyc'},
             original=originals,air_started=False,compiled=False))
    pins=source_check()
    if OPTIONS.source_check or OPTIONS.prepare_source:
        print(json.dumps(dict(source_checked=True,enabled=['RConnectMod'],actual_driver_verified=False,air_started=False)));return 0
    try:b=bundle()
    except (FileNotFoundError,builder.base.NotReady) as error:
        print(json.dumps(dict(ready=False,status='not-ready',error=str(error),air_started=False)));return 2
    if OPTIONS.check:
        assert OPTIONS.output is None
        print(json.dumps(dict(checked=True,arm=OPTIONS.arm,mode=OPTIONS.mode,enabled=['RConnectMod'],
            driver=b['driver_proof']['artifacts']['timing/EffectsDriver.swf'],candidate=b['compile']['candidate_sha256'],air_started=False)));return 0
    assert OPTIONS.output is not None
    namespace={'__file__':str(ORDINARY),'__name__':'only_rc_ordinary_execution'}
    exec(compile(ordinary_text(),str(HERE/'adapted-ordinary.py.txt'),'exec'),namespace)
    def inputs(path):
        current=bundle();assert current==b and path==b['product'];return b['meta'],b['compile'],b['pins']
    def bridge(host,before,sandy):
        assert before==b['installation'] and sandy is False
        assert host==(UI_HOST if OPTIONS.arm=='ui' else None);return b['bridge']
    namespace.update(inputs=inputs,selected_bridge=bridge,SELECTED_HOST=str(UI_HOST) if OPTIONS.arm=='ui' else None,
        DRIVER=DRIVER,DRIVER_SHA=b['driver_proof']['artifacts']['timing/EffectsDriver.swf'],RUNNER=HERE/'selector.py',
        PROBE_DONE=MARKER,collect_observer=collect_observer,validate_only_rc=validate_only_rc)
    argv=sys.argv
    sys.argv=[str(HERE/'run.py'),'--product',str(b['product']),'--mode',OPTIONS.mode,
              '--output',str(OPTIONS.output),'--registry-wait',str(OPTIONS.registry_wait)]
    try:return namespace['main']()
    finally:sys.argv=argv
if __name__=='__main__':raise SystemExit(main())
