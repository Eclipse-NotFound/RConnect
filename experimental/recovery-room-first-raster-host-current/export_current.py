"""Export three exact installed A796 classes; no host mutation or AIR."""
from pathlib import Path
import hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
OUT = ROOT/'build/m52/recovery-room-first-raster-current-source-02'
PIN = 'a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
CLASSES = ('fe.World', 'fe.loc.Game', 'fe.graph.Grafon')
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, FFDEC
sys.path.insert(0, str(ROOT/'tools/validation'))
from runtime_memory import snapshot, wait_owned
from run_security_terminals import installation
sys.path.insert(0, str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p, x): p.write_text(json.dumps(x, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def main():
    assert not sys.flags.optimize and not OUT.exists()
    host = GAME/'pfe.swf'
    assert sha(host) == PIN
    before = installation()
    OUT.mkdir()
    inputs = {str(p):sha(p) for p in (host, JAVA, FFDEC, Path(__file__),
        GAME/'mods/ModLoader/tools/test_registry.py', ROOT/'tools/validation/runtime_memory.py')}
    result = dict(kind='exact-A796-three-class-export', source=str(host), source_sha256=PIN,
        classes=CLASSES, inputs=inputs, installation_before=before, passed=False, commands=[], air_started=False)
    save(OUT/'receipt.json', result)
    def verify():
        assert installation() == before
        assert all(sha(p) == h for p, h in inputs.items())
    try:
        with Registration(owner='RConnect / 当前宿主首次绘制移植', resource='game',
            purpose='A796 World/Game/Grafon exact source and pcode export only',
            run_dir=OUT, evidence=OUT/'receipt.json', wait=900) as reg:
            for name, options in (('source', []), ('pcode', ['-format', 'script:pcode'])):
                verify()
                assert snapshot()['free_commit_bytes'] >= 1024**3
                command = [str(JAVA), '-Xmx512m', '-jar', str(FFDEC), *options,
                    '-selectclass', ','.join(CLASSES), '-export', 'script', str(OUT/name), str(host)]
                row = dict(command=command, pid=None, exit_code=None)
                result['commands'].append(row)
                process = None
                with (OUT/(name+'.log')).open('x', encoding='utf-8') as log:
                    try:
                        reg.before_launch('export '+name)
                        process = subprocess.Popen(command, cwd=OUT, stdout=log, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW)
                        row['pid'] = process.pid
                        reg.child(process.pid)
                        row['exit_code'] = wait_owned(process, 300, OUT/(name+'-memory.json'))
                        assert row['exit_code'] == 0
                    finally:
                        if process is not None:
                            if process.poll() is None: process.kill()
                            process.wait()
                            reg.child_stopped()
                log_text = (OUT/(name+'.log')).read_text(encoding='utf-8', errors='replace')
                assert not any(x in log_text for x in ('SEVERE:', 'Exception in thread', 'Export error'))
            for cls in CLASSES:
                p = OUT/'source/scripts'/Path(*cls.split('.')).with_suffix('.as')
                assert p.is_file() and p.stat().st_size > 1000, p
            assert len(list((OUT/'pcode/scripts').rglob('*.pcode'))) == 3
            verify()
            result['passed'] = True
            reg.outcome = 'passed'
            reg.note = 'Three exact classes exported; no patched host or gameplay claim'
    except BaseException as error:
        result['error'] = repr(error)
        raise
    finally:
        result['installation_unchanged'] = installation() == before
        result['inputs_unchanged'] = all(sha(p) == h for p, h in inputs.items())
        result['files'] = {p.relative_to(OUT).as_posix():sha(p)
            for sub in ('source','pcode') for p in (OUT/sub).rglob('*') if p.is_file()}
        if not result['installation_unchanged'] or not result['inputs_unchanged']: result['passed'] = False
        save(OUT/'receipt.json', result)
    print(json.dumps(dict(passed=result['passed'], output=str(OUT))))

if __name__ == '__main__': main()
