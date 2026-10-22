"""Build the approved A travel bridge on exact CEC6 sources, never release.

The Sandevistan working source contains B work and is deliberately not read as
an input. The original frozen source, proposal, compiler inputs and installed
runtime files are checked before and after the registered compilation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
SAND = GAME / 'mods/Sandevistan'
BASE = SAND / 'build/out/keybind-20261015-006'
PROPOSAL = ROOT / 'experimental/recovery-sandy-travel-hold-proposal'
sys.path.insert(0, str(ROOT / 'tools/validation'))
from runtime_memory import snapshot, wait_owned
from run_security_terminals import installation
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from test_registry import Registration


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def save(p, data):
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def apply_exact(old, patch):
    lines = old.replace('\r\n', '\n').splitlines(keepends=True)
    changes = patch.replace('\r\n', '\n').splitlines(keepends=True)
    out, cursor, count, added = [], 0, 0, 0
    i = 2
    while i < len(changes):
        h = re.fullmatch(r'@@ -(\d+),(\d+) \+(\d+),(\d+) @@\n', changes[i])
        assert h, 'Unexpected patch header'
        start, removed, new_start, inserted = map(int, h.groups())
        assert start - 1 >= cursor
        out += lines[cursor:start - 1]
        assert len(out) == new_start - 1
        cursor = start - 1
        before, after = [], []
        i += 1
        while i < len(changes) and not changes[i].startswith('@@ '):
            line = changes[i]
            assert line[0] in ' +', 'Approved patch must contain no removals'
            if line[0] == ' ':
                before.append(line[1:])
            else:
                added += 1
            after.append(line[1:])
            i += 1
        assert len(before) == removed and len(after) == inserted
        assert lines[cursor:cursor + removed] == before, 'CEC6 patch context mismatch'
        out += after
        cursor += removed
        count += 1
    assert count == 7 and added == 22
    return ''.join(out + lines[cursor:]).replace('\n', '\r\n').encode('utf-8')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', required=True, help='Fresh Sandevistan build/out child name')
    ap.add_argument('--registry-wait', type=float, default=900)
    args = ap.parse_args()
    assert Path(args.output).name == args.output
    out = (SAND / 'build/out' / args.output).resolve()
    assert out.parent == (SAND / 'build/out').resolve() and not out.exists()
    base = json.loads((BASE / 'build-input.json').read_text(encoding='utf-8'))
    assert base['candidate_sha256'] == 'cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942'
    assert sha(SAND / 'release/SandevistanMod.swf') == base['candidate_sha256']
    assert sha(BASE / 'SandevistanMod.swf') == base['candidate_sha256']
    assert not base['b_interface_included']
    inputs = {str(BASE / 'frozen' / name): digest for name, digest in base['sources'].items()}
    inputs.update({str(p): sha(p) for p in [Path(__file__), BASE / 'build-input.json',
                  BASE / 'candidate-config.xml', PROPOSAL / 'entry-changes.patch',
                  PROPOSAL / 'SandyTravelHoldBridge.as']})
    assert sha(PROPOSAL / 'entry-changes.patch') == 'fd21e2bdf79e61b5b6f0bf8238ed476d88517e120c2f7a12f636b8c7b3e478c3'
    assert sha(PROPOSAL / 'SandyTravelHoldBridge.as') == '5b195a60fedcd94b416a7f0f3fa82db5cc5423a843ec3d90ef6bcc78037a2890'
    assert all(sha(Path(p)) == digest for p, digest in inputs.items())
    installed = installation()
    out.mkdir()
    for name in base['sources']:
        dest = out / 'frozen' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(BASE / 'frozen' / name, dest)
    entry = out / 'frozen/src/SandevistanMod.as'
    old = entry.read_bytes().decode('utf-8')
    entry.write_bytes(apply_exact(old, (PROPOSAL / 'entry-changes.patch').read_text(encoding='utf-8')))
    assert sha(entry) == '577679b9da303a2959e50512a51c5cd0e39f37dfc46416615f8fb15ecf0cd352'
    assert 'SandyAuthority' not in entry.read_text(encoding='utf-8')
    helper = (PROPOSAL / 'SandyTravelHoldBridge.as').read_bytes().decode('utf-8')
    helper_eol = '\r\n' if '\r\n' in helper else '\n'
    helper = helper.replace('\r\n', '\n')
    for before, after in [
        ('} catch(e:*) {return null;}\n      }', '} catch(e:*) {return null;}\n         return null;\n      }'),
        ('} catch(e:*) {return false;}\n      }', '} catch(e:*) {return false;}\n         return false;\n      }')]:
        assert helper.count(before) == 1
        helper = helper.replace(before, after)
    (out / 'frozen/src/SandyTravelHoldBridge.as').write_bytes(helper.replace('\n', helper_eol).encode('utf-8'))
    cfg = out / 'candidate-config.xml'
    text = (BASE / 'candidate-config.xml').read_text(encoding='utf-8')
    assert text.count((BASE / 'frozen/src').as_posix()) == 1
    cfg.write_text(text.replace((BASE / 'frozen/src').as_posix(), (out / 'frozen/src').as_posix()), encoding='utf-8')
    command = [arg.replace(str(BASE), str(out)) for arg in base['command']]
    assert str(entry) == command[-1]
    for p in [Path(command[0]), SAND/'build/tools/flexsdk/lib/mxmlc.jar',
              SAND/'build/out/Gov60Stubs.swc', SAND/'build/tools/airsdk/frameworks/libs/air/airglobal.swc',
              SAND/'build/tools/airsdk/frameworks/libs/player/14.0/playerglobal.swc']:
        inputs[str(p)] = sha(p)
    sources = {p.relative_to(out/'frozen').as_posix(): sha(p) for p in sorted((out/'frozen').rglob('*.as'))}
    intent = dict(authorized='2026-10-22 A travel-hold interface; isolated test, qualified deployment only',
                  original_candidate=base['candidate_sha256'], inputs=inputs, sources=sources,
                  command=command, b_interface_included=False, installation_before=installed)
    save(out / 'intent.json', intent)
    result = dict(compiled=False, installed=False, native_tested=False, performance_qualified=False)

    def verify():
        assert installation() == installed, 'Installed inputs changed'
        assert all(sha(Path(p)) == digest for p, digest in inputs.items()), 'Input changed'
        assert all(sha(out/'frozen'/p) == digest for p, digest in sources.items()), 'Frozen source changed'

    try:
        with Registration(owner='RConnect / A版时停加载接口', resource='game',
                          purpose='准确CEC6增加已授权travel-hold接口；只编译，不部署',
                          run_dir=out, evidence=out/'receipt.json', wait=args.registry_wait) as rec:
            verify()
            mem = snapshot()
            save(out/'memory-before.json', mem)
            assert mem['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB for bounded compilation'
            proc = None
            try:
                with (out/'compile.log').open('w', encoding='utf-8') as log:
                    rec.before_launch('CEC6 + A travel hold compiler')
                    proc = subprocess.Popen(command, cwd=SAND, stdout=log, stderr=subprocess.STDOUT,
                                            env=dict(os.environ, JAVA_HOME=str(Path(command[0]).parent.parent)))
                    rec.child(proc.pid)
                    result['exit_code'] = wait_owned(proc, 120, out/'memory-timeline.json')
            finally:
                if proc is not None:
                    if proc.poll() is None:
                        proc.kill()
                    proc.wait()
                rec.child_stopped()
            assert result['exit_code'] == 0, 'Compilation failed; see compile.log'
            result.update(compiled=True, candidate=str(out/'SandevistanMod.swf'),
                          candidate_sha256=sha(out/'SandevistanMod.swf'))
            verify()
            rec.outcome = 'passed'
            rec.note = '准确CEC6+已授权A加载接口编译通过；未运行原生或部署'
    finally:
        try:
            verify()
            result['inputs_unchanged'] = True
        finally:
            save(out/'receipt.json', result)
            print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
