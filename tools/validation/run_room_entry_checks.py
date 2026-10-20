"""Compile and run actual RoomSync against a small native-world/display fixture.

No game assets or user storage loaded. Production classes are copied unchanged;
the fixture substitutes only native world/session I/O. Not a native game pass.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from runtime_memory import snapshot, wait_owned

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--registry-wait',type=float,default=0)
    args = parser.parse_args()
    out, source = [(ROOT/p).resolve() for p in (args.output, args.source)]
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert source.is_relative_to(ROOT)
    out.mkdir()
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 房间交接组件',purpose='真实RoomSync与显示树组件断言',
                      run_dir=out,evidence=out/'receipt.json',resource='game' if args.run else 'offline',wait=args.registry_wait) as record:
        run_component(args,out,source,record)

def run_component(args,out,source,record):
    src = out/'src'
    shutil.copytree(ROOT/'tests/room-entry', src)
    files = ['rconnect/core/RoomSync.as', 'rconnect/net/RoomCodec.as', 'rconnect/net/Protocol.as', 'rconnect/net/BinaryMessageCodec.as']
    if (source/'rconnect/game/NativeTileState.as').is_file():
        files += ['rconnect/game/NativeTileState.as','rconnect/game/NativeRoomState.as']
    fallback = ROOT/'build/m52/coop-bundle-04/src'
    if (source/'rconnect/ui/RoomEntryView.as').is_file() or (fallback/'rconnect/ui/RoomEntryView.as').is_file():
        files.append('rconnect/ui/RoomEntryView.as')
    originals = {}
    for n in files:
        p = source/n
        if not p.exists():
            # The production override tree is deliberately sparse.
            p = fallback/n
        dest = src/n
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, dest)
        originals[n] = dict(path=str(p), sha256=sha(p))
    intent = dict(kind='room-entry-component', production=originals,
                  files={p.relative_to(src).as_posix():sha(p) for p in src.rglob('*.as')},
                  script_sha256=sha(Path(__file__)), installed=False, native_game_test=False)
    (out/'inputs.json').write_text(json.dumps(intent, indent=2), encoding='utf-8')
    cmd = [str(JAVA), '-Xmx256m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
           '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=true',
           '-source-path='+str(src), '-output='+str(out/'RoomEntryChecks.swf'), str(src/'RoomEntryChecks.as')]
    with (out/'compile.log').open('w', encoding='utf-8') as log:
        code = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, AIR_HOME=str(SDK))).returncode
    if code:
        print((out/'compile.log').read_text(encoding='utf-8', errors='replace')[-7000:])
        raise SystemExit(code)
    print('Compiled component fixture', flush=True)
    if not args.run:
        return
    memory = snapshot()
    (out/'memory-before.json').write_text(json.dumps(memory), encoding='utf-8')
    # Small display-only component, not the multi-GiB native dual-game harness.
    assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB for tiny AIR component; not started'
    appid = 'rconnect-room-entry-'+uuid.uuid4().hex
    descriptor = out/'application.xml'
    descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+
        '</id><versionNumber>1.0</versionNumber><filename>RoomEntryChecks</filename><initialWindow>'+
        '<content>RoomEntryChecks.swf</content><visible>false</visible><width>640</width><height>400</height>'+
        '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
    before = sha(GAME/'pfe.swf'), sha(ROOT/'release/RConnectMod.swf')
    with (out/'stdout.log').open('w', encoding='utf-8') as log:
        sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
        from air_test_process import HiddenProcess
        record.before_launch('component / '+appid+' / '+str(descriptor))
        process = HiddenProcess([str(GAME/'adl64.exe'), '-runtime', str(GAME/'runtimes/air/win64'), str(descriptor)],
            cwd=out, stdout=log, stderr=log)
        record.child(process.pid)
        (out/'process.json').write_text(json.dumps(dict(pid=process.pid, app_id=appid)), encoding='utf-8')
        try:
            code = wait_owned(process, 40, out/'memory-timeline.json')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.close()
            record.child_stopped()
    result_file = Path(os.environ['APPDATA'])/appid/'Local Store/result.json'
    result = {}
    if result_file.is_file():
        shutil.copyfile(result_file, out/'result.json')
        result = json.loads(result_file.read_text(encoding='utf-8'))
    unchanged = before == (sha(GAME/'pfe.swf'), sha(ROOT/'release/RConnectMod.swf'))
    receipt = dict(exit=code, assertions=len(result.get('assertions', [])), failed=result.get('failed'),
                   installation_unchanged=unchanged, native_game_test=False,
                   production_unchanged=all(sha(Path(v['path']))==v['sha256'] for v in originals.values()))
    (out/'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt))
    for row in result.get('assertions', []):
        if not row['passed']:
            print('FAIL '+row['label'])
    if code or not unchanged or not result.get('passed'):raise SystemExit(code or 1)
    record.outcome='passed';record.note='RoomSync组件断言通过；不是完整原生游戏验收'


if __name__ == '__main__':
    main()
