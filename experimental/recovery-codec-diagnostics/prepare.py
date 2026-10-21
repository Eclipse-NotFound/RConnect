"""Generate an isolated RoomCodec diagnostic gate; never compiles or installs."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-05/src/rconnect/net/RoomCodec.as'


def replace(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Ambiguous source anchor: ' + old)
    return text.replace(old, new, 1)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode('utf-8'))


old = BASE.read_text(encoding='utf-8')
new = replace(old, '      private static const DIGITS:',
    '      /** Explicit diagnostic opt-in. Per-cell disk writes must not run during ordinary play. */\n'
    '      public static var timingEnabled:Boolean=false;\n'
    '      private static const DIGITS:')
new = new.replace('var started:int=getTimer(),timing:Object={};',
                  'var started:int=timingEnabled?getTimer():0,timing:Object=timingEnabled?{}:null;')
for field in ('table', 'json', 'utf', 'compress', 'base64', 'inflate'):
    new = new.replace('timing.' + field + '=getTimer()-started;',
                      'if(timing!=null)timing.' + field + '=getTimer()-started;')
new = replace(new, 'timing.bytes=b.length;b.compress();',
              'if(timing!=null)timing.bytes=b.length;b.compress();')
for start, end in [
    ('         Log.d("RConnectRoomTiming pack ', '         return result;'),
    ('         Log.d("RConnectRoomTiming unpack ', '         return result;'),
]:
    at = new.index(start)
    finish = new.index(end, at)
    body = new[at:finish]
    new = new[:at] + '         if(timing!=null) {\n' + ''.join('   '+line for line in body.splitlines(True)) + '         }\n' + new[finish:]
write(HERE / 'src/rconnect/net/RoomCodec.as', new)
for name, source in [('CodecBefore', old), ('CodecAfter', new)]:
    write(HERE / ('components/rconnect/net/' + name + '.as'),
          replace(source, 'public class RoomCodec', 'public class ' + name))
files = [BASE, HERE / 'src/rconnect/net/RoomCodec.as']
files += sorted((HERE / 'components').rglob('*.as'))
manifest = dict(base=str(BASE.relative_to(ROOT)),
    source_sha256=hashlib.sha256(BASE.read_bytes()).hexdigest(),
    files={p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
    gameplay_change=False, default_diagnostics=False, native_tested=False)
write(HERE / 'manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(dict(files=len(files), source_sha256=manifest['source_sha256'], compiled=False)))
