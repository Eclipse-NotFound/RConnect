"""Check the release ZIP and simulate a merge in an owned, isolated folder."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = ROOT / 'build/a-tcp-01'
ARCHIVE = ARTIFACT / 'RConnect_v0.2.24-tcp1.zip'
DEST = ROOT / 'build/a-tcp-package-check-01'
EXPECTED = '690604878bd8707007a99e3ad14f8f5f3f55cdd4948c8debe6cc87363afd38c9'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    assert DEST.resolve().is_relative_to((ROOT / 'build').resolve())
    assert not DEST.exists(), 'Preserve previous check results'
    with zipfile.ZipFile(ARCHIVE) as z:
        assert z.testzip() is None
        names = z.namelist()
        assert len(names) == len(set(names)), 'Duplicate archive entries'
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts
            assert '\\' not in name and ':' not in name
            assert name in ('INSTALL.txt', '先读我-安装说明.txt', 'SHA256.json') or name.startswith('mods/RConnect/')
            assert path.name != 'config.txt'
        checks = json.loads(z.read('SHA256.json'))
        assert set(checks) == set(names) - {'SHA256.json'}
        for name, digest in checks.items():
            assert sha(z.read(name)) == digest, name
        product = z.read('mods/RConnect/release/RConnectMod.swf')
        assert sha(product) == EXPECTED
        assert product == (ARTIFACT / 'RConnectMod.swf').read_bytes()
        assert product == (ROOT / 'release/RConnectMod.swf').read_bytes()
        assert [n for n in names if n.lower().endswith('.swf')] == ['mods/RConnect/release/RConnectMod.swf']
        assert not any(n.lower().endswith(('.as', '.log', '.sol', '.exe')) for n in names)
        assert z.read('INSTALL.txt') == z.read('先读我-安装说明.txt')
        build = json.loads(z.read('mods/RConnect/BUILD.json'))
        assert build['version'] == '0.2.24-tcp1' and build['swf_sha256'] == EXPECTED
        for dependency in ('Start-Coop.bat', 'tools/start_coop.ps1', 'tools/RConnect.Process.ps1',
                           'tools/RConnect.Profile.ps1', 'tools/keep_test_responsive.ps1',
                           'tools/second_player_descriptor.xml'):
            assert 'mods/RConnect/' + dependency in names, dependency
        for guide in ('tcp-tunnel.zh-CN.md', 'tcp-tunnel.md', 'local-coop.md',
                      'release-0.2.24-tcp1.md', 'release-0.2.24.md', 'BUILD-A.md'):
            assert 'mods/RConnect/docs/' + guide in names, guide

        # A merge must preserve existing settings, saves and the game itself.
        sentinels = {'mods/RConnect/release/config.txt': b'personal config sentinel',
                     'pfe.swf': b'game sentinel', 'saves/player.sol': b'save sentinel',
                     'mods/OtherMod/release/config.txt': b'other mod sentinel'}
        DEST.mkdir()
        for name, data in sentinels.items():
            p = DEST / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
        z.extractall(DEST)
        for name, data in sentinels.items():
            assert (DEST / name).read_bytes() == data, name
        assert (DEST / 'mods/RConnect/release/RConnectMod.swf').read_bytes() == product
        assert not (DEST / 'mods/mods').exists()

    report = dict(passed=True, archive=ARCHIVE.name, zip_sha256=sha(ARCHIVE.read_bytes()),
                  swf_sha256=EXPECTED, entries=len(names), unpacked_bytes=sum(i.file_size for i in z.infolist()),
                  preserved_sentinels=list(sentinels), source_files=len(build['source']),
                  external_declarations=len(build['stubs']),
                  scope='Archive integrity and isolated folder merge; no game launched or real installation modified')
    (ARTIFACT / 'package-install-check.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
