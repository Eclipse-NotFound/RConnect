"""Source-only proof, not an AS runtime/semantic or performance result."""
import json
from pathlib import Path
import re
import sys

from generate import BASE, FILES, HELPER, HERE, ROOT, MARK, mask, sha, stripped
import prepare


def main():
    proposal,base,driver=prepare.verify_proposal()
    checks=[]

    def check(value,label):
        assert value,label
        checks.append(dict(label=label,passed=True))

    allowed={'RestoreCostTrace.enable','RestoreCostTrace.transaction','RestoreCostTrace.phase',
             'RestoreCostTrace.begin','RestoreCostTrace.end','RestoreCostTrace.postGrant',
             'RestoreCostTrace.abort','RestoreCostTrace.count','RestoreCostTrace.createdClass',
             'game.roomKey','String','Number','if'}
    block_count=0
    for name in FILES:
        original=(BASE/'src'/name).read_bytes()
        text=(HERE/'src'/name).read_text(encoding='utf-8')
        check(stripped(text).encode('utf-8')==original,'strip restores exact recovery07 '+name)
        def method_depths(source):
            clean=mask(source)
            return [(m[1],clean[:m.start()].count('{')-clean[:m.start()].count('}'))
                    for m in re.finditer(r'\b(?:public|private|protected|internal)\s+(?:static\s+)?function\s+(\w+)\(',clean)]
        clean=mask(text)
        check(clean.count('{')==clean.count('}') and method_depths(text)==method_depths(original.decode('utf-8')),
              'method/class scope nesting preserved '+name)
        for part in MARK.finditer(text):
            code=mask(part[0]);block_count+=1
            calls=set(re.findall(r'([A-Za-z_$][\w.$]*)\s*\(',code))
            check(calls<=allowed,'block '+part[1]+' adds diagnostic/read-only calls only')
    check(block_count==proposal['inserted_blocks'],'all inserted blocks counted')
    helper=(HERE/'src'/HELPER).read_text(encoding='utf-8')
    check(helper.count('Log.d(')==1,'only one aggregate log call, no per-unit logs')
    check('LIMIT:int=3' in helper and 'size>=64' in helper and 'frame.renders.length>=16' in helper,
          'transaction/class/render buffers bounded')
    check('record.frames.length>=3' in helper and 'three-complete-enter-frames' in helper,
          'finish at fourth ENTER_FRAME after first three frames')
    check('applicationID.indexOf("pfe-modsettings-rconnect-coop-")!=0' in helper,'actual isolated AIR ID gate retained')
    check(not re.search(r'\b(new\s+Timer|invalidate|updateAfterEvent|dispatchEvent|setPos|restoreCheckpoint|capture|FileStream)\b',mask(helper)),
          'collector has no game, rendering, timer or direct file actions')
    check('stopPropagation' not in helper and 'stopImmediatePropagation' not in helper,'observer does not stop events')
    check('removeEventListener' in helper,'listener teardown is present after quota')
    combined='\n'.join((HERE/'src'/name).read_text(encoding='utf-8') for name in FILES)
    for label in ['unit.constructor','unit.restoreRuntime','unit.restoreInternal','terrain.capture','terrain.restore',
                  'terrain.nativeCapture','terrain.nativeRestore','terrain.viewCapture','terrain.viewCompare',
                  'frame.rcMirror','frame.rcView','frame.rcPerception','frame.rcMask','room.grant','room.commit']:
        check('RestoreCostTrace.begin("'+label+'")' in combined and 'RestoreCostTrace.end("'+label+'")' in combined,
              'timed scope '+label)
    check(driver['changed'] is False,'original scene12 complete frozen inventory verified, unchanged')
    result=dict(passed=True,checks=len(checks),failed=0,assertions=checks,
                source_only=True,as_executed=False,compiled=False,air_started=False,performance_qualified=False,
                base_sha256=base['sha256'],proposal_sha256=sha((HERE/'inputs.json').read_bytes()),
                scene_driver=driver,tools={p.name:sha(p.read_bytes()) for p in
                    [Path(__file__),HERE/'generate.py',HERE/'prepare.py']})
    (HERE/'source-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ['passed','checks','failed','source_only','compiled','air_started']}))


if __name__=='__main__':main()
