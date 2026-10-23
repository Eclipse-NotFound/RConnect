"""Use the frozen rx private adapter with one candidate-path replacement."""
from pathlib import Path
import hashlib
import importlib.util
import sys

if sys.flags.optimize:
    raise RuntimeError('Private diagnostic runner forbids -O')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'experimental/recovery-ordinary-wall-rx-native/private_runner.py'
OLD_SHA = '94c3c51cbb42c0e1891303bf267978fb0cd8908efb451eee58697a6333418b29'


def prepared_source():
    assert hashlib.sha256(OLD.read_bytes()).hexdigest() == OLD_SHA
    spec = importlib.util.spec_from_file_location('pump_original_rx_private_adapter', OLD)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    source = old.prepared_source()
    before = "PRODUCT = ROOT / 'build/m52/recovery-ordinary-wall-rx-timing-01/RConnectMod.swf'"
    after = "PRODUCT = ROOT / 'build/m52/recovery-ordinary-receive-pump-01/RConnectMod.swf'"
    assert source.count(before) == 1 and after not in source
    return source.replace(before, after, 1)


def prepared_module():
    scope = dict(__name__='pump_exact_ack_private_adapter', __file__=str(Path(__file__).resolve()))
    exec(compile(prepared_source(), '<pump exact candidate path adaptation>', 'exec'), scope)
    return scope


def adapted_runner():
    return prepared_module()['adapted_runner']()


if __name__ == '__main__':
    prepared_module()['main']()
