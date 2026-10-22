"""Exact frozen aggregate build/driver audit, four diagnostic AS files only."""
from pathlib import Path
import baseline as _base
_dir=Path(__file__).resolve().parent
_source=_dir.parent/'recovery-early-paint-aggregate/binding.py'
assert _base.sha(_source)=='0bb8bdb7e8139c48425cadc2351fc15bc2eec6dd0101d28c7d0b90765dcb414c'
_text=_source.read_text(encoding='utf-8-sig')
for _old,_new in (
 ("scene-native-input-early-paint-aggregate-driver","scene-native-input-early-paint-tail-driver"),
 ("ensure-work-aggregate-v1","ensure-work-tail-cpu-v1"),
 ("PROBE_SHA='a1e5298292f33aa30dee4f827eb89d39270b1ae181c086ae3ff67b8c83f593e7'",
  "PROBE_SHA="+repr(_base.sha(_dir/'tests/FirstRasterSceneProbe.as'))),
 ("('FirstRasterSceneProbe.as','PaintTimingBuffer.as')",
  "('FirstRasterSceneProbe.as','PaintTimingBuffer.as','PaintTailSampler.as','FlashPaintTailSampler.as')"),
 ("aggregate-inputs.json","tail-inputs.json")):
    _text=_base.replace_once(_text,_old,_new)
exec(compile(_text,str(_source),'exec'),globals())
