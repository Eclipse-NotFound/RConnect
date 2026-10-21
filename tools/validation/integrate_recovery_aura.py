"""Integrate the reviewed single-file aura correction into the active source only."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = ROOT / 'experimental/recovery-integrated'
BASE = ROOT / 'build/m52/recovery-01/src'
OVERLAY = ROOT / 'experimental/recovery-aura-followup/src'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest_path = ACTIVE / 'integration.json'
    meta = json.loads(manifest_path.read_text(encoding='utf-8'))
    assert meta['version'] == '0.2.24-recovery1', 'This exact source integration is single use'
    for row in meta['source']:
        assert sha(ACTIVE / 'src' / row['path']) == row['sha256'], row['path']
    relative = 'rconnect/game/TelekinesisVisuals.as'
    original, dest, source = BASE / relative, ACTIVE / 'src' / relative, OVERLAY / relative
    assert dest.read_bytes() == original.read_bytes(), 'Merge production changes explicitly'
    assert sha(source) == '2a98e2d94bf6d0cfcf62f64e830845a3919a9cb461719b81ae5f152031be30b1'
    change = dict(path=relative, source_sha256=sha(source), ancestor_sha256=sha(original),
                  before_sha256=sha(dest), merge='reviewed single-file delta')
    dest.write_bytes(source.read_bytes())
    change['merged_sha256'] = sha(dest)
    version_file = ACTIVE / 'src/RConnectMod.as'
    text = version_file.read_text(encoding='utf-8')
    assert text.count('0.2.24-recovery1') == 1
    version_file.write_text(text.replace('0.2.24-recovery1', '0.2.24-recovery2'), encoding='utf-8', newline='\n')
    meta['layers'].append(dict(name='aura-rgb-alpha-ownership', source=str(OVERLAY.relative_to(ROOT)),
                               ancestor='build/m52/recovery-01/src', files=[change]))
    for row in meta['source']:
        row['sha256'] = sha(ACTIVE / 'src' / row['path'])
        row['changed'] = row['sha256'] != row['baseline_sha256']
    meta.update(version='0.2.24-recovery2', compiled=False, runtime_tested=False)
    meta['followup_review'] = 'Only independent RGB/alpha ownership restoration and version; no motion, room or network changes'
    meta['static_checks']['version'] = True
    manifest_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(dict(version=meta['version'], file=relative, sha256=sha(dest))))


if __name__ == '__main__':
    main()
