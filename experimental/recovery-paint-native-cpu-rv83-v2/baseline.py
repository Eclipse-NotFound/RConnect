"""Admit only the independently deployed RV83 installation; runtime stays RV7852."""
from pathlib import Path
import hashlib,types
_source=Path(__file__).resolve().parent.parent/'recovery-early-paint-tail-native/baseline.py'
assert hashlib.sha256(_source.read_bytes()).hexdigest()=='f6d937d17e3bde238be0c974f226a62e537a4f9edb62fc8d1e367afe6512f2da'
_text=_source.read_text(encoding='utf-8-sig')
_old='6593ee35008a898bd2d2b1189693a17bd0767c387697bcbee73a387f8fd6ec06'
_new='83d8e590c062e181b70bd5cabef2200084d5e81aaca081d1d1ebc347205c7e65'
assert _text.count(_old)==1
_text=_text.replace(_old,_new,1).replace('Only the exact RV6593 installation is admitted','Only the exact RV83D8 installation is admitted')
_history="in (RV_OLD,RV_PREVIOUS,'187d287b06fea10e6057c8e80287352062cff7577d075181261ddc0d04111272',RV_NEW)"
assert _text.count(_history)==1
# E6B3 was compiled while RV6593 was installed. This admits that immutable
# historical manifest only; the live installation must still equal RV83D8.
_text=_text.replace(_history,_history.replace(',RV_NEW)',",'"+_old+"',RV_NEW)"),1)
_module=types.ModuleType('rv83_exact_tail_baseline');_module.__file__=str(_source)
exec(compile(_text,str(_source),'exec'),_module.__dict__)
globals().update({k:v for k,v in vars(_module).items() if not k.startswith('__')})

