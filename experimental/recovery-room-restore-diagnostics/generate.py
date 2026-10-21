"""Generate insertion-only diagnostic overlays; no compiler, AIR or deployment."""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-07'
HELPER = 'rconnect/game/RestoreCostTrace.as'
FILES = ['RConnectMod.as', 'rconnect/core/RoomSync.as', 'rconnect/game/GameBridge.as',
         'rconnect/game/NativeRoomState.as', 'rconnect/game/UnitPresentation.as',
         'rconnect/game/TerrainSync.as', 'rconnect/game/NativeTileState.as',
         'rconnect/game/RoomTerrainView.as', 'rconnect/net/RoomCodec.as']
MARK = re.compile(r'/\*RCRESTORE:(\d+):BEGIN\*/.*?/\*RCRESTORE:\1:END\*/', re.S)
sequence = 0


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def block(code):
    global sequence
    sequence += 1
    return f'/*RCRESTORE:{sequence}:BEGIN*/\n{code}\n/*RCRESTORE:{sequence}:END*/'


def stripped(text):
    value = MARK.sub('', text)
    assert 'RCRESTORE:' not in value, 'Unpaired instrumentation marker'
    return value


def mask(text):
    return re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27',
                  lambda m: ' ' * len(m.group()), text)


def close_brace(text, start):
    clean = mask(text)
    assert clean[start] == '{'
    depth, end = 1, start + 1
    while depth:
        assert end < len(clean), 'Unclosed AS method/block'
        depth += (clean[end] == '{') - (clean[end] == '}')
        end += 1
    return end - 1


def method(text, name):
    matches = list(re.finditer(r'\bfunction\s+' + re.escape(name) + r'\(', mask(text)))
    assert len(matches) == 1, name
    start = text.index('{', matches[0].end())
    return start, close_brace(text, start)


def add(text, anchor, code, after=True):
    assert text.count(anchor) == 1, anchor
    at = text.index(anchor) + (len(anchor) if after else 0)
    return text[:at] + block(code) + text[at:]


def around(text, anchor, label, tail=''):
    assert text.count(anchor) == 1, anchor
    return text.replace(anchor, block(f'RestoreCostTrace.begin("{label}");try {{') + anchor +
                        block(f'}} finally {{RestoreCostTrace.end("{label}");}}\n{tail}'), 1)


def wrap(text, name, label, fallback=None):
    start, end = method(text, name)
    suffix = f'}} finally {{RestoreCostTrace.end("{label}");}}'
    # ASC's return analysis can reject a return inside an added try/finally.
    # These fallbacks are unreachable on all original paths of value methods.
    if fallback is not None:
        suffix += '\nreturn ' + fallback + ';'
    return text[:start+1] + block(f'RestoreCostTrace.begin("{label}");try {{') + text[start+1:end] + \
        block(suffix) + text[end:]


def wrap_region(text, anchor, before, after):
    assert text.count(anchor) == 1, anchor
    start = text.index('{', text.index(anchor) + len(anchor))
    end = close_brace(text, start)
    return text[:start+1] + block(before) + text[start+1:end] + block(after) + text[end:]


def transform(name, text):
    if name in ('RConnectMod.as', 'rconnect/core/RoomSync.as', 'rconnect/net/RoomCodec.as'):
        at = text.index('   import ')
        text = text[:at] + block('   import rconnect.game.RestoreCostTrace;') + text[at:]
    if name == 'RConnectMod.as':
        return add(text, '         this.stage = main["stage"] as Stage;', 'RestoreCostTrace.enable(this.stage);')
    if name == 'rconnect/core/RoomSync.as':
        _, end = method(text, 'sendReady')
        text = text[:end] + block('} finally {RestoreCostTrace.end("room.ready");}\nRestoreCostTrace.phase("ready-sent");') + text[end:]
        text = add(text, '         var keepOwner:Boolean=ready && authority && currentSettledRoom() && hostInfo!=null && String(hostInfo.roomKey)!=settledKey;',
                   'RestoreCostTrace.transaction("join",game.roomKey(),epoch,pending);\nRestoreCostTrace.phase("ready-begin");\nRestoreCostTrace.begin("room.ready");try {', after=False)
        text = wrap_region(text,
            'else if(msg.op=="grant" && int(msg.barrier)==pending && int(msg.epoch)==epoch && acceptsJoinGrant(msg))',
            'RestoreCostTrace.transaction("join",String(msg.key),epoch,pending);\nRestoreCostTrace.phase("grant-begin");\nRestoreCostTrace.begin("room.grant");try {',
            'RestoreCostTrace.postGrant();\n} finally {RestoreCostTrace.end("room.grant");}')
        _, end = method(text, 'commit')
        text = text[:end] + block('RestoreCostTrace.postGrant();\n} finally {RestoreCostTrace.end("room.commit");}') + text[end:]
        text = add(text, '         var myKey:String=game.roomKey(),theirKey:String=String(msg.info.roomKey);',
            'RestoreCostTrace.transaction("host",myKey,epoch,pending);\nRestoreCostTrace.phase("commit-begin");\nRestoreCostTrace.begin("room.commit");try {')
        anchor='catch(error:Error){fail(error);}'
        assert text.count(anchor)==4
        text=re.sub(re.escape(anchor),lambda m:'catch(error:Error){'+block('RestoreCostTrace.abort();')+'fail(error);}',text)
        return wrap(text, 'present', 'room.present')
    if name == 'rconnect/game/GameBridge.as':
        for name2, label, value in [('checkpoint','checkpoint.total','null'), ('roomRole','restore.roomRole',None),
                ('restoreCheckpoint','restore.total',None), ('applyUnitsSync','mirror.applyUnits','null'),
                ('onMirrorFrame','frame.rcMirror',None), ('onMirrorMaskFrame','frame.rcMask',None),
                ('onPerceptionFrame','frame.rcPerception',None), ('onVisForceFrame','frame.rcView',None)]:
            text = wrap(text, name2, label, value)
        text = around(text, '         var list:Array=readUnitsSnapshot() || [],used:Dictionary=new Dictionary();', 'checkpoint.unitSnapshot')
        text = around(text, '         var objects:Array=readObjsSnapshot() || [];used=new Dictionary();', 'checkpoint.objectSnapshot')
        text = around(text, '            reconcileObjs(s.objs as Array);', 'restore.reconcileObjects')
        text = add(text, '         var timingStart:int=getTimer(),timing:Object={authority:authority,foreign:foreign,retained:retained};',
            'RestoreCostTrace.count(authority?"restore.authority":"restore.mirror");\nRestoreCostTrace.count(foreign?"restore.foreign":"restore.local");\nRestoreCostTrace.count(retained?"restore.retained":"restore.full");')
        start = '            for each(var previous:Object in (loc.units as Array).concat())'
        end = '            _units.clearRoom(loc);'
        segment = text[text.index(start):text.index(end, text.index(start))+len(end)]
        text = around(text, segment, 'restore.removeForeignUnits')
        text = add(text, '               loc.remObj(previous);var index:int=loc.units.indexOf(previous);if(index>=0)loc.units.splice(index,1);', 'RestoreCostTrace.count("unit.removedForeign");')
        text = around(text, '            var unit:Object=_units.resolve(us,loc.units,used);', 'unit.resolve',
                      'RestoreCostTrace.count(unit==null?"unit.missing":"unit.resolved");\nRestoreCostTrace.count(Number(us.sost)>=3?"unit.deadSnapshot":"unit.liveSnapshot");')
        for anchor,label in [
            ('               var cls:Class=main.loaderInfo.applicationDomain.getDefinition(String(us.cls)) as Class;', 'unit.classLookup'),
            ('               var map:XML=us.runtime.internal.xml==null?<unit/>:new XML(us.runtime.internal.xml);\n               if(int(us.tr)>0)map.@tr=int(us.tr);','unit.constructorXML'),
            ('               unit=new cls(NativeRoomState.constructorId(us),Number(loc.locDifLevel),map,null);','unit.constructor'),
            ('unit.putLoc(loc,Number(us.x),Number(us.y));','unit.putLoc'), ('loc.addObj(unit);','unit.addObj'),
            ('            NativeRoomState.restoreUnit(unit,us.runtime,main);','unit.restoreCall'),
            ('            RConnectAnimationAccess.receive(unit as Unit,us.pose,String(us.anim));','unit.pose'),
            ('            if(us.body!=null)TurretDisplay.receive(unit,us.body);','unit.body'),
            ('                     hit = new MirrorHitUnit(target);','mirror.hitConstructor')]:
            text = around(text, anchor, label,
                'RestoreCostTrace.count("unit.created");RestoreCostTrace.createdClass(String(us.cls));' if label=='unit.constructor' else
                'RestoreCostTrace.count("mirror.hitCreated");' if label=='mirror.hitConstructor' else '')
        start = '         for each(unit in (loc.units as Array).concat())'
        end = '         timing.units=getTimer()-timingStart;'
        segment = text[text.index(start):text.index(end,text.index(start))]
        text = around(text, segment, 'restore.pruneUnits')
        text = add(text, '{loc.remObj(unit);index=loc.units.indexOf(unit);if(index>=0)loc.units.splice(index,1);}', 'RestoreCostTrace.count("unit.pruned");', after=False)
        # Move the counter into the original conditional body, preserving its guard.
        pattern = re.compile(r'(/\*RCRESTORE:\d+:BEGIN\*/\nRestoreCostTrace.count\("unit.pruned"\);\n/\*RCRESTORE:\d+:END\*/)(\{loc.remObj\(unit\);)')
        text, n = pattern.subn(lambda m:m[2]+m[1],text);assert n==1
        start = '         for each(var loot:Array in lootWalk())loc.remObj(loot[0]);'
        end = '         if(!authority)applyUnitsSync(s.units as Array);'
        segment=text[text.index(start):text.index(end,text.index(start))]
        text=around(text,segment,'restore.loot')
        # Same statement appears twice: both calls are timed without deduplicating.
        anchor='_mirrorMasks.prepare(target);'
        assert text.count(anchor)==2
        text=re.sub(re.escape(anchor),lambda m:block('RestoreCostTrace.begin("mirror.maskPrepare");try {')+anchor+
                          block('} finally {RestoreCostTrace.end("mirror.maskPrepare");}'),text)
        text=around(text,'                  _mirrorMasks.register(target,hit);','mirror.maskRegister')
        return text
    if name == 'rconnect/game/NativeRoomState.as':
        text=wrap(text,'unit','checkpoint.unitRuntime','null')
        text=wrap(text,'restoreUnit','unit.restoreRuntime')
        for anchor,label in [('         restore(u,s.p);','unit.restoreScalars'),
            ('         RConnectUnitAccess.restore(u as Unit,s.internal);','unit.restoreInternal'),
            ('               w=factory.create(u,String(gun.p.id),int(gun.p.variant));','gun.constructor'),
            ('restore(w,gun.p);','gun.restoreScalars')]:
            text=around(text,anchor,label)
        text=add(text,'            var w:Object=children[int(gun.slot)];','RestoreCostTrace.count("gun.visited");')
        return add(text,'               children[int(gun.slot)]=w;','RestoreCostTrace.count("gun.created");')
    if name == 'rconnect/game/UnitPresentation.as':
        text=wrap(text,'apply','presentation.apply')
        text=add(text,'               var children:Array=get(u,"childObjs") as Array;', 'RestoreCostTrace.count("presentation.newState");',after=False)
        return around(text,'                     var replacement:Object=factory.create(u,String(s.id),int(s.variant));',
                      'presentation.gunConstructor','if(replacement!=null)RestoreCostTrace.count("presentation.gunCreated");')
    if name == 'rconnect/game/TerrainSync.as':
        text=wrap(text,'checkpoint','terrain.capture','null')
        text=wrap(text,'restoreCheckpoint','terrain.restore')
        return wrap(text,'enter','terrain.enter')
    if name == 'rconnect/game/NativeTileState.as':
        text=wrap(text,'capture','terrain.nativeCapture','null')
        return wrap(text,'restore','terrain.nativeRestore')
    if name == 'rconnect/game/RoomTerrainView.as':
        text=wrap(text,'RoomTerrainView','terrain.viewCapture')
        text=wrap(text,'unchanged','terrain.viewCompare','false')
        return wrap(text,'refresh','terrain.viewRefresh')
    if name == 'rconnect/net/RoomCodec.as':
        text=wrap(text,'pack','codec.pack','null')
        return wrap(text,'unpack','codec.unpack','null')
    raise AssertionError(name)


def main():
    manifest=read(BASE/'prepared.json')
    assert manifest['compiled'] and manifest['version']=='0.2.24-recovery7'
    assert sha((BASE/'RConnectMod.swf').read_bytes())==manifest['sha256']
    receipt=dict(base=str(BASE.relative_to(ROOT)), base_sha256=manifest['sha256'],
                 base_manifest_sha256=sha((BASE/'prepared.json').read_bytes()),
                 diagnostic_only=True, compiled=False, air_started=False, performance_qualified=False,
                 source={}, overlay={}, stripped_equal={}, helper=HELPER)
    differences=[]
    for name in FILES:
        original=(BASE/'src'/name).read_bytes()
        assert sha(original)==manifest['source'][name],name
        assert b'\r' not in original,'Require exact LF baseline'
        old=original.decode('utf-8')
        new=transform(name,old)
        assert stripped(new).encode('utf-8')==original,name
        dest=HERE/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(new.encode('utf-8'))
        receipt['source'][name]=sha(original)
        receipt['overlay'][name]=sha(dest.read_bytes())
        receipt['stripped_equal'][name]=True
        differences.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                           fromfile='recovery07/'+name,tofile='diagnostic/'+name))
    receipt['overlay'][HELPER]=sha((HERE/'src'/HELPER).read_bytes())
    receipt['inserted_blocks']=sequence
    receipt['generator_sha256']=sha(Path(__file__).read_bytes())
    (HERE/'diagnostic.patch').write_text(''.join(differences),encoding='utf-8')
    (HERE/'inputs.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(files=len(receipt['overlay']), stripped_equal=len(receipt['stripped_equal']),
                         blocks=sequence,compiled=False,air_started=False)))


if __name__=='__main__':main()
