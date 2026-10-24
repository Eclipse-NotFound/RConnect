"""Update only the existing B190 playable package, preserving its profiles and tuple."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import ROOT, read, save, sha, verify_files

PLAYABLE = ROOT/'build/ab/b3-playable-190'
BUILD = ROOT/'build/ab/b190-startup2-build'
OUT = ROOT/'build/ab/b190-startup2-deploy-20261025-01'
SWF = 'game/mods/RConnect/release/RConnectMod.swf'
NAMES = [SWF, 'README.txt', 'manual-input.json', 'playable-validation.json']
ORIGINAL = '5c3a57f27c0f4e0293a1b3ed2a6483e7ab724ae5ab91944002f43150d80132ef'
CANDIDATE = '2c536b5d2204b0acb0d69b025beff4cca7036c08260fda6a205ecb2190eb259b'
SOURCE = 'a8d1148646d86a2088d0ce1ea1672bce9e588b6221e2230c0429e1360b07aa3f'
TESTS = ['startup-v2-host-cancel-20261025-01', 'startup-v2-host-bind-failure-20261025-01',
         'startup-v2-join-refused-20261025-01', 'startup-v2-pair-20261025-03']
SMOKE = ROOT/'build/ab/startup-installed-pair-20261025-01/result.json'


def relative(path):
    return str(path.relative_to(ROOT)).replace('\\', '/')


def verified_test(path):
    data = read(path)
    if not data.get('passed') or not data.get('runtime_unchanged') or data['candidate_sha256'] != CANDIDATE:
        raise ValueError('Unqualified test: '+str(path))
    for role, entry in data['roles'].items():
        if not entry['done'] or entry['failed'] or entry['fatal']:
            raise ValueError('Failed role: '+role)
        verify_files(path.parent, entry['logs'])
        events = [json.loads(line) for line in (path.parent/(role+'.BStartupDriver.log')).read_text(encoding='utf-8-sig').splitlines()]
        installed = next(e['data'] for e in events if e['kind']=='installed')
        if installed['source'] != SOURCE or installed['version'] != 'B3-0.1-startup2':
            raise ValueError('Different runtime version')
        if sum(e['kind']=='PASS' for e in events)!=entry['passed']:
            raise ValueError('Changed assertion count')
    # All original game assets must match; only the external driver loader/config differ.
    manifest = read(PLAYABLE/'manual-input.json')
    test_files = {k.lower():v for k,v in data['runtime_files'].items()}
    for name,digest in manifest['files'].items():
        if name.lower() in ('mods/loader-manifest.txt','mods/rconnect/release/rconnectmod.swf'):
            continue
        if test_files.get(name.lower()) != digest:
            raise ValueError('Test tuple differs: '+name)
    return dict(path=relative(path), sha256=sha(path), checks=sum(e['passed'] for e in data['roles'].values()))


def verify_package():
    data=read(PLAYABLE/'manual-input.json')
    verify_files(PLAYABLE/'game',data['files'])
    if read(PLAYABLE/'game/mods/RConnect/release/config.txt')!=data['config']:
        raise ValueError('B configuration changed')
    if sha(PLAYABLE/'README.txt')!=data['readme_sha256']:
        raise ValueError('B README changed')
    for entry in data['launchers']:
        if sha(PLAYABLE/entry['descriptor'])!=entry['descriptor_sha256'] or sha(PLAYABLE/entry['launcher'])!=entry['launcher_sha256']:
            raise ValueError('B player launcher changed')
    return data


def replace_checked(name, content, expected):
    target=PLAYABLE/name
    if sha(target)!=expected:
        raise ValueError('Concurrent package edit: '+name)
    temporary=target.with_name(target.name+'.startup2-tmp')
    with temporary.open('xb') as output:
        output.write(content)
    if sha(target)!=expected:
        raise ValueError('Concurrent edit before replacement: '+name)
    temporary.replace(target)
    return sha(target)


def encoded(value):
    return json.dumps(value,ensure_ascii=False,indent=2).encode('utf-8')


def rollback(receipt):
    for name in NAMES:
        if sha(PLAYABLE/name) not in (receipt['before'][name],receipt['after'].get(name)):
            raise ValueError('Rollback blocked by concurrent edit: '+name)
    for name in NAMES:
        backup=OUT/'before'/name
        if sha(backup)!=receipt['before'][name]:raise ValueError('Backup changed: '+name)
        replace_checked(name,backup.read_bytes(),sha(PLAYABLE/name))
    receipt['status']='rolled_back';save(OUT/'deployment.json',receipt)
    verify_package()


def install():
    manifest=verify_package()
    if sha(PLAYABLE/SWF)!=ORIGINAL:raise ValueError('Expected original B190')
    build=read(BUILD/'build-input.json');verify_files(BUILD,build['sources'])
    if sha(BUILD/'RConnectMod.swf')!=CANDIDATE or build['source_id']!=SOURCE or build['candidate_sha256']!=CANDIDATE:
        raise ValueError('Candidate changed')
    base=read(ROOT/'build/ab/b3-build-190/build-input.json')
    changed=[name for name,digest in build['sources'].items() if base['sources'].get(name)!=digest]
    if set(changed)!={'src/RConnectMod.as','src/authority/PlainData.as','src/authority/BuildInfo.as'}:
        raise ValueError('Unexpected changes beyond startup repair')
    tests=[verified_test(ROOT/'build/ab'/name/'result.json') for name in TESTS]
    OUT.mkdir()
    receipt=dict(status='backup',created=datetime.now(timezone.utc).isoformat(),candidate_sha256=CANDIDATE,
        source_id=SOURCE,tests=tests,source_changes=changed,before={name:sha(PLAYABLE/name) for name in NAMES},after={},
        script_sha256=sha(__file__),scope='Existing experimental B190 package only; player IDs and game tuple preserved')
    shutil.copy2(__file__,OUT/'deploy-executed.py')
    for name in NAMES:
        target=OUT/'before'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(PLAYABLE/name,target)
        if sha(target)!=receipt['before'][name]:raise ValueError('Backup mismatch')
    save(OUT/'deployment.json',receipt)
    readme=(PLAYABLE/'README.txt').read_text(encoding='utf-8-sig')
    readme=readme.replace('RConnect B 独立实验版 · b3-build-190','RConnect B 独立实验版 · B190 启动修复 B3-0.1-startup2',1)
    readme=readme.replace(base['source_id'],SOURCE,1)
    readme+='\n2026-10-25 启动修复：支持较大的旧旅程备份；取消建房或连接失败后，重新连接不再遗留 TDFC 占用。\n'
    readme+='仍使用上面的两个启动器和原有 B 存档。本次只修启动与退出流程，密集战斗性能沿用 B190 的已知限制。\n'
    updated=json.loads(json.dumps(manifest))
    updated.update(source_id=SOURCE,candidate_sha256=CANDIDATE,script_sha256=sha(__file__),
        candidate_manifest_sha256=sha(BUILD/'build-input.json'),
        parent_manifest=dict(path=relative(OUT/'before/manual-input.json'),sha256=receipt['before']['manual-input.json']),
        local_startup_repair_gate_complete=False)
    updated['files'][SWF.removeprefix('game/')]=CANDIDATE
    validation=dict(experimental_only=True,mode='B190 narrow startup/save repair; separate B launchers',
        candidate_ready_for_manual_testing=False,formal_release_gate_complete=False,local_startup_repair_gate_complete=False,
        source_id=SOURCE,candidate_sha256=CANDIDATE,startup_tests=tests,
        historical_base_validation=dict(path=relative(OUT/'before/playable-validation.json'),sha256=receipt['before']['playable-validation.json']),
        limitations=['Full historical B190 gameplay/performance suite was not rerun for these new bytes.',
                    'This startup repair does not qualify B195 or resolve the known B190 dense-scene performance limits.'])
    try:
        receipt['after']['README.txt']=replace_checked('README.txt',readme.encode('utf-8'),receipt['before']['README.txt'])
        updated['readme_sha256']=receipt['after']['README.txt']
        receipt['after'][SWF]=replace_checked(SWF,(BUILD/'RConnectMod.swf').read_bytes(),receipt['before'][SWF])
        receipt['after']['manual-input.json']=replace_checked('manual-input.json',encoded(updated),receipt['before']['manual-input.json'])
        validation['manual_manifest_sha256']=receipt['after']['manual-input.json']
        receipt['after']['playable-validation.json']=replace_checked('playable-validation.json',encoded(validation),receipt['before']['playable-validation.json'])
        verify_package()
        receipt['status']='installed_pending_smoke';save(OUT/'deployment.json',receipt)
    except Exception:
        rollback(receipt)
        raise
    print(json.dumps(receipt,ensure_ascii=False))


def finalize():
    receipt=read(OUT/'deployment.json')
    if receipt['status']!='installed_pending_smoke':raise ValueError('Not awaiting smoke')
    verify_files(PLAYABLE,receipt['after']);manifest=verify_package()
    try:
        smoke=verified_test(SMOKE)
        if Path(read(SMOKE)['candidate_path']).resolve()!=(PLAYABLE/SWF).resolve():
            raise ValueError('Smoke did not use the deployed file')
    except Exception:
        rollback(receipt)
        raise
    manifest['local_startup_repair_gate_complete']=True
    receipt['after']['manual-input.json']=replace_checked('manual-input.json',encoded(manifest),receipt['after']['manual-input.json'])
    validation=read(PLAYABLE/'playable-validation.json')
    validation.update(candidate_ready_for_manual_testing=True,local_startup_repair_gate_complete=True,
        deployment_smoke=smoke,complete_tuple_verified=True,manual_manifest_sha256=receipt['after']['manual-input.json'],
        rollback='Save and exit B; restore the four backed-up package files listed in '+relative(OUT/'deployment.json'))
    receipt['after']['playable-validation.json']=replace_checked('playable-validation.json',encoded(validation),receipt['after']['playable-validation.json'])
    receipt.update(status='verified',deployment_smoke=smoke,finished=datetime.now(timezone.utc).isoformat())
    save(OUT/'deployment.json',receipt);verify_package()
    print(json.dumps(receipt,ensure_ascii=False))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['install','finalize','rollback']);args=parser.parse_args()
    if args.action=='install':install()
    elif args.action=='finalize':finalize()
    else:rollback(read(OUT/'deployment.json'))
