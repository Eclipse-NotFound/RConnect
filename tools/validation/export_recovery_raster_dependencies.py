"""Read-only export of exact E159 activation dependencies; no AIR or SWF writes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
HOST = ROOT / 'build/m52/recovery-native-travel-host-01/pfe.swf'
EXPECTED = 'e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c'
CLASSES = ('fe.inter.Camera', 'fe.inter.GUI', 'fe.loc.Land', 'fe.loc.Location')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    out = (ROOT / sys.argv[1]).resolve()
    assert out.parent == (ROOT / 'build/m52').resolve() and not out.exists()
    assert sha(HOST) == EXPECTED
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    from common import JAVA, FFDEC
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from test_registry import Registration
    from run_security_terminals import installation
    before = installation()
    assert len(before) == 22
    inputs = {str(p): sha(p) for p in (Path(__file__), HOST, JAVA, FFDEC)}
    out.mkdir()
    evidence = out / 'receipt.json'
    code = None
    try:
        with Registration(owner='RConnect / 初绘依赖只读导出', resource='game',
                          purpose='Export exact E159 Camera GUI Land Location; FFDec only',
                          run_dir=out, evidence=evidence, wait=900) as record:
            with (out / 'export.log').open('x', encoding='utf-8') as log:
                record.before_launch('FFDec read-only export / no AIR')
                process = None
                try:
                    process = subprocess.Popen([str(JAVA), '-Xmx512m', '-jar', str(FFDEC),
                        '-selectclass', ','.join(CLASSES), '-export', 'script', str(out), str(HOST)],
                        cwd=out, stdout=log, stderr=subprocess.STDOUT)
                    record.child(process.pid)
                    code = process.wait(timeout=180)
                finally:
                    if process is not None:
                        if process.poll() is None:
                            process.terminate()
                            try:
                                process.wait(timeout=10)
                            except subprocess.TimeoutExpired:
                                process.kill()
                                process.wait()
                        record.child_stopped()
            assert code == 0
            exports = {}
            for name in CLASSES:
                p = out / 'scripts' / Path(*name.split('.')).with_suffix('.as')
                assert p.is_file() and p.stat().st_size > 100
                exports[str(p.relative_to(out))] = sha(p)
            assert installation() == before
            assert all(sha(Path(p)) == h for p, h in inputs.items())
            evidence.write_text(json.dumps(dict(host_sha256=EXPECTED, inputs=inputs,
                installed=before, exports=exports, input_unchanged=True, installed_unchanged=True,
                air_started=False, gameplay_qualified=False, performance_qualified=False),
                ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            record.outcome = 'passed'
            record.note = 'Four requested classes exported; inputs unchanged; no gameplay qualification'
    except BaseException as error:
        if not evidence.exists():
            evidence.write_text(json.dumps(dict(error=str(error), exit_code=code,
                installed_unchanged=installation() == before, air_started=False),
                ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        raise
    print(out)


if __name__ == '__main__':
    main()
