"""Static source/provenance checks only; never launch compiler or game."""
from pathlib import Path
import ast,hashlib,json
from copy import deepcopy
from audit_profile import audit_profiles
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-early-sandy-scene-driver-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def text(p):return p.read_text(encoding='utf-8-sig')
def main():
    checks=[]
    def check(ok,label):
        assert ok,label
        checks.append(label)
    before=text(BASE/'tests/FirstRasterSceneProbe.as')
    after=text(HERE/'tests/FirstRasterSceneProbe.as')
    edits=json.loads(text(HERE/'probe-edits.json'))
    rebuilt=after
    for old,new in reversed(edits):
        check(rebuilt.count(new)==1,'exact reversible probe edit '+old[:50])
        rebuilt=rebuilt.replace(new,old)
    check(rebuilt==before,'all original probe behavior and assertion text retained after removing only observer insertions')
    assertions=before.split('         var ok:Boolean=',1)[1].split('         return {passed:',1)[0]
    check(assertions in after,'entire original finish assertion block byte-for-byte identical as text')
    helper=text(HERE/'tests/PaintTimingBuffer.as')
    check('LIMIT:int=32' in helper and 'if(rows.length>=LIMIT){overflow=true;detach();return;}' in helper,'hard bounded rows, explicit overflow and detach')
    check('calls++;' in helper and 'inclusiveTotalMs+=duration' in helper,'all received calls aggregate before selection')
    check('zeroMsStableResidentSkipped++;return;' in helper and 'v.completed===true && sameWorld && sameGame && sameRenderer && sameLoc' in helper,'filter counts only zero-ms stable-resident successful identity-preserving calls')
    check(helper.index('inclusiveTotalMs+=duration')<helper.index('if(rows.length>=LIMIT)'), 'aggregate includes overflow-triggering call, then detaches explicitly')
    check('if(cls.rconnectPaintTimingBridge===own)' in helper,'only clear owned diagnostic subscriber')
    check('if(cls.rconnectPaintTimingBridge!=null)' in helper,'never replace existing subscriber')
    check('nativeFaults==0 && ownershipPreserved' in helper,'native faults and owner conflict invalidate diagnostic')
    check('v.worldRendererAtStart===true && v.worldRendererAtEnd===true' in helper and 'v.worldLocAtStart===true && v.worldLocAtEnd===true' in helper,'native world-renderer and world-loc identities verified at both boundaries')
    check('paintProbe.bind(w,l,g);' in after and 'if(active && ticket!=null' in after,'bind actual sceneOpen even when solo returns null ticket')
    check(after.index('paintProbe.bind(w,l,g);')<after.index('if(active && ticket!=null'),'solo binding precedes ticket predicate')
    check('paintProbe.begin(mod.game.world);' in after,'observe every segment including solo')
    check('sample():void' not in helper,'helper has no per-frame polling')
    receiver=helper.split('      private function receive(',1)[1].split('      public function finish(',1)[0]
    check('Log.' not in receiver and 'JSON.' not in receiver,'receive only buffers; no log serialization in measured callbacks')
    for forbidden in ('Math.random','BitmapData','FileStream','dispatchEvent','acquire(','.receive(','.gotoLand(','.beginMission('):
        check(forbidden not in helper,'no gameplay or heavy observation operation '+forbidden)
    check('finishPaint("dispose")' in after and 'EARLY PAINT PROFILE' in after,'failure cleanup emits one buffered result')
    for name in ('RoomTravelTimingTestDoc.as','RoomTravelSceneTestDoc.as','A22RoomMetrics.as'):
        old=json.loads(text(BASE/'prepared.json'))['files']['tests/'+name]
        check(sha(BASE/'tests'/name)==old,'original unchanged assertion driver '+name)
    for path in HERE.glob('*.py'):ast.parse(text(path),filename=str(path))
    check(True,'all new Python files parse')
    profiles=[]
    for segment in range(3):
        row=dict(segment=segment,sequence=1,phase='ensure-work',location=1,sameRasterRoom=True,
            started=10,finished=13,startedWall=1000,finishedWall=1003,initial=False,residentBefore=0,residentAfter=1)
        for k in ('sameWorld','sameGame','sameRenderer','sameLoc','completed','worldRendererAtStart',
                  'worldRendererAtEnd','worldLocAtStart','worldLocAtEnd'):row[k]=True
        profiles.append(dict(segment=segment,kind='ensure-work',reason='finish',limit=32,diagnosticOnly=True,
            performanceQualified=False,passed=True,observationComplete=True,available=True,overflow=False,
            ownershipPreserved=True,faults=0,nativeFaults=0,bindingConflicts=0,incompleteCalls=0,
            observedCalls=1,zeroMsStableResidentSkipped=0,rasterRoomBound=True,targetRows=1,
            inclusiveTotalMs=3,maxMs=3,positiveMsCalls=1,rows=[row]))
    def travels(p):return [dict(round=x['segment'],rasterEvidence=dict(paintEvidence=deepcopy(x))) for x in p]
    check(audit_profiles(profiles,travels(profiles))['valid'],'pure-data audit accepts internally consistent three-segment trace')
    negatives=[('nativeFaults',1),('overflow',True),('ownershipPreserved',False),('observedCalls',2),('inclusiveTotalMs',6)]
    for field,bad in negatives:
        p=deepcopy(profiles);p[0][field]=bad
        rejected=False
        try:audit_profiles(p,travels(p))
        except AssertionError:rejected=True
        check(rejected,'pure-data audit rejects '+field+' corruption')
    p=deepcopy(profiles);p[0]['rows'][0]['worldRendererAtEnd']=False
    rejected=False
    try:audit_profiles(p,travels(p))
    except AssertionError:rejected=True
    check(rejected,'pure-data audit rejects replaced world renderer')
    rejected=False
    try:audit_profiles(profiles,travels(profiles)[:2])
    except AssertionError:rejected=True
    check(rejected,'pure-data audit rejects incomplete original travel results')
    print(json.dumps(dict(passed=len(checks),checks=checks,compiled=False,air_run=False,performance_qualified=False),ensure_ascii=False))
if __name__=='__main__':main()
