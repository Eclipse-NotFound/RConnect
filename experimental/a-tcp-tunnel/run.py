"""Reuse the registered isolated runner; replace only the guest endpoint."""
from pathlib import Path
import importlib.util,json,sys
from relay import Relay
RC=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('native_run',RC/'experimental/a-visual-round2/run.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
delay=0
if '--latency' in sys.argv:
    i=sys.argv.index('--latency');delay=float(sys.argv[i+1])/1000;del sys.argv[i:i+2]
prepare=native.prepare;relays=[];output=None
def through_relay(out,candidate,driver,port):
    global output
    output=out;roles=prepare(out,candidate,driver,port);r=Relay(port,delay);relays.append(r)
    for role,folder,desc,storage,appid in roles:
        if role!='join':continue
        path=folder/'mods/Rconnect/release/config.txt';config=json.loads(path.read_text('utf8'))
        config.update(hostIp='tcp://localhost:'+str(r.port),port=1,autoRole='');path.write_text(json.dumps(config),encoding='utf8')
    meta=json.loads((out/'input.json').read_text('utf8'))
    meta['tunnel']={'local':port,'external':r.port,'delay_each_direction_ms':delay*1000}
    for role,folder,desc,storage,appid in roles:meta['roles'][role]['config']=(folder/'mods/Rconnect/release/config.txt').read_text('utf8')
    native.save(out/'input.json',meta);return roles
native.prepare=through_relay
try:native.main()
finally:
    reports=[r.close() for r in relays]
    if output:
        result=json.loads((output/'result.json').read_text('utf8'))
        passed=result['passed'] and len(reports)==1 and all(r['stopped'] and not r['errors'] and r['external']!=r['target'] and min(r['counts'].values())>10000 for r in reports)
        native.save(output/'tunnel-result.json',dict(passed=passed,relay=reports))
        print(json.dumps(dict(tunnel_passed=passed,output=str(output))))
