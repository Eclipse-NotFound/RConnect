"""Reuse the official isolated selector; request exactly RConnectMod."""
from pathlib import Path
import difflib,hashlib,importlib.util,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
BASE=HERE.with_name('recovery-room-reduced-runtime')/'launcher.py'
BASE_SHA='a5d3a120216c7573a4c26c6c923b821b53dbfeb9608ca3a4d5a93f017ab72601'
DISABLED={'AddictionSystemMod','ContinuousSceneMod','FirearmAttachmentsMod','LightAndDarknessMod',
 'LootEditorMod','ModLoaderMod','MoreSkillsWeaponsMod','PermanentInjuryMod','RandomRoomsMod',
 'RealisticVisionMod','SandevistanMod','TDFCMod','WallBlendMod'}
EDITS=(
 ("DISABLED = {'LightAndDarknessMod', 'RealisticVisionMod', 'ContinuousSceneMod'}",
  'DISABLED = '+repr(sorted(DISABLED))+'\nDISABLED = set(DISABLED)'),
 ("assert 'RConnectMod' in enabled and 'ModLoaderMod' in enabled", "assert enabled == {'RConnectMod'}"),
 ('assert args.seconds == 600 and args.game_root.resolve()',
  'assert args.seconds in (300,360) and args.game_root.resolve()'),
 ('    runner.run_registered = registered\n    runner.main()\n',
  '    bind_registered(registered)\n    runner.run_registered = invoke_registered\n    runner.main()\n'))
_registered=None

def source():
 assert hashlib.sha256(BASE.read_bytes()).hexdigest()==BASE_SHA
 old=BASE.read_text('utf8');new=old
 for before,after in EDITS:
  assert new.count(before)==1 and after not in new
  new=new.replace(before,after)
 restored=new
 for before,after in reversed(EDITS):restored=restored.replace(after,before)
 assert restored==old
 compile(new,str(BASE),'exec')
 return new,''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
  fromfile='frozen/official-selector.py',tofile='only-rc/selector.py'))

def load():
 text,_=source();spec=importlib.util.spec_from_loader('only_rc_official_selector',loader=None)
 module=importlib.util.module_from_spec(spec);module.__file__=str(BASE)
 exec(compile(text,str(BASE),'exec'),module.__dict__)
 assert module.DISABLED==DISABLED
 return module

def run_registered(*args,**kwargs):
 assert _registered is not None
 return _registered(*args,**kwargs)

def main():
 global _registered
 module=load()
 def bind(fn):
  global _registered
  assert _registered is None
  _registered=fn
 module.bind_registered=bind
 module.invoke_registered=lambda *args,**kwargs:run_registered(*args,**kwargs)
 try:return module.main()
 finally:_registered=None

if __name__=='__main__':main()
