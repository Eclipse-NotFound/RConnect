"""Build a separately frozen A22 room-cost diagnostic; never patch its parent.

--check-only verifies the frozen input and all exact instrumentation anchors in
memory. It creates no directory and runs no compiler. A normal invocation builds
only in a new direct child of build/m52, suitable for run_a22_map_refresh.py.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
BUILD = (ROOT / 'build/m52').resolve()
BRIDGE = 'src/rconnect/game/GameBridge.as'
CODEC = 'src/rconnect/net/RoomCodec.as'
ENTRY = 'src/RConnectMod.as'
MARKER = '[A22RoomProfile] '


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def require(condition, message):
    if not condition:
        raise ValueError(message)


def replace_once(text, old, new):
    require(text.count(old) == 1, 'Expected one exact source anchor: ' + repr(old[:140]))
    return text.replace(old, new, 1)


def function_edit(text, start, end, edits):
    """Bound every replacement to one explicitly named function region."""
    require(text.count(start) == 1 and text.count(end) == 1, 'Ambiguous function bounds: ' + start)
    first, last = text.index(start), text.index(end)
    require(first < last, 'Reversed function bounds: ' + start)
    body = text[first:last]
    for old, new in edits:
        body = replace_once(body, old, new)
    return text[:first] + body + text[last:]


def instrument_bridge(text):
    require(MARKER not in text and '_rcProfile' not in text, 'GameBridge already instrumented')
    require('import flash.utils.getTimer;' in text and 'import rconnect.core.Log;' in text,
            'Missing existing GameBridge timing/log imports')
    text = function_edit(text, '      public function checkpoint():Object\n',
                         '      public function roomRole(authority:Boolean):void\n', [
        ('         rconnect.core.TravelGuard.clear();\n',
         '         var _rcProfileStart:int=getTimer(),_rcProfileMark:int=_rcProfileStart;\n'
         '         rconnect.core.TravelGuard.clear();\n'),
        ('         var list:Array=readUnitsSnapshot() || [],used:Dictionary=new Dictionary();\n',
         '         var list:Array=readUnitsSnapshot() || [],used:Dictionary=new Dictionary();\n'
         '         var _rcProfileUnits:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         var objects:Array=readObjsSnapshot() || [];used=new Dictionary();\n',
         '         var _rcProfileUnitNative:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         var objects:Array=readObjsSnapshot() || [];used=new Dictionary();\n'
         '         var _rcProfileObjects:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         return {key:roomKey(),width:loc.spaceX,height:loc.spaceY,roomId:String(probe(loc.room,"id")),\n'
         '            units:list,objs:objects,loots:readLootSync() || [],tiles:_terrain.checkpoint(loc),wallPaint:_wall.checkpoint(loc),\n'
         '            points:mapProgress==null?null:mapProgress.capture(loc),\n'
         '            mines:playerMines==null?[]:playerMines.checkpoint()};\n',
         '         var _rcProfileObjectNative:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         var _rcProfileResult:Object={key:roomKey(),width:loc.spaceX,height:loc.spaceY,roomId:String(probe(loc.room,"id")),\n'
         '            units:list,objs:objects};\n'
         '         _rcProfileResult.loots=readLootSync() || [];\n'
         '         var _rcProfileLoot:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         _rcProfileResult.tiles=_terrain.checkpoint(loc);\n'
         '         var _rcProfileTerrain:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         _rcProfileResult.wallPaint=_wall.checkpoint(loc);\n'
         '         var _rcProfileWall:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         _rcProfileResult.points=mapProgress==null?null:mapProgress.capture(loc);\n'
         '         var _rcProfilePoints:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         _rcProfileResult.mines=playerMines==null?[]:playerMines.checkpoint();\n'
         '         var _rcProfileEnd:int=getTimer(),_rcProfileMines:int=_rcProfileEnd-_rcProfileMark;\n'
         '         try {Log.d("[A22RoomProfile] "+JSON.stringify({op:"checkpoint",start:_rcProfileStart,at:_rcProfileEnd,ms:_rcProfileEnd-_rcProfileStart,\n'
         '            room:_rcProfileResult.key,units:list.length,objects:objects.length,\n'
         '            stages:{unitsSnapshot:_rcProfileUnits,unitsNative:_rcProfileUnitNative,objectsSnapshot:_rcProfileObjects,objectsNative:_rcProfileObjectNative,\n'
         '               loot:_rcProfileLoot,terrain:_rcProfileTerrain,wall:_rcProfileWall,points:_rcProfilePoints,mines:_rcProfileMines}}));}catch(_rcProfileError:*){}\n'
         '         return _rcProfileResult;\n'),
    ])
    text = function_edit(text,
                         '      public function restoreCheckpoint(s:Object,authority:Boolean,foreign:Boolean):void\n',
                         '      /** 从游戏全量数据 AllData.d 中取单位 XML（blit 动画定义的数据源）。 */\n', [
        ('         roomRole(authority);\n',
         '         var _rcProfileStart:int=getTimer(),_rcProfileMark:int=_rcProfileStart;\n'
         '         roomRole(authority);\n'
         '         var _rcProfileRole:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         if(mapProgress!=null)mapProgress.restore(s.points);\n',
         '         if(mapProgress!=null)mapProgress.restore(s.points);\n'
         '         var _rcProfilePoints:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         reconcileObjs(s.objs as Array);\n',
         '         reconcileObjs(s.objs as Array);\n'
         '         var _rcProfileObjects:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         _terrain.restoreCheckpoint(loc,s.tiles as Array);\n',
         '         var _rcProfileObjectNative:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         _terrain.restoreCheckpoint(loc,s.tiles as Array);\n'
         '         var _rcProfileTerrain:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         used=new Dictionary();_units.enter(loc);\n',
         '         used=new Dictionary();_units.enter(loc);\n'
         '         var _rcProfileUnitReset:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         // Empty is a real checkpoint too, not a temporary network omission.\n',
         '         var _rcProfileUnits:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         // Empty is a real checkpoint too, not a temporary network omission.\n'),
        ('         for each(var loot:Array in lootWalk())loc.remObj(loot[0]);\n',
         '         var _rcProfilePrune:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         for each(var loot:Array in lootWalk())loc.remObj(loot[0]);\n'),
        ('         if(!authority)applyUnitsSync(s.units as Array);\n',
         '         var _rcProfileLoot:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         if(!authority)applyUnitsSync(s.units as Array);\n'
         '         var _rcProfileMirror:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         if(playerMines!=null)playerMines.restore(s.mines as Array,authority,foreign);\n',
         '         if(playerMines!=null)playerMines.restore(s.mines as Array,authority,foreign);\n'
         '         var _rcProfileMines:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         tileRedrawIfDirty();\n',
         '         tileRedrawIfDirty();\n'
         '         var _rcProfileRedraw:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         _wall.restore(loc,s.wallPaint as Array);_satsRasterDirty=true;\n',
         '         _wall.restore(loc,s.wallPaint as Array);_satsRasterDirty=true;\n'
         '         var _rcProfileEnd:int=getTimer(),_rcProfileWall:int=_rcProfileEnd-_rcProfileMark;\n'
         '         try {Log.d("[A22RoomProfile] "+JSON.stringify({op:"restore",start:_rcProfileStart,at:_rcProfileEnd,ms:_rcProfileEnd-_rcProfileStart,\n'
         '            room:s.key,authority:authority,foreign:foreign,units:s.units==null?0:s.units.length,objects:s.objs==null?0:s.objs.length,\n'
         '            stages:{role:_rcProfileRole,points:_rcProfilePoints,objectsReconcile:_rcProfileObjects,objectsNative:_rcProfileObjectNative,terrain:_rcProfileTerrain,\n'
         '               unitsReset:_rcProfileUnitReset,unitsRestore:_rcProfileUnits,unitsPrune:_rcProfilePrune,loot:_rcProfileLoot,unitsMirror:_rcProfileMirror,\n'
         '               mines:_rcProfileMines,redraw:_rcProfileRedraw,wall:_rcProfileWall}}));}catch(_rcProfileError:*){}\n'),
    ])
    return text


def instrument_codec(text):
    require(MARKER not in text and '_rcProfile' not in text, 'RoomCodec already instrumented')
    text = replace_once(text, '   import flash.utils.ByteArray;\n',
                        '   import flash.utils.ByteArray;\n   import flash.utils.getTimer;\n   import rconnect.core.Log;\n')
    text = function_edit(text, '      public static function pack(o:Object):String\n',
                         '      public static function unpack(s:String):Object\n', [
        ('         var b:ByteArray=new ByteArray();b.writeUTFBytes(JSON.stringify(o));b.compress();b.position=0;\n',
         '         var _rcProfileStart:int=getTimer(),_rcProfileMark:int=_rcProfileStart;\n'
         '         var b:ByteArray=new ByteArray();\n'
         '         var _rcProfileJson:String=JSON.stringify(o);\n'
         '         var _rcProfileStringify:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         b.writeUTFBytes(_rcProfileJson);_rcProfileJson=null;\n'
         '         var _rcProfileRawBytes:uint=b.length;\n'
         '         var _rcProfileUtf8:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         b.compress();b.position=0;\n'
         '         var _rcProfileCompressedBytes:uint=b.length;\n'
         '         var _rcProfileCompress:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         return out.join("");\n',
         '         var _rcProfileBase64:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         var _rcProfileResult:String=out.join("");\n'
         '         var _rcProfileEnd:int=getTimer(),_rcProfileJoin:int=_rcProfileEnd-_rcProfileMark;\n'
         '         if(_rcProfileResult.length>=8192 || _rcProfileEnd-_rcProfileStart>=4)\n'
         '            try {Log.d("[A22RoomProfile] "+JSON.stringify({op:"pack",start:_rcProfileStart,at:_rcProfileEnd,ms:_rcProfileEnd-_rcProfileStart,\n'
         '               rawBytes:_rcProfileRawBytes,compressedBytes:_rcProfileCompressedBytes,stateChars:_rcProfileResult.length,\n'
         '               stages:{stringify:_rcProfileStringify,utf8:_rcProfileUtf8,compress:_rcProfileCompress,base64:_rcProfileBase64,join:_rcProfileJoin}}));}catch(_rcProfileError:*){}\n'
         '         return _rcProfileResult;\n'),
    ])
    text = function_edit(text, '      public static function unpack(s:String):Object\n', '\n   }\n}', [
        ('         var b:ByteArray=new ByteArray();\n',
         '         var _rcProfileStart:int=getTimer(),_rcProfileMark:int=_rcProfileStart;\n'
         '         var b:ByteArray=new ByteArray();\n'),
        ('         b.uncompress();b.position=0;\n',
         '         var _rcProfileCompressedBytes:uint=b.length;\n'
         '         var _rcProfileBase64:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         b.uncompress();b.position=0;\n'
         '         var _rcProfileUncompress:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'),
        ('         return JSON.parse(b.readUTFBytes(b.length));\n',
         '         var _rcProfileRawBytes:uint=b.length;\n'
         '         var _rcProfileJson:String=b.readUTFBytes(b.length);\n'
         '         var _rcProfileUtf8:int=getTimer()-_rcProfileMark;_rcProfileMark=getTimer();\n'
         '         var _rcProfileResult:Object=JSON.parse(_rcProfileJson);_rcProfileJson=null;\n'
         '         var _rcProfileEnd:int=getTimer(),_rcProfileParse:int=_rcProfileEnd-_rcProfileMark;\n'
         '         if(s.length>=8192 || _rcProfileEnd-_rcProfileStart>=4)\n'
         '            try {Log.d("[A22RoomProfile] "+JSON.stringify({op:"unpack",start:_rcProfileStart,at:_rcProfileEnd,ms:_rcProfileEnd-_rcProfileStart,\n'
         '               rawBytes:_rcProfileRawBytes,compressedBytes:_rcProfileCompressedBytes,stateChars:s.length,\n'
         '               stages:{base64:_rcProfileBase64,uncompress:_rcProfileUncompress,utf8:_rcProfileUtf8,parse:_rcProfileParse}}));}catch(_rcProfileError:*){}\n'
         '         return _rcProfileResult;\n'),
    ])
    return text


def safe_child(root, name):
    path = (root / name).resolve()
    require(not Path(name).is_absolute() and path.is_relative_to(root) and path != root,
            'Invalid frozen relative path: ' + name)
    return path


def read_parent(base):
    require(base.parent == BUILD, 'Input must be a direct child of build/m52')
    raw = (base / 'prepared.json').read_bytes()
    receipt = json.loads(raw.decode('utf-8-sig'))
    require(str(receipt.get('version', '')).startswith('0.2.22'), 'Input must be an A22 candidate')
    require(not receipt.get('diagnostic_only'), 'Use a non-diagnostic parent candidate')
    blobs = {}
    seen = set()
    for section in ('source', 'inputs'):
        require(isinstance(receipt.get(section), dict) and receipt[section], 'Missing frozen ' + section)
        for name, expected in receipt[section].items():
            require(name.casefold() not in seen, 'Duplicate frozen path: ' + name)
            seen.add(name.casefold())
            require(name.startswith('src/') if section == 'source' else name.startswith(('tools/', 'tests/')),
                    'Unexpected parent ' + section + ' path: ' + name)
            data = safe_child(base, name).read_bytes()
            require(digest(data) == expected, 'Parent file changed: ' + name)
            blobs[name] = data
    for name, key in (('RConnectMod.swf', 'candidate_sha256'), ('control.swf', 'control_sha256'),
                      ('native/pfe.swf', 'candidate_game_sha256')):
        data = (base / name).read_bytes()
        require(digest(data) == receipt[key], 'Parent binary changed: ' + name)
        if name != 'RConnectMod.swf':
            blobs[name] = data
    for name in (BRIDGE, CODEC, ENTRY, 'tools/build_mod.py', 'tools/build_effects_driver.py'):
        require(name in blobs, 'Missing frozen input: ' + name)
    require(bool(receipt.get('original_game_sha256')), 'Missing runner game provenance')
    return raw, receipt, blobs


def transformed_sources(blobs, parent_version, version):
    require(re.fullmatch(r'[A-Za-z0-9_.-]+', version) and version != parent_version,
            'Use a distinct, plain diagnostic version')
    # Normalize source newlines only in the three edited files; all other bytes
    # come directly from the parent's checked hashes, including tests and tools.
    read = lambda name: blobs[name].decode('utf-8-sig').replace('\r\n', '\n')
    return {
        BRIDGE: instrument_bridge(read(BRIDGE)).encode('utf-8'),
        CODEC: instrument_codec(read(CODEC)).encode('utf-8'),
        ENTRY: replace_once(read(ENTRY), '"' + parent_version + '"', '"' + version + '"').encode('utf-8'),
    }


def schema():
    return dict(
        marker=MARKER, units='milliseconds', clock='getTimer in each instance; do not align absolute host/join clocks',
        bridge=dict(checkpoint=['unitsSnapshot', 'unitsNative', 'objectsSnapshot', 'objectsNative', 'loot', 'terrain', 'wall', 'points', 'mines'],
                    restore=['role', 'points', 'objectsReconcile', 'objectsNative', 'terrain', 'unitsReset', 'unitsRestore', 'unitsPrune', 'loot', 'unitsMirror', 'mines', 'redraw', 'wall']),
        codec=dict(pack=['stringify', 'utf8', 'compress', 'base64', 'join'],
                   unpack=['base64', 'uncompress', 'utf8', 'parse'],
                   log_filter='stateChars >= 8192 OR successful call ms >= 4'),
        limitations=[
            'Successful non-null bridge calls only; original null return and exceptions stay unchanged.',
            'All gameplay calls and checkpoint property order are retained. No cache, skipped restore, or redraw shortcut.',
            'A function total excludes its own final Log.d, but enclosing phases include nested codec logging.',
            'Stage boundaries use millisecond timers; small unsampled timer gaps and rounding may make sums differ from total.',
            'unitsSnapshot includes TravelGuard.clear; loot capture includes result metadata; objectsNative restore includes boxTrackReset.',
            'unitsRestore includes resolve, construction, NativeRoomState.restoreUnit and animation; redraw includes every existing tileRedrawIfDirty effect.',
            'Diagnostic overhead means these measurements locate costs; they are not an uninstrumented performance acceptance run.',
        ])


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output', nargs='?', help='New direct child of build/m52 (relative to the mod or absolute)')
    ap.add_argument('--base', default='build/m52/a22-fixes-11', help='Frozen A22 input, including later follow-up candidates')
    ap.add_argument('--version', help='Distinct diagnostic version; default is parent version plus -roomprof')
    ap.add_argument('--check-only', action='store_true', help='Validate parent hashes and exact edits in memory, without writing or compiling')
    args = ap.parse_args()
    base = (ROOT / args.base).resolve()
    raw, parent, blobs = read_parent(base)
    version = args.version or parent['version'] + '-roomprof'
    updates = transformed_sources(blobs, parent['version'], version)
    changes = {name: dict(before=digest(blobs[name]), after=digest(data)) for name, data in updates.items()}
    out = ((ROOT / args.output).resolve() if args.output else
           BUILD / ('a22-room-profile-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8]))
    require(out.parent == BUILD and not out.exists(), 'Output must be a new direct child of build/m52')
    summary = dict(diagnostic_only=True, base=str(base), output=str(out), version=version,
                   parent_prepared_sha256=digest(raw), changes=changes)
    if args.check_only:
        print(json.dumps(dict(summary, check_only=True, verified_files=len(blobs) + 1), ensure_ascii=False, indent=2))
        return
    # Import the same toolchain selection as prepare_a22_fixes only for a real
    # build. No compilation, writes or SDK import is needed by --check-only.
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    from common import JAVA, SDK
    require(JAVA.is_file() and (SDK / 'lib/mxmlc.jar').is_file(), 'A22 compiler toolchain is unavailable')
    require(shutil.disk_usage(BUILD).free > sum(len(data) for data in blobs.values()) * 2 + 64 * 1024 * 1024,
            'Insufficient space for the isolated diagnostic candidate')
    out.mkdir(exist_ok=False)
    for name, data in {**blobs, **updates}.items():
        target = safe_child(out, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    profile = out / 'profile'
    profile.mkdir()
    (profile / 'parent-prepared.json').write_bytes(raw)
    (profile / 'prepare_a22_room_profile.py').write_bytes(Path(__file__).read_bytes())
    save_json(profile / 'schema.json', schema())
    save_json(profile / 'instrumentation.json', summary)
    source_hashes = {name: sha(out / name) for name in parent['source']}
    input_hashes = {name: sha(out / name) for name in parent['inputs']}
    input_hashes.update({p.relative_to(out).as_posix(): sha(p) for p in profile.iterdir() if p.is_file()})
    with (out / 'build.log').open('w', encoding='utf-8') as stream:
        subprocess.run([sys.executable, '-B', '-X', 'utf8', str(out / 'tools/build_mod.py'),
                        '--java', str(JAVA), '--amxmlc', str(SDK / 'bin/amxmlc.bat'),
                        '--output', str(out / 'RConnectMod.swf')], cwd=ROOT,
                       stdout=stream, stderr=subprocess.STDOUT, check=True)
    # Publish no prepared receipt if any input or the frozen parent changed
    # during compilation. Leave the failed isolated directory for inspection.
    raw_after, _, _ = read_parent(base)
    require(raw_after == raw, 'Parent manifest changed during build')
    for name, expected in {**source_hashes, **input_hashes}.items():
        require(sha(out / name) == expected, 'Diagnostic input changed during build: ' + name)
    for name, key in (('control.swf', 'control_sha256'), ('native/pfe.swf', 'candidate_game_sha256')):
        require(sha(out / name) == parent[key], 'Copied binary changed: ' + name)
    receipt = dict(parent)
    receipt.update(kind='isolated-a22-room-profile', installed=False, diagnostic_only=True, version=version,
                   parent_candidate_sha256=parent['candidate_sha256'], parent_path=str(base),
                   parent_prepared_sha256=digest(raw), base_prepared_sha256=digest(raw),
                   candidate_sha256=sha(out / 'RConnectMod.swf'), script_sha256=sha(profile / 'prepare_a22_room_profile.py'),
                   diagnostic_changes=changes, source=source_hashes, inputs=input_hashes,
                   build_artifacts={p.relative_to(out).as_posix(): sha(p) for p in
                                    (out / 'build.log', out / 'build/GameCombatStubs.swc') if p.is_file()})
    save_json(out / 'prepared.json', receipt)
    print(json.dumps(dict(summary, candidate_sha256=receipt['candidate_sha256'],
                          prepared_sha256=sha(out / 'prepared.json')), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
