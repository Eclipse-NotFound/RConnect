"""Source recovery and report counterexamples only; no JVM/AIR or sampler execution."""
import copy,difflib,json
from generate import HERE,ROOT,BASE,BASE_PIN,PREVIOUS,strip,sha,read
from collect import CAPS,validate,summaries

def fixture():
    windows=[];frames=[]
    for i in range(6):
        t=140+i*40;ctx=dict(phase='travel' if i<3 else 'input-baseline',round=0)
        windows.append(dict(id=i,frame=i+1,startAt=t,endAt=t+25,startNative=0,endNative=3,lastNative=1,
            beginCostMs=1,closeCostMs=2,scanCostMs=1,nativeScanned=3,nativeScanComplete=True,cpuDropped=0,
            stackTruncated=False,stack_tail_truncated=False,complete_stack_capture=True,nativeTruncated=False,duplicateRenders=1 if i==0 else 0,
            contextStart=ctx,contextEnd=ctx,closeReason='render',usable_cpu=True,partial_window=False,completed_render_window=True,invalidReasons=[],
            cpuRows=[[1,100000+i*40,0]],stacks=[['example::step']],stack_tails=[False]))
        frames.append(dict(frame=i+1,t=t,selected=True,window=i,reason='selected-first-six',context=ctx))
    for i in (7,8):frames.append(dict(frame=i,t=100+i*40,selected=False,window=-1,reason='selection-cap',context={}))
    return dict(schema=3,diagnosticOnly=True,performanceQualified=False,role='join',round=0,
        allocationClassesExported=False,samplerCallbackUsed=False,countsAreNotDurations=True,caps=CAPS.copy(),
        armed=True,armAt=100,grantFrame=0,stopAt=430,stopReason='input-failure',
        observedFrames=8,selectedWindows=6,skippedFrames=2,unrecordedFrames=0,duplicateRenders=1,markerDropped=0,
        cpuKept=6,stacksKept=6,windows=windows,frames=frames,
        markers=[dict(label='grant-handler-returned',t=100,frame=0,window=-1,nativeCount=-1),
                 dict(label='baseline-start',t=145,frame=1,window=0,nativeCount=1)])

def invalid_window(p,i,reason):
    w=p['windows'][i];p['cpuKept']-=len(w['cpuRows']);p['stacksKept']-=len(w['stacks'])
    w.update(usable_cpu=False,partial_window=False,completed_render_window=False,complete_stack_capture=False,invalidReasons=[reason],cpuRows=[],stacks=[],stack_tails=[])

def main():
    checks=[]
    def check(ok,label):checks.append(dict(passed=bool(ok),label=label));assert ok,label
    original=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf-8-sig')
    current=(HERE/'tests/RoomTravelTimingTestDoc.as').read_text('utf-8')
    p=(HERE/'tests/RoomInputCpuProfile.as').read_text('utf-8')
    old=ROOT/'experimental/recovery-input-cpu-frames'
    check(sha(old/'RoomInputCpuProfile.as')==sha(HERE/'baseline/RoomInputCpuProfile.as')=='02ade28f2347ae597a60dcb9613a48cf4ef77a31f2c61cf65b8b73e30e283132','original helper preserved exactly in original and baseline')
    check(sha(old/'source-manifest.json')==sha(HERE/'baseline/source-manifest.json')=='ac92feacc41c0ab3230b117a3be0ce8d3de65eb72eb710c7534c05cac9f8cb51','original source manifest preserved exactly')
    check(sha(BASE/'prepared.json')==BASE_PIN,'exact frozen shared scene ancestor')
    check(strip(current)==original,'entire original driver recovered by stripping only diagnostic inserts')
    for source in sorted((BASE/'tests').glob('*.as')):
        if source.name!='RoomTravelTimingTestDoc.as':check(sha(HERE/'tests'/source.name)==sha(source),'unchanged '+source.name)
    check('getTimer()-baselineAt>1000' in current and 'if(baselineFrames<3)return;' in current,'original 1000ms and three-frame checks preserved')
    check(current.index('getTimer()-baselineAt>1000')<current.index('if(baselineFrames<3)return;'),'original deadline precedes accepting third baseline frame')
    check('if(!host&&!solo)inputProfile=new RoomInputCpuProfile(mod.stage,' in current,'join-only helper receives actual stage')
    check('round==0 && phase=="travel" && target=="random_mane"' in current,'eligibility still round0 target travel only')
    check('grantReturned,false,-200001' in p and 'armAt=getTimer()' in p,'arm after target grant handlers, never starts sampling in grant')
    grant=p.split('private function grantReturned(',1)[1].split('private function readContext()',1)[0]
    check('startSampling' not in grant and 'clearSamples' not in grant,'grant callback excludes CPU capture entirely')
    check('Event.ENTER_FRAME,beginFrame,false,1000000' in p and 'Event.RENDER,endFrame,false,-2147483647' in p,'high-priority frame begin and final render end')
    check('MAX_WINDOWS:int=6' in p and 'selected<MAX_WINDOWS' in p,'first six actual post-grant frames only')
    check('selection-cap' in p and 'unrecordedFrames++' in p,'unselected and omitted frame records explicit')
    check('if(current!=null)closeWindow("missing-render",true)' in p,'missing render reads intact elapsed range before next window')
    check('int(lastClosed.frame)==frameNo' in p and 'lastClosed.duplicateRenders++' in p,'duplicate same-frame RENDER never reopens sampler')
    check('closeWindow("stop-before-render",true)' in p,'finish/input failure reads intact elapsed range without inventing RENDER')
    check('w.completed_render_window=w.usable_cpu && reason=="render"' in p,'CPU integrity separate from completed render qualification')
    check('w.partial_window=w.usable_cpu && (reason=="missing-render" || reason=="stop-before-render")' in p,'only intact non-render windows marked partial')
    check('setSamplerCallback' not in p and 'bufferFull' not in p,'no full-buffer callback dependency')
    check(p.index('pauseSampling();w.endNative=getSampleCount();')<p.index('if(allowRead && w.invalidReasons.length==0)scan(w);'),'pause before enumeration')
    check('stopSampling();clearSamples();' in p,'each selected sampler window ends independently')
    check('native-count-regressed' in p and 'native-enumeration-count' in p and 'no-cpu-samples' in p,'zero/lost/incomplete native samples explicitly invalid')
    check('else {w.cpuRows=[];w.stacks=[];w.stack_tails=[];}' in p,'invalid window discards all CPU and stack data')
    check('Number(w.endNative)>MAX_NATIVE' in p and 'seen>=MAX_NATIVE' in p,'native count precheck and iterator hard cap')
    check('MAX_CPU-keptCpu' in p and 'MAX_STACKS-keptStacks' in p,'retained CPU and stack limits apply globally across windows')
    check('depth++>=MAX_DEPTH' in p and 'name.length>MAX_NAME' in p,'bounded stack depth and text')
    check('stack-depth-cap' not in p and 'tail=true;w.stack_tail_truncated=true;break;' in p,'outer stack depth truncation retains visible leaf without invalidating buffer')
    check('(tail?"$tail:":"$full:")+JSON.stringify(names)' in p,'truncated prefix distinct from genuinely complete 24-level stack')
    check('w.complete_stack_capture=w.usable_cpu && !w.stack_tail_truncated' in p,'full-stack qualification separate from buffer and render completion')
    check(p.index('if(sample is NewObjectSample || sample is DeleteObjectSample)continue;')<p.index('if(sample.stack!=null)'),'skip allocations/deletions before reading stack')
    check(all(x not in p for x in ('sample.type','sample.object','sample.size','getQualifiedClassName')),'no sampled allocation class/object/size inspection')
    check('room-input-cpu-frames-partial.json' in p and 'Log.d("SCENE INPUT CPU FRAMES FILE "' in p,'CPU payload stored outside runtime log')
    check('beginCostMs' in p and 'scanCostMs' in p and 'closeCostMs' in p,'diagnostic cost separately recorded')
    check('inputProfile.stop("input-failure")' in current and 'inputProfile.stop("round0-input-complete")' in current,'original failure and success boundaries stop sampler')
    check(current.index('inputProfile.stop("input-failure")')<current.index('Log.d("SCENE TRAVEL INPUT '),'stop before original failure output/cleanup')
    check('performanceQualified:false' in p and 'samplerCallbackUsed:false' in p,'diagnostic does not claim runtime qualification')
    good=fixture();status=validate(good)
    check(status['complete_selected_frame_capture'] and status['usable_cpu_capture'],'valid six windows qualify diagnostic despite original functional input failure')
    check(len(summaries(good))==6 and all(x['top'] for x in summaries(good)),'intact CPU windows yield actual stack summary')
    check(all(w['cpuRows'][0][0]==1 for w in good['windows']),'per-window ordinal reset accepted instead of false global regression')
    x=copy.deepcopy(good);x['windows'][0].update(stacks=[['f'+str(i) for i in range(24)]],stack_tails=[True],stack_tail_truncated=True,complete_stack_capture=False)
    result=validate(x);summary=summaries(x)[0]
    check(result['usable_cpu_capture'] and result['complete_selected_frame_capture'] and not result['complete_stack_capture'],'intact render with outer stack tail retains CPU but no full-stack qualification')
    check(len(summary['top'][0]['stack'])==24 and summary['top'][0]['stack_tail_truncated'] and 'outer callers unknown' in summary['stack_scope'],'summary keeps visible stack prefix and labels unknown caller tail')
    x['windows'][0].update(closeReason='stop-before-render',partial_window=True,completed_render_window=False)
    check(validate(x)['usable_cpu_capture'] and not validate(x)['complete_selected_frame_capture'] and not validate(x)['complete_stack_capture'],'partial CPU and truncated caller tail remain independently qualified')
    for reason in ('missing-render','stop-before-render'):
        x=copy.deepcopy(good);x['windows'][0].update(closeReason=reason,partial_window=True,completed_render_window=False)
        result=validate(x);summary=summaries(x)[0]
        check(result['usable_cpu_capture'] and not result['complete_selected_frame_capture'] and result['partial_windows']==[0],reason+' retains intact CPU but never full-six qualification')
        check(summary['top'] and summary['partial_window'] and not summary['completed_render_window'] and reason in summary['range'],reason+' summary exposes actual partial range and stacks')
    x=copy.deepcopy(good)
    for w in x['windows']:w.update(closeReason='missing-render',partial_window=True,completed_render_window=False)
    check(validate(x)['usable_cpu_capture'] and not validate(x)['complete_selected_frame_capture'] and validate(x)['completed_render_windows']==[],'all intact partial windows usable without any complete render claim')
    for reason in ('native-count-regressed','native-scan-cap','cpu-cap','sampler-enumeration','no-cpu-samples'):
        x=copy.deepcopy(good);invalid_window(x,0,reason)
        x['windows'][0]['closeReason']='stop-before-render'
        if reason=='native-count-regressed':x['windows'][0]['endNative']=0
        result=validate(x)
        check(result['usable_cpu_capture'] and not result['complete_selected_frame_capture'] and summaries(x)[0]['top']==[],reason+' remains invalid, does not infer stacks')
    x=copy.deepcopy(good)
    for i in range(6):invalid_window(x,i,'no-cpu-samples')
    check(not validate(x)['usable_cpu_capture'],'all-invalid capture unusable')
    for label,change in [('marker overflow',lambda x:x.update(markerDropped=1)),('global time cap',lambda x:x.update(stopReason='diagnostic-window-cap'))]:
        x=copy.deepcopy(good);change(x);check(not validate(x)['complete_selected_frame_capture'],label+' cannot claim complete capture')
    bad=[('invalid window retains stacks',lambda x:x['windows'][0].update(usable_cpu=False,invalidReasons=['lost'])),
         ('missing RENDER marked complete',lambda x:x['windows'][0].update(closeReason='missing-render')),
         ('partial and complete simultaneously',lambda x:x['windows'][0].update(partial_window=True)),
         ('partial absent despite no RENDER',lambda x:x['windows'][0].update(closeReason='stop-before-render',completed_render_window=False)),
         ('partial counter regression',lambda x:x['windows'][0].update(closeReason='stop-before-render',partial_window=True,completed_render_window=False,endNative=0)),
         ('partial truncated buffer',lambda x:x['windows'][0].update(closeReason='missing-render',partial_window=True,completed_render_window=False,nativeTruncated=True)),
         ('tail absent despite truncated stack',lambda x:x['windows'][0].update(stack_tail_truncated=True,complete_stack_capture=False)),
         ('tail marked but visible stack too short',lambda x:x['windows'][0].update(stack_tails=[True],stack_tail_truncated=True,complete_stack_capture=False)),
         ('truncated tail claims complete stack',lambda x:x['windows'][0].update(stacks=[['f']*24],stack_tails=[True],stack_tail_truncated=True)),
         ('stack tail metadata count mismatch',lambda x:x['windows'][0].update(stack_tails=[])),
         ('invalid stack metadata retains CPU qualification',lambda x:x['windows'][0].update(stackTruncated=True)),
         ('counter regression marked valid',lambda x:x['windows'][0].update(startNative=4)),
         ('zero CPU marked valid',lambda x:x['windows'][0].update(cpuRows=[])),
         ('duplicate ordinal',lambda x:x['windows'][0].update(cpuRows=[[1,1,0],[1,2,0]])),
         ('bad stack index',lambda x:x['windows'][0].update(cpuRows=[[1,1,1]])),
         ('non-finite sample time',lambda x:x['windows'][0].update(cpuRows=[[1,float('nan'),0]])),
         ('native scan beyond cap',lambda x:x['windows'][0].update(nativeScanned=250001)),
         ('duplicate frame identity',lambda x:x['windows'][1].update(frame=1)),
         ('wrong duplicate-render total',lambda x:x.update(duplicateRenders=2)),
         ('hidden skipped frame',lambda x:x.update(observedFrames=9)),
         ('marker regression inside valid window',lambda x:x['markers'].append(dict(label='baseline-frame',t=146,frame=1,window=0,nativeCount=0))),
         ('too long stack name',lambda x:x['windows'][0].update(stacks=[['x'*193]])),
         ('more than six windows',lambda x:x['windows'].append(copy.deepcopy(x['windows'][0])))]
    for label,change in bad:
        x=copy.deepcopy(good);change(x);rejected=False
        try:validate(x)
        except (AssertionError,KeyError,TypeError,ValueError):rejected=True
        check(rejected,label+' rejected')
    for name,digest in read(HERE/'driver-inputs.json')['sources'].items():check(sha(HERE/'tests'/name)==digest,'source hash '+name)
    for path in HERE.glob('*.py'):compile(path.read_text('utf-8'),str(path),'exec')
    before=(HERE/'baseline/RoomInputCpuProfile.as').read_text('utf-8')
    (HERE/'helper.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),p.splitlines(True),fromfile='original-frame-helper',tofile='intact-partial-frame-helper')),encoding='utf-8')
    result=dict(scope='source-only and Python report counterexamples; not AS execution',assertions=checks,passed=len(checks),failed=0,compiled=False,runtime_tested=False)
    (HERE/'static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    ancestors=[BASE/'prepared.json',PREVIOUS/'generate.py',PREVIOUS/'prepare.py',old/'RoomInputCpuProfile.as',old/'source-manifest.json',
        ROOT/'experimental/recovery-seed-raster-control/prepare_driver.py',ROOT/'experimental/recovery-seed-raster-control/native_runner.py',ROOT/'experimental/recovery-seed-raster-control/control_inputs.py']
    files=[p for p in HERE.rglob('*') if p.is_file() and p!=HERE/'source-manifest.json' and '__pycache__' not in p.parts]
    manifest=dict(ancestor_manifest=BASE_PIN,compiled=False,runtime_tested=False,diagnostic_only=True,
        ancestors={p.relative_to(ROOT).as_posix():sha(p) for p in ancestors},files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(files)})
    (HERE/'source-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=len(checks),failed=0,compiled=False,runtime_tested=False)))

if __name__=='__main__':main()
