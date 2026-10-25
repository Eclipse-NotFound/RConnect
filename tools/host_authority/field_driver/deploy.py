"""Narrow, backed-up update of the existing B playable package after exact-byte gates."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys
from run import ROOT, read, save, sha, verify_files

PLAYABLE=ROOT/'build/ab/b3-playable-190'
BUILD=ROOT/'build/ab/b190-field9-build'
BASE=ROOT/'build/ab/b190-startup2-build'
OUT=ROOT/'build/ab/b190-field3-deploy-20261025-01'
SUITE=ROOT/'build/ab/b-field-regression9-01'
ENEMIES=SUITE/'enemies/result.json'
ENEMY_BASELINE=ROOT/'build/ab/b-field-enemies-baseline-v8-01/result.json'
PERF=ROOT/'build/ab/b-field-performance-fixed9.json'
SMOKE=ROOT/'build/ab/b-field-installed-smoke-01/result.json'
SWF='game/mods/RConnect/release/RConnectMod.swf'
NAMES=[SWF,'README.txt','manual-input.json','playable-validation.json']
VERSION='B3-0.1-field3'

def relative(p):return p.relative_to(ROOT).as_posix()
def encoded(v):return json.dumps(v,ensure_ascii=False,indent=2).encode('utf-8')
def package():
    m=read(PLAYABLE/'manual-input.json');verify_files(PLAYABLE/'game',m['files'])
    if read(PLAYABLE/'game/mods/RConnect/release/config.txt')!=m['config'] or sha(PLAYABLE/'README.txt')!=m['readme_sha256']:raise ValueError('B package/config changed')
    for entry in m['launchers']:
        if sha(PLAYABLE/entry['descriptor'])!=entry['descriptor_sha256'] or sha(PLAYABLE/entry['launcher'])!=entry['launcher_sha256']:raise ValueError('B launcher changed')
    return m
def replace(name,data,expected):
    target=PLAYABLE/name
    if sha(target)!=expected:raise ValueError('Concurrent B edit: '+name)
    temp=target.with_name(target.name+'.field-tmp')
    with temp.open('xb') as stream:stream.write(data)
    if sha(target)!=expected:raise ValueError('Concurrent B edit before replacement: '+name)
    temp.replace(target);return sha(target)
def test(path,build):
    r=read(path)
    if not r.get('passed') or not r.get('runtime_unchanged') or r['candidate_sha256']!=build['candidate_sha256']:raise ValueError('Test did not pass exact bytes: '+str(path))
    for role,v in r['roles'].items():
        verify_files(path.parent,v['logs'])
        if not v['done'] or v['failed'] or v['fatal']:raise ValueError('Failed role '+role)
        rows=[json.loads(s) for s in (path.parent/(role+'.BStartupDriver.log')).read_text(encoding='utf-8-sig').splitlines()]
        boot=next(x['data'] for x in rows if x['kind']=='installed')
        if boot['source']!=build['source_id'] or boot['version']!=VERSION:raise ValueError('Different runtime source')
        if sum(x['kind']=='PASS' for x in rows)!=v['passed']:raise ValueError('Assertion count changed')
    manifest=package();actual={k.lower():v for k,v in r['runtime_files'].items()}
    for name,digest in manifest['files'].items():
        if name.lower() not in ('mods/loader-manifest.txt','mods/rconnect/release/rconnectmod.swf') and actual.get(name.lower())!=digest:raise ValueError('Test tuple differs: '+name)
    return dict(path=relative(path),sha256=sha(path),checks=sum(v['passed'] for v in r['roles'].values()))
def rollback(receipt):
    for name in NAMES:
        if sha(PLAYABLE/name) not in (receipt['before'][name],receipt['after'].get(name)):raise ValueError('Concurrent edit prevents rollback: '+name)
        if sha(OUT/'before'/name)!=receipt['before'][name]:raise ValueError('Backup changed')
    for name in NAMES:replace(name,(OUT/'before'/name).read_bytes(),sha(PLAYABLE/name))
    receipt['status']='rolled_back';save(OUT/'deployment.json',receipt);package()
def install():
    manifest=package();build=read(BUILD/'build-input.json');base=read(BASE/'build-input.json')
    verify_files(BUILD,build['sources']);verify_files(BASE,base['sources'])
    if sha(PLAYABLE/SWF)!=base['candidate_sha256'] or sha(BUILD/'RConnectMod.swf')!=build['candidate_sha256']:raise ValueError('Unexpected B version')
    changes=[name for name,value in build['sources'].items() if base['sources'].get(name)!=value]
    expected={'src/RConnectMod.as','src/authority/BuildInfo.as','src/authority/RoomTransfers.as','src/authority/ReplicaScene.as','src/authority/ClientReplica.as','src/authority/VisualPose.as','src/authority/NativeFields.as','src/authority/PlayerPointer.as','src/authority/SceneSnapshot.as','src/authority/SceneEffects.as'}
    if set(changes)!=expected:raise ValueError('Unexpected source changes')
    tests=[test(SUITE/s/'result.json',build) for s in ('boundary','hover')]
    tests.append(test(ENEMIES,build))
    control=read(ENEMY_BASELINE)
    if not control.get('passed') or control['candidate_sha256']!=base['candidate_sha256']:raise ValueError('Enemy fixture baseline did not pass')
    if control['preparation_sha256']!=read(ENEMIES)['preparation_sha256']:
        # v10 adds independent scalar-application checks before game startup.
        # Require the entire fixture/input/network code to remain byte-equivalent
        # after excluding only this explicit contract section and its sample type.
        driver_root=ROOT/'build/ab/b-field-20261025-01'
        def protocol(version):
            prepared=read(driver_root/('prepared-'+version+'.json'))
            path=driver_root/('driver-prepared-'+version)/'BStartupDriverMod.as'
            if sha(path)!=prepared['driver']:raise ValueError('Fixture source changed')
            s=path.read_text(encoding='utf-8')
            start=s.index('  private static function fieldsContract():void {')
            end=s.index('  /** Frozen B190 capture semantics',start)
            s=s[:start]+s[end:]
            return s.split(' class FieldAccessorSample {')[0].rstrip()
        if sha(driver_root/'prepared-v8.json')!=control['preparation_sha256'] or sha(driver_root/'prepared-v10.json')!=read(ENEMIES)['preparation_sha256'] or protocol('v8')!=protocol('v10'):
            raise ValueError('Enemy gameplay fixture differs from the passing baseline')
    perf=read(PERF)
    if perf['candidate_sha256']!=build['candidate_sha256'] or not perf['no_material_regression']:raise ValueError('Performance gate not satisfied')
    for v in perf['inputs'].values():
        if sha(ROOT/v['path'])!=v['sha256']:raise ValueError('Timing evidence changed')
    command="Get-CimInstance Win32_Process -Filter \"Name='adl64.exe'\" | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"
    check=subprocess.run(['powershell','-NoProfile','-Command',command],check=True,capture_output=True,text=True)
    processes=json.loads(check.stdout) if check.stdout.strip() else []
    if isinstance(processes,dict):processes=[processes]
    if any('b3-playable-190' in (p.get('CommandLine') or '').lower() for p in processes):raise ValueError('Player B is open; wait for user save/exit')
    OUT.mkdir();receipt=dict(status='backup',created=datetime.now(timezone.utc).isoformat(),candidate_sha256=build['candidate_sha256'],source_id=build['source_id'],tests=tests,performance=dict(path=relative(PERF),sha256=sha(PERF)),source_changes=changes,before={name:sha(PLAYABLE/name) for name in NAMES},after={},scope='B playable only; original launchers, config, saves and frozen native tuple retained',script_sha256=sha(__file__))
    shutil.copy2(__file__,OUT/'deploy-executed.py')
    for name in NAMES:
        dest=OUT/'before'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(PLAYABLE/name,dest)
        if sha(dest)!=receipt['before'][name]:raise ValueError('Backup mismatch')
    save(OUT/'deployment.json',receipt)
    readme=(PLAYABLE/'README.txt').read_text(encoding='utf-8-sig')
    readme=readme.replace('B190 启动修复 B3-0.1-startup2','B190 交互与出口修复 '+VERSION,1).replace(base['source_id'],build['source_id'],1)
    readme+='\n2026-10-25 交互与出口修复：关闭跟随后支持实际走出普通房间；加入侧恢复容器和掉落物原生提示。\n性能有局部优化，但密集场景仍可能明显卡顿；完整数据见随包验证记录。已有 B 窗口需保存退出后重新启动。\n'
    updated=json.loads(json.dumps(manifest));updated.update(source_id=build['source_id'],candidate_sha256=build['candidate_sha256'],candidate_manifest_sha256=sha(BUILD/'build-input.json'),parent_manifest=dict(path=relative(OUT/'before/manual-input.json'),sha256=receipt['before']['manual-input.json']),local_field_gate_complete=False)
    key=next(k for k in updated['files'] if k.lower()=='mods/rconnect/release/rconnectmod.swf');updated['files'][key]=build['candidate_sha256']
    validation=dict(experimental_only=True,candidate_ready_for_manual_testing=False,formal_release_gate_complete=False,local_field_gate_complete=False,candidate_sha256=build['candidate_sha256'],source_id=build['source_id'],field_tests=tests,performance=receipt['performance'],historical_validation=dict(path=relative(OUT/'before/playable-validation.json'),sha256=receipt['before']['playable-validation.json']),limitations=['Dense-scene performance remains limited; not claimed fully smooth.','Only changed behaviors and historical enemy visuals tested, not every B gameplay suite.','B195 remains unqualified; this build derives only from delivered startup2.'])
    try:
        receipt['after']['README.txt']=replace('README.txt',readme.encode('utf-8'),receipt['before']['README.txt']);updated['readme_sha256']=receipt['after']['README.txt']
        receipt['after'][SWF]=replace(SWF,(BUILD/'RConnectMod.swf').read_bytes(),receipt['before'][SWF])
        receipt['after']['manual-input.json']=replace('manual-input.json',encoded(updated),receipt['before']['manual-input.json'])
        validation['manual_manifest_sha256']=receipt['after']['manual-input.json']
        receipt['after']['playable-validation.json']=replace('playable-validation.json',encoded(validation),receipt['before']['playable-validation.json'])
        package();receipt['status']='installed_pending_smoke';save(OUT/'deployment.json',receipt)
    except Exception:rollback(receipt);raise
def finalize():
    receipt=read(OUT/'deployment.json');verify_files(PLAYABLE,receipt['after']);manifest=package()
    if receipt['status']!='installed_pending_smoke':raise ValueError('Not awaiting smoke')
    try:
        smoke=test(SMOKE,read(BUILD/'build-input.json'))
        if Path(read(SMOKE)['candidate_path']).resolve()!=(PLAYABLE/SWF).resolve():raise ValueError('Smoke did not use deployed file')
    except Exception:rollback(receipt);raise
    manifest['local_field_gate_complete']=True;receipt['after']['manual-input.json']=replace('manual-input.json',encoded(manifest),receipt['after']['manual-input.json'])
    validation=read(PLAYABLE/'playable-validation.json');validation.update(candidate_ready_for_manual_testing=True,local_field_gate_complete=True,deployment_smoke=smoke,manual_manifest_sha256=receipt['after']['manual-input.json'],rollback=relative(OUT/'deployment.json'))
    receipt['after']['playable-validation.json']=replace('playable-validation.json',encoded(validation),receipt['after']['playable-validation.json'])
    receipt.update(status='verified',deployment_smoke=smoke,finished=datetime.now(timezone.utc).isoformat());save(OUT/'deployment.json',receipt);package()
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('action',choices=['install','finalize','rollback']);a=ap.parse_args()
    if a.action=='install':install()
    elif a.action=='finalize':finalize()
    else:rollback(read(OUT/'deployment.json'))
    print(a.action+' completed',flush=True)
