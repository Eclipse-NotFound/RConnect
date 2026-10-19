"""Share immutable test MP3s; installed files are only ever read/copied.

Never edit a linked MP3 in place. Replace its directory entry to change a test
asset. Configurations, SWFs, saves and evidence remain independent files.
"""
import hashlib
import os
from pathlib import Path
import shutil
import uuid


def signature(path):
    s = Path(path).stat()
    return (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns)


def digest_file(path):
    before = signature(path)
    with Path(path).open('rb') as stream:
        value = hashlib.file_digest(stream, 'sha256').hexdigest()
    if signature(path) != before:
        raise ValueError('Music changed while hashing: ' + str(path))
    return value


def inside(path, root):
    """Validate the absolute target before creating/replacing any file."""
    root = Path(root).absolute()
    path = Path(path).absolute()
    if root.resolve() != root or not path.is_relative_to(root):
        raise ValueError('Target is outside the test build root: ' + str(path))
    current = root
    for part in path.relative_to(root).parts:
        current /= part
        if current.is_symlink() or current.is_junction():
            raise ValueError('Linked directory/file is not an allowed target: ' + str(current))
    if not path.resolve().is_relative_to(root):
        raise ValueError('Resolved target escapes the test build root')
    return path


def is_music(path):
    path = Path(path)
    return path.suffix.lower() == '.mp3' and path.parent.name.lower() == 'music'


class MusicCache:
    def __init__(self, build):
        self.build = Path(build).absolute()
        self.root = inside(self.build / 'shared-assets/music-v1', self.build)
        self.created_bytes = 0
        self.linked = 0
        self.copied = 0

    def blob(self, source, expected=None):
        source = Path(source)
        value = digest_file(source)
        if expected is not None and value != expected:
            raise ValueError('Source differs from the recorded music hash: ' + str(source))
        self.root.mkdir(parents=True, exist_ok=True)
        target = inside(self.root / (value + '.mp3'), self.build)
        if target.exists():
            if digest_file(target) != value:
                raise ValueError('Corrupt music cache; retained without overwrite: ' + str(target))
            return target
        temporary = inside(self.root / ('.copy-' + uuid.uuid4().hex), self.build)
        try:
            # A real copy makes the pool independent of installation/B baselines.
            shutil.copyfile(source, temporary)
            if digest_file(temporary) != value or digest_file(source) != value:
                raise ValueError('Music changed while making the independent cache')
            try:
                os.link(temporary, target)  # publish without replacing an existing blob
                self.created_bytes += temporary.stat().st_size
            except FileExistsError:
                if digest_file(target) != value:
                    raise ValueError('Concurrent music cache entry has incorrect bytes')
        finally:
            if temporary.exists():
                temporary.unlink()
        return target

    def copy(self, source, destination):
        """shutil.copytree copy_function; only MP3s share storage."""
        source = Path(source)
        destination = inside(destination, self.build)
        if not is_music(source):
            return shutil.copy2(source, destination)
        if destination.exists():
            raise FileExistsError(destination)
        blob = self.blob(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            os.link(blob, destination)
            self.linked += 1
        except FileExistsError:
            raise
        except OSError:
            # A different filesystem or unavailable hardlinks must preserve music.
            shutil.copy2(blob, destination)
            if digest_file(destination) != blob.stem:
                raise ValueError('Fallback music copy failed verification')
            self.copied += 1
        return str(destination)

    def replace_duplicate(self, target, expected, recorded_signature):
        target = inside(target, self.build)
        if not is_music(target):
            raise ValueError('Only an existing Music/*.mp3 can be deduplicated')
        if tuple(recorded_signature) != signature(target) or digest_file(target) != expected:
            raise ValueError('Stale music plan; original retained: ' + str(target))
        blob = self.blob(target, expected)
        if os.path.samefile(target, blob):
            return dict(changed=False, freed_file_bytes=0)
        before = target.stat()
        temporary = inside(target.with_name('.music-link-' + uuid.uuid4().hex), self.build)
        try:
            os.link(blob, temporary)
            if signature(target) != tuple(recorded_signature) or digest_file(temporary) != expected:
                raise ValueError('Music changed before replacement; original retained')
            os.replace(temporary, target)  # same directory, no missing-path interval
            if digest_file(target) != expected or not os.path.samefile(target, blob):
                raise ValueError('Replacement verification failed')
        finally:
            if temporary.exists():
                temporary.unlink()
        return dict(changed=True, freed_file_bytes=before.st_size if before.st_nlink == 1 else 0)
