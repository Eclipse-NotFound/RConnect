"""Detect a large exposed white mask in the driver's actual whole-scene PNG.

This checks the observed white-rectangle symptom, not whole-scene equality.
Text/sprite highlights cannot satisfy 32 consecutive pixels for 24 rows.
"""
import hashlib
from pathlib import Path
from PIL import Image, __version__ as pillow_version


def inspect(path):
    path = Path(path)
    with Image.open(path) as image:
        image = image.convert("RGBA")
        assert 0 < image.width * image.height <= 2_000_000
        pixels = image.load()
        streaks = [0] * image.width
        block = None
        for y in range(image.height):
            length = 0
            for x in range(image.width):
                r, g, b, a = pixels[x, y]
                length = length + 1 if r >= 248 and g >= 248 and b >= 248 and a >= 240 else 0
                streaks[x] = streaks[x] + 1 if length >= 32 else 0
                if streaks[x] >= 24:
                    block = [x - 31, y - 23, 32, 24]
                    break
            if block:
                break
        return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "size": [image.width, image.height], "white_block": block, "pillow": pillow_version,
                "criterion": "32x24 opaque contiguous pixels, each RGB channel >=248 and alpha >=240"}


if __name__ == "__main__":
    import json, sys
    results = [inspect(path) for path in sys.argv[1:]]
    print(json.dumps(results, indent=2))
    raise SystemExit(int(any(result["white_block"] is not None for result in results)))
