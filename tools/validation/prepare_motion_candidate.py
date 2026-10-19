"""Create a separate gameplay candidate; preserve the room-fix integration tree.

Preparation is file-only. --compile builds in this candidate without installation.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from prepare_motion_transport import ROOT, BASE, JAVA, SDK, OVERLAY, sha, candidate, session_candidate


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--compile', action='store_true')
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52'
    if out.exists():
        assert args.compile and (out / 'prepared.json').is_file()
        record = json.loads((out / 'prepared.json').read_text(encoding='utf-8-sig'))
        assert not record['compiled'] and record['motion_candidate']
        for name, digest in {**record['source'], **record['inputs']}.items():
            assert sha(out / name) == digest, name
    else:
        baseline = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
        for name, digest in {**baseline['source'], **baseline['inputs']}.items():
            assert sha(BASE / name) == digest, name
        assert sha(BASE / 'RConnectMod.swf') == '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
        for directory in ['src', 'tools']:
            shutil.copytree(BASE / directory, out / directory)
        for name, transform in [('src/rconnect/net/HostServer.as',candidate),
                                ('src/rconnect/core/Session.as',session_candidate)]:
            original = (BASE / name).read_text(encoding='utf-8-sig')
            text = transform(original)
            overlay = ROOT / 'experimental/motion-regression' / name
            assert overlay.read_text(encoding='utf-8-sig') == text, overlay
            (out / name).write_text(text, encoding='utf-8')
        version = '0.2.23-motion1'
        entry = out / 'src/RConnectMod.as'
        text = entry.read_text(encoding='utf-8-sig')
        assert text.count('"0.2.23-coop-bundle2"') == 1
        entry.write_text(text.replace('"0.2.23-coop-bundle2"','"'+version+'"'), encoding='utf-8')
        record = dict(kind='isolated-coop-bundle', motion_candidate=True, version=version,
                      base_binary_sha256=sha(BASE / 'RConnectMod.swf'),
                      base_manifest_sha256=sha(BASE / 'prepared.json'),
                      held_features=['peer-port'], conflicts=[], compiled=False,
                      installed=False, gameplay_qualified=False, recipe_sha256=sha(Path(__file__)),
                      source={p.relative_to(out).as_posix():sha(p) for p in (out / 'src').rglob('*.as')},
                      inputs={p.relative_to(out).as_posix():sha(p) for p in (out / 'tools').rglob('*') if p.is_file()})
    manifest = out / 'prepared.json'
    def save():
        manifest.write_text(json.dumps(record, indent=2), encoding='utf-8')
    save()
    if args.compile:
        assert not (out / 'compile.log').exists()
        command = [sys.executable, '-B', '-X', 'utf8', str(out / 'tools/build_mod.py'),
                   '--java', str(JAVA), '--amxmlc', str(SDK / 'bin/amxmlc.bat'),
                   '--output', str(out / 'RConnectMod.swf')]
        with (out / 'compile.log').open('w',encoding='utf-8') as log:
            result = subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,AIR_HOME=str(SDK)))
        record.update(compile_exit=result.returncode,compile_log_sha256=sha(out / 'compile.log'))
        if result.returncode == 0:
            record.update(compiled=True,sha256=sha(out / 'RConnectMod.swf'),candidate_sha256=sha(out / 'RConnectMod.swf'))
        save()
        if result.returncode:
            raise SystemExit(result.returncode)
    print(json.dumps(dict(output=str(out),version=record['version'],compiled=record['compiled'],installed=False)))


if __name__=='__main__':
    main()
