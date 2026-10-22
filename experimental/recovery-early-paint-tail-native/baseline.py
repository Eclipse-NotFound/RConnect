"""Borrow the immutable aggregate baseline, retaining its own paths and audits."""
from pathlib import Path
import hashlib,types
_path=Path(__file__).resolve().parent.parent/'recovery-early-paint-aggregate/baseline.py'
assert hashlib.sha256(_path.read_bytes()).hexdigest()=='e7671db78f696c0988a1031e7332677fe2bdace400f4b1f6337e22b2869ee19a'
_text=_path.read_text(encoding='utf-8-sig')
# Root verified this single installed-RV update. Runtime still uses frozen RV7852.
for _old,_new in (
 ("RV_NEW='187d287b06fea10e6057c8e80287352062cff7577d075181261ddc0d04111272'",
  "RV_NEW='6593ee35008a898bd2d2b1189693a17bd0767c387697bcbee73a387f8fd6ec06'"),
 ("in (RV_OLD,RV_PREVIOUS,RV_NEW)",
  "in (RV_OLD,RV_PREVIOUS,'187d287b06fea10e6057c8e80287352062cff7577d075181261ddc0d04111272',RV_NEW)"),
 ('Only the exact RV187D installation is admitted','Only the exact RV6593 installation is admitted'),
 ('Only the RV7852 -> AB46 -> 187D source baseline transition may differ',
  'Only the RV7852 -> AB46 -> 187D -> 6593 source baseline transition may differ')):
    assert _text.count(_old)==1,_old
    _text=_text.replace(_old,_new,1)
_base=types.ModuleType('tail_frozen_aggregate_baseline');_base.__file__=str(_path)
exec(compile(_text,str(_path),'exec'),_base.__dict__)
globals().update({k:v for k,v in vars(_base).items() if not k.startswith('__')})
