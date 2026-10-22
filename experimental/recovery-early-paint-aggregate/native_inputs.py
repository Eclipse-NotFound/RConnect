"""Reuse the exact host03 admission with aggregate observer / RV187D dependencies."""
from pathlib import Path
import baseline as _aggregate_baseline

_HERE=Path(__file__).resolve().parent
_PRIOR=_HERE.parent/'recovery-early-paint-native'
_SOURCE=_PRIOR/'native_inputs.py'
_SHA='b0bab671695e2fcce8e89f4b97575c75b380ab9dfe8adc30d121b015b3aec678'
assert _aggregate_baseline.sha(_SOURCE)==_SHA
_text=_SOURCE.read_text(encoding='utf-8-sig')
_EDITS=(
 ("DRIVER=HERE.parent/'recovery-early-paint-driver-v2'","DRIVER=HERE"),
 ("early=load('paint_native_frozen_early_exit_inputs',EXIT/'native_inputs.py')","early=_aggregate_baseline"),
 ("driver=load('paint_native_frozen_v2_driver_binding',DRIVER/'binding.py')","driver=load('aggregate_driver_binding',HERE/'binding.py')"),
 ("profile=load('paint_native_frozen_profile_audit',driver.V1/'audit_profile.py')","profile=load('aggregate_runtime_profile_audit',HERE/'audit_runtime.py')"),
 ("HERE/'inputs.json'","HERE/'runtime-inputs.json'"),
 ("HERE/'source_compat.py'","_PRIOR/'source_compat.py'"))
for _old,_new in _EDITS:
    _expected=2 if _old=="HERE/'inputs.json'" else 1
    assert _text.count(_old)==_expected,(_old,_text.count(_old))
    _text=_text.replace(_old,_new,_expected)
# The complete original audit/host qualification/error fields are retained.
exec(compile(_text,str(_SOURCE),'exec'),globals())

# The borrowed compatibility proof is immutable too; its exact dependencies
# are verified by the original contract and frozen runtime original map.
_compatibility=compatibility
def compatibility():
    pins=read(_PRIOR/'inputs.json')
    assert sha(_PRIOR/'source_compat.py')==pins['sources']['source_compat.py']
    return dict(proof_scope='host03 callback contract only',aggregate_helper_changed=True,
        legacy_host_contract=_compatibility())
