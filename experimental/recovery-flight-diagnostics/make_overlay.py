"""Materialize a diagnostic-only sparse overlay; no compiler/process runner.

Every insertion is delimited. Removing diagnostic spans must reconstruct each
recovery-05 / drivers-09 input byte-for-byte after newline normalization.
"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-05/src'
DRIVER = ROOT / 'build/m52/recovery-drivers-09/tests/NativeFlightContinuityTestDoc.as'
BEGIN = '// FLIGHT_DIAGNOSTIC_BEGIN'
END = '// FLIGHT_DIAGNOSTIC_END'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def block(code):
    return BEGIN + '\n' + code.rstrip() + '\n' + END + '\n'


def add_before(s, anchor, code):
    assert s.count(anchor) == 1, anchor
    return s.replace(anchor, block(code) + anchor)


def add_after(s, anchor, code):
    assert s.count(anchor) == 1, anchor
    return s.replace(anchor, anchor + block(code))


def plain(s):
    return re.sub(r'// FLIGHT_DIAGNOSTIC_BEGIN\n.*?// FLIGHT_DIAGNOSTIC_END\n', '', s, flags=re.S)


def motion(s):
    s = add_after(s, '   import flash.utils.Dictionary;\n', '   import rconnect.diagnostics.FlightDiagnostics;')
    s = add_before(s, '         var copy:Object={};for(var key:String in snap)copy[key]=snap[key];snap=copy;\n',
        '         if(FlightDiagnostics.sink!=null)diagnoseMotion(1,now,Number(snap.sampleTime),NaN);')
    s = add_after(s, '         if(frames.length>32)preceding=frames.shift();\n',
        '         if(FlightDiagnostics.sink!=null)diagnoseMotion(2,now,stamp,NaN);')
    s = add_after(s, '         cursor=Math.min(cursor,Number(latest.at));\n',
        '         if(FlightDiagnostics.sink!=null)diagnoseMotion(3,now,Number(latest.at),wanted);')
    s = add_before(s, '      private function delay():Number {\n', '''      // Observation only: sourceTime/currentSample are not sampled again.
      private function diagnoseMotion(op:int,now:int,stamp:Number,wanted:Number):void {
         FlightDiagnostics.motion(this,op,now,cursor,offset,stamp,sampledAt,arrivedAt,
            frames.length,delay(),interval,(immediateStart?1:0)+(enemyRecovery?2:0)+(bufferLimit>0?4:0),
            wanted,playbackRate,state==null?NaN:Number(state.x),state==null?NaN:Number(state.y),latestSampleTime);
      }
''')
    return s


def stream(s):
    s = add_after(s, 'package rconnect.game {\n', '   import rconnect.diagnostics.FlightDiagnostics;')
    s = add_after(s, '         state.motion=motion;state.delay=delay;state.offset=isFinite(detached)?detached:offset;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.clock(state,motion,1,now,Number(state.offset),delay,Number(state.clockAt),detached,offset);')
    s = add_after(s, '         state.clockAt=now;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.clock(state,null,2,now,Number(state.offset),Number(state.delay),Number(state.clockAt),Number(state.detachedOffset));')
    s = add_after(s, '            state.detachedOffset=Number(state.detachedOffset)+elapsed;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.clock(state,state.motion,3,-1,Number(state.offset),Number(state.delay),Number(state.clockAt),Number(state.detachedOffset));')
    return s


def projectiles(s):
    s = add_after(s, '   import rconnect.core.ProjectileGrip;\n', '   import rconnect.diagnostics.FlightDiagnostics;')
    s = add_after(s, '                     existing.s=update;existing.updated=now;existing.sourceStamp=source;\n',
        '                     if(FlightDiagnostics.sink!=null)FlightDiagnostics.projectileReceive(existing,owner,motion,player,source,int(event.seq),String(update.cls),key,update.frames as Array,Number(update.end));')
    s = add_after(s, '                  ProjectileFrameStream.receiveClock(rec,motion,channel.offset,player?100:300,now);\n',
        '                  if(FlightDiagnostics.sink!=null)FlightDiagnostics.projectileReceive(rec,owner,motion,player,source,int(event.seq),String(s.cls),key,s.frames as Array,Number(s.end));')
    s = add_after(s, '         if(pauseAt>=0)now=Math.min(now,pauseAt);\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.tick(now,active.length,pauseAt);')
    s = add_after(s, '         var s:Object=a.s,list:Array=s.frames as Array,time:Number=ProjectileFrameStream.sourceTime(a,now);\n', '''         if(FlightDiagnostics.sink!=null)FlightDiagnostics.projectileTick(a,now,time,
            int(s.end)>0 && time>=Number(s.end)?2:now-int(a.updated)>15000?3:
            list==null || list.length==0 || time<Number(list[0].at)?0:1,list,Number(s.end));''')
    s = add_before(s, '         var laser:Object=GameBridge.probe(v,"laser");\n         if(laser!=null){laser.scaleX=Number(point.ls);',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.projectileTick(a,now,time,4,list,Number(s.end));')
    # This observation precedes unchanged removal; no lifetime/visibility choice is altered.
    s = add_before(s, '      private function remove(i:int):void {', '''      private function diagnoseRemove(i:int):void {
         if(FlightDiagnostics.sink!=null)FlightDiagnostics.projectileTick(active[i],-1,NaN,5,active[i].s.frames as Array,Number(active[i].s.end));
      }
''')
    # Insert at the sole removal method's body, preserving its original characters.
    anchor = '      private function remove(i:int):void {'
    assert s.count(anchor) == 1
    # A diagnostic span may be embedded on a line; the stripper restores the exact input.
    s = s.replace(anchor, anchor + block('diagnoseRemove(i);'))
    return s


def wall(s):
    s = add_after(s, '   import rconnect.net.RoomCodec;\n', '   import flash.utils.getTimer;\n   import rconnect.diagnostics.FlightDiagnostics;')
    s = add_after(s, '         var cached:Object=wordCache[data];\n', '''         if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,cached!=null && cached.data===data?1:2,
            data,0,wordOrder.length,wordCount,wordChars,0);''')
    s = add_before(s, '         var words:Array=RoomCodec.unpack(data) as Array;\n',
        '         var diagnosticStarted:int=FlightDiagnostics.sink==null?0:getTimer();')
    s = add_after(s, '         var words:Array=RoomCodec.unpack(data) as Array;\n', '''         if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,8,data,getTimer()-diagnosticStarted,
            wordOrder.length,wordCount,wordChars,words==null?-1:words.length);''')
    s = add_before(s, '            var old:Object=wordOrder.shift();delete wordCache[old.data];\n', '''            if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,4,String(wordOrder[0].data),0,
               wordOrder.length,wordCount,wordChars,(wordOrder.length>=WORD_CACHE_ENTRIES?1:0)+
               (wordCount+words.length>WORD_CACHE_WORDS?2:0)+(wordChars+data.length>WORD_CACHE_CHARS?4:0));''')
    s = add_after(s, '         wordCount+=words.length;wordChars+=data.length;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,3,data,0,wordOrder.length,wordCount,wordChars,words.length);')
    s = add_before(s, '               var words:Array=RoomCodec.unpack(String(c.d)) as Array;\n', '''               if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,5,String(c.d),0,wordOrder.length,wordCount,wordChars,0);
               var diagnosticStarted:int=FlightDiagnostics.sink==null?0:getTimer();''')
    s = add_after(s, '               var words:Array=RoomCodec.unpack(String(c.d)) as Array;\n', '''               if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,9,String(c.d),getTimer()-diagnosticStarted,
                  wordOrder.length,wordCount,wordChars,words==null?-1:words.length);''')
    s = add_before(s, '         wordCache=new Dictionary();wordOrder=[];wordCount=0;wordChars=0;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.wall(this,7,null,0,wordOrder.length,wordCount,wordChars,0);')
    return s


def codec(s):
    s = add_after(s, '   import rconnect.core.Log;\n', '   import rconnect.diagnostics.FlightDiagnostics;')
    for operation, word in [('pack', 'encode'), ('unpack', 'decode')]:
        first = next(line + '\n' for line in s.splitlines() if 'Log.d("RConnectRoomTiming ' + operation + ' key=' in line)
        second = next(line + '\n' for line in s.splitlines() if 'Log.d("RConnectRoomTiming ' + word + '-stages ' in line)
        s = add_before(s, first, '         var diagnosticLogStart:int=FlightDiagnostics.sink==null?0:getTimer();')
        s = add_after(s, first, '         var diagnosticLogMiddle:int=FlightDiagnostics.sink==null?0:getTimer();')
        s = add_before(s, second, '         var diagnosticLogSecond:int=FlightDiagnostics.sink==null?0:getTimer();')
        code = '1' if operation == 'pack' else '2'
        size = 'result.length' if operation == 'pack' else 's.length'
        s = add_after(s, second, f'         if(FlightDiagnostics.sink!=null)FlightDiagnostics.codec({code},started,diagnosticLogStart,diagnosticLogMiddle,diagnosticLogSecond,getTimer(),{size},b.length);')
    return s


def driver(s):
    s = add_after(s, '      private var phases:Array=[],phaseSeen:Object={},wire:Array=[];\n',
        '      private var flightDiagnostics:FlightDiagnosticRecorder;')
    s = add_after(s, '      private function setup():void {\n',
        '         flightDiagnostics=new FlightDiagnosticRecorder(mod,host);flightDiagnostics.start();')
    s = add_after(s, '         var enteredAt:int=getTimer(),enteredWall:Number=new Date().time;\n',
        '         if(flightDiagnostics!=null)flightDiagnostics.caseStart(n);')
    s = add_after(s, '         if(phaseSeen[name])return;phaseSeen[name]=true;\n',
        '         if(flightDiagnostics!=null)flightDiagnostics.mark(name);')
    s = add_before(s, '         Log.d("COOP EFFECTS DONE native-flight-continuity "+(host?"host":"join"));\n',
        '         if(flightDiagnostics!=null)flightDiagnostics.finish();')
    return s


def main():
    assert sha(DRIVER) == 'e530e573a67a4e0ed6c5d231be9c134806de999b677adf5b4c1bae12ff26c5bf'
    assert sha(BASE.parent / 'RConnectMod.swf') == 'bf15665a7457eb5997009b45717524512a6622bd8efccc7388e269f14ab045ae'
    prepared = json.loads((BASE.parent / 'prepared.json').read_text(encoding='utf-8'))
    for name, digest in prepared['source'].items():
        assert sha(BASE / name) == digest, 'Frozen recovery-05 source changed: ' + name
    changes = {
        'rconnect/game/RemoteMotion.as': motion,
        'rconnect/game/ProjectileFrameStream.as': stream,
        'rconnect/game/ProjectileVisuals.as': projectiles,
        'rconnect/game/WallImpactVisuals.as': wall,
        'rconnect/net/RoomCodec.as': codec,
    }
    manifest = {'schema': 1, 'purpose': 'diagnostic_only_not_performance_qualification',
                'baseline': str(BASE), 'baseline_prepared_sha256': sha(BASE.parent / 'prepared.json'),
                'baseline_binary_sha256': sha(BASE.parent / 'RConnectMod.swf'), 'files': []}
    for relative, transform in changes.items():
        source, dest = BASE / relative, HERE / 'src' / relative
        original = source.read_text(encoding='utf-8')
        modified = transform(original)
        assert plain(modified) == original, 'Original operations changed: ' + relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(modified, encoding='utf-8', newline='\n')
        manifest['files'].append({'source': str(source), 'source_sha256': sha(source),
                                  'overlay': str(dest.relative_to(HERE)), 'sha256': sha(dest),
                                  'diagnostic_spans': modified.count(BEGIN), 'stripped_equal': True})
    original = DRIVER.read_text(encoding='utf-8')
    modified = driver(original)
    assert plain(modified) == original
    dest = HERE / 'tests' / DRIVER.name
    dest.parent.mkdir(exist_ok=True)
    dest.write_text(modified, encoding='utf-8', newline='\n')
    manifest['driver'] = {'source': str(DRIVER), 'source_sha256': sha(DRIVER),
                          'overlay': str(dest.relative_to(HERE)), 'sha256': sha(dest), 'stripped_equal': True}
    # This new helper/recorder is kept separate from the mechanically instrumented files.
    for relative in ['src/rconnect/diagnostics/FlightDiagnostics.as', 'tests/FlightDiagnosticRecorder.as']:
        path = HERE / relative
        if path.is_file():
            manifest.setdefault('new_files', {})[relative] = sha(path)
    manifest['method_files'] = {name: sha(HERE / name) for name in ['make_overlay.py', 'prepare.py', 'analyze.py', 'test_static.py', 'README.md']}
    (HERE / 'inputs.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'overlay_files': len(changes), 'driver_operations_unchanged': True,
                      'baseline_binary_sha256': manifest['baseline_binary_sha256']}, indent=2))


if __name__ == '__main__':
    main()
