"""Only prepare/check isolated AS text. Never compile, launch, or touch installation."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-room-production-05/src'
PINS = {
    'rconnect/game/GameBridge.as': 'f7016bfd096ca3c88ea1214733117758b1998b579ec6f3ca9fc9332b605011a9',
    'rconnect/game/RemoteMotion.as': '19f035bfccb5a035fdb9df84c364db3a2eb845e2c002d825f8ed0665517174aa',
}
READ_PINS = {
    'rconnect/core/Session.as': '14aac9a684133740b95a4bbe3cbcec9f03095965496c292b2d9ffeb54d9f453d',
    'rconnect/net/Protocol.as': '9655eb28a4c417750bbbf318a0ce20bd485080051447c0caf0500ce76218b39d',
    'rconnect/net/BinaryMessageCodec.as': '001479db144318320669ce3d89e6c275c210a7d81b9e6f116cdb58e6091376f1',
    'rconnect/net/TcpLink.as': 'b7ab3b85e9d97a3096c2ceb466515bdade58f705ac8585b96984c435a3359a5a',
    'rconnect/game/TeleportVisuals.as': 'ec323ce52b1926e6cb1c98e722c78544cd396fa5b3661ba257111b4b703c272c',
}
WEAPON_FIXTURE = ROOT/'experimental/goal-motion-clock-v2/components/rconnect/game/WeaponDisplay.as'
WEAPON_SHA = '0dcf6e87b9ec18737227aa0bbbfc1053bde0cb7e523c7d47e7e62f854f6b0ddc'
EXPECTED_ASSERTIONS = 72

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace(s, old, new):
    if s.count(old) != 1:
        raise RuntimeError('Expected one source anchor: ' + old[:100])
    return s.replace(old, new, 1)

def altered(rel):
    p = BASE / rel
    if sha(p) != PINS[rel]:
        raise RuntimeError('Changed exact 78C source: ' + rel)
    raw = p.read_bytes().decode('utf-8')
    nl = '\r\n' if '\r\n' in raw else '\n'
    s = raw.replace('\r\n', '\n')
    if rel.endswith('GameBridge.as'):
        s = replace(s, '         if(roomHold)return;\n         _wall.observe(loc);',
            '         if(roomHold){_nativeJumpPose.observe(null,loc,world);return;}\n         _wall.observe(loc);')
        s = replace(s, '         if(!skipOfflinePresentation()) {\n            if(!_mirroring) _presentation.observe(loc,_sampleAt);',
            '         if(!skipOfflinePresentation()) {\n            _nativeJumpPose.observe(gg,loc,world);\n            if(!_mirroring) _presentation.observe(loc,_sampleAt);')
        s = replace(s, '            if(gg!=null)_bodyEffects.observe(gg,_sampleAt);\n         }\n         try {main.stage.invalidate();}',
            '            if(gg!=null)_bodyEffects.observe(gg,_sampleAt);\n         } else _nativeJumpPose.observe(null,loc,world);\n         try {main.stage.invalidate();}')
        s = replace(s, '      /** 采集本机玩家状态快照',
            '      private var _nativeJumpPose:NativeJumpPose=new NativeJumpPose();\n\n      /** 采集本机玩家状态快照')
        s = replace(s, '         s.bodyPlaying = probe(probe(osn, "body"), "isPlaying") == true;',
            '         s.bodyPlaying = probe(probe(osn, "body"), "isPlaying") == true;\n'
            '         s.nativeJumpRun = _nativeJumpPose.observe(roomHold?null:gg,loc,world);')
    else:
        s = replace(s, '         if(crossing!=null) {\n            state.x=crossing.x;',
            '         // The selected state is reused: discard any prior interpolated pose first.\n'
            '         if(selected.bodyFrame!==undefined)state.bodyFrame=selected.bodyFrame;\n'
            '         if(crossing!=null) {\n            state.x=crossing.x;')
        s = replace(s, '         if(a.snap.weapons is Array && b.snap.weapons is Array)',
            '         var jumpFrame:Number=NativeJumpPose.between(a.snap,b.snap,t);\n'
            '         if(isFinite(jumpFrame))state.bodyFrame=int(jumpFrame);\n'
            '         if(a.snap.weapons is Array && b.snap.weapons is Array)')
    return s.replace('\n', nl).encode('utf-8')

def method(source, marker):
    start = source.index(marker)
    body = source.index('{', start)
    depth = 1
    i = body+1
    while depth:
        if source[i] == '{': depth += 1
        elif source[i] == '}': depth -= 1
        i += 1
    return source[start:i]

def expected():
    for rel, digest in READ_PINS.items():
        if sha(BASE/rel)!=digest:
            raise RuntimeError('Changed read-only source: '+rel)
    if sha(WEAPON_FIXTURE)!=WEAPON_SHA:
        raise RuntimeError('Changed explicit throwing weapon fixture')
    session=(BASE/'rconnect/core/Session.as').read_text(encoding='utf-8')
    for anchor in ('var snap:Object = mod.game != null ? mod.game.readSnapshot() : null;',
                   '{id: myId, seq: _seq++, name: myName, snap: snap}',
                   'peer.snap = msg.snap;',
                   'players.push({id: p.id, name: p.name, snap: p.snap});',
                   'mod.game.updateRemote(id, p.snap != null ? p.snap : {},'):
        if session.count(anchor)!=1:
            raise RuntimeError('Changed direct snapshot relay: '+anchor)
    link=(BASE/'rconnect/net/TcpLink.as').read_text(encoding='utf-8')
    for anchor in ('BinaryMessageCodec.pack(msg)', 'Protocol.encode(msg)',
                   'BinaryMessageCodec.unpack(body)', 'Protocol.decode(_rbuf.readUTFBytes(len))',
                   'dispatchEvent(new NetMessageEvent(MESSAGE, msg));'):
        if link.count(anchor)!=1:
            raise RuntimeError('Changed real transport binding: '+anchor)
    files = {'src/'+rel: altered(rel) for rel in PINS}
    helper = (HERE/'src/rconnect/game/NativeJumpPose.as').read_bytes()
    files['components/rconnect/game/NativeJumpPose.as'] = helper
    files['components/rconnect/game/RemoteMotion.as'] = files['src/rconnect/game/RemoteMotion.as']
    files['components/rconnect/game/ControlRemoteMotion.as'] = (BASE/'rconnect/game/RemoteMotion.as').read_bytes().replace(b'RemoteMotion', b'ControlRemoteMotion')
    native = (BASE/'rconnect/game/TeleportVisuals.as').read_text(encoding='utf-8')
    # Both complete pure methods are copied, not simulated. Other teleport behavior is not a fixture claim.
    ports = 'package rconnect.game {\n   public class TeleportVisuals {\n'
    ports += method(native, '      private static function valid(')+'\n'
    ports += method(native, '      public static function split(')+'\n   }\n}\n'
    files['components/rconnect/game/TeleportVisuals.as'] = ports.encode('utf-8')
    files['components/rconnect/game/WeaponDisplay.as'] = WEAPON_FIXTURE.read_bytes()
    for name in ('Protocol.as','BinaryMessageCodec.as'):
        files['components/rconnect/net/'+name]=(BASE/'rconnect/net'/name).read_bytes()
    diff = ''
    for rel in PINS:
        diff += ''.join(difflib.unified_diff((BASE/rel).read_text(encoding='utf-8').splitlines(True),
                    files['src/'+rel].decode('utf-8').replace('\r\n','\n').splitlines(True),
                    fromfile='78C/'+rel, tofile='candidate/'+rel))
    diff += ''.join(difflib.unified_diff([], helper.decode('utf-8').splitlines(True),
                fromfile='/dev/null', tofile='candidate/rconnect/game/NativeJumpPose.as'))
    files['source.diff'] = diff.encode('utf-8')
    return files

def manifest():
    return {'kind':'native-jump-pose-source-only', 'compiled':False, 'native_tested':False,
        'performance_qualified':False, 'expected_component_assertions':EXPECTED_ASSERTIONS,
        'base_product_sha256':'78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699',
        'base':PINS, 'read_only_sources':READ_PINS,
        'weapon_fixture':{'path':str(WEAPON_FIXTURE),'sha256':WEAPON_SHA},
        'files':{p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
                 if p.is_file() and p.name!='source-manifest.json' and '__pycache__' not in p.parts}}

def verify():
    files = expected()
    for rel, data in files.items():
        if (HERE/rel).read_bytes() != data:
            raise RuntimeError('Prepared text mismatch: '+rel)
    for name in ('prepare_sources.py', 'read_trace.py'):
        compile((HERE/name).read_text(encoding='utf-8'), name, 'exec')
    if json.loads((HERE/'source-manifest.json').read_text(encoding='utf-8'))!=manifest():
        raise RuntimeError('Changed source manifest')
    print(json.dumps({'source_checks_passed': True, 'compiled': False, 'native_tested': False,
        'base': PINS, 'files': {p.relative_to(HERE).as_posix(): sha(p)
          for p in sorted(HERE.rglob('*')) if p.is_file() and '__pycache__' not in p.parts}}, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prepare', action='store_true')
    args = parser.parse_args()
    if args.prepare:
        for rel, data in expected().items():
            p = HERE/rel
            if p.exists() and p.read_bytes()!=data:
                raise RuntimeError('Refuse overwriting prepared source: '+rel)
            if not p.exists():
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(data)
        target=HERE/'source-manifest.json'
        data=(json.dumps(manifest(),ensure_ascii=False,indent=2)+'\n').encode('utf-8')
        if target.exists() and target.read_bytes()!=data:
            raise RuntimeError('Refuse overwriting frozen source manifest')
        if not target.exists():target.write_bytes(data)
    verify()
