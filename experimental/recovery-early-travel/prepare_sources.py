"""Future source assembly for formal prepare_recovery.py. No JVM/AIR/deploy.

Writes only a NEW direct experimental child, never the current integrated tree.
The exact recovery16 full source is retained except three overlays, one new
gate, and the caller's explicit version. No compiler/resources are copied.
"""
from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-16'
PIN='a1519b39f27b6c073186a4581234de9bad656592ec6c17bb4a3eb494ade5a31c'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def inventory(p):return {q.relative_to(p).as_posix():sha(q) for q in sorted(p.rglob('*.as'))}
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output',type=Path);ap.add_argument('--version',required=True);a=ap.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==ROOT/'experimental' and not out.exists()
    assert re.fullmatch(r'0\.2\.24-[a-z0-9-]+',a.version)
    frozen=read(HERE/'handoff.json')
    assert frozen['status']=='source-frozen-awaiting-native-qualification'
    assert all(sha(HERE/name)==digest for name,digest in frozen['files'].items())
    meta=read(BASE/'prepared.json');before=inventory(BASE/'src')
    assert meta['compiled'] and meta['source']==before and len(before)==89
    assert meta['sha256']==PIN and sha(BASE/'RConnectMod.swf')==PIN
    overlays=inventory(HERE/'src');assert set(overlays)=={'rconnect/core/'+x+'.as' for x in ('RoomSync','MapGeneration','Session','EarlyTravelGate')}
    inputs={str(BASE/'prepared.json'):sha(BASE/'prepared.json'),str(BASE/'integration.json'):sha(BASE/'integration.json'),
        str(HERE/'handoff.json'):sha(HERE/'handoff.json'),str(Path(__file__)):sha(Path(__file__))}
    for name in before:
        p=(HERE/'src'/name) if name in overlays else (BASE/'src'/name)
        data=p.read_bytes();inputs[str(p)]=sha(p)
        if name=='RConnectMod.as':
            text=data.decode('utf-8-sig');text,count=re.subn(r'VERSION:String\s*=\s*"0\.2\.24-recovery16"','VERSION:String = "'+a.version+'"',text)
            assert count==1;data=text.encode('utf-8')
        dest=out/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    for name in set(overlays)-set(before):
        p=HERE/'src'/name;inputs[str(p)]=sha(p);dest=out/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes())
    after=inventory(out/'src');assert len(after)==90
    changed={n for n in before if before[n]!=after[n]}
    assert changed=={'RConnectMod.as','rconnect/core/RoomSync.as','rconnect/core/MapGeneration.as','rconnect/core/Session.as'}
    assert inventory(BASE/'src')==before and all(sha(Path(p))==h for p,h in inputs.items())
    integration={'version':a.version,'baseline':'build/m52/recovery-16','baseline_manifest_sha256':sha(BASE/'prepared.json'),
        'ancestor_integration_sha256':sha(BASE/'integration.json'),'input_sources':inputs,
        'source':[{'path':n,'sha256':h} for n,h in after.items()],'static_errors':[],
        'changed':sorted(changed),'added':sorted(set(after)-set(before)),'diagnostic_only':True,
        'compiled':False,'runtime_tested':False,'requires_host':'ACC + frozen early World/Game overlay',
        'requires_external_contract':'sandy-travel-hold/1; absent contract uses original path'}
    (out/'integration.json').write_text(json.dumps(integration,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'source':str(out),'classes':len(after),'compiled':False,'AIR_started':False}))
if __name__=='__main__':main()
