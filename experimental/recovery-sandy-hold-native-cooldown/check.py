"""Offline source and result-rejection checks only; never executes a compiler or AIR."""
from pathlib import Path
import ast,copy,difflib,json,re
from native_inputs import HERE,OLD,CONFIG,sha,once,verify_tools,config_bytes,audit_row,host_input,HOST,installation,audit,CANDIDATE,sandy_input

def source_text():
    path=OLD/'tests/SandyHoldNativeTestDoc.as'
    assert sha(path)=='d40aa7c2ed2bfabaedb33641f3f106022479b83f2ca8b994aab44e84ba88c877'
    text=path.read_text(encoding='utf-8-sig')
    edits=(
      ('Actual 003 Sandevistan + early1 MapGeneration','Actual 003 Sandevistan + early2 MapGeneration; isolated cooldown=120'),
      ('private var leaseHeld:Boolean=false;',
       'private var leaseHeld:Boolean=false;\n      private var cooldownPrevious:Number=0,cooldownAdvanced:Boolean=false;'),
      ('ensure(state.held===false && state.cooldownLeft<=0,"real replay naturally finishes under pinned zero cooldown");',
       'ensure(state.held===false && state.cooldownLeft>0 && state.cooldownLeft<=120,"real replay naturally finishes with the pinned nonzero cooldown");'),
      ('               tap();state=query();\n               ensure(state.phase==="active" && state.sandyLeft>0,"same native key activates after held KEY_UP and release");',
       '               cooldownPrevious=state.cooldownLeft;change("cooldown");\n'
       '            }else if(phase=="cooldown") {\n'
       '               if(state.phase!=="idle" || state.held!==false || state.cooldownLeft<0 || state.cooldownLeft>cooldownPrevious)\n'
       '                  throw new Error("Released cooldown changed phase, held state or monotonic direction");\n'
       '               cooldownPrevious=state.cooldownLeft;\n'
       '               if(frames==8) {\n'
       '                  ensure(state.cooldownLeft>0 && state.cooldownLeft<holdState.cooldownLeft,\n'
       '                     "real nonzero cooldown decreases after release under native ENTER callbacks");\n'
       '                  cooldownAdvanced=true;note("cooldown-progress",state);\n'
       '               }\n'
       '               if(state.cooldownLeft>0)return;\n'
       '               ensure(cooldownAdvanced && equalControls(holdControls,controls()),\n'
       '                  "real cooldown naturally reaches zero with unchanged native controls");\n'
       '               note("cooldown-zero",state);tap();state=query();\n'
       '               ensure(state.phase==="active" && state.sandyLeft>0,"same native key activates after held KEY_UP and release");'),
      ('enemyManualStepQualified:false,cooldownFreezeQualified:false',
       'enemyManualStepQualified:false,cooldownFreezeQualified:failed==0 && cooldownAdvanced,cooldownAdvanced:cooldownAdvanced'))
    for old,new in edits:text=once(text,old,new)
    return text

def fixture():
    controls=dict(paused=False,ggControl=True,noAct=False,allStat=1,tExit=0)
    state=dict(phase='idle',held=True,sandyLeft=0,cooldownLeft=120,replayIndex=8,enemyEnabled=False,debugTest=False)
    rows=[dict(label='held',state=state.copy(),controls=controls.copy(),frame=20,phaseFrame=0)]
    rows += [dict(label='held-frame',state=state.copy(),controls=controls.copy(),frame=20+i,phaseFrame=i) for i in range(1,13)]
    state['held']=False
    rows += [dict(label='cooldown',state=state.copy(),frame=32,phaseFrame=0)]
    state['cooldownLeft']=116
    rows += [dict(label='cooldown-progress',state=state.copy(),frame=40,phaseFrame=8)]
    state['cooldownLeft']=0
    rows += [dict(label='cooldown-zero',state=state.copy(),frame=272,phaseFrame=240)]
    return dict(passed=True,checks=43,failed=0,holdFrames=12,keyboardCode=220,cooldownFreezeQualified=True,
        cooldownAdvanced=True,enemyManualStepQualified=False,travelFallbackQualified=False,functionOnly=True,
        performanceQualified=False,observations=rows,cleanup={'final':state.copy()},
        keyEvents=[dict(kind=k,phase='held',frame=f) for k,f in [('down',22),('down',25),('up',27)]]+
                  [dict(kind=k,phase='cooldown',frame=272) for k in ['down','up']])

def main():
    verify_tools();labels=[]
    def yes(value,label):assert value,label;labels.append(label)
    def rejects(callback,label):
        try:callback()
        except (AssertionError,KeyError,ValueError):labels.append(label);return
        raise AssertionError('Accepted negative case: '+label)
    for path in HERE.glob('*.py'):ast.parse(path.read_text(encoding='utf-8-sig'));labels.append('Python syntax '+path.name)
    actual=(HERE/'tests/SandyHoldNativeTestDoc.as').read_text(encoding='utf-8-sig')
    yes(actual==source_text(),'Native source is exactly the narrow lifecycle variant')
    yes(len(list((HERE/'tests').glob('*.as')))==1,'One external document, no replacement production classes')
    yes(not re.search(r'(?:sandyActive|replaying|sandyLeft|cooldownLeft|replayIdx)\s*=(?!=)',actual),'No private counter/state writes')
    yes(not re.search(r'\.(?:startSandy|endSandy|stepSandy|stepReplay)\s*\(',actual),'No direct private Sand execution')
    yes(not re.search(r'\.(?:t_exit|onPause|frameRate|ggControl|noAct)\s*=(?!=)',actual),'No native cadence/control writes')
    changed=config_bytes(CONFIG.read_bytes())
    yes(changed.replace(b'cooldown=120',b'cooldown=0',1)==CONFIG.read_bytes(),'Only the private cooldown field changes')
    yes(b'esandyenabled=0' in changed.splitlines(),'Enemy stepping remains explicitly outside this test')
    rejects(lambda:config_bytes(changed),'Already changed config cannot be admitted as the original')
    rejects(lambda:config_bytes(CONFIG.read_bytes()+b'\ncooldown=0\n'),'Ambiguous config refused')
    from native_runner import source_text as runner_source
    from run import adapted_source
    ast.parse(runner_source());ast.parse(adapted_source());labels.append('Exact runner/outer adaptation counts and Python syntax')
    yes(runner_source().index('queued_gate(args,output)')<runner_source().index('memory_before=memory_snapshot()'),'Queue gate precedes private copies and AIR')
    yes(runner_source().index('configure_sand(frozen,output)')<runner_source().index('configuration_files={};descriptors={};launches=[]'),'Private config is set before role copies/config evidence')
    valid=fixture();yes(audit_row(valid),'Synthetic result parser positive control (not native evidence)')
    for label,mutation in (
        ('Zero hold counter',lambda r:r['observations'][0]['state'].update(cooldownLeft=0)),
        ('Decrement inside hold',lambda r:r['observations'][4]['state'].update(cooldownLeft=119)),
        ('Frozen after release',lambda r:r['observations'][14]['state'].update(cooldownLeft=120)),
        ('Never reached zero',lambda r:r['observations'][15]['state'].update(cooldownLeft=1)),
        ('Early retry key',lambda r:r['keyEvents'][3].update(frame=40)),
        ('Missing held observation',lambda r:r['observations'].pop(2)),
        ('Counterfeit enemy coverage',lambda r:r.update(enemyManualStepQualified=True)),
        ('Wrong total',lambda r:r.update(checks=41))):
        row=copy.deepcopy(valid);mutation(row);rejects(lambda:audit_row(row),label)
    before=installation();host=host_input(HOST,before);rc=audit(CANDIDATE);sand=sandy_input('bridge')
    yes(installation()==before,'Read-only admission leaves installation unchanged')
    print(json.dumps(dict(static_passed=True,checks=len(labels),labels=labels,candidate_sha256=rc['sha256'],
        host_sha256=host['candidate_sha256'],sand_sha256=sand['candidate_sha256'],compiled=False,air_started=False,
        native_evidence=False,performance_qualified=False,enemy_manual_step_qualified=False),ensure_ascii=False,indent=2))
if __name__=='__main__':main()
