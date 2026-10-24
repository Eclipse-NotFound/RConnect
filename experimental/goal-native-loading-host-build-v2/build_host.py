"""One-opcode provenance correction; privately reuse the frozen six-step builder."""
from pathlib import Path
import hashlib, importlib.util, sys

if sys.flags.optimize:
 raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OLD=HERE.with_name('goal-native-loading-build')
OLD_PINS={
 'activation_slots.py':'9cccdc8066a0fff7d43cad503d330b6a24f388df70ff10f0140a48dd44f40ac5',
 'build_host.py':'807b6acabbeb3c0087a76d2b9e3523de9ad029089461f574131fe019e26418ae',
 'build_product.py':'69f3f1a303de78387dd243efbeb414ab83f2afe40c4964ccc2f8c01f9aaf3b68',
 'inputs.py':'39f9a735e2bd56a8775026ecee16132269f727aa92478960ae4e63290a9270dc',
 'README.md':'cf678ee48d27aeee77e560f7edeb67a627497ef6dd8f74d01fbd5e5f4b708b23',
 'retain.py':'dabe347416f0820d043584d7fc8f99222540f590a57e53d060279d4f17424655',
 'reused-tools.diff':'ee6d36cff4063693f72019b9a05b3975999e2da43a84d2864c9940196401bd5f',
}
OLD_LINE=b'0xab,0xac,0xad,0xae,0xaf,0xb3):replace(2)'
NEW_LINE=b'0xab,0xac,0xad,0xae,0xaf,0xb0,0xb3):replace(2)'

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def exact_sources():
 for name,expected in OLD_PINS.items():assert sha(OLD/name)==expected,name
 original=(OLD/'activation_slots.py').read_bytes()
 assert original.count(OLD_LINE)==1
 assert (HERE/'activation_slots.py').read_bytes()==original.replace(OLD_LINE,NEW_LINE,1),'Only greaterequals support may change'

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path)
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 return module

exact_sources()
legacy=load('native_ui_v2_original_builder',OLD/'build_host.py')
assert Path(legacy.retain.source.__file__).resolve()==OLD/'inputs.py','Unexpected imported source module'
proof=load('native_ui_v2_activation_provenance',HERE/'activation_slots.py')
# body_names resolves the legacy retainer's globals; retain() also calls its
# own slotproof directly. Both must use this exact proof implementation.
legacy.retain.slotproof=proof
legacy.retain.legacy.slotproof=proof
original_pins=legacy.pins

def pins():
 exact_sources()
 assert legacy.retain.slotproof is proof and legacy.retain.legacy.slotproof is proof
 result=original_pins()
 for path in sorted(HERE.iterdir()):
  if path.is_file() and path.suffix in ('.py','.md','.diff'):result[str(path)]=sha(path)
 return result

legacy.pins=pins
legacy.DEFAULT=ROOT/'build/m52/goal-native-loading-host-03'
prepare=legacy.prepare
frozen=legacy.frozen
build=legacy.build
verify=legacy.verify
retain=legacy.retain
source=legacy.source
commands=legacy.commands
target=legacy.target
main=legacy.main

if __name__=='__main__':main()
