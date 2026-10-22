"""Use the unchanged recovery prepare recipe, omitting optional components only."""
import hashlib
import importlib.util
from pathlib import Path


ORIGIN = Path(__file__).resolve().parent.parent / 'recovery-tests/prepare.py'
ORIGIN_SHA256 = '57adca102a8ecbb0c1996dcee405782eced622fea63917d27238d27e81539ac3'


def verify_origin():
    if hashlib.sha256(ORIGIN.read_bytes()).hexdigest() != ORIGIN_SHA256:
        raise RuntimeError('Original recovery prepare recipe changed; review this adapter again')


def main():
    verify_origin()
    spec = importlib.util.spec_from_file_location('recovery_original_prepare', ORIGIN)
    recipe = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(recipe)
    recipe.COMPONENTS = {}
    try:
        return recipe.main()
    finally:
        verify_origin()


if __name__ == '__main__':
    main()
