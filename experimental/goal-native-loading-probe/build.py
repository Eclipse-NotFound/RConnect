"""One diagnostic driver through the frozen bounded builder; root alone runs --build."""
from pathlib import Path
import hashlib, importlib.util, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=HERE.parent/'goal-three-issues-native'
SOURCE=BASE/'build.py'
SOURCE_SHA='8b85f7e63f4b6f4294ef25eef928f21fa5949fb06f521b6e3eaf6d662dc94944'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p,name):
    spec=importlib.util.spec_from_file_location(name,p)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
assert sha(SOURCE)==SOURCE_SHA
base=load(SOURCE,'loading_probe_original_bounded_builder')
prepare=load(HERE/'prepare.py','loading_probe_source_prepare')
read,save,installed=base.read,base.save,base.installed
PRODUCT,PRODUCT_SHA,HOST_SHA,ABI_HASHES=base.PRODUCT,base.PRODUCT_SHA,base.HOST_SHA,base.ABI_HASHES
EDITS=(
 ("CASES={'native-jump':'NativeJumpNetworkTestDoc.as','fast-held':'FastHeldTestDoc.as'}",
  "CASES={'timing':'RoomTravelTimingTestDoc.as'}",1),
 (" assert len(c['commands'])==2"," assert len(c['commands'])==len(CASES)",1),
 ("'native-motion-measurement-v1'","'native-loading-observer-v1'",2),
 ('Compile two native measurement fixtures using the existing external ABI.',
  'Compile one ordinary-travel loading observer using the existing external ABI.',1),
 ('RConnect / 原生运动测量','RConnect / 原生加载观察',1),
 ('Compile two native measurement fixtures; no AIR','Compile one native-loading observer; no AIR',1),
 ('native motion fixture compiler ','native loading observer compiler ',1),
 ('Two measurement fixtures compiled; no native/performance qualification',
  'One loading observer compiled; no native/performance qualification',1))
def adapted_source():
    assert sha(SOURCE)==SOURCE_SHA
    text=SOURCE.read_text('utf8')
    for old,new,count in EDITS:
        assert text.count(old)==count,old
        text=text.replace(old,new)
    return text
def inputs():
    pins=base.inputs()
    prepare.check()
    assert (HERE/'adapted-build.py.txt').read_text('utf8')==adapted_source()
    ordinary_path=HERE.parent/'goal-ordinary-loading/run.py'
    assert sha(ordinary_path)=='5613e8bca191116797bac42af1d7054cfe99516dd5a32d8f1b44168d896b3502'
    ordinary=load(ordinary_path,'loading_probe_original_ordinary_binding')
    pins.update(ordinary.inputs(PRODUCT)[2])
    m=read(HERE/'source-manifest.json')
    paths=[HERE/n for n in ('build.py','prepare.py','README.md','source-manifest.json','source.diff','adapted-build.py.txt')]
    paths+=list((HERE/'tests').glob('*.as'))+[Path(p) for p in m['original']]
    for p in paths:pins[str(p.resolve())]=sha(p)
    return pins
delegate={'__file__':str(SOURCE),'__name__':'loading_probe_bound_builder'}
exec(compile(adapted_source(),str(HERE/'adapted-build.py.txt'),'exec'),delegate)
delegate.update(HERE=HERE,inputs=inputs,installed=installed)
def verify(out):return delegate['verify'](out)
def main():return delegate['main']()
if __name__=='__main__':main()
