"""Complete recovery14 + frozen wall surface bridge. Source only; no JVM/AIR."""
from pathlib import Path
import difflib,importlib.util,json,shutil

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
HELPER=ROOT/'experimental/recovery-wall-encode-buildsrc/prepare_sources.py'
spec=importlib.util.spec_from_file_location('wall_source_inventory',HELPER)
common=importlib.util.module_from_spec(spec);spec.loader.exec_module(common)
sha,read,save,inventory=common.sha,common.read,common.save,common.inventory
BASE=ROOT/'build/m52/recovery-14';OVERLAY=ROOT/'experimental/recovery-wall-surfaces'
BASE_SHA='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7'
HANDOFF_SHA='74fb4fa581be26f7f56710ab692c2158a1d65016c7cae6d16fa97356ff6fe0f1'
VERSION='0.2.24-recovery16'
FILES=['rconnect/game/WallImpactVisuals.as','rconnect/game/GameBridge.as','rconnect/game/WallSurfaceBridge.as']

def verify():
    integrated=read(HERE/'integration.json');actual=inventory(HERE/'src')
    assert actual=={r['path']:r['sha256'] for r in integrated['source']}
    for p,h in integrated['input_sources'].items():assert sha(Path(p))==h,p
    base=read(BASE/'prepared.json')['source']
    assert len(base)==88 and len(actual)==89
    assert all(p.endswith('.as') for p in actual)
    changed={p for p in set(base)|set(actual) if base.get(p)!=actual.get(p)}
    assert changed==set(FILES+['RConnectMod.as']),changed
    for name in FILES:assert sha(HERE/'src'/name)==sha(OVERLAY/'src'/name)
    old=(BASE/'src/RConnectMod.as').read_bytes();new=(HERE/'src/RConnectMod.as').read_bytes()
    assert old.count(b'0.2.24-recovery14')==1
    assert new==old.replace(b'0.2.24-recovery14',VERSION.encode('ascii'))
    assert sha(HERE/'ancestor-integration.json')==sha(BASE/'integration.json')
    for name,h in integrated['patches'].items():assert sha(HERE/name)==h
    assert not integrated['static_errors'] and integrated['version']==VERSION
    # In particular, recovery15's posture arithmetic is not an input.
    assert actual['rconnect/game/UnitPresentation.as']==base['rconnect/game/UnitPresentation.as']
    assert not any('recovery-15' in p or 'actor-pose' in p for p in integrated['input_sources'])
    assert not (HERE/'tools').exists() and not list(HERE.rglob('*.swf'))
    return dict(passed=True,base_files=88,output_files=89,unchanged_base_files=85,
        changed=sorted(changed),class_overlay_byte_exact=True,version_only_entry_change=True,
        UnitPresentation_unchanged=True,no_recovery15_input=True,formal_source_contract=True,
        JVMStarted=False,AIRStarted=False,compiled=False,native_game_tested=False,
        host_patch_required=True,host_patch_qualified=False,performance_qualified=False)

def main():
    assert not (HERE/'src').exists(),'Already frozen; use --verify instead of overwrite'
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    base=read(BASE/'prepared.json')
    assert base['version']=='0.2.24-recovery14' and base['compiled']
    assert inventory(BASE/'src')==base['source'] and len(base['source'])==88
    assert sha(BASE/'integration.json')==base['integration_sha256']
    assert sha(OVERLAY/'handoff.json')==HANDOFF_SHA
    handoff=read(OVERLAY/'handoff.json')
    for p,h in handoff['files'].items():assert sha(OVERLAY/p)==h,p
    assert handoff['compiled'] is False and handoff['air_started'] is False
    assert handoff['static_checks']==28 and handoff['component_expected']==54
    static=read(OVERLAY/'static-results.json')
    assert static['passed'] and static['count']==28 and all(r['passed'] for r in static['checks'])
    inputs=[BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'integration.json',
        OVERLAY/'handoff.json',OVERLAY/'inputs.json',OVERLAY/'component-inputs.json',
        OVERLAY/'static-results.json',OVERLAY/'native/fe/graph/Grafon.as',
        OVERLAY/'verify_readback.py',Path(__file__),HERE/'README.md',HELPER,
        ROOT/'tools/validation/prepare_recovery.py']
    inputs.extend(BASE/'src'/name for name in base['source'])
    inputs.extend(OVERLAY/'src'/name for name in FILES)
    pinned={str(p):sha(p) for p in inputs}
    shutil.copytree(BASE/'src',HERE/'src')
    for name in FILES:
        dest=HERE/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(OVERLAY/'src'/name,dest)
    entry=HERE/'src/RConnectMod.as';data=entry.read_bytes()
    assert data.count(b'0.2.24-recovery14')==1
    entry.write_bytes(data.replace(b'0.2.24-recovery14',VERSION.encode('ascii')))
    shutil.copyfile(BASE/'integration.json',HERE/'ancestor-integration.json')
    diff=[]
    for name in FILES:
        old=BASE/'src'/name;before=old.read_text(encoding='utf-8-sig') if old.exists() else ''
        after=(HERE/'src'/name).read_text(encoding='utf-8-sig')
        diff.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
            fromfile='recovery14/src/'+name,tofile='recovery16/src/'+name))
    (HERE/'wall-surfaces.patch').write_text(''.join(diff),encoding='utf-8')
    version_diff=difflib.unified_diff((BASE/'src/RConnectMod.as').read_text(encoding='utf-8-sig').splitlines(True),
        entry.read_text(encoding='utf-8-sig').splitlines(True),fromfile='recovery14/src/RConnectMod.as',tofile='recovery16/src/RConnectMod.as')
    (HERE/'version.patch').write_text(''.join(version_diff),encoding='utf-8')
    sources=inventory(HERE/'src')
    integration=dict(version=VERSION,compiled=False,runtime_tested=False,diagnostic_only=False,
        baseline='build/m52/recovery-14',baseline_sha256=BASE_SHA,
        baseline_manifest_sha256=sha(BASE/'prepared.json'),ancestor_integration_sha256=sha(BASE/'integration.json'),
        ancestor_integration_copy='ancestor-integration.json',input_sources=pinned,
        layers=[dict(name='large-scene-wall-surfaces',source='experimental/recovery-wall-surfaces/src',
            source_handoff_sha256=HANDOFF_SHA,
            files=[dict(path=n,ancestor_sha256=base['source'].get(n),sha256=sources[n],merge='exact frozen overlay bytes') for n in FILES])],
        version_change=dict(path='RConnectMod.as',old='0.2.24-recovery14',new=VERSION),
        patches={n:sha(HERE/n) for n in ('wall-surfaces.patch','version.patch')},
        component=dict(source=str(OVERLAY/'components'),input_manifest_sha256=sha(OVERLAY/'component-inputs.json'),
            assertions_expected=54,executed=False,passed=None,native_game_test=False,performance_qualified=False),
        host_dependency=dict(required=True,qualified=False,
            base_sha256='fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e',
            source=str(OVERLAY/'native/fe/graph/Grafon.as'),source_sha256=sha(OVERLAY/'native/fe/graph/Grafon.as'),
            required_field='fe.graph.Grafon.rconnectWallBridge',build_receipt=None),
        source=[dict(path=n,sha256=h) for n,h in sources.items()],static_errors=[],
        native_game_tested=False,performance_qualified=False,installed=False,
        limitations=['1200-cell checkpoint limit unchanged','Requires independently compiled and validated Grafon bridge; source does not qualify host'])
    save(HERE/'integration.json',integration)
    checks=verify();save(HERE/'static-checks.json',checks)
    print(json.dumps(checks,ensure_ascii=False));print('integration_sha256='+sha(HERE/'integration.json'))

if __name__=='__main__':
    import sys
    if '--verify' in sys.argv:print(json.dumps(verify(),ensure_ascii=False))
    else:main()
