"""One explicit prepare/build/run entry; frozen native runner, new diagnostic identity."""
from pathlib import Path
import argparse,difflib,hashlib,json,re,sys,types
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
TAIL=HERE.parent/'recovery-early-paint-tail-native'
KIND='scene-native-input-enter-bands-driver'
DIAGNOSTIC_KIND='ensure-work-enter-bands-v1'
OBSERVERS=('FirstRasterSceneProbe.as','PaintTimingBuffer.as','PaintTailSampler.as','FlashPaintTailSampler.as')
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def replace(text,old,new):
    assert text.count(old)==1,(old,text.count(old))
    return text.replace(old,new,1)
def load(name,path,text=None):
    module=types.ModuleType(name);module.__file__=str(path);sys.modules[name]=module
    if text is None:text=path.read_text(encoding='utf-8-sig')
    exec(compile(text,str(path),'exec'),module.__dict__)
    return module
def observer_source(name):
    assert name in OBSERVERS
    return HERE/'src'/name if name=='PaintTailSampler.as' else TAIL/'tests'/name
def source_pins():
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    old=(HERE.parent/'recovery-early-paint-tail-sampler-v3/src/PaintTailSampler.as').read_text(encoding='utf-8')
    new=observer_source('PaintTailSampler.as').read_text(encoding='utf-8')
    patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
        fromfile='frozen-v3/PaintTailSampler.as',tofile='render-boundary/PaintTailSampler.as'))
    assert patch==(HERE/'render-boundary.patch').read_text(encoding='utf-8')
    assert re.findall(r'\bapi\.\w+\(',old)==re.findall(r'\bapi\.\w+\(',new),'Sampler API sequence changed'
    assert not re.search(r'\.invalidate\s*\(|flash\.sampler|\b(?:startSampling|pauseSampling|stopSampling|getSamples)\s*\(',new)
    assert pins['diagnostic_only'] is True and pins['performance_qualified'] is False
    return pins

def bootstrap():
    source_pins()
    # Import the exact RV83 admission first; no installed hash is disguised.
    base=load('baseline',HERE.parent/'recovery-paint-native-cpu-rv83-v2/baseline.py')
    sys.path.insert(0,str(TAIL))
    native=load('native_inputs',TAIL/'native_inputs.py')
    prior_verify=native.verify_tools
    def verify_runtime():
        source_pins()
        # Old component proof is only the frozen v3 baseline/API provenance.
        # New helper receives its own source diff and new driver manifest below.
        return prior_verify()
    def verify_build():verify_runtime();return source_pins()
    native.verify_tools=verify_runtime

    # Reuse every common driver assertion; only identity, manifest filename and
    # the four observer source paths differ from the frozen aggregate recipe.
    path=HERE.parent/'recovery-early-paint-aggregate/binding.py'
    text=path.read_text(encoding='utf-8-sig')
    text=replace(text,"('FirstRasterSceneProbe.as','PaintTimingBuffer.as')",repr(OBSERVERS))
    text=replace(text,"sha(HERE/'tests'/n)","sha(observer_source(n))")
    text=replace(text,"path/'aggregate-inputs.json'","path/'render-inputs.json'")
    binding=load('binding',HERE/'binding-memory.py',text)
    binding.KIND=KIND;binding.DIAGNOSTIC_KIND=DIAGNOSTIC_KIND
    binding.verify_tools=verify_build;binding.observer_source=observer_source
    def verify_driver(path,meta,scenario):
        verify_runtime()
        assert path.resolve().parent==ROOT/'build/m52'
        return binding.verify_driver(path,meta,scenario)
    native.verify_driver=verify_driver

    runtime=load('runtime_adapter',TAIL/'runtime_adapter.py')
    runtime.KIND=DIAGNOSTIC_KIND
    inherited_outer=runtime.outer_source
    def outer_source():
        return replace(inherited_outer(),
            'RUNNER=Path(__file__).resolve().parent/"runtime_adapter.py"',
            'RUNNER=Path(__file__).resolve()')
    runtime.outer_source=outer_source
    return native,binding,runtime

def prepare_source():
    prior=load('boundary_prepare_recipe',TAIL/'prepare.py')
    text=prior.source()
    text=replace(text,'sha,read,installation\n','sha,read,installation,observer_source\n')
    text=replace(text,"shutil.copyfile(HERE/'tests'/n,out/'tests'/n)","shutil.copyfile(observer_source(n),out/'tests'/n)")
    text=replace(text,"diagnostic_kind='ensure-work-tail-cpu-v1'","diagnostic_kind="+repr(DIAGNOSTIC_KIND))
    text=replace(text,"out/'tail-inputs.json'","out/'render-inputs.json'")
    text=replace(text,"out/'tail-prepare.py'","out/'render-prepare.py'")
    return text

def main():
    parser=argparse.ArgumentParser(add_help=False);parser.add_argument('--output')
    options,_=parser.parse_known_args()
    output=(ROOT/options.output).resolve() if options.output else None
    writable=output is not None and output.parent==ROOT/'build/m52' and not output.exists()
    try:
        native,binding,runtime=bootstrap()
        mode=sys.argv[1] if len(sys.argv)>1 else 'check'
        if mode in ('check','prepare','run'):sys.argv.pop(1)
        if mode=='check':
            native.verify_tools();prepare_source()
            assert runtime.runner_source().count('assert_installation(args,output)')==1
            assert 'process_times' not in runtime.runner_source()
            print(json.dumps(dict(source_checked=True,new_kind=KIND,compiled=False,air_started=False,performance_qualified=False)))
        elif mode=='prepare':
            scope=dict(__file__=__file__,__name__='boundary_explicit_prepare')
            exec(compile(prepare_source(),__file__,'exec'),scope);scope['main']()
        elif mode=='run':
            scope=dict(__file__=__file__,__name__='boundary_outer_run')
            exec(compile((TAIL/'run_native.py').read_text(encoding='utf-8-sig'),__file__,'exec'),scope);scope['main']()
        else:
            # Only the unchanged outer runner issues this private child command.
            assert '--effects' in sys.argv and '--private-desktop' in sys.argv
            native.verify_tools()
            scope=dict(__file__=__file__,__name__='boundary_owned_native_runner')
            exec(compile(runtime.runner_source(),str(runtime.RUNNER),'exec'),scope);scope['main']()
    except BaseException as error:
        if isinstance(error,SystemExit) and error.code in (None,0):raise
        if writable:
            output.mkdir(exist_ok=True)
            receipt=dict(passed=False,error_type=type(error).__name__,error=str(error),
                diagnostic_only=True,performance_qualified=False,note='Inspect preserved runner evidence for whether AIR started')
            for name in ('error.json','result.json'):
                if not (output/name).exists():(output/name).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        raise
if __name__=='__main__':main()
