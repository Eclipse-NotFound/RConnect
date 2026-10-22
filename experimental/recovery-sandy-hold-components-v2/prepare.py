"""Repair only the external fixture's multiple-definition compile error."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT/'experimental/recovery-sandy-hold-components'
spec = importlib.util.spec_from_file_location('hold_original_checks', OLD/'prepare.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
prior.verify()
assert not (HERE/'components').exists()
source = (OLD/'components/SandyTravelHoldChecks.as').read_text(encoding='utf-8')
marker = ' internal final class HoldWorld {\n'
assert source.count(marker) == 1
document, support = source.split(marker)
assert document.endswith(' }\n') and support.endswith(' }\n}\n')
document += '}\n'
support = 'package {\n public final class HoldWorld {\n' + support
prior_helper = (OLD/'components/SandyTravelHoldBridge.as').read_bytes()
actual = ROOT.parent/'Sandevistan/build/out/a-travel-hold-20261022-003/frozen/src/SandyTravelHoldBridge.as'
helper = actual.read_bytes()
assert prior_helper.count(b' // ASC definite-return compatibility; unreachable.') == 2
assert prior_helper.replace(b' // ASC definite-return compatibility; unreachable.', b'') == helper
(HERE/'components').mkdir()
(HERE/'components/SandyTravelHoldChecks.as').write_text(document, encoding='utf-8', newline='\n')
(HERE/'components/HoldWorld.as').write_text(support, encoding='utf-8', newline='\n')
(HERE/'components/SandyTravelHoldBridge.as').write_bytes(helper)
assert (document[:-2] + marker + support.split(' public final class HoldWorld {\n', 1)[1]) == source
inputs = {str(p): prior.sha(p) for p in [OLD/'handoff.json', OLD/'prepare.py', OLD/'static-checks.json',
          OLD/'components/SandyTravelHoldChecks.as', OLD/'components/SandyTravelHoldBridge.as', actual, Path(__file__)]}
manifest = dict(expected=76, fixture_change='Split HoldWorld into its own source file; all original assertions preserved.',
                sources={p.name:prior.sha(p) for p in sorted((HERE/'components').glob('*.as'))}, inputs=inputs,
                original_compile_failure='build/m52/recovery-sandy-hold-component-01/compile.log',
                original_static_checks=prior.verify(), compiled=False, native_tested=False)
(HERE/'inputs.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(prepared=True, expected=76, exact_compiled_helper=True)))
