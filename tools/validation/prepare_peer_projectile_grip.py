"""Build the peer-grenade fix from frozen fix39, without consuming other WIP."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK

BASE = ROOT/'build/m52/a22-fixes-39'
BASE_MANIFEST = 'ccb9401c418c75a9d014c52187abbcca84eabf0a32b44a198056f7fc7f26fbab'
OVERLAY = ROOT/'experimental/peer-projectile-grip'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def replace_once(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def integrate(name, source):
    if name == 'src/RConnectMod.as':
        return replace_once(source, '         game.peerGrip = this.peerGrip;',
            '         game.peerGrip = this.peerGrip;\n'
            '         new rconnect.core.ProjectileGrip(this);')
    if name == 'src/rconnect/game/ProjectileVisuals.as':
        source = replace_once(source, '   import rconnect.core.Log;',
                              '   import rconnect.core.Log;\n   import rconnect.core.ProjectileGrip;')
        source = replace_once(source, 'ended:b.babah || !b.in_chain,blend:b.vis.blendMode};',
            'ended:b.babah || !b.in_chain,blend:b.vis.blendMode,\n'
            '            grip:ProjectileGrip.instance==null?null:ProjectileGrip.instance.describe(b)};')
        source = replace_once(source, 'beam:s.frames is Array,offset:channel.offset,',
                              'owner:owner,beam:s.frames is Array,offset:channel.offset,')
        source = replace_once(source, 'if(a.beam) {if(!tickBeam(a,now))remove(i);continue;}',
            'if(a.beam) {if(!tickBeam(a,now))remove(i);\n'
            '               else if(ProjectileGrip.instance!=null)ProjectileGrip.instance.present(a);continue;}')
        return replace_once(source, 'private function remove(i:int):void {var a:Object=active[i],v:DisplayObject=a.vis;',
            'private function remove(i:int):void {var a:Object=active[i],v:DisplayObject=a.vis;'
            'if(ProjectileGrip.instance!=null)ProjectileGrip.instance.forget(a);')
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert sha(BASE/'prepared.json') == BASE_MANIFEST
    manifest = json.loads((BASE/'prepared.json').read_text('utf-8-sig'))
    for name, digest in manifest['source'].items():
        assert sha(BASE/name) == digest
        source = (BASE/name).read_text('utf-8-sig')
        changed = integrate(name, source)
        if name == 'src/RConnectMod.as':
            changed = replace_once(changed, '"0.2.22-fix39-keybinds"', '"0.2.22-peer-grenade-01"')
        put(out/name, changed.encode('utf-8') if changed != source else (BASE/name).read_bytes())
    for path in (OVERLAY/'src').rglob('*.as'):
        put(out/path.relative_to(OVERLAY), path.read_bytes())
    for name, digest in manifest['inputs'].items():
        if name.startswith('tools/stubs/'):
            assert sha(BASE/name) == digest
            put(out/name, (BASE/name).read_bytes())
    for name in ('tools/build_mod.py',):
        put(out/name, (ROOT/name).read_bytes())
    with (out/'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([sys.executable, '-B', '-X', 'utf8', str(out/'tools/build_mod.py'),
            '--java', str(JAVA), '--amxmlc', str(SDK/'bin/amxmlc.bat'),
            '--output', str(out/'RConnectMod.swf')], stdout=log, stderr=subprocess.STDOUT, check=True)
    record = dict(kind='isolated-peer-projectile-grip', version='0.2.22-peer-grenade-01',
        base_manifest=BASE_MANIFEST, base_binary=manifest['candidate_sha256'],
        candidate_sha256=sha(out/'RConnectMod.swf'), preparer_sha256=sha(Path(__file__)),
        source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')},
        integration_files=['src/RConnectMod.as','src/rconnect/game/ProjectileVisuals.as'],
        installation_modified=False)
    (out/'prepared.json').write_text(json.dumps(record, indent=2), 'utf-8')
    print(json.dumps(dict(candidate=record['candidate_sha256'], output=str(out))))


if __name__ == '__main__':
    main()
