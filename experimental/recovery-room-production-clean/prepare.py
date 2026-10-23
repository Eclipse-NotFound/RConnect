"""Prepare a single clean codec overlay and existing-framework comparison sources.

Source/text only. Does not compile, start AIR, or change frozen/install files.
"""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-room-production-03/src'
OLD_CHECKS = ROOT / 'experimental/recovery-codec-diagnostics/components'
BOUNDARIES = ROOT / 'experimental/recovery-terrain-loop/components'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def replace(s, a, b, count=1):
    assert s.count(a) == count, (a, s.count(a), count)
    return s.replace(a, b)


def write(p, s):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('x', encoding='utf-8', newline='\n') as f:
        f.write(s)


def main():
    source = BASE / 'rconnect/net/RoomCodec.as'
    checks = OLD_CHECKS / 'CodecDiagnosticChecks.as'
    assert sha(source) == '549dbffadf05547509a0c2fe8a3637c0ef089305ebe7637322e6a196c471828c'
    assert sha(checks) == '95be1da8f16b39cb3776e7c0deb5ab6118ca9fe5a1a29d10de07e174523ca453'
    assert not (HERE / 'source-manifest.json').exists()
    old = source.read_text(encoding='utf-8')
    new = old
    for a, b, count in [
        ('   import flash.utils.getTimer;\n', '', 1),
        ('   import rconnect.core.Log;\n', '', 1),
        ('         var started:int=getTimer(),timing:Object={};\n', '', 2),
        (';timing.table=getTimer()-started;', ';', 1),
        (';timing.json=getTimer()-started;', ';', 2),
        (';timing.utf=getTimer()-started;', ';', 2),
        ('timing.bytes=b.length;b.compress();b.position=0;timing.compress=getTimer()-started;', 'b.compress();b.position=0;', 1),
        ('timing.base64=getTimer()-started;b.uncompress();b.position=0;timing.inflate=getTimer()-started;', 'b.uncompress();b.position=0;', 1),
        ('         Log.d("RConnectRoomTiming pack key="+o.key+" ms="+(getTimer()-started)+" chars="+result.length);\n'
         '         timing.total=getTimer()-started;timing.key=o.key;timing.chars=result.length;\n'
         '         Log.d("RConnectRoomTiming encode-stages "+JSON.stringify(timing));\n', '', 1),
        ('         Log.d("RConnectRoomTiming unpack key="+result.key+" ms="+(getTimer()-started)+" bytes="+b.length);\n'
         '         timing.total=getTimer()-started;timing.key=result.key;timing.bytes=b.length;\n'
         '         Log.d("RConnectRoomTiming decode-stages "+JSON.stringify(timing));\n', '', 1),
    ]:
        new = replace(new, a, b, count)
    assert all(x not in new for x in ['getTimer', 'timing', 'Log.'])
    boundary = '      /** Terrain repeats'
    assert new[new.index(boundary):] == old[old.index(boundary):]
    write(HERE / 'src/rconnect/net/RoomCodec.as', new)
    write(HERE / 'source.diff', ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
          fromfile='roomfix3/rconnect/net/RoomCodec.as', tofile='clean/rconnect/net/RoomCodec.as')))

    components = HERE / 'components'
    write(components / 'rconnect/net/RoomCodec.as', new)
    write(components / 'rconnect/net/CodecBefore.as', replace(old, 'public class RoomCodec', 'public class CodecBefore'))
    origins = [source, checks]
    for name in ['rconnect/game/NativeTileState.as', 'rconnect/game/NativeRoomState.as']:
        p = BASE / name
        write(components / name, p.read_text(encoding='utf-8'))
        origins.append(p)
    for name in ['fe/loc/Tile.as', 'fe/unit/Unit.as', 'fe/unit/RConnectUnitAccess.as',
                 'rconnect/game/GameBridge.as', 'rconnect/game/TurretDisplay.as']:
        p = BOUNDARIES / name
        write(components / name, p.read_text(encoding='utf-8'))
        origins.append(p)
    p = OLD_CHECKS / 'rconnect/core/Log.as'
    write(components / 'rconnect/core/Log.as', p.read_text(encoding='utf-8'))
    origins.append(p)

    test = checks.read_text(encoding='utf-8').replace('CodecAfter', 'RoomCodec')
    test = replace(test, '   import rconnect.net.RoomCodec;\n',
        '   import rconnect.net.RoomCodec;\n   import rconnect.game.NativeTileState;\n   import fe.loc.Tile;\n')
    test = replace(test, 'CodecDiagnosticChecks', 'CodecCleanChecks', 2)
    test = replace(test, 'Log.count=0;RoomCodec.timingEnabled=false;', 'Log.count=0;')
    start = '         RoomCodec.timingEnabled=true;Log.count=0;\n'
    end = '         RoomCodec.timingEnabled=false;\n'
    i = test.index(start)
    j = test.index(end, i) + len(end)
    test = test[:i] + (
        '         var crossOld:Object=CodecBefore.unpack(b),crossNew:Object=RoomCodec.unpack(a);\n'
        '         check(canonical(crossOld)==expected && canonical(crossNew)==expected,\n'
        '            label+" old/new cross decoding preserves complete transport semantics");\n'
    ) + test[j:]
    test = replace(test, '         check(RoomCodec.timingEnabled===false,"diagnostic default is off before first use");\n', '')
    test = replace(test, 'native_runtime:false,functional_only:true',
        'native_runtime:false,functional_only:true,native_tile_is_fixture:true,exact_old_new_codec:true')
    test = replace(test, '         var out:Object=',
        '         if(rows.length!=211)check(false,"expected exactly 211 completed checks");\n         var out:Object=')
    anchor = '         for(i=0;i<24;i++)trial('
    addition = '''         // Actual production capture, with only the native Tile boundary reused
         // from the existing terrain component. This is not a running game.
         var loc:Object={spaceX:8,spaceY:4,space:[]};
         for(var x:int=0;x<8;x++) {
            loc.space[x]=[];
            for(var y:int=0;y<4;y++) {
               var t:Tile=new Tile(x-7,y+11);t.front="墙";t.back="背景";t.hp=1000-x*7-y;
               t.phis=(x+y)%2;t.setZForm((x+y)%4);t.opac=(x+y)%5/4;
               loc.space[x][y]=t;
            }
         }
         loc.space[3][2].X=999;loc.space[3][2].phX1=13.125;loc.space[2][1].optional=Number.NaN;
         var table:Object=NativeTileState.capture(loc);
         check(table!=null && table.nativeTileTable===2 && table.rows.length==32,
            "actual current NativeTileState captures the declared native Tile fixture");
         if(table==null)throw new Error("Native tile fixture did not capture");
         trial({key:"native-table-v2",width:8,height:4,tiles:table},"current native tile table v2");
         var v1:Object=JSON.parse(JSON.stringify(table));v1.nativeTileTable=1;
         for(i=0;i<v1.rows.length;i++) {
            var row:Array=v1.rows[i];x=int(i/4);y=i%4;
            for each(var slot:int in v1.grid) {
               var present:Boolean=false;
               for(var n:int=0;n<row.length;n+=2)if(row[n]===slot){present=true;break;}
               if(!present)row.push(slot,loc.space[x][y][v1.names[slot]]);
            }
         }
         delete v1.grid;
         trial({key:"native-table-v1",width:8,height:4,tiles:v1},"legacy native tile table v1");
'''
    assert test.count(anchor) == 1
    test = test.replace(anchor, addition + anchor)
    assert 'timingEnabled' not in test
    write(components / 'CodecCleanChecks.as', test)
    write(HERE / 'component.diff', ''.join(difflib.unified_diff(checks.read_text(encoding='utf-8').splitlines(True),
        test.splitlines(True), fromfile='existing/CodecDiagnosticChecks.as', tofile='components/CodecCleanChecks.as')))
    manifest = dict(base='build/m52/recovery-room-production-03/src',
        source_sha256=sha(source), overlay_sha256=sha(HERE / 'src/rconnect/net/RoomCodec.as'),
        origins={p.relative_to(ROOT).as_posix(): sha(p) for p in origins},
        files={p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()},
        expected_assertions=211, compiled=False, air_started=False, installed=False)
    write(HERE / 'source-manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(overlay_sha256=manifest['overlay_sha256'], expected_assertions=211,
                         compiled=False, air_started=False)))


if __name__ == '__main__':
    main()
