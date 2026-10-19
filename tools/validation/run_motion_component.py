"""Run one frozen, game-free AIR component on its own hidden desktop."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
HELPER = ROOT.parent / 'ModLoader/tools'
sys.path.insert(0, str(HELPER))
from air_test_process import HiddenProcess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate', type=Path, required=True)
    ap.add_argument('--label', required=True)
    args = ap.parse_args()
    candidate = (ROOT / args.candidate).resolve()
    assert candidate.parent == ROOT / 'build/m52'
    prepared = json.loads((candidate / 'prepared.json').read_text(encoding='utf-8-sig'))
    assert prepared['compile_exit'] == 0
    for name, digest in prepared['inputs'].items():
        assert sha(candidate / name) == digest, name
    binary = candidate / 'MotionTransportTestDoc.swf'
    assert sha(binary) == prepared['test_sha256']
    out = candidate / args.label
    assert out.parent == candidate and not out.exists(), out
    out.mkdir()
    shutil.copyfile(binary, out / binary.name)
    appid = 'rconnect-motion-component-' + uuid.uuid4().hex[:12]
    descriptor = out / 'application.xml'
    descriptor.write_text('<?xml version="1.0" encoding="utf-8"?>'
        '<application xmlns="http://ns.adobe.com/air/application/30.0">'
        '<id>' + appid + '</id><versionNumber>1.0.0</versionNumber><filename>MotionTransportTestDoc</filename>'
        '<initialWindow><content>MotionTransportTestDoc.swf</content><visible>false</visible>'
        '<width>100</width><height>100</height></initialWindow></application>', encoding='utf-8')
    installed = ROOT / 'release/RConnectMod.swf'
    before = sha(installed)
    command = [str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)]
    record = dict(appid=appid, candidate_manifest_sha256=sha(candidate / 'prepared.json'),
                  runner_sha256=sha(Path(__file__)), helper_sha256=sha(HELPER / 'air_test_process.py'),
                  test_sha256=sha(binary), command=command, descriptor_sha256=sha(descriptor),
                  installed_before=before, gameplay_qualified=False)
    def save():
        (out / 'process.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    save()
    with (out / 'adl.log').open('wb') as log:
        process = HiddenProcess(command, cwd=out, stdout=log, stderr=log)
        record.update(pid=process.pid, desktop=process.desktop)
        save()
        try:
            try:
                record['exit'] = process.wait(timeout=45)
            except subprocess.TimeoutExpired:
                process.kill()
                record['exit'] = process.wait(timeout=10)
                record['timeout'] = True
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            record['owned_process_exited'] = process.poll() is not None
            process.close()
    record['installed_after'] = sha(installed)
    result = Path(os.environ['APPDATA']) / appid / 'Local Store/result.json'
    if result.is_file():
        shutil.copyfile(result, out / 'result.json')
        record['result_sha256'] = sha(out / 'result.json')
    save()
    assert record['installed_after'] == before
    assert not record.get('timeout') and result.is_file(), record
    data = json.loads((out / 'result.json').read_text(encoding='utf-8-sig'))
    assert record['exit'] == (1 if data['fail'] else 0), record
    print(json.dumps(dict(result=str(out), passed=data['pass'], failed=data['fail'],
                          failures=[x for x in data['checks'] if not x['pass']],
                          metrics=data['metrics'], gameplay_qualified=False)))
    raise SystemExit(1 if data['fail'] else 0)


if __name__ == '__main__':
    main()
