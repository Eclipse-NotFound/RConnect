"""Small nativeui2 adapter over the frozen, actual only-RConnect loading runner."""
from pathlib import Path
import hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.parent/'goal-rconnect-only-loading/run.py'
OLD_SHA='8272c4dc12c72e4e2bbdd6f23a3ddcb653571bc06f84f6572353a5a354c0c637'
PRODUCT_RECIPE=HERE.parent/'goal-native-ui-jump-product';PRODUCT=M52/'goal-native-ui-jump-product-01'
DRIVER=M52/'goal-native-ui-jump-loading-driver-01'
PRODUCT_SHA='5325a3aaeff65e215d8e01cd6ef5f87feea362ce422ce3b93b35a038a5cb4930'
PRODUCT_PINS={'prepare.py':'d830d9732a1b85ca247e63ee43cece7b996b0e9c701430492505dc404466cbf7',
 'build.py':'2dd9874b35bdd9064b0fc92932680d016d8c54b84afef6c6d2433cd2ebd2c60b',
 'source-manifest.json':'d8a173e4eecbca19ec64e96db98292cb7f64c9330d9fd763cdeb4ef2f41e9adc'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
    s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
assert sha(OLD)==OLD_SHA
parent=load(OLD,'nativeui2_only_rc_parent');builder=load(HERE/'build.py','nativeui2_loading_builder')
source=load(HERE/'prepare.py','nativeui2_loading_source_runtime')
original_check=parent.source_check;original_observation=parent.observation_texts;original_validate=parent.validate_only_rc
def observation_texts():
    collect,validate=original_observation()
    return collect,parent.once(validate,"'0.2.24-nativeui1' if OPTIONS.arm=='ui'","'0.2.24-nativeui2' if OPTIONS.arm=='ui'")
def source_check():
    pins=original_check();source.verify()
    m=read(HERE/'runtime-manifest.json');assert m['kind']=='native-ui-jump-loading-runtime-v1' and m['product_pins']==PRODUCT_PINS
    for n,h in m['files'].items():assert sha(HERE/n)==h,n
    for n,h in PRODUCT_PINS.items():assert sha(PRODUCT_RECIPE/n)==h,n;pins[str(PRODUCT_RECIPE/n)]=h
    assert (HERE/'adapted-validation.py.txt').read_text('utf8')==observation_texts()[1]
    pins.update({str(HERE/n):h for n,h in m['files'].items()});pins[str(HERE/'runtime-manifest.json')]=sha(HERE/'runtime-manifest.json')
    return pins
def candidate_bundle():
    """Actual new product+driver; historical 9C/2DB0 retained only as host proof."""
    pins=source_check()
    if parent.OPTIONS is not None:assert parent.OPTIONS.arm=='ui','This adapter only runs nativeui2'
    for out in (PRODUCT,DRIVER):
        if not (out/'compile.json').is_file():raise parent.builder.base.NotReady('Actual compile.json required: '+str(out))
    manifest=load(PRODUCT_RECIPE/'prepare.py','nativeui2_product_source').verify()
    compiled=load(PRODUCT_RECIPE/'build.py','nativeui2_product_builder').verify(PRODUCT)
    assert compiled['candidate_sha256']==sha(PRODUCT/'RConnectMod.swf')==PRODUCT_SHA
    meta=read(PRODUCT/'prepared.json');assert meta['version']==manifest['version']=='0.2.24-nativeui2'
    historic=parent.ui_bundle();pins.update(historic['pins'])
    old=load(parent.ORDINARY,'nativeui2_original_ordinary');before=old.installed()
    environment=parent.env.verify_environment_change(parent.env.read(parent.env.HISTORICAL_ENV)['installation'],before)
    assert before==source.verify()['runtime_environment']==compiled['installation_before']==compiled['installation_after']
    assert manifest['required_runtime_host_sha256']==parent.selector.HOST_SHA
    try:proof=builder.verify(DRIVER)
    except builder.base.NotReady as e:raise parent.builder.base.NotReady(str(e)) from e
    assert proof['build_environment']==before;pins.update(proof['inputs'])
    pins.update({str((ROOT/n).resolve()):h for n,h in manifest['inputs'].items()})
    pins.update({str(PRODUCT_RECIPE/n):h for n,h in manifest['files'].items()})
    pins.update({str(PRODUCT/'src'/n):h for n,h in meta['source'].items()})
    pins.update({str(PRODUCT/'tools'/n):h for n,h in meta['inputs'].items()})
    for out,names in ((PRODUCT,('prepared.json','compile.json','RConnectMod.swf')),
                      (DRIVER,('prepared.json','compile.json','timing/EffectsDriver.swf','timing/EffectsHarness.swf'))):
        for n in names:pins[str(out/n)]=sha(out/n)
    bridge=dict(host=str(parent.UI_HOST/'pfe.swf'),host_sha256=parent.selector.HOST_SHA,sandy=None,sandy_sha256=None,
        pins=historic['pins'],scope='native-test-only',base_sha256=before['pfe.swf'])
    return dict(meta=meta,compile=compiled,pins=pins,installation=before,environment=environment,
        driver_proof=proof,bridge=bridge,product=PRODUCT)
def validate_only_rc(*args):
    # Only the generated expected-version constant changes during validation.
    assert parent.observation_texts is original_observation
    parent.observation_texts=observation_texts
    try:return original_validate(*args)
    finally:parent.observation_texts=original_observation
def main():
    if sys.argv[1:]==['--prepare-source']:
        with (HERE/'adapted-validation.py.txt').open('x',encoding='utf8',newline='\n') as f:f.write(observation_texts()[1])
        files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.suffix!='.pyc'}
        with (HERE/'runtime-manifest.json').open('x',encoding='utf8') as f:
            json.dump(dict(kind='native-ui-jump-loading-runtime-v1',files=files,product_pins=PRODUCT_PINS,
                enabled=['RConnectMod'],compiled=False,air_started=False),f,ensure_ascii=False,indent=2);f.write('\n')
        source_check();print('nativeui2 loading runtime source checked; no compiled qualification');return 0
    if sys.argv[1:]==['--source-check']:
        source_check();print('nativeui2 loading runtime source checked; no Java/AIR');return 0
    parent.source_check=source_check;parent.bundle=candidate_bundle;parent.DRIVER=DRIVER;parent.validate_only_rc=validate_only_rc
    if '--arm' not in sys.argv:sys.argv+=['--arm','ui']
    return parent.main()
if __name__=='__main__':raise SystemExit(main())
