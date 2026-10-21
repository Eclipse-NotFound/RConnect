"""Pure Python integrity and diagnostic parser counterexamples; no process launch."""
import ast
import copy
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import analyze
import make_overlay as recipe

HERE=Path(__file__).resolve().parent
checks=[]
def check(label,ok):
    assert ok,label
    checks.append(dict(label=label,passed=True))
def row(kind,at,*data):return [kind,at,1,1,1,0]+list(data)+[None]*(18-len(data))
def fixture(role):
    records=[row(10,100,0,100000),
        row(2,101,1,7,1,2,1,1000,101,100,0,0,1,None,None),
        row(1,102,1,1,102,0,0,1000,0,0,0,None,1,0,1,0,None,0),
        row(1,102,1,3,102,900,-898,1000,102,0,0,None,1,0,1,0,None,0),
        row(1,102,1,2,102,900,-898,1000,102,102,1,None,1,0,1,0,1000,0),
        row(9,103,1),row(1,103,1,4,103,900,-898,None,103,102,1,901,1,0,1,0,1000,0),
        row(1,103,1,5,103,901,-898,None,103,102,1,901,1,0,1,0,1000,3),row(9,104,2),row(9,105,3)]
    if role=='join':records += [row(3,106,1,1,1,106,None,901,1000,1000,1000,0,0,0,106),
        row(3,200,1,2,1,200,1001,1001,1100,1000,1099,0,1,1,195,1000),
        row(3,300,1,4,1,300,1100,1100,1200,1000,1099,1100,1,1,295,1066),
        row(3,300,1,3,1,300,None,1100,1200,1000,1099,1100,1,1,295,1066)]
    records.append(row(10,400,1,1))
    header=dict(schema=13,role=role,width=24,capacity=32768,rows=len(records),numericBytes=6*1024*1024,dropped=0,
        occupied=False,firstRoundComplete=True,clocks=1,hookErrors=0,identityOverflow=False,lateBindings=0,
        complete=True,diagnosticOnly=True,performanceQualified=False,hookCalls=10,hookCostMs=0,hookMaxMs=0,
        frameCalls=3,frameCostMs=0,frameMaxMs=0)
    done=dict(rows=len(records),complete=True,exportMs=1,diagnosticOnly=True,performanceQualified=False)
    proof=dict(readbackAt=401,wireRows=[dict(key='7:1',firstAt=107,frames=[dict(at=1000)])] if role=='join' else [])
    result=dict(role=role,round=0,value=dict(proof=proof))
    return dict(header=header,done=done,rows=records,result=result)
def text(value):
    return '\n'.join(['GAS CLOCK HEADER '+json.dumps(value['header']),
        'GAS CLOCK ROWS '+json.dumps(dict(from_=0,rows=value['rows'])).replace('"from_"','"from"'),
        'GAS CLOCK DONE '+json.dumps(value['done']),'GAS PULSE RESULT '+json.dumps(value['result'])])
def reject(label,modify):
    value=fixture('join');modify(value)
    check(label,not analyze.inspect(text(value),'join')['complete'])
def main():
    with patch('subprocess.Popen',side_effect=AssertionError('pure Python only')):
        for path in sorted(HERE.glob('*.py')):
            ast.parse(path.read_text(encoding='utf-8'));check('Python syntax '+path.name,True)
        for path in sorted(HERE.rglob('*.as')):
            value=path.read_text(encoding='utf-8');opening=value.index('{')
            ending=recipe.parser.closing_brace(value,opening)
            check('AS package braces '+path.name,not value[ending+1:].strip())
        meta=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
        check('accurate13 binary and prepared ancestry',recipe.sha(recipe.BASE/'RConnectMod.swf')==recipe.BASE_SHA
              and recipe.sha(recipe.BASE/'prepared.json')==recipe.BASE_MANIFEST)
        base=json.loads((recipe.BASE/'prepared.json').read_text(encoding='utf-8'))
        check('all 87 accurate13 source files unchanged',len(base['source'])==87 and all(
            recipe.sha(recipe.BASE/'src'/p)==h for p,h in base['source'].items()))
        for item in meta['files']:
            path=HERE/item['overlay'];original=Path(item['source'])
            check('strip exact bytes '+path.name,recipe.plain(path.read_text(encoding='utf-8')).encode('utf-8')==original.read_bytes())
            check('manifest hashes '+path.name,recipe.sha(path)==item['sha256'] and recipe.sha(original)==item['source_sha256'])
        for p,h in dict(meta['dependencies'],**meta['support']).items():check('exact dependency '+Path(p).name,recipe.sha(Path(p))==h)
        for p,h in meta['new_files'].items():check('new helper manifest '+Path(p).name,recipe.sha(HERE/p)==h)
        source=(HERE/'src/rconnect/game/RemoteMotion.as').read_text(encoding='utf-8')
        original=(recipe.BASE/'src/rconnect/game/RemoteMotion.as').read_text(encoding='utf-8')
        check('no extra rateHeld call or owner traversal',source.count('rateHeld()')==original.count('rateHeld()')
              and source.count('rateOwners')==original.count('rateOwners'))
        for token in ('sample(now)','sampleTimed(now)','delay()','pushTimed(snap,now)'):
            check('no added clock evaluation '+token,source.count(token)==original.count(token))
        bridge=(HERE/'src/rconnect/game/GameBridge.as').read_text(encoding='utf-8')
        check('bind before first player push',bridge.index('FlightDiagnostics.bind(rec.motion')<bridge.index('rec.motion.push(snap,getTimer());'))
        helper=(HERE/'src/rconnect/diagnostics/FlightDiagnostics.as').read_text(encoding='utf-8')
        recorder=(HERE/'tests/GasClockRecorder.as').read_text(encoding='utf-8')
        check('default null sink / two actor clocks', 'sink:Object=null' in helper and 'boundCount>=2' in helper)
        check('late existing timed or legacy state rejected','isFinite(m.sourceTime) || m.currentSample!=null' in helper)
        check('fixed 6MiB / overflow invalidates','WIDTH:int=24,MAX_ROWS:int=32768' in recorder and 'dropped==0' in recorder)
        check('no diagnostic log inside production hooks','Log.' not in helper)
        check('only deferred export writes logs',recorder.count('Log.d(')==3 and recorder.index('public function finish()')<recorder.index('Log.d('))
        driver=(HERE/'tests/GasPulseNativeTestDoc.as').read_text(encoding='utf-8')
        check('first round cutoff and deferred finish', 'if(round==0 && clockDiagnostic!=null)clockDiagnostic.stop(true);' in driver
              and driver.count('clockDiagnostic.finish()')==1)
        for role in ('host','join'):
            report=analyze.inspect(text(fixture(role)),role)
            check('synthetic complete '+role,report['complete'])
        report=analyze.inspect(text(fixture('join')),'join')
        check('schema indices retain source/cursor/wire identity',report['gas']['sourceFirst']==1000 and report['gas']['cursorAtReceive']==901
              and report['gas']['wireKey']=='7:1' and report['gas']['receiveToShow']==94)
        check('wire observer order is diagnostic not invented timing gate',report['gas']['receiptMarkerMinusWireObserverMs']==-1)
        reject('overflow fails',lambda v:v['header'].update(dropped=1))
        reject('late bind fails',lambda v:v['header'].update(lateBindings=1))
        reject('third clock fails',lambda v:v['header'].update(clocks=3))
        reject('callback error fails',lambda v:v['header'].update(hookErrors=1))
        reject('unfinished first round fails',lambda v:v['header'].update(firstRoundComplete=False))
        reject('incomplete export fails',lambda v:v['done'].update(rows=0))
        reject('late cutoff fails',lambda v:v['result']['value']['proof'].update(readbackAt=300))
        reject('missing exact gas id fails',lambda v:v['result']['value']['proof']['wireRows'][0].update(key='7:2'))
        reject('missing source birth identity fails',lambda v:v['result']['value']['proof']['wireRows'][0]['frames'][0].update(at=999))
        reject('ambiguous gas identity fails',lambda v:v['result']['value']['proof']['wireRows'].append(copy.deepcopy(v['result']['value']['proof']['wireRows'][0])))
        reject('stage visibility absent fails',lambda v:v['rows'][-4].__setitem__(17,0))
        reject('source history before binding fails',lambda v:v['rows'][1].__setitem__(17,12))
        reject('missing removal fails',lambda v:v['rows'][-2].__setitem__(7,2))
        reject('missing strictEnd comparison time fails',lambda v:v['rows'][-3].__setitem__(10,None))
        check('last sampled pose omission remains observable',report['gas']['lastShownPoseAtStrictEnd']==1066
              and report['gas']['lastReceivedPoseAtStrictEnd']==1099 and report['gas']['actualTimeAtStrictEnd']==1100)
        reject('missing own cost fails',lambda v:v['header'].pop('hookCostMs'))
        reject('unknown operation fails',lambda v:v['rows'][2].__setitem__(7,100))
        reject('invalid numeric value fails',lambda v:v['rows'][2].__setitem__(10,'nan'))
        reject('malformed width fails',lambda v:v['rows'][2].pop())
        reject('unbalanced sample fails',lambda v:v['rows'][7].__setitem__(7,4))
        reject('unbalanced push fails',lambda v:v['rows'][4].__setitem__(7,7))
        check('original FAIL never read as diagnostic pass qualification',report['performance_qualified'] is False
              and 'native_game_pass' not in report)
    result=dict(passed=True,checks=len(checks),rows=checks,JVM=False,AIR=False,compiled=False,native_qualified=False,
                diagnostic_runtime_qualified=False,performance_qualified=False)
    (HERE/'static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,checks=len(checks),JVM=False,AIR=False)))
if __name__=='__main__':main()
