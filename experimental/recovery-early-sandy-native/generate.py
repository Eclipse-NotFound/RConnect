"""Deterministic external adapters; never edits the original tools or binaries."""
from pathlib import Path
import difflib
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'experimental/recovery-first-raster-native'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,s):p.write_text(s,encoding='utf-8',newline='\n')
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b,1)
def patch(name,old,new):
    write(HERE/name,new)
    write(HERE/(name+'.patch'),''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='original/'+name,tofile='adapter/'+name)))

def main():
    for name in ('RoomTravelSceneTestDoc.as','A22RoomMetrics.as'):
        (HERE/'tests'/name).write_bytes((BASE/'tests'/name).read_bytes())
    old=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8-sig')
    new=replace(old,'SceneRasterBuildConfig.REQUIRE_SEED_TICKET && !solo && !host && target=="random_mane"',
        '!solo && target=="random_mane" && (SceneRasterBuildConfig.EXPECT_EARLY || !host)')
    patch('tests/RoomTravelTimingTestDoc.as',old,new)
    old=(ROOT/'tools/run_coop_regression.py').read_text(encoding='utf-8-sig')
    new=replace(old,'from validation.native_runtime_assets',
        'sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools"))\nfrom validation.native_runtime_assets')
    new=replace(new,'ROOT = Path(__file__).resolve().parents[1]','ROOT = Path(__file__).resolve().parents[2]')
    new=replace(new,"    ap.add_argument('--game-root',", "    ap.add_argument('--sandy-candidate',type=Path,help='Pinned A travel-hold candidate; isolated copies only')\n    ap.add_argument('--game-root',")
    new=replace(new,"    roles=('host',) if args.solo else ('host','join')\n    if args.all_mods",
        "    if args.sandy_candidate:\n        from native_inputs import sandy_input\n        assert args.all_mods and args.sandy_candidate.resolve()==Path(sandy_input('bridge')['candidate']).resolve()\n    roles=('host',) if args.solo else ('host','join')\n    if args.all_mods")
    new=replace(new,"                if path.exists(): shutil.copy2(path,destination/filename)",
        "                if name.lower()=='sandevistan' and filename==entry+'.swf' and args.sandy_candidate:\n                    path=args.sandy_candidate.resolve()\n                if path.exists(): shutil.copy2(path,destination/filename)")
    patch('native_runner.py',old,new)
    old=(BASE/'run_native.py').read_text(encoding='utf-8-sig')
    new=replace(old,'verify_host_intent,verify_driver','verify_host_intent,verify_driver,sandy_input')
    new=replace(new,"    ap.add_argument('--solo',action='store_true')","    ap.add_argument('--solo',action='store_true')\n    ap.add_argument('--sand-mode',choices=['bridge','legacy'],default='bridge')")
    new=replace(new,'    audit(candidate)','    audit(candidate)\n    sand=sandy_input(a.sand_mode)')
    new=replace(new,"    verify_driver(drivers,meta,a.scenario)\n    assert not",'    verify_driver(drivers,meta,a.scenario)\n    if a.scenario=="scene":assert meta["sand_mode"]==a.sand_mode\n    assert not')
    new=replace(new,"runner_sha256=sha(ROOT/'tools/run_coop_regression.py'),wrapper_sha256=sha(__file__),native_host=host_intent)",
        "runner_sha256=sha(Path(__file__).with_name('native_runner.py')),wrapper_sha256=sha(__file__),native_host=host_intent,sandy=sand)")
    new=replace(new,"str(ROOT/'tools/run_coop_regression.py'),'--candidate'","str(Path(__file__).with_name('native_runner.py')),'--candidate'")
    new=replace(new,"    if a.solo:cmd+=['--solo']","    if a.solo:cmd+=['--solo']\n    if a.sand_mode=='bridge':cmd+=['--sandy-candidate',sand['candidate']]")
    new=replace(new,"            assert inp['driver']==sha(binding/'EffectsDriver.swf')", "            assert inp['driver']==sha(binding/'EffectsDriver.swf')\n            modules={k.replace(chr(92),'/').lower():v for k,v in inp['modules'].items()}\n            assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']")
    new=replace(new,"    save(out/'result.json',result)","    assert sandy_input(a.sand_mode)==sand\n    result['sandy']=sand\n    result['early_performance_qualified']=False\n    save(out/'result.json',result)")
    patch('run_native.py',old,new)
    old=(BASE/'prepare_scene.py').read_text(encoding='utf-8-sig')
    new=replace(old,"    mode=ap.add_mutually_exclusive_group(required=True);mode.add_argument('--require-seed-raster',action='store_true');mode.add_argument('--control-no-seed-raster',action='store_true')",
        "    ap.add_argument('--sand-mode',choices=['bridge','legacy'],required=True)")
    new=replace(new,"    inputs=json.loads((HERE/'driver-inputs.json').read_text(encoding='utf-8'))", "    from native_inputs import verify_tools,sandy_input\n    verify_tools();sandy_input(a.sand_mode)\n    inputs=json.loads((HERE/'driver-inputs.json').read_text(encoding='utf-8'))")
    new=replace(new,"HERE/'generate_scene_driver.py'","HERE/'generate.py'")
    new=replace(new,"BASE/'ProductionDeclarations.swc',BASE/'scene/EffectsHarness.swf',*sorted((HERE/'tests').glob('*.as'))]",
        "BASE/'ProductionDeclarations.swc',BASE/'scene/EffectsHarness.swf',HERE/'inputs.json',HERE/'native_inputs.py',\n        HERE/'native_runner.py',HERE/'run_native.py',HERE/'check.py',*sorted((HERE/'tests').glob('*.as'))]")
    new=replace(new,"public static const REQUIRE_SEED_TICKET:Boolean='+str(a.require_seed_raster).lower()", "public static const EXPECT_EARLY:Boolean='+str(a.sand_mode=='bridge').lower()")
    new=replace(new,"        sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK", "        sys.path.insert(0,str(ROOT/'tools/host_authority'));from common import JAVA,SDK\n        from runtime_memory import snapshot,wait_owned")
    new=replace(new,"                    record.before_launch('Scene native input driver compile')", "                    assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'\n                    record.before_launch('Scene native input driver compile')")
    new=replace(new,"env=dict(os.environ,AIR_HOME=str(SDK)))", "env=dict(os.environ,AIR_HOME=str(SDK)),creationflags=subprocess.CREATE_NO_WINDOW)")
    new=replace(new,"record.child(process.pid);code=process.wait(timeout=240);assert code==0,code", "record.child(process.pid);code=wait_owned(process,240,out/'compile-memory.json');assert code==0,code")
    new=replace(new,"kind='scene-native-input-first-raster-driver'", "kind='scene-native-input-early-sandy-driver'")
    new=replace(new,'require_seed_raster=a.require_seed_raster','sand_mode=a.sand_mode')
    patch('prepare_scene.py',old,new)
    sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))}
    write(HERE/'driver-inputs.json',json.dumps(dict(sources=sources,original_scene_checks_retained=True,compiled=False,runtime_tested=False),indent=2)+'\n')

if __name__=='__main__':main()
