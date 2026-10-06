"""Bind each new core snapshot to its immutable installation baseline."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
LEGACY = 'build/m46/integration-baseline'
AFTER_UI = 'build/m46/integration-baseline-after-ui-20261006'
UI_SHA = 'a5698f9f5941b27c2fd47de56366c4d867bf256b2dcb7d484596844dea093971'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def read_baseline(manifest):
    name = manifest.get('baseline_path', LEGACY)
    folder = (ROOT / name).resolve()
    assert folder.parent == ROOT / 'build/m46' and folder.name.startswith('integration-baseline'), name
    path = folder / 'inputs.json'
    if name != LEGACY:
        assert manifest['baseline_inputs_sha256'] == sha(path), 'baseline manifest changed'
        assert manifest['version'] == '0.2.18-dev', 'post-UI core requires a distinct version'
    baseline = read(path)
    if name == AFTER_UI:
        assert baseline['release_sha256'] == UI_SHA, 'wrong UI installation baseline'
    return baseline

def verify_protected(manifest, own_release=None):
    baseline = read_baseline(manifest)
    for name, digest in baseline['protected'].items():
        if own_release is not None and name.lower() == 'mods/rconnect/release/rconnectmod.swf':
            digest = own_release
        assert sha(GAME / name) == digest, name
    return baseline
