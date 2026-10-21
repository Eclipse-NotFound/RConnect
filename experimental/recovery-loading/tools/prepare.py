"""Prepare exact recovery-loading inputs. Compilation/AIR remain opt-in elsewhere."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/validation'))
from check_coop_bundle import inventory, read, save, sha, verify, JAVA, SDK
from audit_room_entry_candidate import audit

BASE_SHA = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
ROOM_SHA = '051240012891ab8e6e41d30d8fb13ab16d120f41c5d9578a84a9146906257fea'
ROOM_MANIFEST = 'd11d8f9f04127989e62b669538c088e24200fc7286b9ae15527f1cc3550cd844'


def candidate(out, version):
    base = ROOT / 'build/m52/coop-bundle-04'
    room = ROOT / 'build/m52/room-entry-fast-19'
    bm, rm = verify(base), audit(room)
    assert bm['sha256'] == BASE_SHA and rm['sha256'] == ROOM_SHA
    assert sha(room / 'prepared.json') == ROOM_MANIFEST
    for name in ('src', 'tools'):
        shutil.copytree(room / name, out / name)
    source = HERE / 'src'
    for p in source.rglob('*.as'):
        target = out / 'src' / p.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
    entry = out / 'src/RConnectMod.as'
    body = entry.read_text(encoding='utf-8-sig')
    assert body.count(rm['version']) == 1
    entry.write_text(body.replace(rm['version'], version), encoding='utf-8')
    original = inventory(base / 'src')
    changed = {k: {'base': original.get(k), 'room19': v}
               for k, v in rm['source'].items() if original.get(k) != v}
    save(out / 'prepared.json', dict(kind='isolated-room-entry-fast', version=version,
        base_sha256=BASE_SHA, base_manifest=sha(base / 'prepared.json'),
        room19_sha256=ROOM_SHA, room19_manifest=ROOM_MANIFEST,
        room19_changes=changed, recovery_overlay=inventory(source),
        source=inventory(out / 'src'), inputs=inventory(out / 'tools'),
        recipe_sha256=sha(__file__), compiled=False))


def drivers(out):
    base = ROOT / 'build/m52/room-travel-driver-12'
    meta = read(base / 'prepared.json')
    for key, digest in meta['files'].items():
        assert sha(base / key) == digest, key
    shutil.copytree(base / 'tests', out / 'tests')
    shutil.copyfile(base / 'ProductionDeclarations.swc', out / 'ProductionDeclarations.swc')
    shutil.copyfile(HERE / 'tests/NativeLoadingProbe.as', out / 'tests/NativeLoadingProbe.as')
    p = out / 'tests/RoomEntryProbe.as'
    body = p.read_text(encoding='utf-8-sig')
    replacements = [
        ('      private var mod:RConnectMod,confirmedRoom:',
         '      private var nativeLoading:NativeLoadingProbe;\n      private var mod:RConnectMod,confirmedRoom:'),
        ('         mod=m;m.stage.addEventListener',
         '         mod=m;nativeLoading=new NativeLoadingProbe(m);m.stage.addEventListener'),
        ('         if(finished)return;finished=true;',
         '         if(finished)return;finished=true;nativeLoading.finish();'),
        # Room19 commits before ACK. Session has already processed `ready` when
        # this observer sees it, and rooms.term must match its transaction.
        ('mod.session.mode==Session.HOSTING && p.op=="ack"',
         'mod.session.mode==Session.HOSTING && (p.op=="ready" || p.op=="ack")'),
    ]
    for old, new in replacements:
        assert body.count(old) == 1, old
        body = body.replace(old, new)
    p.write_text(body, encoding='utf-8')
    for scenario in ('entry-room', 'entry-map'):
        (out / scenario).mkdir()
        shutil.copyfile(base / scenario / 'EffectsHarness.swf', out / scenario / 'EffectsHarness.swf')
    save(out / 'prepared.json', dict(files=inventory(out), recipe_sha256=sha(__file__),
        external=True, diagnostic_only=False, compiled=False,
        base_manifest=sha(base / 'prepared.json'), native_loading_observer=True,
        require_post_commit_host_confirmation=True, shared_wall_clock=True))


def compile_inputs(kind, out, wait):
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect recovery / loading', purpose='恢复候选或独立观察器编译',
                      run_dir=out, evidence=out / 'compile.log', wait=wait) as record:
        with (out / 'compile.log').open('w', encoding='utf-8') as log:
            if kind == 'candidate':
                command = [sys.executable, '-B', '-X', 'utf8', str(out / 'tools/build_mod.py'),
                    '--java', str(JAVA), '--amxmlc', str(SDK / 'bin/amxmlc.bat'),
                    '--output', str(out / 'RConnectMod.swf')]
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
            else:
                for name, entry in [('entry-room', 'A22RoomEntryTestDoc'), ('entry-map', 'A22MapEntryTestDoc')]:
                    command = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
                        '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
                        '-source-path=' + str(out / 'tests'),
                        '-external-library-path+=' + str(out / 'ProductionDeclarations.swc'),
                        '-external-library-path+=' + str(ROOT / 'build/m52/coop-bundle-04/build/GameCombatStubs.swc'),
                        '-output=' + str(out / name / 'EffectsDriver.swf'), str(out / 'tests' / (entry + '.as'))]
                    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True,
                                   env=dict(os.environ, AIR_HOME=str(SDK)))
        meta = read(out / 'prepared.json')
        meta['compiled'] = True
        if kind == 'candidate':
            meta['sha256'] = sha(out / 'RConnectMod.swf')
        else:
            meta['files'] = {k: v for k, v in inventory(out).items() if k != 'prepared.json'}
        save(out / 'prepared.json', meta)
        record.outcome = 'passed'
        record.note = '仅编译通过；原生加载、功能和性能仍待验证'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('kind', choices=['candidate', 'drivers'])
    ap.add_argument('output')
    ap.add_argument('--version', default='0.2.24-recovery-loading1')
    ap.add_argument('--build', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=300)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and not out.exists()
    if args.kind == 'candidate':
        candidate(out, args.version)
    else:
        drivers(out)
    if args.build:
        compile_inputs(args.kind, out, args.registry_wait)
    print(json.dumps({'prepared': str(out), 'compiled': args.build}, ensure_ascii=False))


if __name__ == '__main__':
    main()
