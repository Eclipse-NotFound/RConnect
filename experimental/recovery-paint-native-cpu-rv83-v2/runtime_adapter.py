"""Exact CPU observer, with the sole installed-RV baseline change imported first."""
from pathlib import Path
import hashlib
import baseline
_source=Path(__file__).resolve().parent.parent/'recovery-paint-native-cpu/runtime_adapter.py'
assert hashlib.sha256(_source.read_bytes()).hexdigest()=='960705150bbdcb40610cac5df74a20d43303986eb404842b7082078962dfa3ab'
_text=_source.read_text(encoding='utf-8-sig')
_entry="if __name__=='__main__':main()\n"
assert _text.endswith(_entry)
_scope=dict(__file__=str(_source),__name__='unchanged_owned_cpu_observer')
exec(compile(_text[:-len(_entry)],str(_source),'exec'),_scope)
outer_source=_scope['outer_source']
verify_inputs=_scope['verify_inputs']
if __name__=='__main__':_scope['main']()

