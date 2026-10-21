"""Offline insertion/fake-runner checks; never compiles or launches a process."""
import ast
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch
import run_native as entry
import prepare as recipe

checks=[]
def check(label,value):
    assert value,label
    checks.append(dict(label=label,passed=True))


def row(width,height,index):
    return dict(diagnosticOnly=True,performanceQualified=False,stage='unchanged',outcome='success',
        scope='unchanged',field='all-inputs',id=index,at=index*100,width=width,height=height)


def evidence():
    return dict(rows={'host':[],'join':[row(240,125,1),row(48,25,2),row(240,125,3)]},parse_errors=[])


def fake_case(name,passed=True,changed=False,missing=False):
    adapter=entry.adapter
    with tempfile.TemporaryDirectory(prefix='.offline-',dir=recipe.HERE) as temporary:
        root=Path(temporary);m52=root/'build/m52';coop=root/'build/cooperation';m52.mkdir(parents=True);coop.mkdir()
        out=m52/name;raw=b'{"run":"0123456789","passed":'+(b'true' if passed else b'false')+b',"retained":true}'
        old_argv=sys.argv[:];sentinel=lambda path:None
        def main():
            assert adapter.framework.audit is entry.audit
            assert sys.argv[sys.argv.index('--scenario')+1]=='scene'
            assert sys.argv[sys.argv.index('--drivers')+1]==str(adapter.DRIVERS)
            assert sys.argv[sys.argv.index('--game-candidate')+1]==str(adapter.HOST)
            assert '--solo' not in sys.argv and '--seconds' not in sys.argv
            out.mkdir();(out/'result.json').write_bytes(raw);run=coop/'0123456789';run.mkdir()
            for role,rows in evidence()['rows'].items():
                if missing and role=='join':rows=rows[:-1]
                (run/(role+'.log')).write_text('\n'.join('RConnectViewReason '+json.dumps(r) for r in rows),encoding='utf-8')
            if not passed:raise SystemExit(1)
        with patch.object(adapter,'ROOT',root),patch.object(adapter,'M52',m52),\
             patch.object(adapter,'fingerprints',side_effect=[{'input':1},{'input':2 if changed else 1}]),\
             patch.object(adapter.framework,'audit',sentinel),patch.object(adapter.framework,'main',main),\
             contextlib.redirect_stdout(io.StringIO()):
            code=adapter.run(out,0)
            assert adapter.framework.audit is sentinel and sys.argv==old_argv
        result=json.loads((out/'diagnostic-result.json').read_text())
        assert (out/'result.json').read_bytes()==(out/'framework-result.json').read_bytes()==raw
        assert result['framework_result_sha256']==hashlib.sha256(raw).hexdigest()
        assert result['passed'] is False and result['gameplay_qualified'] is False and result['performance_qualified'] is False
        expected=passed and not changed and not missing
        check(name,code==(0 if expected else 1) and result['diagnostic_checks_passed'] is expected)


def main():
    with patch('subprocess.Popen',side_effect=AssertionError('Offline only')):
        proposal,base=recipe.proposal()
        check('Exact11 source and one overlay',set(proposal['overlay'])=={recipe.REL})
        original=(recipe.BASE/'src'/recipe.REL).read_bytes()
        text=(recipe.HERE/'src'/recipe.REL).read_text()
        check('Strip returns exact original bytes',recipe.stripped(text).encode()==original)
        check('Generator reproduces overlay with explicit imports',recipe.transformed(original.decode())==text
            and 'import rconnect.core.Log;' in text and 'import flash.utils.getTimer;' in text
            and 'rconnect.core.Log.d(' not in text and 'flash.utils.getTimer(' not in text
            and 'Log.d("RConnectViewReason ' in text and 'at:getTimer()' in text)
        check('Refresh has no instrumentation',text.split('public function refresh',1)[1]==original.decode().split('public function refresh',1)[1])
        check('External mutation cannot strip equal',recipe.stripped(text+'\n').encode()!=original)
        check('Three scene observations accepted',entry.rows_complete(evidence()))
        value=evidence();value['rows']['join'].pop();check('Missing observation rejected',not entry.rows_complete(value))
        value=evidence();value['parse_errors'].append({});check('Malformed evidence rejected',not entry.rows_complete(value))
        fake_case('raw-success-stays-diagnostic-only')
        fake_case('original-failure-retained',passed=False)
        fake_case('changed-inputs-not-qualified',changed=True)
        fake_case('missing-reasons-not-qualified',missing=True)
        for path in recipe.HERE.glob('*.py'):ast.parse(path.read_text())
    result=dict(passed=True,checks=checks,count=len(checks),jvm_started=False,air_started=False,
        actual_as_execution=False,gameplay_qualified=False,performance_qualified=False)
    (recipe.HERE/'offline-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,count=len(checks),jvm_started=False,air_started=False)))


if __name__=='__main__':main()
