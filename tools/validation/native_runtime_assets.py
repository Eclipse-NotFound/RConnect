"""Enumerate the native assets needed by an unmodified 1.02 game copy."""
import hashlib
from pathlib import Path

RUNTIME_SWFS = ('pfe.swf','sound.swf','sound_unit.swf','sound_weapon.swf',
                'sprite.swf','sprite1.swf','texture.swf','texture1.swf')


def native_runtime_files(game):
    game=Path(game)
    for name in RUNTIME_SWFS:
        assert (game/name).is_file(), 'Missing native runtime file: '+name
    files={p for p in game.iterdir() if p.is_file() and
           (p.suffix.lower() in ('.xml','.cfg') or p.name in RUNTIME_SWFS)}
    for name in ('Rooms','Music'):
        directory=game/name
        assert directory.is_dir(), 'Missing native runtime directory: '+name
        children={p for p in directory.rglob('*') if p.is_file()}
        assert children, 'Empty native runtime directory: '+name
        files.update(children)
    return sorted(files)


def asset_hashes(game,relative_names=None):
    game=Path(game)
    names=relative_names if relative_names is not None else [p.relative_to(game).as_posix() for p in native_runtime_files(game)]
    return {name:hashlib.sha256((game/name).read_bytes()).hexdigest() for name in names}
