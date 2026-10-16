"""Freeze the installed CS-compatible WallBlend; change only comparison caches."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
WB = ROOT.parent / 'WallBlend'
BASE = ROOT.parent / 'ContinuousScene/build/generated/wb-production'
sys.path.insert(0, str(Path(__file__).parent))
from prepare_a33_rv import compile_as

BASE_SHA = '3b1b40a65d7c57e4711c3861463b3470b0dfc086a8c8c01870c91a2f413da96f'
VERSION = '0.5.5-scene'
HASHES = {
    'BackgroundBlendLayer.as': 'abd0405317a1def7f639fad63bf26fdc111ebb59ece8d7203ca35273976cfe7d',
    'BlendLayer.as': 'd988f57f09ef48b9c0000a5bfe96e4eebe8f10fe05a4101d3aa55ccbe2e65666',
}


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


COMMON = '''        // Only immutable primitive fields can be reused by identity. Unknown
        // mutable values retain the original concatenation on every scan.
        private static function comparisonValue(value:*):Boolean {
            return value==null || value is String || value is Number || value is Boolean;
        }
        private static function sameComparison(a:*,b:*):Boolean {
            return a===b || (a is Number && b is Number && isNaN(a) && isNaN(b));
        }
        private var comparisonValid:Boolean=false;
        private var comparisonFields:Array=[], comparisonCells:Array=[], comparisonSafe:Array=[];
        private var comparisonPrefix:String, comparisonStamp:String;
        private function clearComparison():void {
            comparisonValid=false; comparisonFields=[]; comparisonCells=[]; comparisonSafe=[];
            comparisonPrefix=null; comparisonStamp=null;
        }
'''

BACKGROUND_KEY = '''        private function stateKey(loc:*):String {
            var valid:Boolean=comparisonValid;
            // A failed read/concatenation must not publish a partial scan.
            comparisonValid=false;
            var parts:Array=[loc.homeStable,loc.darkness,loc.lightOn,loc.backwall,loc.transpFon,
                loc.cTransform?loc.cTransform.toString():"",loc.spaceX,loc.spaceY];
            for each(var bo:* in loc.backobjs) parts.push(bo.id,bo.X,bo.Y,bo.scX,bo.scY,bo.frame,bo.sloy,bo.alpha,bo.er);
            var prefix:String=parts.join("|"), dirty:Boolean=!valid || comparisonPrefix!==prefix;
            var count:int=0;
            for(var y:int=0;y<loc.spaceY;++y) for(var x:int=0;x<loc.spaceX;++x) {
                var tile:*=loc.space[x][y], back:*=tile.back, front:*=tile.front, phis:*=tile.phis, shape:*=tile.zForm;
                var offset:int=count*4;
                var same:Boolean=valid && comparisonSafe[count]===true &&
                    back===comparisonFields[offset] && front===comparisonFields[offset+1] &&
                    phis===comparisonFields[offset+2] && shape===comparisonFields[offset+3];
                if(!same && valid && comparisonSafe[count]===true)
                    same=sameComparison(back,comparisonFields[offset]) && sameComparison(front,comparisonFields[offset+1]) &&
                         sameComparison(phis,comparisonFields[offset+2]) && sameComparison(shape,comparisonFields[offset+3]);
                if(!same) {
                    comparisonCells[count]=back+":"+front+":"+phis+":"+shape;
                    comparisonFields[offset]=back; comparisonFields[offset+1]=front;
                    comparisonFields[offset+2]=phis; comparisonFields[offset+3]=shape;
                    comparisonSafe[count]=comparisonValue(back) && comparisonValue(front) && comparisonValue(phis) && comparisonValue(shape);
                    dirty=true;
                }
                count++;
            }
            if(comparisonCells.length!=count)dirty=true;
            comparisonCells.length=count; comparisonFields.length=count*4; comparisonSafe.length=count;
            if(dirty)comparisonStamp=prefix+(count?"|"+comparisonCells.join("|"):"");
            comparisonPrefix=prefix; comparisonValid=true;
            return comparisonStamp;
        }

'''

FOREGROUND_KEY = '''        private function gridKey(loc:*, width:int, joinStyle:String):String {
            var valid:Boolean=comparisonValid;
            comparisonValid=false;
            var parts:Array=[loc.spaceX,loc.spaceY,width,loc.homeStable,
                loc.cTransform?loc.cTransform.toString():""];
            var prefix:String=parts.join("|"),dirty:Boolean=!valid || comparisonPrefix!==prefix,count:int=0;
            for(var y:int=0;y<loc.spaceY;++y) for(var x:int=0;x<loc.spaceX;++x) {
                var tile:*=loc.space[x][y],allowed:Boolean=eligible(tile,joinStyle);
                var front:*=allowed?tile.front:null,shape:*=allowed && joinStyle=="readable"?tile.zForm:"";
                var offset:int=count*2;
                var same:Boolean=valid && comparisonSafe[count]===true &&
                    front===comparisonFields[offset] && shape===comparisonFields[offset+1];
                if(!same && valid && comparisonSafe[count]===true)
                    same=sameComparison(front,comparisonFields[offset]) && sameComparison(shape,comparisonFields[offset+1]);
                if(!same) {
                    comparisonCells[count]=allowed?front+shape:"-";
                    comparisonFields[offset]=front; comparisonFields[offset+1]=shape;
                    comparisonSafe[count]=comparisonValue(front) && comparisonValue(shape);
                    dirty=true;
                }
                count++;
            }
            if(comparisonCells.length!=count)dirty=true;
            comparisonCells.length=count; comparisonFields.length=count*2; comparisonSafe.length=count;
            if(dirty)comparisonStamp=prefix+(count?"|"+comparisonCells.join("|"):"");
            comparisonPrefix=prefix; comparisonValid=true;
            return comparisonStamp;
        }

'''


def replace_once(source, old, new):
    assert source.count(old) == 1, old[:80]
    return source.replace(old, new)


def optimized(source, name):
    source = source.replace('\r\n', '\n')
    source = replace_once(source, '        private var signature:String;', '        private var signature:String;\n'+COMMON)
    if name == 'BackgroundBlendLayer.as':
        source = replace_once(source, 'public function invalidate():void { signature=null; }',
                              'public function invalidate():void { signature=null; clearComparison(); }')
        source = replace_once(source, 'public function dispose():void {', 'public function dispose():void {\n            clearComparison();')
        start = source.index('            var started:int=getTimer(), parts:Array=')
        end = source.index('            if(location!==loc', start)
        source = source[:start]+'''            var started:int=getTimer(), stamp:String=stateKey(loc);
            var visualStamp:String=comparisonPrefix, key:String=style+":"+stamp;
            var y:int,x:int;
'''+source[end:]
        source = replace_once(source, '        private function findNative(', BACKGROUND_KEY+'        private function findNative(')
    else:
        source = replace_once(source, 'public function invalidate():void { signature = null; }',
                              'public function invalidate():void { signature = null; clearComparison(); }')
        source = replace_once(source, 'public function dispose(keepFractureProfiles:Boolean = false):void {',
                              'public function dispose(keepFractureProfiles:Boolean = false):void {\n            clearComparison();')
        start = source.index('        private function gridKey(')
        end = source.index('        private function eligible(', start)
        source = source[:start]+FOREGROUND_KEY+source[end:]
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert sha(WB/'release/WallBlendMod.swf') == BASE_SHA
    for name, value in HASHES.items():
        assert sha(BASE/'wallblend'/name) == value
    original = {p.relative_to(BASE).as_posix():sha(p) for p in BASE.rglob('*.as')}
    out.mkdir()
    for name in original:
        p=out/'src'/name; p.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(BASE/name,p)
    shutil.copyfile(WB/'release/WallBlendMod.swf',out/'control.swf')
    for name in HASHES:
        p=out/'src/wallblend'/name
        p.write_text(optimized(p.read_text(encoding='utf-8-sig'),name),encoding='utf-8')
    entry=out/'src/WallBlendMod.as'
    entry.write_text(replace_once(entry.read_text(encoding='utf-8-sig'),'"0.5.4-scene"','"'+VERSION+'"'),encoding='utf-8')
    air=GAME/'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'
    compile_as(out/'src/WallBlendDoc.as',out/'WallBlendMod.swf',[out/'src'],[air])
    checks=out/'checks/src';checks.mkdir(parents=True)
    for name in HASHES:
        for baseline in (True,False):
            source=(BASE/'wallblend'/name) if baseline else (out/'src/wallblend'/name)
            class_name=('Baseline' if baseline else '')+Path(name).stem
            text=source.read_text(encoding='utf-8-sig').replace(Path(name).stem,class_name)
            if baseline and name=='BackgroundBlendLayer.as':
                # Expose the exact old expression in a test-only method. No
                # independent reimplementation of the baseline key algorithm.
                start=text.index('            var started:int=getTimer(), parts:Array=')
                end=text.index('            var stamp:String=parts.join("|")',start)
                body=text[start:end]+'            return parts.join("|");\n'
                text=text.replace('        private function findNative(',
                    '        public function stateKey(loc:*):String {\n'+body+'        }\n\n        private function findNative(',1)
            p=checks/'wallblend'/(class_name+'.as');p.parent.mkdir(exist_ok=True)
            p.write_text(re.sub(r'\bprivate\b','public',text),encoding='utf-8')
    for source in (ROOT/'tests/wallblend').glob('*.as'):
        shutil.copyfile(source,checks/source.name)
    compile_as(checks/'WallKeyChecks.as',out/'checks/WallKeyChecks.swf',[checks,out/'src'],[air])
    current={p.relative_to(out/'src').as_posix():sha(p) for p in (out/'src').rglob('*.as')}
    changed=sorted(n for n in current if current[n]!=original[n])
    assert changed==['WallBlendMod.as','wallblend/BackgroundBlendLayer.as','wallblend/BlendLayer.as'],changed
    assert {p.relative_to(BASE).as_posix():sha(p) for p in BASE.rglob('*.as')}==original
    manifest=dict(kind='isolated-wallblend-comparison',version=VERSION,baseline_sha256=BASE_SHA,
        candidate_sha256=sha(out/'WallBlendMod.swf'),parent_source=original,changed=changed,
        source={'src/'+n:h for n,h in current.items()},inputs={p.relative_to(out).as_posix():sha(p) for p in checks.rglob('*.as')},
        tests={'WallKeyChecks.swf':sha(out/'checks/WallKeyChecks.swf')},preparer_sha256=sha(__file__))
    (out/'prepared.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ('version','candidate_sha256','changed')}))


if __name__=='__main__':main()
