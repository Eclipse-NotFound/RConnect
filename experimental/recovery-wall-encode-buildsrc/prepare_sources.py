"""Freeze complete recovery13 + two-file wall overlay; no JVM/AIR or installation."""
from pathlib import Path
import difflib,hashlib,json,shutil

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-13';OVERLAY=ROOT/'experimental/recovery-wall-encode'
COMPONENT=ROOT/'build/m52/recovery-wall-encode-component-01'
BASE_SHA='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
OVERLAY_HANDOFF='e36713037315ebd0a07f12ec889ca3b0083348e6c60ba22a80fdd2e5f9da16e9'
VERSION='0.2.24-recovery14'
FILES=['rconnect/game/WallImpactVisuals.as','rconnect/net/WallCellCodec.as']

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {q.relative_to(p).as_posix():sha(q) for q in sorted(p.rglob('*')) if q.is_file()}
def verify():
    integrated=read(HERE/'integration.json');actual=inventory(HERE/'src')
    assert actual=={r['path']:r['sha256'] for r in integrated['source']}
    for path,digest in integrated['input_sources'].items():assert sha(Path(path))==digest,path
    base=read(BASE/'prepared.json')['source']
    assert len(base)==87 and len(actual)==88
    changed={p for p in set(base)|set(actual) if base.get(p)!=actual.get(p)}
    assert changed==set(FILES+['RConnectMod.as']),changed
    for name in FILES:assert sha(HERE/'src'/name)==sha(OVERLAY/'src'/name)
    old=(BASE/'src/RConnectMod.as').read_bytes();new=(HERE/'src/RConnectMod.as').read_bytes()
    assert old.count(b'0.2.24-recovery13')==1
    assert new==old.replace(b'0.2.24-recovery13',VERSION.encode('ascii'))
    assert sha(HERE/'src/rconnect/net/RoomCodec.as')==base['rconnect/net/RoomCodec.as']
    assert not integrated['static_errors'] and integrated['version']==VERSION
    return dict(passed=True,base_files=87,output_files=88,unchanged_base_files=85,
                changed=sorted(changed),class_overlay_byte_exact=True,version_only_entry_change=True,
                RoomCodec_unchanged=True,JVMStarted=False,AIRStarted=False,compiled=False,
                native_game_tested=False,performance_qualified=False)

def main():
    assert not (HERE/'src').exists(),'Source snapshot already exists; verify it, do not overwrite'
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert sha(OVERLAY/'handoff.json')==OVERLAY_HANDOFF
    handoff=read(OVERLAY/'handoff.json')
    for p,h in handoff['files'].items():assert sha(OVERLAY/p)==h,p
    base=read(BASE/'prepared.json');assert base['version']=='0.2.24-recovery13'
    assert inventory(BASE/'src')==base['source'] and len(base['source'])==87
    assert sha(BASE/'integration.json')==base['integration_sha256']
    receipt=read(COMPONENT/'receipt.json');actual=read(COMPONENT/'component-result.json')
    assert receipt['passed'] and receipt['observed_checks']==49 and receipt['checks_failed']==0
    assert receipt['installation_unchanged'] and receipt['source_unchanged']
    assert len(actual['assertions'])==49 and all(r['passed'] for r in actual['assertions'])
    assert actual['passed'] and actual['failed']==0 and not actual['native_game_test']
    assert sha(COMPONENT/'Checks.swf')==receipt['component_sha256']
    intent=read(COMPONENT/'intent.json')
    assert intent['expected']==49
    for name,h in intent['sources'].items():
        assert sha(OVERLAY/'components'/name)==h and sha(COMPONENT/'src'/name)==h,name
    inputs=[BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'integration.json',OVERLAY/'handoff.json',
            COMPONENT/'receipt.json',COMPONENT/'component-result.json',COMPONENT/'intent.json',COMPONENT/'Checks.swf',
            Path(__file__),ROOT/'tools/validation/prepare_recovery.py']
    inputs.extend(BASE/'src'/name for name in base['source'])
    inputs.extend(OVERLAY/'src'/name for name in FILES)
    pinned={str(p):sha(p) for p in inputs}
    shutil.copytree(BASE/'src',HERE/'src')
    for name in FILES:
        p=HERE/'src'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(OVERLAY/'src'/name,p)
    entry=HERE/'src/RConnectMod.as';data=entry.read_bytes()
    assert data.count(b'0.2.24-recovery13')==1
    entry.write_bytes(data.replace(b'0.2.24-recovery13',VERSION.encode('ascii')))
    shutil.copyfile(BASE/'integration.json',HERE/'ancestor-integration.json')
    diff=[]
    for name in FILES:
        p=BASE/'src'/name;old=p.read_text(encoding='utf-8-sig') if p.exists() else ''
        new=(HERE/'src'/name).read_text(encoding='utf-8-sig')
        diff.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
            fromfile='recovery13/src/'+name,tofile='recovery14/src/'+name))
    (HERE/'wall-encode.patch').write_text(''.join(diff),encoding='utf-8')
    version_diff=difflib.unified_diff((BASE/'src/RConnectMod.as').read_text(encoding='utf-8-sig').splitlines(True),
        entry.read_text(encoding='utf-8-sig').splitlines(True),fromfile='recovery13/src/RConnectMod.as',tofile='recovery14/src/RConnectMod.as')
    (HERE/'version.patch').write_text(''.join(version_diff),encoding='utf-8')
    rows=actual['measurements']['abba']['blocks']
    assert len(rows)==8 and [r['side'] for r in rows]==['old','new','new','old']*2
    summary={}
    for side in ('old','new'):
        selected=[r for r in rows if r['side']==side]
        assert all(r['calls']==246 and r['coldDecode']['calls']==246 for r in selected)
        summary[side]=dict(encode_ms=[r['ms'] for r in selected],decode_ms=[r['coldDecode']['ms'] for r in selected])
        summary[side]['encode_mean_ms']=sum(summary[side]['encode_ms'])/4
        summary[side]['decode_mean_ms']=sum(summary[side]['decode_ms'])/4
    summary['component_only_reduction']=dict(
        encode=1-summary['new']['encode_mean_ms']/summary['old']['encode_mean_ms'],
        cold_decode=1-summary['new']['decode_mean_ms']/summary['old']['decode_mean_ms'])
    summary.update(qualifies_native_performance=False,historical_payloads=82,blocks=rows,
        source_result_sha256=sha(COMPONENT/'component-result.json'),
        natural=actual['measurements']['natural'],batches=actual['measurements']['batchSizes'])
    save(HERE/'component-review.json',summary)
    sources=inventory(HERE/'src')
    integration=dict(version=VERSION,compiled=False,runtime_tested=False,diagnostic_only=False,
        baseline='build/m52/recovery-13',baseline_sha256=BASE_SHA,
        baseline_manifest_sha256=sha(BASE/'prepared.json'),ancestor_integration_sha256=sha(BASE/'integration.json'),
        ancestor_integration_copy='ancestor-integration.json',input_sources=pinned,
        layers=[dict(name='wall-cell-encoding',source='experimental/recovery-wall-encode/src',
            source_handoff_sha256=OVERLAY_HANDOFF,
            files=[dict(path=n,ancestor_sha256=base['source'].get(n),sha256=sources[n],merge='exact overlay bytes') for n in FILES])],
        version_change=dict(path='RConnectMod.as',old='0.2.24-recovery13',new=VERSION),
        patches={n:sha(HERE/n) for n in ('wall-encode.patch','version.patch')},
        component=dict(directory=str(COMPONENT),receipt_sha256=sha(COMPONENT/'receipt.json'),
            assertions=49,failed=0,native_game_test=False,performance_qualified=False),
        source=[dict(path=n,sha256=h) for n,h in sources.items()],static_errors=[],
        native_game_tested=False,performance_qualified=False,installed=False)
    save(HERE/'integration.json',integration)
    checks=verify();save(HERE/'static-checks.json',checks)
    print(json.dumps(checks,ensure_ascii=False));print('integration_sha256='+sha(HERE/'integration.json'))

if __name__=='__main__':
    import sys
    if '--verify' in sys.argv:print(json.dumps(verify(),ensure_ascii=False))
    else:main()
