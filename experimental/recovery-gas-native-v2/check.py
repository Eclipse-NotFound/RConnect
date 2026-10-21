"""Offline source integrity and analyzer counterexamples; never starts JVM/AIR."""
import ast
import copy
import json
from io import BytesIO
from pathlib import Path
from unittest.mock import patch
import generate
import verify_results as verify

HERE=Path(__file__).resolve().parent
rows=[]
def check(label,value):
    assert value,label
    rows.append(dict(label=label,passed=True))
class MemoryLog:
    def __init__(self,text=''):self.text=text
    def read_text(self,**kwargs):return self.text
def fixture(source,requested):
    poses=[dict(at=1000+n*33,wall=100000+n*33,x=1+n,y=2,r=3,sx=1,sy=1,a=alpha,f=1,
                visible=True,c=[1,1,1,1,0,0,0,0],frame=n+1,sourceLo=999+n*33,sourceHi=1000+n*33)
           for n,alpha in enumerate([.6,.4,.1])]
    displayed=copy.deepcopy(poses)
    if not source:
        for p in displayed:p['at']+=4100;p['wall']+=100
    for p in displayed:
        p.update(observedAt=p['at'],observedWall=p['wall'],revision=0,sampleId=str(p['frame'])+':0')
    born=1000 if source else 5100;end=1099 if source else 5200
    visual=dict(id=0,cls='visualGas',bornAt=born,endAt=end,bornWall=100000 if source else 100100,
                endWall=100099 if source else 100200,alphaMin=.1,alphaMax=.6,samples=displayed,captures=[copy.deepcopy(displayed[0])])
    native=dict(id=0,visual=0,x=1,y=2,bornFrame=1,partClass='fe.graph::Part',cls='visualGas',bornAt=1000,endAt=1099,finalLiv=0,
                bornLo=999,bornHi=1000,endLo=1098,endHi=1099)
    wire=dict(key='1:1',firstAt=5002,firstWall=100002,frames=copy.deepcopy(poses),end=1099,strictEnd=True,endReceivedAt=5110,endReceivedWall=100110)
    proof=dict(overflow=False,allEnded=True,readbackAt=end+600,lastActivity=end,quietMs=600,
               observationSchema='first-time-final-pose-capture-revision-v2',
               clockObservation='source-frame-bounds-only',playbackCursorObserved=False,
               pixel=dict(visual=0,frame=1,sampleAt=born,sampleId='1:0',observedAt=born,at=born,pixels=1,
                          pose=copy.deepcopy(displayed[0]),afterPose=copy.deepcopy(displayed[0]),bounds=dict(w=2,h=2)),
               nativeRows=[native] if source else [],visualRows=[visual],wireRows=[] if source else [wire])
    return dict(source=source,id='gasgr',requested=requested,shots=requested if source else 0,inputReleased=2,
                throwGates=[dict(afterShot=1,afterFrame=1,frame=5,at=550,tAuto=0,tAttack=0,tReload=0,attackPos=True)] if source and requested==2 else [],
                overlap=requested==2,unexpected=0,proof=proof,
                shotRows=[dict(born=500+i*100,exploded=900+i*100,end=2900+i*100) for i in range(requested)] if source else [])
def png_pair():
    from PIL import Image
    image=Image.new('RGBA',(2,2),(0,0,0,255));out=BytesIO();image.save(out,format='PNG');without=out.getvalue()
    image.putpixel((0,0),(255,0,0,255));out=BytesIO();image.save(out,format='PNG')
    return out.getvalue(),without
def main():
    with patch('subprocess.Popen',side_effect=AssertionError('offline only')):
        plan=json.loads((HERE/'native-plan.json').read_text())
        check('Exact failed frozen gas driver01 ancestors',all(generate.sha(generate.BASE/name)==digest for name,digest in generate.BASE_HASHES.items()))
        check('Generated native driver exact',generate.source().encode()==(HERE/'native/GasPulseNativeTestDoc.as').read_bytes())
        check('Generated native probe exact',generate.source('GasPulseProbe.as').encode()==(HERE/'native/GasPulseProbe.as').read_bytes())
        check('Native AS inputs match plan',all(generate.sha(HERE/'native'/n)==h for n,h in plan['files'].items()))
        for path in HERE.glob('*.py'):ast.parse(path.read_text(encoding='utf-8'))
        check('Recipes parse',True)
        src=(HERE/'native/GasPulseProbe.as').read_text();driver=(HERE/'native/GasPulseNativeTestDoc.as').read_text()
        check('No production capture or artificial pulse call',all(token not in src+driver for token in
            ['readSnapshot(','.explRun(','.explosion(','.observeWeapon(','.captureGas(','.sourceTime=']))
        check('Native G and overlap requirement retained','ctr.keyGrenad=true' in driver and 'gasOverlap' in driver and 'sourceShots<int(spec.shots)' in driver)
        check('Sampling stops before PNG work','setPhase("result");var proof:Object=ground.result()' in driver)
        check('Exact generic DONE marker','Log.d("COOP EFFECTS DONE gas-pulse-native "+(host?"host":"join"))' in driver)
        check('Source frame bounds use only external event brackets','clockBefore,false,90001' in driver and 'clockAfter,false,89999' in driver and '_remotes' not in src+driver)
        check('Cold first round and original deadlines retained','phase=="boot"?180000:26000' in driver and plan['seconds']==360 and plan['cold_first_round'] is True)
        check('Release waits for native readiness','releasePending && gameFrame>lastShotFrame && int(gun.t_auto)==0 && gun.attackPos()' in driver)
        import re
        check('No writes to native latch or cooldown',not re.search(r'gun\.(?:t_auto|t_attack|t_reload|rapid)\s*=(?!=)',driver))
        check('Capture immutable reference survives final observation replacement','row.captures.push(sample)' in src and 'sample.at=previous.at;sample.wall=previous.wall' in src)
        check('Good scalar fixture validates',not verify.validate(fixture(True,1),True,1) and not verify.validate(fixture(False,2),False,2))
        bad=fixture(False,1);bad['proof']['nativeRows']=[{}]
        check('Replay into native object chain rejected',bool(verify.validate(bad,False,1)))
        bad=fixture(False,1);bad['proof']['wireRows'][0]['strictEnd']=False
        check('Missing strict terminal rejected',bool(verify.validate(bad,False,1)))
        a,b=fixture(True,1),fixture(False,1)
        check('Actual received pose correspondence succeeds',not verify.compare(a,b)[0])
        b['proof']['visualRows'][0]['samples'][0]['x']=999
        check('Invented display pose rejected',bool(verify.compare(a,b)[0]))
        counterexamples=[]
        a,b=fixture(True,1),fixture(False,1);b['proof']['visualRows'][0]['endAt']=5101;b['proof']['visualRows'][0]['endWall']=100101
        counterexamples.append(('Remote disappears 1ms after birth while native source and wire remain alive',bool(verify.compare(a,b)[0])))
        a,b=fixture(True,1),fixture(False,1);b['proof']['visualRows'][0]['samples'][1].update(x=999,f=99)
        counterexamples.append(('Later remote pose and frame wrong after first matching pose',bool(verify.compare(a,b)[0])))
        a,b=fixture(True,1),fixture(False,1);a['proof']['nativeRows'][0]['x']+=999
        for pose in a['proof']['visualRows'][0]['samples']:pose['x']+=999
        counterexamples.append(('Source Part and displayed source positions unrelated to wire',bool(verify.compare(a,b)[0])))
        a,b=fixture(True,1),fixture(False,1)
        for owner,field in [(a,'nativeRows'),(a,'visualRows'),(b,'visualRows')]:
            row=copy.deepcopy(owner['proof'][field][0]);row['id']=1
            if field=='nativeRows':row['visual']=1
            owner['proof'][field].append(row)
        row=copy.deepcopy(b['proof']['wireRows'][0]);row['key']='1:2';b['proof']['wireRows'].append(row)
        counterexamples.append(('Identical complete histories have ambiguous identities',bool(verify.compare(a,b)[0])))
        for name,rejected in counterexamples:check('Review counterexample rejected: '+name,rejected)
        generate.put(HERE/'counterexamples-recheck.json',json.dumps(dict(prior_review='../recovery-gas-native-review/counterexamples.json',
            counterexamples=[dict(name=n,accepted=not rejected) for n,rejected in counterexamples],JVM_started=False,AIR_started=False),indent=2)+'\n')
        a,b=fixture(True,1),fixture(False,1);b['proof']['visualRows'][0]['samples'][1:]=list(reversed(b['proof']['visualRows'][0]['samples'][1:]))
        check('Backward observed trajectory rejected',bool(verify.compare(a,b)[0]))
        a,b=fixture(True,1),fixture(False,1);b['proof']['wireRows'][0]['end']=1001
        check('Wire ending outside real source removal frame rejected',bool(verify.compare(a,b)[0]))
        a,b=fixture(True,1),fixture(False,1);b['proof']['wireRows'][0]['endReceivedAt']=5201
        check('Display removal before actual terminal receipt rejected',bool(verify.compare(a,b)[0]))
        bad=fixture(False,1);del bad['proof']['wireRows'][0]['endReceivedAt']
        check('Missing actual terminal receipt timestamp rejected',bool(verify.validate(bad,False,1)))
        a,b=fixture(True,1),fixture(False,1);b['proof']['visualRows'][0]['samples'].pop()
        check('Missing actual final displayed pose rejected',bool(verify.compare(a,b)[0]))
        a,b=fixture(True,1),fixture(False,1)
        row=b['proof']['visualRows'][0]
        row['samples'][0].update(observedAt=5102,revision=1,sampleId='1:1')
        check('Same-frame later RENDER keeps birth and exact original PNG identity',not verify.validate(b,False,1) and not verify.compare(a,b)[0])
        bad=copy.deepcopy(b);bad['proof']['visualRows'][0]['samples'][0]['at']=5102
        check('Old same-frame birth timestamp overwrite still rejected',bool(verify.validate(bad,False,1)))
        bad=copy.deepcopy(b);bad['proof']['pixel']['sampleId']='1:1'
        check('PNG cannot silently bind replacement RENDER revision',bool(verify.validate(bad,False,1)))
        bad=copy.deepcopy(b);bad['proof']['visualRows'][0]['captures'][0]['observedAt']=5103
        check('Capture cannot postdate final frame observation',bool(verify.validate(bad,False,1)))
        bad=copy.deepcopy(b);bad['proof']['pixel']['afterPose']['a']=.99
        check('Pose changes during with/without screenshot are rejected',bool(verify.validate(bad,False,1)))
        bad=copy.deepcopy(b)
        for p in [bad['proof']['visualRows'][0]['captures'][0],bad['proof']['pixel']['pose'],bad['proof']['pixel']['afterPose']]:p['x']=999
        check('Captured pose must belong to the same ordered wire history',bool(verify.compare(a,bad)[0]))
        bad=fixture(True,2);bad['throwGates'][0]['tAuto']=2
        check('Premature second G while native latch remains set is rejected',bool(verify.validate(bad,True,2)))
        bad=fixture(True,2);bad['throwGates']=[]
        check('Missing native release-readiness observation is rejected',bool(verify.validate(bad,True,2)))
        proof=fixture(True,1)['proof'];with_png,without_png=png_pair();serialized=json.dumps(proof).encode()
        check('Real PNG recomputed difference and exact saved proof pass',not verify.verify_pair(proof,serialized,with_png,without_png)[0])
        bad=copy.deepcopy(proof);bad['quietMs']=999
        check('Log versus saved proof mismatch rejected',bool(verify.verify_pair(proof,json.dumps(bad).encode(),with_png,without_png)[0]))
        check('Identical PNG pair rejected',bool(verify.verify_pair(proof,serialized,without_png,without_png)[0]))
        bad=copy.deepcopy(proof);bad['pixel']['pixels']=2
        check('Claimed pixel count different from actual PNG rejected',bool(verify.verify_pair(bad,json.dumps(bad).encode(),with_png,without_png)[0]))
        bad=copy.deepcopy(proof);bad['pixel']['bounds']['w']=4
        check('PNG dimensions must equal recorded capture rectangle',bool(verify.verify_pair(bad,json.dumps(bad).encode(),with_png,without_png)[0]))
        bad=fixture(False,1);bad['proof']['pixel']['visual']=99
        check('Pixel object and frame metadata must belong to observed track',bool(verify.validate(bad,False,1)))
        h=MemoryLog();j=MemoryLog()
        check('Empty or missing rounds never pass',not verify.analyze(h,j)['passed'])
        texts={'host':[],'join':[]}
        for n in range(4):
            for role in texts:texts[role].append('GAS PULSE RESULT '+json.dumps(dict(round=n,role=role,value=fixture((role=='host')==(n%2==0),1 if n<2 else 2))))
        h.text='\n'.join(texts['host']);j.text='\n'.join(texts['join'])
        check('Complete four bidirectional fixture records accepted',verify.analyze(h,j)['passed'])
        h.text+='\nCOOP FAIL gas-pulse-native injected'
        check('Original framework failure preserved',not verify.analyze(h,j)['passed'])
    result=dict(passed=True,checks=rows,count=len(rows),native_game=False,AS3_executed=False,JVM_started=False,AIR_started=False,performance_qualified=False)
    generate.put(HERE/'offline-checks.json',json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(passed=True,count=len(rows),JVM_started=False,AIR_started=False)))
if __name__=='__main__':main()
