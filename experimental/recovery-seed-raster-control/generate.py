"""Generate isolated seed-gate control and one shared external driver; no JVM/AIR."""
from pathlib import Path
import hashlib,json,difflib,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-13';PREVIOUS=ROOT/'experimental/recovery-first-raster-native'
FIX=ROOT/'experimental/recovery-seed-first-raster/components/room'
PIN='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
REPLACED='            return firstRaster.open(w,l,g,seedRaster.id);'
REPLACEMENT='            return null; // Isolated control: seed identity/anchor/restore remain; native raster runs normally.'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def put(name,text):
 p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8',newline='\n')
def change(s,a,b):assert s.count(a)==1,a[:100];return s.replace(a,b,1)
def method(s,name):
 start=re.search(r'^      private function '+name+r'\(',s,re.M).start();opening=s.index('{',start);i=opening+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]
def main():
 meta=read(BASE/'prepared.json');assert sha(BASE/'RConnectMod.swf')==meta['sha256']==PIN
 for folder,items in (('src',meta['source']),('tools',meta['inputs'])):
  for name,digest in items.items():assert sha(BASE/folder/name)==digest
 old=(BASE/'src/rconnect/core/RoomSync.as').read_text(encoding='utf-8-sig')
 off=change(old,REPLACED,REPLACEMENT)
 put('src/rconnect/core/RoomSync.as',off)
 put('proposal.patch',''.join(difflib.unified_diff(old.splitlines(True),off.splitlines(True),fromfile='recovery13/RoomSync.as',tofile='seed-gate-off/RoomSync.as')))
 # Same test code in both components; only the actual production method and
 # explicit expected mode differ. All previous non-seed tests remain intact.
 actual={'rconnect/core/'+n+'.as' for n in ('RoomSync','FirstRasterGate','SeedRasterEntry','NativeTravelPlan','TravelGuard','TravelPlacement')}
 actual.add('rconnect/ui/RoomEntryView.as')
 component_inputs={}
 for source in sorted(FIX.rglob('*.as')):
  rel=source.relative_to(FIX).as_posix();text=source.read_text(encoding='utf-8-sig');component_inputs[str(source.relative_to(ROOT))]=sha(source)
  if rel in actual:text=(BASE/'src'/rel).read_text(encoding='utf-8-sig')
  if rel=='NativeTravelRoomChecks.as':
   text=change(text,method(text,'seedCases'),(HERE/'seed-control-cases.inc').read_text(encoding='utf-8').rstrip())
   text=change(text,'assertions:rows,functional_only:true','assertions:rows,seed_semantics:seedSemantics,seed_gate_expected:gateExpected(),functional_only:true')
  for mode in ('on','off'):put('components/'+mode+'/'+rel,off if rel=='rconnect/core/RoomSync.as' and mode=='off' else text)
 for mode in ('on','off'):put('components/'+mode+'/SeedGateCaseMode.as','package { public final class SeedGateCaseMode { public static const EXPECTED:Boolean='+str(mode=='on').lower()+'; } }\n')
 # Shared native driver reads an explicit immutable per-run intent, never a
 # production version guess or a silent absent-file fallback.
 frozen=read(PREVIOUS/'native-adapter-manifest.json')
 for name,digest in frozen['files'].items():assert sha(PREVIOUS/name)==digest,name
 original=(PREVIOUS/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8')
 s=change(original,'private var rasterProbe:FirstRasterSceneProbe,livingPrepared:Boolean=false;',
     'private var rasterProbe:FirstRasterSceneProbe,livingPrepared:Boolean=false,seedGateIntent:Object;')
 s=change(s,'SceneRasterBuildConfig.REQUIRE_SEED_TICKET','seedGateIntent.expectSeedTicket')
 s=change(s,'            configured=true;mod.config.setValue("followTeammate","0");',
     '            configured=true;\n            try{seedGateIntent=SeedGateNativeIntent.read();Log.d("SEED GATE INTENT "+JSON.stringify(seedGateIntent));}\n            catch(intentError:Error){check(false,"explicit seed gate intent: "+intentError);finish();return;}\n            mod.config.setValue("followTeammate","0");')
 s=change(s,'         localResult.flagsReadyWall=new Date().time;localResult.requestedWall=requestedWall;',
     '         localResult.flagsReadyWall=new Date().time;localResult.requestedWall=requestedWall;localResult.seedGateIntent=seedGateIntent;')
 put('tests/RoomTravelTimingTestDoc.as',s)
 for name in ('FirstRasterSceneProbe.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as'):put('tests/'+name,(PREVIOUS/'tests'/name).read_text(encoding='utf-8'))
 put('tests/SeedGateNativeIntent.as',(HERE/'SeedGateNativeIntent.as').read_text(encoding='utf-8'))
 put('driver.patch',''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='frozen-scene-input/RoomTravelTimingTestDoc.as',tofile='shared-intent/RoomTravelTimingTestDoc.as')))
 put('driver-inputs.json',json.dumps(dict(sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))},
     previous_manifest=sha(PREVIOUS/'native-adapter-manifest.json'),same_driver_both_modes=True,compiled=False,runtime_tested=False),indent=2)+'\n')
 # Reuse the already reviewed external-only compiler recipe, removing its
 # compile-time mode flag so both candidates necessarily use the same SWF.
 prep=(PREVIOUS/'prepare_scene.py').read_text(encoding='utf-8')
 prep=change(prep,"    mode=ap.add_mutually_exclusive_group(required=True);mode.add_argument('--require-seed-raster',action='store_true');mode.add_argument('--control-no-seed-raster',action='store_true')\n",'')
 prep=change(prep,"HERE/'generate_scene_driver.py'","HERE/'generate.py'")
 line=next(x for x in prep.splitlines(True) if "tests/SceneRasterBuildConfig.as').write_text" in x);prep=change(prep,line,'')
 prep=change(prep,"kind='scene-native-input-first-raster-driver'","kind='scene-seed-gate-comparison-driver'")
 prep=change(prep,'require_seed_raster=a.require_seed_raster,','explicit_intent=True,same_driver_both_modes=True,')
 put('prepare_driver.py',prep)
 # Derive a private runner copy with exactly one additional immutable test
 # asset. Common runtime checks/registry/launch/memory/cleanup remain intact.
 source=ROOT/'tools/run_coop_regression.py';original=runtime=source.read_text(encoding='utf-8-sig')
 runtime=change(runtime,'ROOT = Path(__file__).resolve().parents[1]','ROOT = Path(__file__).resolve().parents[2]')
 runtime=change(runtime,"        shutil.copy2(args.effects_driver/'EffectsDriver.swf',driver_dir/'EffectsDriver.swf')", "        shutil.copy2(args.effects_driver/'EffectsDriver.swf',driver_dir/'EffectsDriver.swf')\n        gate_intent=json.loads((args.effects_driver/'seed-gate-intent.json').read_text(encoding='utf-8'))\n        assert gate_intent['schema']==1 and type(gate_intent['expectSeedTicket']) is bool and gate_intent['candidateSha']==candidate_hash\n        shutil.copy2(args.effects_driver/'seed-gate-intent.json',driver_dir/'seed-gate-intent.json')")
 runtime=change(runtime,"                inputs[role]['driver']=hashlib.sha256((folder/'tests/EffectsDriver.swf').read_bytes()).hexdigest()", "                inputs[role]['driver']=hashlib.sha256((folder/'tests/EffectsDriver.swf').read_bytes()).hexdigest()\n                inputs[role]['seed_gate_intent']=hashlib.sha256((folder/'tests/seed-gate-intent.json').read_bytes()).hexdigest()")
 runtime='from pathlib import Path\nimport sys\nsys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))\n'+runtime
 put('native_runner.py',runtime)
 put('native-runner.patch',''.join(difflib.unified_diff(original.splitlines(True),runtime.splitlines(True),fromfile='common/run_coop_regression.py',tofile='isolated/native_runner.py')))
 put('integration.json',json.dumps(dict(base='build/m52/recovery-13',base_sha256=PIN,
     overlay={'src/rconnect/core/RoomSync.as':sha(HERE/'src/rconnect/core/RoomSync.as')},
     original_room_sha256=sha(BASE/'src/rconnect/core/RoomSync.as'),component_inputs=component_inputs,
     private_runtime_original_sha256=sha(source),private_runtime_sha256=sha(HERE/'native_runner.py'),
     compiled=False,runtime_tested=False,protocol_changed=False),indent=2)+'\n')
 print('Generated one-line production control, paired components and shared intent driver; source only')
if __name__=='__main__':main()
