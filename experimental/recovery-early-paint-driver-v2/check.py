"""Pure source checks for the small v2 adapter; never compile or run AIR."""
import ast,json
from binding import HERE,V1,HOST_V2,KIND,sha,load,v1

def main():
    checks=[]
    def check(value,label):
        assert value,label
        checks.append(label)
    pins=v1.verify_tools()
    frozen=load('frozen_paint_driver_v1_checks',V1/'check.py')
    frozen.main()
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
    check(True,'all v2 Python files parse')
    check(KIND=='scene-native-input-early-paint-driver-v2','distinct diagnostic metadata kind')
    source=(HERE/'prepare.py').read_text(encoding='utf-8')
    check('recipe.HERE=V1' in source,'reuse frozen AS files without edits')
    check('recipe.KIND=KIND' in source and 'recipe.verify_tools=preparation_bindings' in source,
          'only diagnostic kind and exact admission are adapted')
    check('subprocess' not in source,'adapter adds no process or runtime path')
    check(not (HERE/'tests').exists(),'no duplicate AS source tree')
    check(pins['sources']['tests/FirstRasterSceneProbe.as']==sha(V1/'tests/FirstRasterSceneProbe.as'),
          'original assertion-preserving probe exact')
    check(pins['sources']['tests/PaintTimingBuffer.as']==sha(V1/'tests/PaintTimingBuffer.as'),
          'same bounded callback source')
    if (HERE/'inputs.json').exists():
        from binding import verify_tools,preparation_bindings
        own=verify_tools();combined=preparation_bindings()
        check(combined['paint_contract']==str(HOST_V2/'prepared.json'),'prepared metadata binds v2 contract')
        check(combined['paint_source']==str(HOST_V2/'src/fe/graph/Grafon.as'),'prepared metadata binds v2 source')
        check(combined['originals'][str(HERE/'inputs.json')]==sha(HERE/'inputs.json'),'adapter admission pinned in source inputs')
        check(combined['sources']==pins['sources'],'all original observer source fingerprints unchanged')
    print(json.dumps(dict(v2_passed=len(checks),checks=checks,compiled=False,air_run=False,
                         performance_qualified=False),ensure_ascii=False))

if __name__=='__main__':main()
