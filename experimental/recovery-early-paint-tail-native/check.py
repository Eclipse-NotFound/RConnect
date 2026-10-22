"""Small read-only integration checks. Does not compile, launch or freeze."""
from pathlib import Path
import ast,json,sys,types
from unittest.mock import patch
import baseline,generate,prepare,sampler_admission
HERE=Path(__file__).resolve().parent

def check():
    checks=[]
    def yes(value,label):
        assert value,label
        checks.append(label)
    for name in generate.PINS:
        yes((HERE/'tests'/name).read_text(encoding='utf-8')==generate.transformed(name),'exact additive source '+name)
    for name in ('PaintTailSampler.as','FlashPaintTailSampler.as'):
        yes((HERE/'tests'/name).read_bytes()==(generate.HELPER/'src'/name).read_bytes(),'frozen v3 helper '+name)
    probe=(HERE/'tests/FirstRasterSceneProbe.as').read_text(encoding='utf-8')
    buffer=(HERE/'tests/PaintTimingBuffer.as').read_text(encoding='utf-8')
    yes(probe.index('tailProbe.finish(reason)')<probe.index('paintProbe.finish(reason)'),'close sampler before releasing original slot')
    yes(buffer.index('height:Number(v.height)});')<buffer.index('tailObserver(g,w,gameValue,l,v)'),'aggregate important record before tail callback')
    yes(probe.count('new FlashPaintTailSampler(true)')==1,'one admitted real adapter construction')
    yes('return {passed:ok,expected:expected' in probe,'original scene result predicate retained')
    yes('rconnectPaintTimingBridge=' not in probe.replace(' ',''),'no additional native observer slot replacement')
    recipe=prepare.source()
    yes("'-debug=false','-optimize=true'" in recipe,'original compiler mode')
    yes("'-Xmx384m'" in recipe and '1024**3' in recipe,'original compiler memory guard')
    yes('RoomTravelSceneTestDoc.as' in recipe and 'unchanged_assertion_sources' in recipe,'original scene entry and assertion files')
    import runtime_adapter
    outer=runtime_adapter.outer_source();runner=runtime_adapter.runner_source()
    yes("'ensure-work-tail-cpu-v1'" in outer and "'ensure-work-aggregate-v1'" not in outer,'diagnostic kind bound in original outer wrapper')
    yes('require-exclusive-air' in outer and 'private-desktop' in outer,'original exclusive hidden test isolation')
    yes('from native_inputs import frozen_vision,sandy_input' in runner,'child rechecks frozen runtime inputs')
    yes(runner.index("check_cancel_requested(output,'registration acquired')")<runner.index('assert_installation(args,output)')
        <runner.index('memory_before=memory_snapshot()')<runner.index("candidate=output/'candidate.swf'"),
        'queued installation gate precedes memory/private copy/launch work')
    import queued_gate
    expected=baseline.expected_installation()
    class Output:
        def __init__(self):self.written={}
        def __truediv__(self,name):
            sink=self
            class File:
                def write_text(self,text,encoding):sink.written[name]=json.loads(text)
            return File()
    args=types.SimpleNamespace(effects_driver=HERE/'unused-driver')
    for name,outer,actual,tool_failure in (
        ('match',expected,expected,False),
        ('changed while queued',expected,{**expected,'pfe.swf':'changed'},False),
        ('old outer RV187D',{**expected,baseline.RV_KEY:'187d287b06fea10e6057c8e80287352062cff7577d075181261ddc0d04111272'},expected,False),
        ('frozen tool changed',expected,expected,True)):
        output=Output();calls=[]
        def tools():
            calls.append(True)
            if tool_failure:raise ValueError('frozen tool mismatch')
        stub=types.ModuleType('native_inputs');stub.verify_tools=tools
        failed=False
        with patch.multiple(baseline,sha=lambda p:'test-intent',read=lambda p:dict(installation=outer),installation=lambda:actual),patch.dict(sys.modules,{'native_inputs':stub}):
            try:queued_gate.assert_installation(args,output)
            except (AssertionError,ValueError):failed=True
        yes(failed==(name!='match'),'queued gate '+name)
        yes(bool(calls)==(name in ('match','frozen tool changed')),'gate checks tools only after exact installation '+name)
        yes(set(output.written)==({'installation-gate.json'} if name=='match' else {'installation-gate.json','error.json','result.json'}),
            'gate leaves complete receipt '+name)
    for path in sorted(HERE.glob('*.py')):
        ast.parse(path.read_text(encoding='utf-8-sig'),filename=str(path));checks.append('Python syntax '+path.name)
    component=sampler_admission.verify_component();checks.append('actual v3 component31/0 exact-source proof')
    current=baseline.installation();baseline.assert_current(current,current)
    yes(current[baseline.RV_KEY]==baseline.RV_NEW=='6593ee35008a898bd2d2b1189693a17bd0767c387697bcbee73a387f8fd6ec06','current installation RV6593 only')
    yes(baseline.sha(baseline.frozen_vision())==baseline.RV_OLD,'runtime RV7852 unchanged')
    return dict(source_checks=len(checks),checks=checks,component_evidence=component,
        diagnostic_source_only=True,native_compiled=False,native_air_started=False,performance_qualified=False)

if __name__=='__main__':print(json.dumps(check(),indent=2))
