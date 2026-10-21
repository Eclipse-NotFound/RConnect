"""Repair only the paired component's two accidentally expanded dependencies.

The original control, failed component and passed seed fixture are read-only.
This script generates source only; it never starts a compiler or AIR.
"""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
CONTROL=ROOT/'experimental/recovery-seed-raster-control'
PASSED=ROOT/'build/m52/recovery-seed-first-raster-room-01'
FAILED=ROOT/'build/m52/recovery-seed-gate-on-component-01'
BASE=ROOT/'build/m52/recovery-13'
PIN='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
REPAIRS=('rconnect/core/TravelGuard.as','rconnect/core/TravelPlacement.as')


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def text(path):return path.read_text(encoding='utf-8-sig')
def files(path):return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*.as'))}
def save(name,value):
    path=HERE/name;path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(value,encoding='utf-8',newline='\n')


def verify_sources():
    manifest=read(CONTROL/'control-manifest.json')
    assert all(sha(CONTROL/p)==h for p,h in manifest['files'].items())
    assert sha(BASE/'RConnectMod.swf')==PIN
    good=read(PASSED/'receipt.json');intent=read(PASSED/'intent.json')
    assert good['passed'] and good['compiled'] and good['observed_checks']==109 and good['checks_failed']==0
    assert good['source_unchanged'] and good['installation_unchanged']
    assert files(PASSED/'src')==intent['sources']
    assert sha(PASSED/'Checks.swf')==good['component_sha256']
    bad=read(FAILED/'receipt.json')
    assert not bad['compiled'] and not bad['air_started'] and not bad['passed']
    assert files(FAILED/'src')==files(CONTROL/'components/on')
    return good,bad


def main():
    good,bad=verify_sources()
    patches=[];origins={};changes={}
    for mode in ('on','off'):
        previous=CONTROL/'components'/mode
        for path in sorted(previous.rglob('*.as')):
            rel=path.relative_to(previous).as_posix()
            source=PASSED/'src'/rel if rel in REPAIRS else path
            save('components/'+mode+'/'+rel,text(source))
            origins[mode+'/'+rel]=dict(path=str(source.relative_to(ROOT)),sha256=sha(source),
                boundary='original tested fixture, not a native implementation' if rel in REPAIRS else 'unchanged paired component source')
            if rel in REPAIRS:
                patches.append(''.join(difflib.unified_diff(text(path).splitlines(True),text(source).splitlines(True),
                    fromfile='frozen-control/'+mode+'/'+rel,tofile='fixed-component/'+mode+'/'+rel)))
        altered=[p for p,h in files(previous).items() if files(HERE/'components'/mode)[p]!=h]
        assert sorted(altered)==sorted(REPAIRS)
        changes[mode]=altered
    # Audit all inherited dependencies, rather than only the reported missing type.
    dependency_audit=[]
    for path in sorted((PASSED/'src').rglob('*.as')):
        rel=path.relative_to(PASSED/'src').as_posix()
        current=CONTROL/'components/on'/rel
        production=BASE/'src'/rel
        dependency_audit.append(dict(path=rel,passed_source_sha256=sha(path),control_source_sha256=sha(current),
            identical_to_passed=sha(path)==sha(current),
            control_is_production=production.is_file() and sha(production)==sha(current),
            fix='restore original fixture' if rel in REPAIRS else
                'retain intentional shared on/off cases' if rel=='NativeTravelRoomChecks.as' else 'unchanged'))
    save('component-fix.patch',''.join(patches))
    verify_sources()
    save('integration.json',json.dumps(dict(
        base='build/m52/recovery-13',base_sha256=PIN,original_control_manifest_sha256=sha(CONTROL/'control-manifest.json'),
        passed_fixture=dict(path=str(PASSED.relative_to(ROOT)),receipt_sha256=sha(PASSED/'receipt.json'),
            intent_sha256=sha(PASSED/'intent.json'),component_sha256=good['component_sha256'],checks=109),
        preserved_failure=dict(path=str(FAILED.relative_to(ROOT)),receipt_sha256=sha(FAILED/'receipt.json'),
            compile_log_sha256=sha(FAILED/'compile.log'),compiled=bad['compiled'],air_started=bad['air_started']),
        repairs=list(REPAIRS),changes=changes,origins=origins,dependency_audit=dependency_audit,
        expected_checks_each=109,tests_changed=False,production_changed=False,driver_changed=False,
        JVM_started=False,AIR_started=False),ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(repairs_per_mode=2,component_files_per_mode=len(files(HERE/'components/on')),
        expected_checks_each=109,JVM_started=False,AIR_started=False)))


if __name__=='__main__':main()
