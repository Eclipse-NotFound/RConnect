"""Freeze the owner's validated FA build for RConnect compatibility testing.

Read-only outside this mod. Does not rebuild, install, or alter old evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FA = ROOT.parent / 'FirearmAttachments'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and not out.exists()
    proof_data = (FA / 'build/out/validated.json').read_bytes()
    proof = json.loads(proof_data)
    candidate = (FA / 'build/out/FirearmAttachmentsMod.swf').read_bytes()
    assert sha(candidate) == proof['candidate_sha256']
    assert proof['version'] == '0.3.2' and proof['checks'] >= 390
    files = {}
    for directory in ('src', 'data', 'tests'):
        for path in (FA / directory).rglob('*'):
            if path.is_file():
                files[path.relative_to(FA).as_posix()] = path.read_bytes()
    source = {name: sha(data) for name, data in files.items()}
    files.update({'FirearmAttachmentsMod.swf': candidate, 'validated.json': proof_data})
    out.mkdir()
    for name, data in files.items():
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('xb') as stream:
            stream.write(data)
        assert sha(path.read_bytes()) == sha(data)
    for name, digest in source.items():
        assert sha((FA / name).read_bytes()) == digest
    assert (FA / 'build/out/validated.json').read_bytes() == proof_data
    assert (FA / 'build/out/FirearmAttachmentsMod.swf').read_bytes() == candidate
    receipt = dict(kind='validated-fa-compatibility-snapshot', installed=False,
                   version=proof['version'], candidate_sha256=sha(candidate), source=source,
                   validation_sha256=sha(proof_data), validation_appid=proof['appid'])
    (out / 'prepared.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({key:receipt[key] for key in ('version','candidate_sha256','validation_appid')}))

if __name__ == '__main__':
    main()
