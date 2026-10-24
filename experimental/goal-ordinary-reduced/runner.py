"""Expose the existing official-selector runner to the ordinary wrapper hooks."""
from pathlib import Path
import hashlib, importlib.util, shutil, sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
BASE = HERE.parent/'recovery-room-reduced-runtime/launcher.py'
BASE_SHA = 'a5d3a120216c7573a4c26c6c923b821b53dbfeb9608ca3a4d5a93f017ab72601'
OLD = '    runner.run_registered = registered\n    runner.main()\n'
NEW = '    bind_registered(registered)\n    runner.run_registered = invoke_registered\n    runner.main()\n'
_registered = None


def load():
    assert hashlib.sha256(BASE.read_bytes()).hexdigest() == BASE_SHA
    source = BASE.read_text(encoding='utf-8')
    assert source.count(OLD) == 1
    adapted = source.replace(OLD, NEW)
    assert adapted.replace(NEW, OLD) == source
    spec = importlib.util.spec_from_loader('ordinary_reduced_existing_selector', loader=None)
    module = importlib.util.module_from_spec(spec)
    module.__file__ = str(BASE)
    exec(compile(adapted, str(BASE), 'exec'), module.__dict__)
    return module


def run_registered(*args, **kwargs):
    assert _registered is not None
    return _registered(*args, **kwargs)


def main():
    global _registered
    module = load()
    def bind(fn):
        global _registered
        assert _registered is None
        _registered = fn
    module.bind_registered = bind
    module.invoke_registered = lambda *args, **kwargs: run_registered(*args, **kwargs)
    try:
        return module.main()
    finally:
        _registered = None


if __name__ == '__main__':
    main()
