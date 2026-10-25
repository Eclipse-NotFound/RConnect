"""Original onlyRC selector, admitting only the exact native UI host candidate."""
from pathlib import Path
import hashlib,importlib.util,sys,types
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.with_name('goal-rconnect-only-motion')/'selector.py'
OLD_SHA='2bbe601d0a09bd33909aba8a0e48ab32fe3aab096dc9bf29f7f84962d176d345'
HOST=ROOT/'build/m52/goal-native-loading-host-03/pfe.swf'
HOST_SHA='2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
BEFORE='args.game_candidate is None'
AFTER='bundle_game_candidate(args.game_candidate)'
_registered=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def game_candidate(path):
 if path is None:return False
 path=Path(path).resolve()
 return path==HOST.resolve() and path.is_file() and sha(path)==HOST_SHA
def source():
 assert sha(OLD)==OLD_SHA
 spec=importlib.util.spec_from_file_location('nativeui2_original_selector',OLD)
 old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
 text,_=old.source();assert text.count(BEFORE)==1 and AFTER not in text
 adapted=text.replace(BEFORE,AFTER);assert adapted.replace(AFTER,BEFORE)==text
 compile(adapted,str(OLD),'exec')
 return old,adapted
def check():
 source()
 assert not game_candidate(None)
 assert not game_candidate(ROOT.parents[1]/'pfe.swf')
 assert not game_candidate(HERE/'pfe.swf')
 assert game_candidate(HOST)
 return dict(checks=4,host_sha256=HOST_SHA,air_started=False)
def run_registered(*args,**kwargs):
 assert _registered is not None
 return _registered(*args,**kwargs)
def main():
 global _registered
 old,text=source();module=types.ModuleType('nativeui2_official_selector');module.__file__=str(old.BASE)
 module.bundle_game_candidate=game_candidate
 exec(compile(text,str(old.BASE),'exec'),module.__dict__)
 def bind(fn):
  global _registered
  assert _registered is None;_registered=fn
 module.bind_registered=bind
 module.invoke_registered=lambda *args,**kwargs:run_registered(*args,**kwargs)
 try:return module.main()
 finally:_registered=None
if __name__=='__main__':main()
