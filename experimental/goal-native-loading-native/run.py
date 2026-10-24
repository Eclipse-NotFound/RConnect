"""Thin paired native-UI run: exact original ordinary checks plus real terminal UI evidence."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,struct,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1];M52=ROOT/'build/m52'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def save(p,value):
    with Path(p).open('x',encoding='utf8') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')
def load(p,name):
    spec=importlib.util.spec_from_file_location(name,p)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
recipe=load(HERE/'recipe.py','native_loading_recipe')
BASE=M52/'recovery-room-production-05'
BASE_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
BASE_HOST='a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
SAND='cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942'
UI_BUILD=HERE.parent/'goal-native-loading-build'
PROBE_BUILD=HERE.parent/'goal-native-loading-probe/build.py'
OPTIONS=None

class NotReady(Exception):pass

def target(value,prefix):
    p=(ROOT/Path(value)).resolve()
    assert p.parent==M52 and p.name.startswith(prefix),p
    return p

def paths():
    product=target(OPTIONS.product,'goal-native-loading-product-')
    host=target(OPTIONS.host,'goal-native-loading-host-')
    driver=target(OPTIONS.drivers,'goal-native-loading-probe-driver-')
    admission=(ROOT/OPTIONS.admission).resolve() if OPTIONS.admission else host/'runtime-admission.json'
    assert admission.parent==host,admission
    return product,host,driver,admission

def builders():
    # build_product uses a plain "import inputs"; bind its exact source module
    # locally, then restore the interpreter's previous mapping.
    source=load(UI_BUILD/'inputs.py','ui_runtime_exact_inputs')
    prior=sys.modules.get('inputs');sys.modules['inputs']=source
    try:product=load(UI_BUILD/'build_product.py','ui_runtime_product_builder')
    finally:
        if prior is None:sys.modules.pop('inputs',None)
        else:sys.modules['inputs']=prior
    return product,load(UI_BUILD/'build_host.py','ui_runtime_host_builder'),load(PROBE_BUILD,'ui_runtime_probe_builder')

def semantic_admission(host,receipt,path):
    a=read(path)
    assert a['kind']=='native-loading-ui-host-runtime-admission'
    assert a['validated'] is True and a['scope']=='native-test-only' and a['installed'] is False
    assert a['base_sha256']==BASE_HOST and a['candidate_sha256']==receipt['candidate_sha256']
    assert a['build_manifest_sha256']==sha(host/'build.json')
    evidence={str(Path(p).resolve()):h for p,h in a['inputs'].items()}
    assert len(evidence)==len(a['inputs'])
    for p,h in evidence.items():assert sha(p)==h,p
    semantic=Path(a['semantic_review']).resolve()
    required=[host/'pfe.swf',host/'build.json',host/'method-audit.json',host/'readback/scripts/fe/World.as',
              host/'pcode/scripts/fe/World.pcode',semantic]
    assert semantic.is_file() and semantic!=path
    assert all(evidence.get(str(p.resolve()))==sha(p) for p in required)
    return a,evidence|{str(path):sha(path)}

def bundle():
    recipe.check()
    original=load(recipe.ORDINARY,'native_ui_original_ordinary')
    # Run the genuine old admission against its genuine old product/driver.
    pins=original.inputs(BASE)[2]
    product,host,driver,admission=paths()
    required=[product/'prepared.json',product/'compile.json',product/'RConnectMod.swf',
              host/'prepared.json',host/'build.json',host/'pfe.swf',admission,
              driver/'prepared.json',driver/'compile.json',driver/'timing/EffectsDriver.swf']
    missing=[str(p) for p in required if not p.is_file()]
    if missing:raise NotReady('Missing actual outputs or independent admission: '+json.dumps(missing))
    pb,hb,db=builders()
    pc=pb.verify(product);hc=hb.verify(host);dc=db.verify(driver)
    pm=read(product/'prepared.json')
    assert pm['version']=='0.2.24-nativeui1' and pm['base_sha256']==BASE_SHA
    assert pc['candidate_sha256']!=BASE_SHA
    assert hc['base_sha256']==BASE_HOST and hc['validated'] is False and hc['build_checks_passed'] is True
    assert hc['candidate_sha256']!=BASE_HOST
    assert dc['verified'] is True and dc['candidate_sha256']==BASE_SHA and dc['smoothnessQualified'] is False
    assert set(dc['artifacts'])=={'timing/EffectsDriver.swf','timing/EffectsHarness.swf'}
    assert dc['artifacts']['timing/EffectsHarness.swf']==original.HARNESS_SHA
    before=original.installed()
    assert len(before)==22 and before['pfe.swf']==BASE_HOST and before['mods/Rconnect/release/RConnectMod.swf']==BASE_SHA
    assert before['mods/Sandevistan/release/SandevistanMod.swf']==SAND
    assert before==pm['installation_before']==hc['installation_before']==dc['installation']
    a,apins=semantic_admission(host,hc,admission)
    pins.update(pm['reviewed_inputs']);pins.update(hc['inputs']);pins.update(dc['inputs']);pins.update(apins)
    own=recipe.check()
    for name in own['files']:pins[str(HERE/name)]=sha(HERE/name)
    pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
    for folder,names in [(product,('prepared.json','compile.json','RConnectMod.swf')),
                         (host,('prepared.json','build.json','pfe.swf','method-audit.json')),
                         (driver,('prepared.json','compile.json','timing/EffectsDriver.swf','timing/EffectsHarness.swf'))]:
        for name in names:pins[str(folder/name)]=sha(folder/name)
    return dict(meta=pm,compile=pc,host_receipt=hc,driver_proof=dc,admission=a,pins=pins,installation=before,
                product=product,host=host,driver=driver)

def product_inputs(path):
    b=bundle();assert path==b['product']
    return b['meta'],b['compile'],b['pins']

def ui_bridge(host_path,before,sandy):
    b=bundle();assert host_path==b['host'] and before==b['installation'] and sandy is False
    return dict(host=str(b['host']/'pfe.swf'),host_sha256=b['host_receipt']['candidate_sha256'],
                sandy=None,sandy_sha256=None,pins=b['pins'],scope='native-test-only',
                base_sha256=BASE_HOST,independent_admission_sha256=sha(paths()[3]))

def collect_observer(output,out,settings,roles):
    """Called after all owned children stopped, before original copy cleanup."""
    receipt=dict(before_copy_cleanup=True,roles={},errors=[])
    assert roles==['host','join'] and set(settings)==set(roles)
    for role in roles:
        appid='pfe-modsettings-rconnect-coop-'+role+'-'+output.name
        assert settings[role]['app_id']==appid
        storage=Path(os.environ['APPDATA']).resolve()/appid/'Local Store'
        assert Path(settings[role]['preference']).parent==storage
        destination=out/'observer'/role;destination.mkdir(parents=True)
        receipt['roles'][role]=dict(app_id=appid,files={})
        for name in ('native-loading-observer.json','native-loading-terminal.png'):
            source=storage/name;copied=destination/name
            try:
                assert source.is_file(),str(source)
                raw=source.read_bytes()
                with copied.open('xb') as f:f.write(raw)
                assert sha(source)==sha(copied)
                receipt['roles'][role]['files'][name]=dict(source=str(source),copied=str(copied),sha256=sha(copied),bytes=len(raw))
            except Exception as error:receipt['errors'].append(role+' '+name+': '+repr(error))
    save(out/'observer-collected.json',receipt)
    assert not receipt['errors'],receipt['errors']

def validate_observer(out,run_path,roles,settings,result):
    evidence=read(out/'observer-collected.json')
    assert evidence['before_copy_cleanup'] is True and not evidence['errors'] and set(evidence['roles'])==set(roles)
    proofs={}
    zero=('faultCount','dropped','missingWait','layerLeak','copyCount','identityChanges','parentChanges','bridgeMissing','worldFaultFrames')
    for role in roles:
        root=out/'observer'/role
        doc=read(root/'native-loading-observer.json')
        assert doc['kind']=='native-loading-observer-v1' and doc['role']==role and doc['appId']==settings[role]['app_id']
        assert doc['passed'] is True and doc['complete'] is True
        assert doc['diagnosticOnly'] is True and doc['performanceQualified'] is False and doc['loadingViewCalled'] is False
        assert len(doc['checks'])==11 and all(c['passed'] is True for c in doc['checks'])
        assert len({c['label'] for c in doc['checks']})==11
        assert all(doc[n]==0 for n in zero) and doc['faults']==[]
        rows=doc['rows'];assert 0<len(rows)<=20000 and len(rows)==doc['renderCount']
        assert all(type(r['at']) is int for r in rows)
        assert all(b['at']>=a['at'] for a,b in zip(rows,rows[1:]))
        assert doc['maxRenderGap']==max([b['at']-a['at'] for a,b in zip(rows,rows[1:])]+[0])
        assert sum(r['eligible'] is True for r in rows)==doc['eligibleCount']>0
        assert sum(r['wait']['effective'] is True for r in rows)==doc['waitCount']>0
        counts={}
        for row in rows:
            assert row['supported'] is True and row['nativeFaults']==0 and not row['copies']
            assert row['nativeWaitIdentity'] is True and row['nativeParentIdentity'] is True
            if row['eligible']:
                assert row['wait']['effective'] is True and all(row[n]['visible'] is False for n in ('visual','vfon','vgui'))
            item=counts.setdefault(str(row['round']),dict(renders=0,nativeWait=0,eligible=0,pending=0,black=0))
            item['renders']+=1
            for name,value in [('nativeWait',row['wait']['effective']),('eligible',row['eligible']),
                               ('pending',row['entryPending']),('black',row['vblack']['effective'])]:
                if value:item[name]+=1
        assert counts==doc['rounds'] and all(counts[str(n)]['renders']>0 for n in range(3))
        boundaries=doc['boundaries']
        assert [b['round'] for b in boundaries if b['kind']=='begin']==[0,1,2]
        assert [b['round'] for b in boundaries if b['kind']=='result']==[0,1,2]
        finished=[b for b in boundaries if b['kind']=='finish-request']
        assert len(finished)==1 and finished[0]['at']==doc['finishedAt']
        last=rows[-1]
        assert last['phase']=='finished' and last['at']>=doc['finishedAt']
        assert last['entryPending'] is False and last['busy'] is False
        assert last['wait']['effective'] is False and last['vblack']['effective'] is False
        assert all(last[n]['effective'] is True for n in ('visual','vfon','vgui'))
        assert doc['terminalTree']['visited']>0 and doc['terminalTree']['copies']==[]
        assert set(doc['spans'])=={'nativeWait','black','obscured','pending'}
        assert all(v['start']==-1 and v['total']>=v['max']>=0 for v in doc['spans'].values())
        png=(root/'native-loading-terminal.png').read_bytes()
        assert png[:8]==b'\x89PNG\r\n\x1a\n' and png[12:16]==b'IHDR' and png[-12:]==b'\x00\x00\x00\x00IEND\xaeB`\x82'
        width,height=struct.unpack('>II',png[16:24]);assert width>0 and height>0
        assert doc['png']['width']==width and doc['png']['height']==height and doc['png']['bytes']==len(png)
        assert doc['png']['name']=='native-loading-terminal.png' and doc['png']['afterMeasuredTravel'] is True
        assert doc['png']['at']>=doc['finishedAt']>=max(r['at'] for r in result['roles'][role]['rows'])
        text=(run_path/(role+'.log')).read_text('utf-8-sig')
        old='COOP EFFECTS DONE travel-timing '+role;new=recipe.MARKER+role
        assert text.count(old)==text.count(new)==1 and text.index(old)<text.index(new)
        assert 'NATIVE LOADING PROBE OUTPUT FAILED' not in text
        reports=[json.loads(line.split('NATIVE LOADING PROBE RESULT ',1)[1]) for line in text.splitlines() if line.startswith('NATIVE LOADING PROBE RESULT ')]
        assert len(reports)==1 and reports[0]['passed'] is True and reports[0]['checks']==doc['checks']
        assert all(reports[0][k]==doc[k] for k in ('renderCount','eligibleCount','faultCount','dropped'))
        for name,row in evidence['roles'][role]['files'].items():assert sha(root/name)==row['sha256']
        proofs[role]=dict(json_sha256=sha(root/'native-loading-observer.json'),png_sha256=sha(root/'native-loading-terminal.png'),
                          checks=11,renderCount=doc['renderCount'],eligibleCount=doc['eligibleCount'],rounds=doc['rounds'],
                          spans=doc['spans'],maxRenderGap=doc['maxRenderGap'],observationMs=doc['observationMs'],observationMaxMs=doc['observationMaxMs'])
    result.update(observer_passed=True,observer=proofs,observer_collection_sha256=sha(out/'observer-collected.json'))

def main():
    global OPTIONS
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--product',type=Path,default=Path('build/m52/goal-native-loading-product-01'))
    ap.add_argument('--host',type=Path,default=Path('build/m52/goal-native-loading-host-01'))
    ap.add_argument('--drivers',type=Path,default=Path('build/m52/goal-native-loading-probe-driver-01'))
    ap.add_argument('--admission',type=Path)
    ap.add_argument('--output',type=Path);ap.add_argument('--check',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=900)
    OPTIONS=ap.parse_args();assert OPTIONS.registry_wait>=0
    if OPTIONS.check:assert OPTIONS.output is None
    else:assert OPTIONS.output is not None
    try:b=bundle()
    except NotReady as error:
        print(json.dumps(dict(ready=False,checked=False,air_started=False,reason=str(error))));return 2
    namespace={'__file__':str(recipe.ORDINARY),'__name__':'native_loading_bound_ordinary'}
    exec(compile(recipe.ordinary_source(),str(HERE/'adapted-ordinary.py.txt'),'exec'),namespace)
    namespace.update(inputs=product_inputs,ui_bridge=ui_bridge,UI_HOST=b['host'],PROBE_DONE=recipe.MARKER,
                     DRIVER=b['driver'],DRIVER_SHA=b['driver_proof']['artifacts']['timing/EffectsDriver.swf'],
                     RUNNER=HERE/'private_runner.py',collect_observer=collect_observer,validate_observer=validate_observer)
    old_argv=sys.argv
    sys.argv=[str(HERE/'run.py'),'--product',str(b['product']),'--mode','dual','--registry-wait',str(OPTIONS.registry_wait)]
    if OPTIONS.check:sys.argv+=['--check']
    else:sys.argv+=['--output',str(OPTIONS.output)]
    try:return namespace['main']()
    finally:sys.argv=old_argv
if __name__=='__main__':raise SystemExit(main())
