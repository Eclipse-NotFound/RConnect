"""Pure source/input checks. No compiler, game, registry or subprocess."""
import ast,hashlib,json,re,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'tools/validation'))
from generate_scene_driver import method
from native_inputs import audit,host_input,verify_driver,CANDIDATE,HOST,DRIVER12
from run_security_terminals import installation

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    labels=[]
    def check(ok,label):
        assert ok,label
        labels.append(label)
    for p in sorted(HERE.glob('*.py')):
        ast.parse(p.read_text(encoding='utf-8-sig'));labels.append('Python syntax '+p.name)
    old=(DRIVER12/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8-sig')
    new=(HERE/'tests/RoomTravelTimingTestDoc.as').read_text(encoding='utf-8')
    cold=(ROOT/'build/m52/recovery-cold-travel-driver-03/tests/ColdFixedTravelTestDoc.as').read_text(encoding='utf-8-sig')
    for n in ('stable','result','send','watch'):
        check(method(old,n)==method(new,n),'original scene12 method unchanged: '+n)
    for n in ('inputSample','inputError','baselineInput','releaseKey','completeInput'):
        check(method(cold,n).replace('COLD TRAVEL INPUT','SCENE TRAVEL INPUT')==method(new,n),'cold03 real input method unchanged: '+n)
    expected=method(cold,'completeRelease').replace('COLD TRAVEL INPUT','SCENE TRAVEL INPUT').replace(
        '         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));',
        '         check(true,"native travel and input restoration finished");\n         Log.d("TRAVEL RESULT "+JSON.stringify(localResult));')
    check(expected==method(new,'completeRelease'),'cold03 release only adds original scene completion label')
    for literal in ('MAP_SEED:uint=1380142925','target=round%2==0?"random_mane":"rbl"',
        'phase=="boot"?240000:95000','dx*dx+dy*dy<=80*80','mod.game.world.game.beginMission(target)',
        'mod.game.world.game.gotoLand(target)','Object(mod.session.rooms).prepareMap(land,MAP_SEED,true)'):
        check(literal in old and literal in new,'scene input/path/limit retained: '+literal)
    labels_old=re.findall(r'check\([^;]*?,\s*"([^"\n]*)"',old)
    check(len(labels_old)==12,'original source has twelve static check label starts')
    for label in labels_old:check('"'+label+'"' in new,'original check label retained: '+label)
    check('localResult=result();startInputCheck();' in new,'original spawn snapshot precedes actual movement')
    check('phase!="wait"' in method(new,'compare'),'peer result cannot interrupt local input probe')
    probe=(HERE/'tests/FirstRasterSceneProbe.as').read_text(encoding='utf-8')
    check(probe.count('original(w,l,g)')==1,'production callback invoked exactly once per wrapper call')
    check('sceneViewReady(' not in probe and 'bitmapData' not in probe,'probe does not force raster readiness or pixels')
    check(not re.search(r'ticket\.(waiting|unpainted)\s*=(?!=)',probe),'probe never mutates production tickets')
    check('row.initialWaiting===true' in probe and 'row.firstPainted>=row.firstReleased' in probe,'ticket initial/published paint evidence required')
    driver=json.loads((HERE/'driver-inputs.json').read_text(encoding='utf-8'))
    for name,h in driver['sources'].items():check(sha(HERE/'tests'/name)==h,'generated driver fingerprint: '+name)
    wrapper=(ROOT/'tools/validation/run_room_travel_timing.py').read_text(encoding='utf-8-sig')
    derived=(HERE/'run_native.py').read_text(encoding='utf-8')
    # The whole runtime launch and qualification block is byte-identical.
    start='    out.mkdir();binding=';end='    if host_candidate:\n        assert sha(host_candidate/'
    common=wrapper[wrapper.index(start):wrapper.index(end)]
    check(common in derived,'runtime command, memory/exclusive delegation, logs and outcome checks unchanged')
    check("ap.add_argument('--game-candidate',required=True" in derived,'exact native host cannot be omitted')
    pins=json.loads((HERE/'runner-inputs.json').read_text(encoding='utf-8'))
    for p,h in ((ROOT/'tools/validation/run_room_travel_timing.py',pins['original_wrapper_sha256']),
        (ROOT/'tools/run_coop_regression.py',pins['native_runner_sha256']),(HERE/'run_native.py',pins['derived_runner_sha256']),
        (HERE/'native_inputs.py',pins['adapter_sha256'])):check(sha(p)==h,'wrapper fingerprint: '+p.name)
    candidate=audit(CANDIDATE);check(candidate['compiled'],'exact recovery13 compiled source and binary audit')
    installed=installation();intent=host_input(HOST,installed)
    check(len(installed)==22 and intent['source_inputs_unchanged'],'FD92 independent readback and 22 installed inputs')
    verify_driver(DRIVER12,json.loads((DRIVER12/'prepared.json').read_text(encoding='utf-8-sig')),'entry-room')
    labels.append('unmodified frozen scene12 entry-room driver accepted')
    result=dict(kind='static-native-adapter-checks',passed=len(labels),failed=0,labels=labels,
        candidate_sha256=candidate['sha256'],host_sha256=intent['candidate_sha256'],runtime_started=False,compiled=False)
    (HERE/'native-static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='labels'},ensure_ascii=False))
if __name__=='__main__':main()
