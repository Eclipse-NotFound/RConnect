"""Source checks only; never treats simulated Sand state as native evidence."""
import ast,json,re
from pathlib import Path
from prepare import HERE,ROOT,check

def main():
    check();labels=[]
    def yes(value,label):
        assert value,label
        labels.append(label)
    for p in HERE.glob('*.py'):
        ast.parse(p.read_text(encoding='utf-8-sig'));labels.append('Python syntax '+p.name)
    source=(HERE/'tests/SandyHoldNativeTestDoc.as').read_text(encoding='utf-8-sig')
    yes(len(list((HERE/'tests').glob('*.as')))==1,'Only one external document; no Sand substitute or production classes')
    yes('new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,KEY)' in source and
        'new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,KEY)' in source,'Actual Stage down/up event route')
    yes('private static const KEY:uint=220;' in source,'Pinned key matches actual copied release config')
    yes('private static const HOLD_FRAMES:int=12;' in source,'Twelve observed native ENTER callbacks')
    yes('carrier.acquire(directOwner,world,nativeGame,directId)' in source and 'map.acquireEarly(leaseId)' in source,'Both real carrier and real MapGeneration refusal tested')
    yes('carrier.query(world,nativeGame)' in source,'State read from actual helper, not a fixture object')
    yes('state.sandyLeft<activeStart' in source,'Actual active counter must progress before and after hold')
    yes('replaySeen=true;denyDuring("replay")' in source,'Replay refusal requires actual post-key phase')
    yes('if(state.phase!=="idle")return;' in source,'Replay ends naturally; no forced transition')
    yes('if(frames==2 || frames==5)down();' in source and 'if(frames==7)up();' in source,'Held key down/repeat/up stimuli retained')
    yes('if(frames<HOLD_FRAMES)return;' in source,'No early held-window completion')
    yes('map.releaseEarly(leaseId+"-other")===false' in source,'Wrong production lease release is rejected')
    yes('world.game!==nativeGame' in source and 'mod.game.gg!==actor' in source,'Real identity continuity required')
    yes(not re.search(r'(?:sandyActive|replaying|sandyLeft|cooldownLeft|replayIdx)\s*=(?!=)',source),'No private Sand state writes')
    yes(not re.search(r'\.(?:startSandy|endSandy|stepSandy|stepReplay)\s*\(',source),'No direct private Sand execution')
    yes(not re.search(r'\.(?:t_exit|onPause|frameRate|ggControl|noAct)\s*=(?!=)',source),'No World pause/countdown/control or stage cadence writes')
    yes('enemyManualStepQualified:false,cooldownFreezeQualified:false' in source,'Unexercised enemy/cooldown boundaries explicitly unqualified')
    yes('travelFallbackQualified:false' in source,'Interface lifecycle is not claimed as full travel fallback')
    cfg=(ROOT.parent/'Sandevistan/release/config.txt').read_text(encoding='utf-8-sig')
    for line in ('hotkey=220','duration=210','cooldown=0','debugtest=0','esandyenabled=0'):
        yes(line in cfg.splitlines(),'Actual read-only config '+line)
    run=(HERE/'run.py').read_text()
    for needle in ("str(TRAVEL/'native_runner.py')","'--solo'","'--all-mods'","'--private-desktop'","'--require-exclusive-air'",'verify_host_intent(HOST,host,after)',"row['checks']==41"):
        yes(needle in run,'Runtime contract '+needle)
    yes('function_only=True,performance_qualified=False' in run,'Lifecycle result explicitly excludes performance qualification')
    print(json.dumps(dict(static_passed=True,checks=len(labels),labels=labels,compiled=False,air_started=False,
        native_evidence=False,simulated_state=False),ensure_ascii=False,indent=2))
if __name__=='__main__':main()
