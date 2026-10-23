"""Thin private runner: existing ACK config guard, one socket mode, namespace51."""
from pathlib import Path
import hashlib
import importlib.util
import sys

if sys.flags.optimize:
    raise RuntimeError('Private trial forbids -O')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = ROOT / 'experimental/recovery-ordinary-wall-ack-timing-native/private_runner.py'
OLD_SHA = 'ccf4941f217ca1b2054ba5cb0e2552a99e95b98da5bbdddcce0f37254cfea2fe'
PRODUCT = ROOT / 'build/m52/recovery-ordinary-socket-nodelay-02/RConnectMod.swf'
HOST = ROOT / 'build/m52/recovery-ordinary-socket-host-01/pfe.swf'
NS30 = 'http://ns.adobe.com/air/application/30.0'
NS51 = 'http://ns.adobe.com/air/application/51.0'


def adapted_runner(mode):
    assert mode in ('off', 'on')
    assert hashlib.sha256(OLD.read_bytes()).hexdigest() == OLD_SHA
    spec = importlib.util.spec_from_file_location('socket_original_ack_private_runner', OLD)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    runner, source = old.adapted_runner()
    assert source.count(NS30) == 1 and NS51 not in source
    source = source.replace(NS30, NS51, 1)

    def private_config(cfg, release, output, role):
        assert 'socketNoDelayTrial' not in cfg
        old.private_config(cfg, release, output, role)
        cfg['socketNoDelayTrial'] = mode

    scope = dict(runner.run_registered.__globals__, _ack_private_config=private_config)
    exec(compile(source, '<socket trial private namespace and config>', 'exec'), scope)
    runner.run_registered = scope['run_registered']
    return runner, source


def main():
    def arg(name):
        assert sys.argv.count(name) == 1
        return sys.argv[sys.argv.index(name) + 1]
    mode = arg('--socket-mode')
    assert mode in ('off', 'on')
    assert Path(arg('--candidate')).resolve() == PRODUCT.resolve()
    assert Path(arg('--game-candidate')).resolve() == HOST.resolve()
    assert arg('--seconds') == '600'
    for flag in ('--effects', '--all-mods', '--private-desktop', '--defer-visible',
                 '--wait-host-world', '--require-exclusive-air', '--keep-copies'):
        assert flag in sys.argv
    assert '--solo' not in sys.argv and '--visible-windows' not in sys.argv
    # The extra argument belongs to this wrapper. The original parser and
    # registration never receive an invented option.
    index = sys.argv.index('--socket-mode')
    del sys.argv[index:index + 2]
    runner, _ = adapted_runner(mode)
    runner.main()


if __name__ == '__main__':
    main()
