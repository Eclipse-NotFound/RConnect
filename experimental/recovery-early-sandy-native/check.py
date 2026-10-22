"""Pure source/receipt checks; does not run compiler, AIR or gameplay."""
from pathlib import Path
import ast,json
from native_inputs import HERE,ROOT,M52,verify_tools,sandy_input,audit,host_input,CANDIDATE,HOST,installation

def main():
    verify_tools();checks=[]
    def check(ok,label):
        assert ok,label
        checks.append(label)
    for path in sorted(HERE.glob('*.py')):
        ast.parse(path.read_text(encoding='utf-8-sig'));checks.append('Python syntax '+path.name)
    original=ROOT/'experimental/recovery-first-raster-native'
    before=(original/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8-sig')
    after=(HERE/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8-sig')
    old='SceneRasterBuildConfig.REQUIRE_SEED_TICKET && !solo && !host && target=="random_mane"'
    new='!solo && target=="random_mane" && (SceneRasterBuildConfig.EXPECT_EARLY || !host)'
    check(before.count(old)==1 and before.replace(old,new)==after,'Timing source differs only in explicit early-vs-legacy ticket expectation')
    for name in ('A22RoomMetrics.as','RoomTravelSceneTestDoc.as'):
        check((original/'tests'/name).read_bytes()==(HERE/'tests'/name).read_bytes(),'Exact ancestor '+name)
    for needle in ('baselineFrames<3','getTimer()-baselineAt>1000','now-inputAt>1000','phase=="boot"?240000:95000','dx*dx+dy*dy<=80*80','if(round>=2)'):
        check(needle in after,'Original threshold '+needle)
    native=(HERE/'native_runner.py').read_text()
    for needle in ('minimum_start_gib=3 if args.solo else 6',"row['free_commit_bytes']<512*1024**2",'with Registration(',"check_cancel_requested(output,'registration acquired')",'--private-desktop','def record_memory():'):
        check(needle in native,'Original isolation/registry/memory '+needle)
    prepare=(HERE/'prepare_scene.py').read_text()
    check("snapshot()['free_commit_bytes']>=1024**3" in prepare and 'wait_owned(process,240' in prepare,'Compiler retains 1GiB entry and owned runtime memory guard')
    check('CREATE_NO_WINDOW' in prepare,'Compiler hidden and owned')
    probe=(HERE/'tests/FirstRasterSceneProbe.as').read_text()
    check('.acquire(' not in probe and '.release(' not in probe and '.receive(' not in probe,'Raster probe cannot create/complete production hold')
    check('cls.rconnectRasterBridge===wrapper' in probe,'Restore only own observer')
    for early,solo,host,target,expected in [(True,False,True,'random_mane',True),(True,False,False,'random_mane',True),(False,False,True,'random_mane',False),(False,False,False,'random_mane',True),(True,True,True,'random_mane',False),(True,False,True,'rbl',False)]:
        check((not solo and target=='random_mane' and (early or not host))==expected,'Ticket mode '+str((early,solo,host,target)))
    bridge=sandy_input('bridge');legacy=sandy_input('legacy')
    check(bridge['candidate_sha256']!=legacy['candidate_sha256'],'Exact bridge and legacy binaries differ')
    audit(CANDIDATE);checks.append('Early1 frozen full source and binary audit')
    host_input(HOST,installation());checks.append('Early host independent full recheck reproduces frozen receipt')
    result=dict(static_passed=True,checks=len(checks),labels=checks,compiled=False,air_started=False,
        production_changed=False,thresholds_changed=False,active_replay_runtime_covered=False)
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
