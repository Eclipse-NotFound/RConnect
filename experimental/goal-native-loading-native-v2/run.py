"""Only substitute the corrected host verifier and default host03 in the frozen UI run."""
from pathlib import Path
import difflib,hashlib,json,sys
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
EDITS=(
 ("load(UI_BUILD/'build_host.py','ui_runtime_host_builder')",
  "load(V2_HOST_BUILDER,'ui_runtime_host_builder_v2')"),
 ("    ap.add_argument('--host',type=Path,default=Path('build/m52/goal-native-loading-host-01'))",
  "    ap.add_argument('--host',type=Path,default=Path('build/m52/goal-native-loading-host-03'))"))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def adapted():
    assert sha(SOURCE)==SOURCE_SHA and sha(OLD/'source-manifest.json')==OLD_MANIFEST_SHA
    text=SOURCE.read_text('utf8')
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text
def exact_pins():
    text=adapted();m=read(HERE/'source-manifest.json')
    assert m['kind']=='native-loading-runtime-host-verifier-v2' and m['replacements']==2
    assert m['original_sha256']==SOURCE_SHA and m['original_manifest_sha256']==OLD_MANIFEST_SHA
    assert m['host_verifier']==V2_PINS
    assert (HERE/'adapted-entry.py.txt').read_text('utf8')==text
    paths={str(SOURCE):SOURCE_SHA,str(OLD/'source-manifest.json'):OLD_MANIFEST_SHA}
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
    namespace={'__file__':str(SOURCE),'__name__':'native_loading_runtime_host_v2','V2_HOST_BUILDER':V2/'build_host.py'}
    exec(compile(adapted(),str(HERE/'adapted-entry.py.txt'),'exec'),namespace)
    original_bundle=namespace['bundle']
    def bundle():
        current=exact_pins();assert current==pins
        value=original_bundle() # Genuine product/probe verification and actual v2 host.verify.
        assert value['product']==ROOT/'build/m52/goal-native-loading-product-01'
        assert value['compile']['candidate_sha256']==PRODUCT_SHA
        assert value['driver']==ROOT/'build/m52/goal-native-loading-probe-driver-01'
        assert value['driver_proof']['artifacts']['timing/EffectsDriver.swf']==DRIVER_SHA
        value['pins'].update(current)
        return value
    namespace['bundle']=bundle
    return namespace['main']()
if __name__=='__main__':raise SystemExit(main())
