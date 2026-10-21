"""Freeze source plus Embed data, compile and run the 73-check AIR component.

Default is read-only input verification. --run explicitly opts into registered
JVM/AIR execution. A new build/m52 direct child is required for every run.
This adapter never modifies generic tools, accepted inputs, installed files or
the expected assertion count. Only its own child handles may be terminated.
"""
import argparse
import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import traceback
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
EXPECTED = 73
ENTRY = 'WorkingSetChecks.as'
EXPECTED_OLD_BY_CASE = [221, 148, 133, 154, 119, 166, 172, 163]
ERROR = re.compile(r'^\s*(?:FAIL\b|Error(?:\s*#\d+|:)|(?:TypeError|ArgumentError|ReferenceError|'
                   r'VerifyError|RangeError|SecurityError):)|\bout of memory\b', re.I)


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def source_recipe():
    spec = importlib.util.spec_from_file_location('wall_working_set_source_recipe', HERE / 'prepare.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_source():
    source_recipe().verify()  # Read-only: never calls materialize().
    require((HERE / 'components' / ENTRY).is_file(), 'Missing component entry')
    entry = (HERE / 'components' / ENTRY).read_text(encoding='utf-8-sig')
    embeds = re.findall(r'\[Embed\(source="([^"]+)"', entry)
    require(embeds == ['../data/flight-payloads.json'], 'Unexpected Embed input')
    require((HERE / 'components' / embeds[0]).resolve() == HERE / 'data/flight-payloads.json', 'Embed escapes fixture')
    return read(HERE / 'inputs.json')


def helpers():
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from common import JAVA, SDK
    from runtime_memory import snapshot, wait_owned
    from run_security_terminals import installation
    from test_registry import Registration
    from air_test_process import HiddenProcess
    return JAVA, SDK, snapshot, wait_owned, installation, Registration, HiddenProcess


def tool_inventory(java, sdk):
    paths = [Path(__file__).resolve(), HERE / 'prepare.py', Path(sys.executable), java,
             sdk / 'lib/mxmlc.jar', sdk / 'frameworks/air-config.xml',
             sdk / 'frameworks/libs/air/airglobal.swc',
             ROOT / 'tools/host_authority/common.py', ROOT / 'tools/validation/runtime_memory.py',
             ROOT / 'tools/validation/run_security_terminals.py',
             ROOT / 'tools/validation/prepare_security_terminals.py',
             GAME / 'mods/ModLoader/tools/test_registry.py', GAME / 'mods/ModLoader/tools/air_test_process.py',
             GAME / 'adl64.exe', GAME / 'runtimes/air/win64/Adobe AIR/Versions/1.0/Adobe AIR.dll']
    require(all(p.is_file() for p in paths), 'Missing compiler/runtime/helper input')
    return {str(p.resolve()): sha(p) for p in paths}


def installed(installation):
    values = installation()
    require(len(values) == 22, 'Expected exactly 22 installed runtime inputs; inspect changed inventory')
    return values


def validate_result(raw):
    rows = raw.get('assertions')
    require(isinstance(rows, list) and rows and all(isinstance(r, dict) and
            type(r.get('passed')) is bool and isinstance(r.get('label'), str) and r['label'] for r in rows),
            'Malformed per-assertion component result')
    require(len({r['label'] for r in rows}) == len(rows), 'Duplicate assertion labels')
    failures = [r for r in rows if not r['passed']]
    require(type(raw.get('failed')) is int and raw['failed'] == len(failures), 'Failure total disagrees with rows')
    require(type(raw.get('passed')) is bool and raw['passed'] == (len(failures) == 0), 'Pass flag disagrees with rows')
    require(len(rows) == EXPECTED, 'Expected exactly 73 actual assertions; never rewrite this expectation')
    for name in ['native_game', 'tcp_socket', 'performance_qualified']:
        require(raw.get(name) is False, 'Unexpected qualification: ' + name)
    require(raw.get('observed_real_payloads') is True, 'Real payload fixture was not reported')
    measured = raw.get('measurements', {}).get('trace', {})
    require(type(measured.get('oldUnpack')) is int and measured['oldUnpack'] == 1276,
            'Actual old unpack count missing or unexpected')
    require(type(measured.get('newUnpack')) is int and measured['newUnpack'] == 82,
            'Actual new unpack count missing or unexpected')
    require(measured.get('recordedMissOrderOnly') is True and measured.get('omittedReadOnlyHits') == 1147
            and measured.get('omittedProtectedDecodes') == 122, 'Replay evidence scope changed')
    rounds = measured.get('byCase')
    require(isinstance(rounds, list) and len(rounds) == 8, 'Missing per-case actual decode measurements')
    for i, row in enumerate(rounds):
        require(isinstance(row, dict) and all(type(row.get(k)) is int for k in ('oldUnpack', 'newUnpack', 'visits')),
                'Malformed case decode measurement')
        require(row['visits'] == row['oldUnpack'] == EXPECTED_OLD_BY_CASE[i] and
                row['newUnpack'] == (82 if i == 0 else 0), 'Unexpected actual case decode count: ' + str(i))
    require(not failures, 'Component assertions failed')
    return {'observed_checks': len(rows), 'checks_passed': len(rows) - len(failures),
            'checks_failed': len(failures), 'failures': failures, 'measurements': raw['measurements']}


def freeze(out, manifest, tools):
    require(not out.exists() and out.parent == ROOT / 'build/m52', 'Use a new build/m52 direct child')
    out.mkdir()
    values = dict(manifest['outputs'])
    for name in ['inputs.json', 'prepare.py', 'proposal.patch', 'README.md', 'run_component.py']:
        values[name] = sha(HERE / name)
    for name, digest in values.items():
        source, dest = (HERE / name).resolve(), out / 'frozen' / name
        require(source.is_relative_to(HERE), 'Source escaped proposal')
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        require(sha(dest) == digest, 'Frozen source/data copy differs: ' + name)
    # Preserve helper recipes, not another copy of large runtimes/SDKs.
    copies = {}
    for source, digest in tools.items():
        p = Path(source)
        if p.suffix == '.py' and p not in [Path(__file__).resolve(), HERE / 'prepare.py']:
            name = 'helpers/' + hashlib.sha256(source.encode()).hexdigest()[:12] + '-' + p.name
            dest = out / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, dest)
            require(sha(dest) == digest, 'Frozen helper differs: ' + source)
            copies[name] = digest
    require((out / 'frozen/components/../data/flight-payloads.json').resolve() ==
            out / 'frozen/data/flight-payloads.json', 'Frozen Embed relationship changed')
    return values, copies


def run(args):
    manifest = check_source()
    java, sdk, snapshot, wait_owned, installation, Registration, HiddenProcess = helpers()
    before = installed(installation)
    tools = tool_inventory(java, sdk)
    out = (ROOT / args.output).resolve()
    sources, helper_copies = freeze(out, manifest, tools)
    intent = {'kind': 'wall-working-set-component', 'source': str(HERE), 'sources': sources,
              'tools': tools, 'helper_copies': helper_copies, 'installation_before': before,
              'entry': ENTRY, 'expected_checks': EXPECTED, 'minimum_start_bytes': 1024**3,
              'minimum_runtime_bytes': 512 * 1024**2, 'private_desktop': True,
              'native_game': False, 'tcp_socket': False, 'performance_qualified': False}
    save(out / 'intent.json', intent)
    result = {'passed': False, 'compiled': False, 'air_started': False, 'installed': False,
              'functional_only': True, 'native_game': False, 'tcp_socket': False,
              'performance_qualified': False, 'expected_checks': EXPECTED}

    def verify():
        check_source()
        for name, digest in sources.items():
            require(sha(HERE / name) == digest and sha(out / 'frozen' / name) == digest,
                    'Source or frozen input changed: ' + name)
        for name, digest in helper_copies.items():
            require(sha(out / name) == digest, 'Frozen helper changed: ' + name)
        for name, digest in tools.items():
            require(sha(name) == digest, 'Tool/runtime changed: ' + name)
        require(installed(installation) == before, 'Installed runtime inputs changed')
        if result['compiled']:
            require(sha(out / 'Checks.swf') == result['component_sha256'], 'Compiled component changed')

    try:
        with Registration(owner='RConnect / 墙面缓存工作集组件', resource='game',
                          purpose='actual old/new wall decode; 73 checks; no native game or performance claim',
                          run_dir=out, evidence=out / 'receipt.json', wait=args.registry_wait) as record:
            verify()
            memory = snapshot(); save(out / 'memory-before-compile.json', memory)
            require(memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB commit headroom; compiler not started')
            command = [str(java), '-Xmx256m', '-jar', str(sdk / 'lib/mxmlc.jar'), '+configname=air',
                       '+flexlib=' + str(sdk / 'frameworks'), '-swf-version=38', '-debug=true',
                       '-source-path=' + str(out / 'frozen/components'),
                       '-output=' + str(out / 'Checks.swf'), str(out / 'frozen/components' / ENTRY)]
            save(out / 'compile-command.json', command)
            process = None
            with (out / 'compile.log').open('w', encoding='utf-8') as log:
                try:
                    record.before_launch('compiler / ' + ENTRY)
                    process = subprocess.Popen(command, cwd=out, stdout=log, stderr=subprocess.STDOUT,
                                               env=dict(os.environ, AIR_HOME=str(sdk)),
                                               creationflags=subprocess.CREATE_NO_WINDOW)
                    record.child(process.pid)
                    result['compile_pid'] = process.pid
                    result['compile_exit'] = wait_owned(process, 120, out / 'compile-memory-timeline.json')
                finally:
                    if process is not None:
                        if process.poll() is None: process.kill()
                        process.wait(timeout=15)
                    record.child_stopped()
            require(result['compile_exit'] == 0 and (out / 'Checks.swf').is_file(), 'Compilation failed; see compile.log')
            result.update(compiled=True, component_sha256=sha(out / 'Checks.swf'))
            verify()
            memory = snapshot(); save(out / 'memory-before-air.json', memory)
            require(memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB commit headroom; AIR not started')
            appid = 'rconnect-wall-working-set-' + uuid.uuid4().hex
            storage = Path(os.environ['APPDATA']) / appid / 'Local Store'
            require(not storage.parent.exists(), 'Unique component application storage already exists')
            descriptor = out / 'application.xml'
            descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid +
                '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>' +
                '<content>Checks.swf</content><visible>false</visible><width>120</width><height>120</height>' +
                '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
            command = [str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)]
            intent.update(appid=appid, storage=str(storage), descriptor_sha256=sha(descriptor), air_command=command)
            save(out / 'intent.json', intent)
            process = None
            with (out / 'stdout.log').open('w', encoding='utf-8') as log:
                try:
                    verify()
                    require(sha(descriptor) == intent['descriptor_sha256'], 'AIR descriptor changed')
                    record.before_launch('component / ' + appid)
                    process = HiddenProcess(command, cwd=out, stdout=log, stderr=log)
                    record.child(process.pid)
                    result.update(air_started=True, pid=process.pid, appid=appid, desktop=process.desktop)
                    save(out / 'process.json', result)
                    result['exit_code'] = wait_owned(process, 60, out / 'memory-timeline.json')
                finally:
                    if process is not None:
                        if process.poll() is None:
                            process.kill(); process.wait(15)
                        process.close()
                    record.child_stopped()
            require((storage / 'result.json').is_file(), 'Component wrote no unique result')
            shutil.copyfile(storage / 'result.json', out / 'component-result.json')
            raw = read(out / 'component-result.json')
            result['raw_result_sha256'] = sha(out / 'component-result.json')
            # Preserve raw rows/counts even if strict validation later rejects.
            result['observed_checks'] = len(raw.get('assertions', [])) if isinstance(raw.get('assertions'), list) else None
            result['actual_assertions'] = raw.get('assertions')
            result['measurements'] = raw.get('measurements')
            if isinstance(raw.get('assertions'), list):
                rows = raw['assertions']
                result['checks_passed'] = sum(isinstance(r, dict) and r.get('passed') is True for r in rows)
                result['checks_failed'] = sum(isinstance(r, dict) and r.get('passed') is False for r in rows)
                result['failures'] = [r for r in rows if isinstance(r, dict) and r.get('passed') is False]
            result.update(validate_result(raw))
            result['errors'] = [{'line': n, 'text': line} for n, line in enumerate(
                (out / 'stdout.log').read_text(encoding='utf-8-sig', errors='replace').splitlines(), 1) if ERROR.search(line)]
            require(result['exit_code'] == 0 and not result['errors'], 'Component exit or runtime log failed')
            verify()
            require(sha(descriptor) == intent['descriptor_sha256'], 'AIR descriptor changed during run')
            result['passed'] = True
            record.outcome = 'passed'
            record.note = '73 actual component assertions passed; functional only, native/performance unqualified'
    except BaseException as error:
        result.update(passed=False, error=str(error), error_type=type(error).__name__, traceback=traceback.format_exc())
    finally:
        try:
            verify()
            result['inputs_unchanged'] = True
        except BaseException as error:
            result.update(passed=False, inputs_unchanged=False, final_audit_error=str(error))
        try:
            after = installation()
            result['installation_after'] = after
            result['installation_changes'] = {n: {'before': before.get(n), 'after': after.get(n)}
                for n in sorted(set(before) | set(after)) if before.get(n) != after.get(n)}
            if len(after) != 22 or result['installation_changes']: result['passed'] = False
        except BaseException as error:
            result.update(passed=False, installation_after_error=str(error))
        save(out / 'receipt.json', result)
        print(json.dumps({k: result.get(k) for k in ['passed', 'compiled', 'air_started', 'observed_checks',
              'checks_failed', 'error', 'inputs_unchanged', 'installation_changes', 'performance_qualified']},
              ensure_ascii=False), flush=True)
    return 0 if result['passed'] else 1


def self_test():
    # In-memory validator tests only; no registration, compiler, AIR or fixture writes.
    raw = {'assertions': [{'passed': True, 'label': 'check ' + str(i)} for i in range(EXPECTED)],
           'passed': True, 'failed': 0, 'native_game': False, 'tcp_socket': False,
           'performance_qualified': False, 'observed_real_payloads': True,
           'measurements': {'trace': {'oldUnpack': 1276, 'newUnpack': 82, 'recordedMissOrderOnly': True,
               'omittedReadOnlyHits': 1147, 'omittedProtectedDecodes': 122,
               'byCase': [{'oldUnpack': n, 'newUnpack': 82 if i == 0 else 0, 'visits': n}
                          for i, n in enumerate(EXPECTED_OLD_BY_CASE)]}}}
    require(validate_result(raw)['observed_checks'] == 73, 'Valid fixture rejected')
    edits = [lambda x: x['assertions'].pop(), lambda x: x['assertions'][0].update(passed=False),
             lambda x: x.update(performance_qualified=True), lambda x: x['measurements']['trace'].update(newUnpack=83),
             lambda x: x['measurements']['trace']['byCase'][1].update(newUnpack=1),
             lambda x: x['assertions'][1].update(label='check 0'), lambda x: x.update(failed=True)]
    for edit in edits:
        bad = json.loads(json.dumps(raw)); edit(bad)
        try: validate_result(bad)
        except RuntimeError: pass
        else: raise RuntimeError('Invalid fixture accepted')
    require(not ERROR.search('PASS malformed same native reject/error'), 'Expected rejection label falsely flagged')
    require(ERROR.search('TypeError: Error #1009') and ERROR.search('FAIL actual check'), 'Runtime failure not detected')
    ast.parse(Path(__file__).read_text(encoding='utf-8'))
    print(json.dumps({'self_test_passed': True, 'validator_cases': 8, 'runtime_log_cases': 3,
                      'JVM_started': False, 'AIR_started': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--run', action='store_true', help='Register, compile and launch this isolated component')
    parser.add_argument('--self-test', action='store_true', help='In-memory Python validator checks only')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    if args.self_test:
        require(not args.run and args.output is None, 'Self-test never launches or creates a run')
        self_test(); return 0
    if not args.run:
        require(args.output is None, '--output requires explicit --run')
        check_source(); return 0
    require(args.output is not None and args.registry_wait >= 0, '--run needs a fresh --output and nonnegative wait')
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
