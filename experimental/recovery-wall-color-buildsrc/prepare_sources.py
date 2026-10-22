"""Exact recovery16 + two native setter calls and validated LUT; source only.

Default prepares sources/components without integration.json. After the root
executes the 69-check component, --finalize binds that actual result for the
existing prepare_recovery.py. This script never launches JVM/AIR or deploys.
"""
import argparse
import difflib
import importlib.util
import json
import shutil
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
HELPERS=ROOT/'experimental/recovery-wall-encode-buildsrc/prepare_sources.py'
spec=importlib.util.spec_from_file_location('wall_color_source_inventory',HELPERS)
common=importlib.util.module_from_spec(spec);spec.loader.exec_module(common)
sha,read,save,inventory=common.sha,common.read,common.save,common.inventory
BASE=ROOT/'build/m52/recovery-16'
BASE_SHA='a1519b39f27b6c073186a4581234de9bad656592ec6c17bb4a3eb494ade5a31c'
OLD_COMPONENT=ROOT/'build/m52/recovery-wall-surfaces-component-01'
LUT_COMPONENT=ROOT/'build/m52/recovery-wall-color-component-02'
LUT=ROOT/'experimental/recovery-wall-color-lut/rconnect/game/NativeWallColor.as'
LUT_SHA='0f7160457f21d46759cc3b43d9defd17a8d921007521407365d906988dcfa842'
BRIDGE='rconnect/game/WallSurfaceBridge.as';COLOR='rconnect/game/NativeWallColor.as'
VERSION='0.2.24-recovery18';EXPECTED=69
ANCHOR=b'b.setPixel32(x,y,color);'
REPLACEMENT=b'b.setPixel32(x,y,NativeWallColor.setter(color));'


def receipt(directory,count,expected_sources=None):
    r=read(directory/'receipt.json');a=read(directory/'component-result.json');intent=read(directory/'intent.json')
    assert r['passed'] and r['compiled'] and r['air_started'] and r['exit_code']==0
    assert r['observed_checks']==count and r['checks_failed']==0
    assert r['installation_unchanged'] and r['source_unchanged']
    assert a['passed'] and a['failed']==0 and a['count']==count and len(a['assertions'])==count
    assert all(row['passed'] is True and row['label'] for row in a['assertions'])
    assert sha(directory/'Checks.swf')==r['component_sha256']
    assert intent['expected']==count and inventory(directory/'src')==intent['sources']
    if expected_sources is not None:assert intent['sources']==expected_sources
    return r,a,intent


def verify():
    p=read(HERE/'source-plan.json');base=read(BASE/'prepared.json')['source'];actual=inventory(HERE/'src')
    assert actual==p['source'] and len(base)==89 and len(actual)==90
    assert inventory(HERE/'components')==p['components']
    assert all(sha(Path(path))==digest for path,digest in p['input_sources'].items())
    assert actual[COLOR]==LUT_SHA
    assert (HERE/'src'/BRIDGE).read_bytes()==(BASE/'src'/BRIDGE).read_bytes().replace(ANCHOR,REPLACEMENT)
    assert (BASE/'src'/BRIDGE).read_bytes().count(ANCHOR)==2
    changed={n for n in set(base)|set(actual) if base.get(n)!=actual.get(n)}
    assert changed=={BRIDGE,COLOR,'RConnectMod.as'}
    assert (HERE/'src/RConnectMod.as').read_bytes()==(BASE/'src/RConnectMod.as').read_bytes().replace(b'0.2.24-recovery16',VERSION.encode())
    assert sum(base.get(n)==h for n,h in actual.items())==87
    for n in (BRIDGE,COLOR,'rconnect/game/WallImpactVisuals.as','rconnect/net/RoomCodec.as','rconnect/net/WallCellCodec.as'):
        assert sha(HERE/'components'/n)==actual[n]
    old=(OLD_COMPONENT/'src/WallSurfaceChecks.as').read_text(encoding='utf-8-sig')
    addon=(HERE/'color-checks.inc').read_text(encoding='utf-8')
    anchor='   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}'
    assert old.count(anchor)==1
    assert (HERE/'components/WallSurfaceChecks.as').read_text(encoding='utf-8')==old.replace(anchor,addon+anchor)
    for n,h in inventory(OLD_COMPONENT/'src').items():
        if n not in (BRIDGE,'WallSurfaceChecks.as'):assert sha(HERE/'components'/n)==h,n
    assert sha(HERE/'ancestor-integration.json')==sha(BASE/'integration.json')
    assert not list(HERE.rglob('*.swf')) and not (HERE/'native').exists()
    return dict(passed=True,baseline_files=89,output_files=90,unchanged_base_files=87,
        changed=sorted(changed),setPixel32_call_changes=2,original_component_checks=54,
        added_component_checks=15,expected_component_checks=EXPECTED,
        helper_exact_tested_bytes=True,wire_and_logic_unchanged=True,gutter_selection_unchanged=True,
        host_source_unchanged=True,jvm_started=False,air_started=False,performance_qualified=False)


def prepare():
    assert not (HERE/'src').exists() and not (HERE/'components').exists(),'Do not overwrite frozen source'
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA and sha(LUT)==LUT_SHA
    b=read(BASE/'prepared.json');assert b['compiled'] and b['version']=='0.2.24-recovery16'
    assert inventory(BASE/'src')==b['source'] and len(b['source'])==89
    assert sha(BASE/'integration.json')==b['integration_sha256']
    receipt(OLD_COMPONENT,54);receipt(LUT_COMPONENT,10)
    assert sha(LUT_COMPONENT/'src'/COLOR)==LUT_SHA
    for n in (BRIDGE,'rconnect/game/WallImpactVisuals.as','rconnect/net/RoomCodec.as','rconnect/net/WallCellCodec.as'):
        assert sha(OLD_COMPONENT/'src'/n)==b['source'][n],n
    inputs=[Path(__file__),HERE/'README.md',HERE/'color-checks.inc',HELPERS,LUT,
        BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'integration.json',
        ROOT/'tools/validation/run_recovery_component.py',ROOT/'tools/validation/prepare_recovery.py']
    inputs.extend(BASE/'src'/n for n in b['source'])
    for component in (OLD_COMPONENT,LUT_COMPONENT):
        inputs.extend(component/n for n in ('receipt.json','component-result.json','intent.json','Checks.swf'))
        inputs.extend(component/'src'/n for n in inventory(component/'src'))
    pinned={str(p):sha(p) for p in inputs}
    shutil.copytree(BASE/'src',HERE/'src');shutil.copytree(OLD_COMPONENT/'src',HERE/'components')
    bridge=HERE/'src'/BRIDGE;data=bridge.read_bytes();assert data.count(ANCHOR)==2
    bridge.write_bytes(data.replace(ANCHOR,REPLACEMENT));shutil.copyfile(LUT,HERE/'src'/COLOR)
    entry=HERE/'src/RConnectMod.as';data=entry.read_bytes();assert data.count(b'0.2.24-recovery16')==1
    entry.write_bytes(data.replace(b'0.2.24-recovery16',VERSION.encode()))
    for n in (BRIDGE,COLOR):shutil.copyfile(HERE/'src'/n,HERE/'components'/n)
    old=(OLD_COMPONENT/'src/WallSurfaceChecks.as').read_text(encoding='utf-8-sig')
    anchor='   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}'
    assert old.count(anchor)==1
    (HERE/'components/WallSurfaceChecks.as').write_text(old.replace(anchor,(HERE/'color-checks.inc').read_text(encoding='utf-8')+anchor),encoding='utf-8')
    shutil.copyfile(BASE/'integration.json',HERE/'ancestor-integration.json')
    for output,names in [('native-setters.patch',[BRIDGE,COLOR]),('version.patch',['RConnectMod.as'])]:
        lines=[]
        for name in names:
            previous=BASE/'src'/name
            before=previous.read_text(encoding='utf-8-sig') if previous.exists() else ''
            after=(HERE/'src'/name).read_text(encoding='utf-8-sig')
            lines.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='recovery16/src/'+name,tofile='recovery18/src/'+name))
        (HERE/output).write_text(''.join(lines),encoding='utf-8')
    save(HERE/'source-plan.json',dict(version=VERSION,baseline='build/m52/recovery-16',baseline_sha256=BASE_SHA,
        source=inventory(HERE/'src'),components=inventory(HERE/'components'),input_sources=pinned,
        expected_component_checks=EXPECTED,component_executed=False,integration_ready=False,
        compiled=False,air_started=False,installed=False,performance_qualified=False))
    save(HERE/'static-checks.json',verify())
    print(json.dumps(verify(),ensure_ascii=False))


def finalize(directory):
    verify();directory=(ROOT/directory).resolve()
    assert directory.parent==ROOT/'build/m52' and not (HERE/'integration.json').exists()
    r,a,intent=receipt(directory,EXPECTED,inventory(HERE/'components'))
    old=read(OLD_COMPONENT/'component-result.json')
    assert a['assertions'][:54]==old['assertions'],'Original 54 assertion results must remain unchanged'
    p=read(HERE/'source-plan.json');inputs=dict(p['input_sources'])
    for path in [HERE/'source-plan.json',HERE/'static-checks.json',directory/'receipt.json',directory/'component-result.json',directory/'intent.json',directory/'Checks.swf',*(directory/'src').rglob('*.as')]:
        inputs[str(path)]=sha(path)
    integration=dict(version=VERSION,compiled=False,runtime_tested=False,diagnostic_only=False,
        baseline=p['baseline'],baseline_sha256=BASE_SHA,baseline_manifest_sha256=sha(BASE/'prepared.json'),
        ancestor_integration_copy='ancestor-integration.json',ancestor_integration_sha256=sha(BASE/'integration.json'),
        source=[dict(path=n,sha256=h) for n,h in p['source'].items()],input_sources=inputs,
        layers=[dict(name='native-wall-color-roundtrip',files=[BRIDGE,COLOR],changes='Only two final bitmap setters; helper exact component02 LUT')],
        version_change=dict(path='RConnectMod.as',old='0.2.24-recovery16',new=VERSION),
        patches={n:sha(HERE/n) for n in ('native-setters.patch','version.patch')},
        component=dict(directory=str(directory),assertions=EXPECTED,passed=True,executed=True,sha256=r['component_sha256']),
        host_dependency=dict(unchanged_from_recovery16=True,required_sha256='acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd'),
        static_errors=[],native_game_tested=False,performance_qualified=False,installed=False,
        limitations=['Opaque mismatch root cause remains unresolved; strict driver04 must be rerun','No gutter capture-order change','Small components do not qualify gameplay or dense-scene performance'])
    save(HERE/'integration.json',integration)
    print('integration_sha256='+sha(HERE/'integration.json'))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify',action='store_true');p.add_argument('--finalize',type=Path)
    args=p.parse_args()
    if args.finalize:finalize(args.finalize)
    elif args.verify:print(json.dumps(verify(),ensure_ascii=False))
    else:prepare()
