import json, os, shutil, subprocess, sys, time, uuid
from pathlib import Path
RC = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RC / 'tools' / 'host_authority' / 'field2_driver'))
from run import Registration, read, save, sha, inside_build

WORK = RC / 'build/ab/b-field2-bench-20261025-01'
GAME = WORK / 'host'
CANDIDATE = Path(sys.argv[1]) if len(sys.argv) > 1 else RC / 'build/ab/b-smooth-04-build'
run_id = uuid.uuid4().hex[:12]
appid = 'pfe-modsettings-rconnect-b-airprobe2-' + run_id
OUT = inside_build(RC / ('build/ab/b-perfdiag-airprobe-default2-' + run_id))
OUT.mkdir(parents=True, exist_ok=False)
store = Path(os.environ['APPDATA']) / appid / 'Local Store'
store.mkdir(parents=True, exist_ok=True)
try:
    with Registration(owner='RConnect B / AIR launch probe 2', resource='game',
                      purpose='AIR default desktop launch probe', run_dir=OUT, evidence=OUT/'result.json', wait=300) as reg:
        reg.before_launch('host / ' + appid)
        shutil.copy2(CANDIDATE / 'RConnectMod.swf', GAME / 'mods/Rconnect/release/RConnectMod.swf')
        config = read(GAME / 'mods/Rconnect/release/config.txt')
        config.update(experimental=True, role='host', session=run_id, port=55998, autoGame=False,
                      land='rbl', probe=False, frameProfile=False)
        save(GAME / 'mods/Rconnect/release/config.txt', config)
        descriptor = GAME / ('airprobe2-' + run_id + '.xml')
        descriptor.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
                              '<id>' + appid + '</id><versionNumber>1.0</versionNumber><filename>probe</filename>'
                              '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width>'
                              '<height>650</height></initialWindow></application>', encoding='utf-8')
        log = (OUT / 'host.stdout.log').open('x', encoding='utf-8')
        cmd = [str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)]
        p = subprocess.Popen(cmd, cwd=str(GAME), stdout=log, stderr=log)
        reg.child(p.pid)
        print('pid', p.pid, flush=True)
        code = None
        for i in range(45):
            code = p.poll()
            if code is not None:
                print('exited after', i, 's code', code, hex(code & 0xffffffff), flush=True)
                break
            if i % 5 == 0:
                print('alive', i, 'store', store.is_dir(), flush=True)
            time.sleep(1)
        if p.poll() is None:
            print('alive after 45s, killing own process', flush=True)
            p.kill(); p.wait(timeout=20)
        log.close()
        result = dict(pid=p.pid, appid=appid, store=str(store), store_created=store.is_dir(),
                      exit_code=p.poll(), candidate=str(CANDIDATE), candidate_sha=sha(CANDIDATE / 'RConnectMod.swf'))
        save(OUT / 'result.json', result)
        print(json.dumps(result, ensure_ascii=False))
finally:
    if store.is_dir():
        print('store files:', sorted(x.name for x in store.iterdir()))
