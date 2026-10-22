"""Retain the exact host03/early2/Sand003/RV7852 gates; add sampler admission."""
from pathlib import Path
import baseline as _tail_base
_tail_source=Path(__file__).resolve().parent.parent/'recovery-early-paint-aggregate/native_inputs.py'
assert _tail_base.sha(_tail_source)=='2cc826e9eab05326c101b5e2ba4b1b64c2f5a4b57cb65803f68a41250e03e750'
exec(compile(_tail_source.read_text(encoding='utf-8-sig'),str(_tail_source),'exec'),globals())
_tail_verify=verify_tools
def verify_tools():
    pins=_tail_verify()
    from sampler_admission import verify_component,verify_sampler_inputs
    verify_component();verify_sampler_inputs()
    return pins
