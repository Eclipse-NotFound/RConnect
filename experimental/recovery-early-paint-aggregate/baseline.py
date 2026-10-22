"""Exact RV187D installation, while isolated runs retain frozen RV7852.

Reuse immutable prior audits with only named dependency substitutions. No old
receipt/source is rewritten; the real installation map is never disguised.
"""
from pathlib import Path
import hashlib,json,types,sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
BASE=HERE.parent/'recovery-early-revisit-frozen-rv'
EXIT=HERE.parent/'recovery-early-exit-native'
RV_KEY='mods/RealisticVision/release/RealisticVisionMod.swf'
RV_OLD='7852f61e083993e69431d5d8ca2fdf3c07d4068715946d04b3e796cecbe86764'
RV_PREVIOUS='ab461ff3bdf77544bfb3e7f45b67265429d52280721fa8b8321ba92be2f23871'
RV_NEW='187d287b06fea10e6057c8e80287352062cff7577d075181261ddc0d04111272'
HOST_MANIFEST=M52/'recovery-early-paint-host-03/prepared.json'
HOST_MANIFEST_SHA='a81c362bea743106eaed4a3696224d2fe4e4764b483cbbda928ad9243a7b5d50'
PINS={
 BASE/'native_inputs.py':'c7ce9e09d74972e2d07c3fce1893f30a3c6263498a83e616f5a6084d081b7ebe',
 BASE/'baseline.py':'bd35df91bd206b550e28ced4ba09f003a93a1b33f3c594e41b14c165d8de13f7',
 BASE/'host_recheck.py':'9fb1ff00ff39e61bfbdf3a4da433765421e143d40c36efb9e198933da57eff40',
 EXIT/'native_inputs.py':'530550fe5ab85dabe033081012452d727324832e4d3a052b9540bc6f26263c93',
 HOST_MANIFEST:HOST_MANIFEST_SHA,
 HERE.parent/'recovery-early-paint-native/inputs.json':'fede0b5ebcbf0b6fe9e75c1bf7f4a31adaf48fef20d015cb51762f718b785c47',
 HERE.parent/'recovery-early-paint-native/source_compat.py':'f0228b73354f4ab008f7cbab88e72dfb5fcb2795e8c608ca5a54f4a2d8fa143b',
 HERE.parent/'recovery-early-paint-native/freeze.py':'a3a25780b152997c29695ccbd2183b820b5fd344d6328bb87215032d44b884e8'}

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def replace_once(text,old,new):
    assert text.count(old)==1,('Exact dependency substitution mismatch',old,text.count(old))
    return text.replace(old,new,1)
def module(name,path,edits=(),bindings=None):
    assert sha(path)==PINS[path],str(path)
    text=path.read_text(encoding='utf-8-sig')
    for old,new in edits:text=replace_once(text,old,new)
    result=types.ModuleType(name);result.__file__=str(path)
    if bindings:result.__dict__.update(bindings)
    exec(compile(text,str(path),'exec'),result.__dict__)
    return result

legacy_baseline=module('aggregate_original_rv_baseline',BASE/'baseline.py')
sys.path.insert(0,str(ROOT/'tools/validation'))
from run_security_terminals import installation

def expected_installation():
    assert sha(HOST_MANIFEST)==HOST_MANIFEST_SHA
    previous=read(HOST_MANIFEST)['installation_before']
    assert len(previous)==22 and previous[RV_KEY]==RV_PREVIOUS
    result=dict(previous);result[RV_KEY]=RV_NEW
    return result

def assert_current(current,original_map):
    expected=expected_installation()
    assert current==expected,'Only the exact RV187D installation is admitted'
    assert len(original_map)==22 and original_map.get(RV_KEY) in (RV_OLD,RV_PREVIOUS,RV_NEW)
    prior=dict(original_map);prior[RV_KEY]=RV_NEW
    assert prior==expected,'Only the RV7852 -> AB46 -> 187D source baseline transition may differ'

def frozen_vision():
    # This original check pins RV7852 bytes, size, backup, and its actual old
    # deployment receipt. It does not select the currently installed RV.
    path=legacy_baseline.frozen_vision()
    assert sha(path)==RV_OLD
    return path

def load_host_review(path):
    assert path==BASE/'host_recheck.py'
    return module('aggregate_original_native_host_review',path,
       [('from baseline import assert_current','# Explicit exact RV187D baseline dependency')],
       {'assert_current':assert_current})

original=module('aggregate_original_native_inputs',BASE/'native_inputs.py',[
 ('from baseline import assert_current,frozen_vision,RV_KEY,RV_OLD,RV_NEW',
  '# Explicit exact RV187D baseline dependencies'),
 ('module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)',
  'module=load_host_review(recipe)')],
 {'assert_current':assert_current,'frozen_vision':frozen_vision,'RV_KEY':RV_KEY,
  'RV_OLD':RV_OLD,'RV_NEW':RV_NEW,'load_host_review':load_host_review})

EARLY_IMPORT='''sys.path.insert(0,str(BASE))
spec=importlib.util.spec_from_file_location('early_exit_original_inputs',BASE/'native_inputs.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)'''
early=module('aggregate_early2_native_inputs',EXIT/'native_inputs.py',[
 (EARLY_IMPORT,'# Explicit unchanged early1 audit dependency with exact RV187D baseline')],{'original':original})

def verify_tools():
    for path,digest in PINS.items():assert sha(path)==digest,str(path)
    early.verify_tools()
    current=installation();assert_current(current,read(HOST_MANIFEST)['installation_before'])
    frozen_vision()
    return dict(original_source_sha256={str(p):h for p,h in PINS.items()},
       installed_rv_sha256=RV_NEW,previous_installed_rv_sha256=RV_PREVIOUS,
       runtime_rv_sha256=RV_OLD,installation=current)

def audit(candidate):verify_tools();return early.audit(candidate)
def sandy_input(mode):
    verify_tools();assert mode=='bridge'
    return early.sandy_input(mode)
