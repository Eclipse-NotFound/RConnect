"""Prepare a sparse recovery-02 overlay and source-derived checks; no Java/AIR."""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-02/src'
NAMES = ['game/ProjectileFrameStream.as', 'game/UnitPresentation.as',
         'game/EnergyImpactVisuals.as', 'game/WallImpactVisuals.as',
         'game/GameBridge.as', 'core/Session.as']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(name, text):
    path = (HERE / name).resolve()
    assert path.is_relative_to(HERE)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', newline='\n')


def replace(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def method(text, name):
    match = re.search(r'(?:public|private) (?:static )?function ' + name + r'\(', text)
    assert match, name
    start = text.index('{', match.start())
    end, depth = start + 1, 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[match.start():end]


def make_frame_probe(text, suffix):
    members = method(text, 'samePoint') + '\n' + method(text, 'after')
    # Count loop-body visits only. The production branch expressions are intact.
    members = replace(members,
        'for each(var point:Object in frames)if(Number(point.at)>stamp)out.push(point);',
        'for each(var point:Object in frames){Counter.' + suffix.lower() +
        '++;if(Number(point.at)>stamp)out.push(point);}')
    if suffix == 'After':
        added = method(text, 'afterWithRevision')
        added = replace(added, 'for each(var point:Object in frames) {',
            'for each(var point:Object in frames) {Counter.after++;')
        members += '\n' + added
    write('components/rconnect/game/Frame' + suffix + '.as',
        'package rconnect.game { public class Frame' + suffix + ' {\n' + members + '\n}}\n')


def make_delta_probes(source, suffix):
    unit = method(source['game/UnitPresentation.as'], 'captureEffects')
    energy = method(source['game/EnergyImpactVisuals.as'], 'captureDelta')
    if suffix == 'Before':
        old = ('for each(var revised:Object in shot.frames)\n'
               '                     if(Number(revised.at)==Number(shot.fastAt) && !ProjectileFrameStream.samePoint(revised,shot.fastPoint)) {points.unshift(revised);break;}')
        unit = replace(unit, old, old.replace('shot.frames)\n', 'shot.frames) {Counter.before++;\n') + '}')
        old = ('for each(var revised:Object in all)\n'
               '               if(Number(revised.at)==Number(record.fastAt) && !ProjectileFrameStream.samePoint(revised,record.fastPoint)) {points.unshift(revised);break;}')
        energy = replace(energy, old, old.replace('in all)\n', 'in all) {Counter.before++;\n') + '}')
    unit = unit.replace('ProjectileFrameStream.', 'Frame' + suffix + '.')
    energy = energy.replace('ProjectileFrameStream.', 'Frame' + suffix + '.')
    write('components/rconnect/game/Energy' + suffix + '.as',
        'package rconnect.game { import flash.utils.Dictionary; public class Energy' + suffix + ' {\n'
        'public var sources:Dictionary=new Dictionary();\n' + energy + '\n}}\n')
    write('components/rconnect/game/Capture' + suffix + '.as',
        'package rconnect.game { import flash.utils.Dictionary; import flash.utils.getTimer;\n'
        'public class Capture' + suffix + ' {\n'
        'public var hostShots:Dictionary=new Dictionary();public var weapons:Array=[];\n'
        'public var energyImpacts:Energy' + suffix + '=new Energy' + suffix + '();public var frameTime:int=900;\n'
        'private function weaponList(u:Object):Array{return weapons;}\n'
        'private static function get(o:Object,k:String):*{return o[k];}\n'
        '// Native captureFlight alone is a fixture: keep class/endpoint fields supplied by each case.\n'
        'private function captureFlight(shot:Object):Object{if(shot.flight==null)return null;var out:Object={};for(var k:String in shot.flight)out[k]=shot.flight[k];return out;}\n'
        + unit + '\n}}\n')


def make_wall_probes(source, suffix):
    wall = source['game/WallImpactVisuals.as'].replace('class WallImpactVisuals', 'class Wall' + suffix).replace(
        'function WallImpactVisuals(', 'function Wall' + suffix + '(')
    marker = '      public function observe(loc:Object,tiles:Array=null):void\n      {'
    wall = replace(wall, marker, '      public var observeCalls:int=0;\n' + marker + '\n         observeCalls++;')
    write('components/rconnect/game/Wall' + suffix + '.as', wall)
    names = ['readTilePatch', 'scanTileReports', 'readWallPaint']
    members = '\n'.join(method(source['game/GameBridge.as'], n) for n in names)
    session = source['core/Session.as']
    start = session.index('               var tpatch:Array = mod.game.readTilePatch();')
    finish = session.index('\n               var nspawn:Array', start)
    pair = session[start:finish]
    write('components/rconnect/game/Calls' + suffix + '.as',
        'package rconnect.game { public class Calls' + suffix + ' {\n'
        'public var loc:Object;public var _wall:Object;public var _terrain:Object;\n' + members + '\n'
        '// This segment is extracted verbatim from Session; envelope/native terrain are fixtures.\n'
        'public function hostPair():Object{var mod:Object={game:this};var usMsg:Object={};\n' + pair + '\nreturn usMsg;}\n}}\n')


def main():
    old = {name: (BASE / 'rconnect' / name).read_text(encoding='utf-8-sig') for name in NAMES}
    new = dict(old)
    frame = '''      /** Same result as after() followed by the first changed same-stamp
       * point. Keep input order, including duplicate or out-of-order samples;
       * only the history traversal is shared. */
      public static function afterWithRevision(frames:Array,stamp:Number,previous:Object,revisionStamp:Number):Array {
         var out:Array=[],revised:Object=null;
         for each(var point:Object in frames) {
            var at:Number=Number(point.at);
            if(at>stamp)out.push(point);
            if(revised==null && previous!=null && at==revisionStamp && !samePoint(point,previous))revised=point;
         }
         if(revised!=null)out.unshift(revised);
         return out;
      }
'''
    new['game/ProjectileFrameStream.as'] = replace(new['game/ProjectileFrameStream.as'],
        '      public static function merge(previous:Array,incoming:Array):Array {',
        frame + '      public static function merge(previous:Array,incoming:Array):Array {')
    start = old['game/UnitPresentation.as'].index('               var points:Array=shot.recorded?ProjectileFrameStream.after(')
    end = old['game/UnitPresentation.as'].index('               var ending:Boolean=', start)
    new['game/UnitPresentation.as'] = replace(new['game/UnitPresentation.as'], old['game/UnitPresentation.as'][start:end],
        '               var points:Array=shot.recorded?ProjectileFrameStream.afterWithRevision(shot.frames as Array,\n'
        '                  fresh||shot.fastAt==null?Number.NEGATIVE_INFINITY:Number(shot.fastAt),\n'
        '                  fresh?null:shot.fastPoint,Number(shot.fastAt)):null;\n')
    start = old['game/EnergyImpactVisuals.as'].index('            var points:Array=ProjectileFrameStream.after(')
    end = old['game/EnergyImpactVisuals.as'].index('            var ending:Boolean=', start)
    new['game/EnergyImpactVisuals.as'] = replace(new['game/EnergyImpactVisuals.as'], old['game/EnergyImpactVisuals.as'][start:end],
        '            var points:Array=ProjectileFrameStream.afterWithRevision(all,\n'
        '               record.fastAt==null?Number.NEGATIVE_INFINITY:Number(record.fastAt),record.fastPoint,Number(record.fastAt));\n')
    new['game/GameBridge.as'] = replace(new['game/GameBridge.as'],
        '         var paint:Object=_wall.report(loc);', '         var paint:Object=_wall.report(loc,false);')
    new['game/GameBridge.as'] = replace(new['game/GameBridge.as'],
        'public function readWallPaint():Array {return _wall.snapshot(loc);}',
        'public function readWallPaint(observeNow:Boolean=true):Array {return _wall.snapshot(loc,observeNow);}')
    new['game/WallImpactVisuals.as'] = replace(new['game/WallImpactVisuals.as'],
        'public function snapshot(loc:Object):Array\n      {\n         observe(loc);var s:Object=',
        'public function snapshot(loc:Object,observeNow:Boolean=true):Array\n      {\n         if(observeNow)observe(loc);var s:Object=')
    new['core/Session.as'] = replace(new['core/Session.as'],
        '               usMsg.wallPaint=mod.game.readWallPaint();',
        '               // readTilePatch just observed native contacts and this terrain delta.\n'
        '               usMsg.wallPaint=mod.game.readWallPaint(false);')
    for name in NAMES:
        write('src/rconnect/' + name, new[name])
    for suffix, source in [('Before', old), ('After', new)]:
        make_frame_probe(source['game/ProjectileFrameStream.as'], suffix)
        make_delta_probes(source, suffix)
        make_wall_probes(source, suffix)
    write('components/rconnect/net/RoomCodec.as', (BASE / 'rconnect/net/RoomCodec.as').read_text(encoding='utf-8-sig'))
    write('components/rconnect/game/GameBridge.as', '''package rconnect.game { public class GameBridge {
      public static function probe(o:Object,k:String):*{try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}
   }}
''')
    write('components/rconnect/core/Log.as', 'package rconnect.core {public class Log {public static function d(s:String):void{}}}\n')
    write('components/rconnect/game/Counter.as', 'package rconnect.game {public class Counter {public static var before:int=0,after:int=0;}}\n')
    patch = ''.join(''.join(difflib.unified_diff(old[n].splitlines(True), new[n].splitlines(True),
        fromfile='recovery-02/src/rconnect/' + n, tofile='overlay/src/rconnect/' + n)) for n in NAMES)
    write('proposal.patch', patch)
    audit = dict(base=str(BASE), files={n:dict(base_sha256=sha(BASE/'rconnect'/n),
        overlay_sha256=sha(HERE/'src/rconnect'/n)) for n in NAMES},
        compiled=False, AIR_started=False, JVM_started=False,
        boundaries=['Source-derived capture methods; native weapon discovery/captureFlight/terrain producer are fixtures.',
                    'Real WallImpactVisuals/RoomCodec methods; only observation counters added to copied test classes.',
                    'Extracted history loops have only loop-visit counters added; production branch expressions are unchanged.'])
    write('inputs.json', json.dumps(audit, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(overlay_files=len(NAMES), compiled=False, JVM_started=False, AIR_started=False)))


if __name__ == '__main__':
    main()
