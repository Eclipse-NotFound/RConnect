"""Freeze an insertion-only room-cost diagnostic against recovery07, no deploy.

Default is source freeze only. --build acquires the existing registry and invokes
the frozen production compiler in a new build/m52 folder. AIR is never started.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from generate import BASE, FILES, HELPER, HERE, ROOT, read, sha, stripped


def inventory(folder):
    return {p.relative_to(folder).as_posix():sha(p.read_bytes()) for p in sorted(folder.rglob('*')) if p.is_file()}


def save(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def verify_proposal():
    meta=read(HERE/'inputs.json');base=read(BASE/'prepared.json')
    assert meta['diagnostic_only'] and not meta['compiled'] and not meta['air_started']
    assert meta['base_manifest_sha256']==sha((BASE/'prepared.json').read_bytes())
    assert base['compiled'] and base['version']=='0.2.24-recovery7'
    assert meta['base_sha256']==base['sha256']==sha((BASE/'RConnectMod.swf').read_bytes())
    assert inventory(BASE/'src')==base['source']
    assert inventory(BASE/'tools')==base['inputs']
    assert inventory(HERE/'src')==meta['overlay']
    assert set(meta['source'])==set(FILES) and set(meta['overlay'])==set(FILES)|{HELPER}
    assert meta['generator_sha256']==sha((HERE/'generate.py').read_bytes())
    for name in FILES:
        original=(BASE/'src'/name).read_bytes()
        assert sha(original)==meta['source'][name]
        assert stripped((HERE/'src'/name).read_text(encoding='utf-8')).encode('utf-8')==original,name
    driver=ROOT/'build/m52/room-travel-driver-12'
    driver_meta=read(driver/'prepared.json')
    for name,digest in driver_meta['files'].items():
        assert sha((driver/name).read_bytes())==digest,name
    return meta,base,dict(path=str(driver.relative_to(ROOT)),
        manifest_sha256=sha((driver/'prepared.json').read_bytes()),
        scene_test_sha256=sha((driver/'tests/RoomTravelTimingTestDoc.as').read_bytes()),
        changed=False)


def freeze(out):
    proposal,base,driver=verify_proposal()
    assert out.parent==(ROOT/'build/m52').resolve() and not out.exists(), 'Use a new immediate build/m52 child'
    shutil.copytree(BASE/'src',out/'src')
    shutil.copytree(BASE/'tools',out/'tools')
    for name in proposal['overlay']:
        target=out/'src'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(HERE/'src'/name,target)
    audit=out/'diagnostic-inputs';audit.mkdir()
    for name in ('inputs.json','generate.py','prepare.py','diagnostic.patch','README.md'):
        shutil.copyfile(HERE/name,audit/name)
    meta=dict(kind='isolated-room-restore-diagnostic',version=base['version'],
        base=proposal['base'],base_sha256=proposal['base_sha256'],
        base_manifest_sha256=proposal['base_manifest_sha256'],
        recipe_sha256=sha(Path(__file__).read_bytes()),proposal_sha256=sha((HERE/'inputs.json').read_bytes()),
        source=inventory(out/'src'),inputs=inventory(out/'tools'),diagnostic_inputs=inventory(audit),
        stripped_equal=proposal['stripped_equal'],scene_driver=driver,
        diagnostic_only=True,compiled=False,air_started=False,installed=False,
        gameplay_qualified=False,performance_qualified=False)
    save(out/'prepared.json',meta)
    verify(out)
    return meta


def verify(out):
    meta=read(out/'prepared.json')
    assert meta['kind']=='isolated-room-restore-diagnostic' and meta['diagnostic_only']
    assert meta['recipe_sha256']==sha(Path(__file__).read_bytes())
    assert inventory(out/'src')==meta['source']
    assert inventory(out/'tools')==meta['inputs']
    assert inventory(out/'diagnostic-inputs')==meta['diagnostic_inputs']
    assert sha((BASE/'prepared.json').read_bytes())==meta['base_manifest_sha256']
    return meta


def build(out,wait):
    meta=verify(out)
    assert not meta['compiled'] and not (out/'compile.log').exists(), 'Never rebuild failed or completed evidence'
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,SDK
    sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 独立房间导入诊断',purpose='仅编译插桩候选，保持scene12驱动原判据',
                      resource='game',run_dir=out,evidence=out/'compile.log',wait=wait) as record:
        verify(out)
        tool_paths=[JAVA,SDK/'lib/mxmlc.jar',SDK/'lib/compc.jar',
                    SDK/'frameworks/air-config.xml',SDK/'frameworks/libs/air/airglobal.swc',
                    ROOT/'tools/host_authority/common.py',ROOT.parent/'ModLoader/tools/test_registry.py']
        tools={str(p):sha(p.read_bytes()) for p in tool_paths}
        command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),
                 '--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),
                 '--output',str(out/'RConnectMod.swf')]
        save(out/'build-intent.json',dict(command=command,tools=tools,diagnostic_only=True))
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            code=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT).returncode
        meta.update(compile_exit=code,compile_log_sha256=sha((out/'compile.log').read_bytes()))
        verify(out)
        assert all(sha(Path(p).read_bytes())==digest for p,digest in tools.items()),'Build tools changed'
        if code==0:
            meta.update(compiled=True,sha256=sha((out/'RConnectMod.swf').read_bytes()),
                        candidate_sha256=sha((out/'RConnectMod.swf').read_bytes()))
        save(out/'prepared.json',meta)
        if code:raise SystemExit(code)
        record.outcome='passed';record.note='诊断候选只编译通过，未运行AIR，不具备性能资格'
    return meta


def main(argv=None):
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--build',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=900)
    args=ap.parse_args(argv)
    out=(ROOT/args.output).resolve()
    assert args.registry_wait>=0
    assert out.parent==(ROOT/'build/m52').resolve()
    if out.exists():
        assert args.build,'Existing freeze permits only its first pending build'
        verify(out)
    else:freeze(out)
    if args.build:build(out,args.registry_wait)
    print(out)
    return 0


if __name__=='__main__':raise SystemExit(main())
