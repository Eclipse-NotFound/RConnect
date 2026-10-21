"""Freeze the exact control/patch and shared component; no process without flags.

--compile compiles a resource-free AIR component. --run also runs it in an
isolated hidden AIR app under the shared game registration. The unchanged
control is expected to report genuine failed regression assertions and exit 1;
those results are never rewritten as a functional pass.
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
BASE = ROOT / 'build/m52/recovery-03/src'
NAMES = ['ImpactEventQueue', 'ProjectileFrameStream', 'ProjectileVisuals',
         'EnergyImpactVisuals', 'BallisticImpactVisuals', 'RemoteMotion']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def unchanged(paths):
    return all(Path(p).is_file() and sha(p) == h for p, h in paths.items())


def validate_result(result, expected):
    """Reject empty/partial or contradictory reports without changing raw evidence."""
    errors = []
    if not isinstance(result, dict):
        return ['Result is not an object'], []
    rows = result.get('assertions')
    if not isinstance(rows, list) or not rows:
        return ['Assertions must be a nonempty array'], []
    if len(rows) != expected:
        errors.append('Assertion count differs from the complete fixture')
    valid = all(isinstance(row, dict) and type(row.get('passed')) is bool
                and isinstance(row.get('label'), str) and row['label'] for row in rows)
    if not valid:
        return errors + ['Every assertion needs a Boolean passed and a nonempty label'], []
    failed = [row for row in rows if not row['passed']]
    passed_count = len(rows) - len(failed)
    for name, actual in [('total', len(rows)), ('passed_count', passed_count), ('failed', len(failed))]:
        if type(result.get(name)) is not int or result[name] != actual:
            errors.append(name + ' summary disagrees with individual assertions')
    if type(result.get('passed')) is not bool or result['passed'] != (len(failed) == 0):
        errors.append('passed summary disagrees with individual assertions')
    return errors, failed


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output')
    ap.add_argument('--variant', choices=('control', 'candidate'), required=True)
    ap.add_argument('--compile', action='store_true')
    ap.add_argument('--run', action='store_true')
    ap.add_argument('--registry-wait', type=float, default=300)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and not out.exists(), out
    manifest = json.loads((HERE / 'manifest.json').read_text(encoding='utf-8'))
    assert sha(ROOT / 'build/m52/recovery-03/RConnectMod.swf') == manifest['base_swf_sha256']
    sources = {}
    for name in NAMES:
        relative = 'rconnect/game/' + name + '.as'
        original = BASE / relative
        assert sha(original) == manifest['base_sources'][relative], original
        sources[str(original)] = sha(original)
        patched = HERE / 'src' / relative
        if patched.is_file():
            assert sha(patched) == manifest['overlay_sources'][relative], patched
            sources[str(patched)] = sha(patched)
    for path in (HERE / 'tests').rglob('*.as'):
        sources[str(path)] = sha(path)
    sources[str(Path(__file__).resolve())] = sha(__file__)
    sources[str(HERE / 'manifest.json')] = sha(HERE / 'manifest.json')
    installed = {str(p): sha(p) for p in [GAME / 'pfe.swf', ROOT / 'release/RConnectMod.swf']}
    out.mkdir()
    src = out / 'src'
    shutil.copytree(HERE / 'tests', src)
    for name in NAMES:
        relative = 'rconnect/game/' + name + '.as'
        source = HERE / 'src' / relative if args.variant == 'candidate' and (HERE / 'src' / relative).is_file() else BASE / relative
        target = src / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    frozen = {str(p): sha(p) for p in src.rglob('*.as')}
    save(out / 'inputs.json', dict(variant=args.variant, input_sources=sources,
        frozen_sources={Path(p).relative_to(src).as_posix(): h for p, h in frozen.items()},
        installed=installed, native_game=False, tcp=False, controlled_shooter_clock=True,
        actual_production=['ProjectileVisuals', 'ImpactEventQueue', 'ProjectileFrameStream',
                           'EnergyImpactVisuals', 'BallisticImpactVisuals', 'RemoteMotion']))
    if not (args.compile or args.run):
        assert unchanged(sources) and unchanged(frozen), 'Inputs changed while freezing'
        assert unchanged(installed), 'Installed inputs changed while freezing'
        save(out / 'receipt.json', dict(variant=args.variant, prepared=True, compiled=False, ran=False))
        print(out)
        return 0

    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from common import JAVA, SDK
    from runtime_memory import snapshot, wait_owned
    from test_registry import Registration
    from air_test_process import HiddenProcess
    receipt = dict(variant=args.variant, compiled=False, ran=False, native_game=False,
                   tcp=False, expected_control_failure=args.variant == 'control', input_checks=[])

    def verify_inputs(phase):
        check = dict(phase=phase, input_sources_unchanged=unchanged(sources),
                     frozen_sources_unchanged=unchanged(frozen), installation_unchanged=unchanged(installed))
        receipt['input_checks'].append(check)
        assert all(check[key] for key in check if key != 'phase'), 'Inputs changed at ' + phase

    try:
        with Registration(owner='RConnect recovery / impact detach component',
                          purpose='射手离房后的确认命中时钟解绑；前后同夹具，不是原生游戏验收',
                          run_dir=out, evidence=out / 'receipt.json', wait=args.registry_wait) as record:
            cmd = [str(JAVA), '-Xmx256m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
                   '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=true',
                   '-source-path=' + str(src), '-output=' + str(out / 'Checks.swf'), str(src / 'DetachChecks.as')]
            with (out / 'compile.log').open('w', encoding='utf-8') as log:
                record.before_launch('impact detach component compiler')
                verify_inputs('before_compiler_launch')
                process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                    env=dict(os.environ, AIR_HOME=str(SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
                record.child(process.pid)
                try:
                    code = process.wait(timeout=180)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    record.child_stopped()
            receipt['compile_exit'] = code
            verify_inputs('after_compiler_exit')
            checks_swf = out / 'Checks.swf'
            if checks_swf.is_file():
                receipt['checks_swf_sha256'] = sha(checks_swf)
            if code:
                record.outcome = 'failed'
                record.note = '组件编译失败；保留日志'
                return code
            assert checks_swf.is_file() and checks_swf.stat().st_size > 0, 'Compiler produced no Checks.swf'
            receipt['compiled'] = True
            if not args.run:
                record.outcome = 'passed'
                record.note = '仅组件编译；未运行 AIR'
                return 0
            memory = snapshot()
            save(out / 'memory-before.json', memory)
            assert memory['free_commit_bytes'] >= 1024 ** 3, 'Resource-free component requires 1 GiB'
            appid = 'rconnect-impact-detach-' + uuid.uuid4().hex
            descriptor = out / 'application.xml'
            descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>' + appid +
                '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>' +
                '<content>Checks.swf</content><visible>false</visible><width>320</width><height>200</height>' +
                '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf-8')
            with (out / 'stdout.log').open('w', encoding='utf-8') as log:
                record.before_launch('impact detach component ' + appid)
                verify_inputs('before_air_launch')
                assert sha(checks_swf) == receipt['checks_swf_sha256'], 'Checks.swf changed before launch'
                process = HiddenProcess([str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)],
                    cwd=out, stdout=log, stderr=log)
                record.child(process.pid)
                save(out / 'process.json', dict(pid=process.pid, app_id=appid))
                try:
                    code = wait_owned(process, 40, out / 'memory-timeline.json')
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    process.close()
                    record.child_stopped()
            result_path = Path(os.environ['APPDATA']) / appid / 'Local Store/result.json'
            result = {}
            report_errors = []
            if result_path.is_file():
                shutil.copyfile(result_path, out / 'result.json')
                try:
                    result = json.loads(result_path.read_text(encoding='utf-8'))
                except (ValueError, UnicodeError) as error:
                    report_errors.append('Result cannot be parsed: ' + str(error))
            errors, failed = validate_result(result, manifest['expected_normal_assertions'])
            report_errors.extend(errors)
            verify_inputs('after_air_exit')
            assert sha(checks_swf) == receipt['checks_swf_sha256'], 'Checks.swf changed during run'
            summary = result if isinstance(result, dict) else {}
            rows = summary.get('assertions')
            receipt.update(ran=True, exit=code, failed=summary.get('failed'),
                assertions=len(rows) if isinstance(rows, list) else 0,
                report_valid=not report_errors, report_errors=report_errors,
                functional_pass=code == 0 and not report_errors and summary.get('passed') is True,
                regression_failures=[row['label'] for row in failed if row['label'].startswith('REGRESSION ')],
                unrelated_failures=[row['label'] for row in failed if not row['label'].startswith('REGRESSION ')])
            record.outcome = 'passed' if receipt['functional_pass'] else 'failed'
            record.note = '候选组件通过；非原生验收' if receipt['functional_pass'] else '保留实际失败；control 预期回归断言为红，不改绿'
            return 0 if receipt['functional_pass'] else 1
    finally:
        receipt['sources_unchanged'] = unchanged(sources)
        receipt['frozen_sources_unchanged'] = unchanged(frozen)
        receipt['installation_unchanged'] = unchanged(installed)
        inputs_unchanged = all(receipt[key] for key in
            ('sources_unchanged', 'frozen_sources_unchanged', 'installation_unchanged'))
        if not inputs_unchanged:
            receipt['functional_pass'] = False
        save(out / 'receipt.json', receipt)
        print(json.dumps(receipt, ensure_ascii=False))
        assert inputs_unchanged, 'Inputs changed during component work'


if __name__ == '__main__':
    raise SystemExit(main())
