"""Small filesystem checks. No AIR, game assets or real saves are used."""
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from shared_music import MusicCache, digest_file, inside, signature

ROOT = Path(__file__).resolve().parents[2]


class MusicChecks(unittest.TestCase):
    def setUp(self):
        self.folder = Path(tempfile.mkdtemp(prefix='music-check-', dir=ROOT/'build')).resolve()
        self.build = self.folder/'build'
        self.build.mkdir()
        self.install = self.folder/'installed/Music/song.mp3'
        self.install.parent.mkdir(parents=True)
        self.install.write_bytes(b'unchanged music contents')
        self.cache = MusicCache(self.build)

    def tearDown(self):
        assert self.folder.parent == (ROOT/'build').resolve()
        assert self.folder.name.startswith('music-check-')
        shutil.rmtree(self.folder)

    def target(self, name):
        return self.build/name/'Music/song.mp3'

    def test_two_roles_share_data_but_not_installation(self):
        host, join = self.target('host'), self.target('join')
        self.cache.copy(self.install, host)
        self.cache.copy(self.install, join)
        self.assertTrue(os.path.samefile(host, join))
        self.assertFalse(os.path.samefile(host, self.install))
        self.install.write_bytes(b'new installed soundtrack')
        self.assertEqual(host.read_bytes(), b'unchanged music contents')

    def test_deleting_one_instance_leaves_others_playable(self):
        host, join = self.target('host'), self.target('join')
        self.cache.copy(self.install, host)
        self.cache.copy(self.install, join)
        host.unlink()
        self.assertEqual(join.read_bytes(), self.install.read_bytes())
        self.assertEqual(len(list(self.cache.root.glob('*.mp3'))), 1)

    def test_same_name_different_content_is_not_merged(self):
        a, b = self.target('a'), self.target('b')
        self.cache.copy(self.install, a)
        self.install.write_bytes(b'another track')
        self.cache.copy(self.install, b)
        self.assertFalse(os.path.samefile(a, b))
        self.assertNotEqual(a.read_bytes(), b.read_bytes())

    def test_configs_are_independent(self):
        source = self.folder/'config.txt'
        source.write_text('old')
        target = self.build/'config.txt'
        self.cache.copy(source, target)
        target.write_text('new')
        self.assertEqual(source.read_text(), 'old')

    def test_atomic_replacement_preserves_path_and_hash(self):
        target = self.target('old')
        target.parent.mkdir(parents=True)
        shutil.copy2(self.install, target)
        sig, expected = signature(target), digest_file(target)
        result = self.cache.replace_duplicate(target, expected, sig)
        self.assertTrue(result['changed'])
        self.assertEqual(result['freed_file_bytes'], len(self.install.read_bytes()))
        self.assertEqual(digest_file(target), expected)
        again = self.cache.replace_duplicate(target, expected, signature(target))
        self.assertFalse(again['changed'])

    def test_changed_target_is_retained(self):
        target = self.target('old')
        target.parent.mkdir(parents=True)
        shutil.copy2(self.install, target)
        sig, expected = signature(target), digest_file(target)
        target.write_bytes(b'edited after plan')
        with self.assertRaises(ValueError):
            self.cache.replace_duplicate(target, expected, sig)
        self.assertEqual(target.read_bytes(), b'edited after plan')

    def test_corrupt_pool_is_not_silently_trusted(self):
        blob = self.cache.blob(self.install)
        blob.write_bytes(b'corrupt')
        with self.assertRaises(ValueError):
            self.cache.copy(self.install, self.target('host'))
        self.assertFalse(self.target('host').exists())

    def test_failed_link_keeps_existing_original(self):
        target = self.target('old')
        target.parent.mkdir(parents=True)
        shutil.copy2(self.install, target)
        self.cache.blob(self.install)
        before = signature(target)
        with patch('shared_music.os.link', side_effect=PermissionError('locked')):
            with self.assertRaises(PermissionError):
                self.cache.replace_duplicate(target, digest_file(target), before)
        self.assertEqual(signature(target), before)
        self.assertFalse(list(target.parent.glob('.music-link-*')))

    def test_new_copy_falls_back_without_losing_music(self):
        self.cache.blob(self.install)
        target = self.target('host')
        with patch('shared_music.os.link', side_effect=OSError('no hardlinks')):
            self.cache.copy(self.install, target)
        self.assertEqual(target.read_bytes(), self.install.read_bytes())
        self.assertEqual(self.cache.copied, 1)

    def test_targets_outside_build_and_non_music_are_rejected(self):
        with self.assertRaises(ValueError):
            self.cache.copy(self.install, self.folder/'outside.mp3')
        outside = self.folder/'outside.mp3'
        outside.write_bytes(b'unique')
        with self.assertRaises(ValueError):
            self.cache.replace_duplicate(outside, digest_file(outside), signature(outside))
        config = self.build/'config.txt'
        config.write_bytes(b'config')
        with self.assertRaises(ValueError):
            self.cache.replace_duplicate(config, digest_file(config), signature(config))
        self.assertEqual(outside.read_bytes(), b'unique')

    def test_symlink_target_is_rejected(self):
        target = self.target('symlink')
        target.parent.mkdir(parents=True)
        try:
            target.symlink_to(self.install)
        except OSError:
            self.skipTest('Symlink creation unavailable; no boundary bypass attempted')
        with self.assertRaises(ValueError):
            inside(target, self.build)

    def test_copytree_links_only_music(self):
        frozen = self.build/'frozen'
        self.cache.copy(self.install, frozen/'Music/song.mp3')
        (frozen/'config.txt').write_text('host')
        joined = self.build/'joined'
        shutil.copytree(frozen, joined, copy_function=self.cache.copy)
        self.assertTrue(os.path.samefile(frozen/'Music/song.mp3', joined/'Music/song.mp3'))
        self.assertFalse(os.path.samefile(frozen/'config.txt', joined/'config.txt'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
