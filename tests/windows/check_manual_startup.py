"""Compare legacy/manual AIR identities without touching either player profile.

All game and mod inputs are frozen once. There is no gameplay driver: a fresh
world appearing before user input is the failure being measured.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--legacy', action='store_true', help='Reproduce the old identity policy (expected failure)')
    ap.add_argument('--chooser-driver', type=Path, help='Directory produced by build_manual_startup_test.py')
    ap.add_argument('--save-template', type=Path, help='Read-only native slot-one template for chooser validation')
    args = ap.parse_args()
    token = uuid.uuid4().hex[:10]
    output = ROOT / 'build' / 'launcher' / token
    frozen = output / 'game'
    frozen.mkdir(parents=True)
    assets = {'pfe.swf', 'sound.swf', 'sound_unit.swf', 'sound_weapon.swf',
              'sprite.swf', 'sprite1.swf', 'texture.swf', 'texture1.swf'}
    for src in GAME.iterdir():
        if src.is_file() and (src.name in assets or src.suffix in ('.xml', '.cfg')):
            shutil.copy2(src, frozen / src.name)
    shutil.copytree(GAME / 'Rooms', frozen / 'Rooms')
    manifest = (GAME / 'mods/loader-manifest.txt').read_text(encoding='utf-8-sig')
    for line in manifest.splitlines():
        if line.startswith('#') or '|' not in line:
            continue
        name, entry = line.split('|')[:2]
        dst = frozen / 'mods' / name / 'release'
        dst.mkdir(parents=True, exist_ok=True)
        for filename in (entry + '.swf', 'config.txt'):
            src = GAME / 'mods' / name / 'release' / filename
            if src.exists():
                shutil.copy2(src, dst / filename)
    (frozen / 'mods/loader-manifest.txt').write_text(manifest, encoding='utf-8')
    if args.chooser_driver:
        if args.legacy or not args.save_template:
            ap.error('Chooser validation needs a native slot-one template and the manual identity')
        testdir = frozen / 'tests'
        testdir.mkdir()
        shutil.copy2(args.chooser_driver / 'RConnectMod.swf', testdir / 'RConnectProduction.swf')
        shutil.copy2(args.chooser_driver / 'EffectsDriver.swf', testdir / 'EffectsDriver.swf')
        shutil.copy2(args.chooser_driver / 'EffectsHarness.swf', frozen / 'mods/Rconnect/release/RConnectMod.swf')
    inputs = {str(p.relative_to(frozen)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in frozen.rglob('*') if p.is_file()}
    appid = ('pfe-rconnect-launcher-' if args.legacy else 'pfe-modsettings-rconnect-launcher-') + token
    storage = Path(os.environ['APPDATA']) / appid / 'Local Store'
    assert not storage.exists(), 'Only fresh isolated profiles are allowed'
    template_hash = None
    if args.save_template:
        data = args.save_template.read_bytes()
        assert data[:2] == b'\x00\xbf' and data[6:10] == b'TCSO' and data[16:26] == b'\x00\x08PFEgame1', 'Need a native slot-one SOL'
        template_hash = hashlib.sha256(data).hexdigest()
        save = storage / '#SharedObjects/pfe.swf/PFEgame1.sol'
        save.parent.mkdir(parents=True)
        save.write_bytes(data)
    desc = output / 'application.xml'
    desc.write_text('''<application xmlns="http://ns.adobe.com/air/application/30.0">
<id>''' + appid + '''</id><versionNumber>1.0</versionNumber><filename>RConnectStartupTest</filename>
<initialWindow><content>pfe.swf</content><visible>false</visible><renderMode>direct</renderMode></initialWindow>
</application>''', encoding='utf-8')
    proc = None
    try:
        with (output / 'stdout.log').open('w', encoding='utf-8') as stdout:
            proc = subprocess.Popen([str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'),
                                     str(desc), str(frozen)], cwd=frozen, stdout=stdout,
                                    stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            print('START ' + appid + ' pid=' + str(proc.pid), flush=True)
            deadline = time.monotonic() + 55
            log = ''
            while time.monotonic() < deadline and proc.poll() is None:
                path = storage / 'RConnect.log'
                log = path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''
                driverlog = storage / 'RConnectLauncherTest.log'
                if args.chooser_driver and driverlog.exists() and ('DONE' in driverlog.read_text() or 'FAIL' in driverlog.read_text()):
                    break
                if not args.chooser_driver and 'tick 400 ' in log:
                    break
                time.sleep(1)
            heartbeats = [s for s in log.splitlines() if 'RConnectDbg: tick' in s]
            passed = (len(heartbeats) >= 2 and all('world=null' in s and 'mm.active=true' in s
                                                 and 'verror=false' in s for s in heartbeats))
            if args.chooser_driver:
                detail = driverlog.read_text() if driverlog.exists() else ''
                passed = 'DONE' in detail and 'FAIL' not in detail and template_hash == hashlib.sha256(args.save_template.read_bytes()).hexdigest()
                print(detail, flush=True)
            result = dict(passed=passed, appid=appid, pid=proc.pid, inputs=inputs,
                          initialized=[s for s in log.splitlines() if ' initialized' in s], heartbeats=heartbeats, template_sha256=template_hash)
            (output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
            print(('PASS' if passed else 'FAIL') + (' native chooser and selected save' if args.chooser_driver else ' menu preserved before user input'), flush=True)
            for line in heartbeats:
                print(line, flush=True)
    finally:
        if proc is not None and proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=15)
        for name in ('RConnect.log', 'tdfc.log', 'RConnectLauncherTest.log'):
            if (storage / name).exists():
                shutil.copy2(storage / name, output / name)
    print('REPORT ' + str(output), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
