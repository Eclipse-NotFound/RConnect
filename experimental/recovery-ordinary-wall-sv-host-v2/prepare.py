"""Prepare exact isolated native sources; no compiler, AIR or deployment entry."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
INPUTS = {
    'Grafon': (RC / 'build/m52/recovery-wall-surfaces-host-01/import/fe/graph/Grafon.as',
               '625db5c71c4319f4c942e581e039b7419dc070065dc3fb148e23003b715abb04'),
    'Location': (RC / 'build/m52/recovery-raster-dependencies-01/scripts/fe/loc/Location.as',
                 '9c7e679a4b5b8423355cb3ce07e496caa13415beb1ffdd630f0f2ed7b38c9cab'),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def once(text, old, new):
    assert text.count(old) == 1, ('anchor mismatch', old[:120], text.count(old))
    return text.replace(old, new, 1)


def method(text, name):
    matches = list(re.finditer(r'^      (?:public|private|internal)\s+(?:static\s+)?function\s+' + re.escape(name) + r'\(', text, re.M))
    assert len(matches) == 1, name
    start = matches[0].start()
    brace = text.index('{', matches[0].end())
    depth = 1
    cursor = brace + 1
    # Exact frozen native methods here contain no brace literals/comments.
    while depth:
        if text[cursor] == '{': depth += 1
        elif text[cursor] == '}': depth -= 1
        cursor += 1
    return text[start:cursor]


def patched_grafon(source):
    result = once(source, '      public static var rconnectWallBridge:Function = null;',
                  (HERE / 'ordinary-bridge.inc.as').read_text(encoding='utf-8').rstrip() +
                  '\n\n      public static var rconnectWallBridge:Function = null;')
    old = method(result, 'tileDie')
    new = once(old, 'tileDie(param1:Tile, param2:int)', 'tileDie(param1:Tile, param2:int, ordinaryPrepared:Object = null)')
    call = '         this.decal(_loc3_,_loc4_,_loc5_,_loc6_,1,0,"hardlight");'
    new = once(new, call, '''         if(rconnectOrdinaryWallBridge != null && !this.sceneLarge)
         {
            var previousOrdinary:Object = this.rconnectOrdinaryStructure;
            // mat7 / doors keep the native path; they must not become ordinary ink.
            this.rconnectOrdinaryStructure = {tile:param1,prepared:ordinaryPrepared,
               ordinaryPhysical:param1.mat != 7 && param1.door == null};
            try
            {
               this.decal(_loc3_,_loc4_,_loc5_,_loc6_,1,0,"hardlight");
            }
            catch(nativeFailure:*)
            {
               this.rconnectOrdinaryStructure = previousOrdinary;
               throw nativeFailure;
            }
            this.rconnectOrdinaryStructure = previousOrdinary;
         }
         else this.decal(_loc3_,_loc4_,_loc5_,_loc6_,1,0,"hardlight");''')
    result = once(result, old, new)
    old = method(result, 'decal')
    new = once(old, '         if(this.sceneLarge && !this.sceneRasterizing)', '''         if(rconnectOrdinaryWallBridge != null && !this.sceneLarge
            && (this.rconnectOrdinaryStructure == null || this.rconnectOrdinaryStructure.ordinaryPhysical === true))
         {
            this.ordinaryDecal(param1,param2,param3,param4,param5,param6,param7);
            return;
         }
         if(this.sceneLarge && !this.sceneRasterizing)''')
    result = once(result, old, new)
    old = method(result, 'drawLoc')
    new = once(old, '         var sceneStarted:int;', '''         var ordinaryRaster:Boolean = rconnectOrdinaryWallBridge != null && ordinaryRoom(param1) && !this.sceneRasterizing;
         var ordinaryRasterOK:Boolean = true;
         var ordinaryRasterError:String = "";
         var sceneStarted:int;''')
    new = once(new, '         this.scenePrepare(param1);', '''         try {this.scenePrepare(param1);}
         catch(prepareError:*)
         {
            if(ordinaryRaster)this.ordinaryRaster("raster-failed",param1,String(prepareError));
            throw prepareError;
         }''')
    for indent, body in [('                  ', 'World.w.showError(err,"Ошибка рисования слоя " + mat.id);'),
                         ('                  ', 'World.w.showError(err,"Ошибка рисования слоя " + arrBack[e].id);'),
                         ('            ', 'World.w.showError(err);')]:
        new = once(new, indent + body, indent + 'ordinaryRasterOK = false;ordinaryRasterError = String(err);\n' + indent + body)
    new = once(new, '''         this.sceneRestoreMarks();
         if(!this.sceneRepaint)
         {
            this.drawAllObjs();
         }''', '''         try
         {
            this.sceneRestoreMarks(); // Ordinary native path returns without replaying marks.
            if(!this.sceneRepaint)this.drawAllObjs();
         }
         catch(tailError:*)
         {
            if(ordinaryRaster)this.ordinaryRaster("raster-failed",param1,String(tailError));
            throw tailError;
         }
         if(ordinaryRaster)this.ordinaryRaster(ordinaryRasterOK ? "raster" : "raster-failed",param1,ordinaryRasterError);''')
    result = once(result, old, new)
    return result


def patched_location(source):
    result = source
    for name, indent, kind in [('hitTile', '                  ', 'param5'), ('dieTile', '            ', '4')]:
        old = method(result, name)
        new = once(old, indent + 'param1.die();',
                   indent + 'var ordinaryPrepared:Object = Grafon.rconnectOrdinaryPrepare(this,param1);\n' + indent + 'param1.die();')
        old_block = ('                  if(this.active)\n                  {\n                     this.grafon.tileDie(param1,param5);\n                  }'
                     if name == 'hitTile' else
                     '            if(this.active)\n            {\n               this.grafon.tileDie(param1,4);\n            }')
        inner = indent + '   '
        new_block = (indent + 'if(this.active)\n' + indent + '{\n' + inner +
                     'this.grafon.tileDie(param1,' + kind + ',ordinaryPrepared);\n' + indent + '}\n' +
                     indent + 'else Grafon.rconnectOrdinaryPending(this,param1,ordinaryPrepared);')
        new = once(new, old_block, new_block)
        result = once(result, old, new)
    return result


def prepare(verify=False):
    outputs = {}
    originals = {}
    for name, (path, digest) in INPUTS.items():
        assert sha(path) == digest, str(path)
        originals[name] = path.read_text(encoding='utf-8-sig')
    outputs['src/fe/graph/Grafon.as'] = patched_grafon(originals['Grafon'])
    outputs['src/fe/loc/Location.as'] = patched_location(originals['Location'])
    for name, original in originals.items():
        relative = 'src/fe/' + ('graph' if name == 'Grafon' else 'loc') + '/' + name + '.as'
        outputs[name + '.patch'] = ''.join(difflib.unified_diff(original.splitlines(True), outputs[relative].splitlines(True),
                                                               fromfile='exact-input/' + name + '.as', tofile=relative))
    for relative, text in outputs.items():
        path = HERE / relative
        data = text.encode('utf-8')
        if verify or path.exists():
            assert path.read_bytes() == data, 'Prepared file changed: ' + relative
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    record = {
        'kind': 'ordinary-wall-native-event-source-only', 'compiled': False, 'AIR_run': False, 'deployed': False,
        'inputs': {str(path): digest for path, digest in INPUTS.values()},
        'generator_sha256': sha(__file__), 'bridge_fragment_sha256': sha(HERE / 'ordinary-bridge.inc.as'),
        'outputs': {relative: sha(HERE / relative) for relative in outputs},
        'source_contract': 'function(event:Object):Object; independent rconnectOrdinaryWallBridge',
        'runtime_qualification': False,
        'remaining': ['Actual native asset/timeline bounds and image equivalence require compilation and AIR',
                      'Direct owner tileDie without pre-die token must be rejected as incomplete coverage by RConnect',
                      'mat7/gwall and arbitrary external direct frontBmp writes remain excluded',
                      'RConnect receiver/ownership/version state is implemented in a separate isolated directory'],
    }
    path = HERE / 'prepared.json'
    encoded = (json.dumps(record, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    if verify or path.exists(): assert path.read_bytes() == encoded, 'Prepared receipt changed'
    else: path.write_bytes(encoded)
    print(json.dumps({'verified': verify, 'outputs': record['outputs'], 'compiled': False}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    prepare(parser.parse_args().verify)
