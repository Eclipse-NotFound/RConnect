"""Read API visibility in a standalone, invisible AIR app. No game changes."""
import hashlib
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK


def main():
    out = (ROOT/(sys.argv[1] if len(sys.argv)>1 else 'build/m52/socket-api-02')).resolve()
    assert out.parent == ROOT/'build/m52'
    out.mkdir()  # retain previous evidence instead of reusing it
    main_version = int(sys.argv[2]) if len(sys.argv)>2 else 38
    assert main_version in (38, 51)
    for entry, name, version in [('SocketApiProbeDoc', 'Main', main_version), ('SocketApiHelper', 'Helper', 51)]:
        command = [str(JAVA), '-Xmx256m', '-jar', str(SDK/'lib/mxmlc.jar'),
                   '+configname=air', '+flexlib='+str(SDK/'frameworks'),
                   '-swf-version='+str(version), '-debug=false', '-optimize=true', '-omit-trace-statements=false',
                   '-output='+str(out/(name+'.swf')), str(ROOT/'tests/net-api'/(entry+'.as'))]
        result = subprocess.run(command, capture_output=True, env=dict(os.environ, AIR_HOME=str(SDK)))
        (out/(name+'-build.log')).write_bytes(result.stdout+result.stderr)
        result.check_returncode()
    rows = []
    for namespace in ('30.0', '51.0'):
        appid = 'rconnect-socket-api-'+uuid.uuid4().hex[:12]
        descriptor = out/('application-'+namespace+'.xml')
        descriptor.write_text('<?xml version="1.0" encoding="utf-8"?>\n'
                              '<application xmlns="http://ns.adobe.com/air/application/'+namespace+'">'
                              '<id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>SocketApiProbe</filename>'
                              '<initialWindow><content>Main.swf</content><visible>false</visible></initialWindow>'
                              '</application>', encoding='utf-8')
        process = subprocess.Popen([str(GAME/'adl64.exe'), '-runtime', str(GAME/'runtimes/air/win64'), str(descriptor)],
                                   cwd=out, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            log, _ = process.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            process.terminate()  # only this exact child process
            log, _ = process.communicate(timeout=10)
        (out/(namespace+'.log')).write_bytes(log)
        row = dict(namespace=namespace, appid=appid, pid=process.pid, exit=process.returncode,
                   log_sha256=hashlib.sha256(log).hexdigest(), output=log.decode('utf-8', errors='replace'))
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
    (out/'result.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
