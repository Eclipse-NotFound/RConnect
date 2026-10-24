"""Thin binding to the unchanged bounded compiler; only root runs main()."""
import importlib.util
from pathlib import Path
import sys
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify(output):
    """Require an actual successful isolated compilation, not preparation alone."""
    prepared = load('explorationnoop_verify_source', HERE / 'prepare.py')
    manifest = prepared.verify()
    out = Path(output).resolve()
    assert out.parent == prepared.ROOT / 'build/m52' and (out / 'compile.json').is_file()
    meta, receipt = [prepared.checked.data(out / name) for name in ('prepared.json', 'compile.json')]
    assert meta['base_sha256'] == manifest['base_sha256'] and meta['version'] == manifest['version']
    assert meta['overlay_manifest_sha256'] == prepared.sha(HERE / 'source-manifest.json')
    assert meta['recipe_sha256'] == prepared.sha(prepared.DELEGATE)
    assert meta['source'] == manifest['candidate_source'] == prepared.inventory(out / 'src')
    assert meta['inputs'] == prepared.checked.data(prepared.BASE / 'prepared.json')['inputs']
    assert meta['inputs'] == prepared.inventory(out / 'tools')
    assert all(receipt[k] is True for k in ('compiled', 'installation_unchanged', 'sources_unchanged'))
    assert receipt['air_started'] is False and receipt['installed'] is False
    assert len(receipt['commands']) == 2 and all(c['exit_code'] == 0 for c in receipt['commands'])
    assert meta['installation_before'] == receipt['installation_before'] == receipt['installation_after']
    assert receipt['installation_before']['mods/Rconnect/release/RConnectMod.swf'] == manifest['base_sha256']
    assert prepared.sha(out / 'RConnectMod.swf') == receipt['candidate_sha256']
    return receipt


def main():
    prepared = load('explorationnoop_source_prepare', HERE / 'prepare.py')
    prepared.verify()
    absent = object()
    prior, old_argv, old_path = sys.modules.get('prepare', absent), sys.argv[:], sys.path[:]
    try:
        sys.modules['prepare'] = prepared
        bounded = load('explorationnoop_original_bounded_compiler', prepared.DELEGATE)
        bounded.HERE = HERE
        assert bounded.BASE == prepared.BASE and bounded.ROOT == prepared.ROOT
        assert bounded.inventory is prepared.inventory and bounded.sha is prepared.sha
        bounded.main()
    finally:
        sys.argv, sys.path[:] = old_argv, old_path
        if prior is absent:
            sys.modules.pop('prepare', None)
        else:
            sys.modules['prepare'] = prior
        prepared.verify()


if __name__ == '__main__':
    main()
