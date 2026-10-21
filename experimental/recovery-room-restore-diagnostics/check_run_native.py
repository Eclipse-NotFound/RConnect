"""Offline runner-adapter checks. Fake framework only; no JVM/AIR/processes."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('checked_restore_runner', HERE / 'run_native.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
checks = []


def check(label, condition):
    assert condition, label
    checks.append(dict(label=label, passed=True))


def row(role):
    return dict(role=role, diagnosticOnly=True, performanceQualified=False,
        reason='three-complete-enter-frames', frames=[{}, {}, {}], scopeMismatches=0, openScopes={})


def fake_case(name, passed=True, complete=True, changed=False, malformed=False, raises=False):
    with tempfile.TemporaryDirectory(prefix='.runner-offline-', dir=HERE) as temporary:
        root = Path(temporary).resolve()
        m52 = root / 'build/m52'
        coop = root / 'build/cooperation'
        m52.mkdir(parents=True)
        coop.mkdir()
        out = m52 / name
        sentinel = lambda value: None
        original_argv = sys.argv[:]
        raw_bytes = b'{"passed":' + (b'true' if passed else b'false') + b',"run":"0123456789","original_failure":' + (b'null' if passed else b'"COOP FAIL preserved"') + b'}'
        def fake_main():
            assert runner.framework.audit is runner.audit
            # Only audit was replaced, and all scenario inputs remain pinned.
            assert sys.argv[sys.argv.index('--candidate')+1] == str(runner.CANDIDATE)
            assert sys.argv[sys.argv.index('--drivers')+1] == str(runner.DRIVERS)
            assert sys.argv[sys.argv.index('--game-candidate')+1] == str(runner.HOST)
            assert sys.argv[sys.argv.index('--scenario')+1] == 'scene'
            assert '--solo' not in sys.argv and '--seconds' not in sys.argv
            out.mkdir()
            (out / 'result.json').write_bytes(raw_bytes)
            run = coop / '0123456789'
            run.mkdir()
            for role in ('host', 'join'):
                text = '\n'.join('RConnectRestoreCost ' + json.dumps(row(role)) for _ in range(3 if complete else 2))
                if malformed and role == 'join': text += '\nRConnectRestoreCost {broken'
                (run / (role + '.log')).write_text(text, encoding='utf-8')
            print(raw_bytes.decode())
            if raises: raise SystemExit(1)
        with patch.object(runner, 'ROOT', root), patch.object(runner, 'M52', m52), \
             patch.object(runner.framework, 'audit', sentinel), patch.object(runner.framework, 'main', fake_main), \
             patch.object(runner, 'fingerprints', side_effect=[{'fingerprint':1}, {'fingerprint':2 if changed else 1}]), \
             contextlib.redirect_stdout(io.StringIO()) as console:
            code = runner.run(out, 0)
            assert runner.framework.audit is sentinel and sys.argv == original_argv
        data = json.loads((out / 'diagnostic-result.json').read_text())
        assert (out / 'result.json').read_bytes() == (out / 'framework-result.json').read_bytes() == raw_bytes
        assert data['framework_result_sha256'] == hashlib.sha256(raw_bytes).hexdigest()
        assert data['passed'] is False and not data['gameplay_qualified'] and not data['performance_qualified']
        assert data['diagnostic_only'] is True
        assert json.loads(console.getvalue())['passed'] is False
        expected = passed and complete and not changed and not malformed and not raises
        assert data['diagnostic_checks_passed'] is expected and code == (0 if expected else 1)
        if malformed: assert len(data['parse_errors']) == 1
        if not passed: assert b'COOP FAIL preserved' in (out / 'framework-result.json').read_bytes()
        check(name + ': exact evidence/qualification/restore', True)


def main():
    with patch('subprocess.Popen', side_effect=AssertionError('Offline checks cannot create a process')):
        meta = runner.audit(runner.CANDIDATE)
        check('Exact compiled diagnostic fingerprint', meta['compiled'] is True)
        try: runner.audit(runner.DRIVERS)
        except AssertionError: check('Other candidate rejected', True)
        else: raise AssertionError('Wrong candidate accepted')
        frozen = runner.fingerprints()
        check('Read-only complete candidate/scene12/E159/tools/22 installation inputs', len(frozen['installation']) == 22)
        fake_case('success')
        fake_case('framework-failure', passed=False, raises=True)
        fake_case('incomplete-costs', complete=False)
        fake_case('input-change', changed=True)
        fake_case('malformed-cost-row', malformed=True)
        fake_case('exception-after-raw-success', raises=True)
        check('Missing rows cannot pass', not runner.rows_complete(dict(rows={}, parse_errors=[])))
        bad = row('join'); bad['frames'] = 'abc'
        check('Malformed frames cannot pass', not runner.rows_complete(dict(rows={'host':[row('host')]*3,'join':[bad]*3},parse_errors=[])))
    result = dict(kind='restore-runner-offline-checks', checks=checks, passed=True, count=len(checks),
        jvm_started=False, air_started=False, native_qualified=False,
        sources={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (Path(__file__), HERE/'run_native.py')})
    (HERE/'native-runner-offline-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'checks':len(checks),'passed':True,'jvm_started':False,'air_started':False}))


if __name__ == '__main__': main()
