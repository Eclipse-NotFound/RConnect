"""Freeze/optionally compile slot-override counterexamples. Never run AIR.

Positive control must compile first. A missing SDK/type/syntax error is not an
accepted negative result. Outputs are new build/m52 directories only.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare import HERE, ROOT, GAME, sha


def accepted_error(log, class_name, field):
    errors = [line for line in log.splitlines() if 'Error:' in line]
    allowed = ('Incompatible override.',
               'Method marked override must override another method.',
               'A conflict exists with inherited definition ' + field + ' in namespace ')
    return bool(errors) and all(class_name+'.as' in line and
        any(message in line for message in allowed) for line in errors) and bool(
        re.search(r'override\s+public\s+function\s+get\s+'+field+r'\s*\(', log))


def inventory(path):
    return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*.as'))}


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def verify_inputs():
    info = json.loads((HERE/'extraction.json').read_text(encoding='utf-8'))
    assert all(sha(Path(p)) == h for p,h in info['inputs'].items()), 'Extraction input changed'
    manifest = json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
    assert all(sha(HERE/p) == h for p,h in manifest['files'].items()), 'Runtime fixture changed'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compile', action='store_true')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    verify_inputs()
    sys.path.insert(0, str(ROOT/'tools/host_authority'))
    from common import JAVA, SDK
    sys.path.insert(0, str(ROOT/'tools/validation'))
    from run_security_terminals import installation
    sys.path.insert(0, str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    before = installation()
    original = inventory(HERE/'components')
    negative = inventory(HERE/'negative')
    tools = {str(p):sha(p) for p in [Path(__file__).resolve(), JAVA, SDK/'lib/mxmlc.jar',
             SDK/'lib/asc.jar', GAME/'mods/ModLoader/tools/test_registry.py']}
    out.mkdir()
    cases = [('positive', 'PositiveCompileChecks', None),
             ('weapon', 'IllegalWeaponGetter', 'hold'), ('bullet', 'IllegalBulletGetter', 'babah')]
    for name, cls, field in cases:
        src = out/name/'src'
        shutil.copytree(HERE/'components/fe', src/'fe')
        shutil.copyfile(HERE/'negative'/(cls+'.as'), src/(cls+'.as'))
        if field:
            (src/'NegativeCompileChecks.as').write_text(
                'package { import flash.display.Sprite; public class NegativeCompileChecks extends Sprite {'
                ' public function NegativeCompileChecks(){trace(new '+cls+'());}}}\n', encoding='utf-8')
    frozen = {name:inventory(out/name/'src') for name,_,_ in cases}
    save(out/'intent.json', dict(sources=original, negative_sources=negative, frozen=frozen,
        tools=tools, installation_before=before, AIR_started=False, compile_requested=args.compile))
    result = dict(passed=False, prepared=True, compile_requested=args.compile, AIR_started=False,
                  native_game_test=False, performance_qualified=False, cases=[])

    def verify():
        verify_inputs()
        assert original == inventory(HERE/'components') and negative == inventory(HERE/'negative')
        assert all(frozen[n] == inventory(out/n/'src') for n,_,_ in cases)
        assert all(sha(Path(p)) == h for p,h in tools.items())
        assert installation() == before

    try:
        if args.compile:
            with Registration(owner='RConnect / probe slot 反例', resource='game',
                purpose='Exact13 probe fixture positive/negative compilation; no AIR',
                run_dir=out, evidence=out/'receipt.json', wait=args.registry_wait) as record:
                for name, cls, field in cases:
                    verify()
                    src=out/name/'src'
                    entry=cls+'.as' if field is None else 'NegativeCompileChecks.as'
                    command=[str(JAVA), '-Xmx256m', '-Duser.language=en', '-Duser.country=US',
                        '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
                        '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=true',
                        '-source-path='+str(src), '-output='+str(out/name/'Checks.swf'), str(src/entry)]
                    save(out/name/'command.json', command)
                    process=None
                    with (out/name/'compile.log').open('w',encoding='utf-8') as log:
                        try:
                            record.before_launch('compiler / probe '+name)
                            process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,
                                env=dict(os.environ,AIR_HOME=str(SDK)))
                            record.child(process.pid)
                            code=process.wait(timeout=120)
                        finally:
                            if process is not None:
                                if process.poll() is None:process.kill()
                                process.wait()
                            record.child_stopped()
                    text=(out/name/'compile.log').read_text(encoding='utf-8',errors='replace')
                    ok=code==0 and (out/name/'Checks.swf').is_file() if field is None else (
                        code!=0 and accepted_error(text,cls,field) and not (out/name/'Checks.swf').exists())
                    row=dict(name=name,exit_code=code,passed=ok,expected_rejection=field is not None,
                             log_sha256=sha(out/name/'compile.log'))
                    result['cases'].append(row)
                    assert ok, 'Unexpected '+name+' compilation result; inspect preserved log'
                verify()
                result['passed']=True
                record.outcome='passed'
                record.note='Positive compile plus two explicit inherited-variable override rejections; no AIR'
    except BaseException as error:
        result.update(error=str(error),error_type=type(error).__name__)
        raise
    finally:
        result['installation_unchanged']=installation()==before
        result['source_unchanged']=original==inventory(HERE/'components') and negative==inventory(HERE/'negative')
        if not result['installation_unchanged'] or not result['source_unchanged']:result['passed']=False
        save(out/'receipt.json',result)
        print(json.dumps(result,ensure_ascii=False),flush=True)


if __name__=='__main__':
    main()
