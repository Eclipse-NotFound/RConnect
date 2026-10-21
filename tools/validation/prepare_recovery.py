"""Freeze the reviewed four-feature recovery source; never deploy it."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

from check_coop_bundle import ROOT, M52, JAVA, SDK, inventory, read, save, sha, verify
from audit_room_entry_candidate import audit

BASE_SHA = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
ROOM_SHA = '051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea'


def prepare(args):
    source = (ROOT / args.source).resolve()
    assert source.parent == ROOT / 'experimental' and source.is_dir(), 'Use a reviewed experimental source directory'
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and not out.exists()
    base, room = M52 / 'coop-bundle-04', M52 / 'room-entry-fast-19'
    assert verify(base)['sha256'] == BASE_SHA
    assert audit(room)['sha256'] == ROOM_SHA
    assert (source / 'integration.json').is_file(), 'Complete source integration before freezing'
    original = inventory(source / 'src')
    integrated = read(source / 'integration.json')
    assert not integrated['static_errors']
    assert original == {row['path']: row['sha256'] for row in integrated['source']}, 'Integrated source changed after review receipt'
    assert original and 'RConnectMod.as' in original
    shutil.copytree(source / 'src', out / 'src')
    shutil.copytree(room / 'tools', out / 'tools')
    shutil.copyfile(source / 'integration.json', out / 'integration.json')
    version = args.version
    assert integrated['version'] == version
    text = (out / 'src/RConnectMod.as').read_text(encoding='utf-8-sig')
    assert 'VERSION:String = "'+version+'"' in text or 'VERSION:String="'+version+'"' in text
    meta = dict(kind='isolated-recovery', version=version, base_sha256=BASE_SHA,
        room19_sha256=ROOM_SHA, base_manifest_sha256=sha(base / 'prepared.json'),
        room_manifest_sha256=sha(room / 'prepared.json'),
        integration_sha256=sha(source / 'integration.json'),
        source=inventory(out / 'src'), inputs=inventory(out / 'tools'),
        recipe_sha256=sha(__file__), source_root=str(source),
        diagnostic_only=integrated.get('diagnostic_only', False), compiled=False, installed=False,
        gameplay_qualified=False, performance_qualified=False)
    assert inventory(source / 'src') == original == meta['source']
    save(out / 'prepared.json', meta)
    if args.build:
        sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
        from test_registry import Registration
        with Registration(owner='RConnect / 四项统一恢复', purpose=version+' 隔离编译，不部署',
                run_dir=out, evidence=out / 'compile.log', wait=args.registry_wait) as record:
            command = [sys.executable, '-B', '-X', 'utf8', str(out / 'tools/build_mod.py'),
                '--java', str(JAVA), '--amxmlc', str(SDK / 'bin/amxmlc.bat'),
                '--output', str(out / 'RConnectMod.swf')]
            with (out / 'compile.log').open('w', encoding='utf-8') as log:
                code = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
            meta.update(compile_exit=code, compile_log_sha256=sha(out / 'compile.log'))
            if not code:
                assert inventory(out / 'src') == meta['source']
                assert inventory(out / 'tools') == meta['inputs']
                meta.update(compiled=True, sha256=sha(out / 'RConnectMod.swf'),
                            candidate_sha256=sha(out / 'RConnectMod.swf'))
            save(out / 'prepared.json', meta)
            if code:
                print((out / 'compile.log').read_text(encoding='utf-8', errors='replace')[-6000:])
                raise SystemExit(code)
            record.outcome='passed'
            record.note='完整生产候选仅编译通过，四项实际画面与性能待验证'
    print(str(out), meta.get('sha256'), flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output', type=Path)
    ap.add_argument('--source', type=Path, default=Path('experimental/recovery-integrated'),
                    help='Reviewed complete source and integration manifest; defaults to the active recovery candidate')
    ap.add_argument('--version', default='0.2.24-recovery1')
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=300)
    prepare(ap.parse_args())


if __name__ == '__main__':
    main()
