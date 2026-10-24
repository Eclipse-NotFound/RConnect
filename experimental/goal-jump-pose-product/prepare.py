"""Text-only binding of the frozen three-class jump pose change to exact 78C."""
import argparse
import ast
import contextlib
import difflib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT/'build/m52/recovery-room-production-05'
SOURCE = ROOT/'experimental/goal-jump-pose-interpolation'
DELEGATE = ROOT/'experimental/recovery-room-production-v5/build.py'
BASE_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
VERSION = '0.2.24-jumppose1'
PINS = {
    'build/m52/recovery-room-production-05/prepared.json':'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
    'build/m52/recovery-room-production-05/compile.json':'68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
    'experimental/goal-jump-pose-interpolation/source-manifest.json':'b77dffb1ff1518562ac592dcd928f08221f77622d946252374fd60427da6d914',
    'experimental/goal-jump-pose-interpolation/prepare_sources.py':'c5732f3284db46fb0858a0555e67d5fee4931b365cc8d319d749cd884ea1c83b',
    'experimental/recovery-room-production-v5/build.py':'1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
    'experimental/goal-self-echo-prune/build.py':'30bef16cde7de5fc02b4a73b270effc1c6e991f944c57f31922d4b68f06de24d',
    'tools/validation/run_security_terminals.py':'4e4ad73dd0f8df69db5c0c11f6c2c1c94c96fb1235dbaa1aad18caaf9877b9cb',
    'tools/validation/prepare_security_terminals.py':'5d156d663f616baf793b03ca183388951a10375a5d11e561e81c2b81ab7e13b5',
    'tools/validation/runtime_memory.py':'d4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    '../ModLoader/tools/test_registry.py':'8b35a6d6ca1dd94cfd5cba9a42979ebd14d9ae65497688fa859d084425922049',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*')) if p.is_file()}


def expected():
    for name,digest in PINS.items():
        assert sha(ROOT/name)==digest, name
    spec=importlib.util.spec_from_file_location('frozen_jump_source_check',SOURCE/'prepare_sources.py')
    original=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(original)
    with contextlib.redirect_stdout(io.StringIO()):
        original.verify()
    old,compiled=read(BASE/'prepared.json'),read(BASE/'compile.json')
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA==compiled['candidate_sha256']
    assert all(compiled[k] is True for k in ('compiled','sources_unchanged','installation_unchanged'))
    assert compiled['air_started'] is False and compiled['installed'] is False
    assert compiled['installation_before']==compiled['installation_after']==old['installation_before']
    assert len(compiled['commands'])==2 and all(c['exit_code']==0 for c in compiled['commands'])
    assert inventory(BASE/'src')==old['source'] and inventory(BASE/'tools')==old['inputs']
    assert len(old['source'])==81
    source=read(SOURCE/'source-manifest.json')
    assert source['base_product_sha256']==BASE_SHA and source['expected_component_assertions']==72
    names=('rconnect/game/GameBridge.as','rconnect/game/RemoteMotion.as','rconnect/game/NativeJumpPose.as')
    assert set(inventory(SOURCE/'src'))==set(names)
    files={'src/'+name:(SOURCE/'src'/name).read_bytes() for name in names}
    entry=(BASE/'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomfix5')==1
    files['src/RConnectMod.as']=entry.replace(b'0.2.24-roomfix5',VERSION.encode('ascii'))
    changes={}
    candidate=dict(old['source'])
    diff=''
    for rel,data in sorted(files.items()):
        name=rel[4:]
        digest=hashlib.sha256(data).hexdigest()
        changes[name]={'base_sha256':old['source'].get(name),'candidate_sha256':digest}
        candidate[name]=digest
        before=(BASE/'src'/name).read_text(encoding='utf-8').splitlines(True) if name in old['source'] else []
        diff+=''.join(difflib.unified_diff(before,data.decode('utf-8').replace('\r\n','\n').splitlines(True),
                      fromfile='78C/'+name,tofile='jumppose1/'+name))
    assert len(candidate)==82 and sum(candidate[k]==v for k,v in old['source'].items())==78
    assert changes['rconnect/game/NativeJumpPose.as']['base_sha256'] is None
    files['source.diff']=diff.encode('utf-8')
    for name in ('prepare.py','build.py'):
        ast.parse((HERE/name).read_text('utf-8'))
    manifest={'kind':'native-jump-pose-bounded-product-v1','base_sha256':BASE_SHA,'version':VERSION,
        'current_environment_bound':False,'source_manifest_sha256':sha(SOURCE/'source-manifest.json'),
        'inputs':PINS,'base_source':old['source'],'candidate_source':candidate,'changes':changes,
        'expected_component_assertions':72,'native_tested':False,'performance_qualified':False}
    manifest['files']={name:hashlib.sha256(data).hexdigest() for name,data in files.items()}
    manifest['files'].update({name:sha(HERE/name) for name in ('prepare.py','build.py','README.md')})
    return files,manifest


def verify():
    files,manifest=expected()
    for name,data in files.items():
        assert (HERE/name).read_bytes()==data, name
    assert read(HERE/'source-manifest.json')==manifest
    assert inventory(HERE/'src')=={name:row['candidate_sha256'] for name,row in manifest['changes'].items()}
    actual={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
            if p.is_file() and p.name!='source-manifest.json'}
    assert actual==manifest['files'], 'Frozen product recipe changed'
    return manifest


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare',action='store_true')
    group.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.prepare:
        files,manifest=expected()
        files['source-manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
        for name,data in files.items():
            p=HERE/name
            if p.exists():
                assert p.read_bytes()==data, 'Refuse overwriting frozen text: '+name
            else:
                p.parent.mkdir(parents=True,exist_ok=True)
                with p.open('xb') as f:f.write(data)
    verify()
    print(json.dumps(dict(checked=True,changed_existing_classes=3,added_classes=1,unchanged_classes=78,
                         compiled=False,air_started=False,current_environment_bound=False)))
