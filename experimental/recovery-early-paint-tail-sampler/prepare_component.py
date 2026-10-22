"""Prepare exact flat AS3 component inputs only. No compiler, AIR, or runner changes."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
FILES = ('src/PaintTailSampler.as', 'src/FlashPaintTailSampler.as',
         'tests/PaintTailSamplerChecks.as', 'tests/PaintTailSamplerComponentDoc.as')


def main():
    target = HERE / 'component'
    assert target.resolve().parent == HERE.resolve()
    target.mkdir(exist_ok=True)
    hashes = {}
    for name in FILES:
        source = HERE / name
        destination = target / source.name
        content = source.read_bytes()
        destination.write_bytes(content)
        hashes[name] = hashlib.sha256(content).hexdigest()
        assert source.read_bytes() == destination.read_bytes()
    metadata = dict(kind='paint-tail-component-source', source_sha256=hashes,
                    entry='PaintTailSamplerComponentDoc.as', expected=31,
                    compiled=False, air_started=False, real_sampler_used=False,
                    performance_qualified=False)
    (HERE / 'component-inputs.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
