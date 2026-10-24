"""Same two native motion fixtures, with honest historical/current RV bindings."""
from pathlib import Path
import ast,difflib,hashlib,importlib.util,json,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.with_name('goal-three-issues-native')
ENV=HERE.with_name('goal-native-loading-native-v2')
RECIPE=HERE.with_name('goal-self-echo-prune')
DRIVERS=M52/'goal-three-issues-native-drivers-02'
BASELINE=M52/'recovery-room-production-05'
CANDIDATE=M52/'goal-self-echo-product-01'
OLD_PINS={
 'run.py':'2dc340ab793e95fec7abab6d3061a789255d6b0afe861036b96ee654ac36ed12',
 'build.py':'8b85f7e63f4b6f4294ef25eef928f21fa5949fb06f521b6e3eaf6d662dc94944',
 'analyze.py':'ac369d4d4a63607e737a550730df609c328be73792bd0e971468b2427b0c0508',
 'environment.json':'6f2a70bbe43d6729903a0ba2577d0687206442e684d74b787b96ee2cde8eebd0'}
ENV_PINS={
 'run.py':'a5b2ce70fcef52bd5960715fb0d29289f5124acf5139387db92e30aefc1782f3',
 'runtime-environment.json':'3214299ed82486102fd118f214825da5ea48f776be1842a4aa74a4db4c104de6'}
DRIVER_PINS={
 'prepared.json':'f80d5e5520eea127e12ae70744028d254978938d6127d7622a9ade5a5db9acc3',
 'compile.json':'9d4f654559cf767d626ef3e9089c9790ce41072ff71472b727a586fc63b81f0c',
 'native-jump/EffectsDriver.swf':'9ee16fa6ea2db8e0441a49e53f7ac55a4d5980c113706881e5cadd2d6f4c1e84',
 'fast-held/EffectsDriver.swf':'fef72ab405e5df894b1e683e40d6171fa9cbd1d543aac6d2a75f5f51402317cb'}
CANDIDATE_PINS={
 'build.py':'30bef16cde7de5fc02b4a73b270effc1c6e991f944c57f31922d4b68f06de24d',
 'source-manifest.json':'318748f65a52039ff7acc2df076e3764a01d663b532b66ad7f62a99ddd89244e'}
class NotReady(Exception):pass
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
def function_text(path,name):
    text=Path(path).read_text('utf8');nodes=[n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert len(nodes)==1
    return ''.join(text.splitlines(True)[nodes[0].lineno-1:nodes[0].end_lineno])
def expanded_build():
    inputs=function_text(OLD/'build.py','inputs')
    inputs=once(inputs," env=read(HERE/'environment.json'); assert installed()==env['installation']",
                " env=read(HERE/'environment.json'); verify_environment_change(env['installation'],installed())")
    verify=function_text(OLD/'build.py','verify')
    verify=once(verify," assert m['inputs']==inputs() and m['installation_before']==c['installation_before']==c['installation_after']==installed()",
                " assert m['inputs']==inputs() and m['installation_before']==c['installation_before']==c['installation_after']\n"
                " verify_environment_change(m['installation_before'],installed())")
    verify=once(verify,"compile_sha256=sha(out/'compile.json'),installation=installed(),smoothnessQualified=False)",
                "compile_sha256=sha(out/'compile.json'),build_environment=m['installation_before'],runtime_environment=installed(),smoothnessQualified=False)")
    return inputs+'\n'+verify
def expanded_run():
    text=(OLD/'run.py').read_text('utf8')
    text=once(text,'import build\nfrom analyze import summarize','build=CURRENT_BUILD\nsummarize=ORIGINAL_SUMMARIZE')
    text=once(text,function_text(OLD/'run.py','product'),
              'def product(path):\n return selfecho_product(path)\n')
    text=once(text,'assert out.parent==M52 and not out.exists()',
              "assert out.parent==M52 and out.name.startswith('goal-self-echo-native-') and not out.exists()")
    return text
def inputs():
    m=read(HERE/'source-manifest.json')
    assert m['kind']=='self-echo-native-motion-binding-v1' and m['run_replacements']==3 and m['build_replacements']==3
    for n,h in m['files'].items():assert sha(HERE/n)==h,n
    for n,h in m['inputs'].items():assert sha(n)==h,n
    for folder,pins in ((OLD,OLD_PINS),(ENV,ENV_PINS),(DRIVERS,DRIVER_PINS),(RECIPE,CANDIDATE_PINS)):
        for n,h in pins.items():assert sha(folder/n)==h,n
    assert (HERE/'adapted-run.py.txt').read_text('utf8')==expanded_run()
    assert (HERE/'adapted-build.py.txt').read_text('utf8')==expanded_build()
    pins=dict(m['inputs']);pins.update({str(HERE/n):h for n,h in m['files'].items()})
    pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
    return pins
def binding():
    environment=load(ENV/'run.py','selfecho_environment_only')
    original=load(OLD/'build.py','selfecho_historical_driver_builder')
    scope=dict(vars(original),verify_environment_change=environment.verify_environment_change)
    exec(compile(expanded_build(),str(HERE/'adapted-build.py.txt'),'exec'),scope)
    def verify(out):
        assert Path(out).resolve()==DRIVERS
        pins=inputs();proof=scope['verify'](out)
        for case in ('native-jump','fast-held'):
            assert proof['artifacts'][case+'/EffectsDriver.swf']==DRIVER_PINS[case+'/EffectsDriver.swf']
        proof['historical_inputs']=dict(proof['inputs'])
        proof['inputs']=proof['inputs']|pins
        return proof
    public=dict(vars(original));public.update(inputs=scope['inputs'],verify=verify)
    return types.SimpleNamespace(**public),environment
def product(path,build,environment):
    path=Path(path).resolve();assert path in (BASELINE,CANDIDATE)
    pins=inputs();current=build.installed()
    transition=environment.verify_environment_change(read(OLD/'environment.json')['installation'],current)
    if path==BASELINE:
        build.inputs()
        meta,receipt=read(path/'prepared.json'),read(path/'compile.json')
        digest=build.PRODUCT_SHA;version='0.2.24-roomfix5'
    else:
        required=[RECIPE/'build.py',path/'prepared.json',path/'compile.json',path/'RConnectMod.swf']
        missing=[str(p) for p in required if not p.is_file()]
        if missing:raise NotReady('Missing complete selfecho build: '+json.dumps(missing))
        builder=load(RECIPE/'build.py','selfecho_actual_product_verifier')
        receipt=builder.verify(path);meta=read(path/'prepared.json')
        assert meta['version']=='0.2.24-selfecho1' and meta['base_sha256']==build.PRODUCT_SHA
        assert receipt['compiled'] and receipt['candidate_sha256']==sha(path/'RConnectMod.swf')
        assert meta['installation_before']==receipt['installation_before']==receipt['installation_after']==current
        digest=receipt['candidate_sha256'];version='0.2.24-selfecho1'
    pins.update({str(path/n):sha(path/n) for n in ('RConnectMod.swf','prepared.json','compile.json')})
    return dict(path=str(path),sha256=digest,version=version,receipt=receipt,pins=pins,
                build_environment=meta['installation_before'],driver_build_environment=transition['build_environment'],
                runtime_environment=transition['runtime_environment'],runtime_transition=transition)
def main():
    inputs()
    if sys.argv[1:]==['--source-check']:
        ast.parse(expanded_run());ast.parse(expanded_build())
        print(json.dumps(dict(source_checked=True,compiled=False,air_started=False)));return 0
    build,environment=binding();analyzer=load(OLD/'analyze.py','selfecho_original_analyzer')
    namespace={'__file__':str(OLD/'run.py'),'__name__':'selfecho_native_bound_original',
               'CURRENT_BUILD':build,'ORIGINAL_SUMMARIZE':analyzer.summarize,
               'selfecho_product':lambda path:product(path,build,environment)}
    exec(compile(expanded_run(),str(HERE/'adapted-run.py.txt'),'exec'),namespace)
    assert namespace['CASES']=={'native-jump':dict(seconds=300,done='native-jump',rounds=[0],checks={'host':6,'join':6}),
        'fast-held':dict(seconds=360,done='tele-motion',rounds=[0,1,2,3],checks={'host':43,'join':42})}
    try:return namespace['main']()
    except NotReady as error:
        print(json.dumps(dict(ready=False,checked=False,air_started=False,reason=str(error))));return 2
if __name__=='__main__':raise SystemExit(main())
