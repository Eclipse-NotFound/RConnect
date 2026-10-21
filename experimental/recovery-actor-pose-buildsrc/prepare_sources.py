"""Reuse the reviewed source-freezing recipe for exact recovery14 + one tested overlay.

Text/files only; compilation remains tools/validation/prepare_recovery.py.
"""
from pathlib import Path
import difflib
import importlib.util
import json
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
HELPER=ROOT/'experimental/recovery-wall-encode-buildsrc/prepare_sources.py'
spec=importlib.util.spec_from_file_location('reviewed_source_freeze',HELPER)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
sha,read,save,inventory=shared.sha,shared.read,shared.save,shared.inventory
BASE=ROOT/'build/m52/recovery-14'
OVERLAY=ROOT/'experimental/recovery-actor-pose-fast'
COMPONENT=ROOT/'build/m52/recovery-actor-pose-fast-component-01'
BASE_SHA='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7'
OVERLAY_HANDOFF='badd506ca02e359941065036bc8dbddeed38a8ba4a186b73add25a355427351a'
COMPONENT_SHA='0316e8993b4c0b9ad0405bca542e5d36d48997a1b9bc33ee9663a60f0c753a2d'
NAME='rconnect/game/UnitPresentation.as'
VERSION='0.2.24-recovery15'


def verify():
    integrated=read(HERE/'integration.json');actual=inventory(HERE/'src')
    assert actual=={r['path']:r['sha256'] for r in integrated['source']}
    for path,digest in integrated['input_sources'].items():assert sha(Path(path))==digest,path
    base=read(BASE/'prepared.json')['source']
    assert len(base)==len(actual)==88
    changed={p for p in set(base)|set(actual) if base.get(p)!=actual.get(p)}
    assert changed=={NAME,'RConnectMod.as'},changed
    assert sha(HERE/'src'/NAME)==sha(OVERLAY/'src'/NAME)
    old=(BASE/'src/RConnectMod.as').read_bytes();new=(HERE/'src/RConnectMod.as').read_bytes()
    assert old.count(b'0.2.24-recovery14')==1
    assert new==old.replace(b'0.2.24-recovery14',VERSION.encode('ascii'))
    assert (HERE/'ancestor-integration.json').read_bytes()==(BASE/'integration.json').read_bytes()
    for path,digest in integrated['patches'].items():assert sha(HERE/path)==digest,path
    assert not integrated['static_errors'] and integrated['version']==VERSION
    return dict(passed=True,base_files=88,output_files=88,unchanged_base_files=86,
                changed=sorted(changed),class_overlay_byte_exact=True,version_only_entry_change=True,
                component_assertions=54,component_failed=0,JVMStarted=False,AIRStarted=False,
                compiled=False,native_game_tested=False,performance_qualified=False)


def main():
    assert not (HERE/'src').exists(),'Source snapshot already exists; use --verify'
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert sha(OVERLAY/'handoff.json')==OVERLAY_HANDOFF
    for path,digest in read(OVERLAY/'handoff.json')['files'].items():assert sha(OVERLAY/path)==digest,path
    overlay_spec=importlib.util.spec_from_file_location('actor_pose_overlay',OVERLAY/'prepare.py')
    overlay=importlib.util.module_from_spec(overlay_spec);overlay_spec.loader.exec_module(overlay)
    assert overlay.verify()['verified']
    base=read(BASE/'prepared.json')
    assert base['version']=='0.2.24-recovery14'
    assert inventory(BASE/'src')==base['source'] and len(base['source'])==88
    assert sha(BASE/'integration.json')==base['integration_sha256']
    receipt=read(COMPONENT/'receipt.json');raw=read(COMPONENT/'component-result.json')
    assert receipt['passed'] and receipt['observed_checks']==54 and receipt['checks_failed']==0
    assert receipt['installation_unchanged'] and receipt['source_unchanged'] and receipt['exit_code']==0
    assert len(raw['assertions'])==54 and all(r['passed'] is True for r in raw['assertions'])
    assert raw['passed'] is True and raw['failed']==0 and raw['native_game_loaded'] is False
    assert sha(COMPONENT/'Checks.swf')==receipt['component_sha256']==COMPONENT_SHA
    intent=read(COMPONENT/'intent.json');assert intent['expected']==54
    assert inventory(OVERLAY/'components')==intent['sources']==inventory(COMPONENT/'src')
    inputs=[BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'integration.json',OVERLAY/'handoff.json',
            OVERLAY/'inputs.json',OVERLAY/'prepare.py',COMPONENT/'receipt.json',COMPONENT/'component-result.json',
            COMPONENT/'intent.json',COMPONENT/'Checks.swf',HELPER,Path(__file__),ROOT/'tools/validation/prepare_recovery.py']
    inputs.extend(BASE/'src'/name for name in base['source'])
    inputs.extend(COMPONENT/'src'/name for name in intent['sources'])
    inputs.append(OVERLAY/'src'/NAME)
    pinned={str(p):sha(p) for p in inputs}
    shutil.copytree(BASE/'src',HERE/'src')
    shutil.copyfile(OVERLAY/'src'/NAME,HERE/'src'/NAME)
    entry=HERE/'src/RConnectMod.as';data=entry.read_bytes()
    assert data.count(b'0.2.24-recovery14')==1
    entry.write_bytes(data.replace(b'0.2.24-recovery14',VERSION.encode('ascii')))
    shutil.copyfile(BASE/'integration.json',HERE/'ancestor-integration.json')
    for name,target in [(NAME,'actor-pose.patch'),('RConnectMod.as','version.patch')]:
        diff=difflib.unified_diff((BASE/'src'/name).read_text(encoding='utf-8-sig').splitlines(True),
              (HERE/'src'/name).read_text(encoding='utf-8-sig').splitlines(True),
              fromfile='recovery14/src/'+name,tofile='recovery15/src/'+name)
        (HERE/target).write_text(''.join(diff),encoding='utf-8')
    review=dict(directory=str(COMPONENT),assertions=54,failed=0,component_sha256=COMPONENT_SHA,
                receipt_sha256=sha(COMPONENT/'receipt.json'),result_sha256=sha(COMPONENT/'component-result.json'),
                original_inputs_sha256=sha(COMPONENT/'intent.json'),installation_unchanged=True,source_unchanged=True,
                full_production_classes_compared=True,clock_boundary_controlled=raw['clock_boundary_controlled'],
                native_game_loaded=False,real_clip_resource_playback_tested=raw['real_clip_resource_playback_tested'],
                native_game_qualified=False,performance_qualified=False,
                assertion_labels=[r['label'] for r in raw['assertions']])
    save(HERE/'component-review.json',review)
    sources=inventory(HERE/'src')
    integration=dict(version=VERSION,compiled=False,runtime_tested=False,diagnostic_only=False,
        baseline='build/m52/recovery-14',baseline_sha256=BASE_SHA,
        baseline_manifest_sha256=sha(BASE/'prepared.json'),ancestor_integration_sha256=sha(BASE/'integration.json'),
        ancestor_integration_copy='ancestor-integration.json',input_sources=pinned,
        layers=[dict(name='actor-pose-fallback-elimination',source='experimental/recovery-actor-pose-fast/src',
            source_handoff_sha256=OVERLAY_HANDOFF,
            files=[dict(path=NAME,ancestor_sha256=base['source'][NAME],sha256=sources[NAME],merge='exact tested overlay bytes')])],
        version_change=dict(path='RConnectMod.as',old='0.2.24-recovery14',new=VERSION),
        patches={name:sha(HERE/name) for name in ('actor-pose.patch','version.patch')},
        component=review,source=[dict(path=name,sha256=digest) for name,digest in sources.items()],
        static_errors=[],native_game_tested=False,performance_qualified=False,installed=False)
    save(HERE/'integration.json',integration)
    checks=verify();save(HERE/'static-checks.json',checks)
    print(json.dumps(checks,ensure_ascii=False));print('integration_sha256='+sha(HERE/'integration.json'))


if __name__=='__main__':
    if '--verify' in sys.argv:print(json.dumps(verify(),ensure_ascii=False))
    else:main()
