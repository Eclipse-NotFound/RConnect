"""Offline source integrity only. Never executes AS, a compiler, AIR or a subprocess."""
import ast
import importlib.util
import json
import re
from pathlib import Path

HERE=Path(__file__).resolve().parent


def main():
    spec=importlib.util.spec_from_file_location('terrain_loop_source_recipe', HERE/'prepare.py')
    recipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(recipe)
    files,inputs=recipe.planned()
    manifest=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
    assert manifest['input_sources']==inputs
    for name,body in files.items():assert (HERE/name).read_bytes()==body,name
    for name,digest in manifest['outputs'].items():assert recipe.sha(HERE/name)==digest,name
    before=(recipe.BASE/'src'/recipe.REL).read_text(encoding='utf-8-sig')
    control=(HERE/'components/rconnect/game/ControlNativeTileState.as').read_text(encoding='utf-8')
    assert control==before.replace('public class NativeTileState {','public class ControlNativeTileState {')
    candidate=(HERE/'src'/recipe.REL).read_text(encoding='utf-8')
    assert candidate==recipe.transformed(before)
    assert (HERE/'components'/recipe.REL).read_bytes()==(HERE/'src'/recipe.REL).read_bytes()
    assert candidate.count('seen:Vector.<int>')==1 and 'seen={}' not in candidate
    validation=candidate.index('// Validate the entire transfer')
    write=candidate.index('var values:Array=table.base.concat();index=0;')
    assert validation<write and 'after(tile,x,y);' in candidate[write:]
    assert 'var opacity:Number=Number(tile.opac);tile.setZForm(int(tile.zForm));tile.opac=opacity;' in candidate[write:]
    fixture=(HERE/'components/TerrainLoopChecks.as').read_text(encoding='utf-8')
    sections=re.findall(r'var cases:Array=(\[[\s\S]*?\]);',fixture)
    counts=[len(json.loads(s)) for s in sections]
    assert counts==[40,10],counts
    # A static planned count, not an assertion of AS execution success.
    planned=3+9+counts[0]+counts[1]+2+3
    assert planned==manifest['expected_assertions']==67
    constructor=fixture.split('public function TerrainLoopChecks()',1)[1].split('private function enqueue',1)[0]
    assert 'enqueue("small-cases-prepare",run)' in constructor and 'try {run();}' not in constructor
    assert 'addEventListener(Event.ENTER_FRAME,onFrame)' in constructor
    assert 'resolvePath("progress.json")' in fixture and 'progress("finished")' in fixture
    assert 'bench.tableRowsChecked==30000 && bench.cellsChecked==30000' in fixture
    assert 'bench.callsOld==30000 && bench.callsNew==30000' in fixture
    assert 'bench.index<30000 && getTimer()-stepStart<8' in fixture
    for method,receiver in [('capture','bench.loc'),('restore','bench.oldRoom'),('restore','bench.newRoom')]:
        assert re.search(r'start=getTimer\(\);[^\n]*\.'+method+r'\('+re.escape(receiver),fixture)
    assert 'canon(a)==canon(b)' not in fixture and 'canon(tableHeader(bench.a))==canon(tableHeader(bench.b))' in fixture
    assert 'NativeRoomState.scalars(bench.' not in fixture and 'canon(bench.a.rows' not in fixture
    assert 'sample:Object=NativeRoomState.scalars(first)' in fixture and 'description:XML=describeType(first)' in fixture
    assert 'String(description.@isDynamic)!="false"' in fixture and 'description.accessor.length()!=0' in fixture
    assert 'old.constructor===Tile && next.constructor===Tile' in fixture
    assert 'bench.scalarValuesCompared==30000*scalarFields.length && bench.referencesChecked==30000' in fixture
    assert 'key==lastProgress && at-lastProgressAt<1000' in fixture
    assert 'old.door===oldRef[1] && old.trap===oldRef[2]' in fixture
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'))
    print(json.dumps(dict(source_integrity_passed=True,planned_assertions=planned,
        actual_as_checks_run=0,actual_old_new_whole_classes=True,jvm_started=False,
        air_started=False,performance_qualified=False)))


if __name__=='__main__':main()
