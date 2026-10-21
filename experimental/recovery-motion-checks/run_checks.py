"""Freeze real capture/codec/receiver classes with explicit native substitutes.

Nothing runs unless this script is invoked. --run adds the isolated AIR component;
neither option starts the native game or a TCP pair.
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

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT / 'tools/validation'))
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK
from runtime_memory import snapshot, wait_owned


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--run', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=300)
    args = ap.parse_args()
    source = (ROOT / args.source).resolve()
    out = (ROOT / args.output).resolve()
    assert source.is_relative_to(ROOT) and source.is_dir()
    assert out.parent == ROOT / 'build/m52' and not out.exists()
    out.mkdir()
    src = out / 'src'
    shutil.copytree(HERE / 'tests', src)
    originals = {}
    names = ['rconnect/game/UnitPresentation.as', 'rconnect/game/ProjectileVisuals.as',
             'rconnect/game/ProjectileFrameStream.as', 'rconnect/game/RemoteMotion.as',
             'rconnect/net/BinaryMessageCodec.as']
    if (source / 'rconnect/game/ImpactEventQueue.as').is_file():
        names.append('rconnect/game/ImpactEventQueue.as')
    for name in names:
        original = source / name
        if not original.is_file():
            original = ROOT / 'build/m52/coop-bundle-04/src' / name
        assert original.is_file(), original
        target = src / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
        originals[name] = dict(path=str(original), sha256=sha(original))
    save(out / 'inputs.json', dict(production=originals, recipe=sha(__file__),
        fixture={p.relative_to(src).as_posix(): sha(p) for p in src.rglob('*.as')},
        native_game=False, tcp_socket=False, real_capture=True, real_codec=True,
        real_receiver=True, adjacent_impacts_are_fixtures=True))
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect recovery / capture component',
                      purpose='真实采集、增量、序列化和接收组件；不算原生或 TCP 实测',
                      run_dir=out, evidence=out / 'receipt.json', wait=args.registry_wait) as registration:
        command = [str(JAVA), '-Xmx256m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
            '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=true',
            '-source-path=' + str(src), '-output=' + str(out / 'CaptureEffectsChecks.swf'),
            str(src / 'CaptureEffectsChecks.as')]
        with (out / 'compile.log').open('w', encoding='utf-8') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True,
                           env=dict(os.environ, AIR_HOME=str(SDK)))
        if not args.run:
            registration.outcome = 'passed'
            registration.note = '仅编译，无组件运行'
            print(json.dumps(dict(output=str(out), compiled=True, ran=False)))
            return
        memory = snapshot()
        save(out / 'memory-before.json', memory)
        assert memory['free_commit_bytes'] >= 1024 ** 3, 'Less than 1 GiB; AIR component not started'
        appid = 'rconnect-recovery-capture-' + uuid.uuid4().hex
        descriptor = out / 'application.xml'
        descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid +
            '</id><versionNumber>1.0</versionNumber><filename>CaptureEffectsChecks</filename><initialWindow>' +
            '<content>CaptureEffectsChecks.swf</content><visible>false</visible><width>640</width><height>400</height>' +
            '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
        before = sha(GAME / 'pfe.swf'), sha(ROOT / 'release/RConnectMod.swf')
        from air_test_process import HiddenProcess
        with (out / 'stdout.log').open('w', encoding='utf-8') as log:
            registration.before_launch(appid + ' / ' + str(descriptor))
            process = HiddenProcess([str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)],
                                    cwd=out, stdout=log, stderr=log)
            registration.child(process.pid)
            save(out / 'process.json', dict(pid=process.pid, app_id=appid))
            try:
                code = wait_owned(process, 40, out / 'memory-timeline.json')
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                process.close()
                registration.child_stopped()
        result_file = Path(os.environ['APPDATA']) / appid / 'Local Store/result.json'
        result = {}
        if result_file.is_file():
            shutil.copyfile(result_file, out / 'result.json')
            result = json.loads(result_file.read_text(encoding='utf-8'))
        unchanged = before == (sha(GAME / 'pfe.swf'), sha(ROOT / 'release/RConnectMod.swf'))
        source_unchanged = all(sha(v['path']) == v['sha256'] for v in originals.values())
        receipt = dict(exit=code, failed=result.get('failed'), assertions=len(result.get('assertions', [])),
            installation_unchanged=unchanged, production_unchanged=source_unchanged,
            native_game=False, tcp_socket=False)
        save(out / 'receipt.json', receipt)
        print(json.dumps(receipt, ensure_ascii=False))
        for row in result.get('assertions', []):
            if not row['passed']:
                print('FAIL ' + row['label'])
        assert code == 0 and result.get('passed') and unchanged and source_unchanged
        registration.outcome = 'passed'
        registration.note = '采集/序列化/接收组件通过；不是原生或 TCP 验收'


if __name__ == '__main__':
    main()
