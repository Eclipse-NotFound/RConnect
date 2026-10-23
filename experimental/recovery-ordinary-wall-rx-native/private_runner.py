"""Frozen ACK private runner, with only its exact candidate path replaced."""
from pathlib import Path
import hashlib
import sys

if sys.flags.optimize:
    raise RuntimeError('Private diagnostic runner forbids -O')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/private_runner.py'
OLD_SHA = 'ccf4941f217ca1b2054ba5cb0e2552a99e95b98da5bbdddcce0f37254cfea2fe'


def prepared_source():
    assert hashlib.sha256(OLD.read_bytes()).hexdigest() == OLD_SHA
    source = OLD.read_text(encoding='utf-8')
    before = "PRODUCT = ROOT / 'build/m52/recovery-ordinary-wall-ack-timing-01/RConnectMod.swf'"
    after = "PRODUCT = ROOT / 'build/m52/recovery-ordinary-wall-rx-timing-01/RConnectMod.swf'"
    assert source.count(before) == 1 and after not in source
    return source.replace(before, after, 1)


def prepared_module():
    scope = dict(__name__='rx_exact_ack_private_adapter', __file__=str(Path(__file__).resolve()))
    exec(compile(prepared_source(), '<rx exact candidate path adaptation>', 'exec'), scope)
    return scope


def adapted_runner():
    return prepared_module()['adapted_runner']()


if __name__ == '__main__':
    prepared_module()['main']()
