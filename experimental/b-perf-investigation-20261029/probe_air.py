import json, os, sys, time, uuid
from pathlib import Path
RC = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RC / 'tools' / 'host_authority' / 'field2_driver'))
from run import Registration, HiddenProcess, read, save, sha, inside_build

WORK = RC / 'build/ab/b-field2-bench-20261025-01'
GAME = WORK / 'host'
CANDIDATE = Path(sys.argv[1]) if len(sys.argv) > 1 else RC / 'build/ab/b-smooth-04-build'
run_id = uuid.uuid4().hex[:12]
appid = 'pfe-modsettings-rconnect-b-airprobe-' + run_id
policy = sys.argv[2] if len(sys.argv) > 2 else 'test'
OUT = inside_build(RC / ('build/ab/b-perfdiag-airprobe-' + policy + '-' + run_id))
OUT.mkdir(parents=True, exist_ok=False)
store = Path(os.environ['APPDATA']) / appid / 'Local Store'
try:
    with Registration(owner='RConnect B / AIR launch probe', resource='game',
                      purpose='AIR launch probe', run_dir=OUT, evidence=OUT/'result.json', wait=300) as reg:
        reg.before_launch('host / ' + appid)
        # candidate + config
        swf = CANDIDATE / 'RConnectMod.swf'
        pre = OUT / 'candidate.sha256'
        pre.write_text(sha(swf), encoding='utf-8')
        import shutil
        shutil.copy2(swf, GAME / 'mods/Rconnect/release/RConnectMod.swf')
        config = read(GAME / 'mods/Rconnect/release/config.txt')
        config.update(experimental=True, role='host', session=run_id, port=55999, autoGame=False,
                      land='rbl', probe=False, frameProfile=False)
        save(GAME / 'mods/Rconnect/release/config.txt', config)
        descriptor = GAME / ('airprobe-' + run_id + '.xml')
        descriptor.write_text('<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0">'
                              '<id>' + appid + '</id><versionNumber>1.0</versionNumber><filename>probe</filename>'
                              '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width>'
                              '<height>650</height></initialWindow></application>', encoding='utf-8')
        log = (OUT / 'host.stdout.log').open('x', encoding='utf-8')
        p = HiddenProcess([str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(descriptor)],
                          cwd=GAME, stdout=log, stderr=log, resource_policy=policy)
        reg.child(p.pid)
        print('pid', p.pid, 'desktop', p.desktop, flush=True)
        created = False
        for i in range(90):
            code = p.poll()
            if store.is_dir():
                created = True
            if code is not None:
                print('exited after', i, 's code', code, flush=True)
                break
            if i % 10 == 0:
                print('alive', i, 'store', created, flush=True)
            time.sleep(1)
        if p.poll() is None:
            print('still alive after 90s; killing own process', flush=True)
            p.kill(); p.wait(timeout=20)
        p.close(); log.close()
        result = dict(pid=p.pid, desktop=p.desktop, appid=appid, store=str(store), store_created=store.is_dir(),
                      exit_code=p.poll(), candidate=str(CANDIDATE), candidate_sha=pre.read_text())
        save(OUT / 'result.json', result)
        print(json.dumps(result, ensure_ascii=False))
finally:
    if store.is_dir():
        print('store files:', sorted(x.name for x in store.iterdir()))
