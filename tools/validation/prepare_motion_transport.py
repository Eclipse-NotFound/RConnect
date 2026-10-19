"""Freeze a narrow worldstate recipient optimization and its component test.

Does not modify active integration sources, installation, or launch AIR.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/m52/coop-bundle-04'
OVERLAY = ROOT / 'experimental/motion-regression/src/rconnect/net/HostServer.as'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = ROOT.parent / 'Sandevistan/build/tools/flexsdk'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidate(source):
    anchor = '               link.send(msg);'
    assert source.count(anchor) == 1
    source = source.replace(anchor, '               link.send(forRecipient(msg, link.id));')
    anchor = '      public function close():void'
    assert source.count(anchor) == 1
    method = '''      /** A player's upload needs immediate relay only to other authenticated
       * observers. The sender receives host state from the regular world tick. */
      public function hasObserverOtherThan(sender:TcpLink):Boolean
      {
         for each(var link:TcpLink in clients)
            if(link !== sender && link.isOpen && link.id > 0) return true;
         return false;
      }

      /** The receiver ignores its own player entry before reading snap.
       * Preserve the roster and every other field, but do not serialize the
       * receiver's own projectile/pose history back to the same player.
       * Copy only the envelopes: the source and other recipients stay intact. */
      private static function forRecipient(msg:Object, id:int):Object
      {
         if(id <= 0 || msg == null || msg.type != Protocol.MSG_WORLDSTATE
            || !(msg.players is Array)) return msg;
         var players:Array = msg.players as Array;
         var result:Object = null, list:Array = null;
         for(var i:int = 0; i < players.length; i++)
         {
            var player:Object = players[i];
            if(player == null || player.id == null || int(player.id) != id
               || player.snap == null) continue;
            if(result == null)
            {
               result = {};
               for(var key:String in msg) result[key] = msg[key];
               list = players.concat();
               result.players = list;
            }
            var own:Object = {};
            for(key in player) own[key] = player[key];
            own.snap = null;
            list[i] = own;
         }
         return result == null ? msg : result;
      }

'''
    return source.replace(anchor, method + anchor)


def session_candidate(source):
    start = source.index('            case Protocol.MSG_PLAYERSTATE:', source.index('private function onHostMessage'))
    end = source.index('            case "map-progress":', start)
    branch = source[start:end]
    anchor = '               broadcastWorldState();'
    assert branch.count(anchor) == 1
    revised = branch.replace(anchor, '''               // The uploaded state is already applied to the host above.
               // With one guest, echoing a fresh world here only repeats the
               // scheduled 50ms broadcast. Keep immediate relay for another
               // authenticated observer, without delaying local ghost input.
               if(server != null && server.hasObserverOtherThan(link))
                  broadcastWorldState();''')
    return source[:start] + revised + source[end:]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and not out.exists(), out
    manifest = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
    names = [f'src/rconnect/net/{n}.as' for n in
             ['HostServer', 'TcpLink', 'Protocol', 'NetMessageEvent', 'BinaryMessageCodec']]
    names.append('src/rconnect/core/Log.as')
    for name in names:
        assert sha(BASE / name) == manifest['source'][name], name
    original = (BASE / names[0]).read_text(encoding='utf-8-sig')
    revised = candidate(original)
    OVERLAY.parent.mkdir(parents=True, exist_ok=True)
    OVERLAY.write_text(revised, encoding='utf-8')
    session = BASE / 'src/rconnect/core/Session.as'
    assert sha(session) == manifest['source']['src/rconnect/core/Session.as']
    session_out = OVERLAY.parents[1] / 'core/Session.as'
    session_out.parent.mkdir(parents=True, exist_ok=True)
    session_out.write_text(session_candidate(session.read_text(encoding='utf-8-sig')), encoding='utf-8')
    for name in names:
        target = out / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(BASE / name, target)
    (out / names[0]).write_text(revised, encoding='utf-8')
    (out / 'src/rconnect/net/BeforeHostServer.as').write_text(
        original.replace('class HostServer', 'class BeforeHostServer'), encoding='utf-8')
    test = ROOT / 'tests/MotionTransportTestDoc.as'
    shutil.copyfile(test, out / 'src/MotionTransportTestDoc.as')
    inputs = {p.relative_to(out).as_posix(): sha(p) for p in (out / 'src').rglob('*.as')}
    command = [str(JAVA), '-Xmx256m', '-jar', str(SDK / 'lib/mxmlc.jar'),
               '+configname=air', '+flexlib=' + str(SDK / 'frameworks'),
               '-swf-version=38', '-debug=false', '-optimize=true',
               '-source-path=' + str(out / 'src'), '-output=' + str(out / 'MotionTransportTestDoc.swf'),
               str(out / 'src/MotionTransportTestDoc.as')]
    with (out / 'compile.log').open('w', encoding='utf-8') as log:
        compiled = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                  env=dict(os.environ, AIR_HOME=str(SDK)))
    record = dict(kind='motion-transport-component', base_manifest_sha256=sha(BASE / 'prepared.json'),
                  base_binary_sha256=sha(BASE / 'RConnectMod.swf'), inputs=inputs,
                  recipe_sha256=sha(Path(__file__)), compile_exit=compiled.returncode,
                  compile_log_sha256=sha(out / 'compile.log'),
                  command=command, installation_modified=False, gameplay_qualified=False)
    if compiled.returncode == 0:
        record['test_sha256'] = sha(out / 'MotionTransportTestDoc.swf')
    (out / 'prepared.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(json.dumps(dict(output=str(out), compile_exit=compiled.returncode)))
    raise SystemExit(compiled.returncode)


if __name__ == '__main__':
    main()
