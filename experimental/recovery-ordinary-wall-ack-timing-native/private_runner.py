"""Exact shared runner with one private-copy config insertion; no other edits."""
from pathlib import Path
import hashlib
import importlib.util
import inspect
import re
import sys

if sys.flags.optimize:
    raise RuntimeError('Private diagnostic runner forbids -O')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNNER = ROOT / 'tools/run_coop_regression.py'
RUNNER_SHA = '7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3'
PRODUCT = ROOT / 'build/m52/recovery-ordinary-wall-ack-timing-01/RConnectMod.swf'
HOST = ROOT / 'build/m52/recovery-ordinary-mask-host-02/pfe.swf'


def private_config(cfg, release, output, role):
    output, release = Path(output).resolve(), Path(release).resolve()
    assert output.parent == (ROOT / 'build/cooperation').resolve()
    assert re.fullmatch(r'[0-9a-f]{10}', output.name) and role in ('host', 'join')
    assert release.is_relative_to(output), 'Private release resolved outside the owned run'
    assert release == (output / role / 'mods/Rconnect/release').resolve()
    assert 'wallAckTiming' not in cfg
    cfg['wallAckTiming'] = '1'


def adapted_runner():
    assert hashlib.sha256(RUNNER.read_bytes()).hexdigest() == RUNNER_SHA
    sys.path.insert(0, str(ROOT / 'tools'))
    spec = importlib.util.spec_from_file_location('ack_timing_original_coop_runner', RUNNER)
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    source = inspect.getsource(runner.run_registered)
    anchor = "            (release/'config.txt').write_text(json.dumps(cfg),encoding='utf-8')"
    assert source.count(anchor) == 1
    source = source.replace(anchor,
        '            _ack_private_config(cfg,release,output,role)\n' + anchor, 1)
    scope = dict(runner.__dict__, _ack_private_config=private_config)
    exec(compile(source, '<ack-timing private config single insertion>', 'exec'), scope)
    runner.run_registered = scope['run_registered']
    return runner, source


def main():
    # Constrain this private entry to the exact diagnostic job, then preserve
    # the shared main's parser, registration, failures and owned-process cleanup.
    def arg(name):
        assert sys.argv.count(name) == 1
        return sys.argv[sys.argv.index(name) + 1]
    assert Path(arg('--candidate')).resolve() == PRODUCT.resolve()
    assert Path(arg('--game-candidate')).resolve() == HOST.resolve()
    assert arg('--seconds') == '600'
    for flag in ('--effects', '--all-mods', '--private-desktop', '--defer-visible',
                 '--wait-host-world', '--require-exclusive-air', '--keep-copies'):
        assert flag in sys.argv
    assert '--solo' not in sys.argv and '--visible-windows' not in sys.argv
    runner, _ = adapted_runner()
    runner.main()


if __name__ == '__main__':
    main()
