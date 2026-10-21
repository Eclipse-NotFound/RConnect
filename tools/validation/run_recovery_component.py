"""Freeze, compile and run a small source-only AIR component; no game is loaded.

All generated files stay under a fresh build/m52 directory. Registration covers
both compiler and AIR. The source tree and all installed runtime inputs are
checked again after execution; a failed run is never overwritten.
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
from run_security_terminals import installation

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from test_registry import Registration
from air_test_process import HiddenProcess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def inventory(root):
    return {p.relative_to(root).as_posix(): sha(p) for p in sorted(root.rglob('*.as'))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--entry', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected', type=int)
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    source, out = [(ROOT/p).resolve() for p in (args.source, args.output)]
    assert source.is_relative_to(ROOT) and source.is_dir()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert Path(args.entry).name == args.entry and args.entry.endswith('.as')
    assert (source/args.entry).is_file()
    before = installation()
    originals = inventory(source)
    out.mkdir()
    for name in originals:
        dest = out/'src'/name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source/name, dest)
    tools = {str(p): sha(p) for p in (Path(__file__).resolve(), JAVA,
             SDK/'lib/mxmlc.jar', GAME/'mods/ModLoader/tools/air_test_process.py',
             GAME/'mods/ModLoader/tools/test_registry.py', ROOT/'tools/validation/runtime_memory.py')}
    intent = dict(source=str(source), sources=originals, tools=tools, entry=args.entry,
                  expected=args.expected, installation_before=before, game_loaded=False)
    save(out/'intent.json', intent)
    result = dict(passed=False, compiled=False, air_started=False, native_game_test=False,
                  performance_qualified=False)

    def verify():
        assert inventory(source) == originals, 'Source changed during component run'
        assert inventory(out/'src') == originals, 'Frozen component source changed'
        assert installation() == before, 'Installed runtime inputs changed'
        assert all(sha(Path(p)) == digest for p, digest in tools.items()), 'Component tool changed'

    try:
        with Registration(owner='RConnect / 恢复候选组件', resource='game',
                          purpose=args.entry+'; small component, no game loaded',
                          run_dir=out, evidence=out/'receipt.json', wait=args.registry_wait) as record:
            verify()
            command = [str(JAVA), '-Xmx256m', '-jar', str(SDK/'lib/mxmlc.jar'),
                       '+configname=air', '+flexlib='+str(SDK/'frameworks'),
                       '-swf-version=38', '-debug=true', '-source-path='+str(out/'src'),
                       '-output='+str(out/'Checks.swf'), str(out/'src'/args.entry)]
            save(out/'compile-command.json', command)
            process = None
            with (out/'compile.log').open('w', encoding='utf-8') as log:
                try:
                    record.before_launch('compiler / '+args.entry)
                    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                               env=dict(os.environ, AIR_HOME=str(SDK)))
                    record.child(process.pid)
                    result['compile_exit'] = process.wait(timeout=120)
                finally:
                    if process is not None:
                        if process.poll() is None:
                            process.kill()
                        process.wait()
                    record.child_stopped()
            assert result['compile_exit'] == 0, 'Component compilation failed; see compile.log'
            result.update(compiled=True, component_sha256=sha(out/'Checks.swf'))
            verify()
            memory = snapshot()
            save(out/'memory-before.json', memory)
            assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB for small component'
            appid = 'rconnect-recovery-component-'+uuid.uuid4().hex
            storage = Path(os.environ['APPDATA'])/appid/'Local Store'
            assert not storage.parent.exists()
            descriptor = out/'application.xml'
            descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+
                '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>'+
                '<content>Checks.swf</content><visible>false</visible><width>640</width><height>400</height>'+
                '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
            process = None
            with (out/'stdout.log').open('w', encoding='utf-8') as log:
                try:
                    record.before_launch('component / '+appid)
                    process = HiddenProcess([str(GAME/'adl64.exe'), '-runtime',
                        str(GAME/'runtimes/air/win64'), str(descriptor)], cwd=out, stdout=log, stderr=log)
                    record.child(process.pid)
                    result.update(air_started=True, pid=process.pid, appid=appid, desktop=process.desktop)
                    save(out/'process.json', result)
                    result['exit_code'] = wait_owned(process, 60, out/'memory-timeline.json')
                finally:
                    if process is not None:
                        if process.poll() is None:
                            process.kill()
                            process.wait(15)
                        process.close()
                        record.child_stopped()
            assert (storage/'result.json').is_file(), 'Component wrote no result'
            shutil.copyfile(storage/'result.json', out/'component-result.json')
            raw = json.loads((out/'component-result.json').read_text(encoding='utf-8-sig'))
            rows = raw.get('assertions')
            assert isinstance(rows, list) and rows and all(isinstance(row, dict) and
                type(row.get('passed')) is bool and isinstance(row.get('label'), str) for row in rows)
            failures = [row for row in rows if not row['passed']]
            result.update(observed_checks=len(rows), checks_failed=len(failures), failures=failures)
            assert type(raw.get('failed')) is int and raw['failed'] == len(failures)
            assert type(raw.get('passed')) is bool and raw['passed'] == (not failures)
            assert args.expected is None or len(rows) == args.expected, 'Unexpected assertion count'
            assert result['exit_code'] == 0 and not failures, 'Component checks failed'
            verify()
            assert sha(out/'Checks.swf') == result['component_sha256']
            result['passed'] = True
            record.outcome='passed'
            record.note=str(len(rows))+' component checks passed; no native game or performance claim'
    except BaseException as error:
        result.update(error=str(error), error_type=type(error).__name__)
        raise
    finally:
        result['installation_unchanged'] = installation() == before
        result['source_unchanged'] = inventory(source) == originals
        if not result['installation_unchanged'] or not result['source_unchanged']:
            result['passed'] = False
        save(out/'receipt.json', result)
        print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
