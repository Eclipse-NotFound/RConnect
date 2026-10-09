import shutil,tempfile,unittest
from pathlib import Path
from native_runtime_assets import RUNTIME_SWFS,native_runtime_files,asset_hashes


class NativeRuntimeAssetTest(unittest.TestCase):
    def make_temp(self):
        workspace=Path(__file__).resolve().parents[2]
        root=workspace/'build'/'validation-unit-temp'
        root.mkdir(parents=True,exist_ok=True)
        self.assertTrue(root.resolve().is_relative_to(workspace))
        temp=tempfile.TemporaryDirectory(dir=root)
        self.assertTrue(Path(temp.name).resolve().is_relative_to(root.resolve()))
        self.addCleanup(temp.cleanup)
        return Path(temp.name)

    def setUp(self):
        self.root=self.make_temp()
        for name in RUNTIME_SWFS+('application.xml','config.cfg','Rooms/a/room.xml','Music/mainmenu.mp3'):
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(name.encode())
        (self.root/'unrelated.log').write_bytes(b'not a runtime asset')
    def test_complete_relative_copy(self):
        target=self.make_temp()
        for source in native_runtime_files(self.root):
            dest=target/source.relative_to(self.root);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
        self.assertEqual(asset_hashes(self.root),asset_hashes(target))
        self.assertIn('Music/mainmenu.mp3',asset_hashes(target))
        self.assertIn('Rooms/a/room.xml',asset_hashes(target))
        self.assertNotIn('unrelated.log',asset_hashes(target))

    def test_missing_music_fails_before_launch(self):
        (self.root/'Music/mainmenu.mp3').unlink()
        with self.assertRaisesRegex(AssertionError,'Empty native runtime directory: Music'):native_runtime_files(self.root)


if __name__=='__main__':unittest.main()
