"""AS/JSON-only recovery17 composition. Default verifies; --materialize creates once.

No compiler, AIR, deployment, binary copying or shared production writes.
"""
import argparse,hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-14';OVERLAY=ROOT/'experimental/recovery-terrain-capture'
COMPONENT=ROOT/'build/m52/recovery-terrain-capture-component-01'
REL='rconnect/game/TerrainSync.as';VERSION='0.2.24-recovery17'
PINS={
    BASE/'prepared.json':'cbc7d3dd962100d90865aa6b05dd85b61d0b794708dc97ccf46a38dc3aab8001',
    BASE/'integration.json':'82ebc2af60753b7af8f0cf492b3b717eddb8ca3a80252ee277ddb519b4ceb042',
    OVERLAY/'source-manifest.json':'224bd84a2f150681e713c6d8c6e4a67f739b8ba8ce9919814b294b5df7062f14',
    COMPONENT/'receipt.json':'4631c58b540449f75d3ced18a51b705d72f0bfbde343ed851127b7c16966ae71',
    COMPONENT/'component-result.json':'db60fc5e3953b82ddcbdea1fbf390674e17cdc2af7f9a9cb389bd7600973f1db',
    COMPONENT/'intent.json':'c8e831088dac012095fce9d624fa9804a0f364b35ffb3139836ef53207424c19',
}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def digest(raw):return hashlib.sha256(raw).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}
def encoded(value):return (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf-8')

def planned():
    for p,h in PINS.items():assert sha(p)==h,str(p)
    base=read(BASE/'prepared.json');receipt=read(COMPONENT/'receipt.json');result=read(COMPONENT/'component-result.json');intent=read(COMPONENT/'intent.json')
    assert base['candidate_sha256']=='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7'
    assert base['compiled'] and base['version']=='0.2.24-recovery14'
    actual=inventory(BASE/'src');assert actual==base['source'] and len(actual)==88
    assert all(name.endswith('.as') for name in actual)
    assert receipt['passed'] and receipt['compiled'] and receipt['air_started'] and receipt['exit_code']==0
    assert receipt['installation_unchanged'] and receipt['source_unchanged']
    assert receipt['observed_checks']==intent['expected']==154 and receipt['checks_failed']==0 and not receipt['failures']
    assert result['passed'] and result['failed']==0 and len(result['assertions'])==154
    assert all(row['passed'] is True for row in result['assertions'])
    assert not result['native_game'] and not result['performance_qualified']
    assert intent['sources']==inventory(COMPONENT/'src')==inventory(OVERLAY/'components')
    assert sha(OVERLAY/'src'/REL)==intent['sources'][REL]=='3bb4ac4a9ab4ca6a045d2376e3b18025d48db409bc6ad72cb62cdece02f5ebfa'
    overlay_manifest=read(OVERLAY/'source-manifest.json')
    assert all(sha(OVERLAY/name)==value for name,value in overlay_manifest['files'].items())
    source={n:(BASE/'src'/n).read_bytes() for n in actual}
    source[REL]=(OVERLAY/'src'/REL).read_bytes()
    old=b'0.2.24-recovery14';new=VERSION.encode();assert source['RConnectMod.as'].count(old)==1
    source['RConnectMod.as']=source['RConnectMod.as'].replace(old,new)
    rows=[dict(path=n,sha256=digest(raw)) for n,raw in sorted(source.items())]
    changed=[n for n,raw in source.items() if digest(raw)!=actual[n]]
    assert sorted(changed)==['RConnectMod.as',REL]
    assert source['RConnectMod.as'].replace(new,old)==(BASE/'src/RConnectMod.as').read_bytes()
    measurements=result['measurements']
    assert [(x['order'],x['ms'],x['candidate'],x['iterations'],x['cells'],x['unexpectedReports']) for x in measurements]==[
        ('A1',171,False,5,30000,0),('B1',113,True,5,30000,0),('B2',114,True,5,30000,0),('A2',199,False,5,30000,0)]
    inputs={str(p):h for p,h in PINS.items()}
    inputs.update({str(BASE/'src'/n):h for n,h in actual.items()})
    inputs[str(OVERLAY/'src'/REL)]=sha(OVERLAY/'src'/REL)
    inputs[str(Path(__file__).resolve())]=sha(__file__)
    report=ROOT/'experimental/recovery-input-frames-review/review.md';inputs[str(report)]=sha(report)
    integration=dict(version=VERSION,compiled=False,runtime_tested=False,native_game_tested=False,
        performance_qualified=False,installed=False,diagnostic_only=False,
        baseline='build/m52/recovery-14',baseline_sha256=base['candidate_sha256'],
        baseline_manifest_sha256=PINS[BASE/'prepared.json'],ancestor_integration_sha256=PINS[BASE/'integration.json'],
        input_sources=inputs,source=rows,static_errors=[],
        changed_files=sorted(changed),unchanged_files=86,
        layers=[dict(name='capture-only',path='experimental/recovery-terrain-capture/src',files=[REL])],
        version_change=dict(path='RConnectMod.as',before='0.2.24-recovery14',after=VERSION),
        component=dict(directory='build/m52/recovery-terrain-capture-component-01',
            receipt_sha256=PINS[COMPONENT/'receipt.json'],result_sha256=PINS[COMPONENT/'component-result.json'],
            intent_sha256=PINS[COMPONENT/'intent.json'],component_sha256=receipt['component_sha256'],
            assertions=154,failed=0,installation_unchanged=True,source_unchanged=True,
            measurements=measurements,native_game_tested=False,performance_qualified=False))
    handoff=dict(version=VERSION,source_directory=str(HERE.relative_to(ROOT)),source_files=88,
        baseline=integration['baseline'],baseline_candidate_sha256=base['candidate_sha256'],
        changed_files=sorted(changed),unchanged_files=86,
        no_recovery15_pose_or_recovery16_surface_changes=True,
        integration_sha256=digest(encoded(integration)),component=integration['component'],
        source={row['path']:row['sha256'] for row in rows},
        compiled=False,native_game_tested=False,performance_qualified=False,installed=False,
        command=['python','-B','-X','utf8','tools/validation/prepare_recovery.py','build/m52/recovery-17',
            '--source','experimental/recovery-terrain-capture-buildsrc','--version',VERSION,'--build','--registry-wait','900'])
    return source,encoded(integration),encoded(handoff)

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--materialize',action='store_true');args=ap.parse_args()
    source,integration,handoff=planned()
    if args.materialize:
        assert not (HERE/'src').exists() and not (HERE/'integration.json').exists() and not (HERE/'handoff.json').exists()
        for name,raw in source.items():
            dest=HERE/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
        (HERE/'integration.json').write_bytes(integration);(HERE/'handoff.json').write_bytes(handoff)
    assert inventory(HERE/'src')=={n:digest(raw) for n,raw in source.items()}
    assert (HERE/'integration.json').read_bytes()==integration and (HERE/'handoff.json').read_bytes()==handoff
    planned() # Verify frozen ancestors and component again after text writes.
    print(json.dumps(dict(verified=True,source_files=88,changed=['RConnectMod.as',REL],unchanged=86,
        integration_sha256=sha(HERE/'integration.json'),handoff_sha256=sha(HERE/'handoff.json'),
        compiled=False,native_game_tested=False)))
if __name__=='__main__':main()
