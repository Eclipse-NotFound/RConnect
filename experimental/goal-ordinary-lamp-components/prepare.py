"""Extract the exact approved helpers and native BAKE for a small AIR fixture."""
from pathlib import Path
import argparse, hashlib, json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
SOURCE=HERE.with_name('goal-ordinary-lamp-first-raster-candidate')/'lad/src/lad'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def generated():
    runtime=(SOURCE/'LadRuntime.as').read_text('utf8')
    assert sha(SOURCE/'LadRuntime.as')=='07cb85b230906a2a93d3c01d2d773acc3dbc1c33f70497c97a8ba448f457c8fb'
    helpers=runtime[runtime.index('        /** First-pass omission only.'):runtime.index('        private function objectAdded')]
    assert helpers.count(' function ')==7
    header='package lad {\nimport flash.utils.Dictionary;\nimport flash.utils.getDefinitionByName;\npublic class OrdinaryRasterHarness {\npublic var enabled:Boolean=true;\nprivate var location:Object,failedLocation:Object,ordinaryRaster:Object;\n'
    wrapper='''
public function pending():Object{return ordinaryRaster;}
public function eligibleSet(loc:Object,found:Array):Boolean{return canUseOrdinaryRaster(loc,found);}
public function cancel(redraw:Boolean=true):void{cancelOrdinaryRaster(redraw);}
public function attachIdentity(loc:Object,failed:Object=null):void{location=loc;failedLocation=failed;}
}}
'''
    catalog=(SOURCE/'LadLampCatalog.as').read_text('utf8')
    begin=catalog.index('        private static const TYPES:')
    end=catalog.index('        public static function discover')
    return {'lad/OrdinaryRasterHarness.as':(header+helpers+wrapper).encode('utf8'),
            'lad/LadLampCatalog.as':('package lad { public class LadLampCatalog {\n'+catalog[begin:end]+'}}\n').encode('utf8'),
            'lad/LadSceneBake.as':(SOURCE/'LadSceneBake.as').read_bytes()}
def check():
    expected=generated()
    for name,data in expected.items():assert (HERE/'src'/name).read_bytes()==data,name
    manifest=json.loads((HERE/'source-manifest.json').read_text('utf8'))
    assert manifest['native_game_test'] is False
    assert manifest['files']=={p.relative_to(HERE/'src').as_posix():sha(p) for p in sorted((HERE/'src').rglob('*.as'))}
    return manifest
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--generate',action='store_true');a=p.parse_args()
    if a.generate:
        assert not (HERE/'source-manifest.json').exists(),'Do not overwrite a frozen fixture'
        for name,data in generated().items():
            dest=HERE/'src'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
        manifest={'kind':'ordinary-raster-helper-component-v1','native_game_test':False,
          'runtime_sha256':sha(SOURCE/'LadRuntime.as'),'bake_sha256':sha(SOURCE/'LadSceneBake.as'),
          'files':{p.relative_to(HERE/'src').as_posix():sha(p) for p in sorted((HERE/'src').rglob('*.as'))}}
        (HERE/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n','utf8')
    print(json.dumps({'checked':bool(check()),'compiled':False,'air_started':False}))
