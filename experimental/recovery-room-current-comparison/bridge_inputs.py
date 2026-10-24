"""Optional first-raster host and the already built A-only Sandy lease.

No file is installed here. The ordinary comparison keeps its original inputs.
"""
from pathlib import Path
import hashlib, importlib.util, json

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
HOST_SHA = 'a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
SAND = GAME/'mods/Sandevistan/build/out/a-travel-hold-20261022-003'
SAND_SHA = '3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c'
SAND_ORIGINAL = 'cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942'

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def product(path):
    builder = ROOT/'experimental/recovery-room-first-raster-current/build.py'
    meta = load(builder, 'first_raster_product_verifier').verify(path)
    assert (path/'compile.json').is_file()
    assert meta['version'] == '0.2.24-roomload1'
    return meta, read(path/'compile.json'), builder

def verify(host, installed, use_sandy):
    if host is None:
        assert not use_sandy
        return None
    host = host.resolve()
    assert host.parent == ROOT/'build/m52'
    assert installed['pfe.swf'] == HOST_SHA
    builder = ROOT/'experimental/recovery-room-first-raster-host-current/build.py'
    receipt = load(builder, 'first_raster_host_verifier').verify(host)
    assert receipt['validated'] is True and receipt['base_sha256'] == HOST_SHA
    assert sha(host/'pfe.swf') == receipt['candidate_sha256']
    pins = {str(p):sha(p) for p in (Path(__file__), builder, host/'pfe.swf', host/'build.json')}
    result = dict(host=str(host/'pfe.swf'), host_sha256=sha(host/'pfe.swf'),
                  sandbox_only=True, sandy=None, pins=pins)
    if not use_sandy:
        return result
    assert installed['mods/Sandevistan/release/SandevistanMod.swf'] == SAND_ORIGINAL
    intent, built = read(SAND/'intent.json'), read(SAND/'receipt.json')
    assert intent['original_candidate'] == SAND_ORIGINAL and intent['b_interface_included'] is False
    assert built['compiled'] is True and built['inputs_unchanged'] is True and built['exit_code'] == 0
    assert Path(built['candidate']).resolve() == SAND/'SandevistanMod.swf'
    assert built['candidate_sha256'] == sha(SAND/'SandevistanMod.swf') == SAND_SHA
    for name, digest in intent['inputs'].items():
        assert sha(name) == digest, name
        pins[name] = digest
    for name, digest in intent['sources'].items():
        p = SAND/'frozen'/name
        assert sha(p) == digest, name
        pins[str(p)] = digest
    for p in (SAND/'intent.json', SAND/'receipt.json', SAND/'SandevistanMod.swf'):
        pins[str(p)] = sha(p)
    result.update(sandy=str(SAND/'SandevistanMod.swf'), sandy_sha256=SAND_SHA)
    return result
