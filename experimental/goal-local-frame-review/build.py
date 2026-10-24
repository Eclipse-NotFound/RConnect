"""One diagnostic driver via the frozen native builder; root alone runs --build."""
from pathlib import Path
import hashlib, importlib.util, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
BASE=HERE.parent/'goal-three-issues-native'
SOURCE=BASE/'build.py'
SOURCE_SHA='8b85f7e63f4b6f4294ef25eef928f21fa5949fb06f521b6e3eaf6d662dc94944'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
assert sha(SOURCE)==SOURCE_SHA
base=load(SOURCE,'goal_cpu_original_native_builder')
prepare=load(HERE/'prepare.py','goal_cpu_prepare')
read,save,installed=base.read,base.save,base.installed
PRODUCT,PRODUCT_SHA,HOST_SHA,ABI_HASHES=base.PRODUCT,base.PRODUCT_SHA,base.HOST_SHA,base.ABI_HASHES
EDITS=(
    ("CASES={'native-jump':'NativeJumpNetworkTestDoc.as','fast-held':'FastHeldTestDoc.as'}",
     "CASES={'native-jump':'NativeJumpNetworkTestDoc.as'}",1),
    (" assert len(c['commands'])==2", " assert len(c['commands'])==len(CASES)",1),
    ("'native-motion-measurement-v1'", "'ordinary-native-jump-cpu-v1'",2))
def adapted_source():
    assert sha(SOURCE)==SOURCE_SHA
    text=SOURCE.read_text('utf8')
    for old,new,count in EDITS:
        assert text.count(old)==count,old
        text=text.replace(old,new)
    return text
def inputs():
    pins=base.inputs() # Real original environment, product, ABI and source checks.
    prepare.check()
    assert (HERE/'adapted-build.py.txt').read_text('utf8')==adapted_source()
    manifest=read(HERE/'source-manifest.json')
    paths=[HERE/n for n in ('build.py','run.py','analyze.py','prepare.py','README.md',
      'source-manifest.json','source.diff','adapted-build.py.txt')]
    paths += list((HERE/'tests').glob('*.as'))+[Path(p) for p in manifest['original']]
    paths += [BASE/'FROZEN.json',BASE/'run.py',BASE/'analyze.py',
      HERE.parent/'recovery-after-render-sampler/analyze.py']
    for p in paths:pins[str(p.resolve())]=sha(p)
    return pins

delegate={'__file__':str(SOURCE),'__name__':'goal_cpu_bound_native_builder'}
exec(compile(adapted_source(),str(HERE/'adapted-build.py.txt'),'exec'),delegate)
delegate.update(HERE=HERE,inputs=inputs,installed=installed)
def verify(out):return delegate['verify'](out)
def main():return delegate['main']()
if __name__=='__main__':main()
