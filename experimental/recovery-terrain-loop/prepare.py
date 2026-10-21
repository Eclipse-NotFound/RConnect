"""Prepare/verify a single-file recovery-09 terrain proposal; no JVM/AIR/process.

--materialize writes only new files in this proposal. The default is read-only.
Components use the actual complete old/new NativeTileState classes together,
plus the exact NativeRoomState and RoomCodec. Adjacent native types are fixtures.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-09'
REL = 'rconnect/game/NativeTileState.as'
BASE_SWF = '1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf'
BASE_SOURCE = 'dab683e9d14e18e8b7e35a917da8a7e237391b602f43d315661fd0d11ce8cae5'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)


def transformed(text):
    text = replace_once(text,
        'private static function gridDefaults(values:Array,base:Array,names:Array,grid:Array,x:int,y:int):void {\n'
        '         for each(var slot:int in grid) {\n'
        '            var kind:int=coordinate(names[slot]);\n'
        '            values[slot]=base[slot]+(kind%2==1?x:y)*(kind<=2?1:40);\n'
        '         }\n      }',
        '''/** Per-call metadata only: no room/table survives this operation. */
      private static function gridPlan(names:Array,grid:Array):Vector.<int> {
         var plan:Vector.<int>=new Vector.<int>();
         for each(var slot:int in grid) {
            var kind:int=coordinate(names[slot]);
            plan.push(slot,kind%2==1?1:0,kind<=2?1:40);
         }
         return plan;
      }
      private static function gridDefaults(values:Array,base:Array,plan:Vector.<int>,x:int,y:int):void {
         for(var i:int=0;i<plan.length;i+=3) {
            var slot:int=plan[i];
            // Preserve base + coordinate * step (and its floating-point order).
            values[slot]=base[slot]+(plan[i+1]==1?x:y)*plan[i+2];
         }
      }''')
    text = replace_once(text,
        'if(coordinate(names[slot]) && base[slot] is Number && base[slot]===int(base[slot]))grid.push(slot);\n         for(var x:int',
        'if(coordinate(names[slot]) && base[slot] is Number && base[slot]===int(base[slot]))grid.push(slot);\n'
        '         var plan:Vector.<int>=gridPlan(names,grid);\n         for(var x:int')
    text = replace_once(text, 'gridDefaults(defaults,base,names,grid,x,y);', 'gridDefaults(defaults,base,plan,x,y);')
    text = replace_once(text,
        'var allowed:Object=fieldTypes(loc.space[0][0]),required:Object={},slots:Object={},name:String,i:int;',
        'var allowed:Object=fieldTypes(loc.space[0][0]),required:Object={},slots:Object={},name:String,i:int;\n'
        '         var slotTypes:Vector.<String>=new Vector.<String>(table.names.length,true);\n'
        '         var slotRequired:Vector.<Boolean>=new Vector.<Boolean>(table.names.length,true);')
    text = replace_once(text, 'slots[field]=i;',
        'slots[field]=i;slotTypes[i]=allowed[field];slotRequired[i]=Boolean(required[field]);')
    text = replace_once(text,
        'var height:int=int(loc.spaceY),row:*,tile:Object,slot:*,seen:Object,value:*,index:int=0;',
        'var height:int=int(loc.spaceY),row:*,tile:Object,slot:*,value:*,index:int=0;\n'
        '         // One marker vector replaces a fresh lookup object for each row.\n'
        '         // index has already advanced to a nonzero row number before use.\n'
        '         var seen:Vector.<int>=new Vector.<int>(table.names.length,true);\n'
        '         var plan:Vector.<int>=gridPlan(table.names,grid);')
    text = replace_once(text, '            seen={};\n', '')
    text = replace_once(text, 'seen[slot]===true', 'seen[int(slot)]==index')
    text = replace_once(text,
        '!matchesType(value,allowed[table.names[int(slot)]]) || (value==null && required[table.names[int(slot)]]))',
        '!matchesType(value,slotTypes[int(slot)]) || (value==null && slotRequired[int(slot)]))')
    text = replace_once(text, 'seen[slot]=true;', 'seen[int(slot)]=index;')
    text = replace_once(text, 'gridDefaults(values,table.base,table.names,grid,x,y);', 'gridDefaults(values,table.base,plan,x,y);')
    return text


def planned():
    assert sha(BASE/'RConnectMod.swf') == BASE_SWF
    assert sha(BASE/'src'/REL) == BASE_SOURCE
    text = (BASE/'src'/REL).read_text(encoding='utf-8-sig')
    candidate = transformed(text)
    control = replace_once(text, 'public class NativeTileState {', 'public class ControlNativeTileState {')
    files = {
        'src/'+REL: candidate.encode(),
        'components/'+REL: candidate.encode(),
        'components/rconnect/game/ControlNativeTileState.as': control.encode(),
        'proposal.patch': ''.join(difflib.unified_diff(text.splitlines(True), candidate.splitlines(True),
            fromfile='recovery-09/'+REL, tofile='recovery-terrain-loop/'+REL)).encode(),
    }
    inputs = {str(BASE/'RConnectMod.swf'): BASE_SWF, str(BASE/'src'/REL): BASE_SOURCE,
              str(BASE/'prepared.json'): sha(BASE/'prepared.json')}
    for name in ('rconnect/game/NativeRoomState.as','rconnect/net/RoomCodec.as'):
        p = BASE/'src'/name
        files['components/'+name] = p.read_bytes(); inputs[str(p)] = sha(p)
    fixture = ROOT/'tests/room-entry'
    for name in ('fe/loc/Tile.as','fe/unit/Unit.as','fe/unit/RConnectUnitAccess.as',
                 'rconnect/game/TurretDisplay.as','rconnect/core/Log.as'):
        p = fixture/name
        files['components/'+name] = p.read_bytes(); inputs[str(p)] = sha(p)
    return files, inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--materialize', action='store_true')
    args = parser.parse_args()
    files, inputs = planned()
    if args.materialize:
        assert not (HERE/'inputs.json').exists(), 'Proposal already frozen; verify, do not overwrite'
        for name, body in files.items():
            p = HERE/name; assert not p.exists(), name
            p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(body)
        outputs = {p.relative_to(HERE).as_posix(): sha(p)
                   for p in HERE.rglob('*') if p.is_file() and p.name!='inputs.json'}
        (HERE/'inputs.json').write_text(json.dumps(dict(kind='terrain-loop-proposal',
            base_swf_sha256=BASE_SWF,input_sources=inputs,outputs=outputs,
            expected_assertions=67, compiled=False,air_started=False,performance_qualified=False),
            ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    else:
        manifest=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
        assert manifest['input_sources']==inputs
        for name, body in files.items(): assert (HERE/name).read_bytes()==body,name
        for name, digest in manifest['outputs'].items(): assert sha(HERE/name)==digest,name
    print(json.dumps(dict(verified=True,generated=args.materialize,production_overlays=1,
        actual_old_new=True,jvm_started=False,air_started=False),ensure_ascii=False))


if __name__=='__main__': main()
