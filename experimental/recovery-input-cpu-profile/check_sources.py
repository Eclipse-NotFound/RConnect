"""Static source/ancestry and offline bounded-report counterexamples; no JVM/AIR."""
from pathlib import Path
import copy,hashlib,json
from generate import HERE,ROOT,BASE,BASE_PIN,strip,sha,read
from collect import validate
def main():
    rows=[]
    def check(ok,label):
        rows.append(dict(passed=bool(ok),label=label));assert ok,label
    original=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf-8-sig')
    current=(HERE/'tests/RoomTravelTimingTestDoc.as').read_text('utf-8')
    p=(HERE/'tests/RoomInputCpuProfile.as').read_text('utf-8')
    check(sha(BASE/'prepared.json')==BASE_PIN,'exact frozen shared driver manifest')
    check(strip(current)==original,'removing only tagged inserts recovers the entire frozen driver')
    for source in (BASE/'tests').glob('*.as'):
        if source.name!='RoomTravelTimingTestDoc.as':check(sha(HERE/'tests'/source.name)==sha(source),'unchanged '+source.name)
    check('getTimer()-baselineAt>1000' in current and 'if(baselineFrames<3)return;' in current,'original input thresholds retained')
    check(current.index('getTimer()-baselineAt>1000')<current.index('if(baselineFrames<3)return;'),'timeout remains before accepting third frame')
    check('200001' in p and '-200001' in p and 'p.op!="grant"' in p,'sampler surrounds first grant MESSAGE handlers')
    check('if(!host&&!solo)inputProfile=' in current and 'round==0 && phase=="travel"' in current,'join round0 only')
    check(p.index('if(sample is NewObjectSample || sample is DeleteObjectSample)continue;')<p.index('if(sample.stack!=null)'),'allocation/deletion samples excluded before stack access')
    check(all(s not in p for s in ('sample.type','sample.object','sample.size','getQualifiedClassName')),'no allocation class/object/size reads')
    check('setSamplerCallback(bufferFull)' in p and 'finally{clearSamples();}' in p,'native buffer callback clears; exported arrays separately bounded')
    check('cpu.length>=MAX_CPU' in p and 'stacks.length<MAX_STACKS' in p and 'seen>=MAX_NATIVE_PER_DRAIN' in p,'CPU/stack/scan limits explicit')
    check('markers.length>=MAX_MARKERS' in p and 'name.length>MAX_NAME' in p and 'depth++>=MAX_DEPTH' in p,'marker/name/depth limits explicit')
    stop=p.split('public function stop(',1)[1].split('public function finish()',1)[0]
    check('pauseSampling()' in stop and all(s not in stop for s in ('drain();','JSON.stringify','FileStream')),'stop pauses without enumeration or file IO')
    check('room-input-cpu-profile.json' in p and 'Log.d("SCENE INPUT CPU FILE "' in p,'CPU stack payload exported outside log error scanner')
    check('new RoomInputCpuProfile' in current and 'inputProfile.stop("input-failure")' in current,'known failure path stops before original diagnostic log')
    check(current.index('inputProfile.stop("input-failure")')<current.index('Log.d("SCENE TRAVEL INPUT '),'failure diagnostic is outside sampling')
    check('inputProfile.stop("round0-input-complete")' in current,'successful round0 stops before later travel rounds')
    check('diagnostic-window-cap' in p and 'performanceQualified:false' in p,'capped/instrumented run never advertises performance qualification')
    sample=dict(schema=1,diagnosticOnly=True,performanceQualified=False,role='join',round=0,allocationClassesExported=False,
        caps=dict(cpu=12000,stacks=512,depth=24,name=192,nativePerDrain=250000,markers=64,windowMs=15000),
        cpuRows=[[2,3000,0]],stacks=[['function']],markers=[dict(label=s,nativeOrdinal=n) for s,n in
            [('grant-handler-before',0),('grant-handler-returned',1),('baseline-start',2),('capture-stop',3)]],
        nativeEntries=3,started=True,fault='',cpuDropped=0,nativeTruncated=False,stackTruncated=False,markerTruncated=False,stopReason='input-failure')
    check(validate(sample)['complete_diagnostic_window'],'a functional input failure can retain valid CPU diagnostic evidence')
    for name,change in [('zero CPU',lambda x:x.update(cpuRows=[])),('missing baseline marker',lambda x:x.update(markers=x['markers'][:2]+x['markers'][3:])),
        ('truncated CPU',lambda x:x.update(cpuDropped=1)),('buffer scan truncated',lambda x:x.update(nativeTruncated=True)),
        ('unsupported sampler',lambda x:x.update(fault='sampler-start')),('window cap',lambda x:x.update(stopReason='diagnostic-window-cap'))]:
        x=copy.deepcopy(sample);change(x);check(not validate(x)['complete_diagnostic_window'],name+' cannot qualify complete diagnostic')
    for name,change in [('bad stack index',lambda x:x.update(cpuRows=[[2,3000,1]])),('duplicate ordinal',lambda x:x.update(cpuRows=[[2,3000,0],[2,3001,0]])),
        ('ordinal beyond buffer',lambda x:x.update(nativeEntries=2)),('too long name',lambda x:x.update(stacks=[['x'*193]]))]:
        x=copy.deepcopy(sample);change(x);rejected=False
        try:validate(x)
        except AssertionError:rejected=True
        check(rejected,name+' rejected')
    for n,h in read(HERE/'driver-inputs.json')['sources'].items():check(sha(HERE/'tests'/n)==h,'generated source fingerprint '+n)
    for path in HERE.glob('*.py'):compile(path.read_text('utf-8'),str(path),'exec')
    result=dict(scope='static source and offline report validation only',assertions=rows,passed=len(rows),failed=0,compiled=False,runtime_tested=False)
    (HERE/'static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    ancestors=[BASE/'prepared.json',ROOT/'experimental/recovery-seed-raster-control/prepare_driver.py',
        ROOT/'experimental/recovery-seed-raster-control/native_runner.py',ROOT/'experimental/recovery-seed-raster-control/control_inputs.py']
    manifest=dict(ancestor_manifest=BASE_PIN,compiled=False,runtime_tested=False,diagnostic_only=True,
        ancestors={p.relative_to(ROOT).as_posix():sha(p) for p in ancestors},
        files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='source-manifest.json' and '__pycache__' not in p.parts})
    (HERE/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(static_checks=len(rows),failed=0,compiled=False,runtime_tested=False,manifest=sha(HERE/'source-manifest.json'))))
if __name__=='__main__':main()
