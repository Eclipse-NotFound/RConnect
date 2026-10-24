"""Read-only verification of the 78C self-snapshot envelope candidate.

No current-installation manifest or process launch. build.py binds the
unchanged bounded compiler and records fresh installation inputs at execution.
"""
from pathlib import Path
import argparse
import ast
import difflib
import hashlib
import json
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-room-production-05'
DELEGATE = ROOT / 'experimental/recovery-room-production-v5/build.py'
PRIOR_SHA = '1fdd8c004cb0b46a839ac87a1b0002b93674ae92f88b0cb1d0e766879bef2fe4'
VERSION = '0.2.24-selfecho1'
BASE_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
REL = 'rconnect/core/Session.as'
BEFORE = b'''         for each(var p:Object in peers)
         {
            players.push({id: p.id, name: p.name, snap: p.snap});
         }'''
AFTER = b'''         // With one authenticated recipient, its own snapshot is never
         // consumed. Keep the roster and the host's stored peer state intact.
         var recipient:TcpLink = peers.length == 1 && server.clients.length == 1
            ? server.clients[0] as TcpLink : null;
         var omitOwnSnapshot:Boolean = recipient != null && recipient.isOpen
            && recipient.id > 0 && peers[0].link === recipient
            && int(peers[0].id) == recipient.id;
         for each(var p:Object in peers)
         {
            players.push({id: p.id, name: p.name, snap: omitOwnSnapshot ? null : p.snap});
         }'''
NET = ('HostServer', 'TcpLink', 'Protocol', 'NetMessageEvent', 'BinaryMessageCodec')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p)
            for p in sorted(path.rglob('*')) if p.is_file()}


def session_slice(source, name):
    """Copy both complete real methods; only access changes for the component."""
    start = source.index('      private function broadcastWorldState():void')
    end = source.index('      // ---- 工具', start)
    methods = source[start:end].replace('      private function ', '      public function ')
    assert methods.count('public function ') == 2
    return '''package echo {
   import rconnect.net.HostServer;
   import rconnect.net.TcpLink;
   import rconnect.net.Protocol;
   // Record-only dependencies: this is a method component, not a game session.
   public class NAME {
      public var server:HostServer;
      public var mod:Object;
      public var rooms:Object;
      public var peers:Array=[];
      public var remotes:Array=[];
      public var myName:String="host";
      public var myId:int=1;
      private var _tickCount:int=37;
METHODS
   }
}
'''.replace('NAME', name).replace('METHODS', methods)


def source_diff():
    result = ''
    for name in ('RConnectMod.as', REL):
        a = (BASE / 'src' / name).read_text(encoding='utf-8')
        b = (HERE / 'src' / name).read_text(encoding='utf-8')
        result += ''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True),
                          fromfile='production05/src/' + name,
                          tofile='overlay/src/' + name))
    return result


def verify():
    m = read(HERE / 'source-manifest.json')
    assert m['base_sha256'] == BASE_SHA and m['version'] == VERSION
    assert m['current_environment_bound'] is False
    prior_path = HERE / 'provenance/source-manifest-before-build.json'
    assert sha(prior_path) == PRIOR_SHA == m['prior_manifest_sha256']
    prior = read(prior_path)
    for key in ('base_source', 'candidate_source', 'component_source'):
        assert m[key] == prior[key], 'Build binding changed frozen AS: ' + key
    for name, digest in m['inputs'].items():
        assert sha(ROOT / name) == digest, name
    assert sha(BASE / 'RConnectMod.swf') == BASE_SHA
    receipt = read(BASE / 'compile.json')
    assert receipt['compiled'] is True and receipt['candidate_sha256'] == BASE_SHA
    original_source = inventory(BASE / 'src')
    assert original_source == m['base_source'] == read(BASE / 'prepared.json')['source']
    assert len(original_source) == 81
    assert inventory(BASE / 'tools') == read(BASE / 'prepared.json')['inputs']
    files = {p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob('*'))
             if p.is_file() and p.name != 'source-manifest.json'}
    assert files == m['files'], 'Frozen recipe changed'
    original = (BASE / 'src' / REL).read_bytes()
    assert original.count(BEFORE) == 1
    candidate = original.replace(BEFORE, AFTER)
    assert (HERE / 'src' / REL).read_bytes() == candidate
    entry = (BASE / 'src/RConnectMod.as').read_bytes()
    assert entry.count(b'0.2.24-roomfix5') == 1
    assert (HERE / 'src/RConnectMod.as').read_bytes() == entry.replace(b'0.2.24-roomfix5', VERSION.encode())
    assert set(inventory(HERE / 'src')) == {REL, 'RConnectMod.as'}
    expected = dict(original_source)
    expected.update(inventory(HERE / 'src'))
    assert expected == m['candidate_source']
    changes = {name: dict(base_sha256=original_source[name], candidate_sha256=sha(HERE / 'src' / name))
               for name in sorted(inventory(HERE / 'src'))}
    assert m['changes'] == changes
    assert sum(expected[k] == v for k, v in original_source.items()) == 79
    for name, content in [('ControlSessionSlice', original), ('CandidateSessionSlice', candidate)]:
        assert (HERE / 'components/echo' / (name + '.as')).read_text('utf-8') == session_slice(content.decode('utf-8'), name)
    for name in NET:
        path = 'rconnect/net/' + name + '.as'
        assert (HERE / 'components' / path).read_bytes() == (BASE / 'src' / path).read_bytes()
    path = 'rconnect/core/Log.as'
    assert (HERE / 'components' / path).read_bytes() == (BASE / 'src' / path).read_bytes()
    assert (HERE / 'source.diff').read_text('utf-8') == source_diff()
    assert inventory(HERE / 'components') == m['component_source']
    component = ROOT / m['component_evidence']
    intent, result, receipt = [read(component / name) for name in ('intent.json', 'component-result.json', 'receipt.json')]
    assert intent['sources'] == m['component_source'] and intent['expected'] == 100
    assert result['passed'] is True and result['failed'] == 0
    assert len(result['assertions']) == 100 and all(row['passed'] is True for row in result['assertions'])
    assert all(receipt[key] is True for key in ('passed', 'compiled', 'source_unchanged', 'installation_unchanged'))
    assert receipt['observed_checks'] == 100 and receipt['checks_failed'] == 0 and receipt['exit_code'] == 0
    assert sha(component / 'Checks.swf') == receipt['component_sha256']
    for name in ('prepare.py', 'build.py'):
        ast.parse((HERE / name).read_text('utf-8'))
    return m


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', required=True)
    parser.parse_args()
    verify()
    print(json.dumps(dict(checked=True, changed_classes=2, unchanged_classes=79,
                          compiled=False, air_started=False, current_environment_bound=False)))
