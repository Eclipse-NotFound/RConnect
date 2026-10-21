"""Derive external AS fixtures from the exact failed frozen driver01. No compiler."""
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-gas-driver-01/tests'
BASE_HASHES = {
    'GasPulseNativeTestDoc.as': 'c2e7955b918a37a9d2c87825725ae1131d5c41e11a1177dc5fae7ea1e33e1bad',
    'GasPulseProbe.as': '498ca428ed190a3d79ab1918758031c87eb92770e69f302abf74d3a083950b71',
}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p, text):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(text.encode('utf-8'))
def one(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)
def source(name='GasPulseNativeTestDoc.as'):
    path = BASE / name
    assert sha(path) == BASE_HASHES[name]
    t = path.read_text(encoding='utf-8')
    if name == 'GasPulseNativeTestDoc.as':
        t = one(t, '      private var gasBullets:Array=[],lastShotFrame:int=-100,gasOverlap:Boolean=false,gasDone:Boolean=false;',
            '''      private var gasBullets:Array=[],lastShotFrame:int=-100,gasOverlap:Boolean=false,gasDone:Boolean=false;
      private var releasePending:Boolean=false,throwGates:Array=[];''')
        t = one(t, '          gasBullets=[];lastShotFrame=-100;gasOverlap=false;gasDone=false;'.lstrip(),
            'gasBullets=[];lastShotFrame=-100;gasOverlap=false;gasDone=false;releasePending=false;throwGates=[];')
        t = one(t, '''         if(phase=="run" && source && sourceShots<int(spec.shots) && gun!=null && gameFrame>lastShotFrame+1) {
            if(spec.magic===true)ctr.keyMagic=true;else if(spec.quick)ctr.keyGrenad=true;else ctr.keyAttack=true;
         }''', '''         if(phase=="run" && source && sourceShots<int(spec.shots) && gun!=null) {
            // Native WThrow sets t_auto=3; pressing too early renews that latch.
            // Leave G released until native actions (not this driver) clear it.
            if(releasePending && gameFrame>lastShotFrame && int(gun.t_auto)==0 && gun.attackPos()) {
               throwGates.push({afterShot:sourceShots,afterFrame:lastShotFrame,frame:gameFrame,at:getTimer(),
                  tAuto:int(gun.t_auto),tAttack:int(gun.t_attack),tReload:int(gun.t_reload),attackPos:gun.attackPos()});
               releasePending=false;
            }
            if(!releasePending) {
               if(spec.magic===true)ctr.keyMagic=true;else if(spec.quick)ctr.keyGrenad=true;else ctr.keyAttack=true;
            }
         }''')
        t = one(t, 'nativeShots[bullet]=true;sourceShots++;issued=true;lastShotFrame=gameFrame;',
            'nativeShots[bullet]=true;sourceShots++;issued=true;lastShotFrame=gameFrame;releasePending=true;')
        t = one(t, 'overlap:gasOverlap,unexpected:unexpectedBullets,inputReleased:inputReleased,proof:proof};',
            'overlap:gasOverlap,unexpected:unexpectedBullets,inputReleased:inputReleased,throwGates:throwGates,proof:proof};')
        t = one(t, '            check(sourceShots==int(spec.shots) && inputReleased>0,"requested actual G throws and input release");',
            '''            check(sourceShots==int(spec.shots) && inputReleased>0,"requested actual G throws and input release");
            var released:Boolean=throwGates.length==Math.max(0,int(spec.shots)-1);
            for each(var gate:Object in throwGates)released=released && gate.tAuto==0 && gate.attackPos===true
               && gate.tAttack<=0 && gate.tReload<=0 && gate.frame>gate.afterFrame;
            check(released,"each repeated G waits for native release latch and attack readiness without writes");''')
        t = one(t, '      private function fail(s:String):void {check(false,s);send("done");finish();}',
            '''      private function fail(s:String):void {
         if(gun!=null)Log.d("GAS INPUT DIAGNOSTIC "+JSON.stringify({round:round,phase:phase,shots:sourceShots,
            requested:spec==null?0:int(spec.shots),pending:releasePending,frame:gameFrame,lastShotFrame:lastShotFrame,
            tAuto:int(gun.t_auto),tAttack:int(gun.t_attack),tReload:int(gun.t_reload),attackPos:gun.attackPos(),gates:throwGates}));
         check(false,s);send("done");finish();
      }''')
    elif name == 'GasPulseProbe.as':
        t = one(t, 'bornFrame:frame,endAt:0,endWall:0,alphaMin:1,alphaMax:0,samples:[]};',
            'bornFrame:frame,endAt:0,endWall:0,alphaMin:1,alphaMax:0,samples:[],captures:[]};')
        t = one(t, '''         var sample:Object=pose(v,now,frame);
         if(row.samples.length>0 && row.samples[row.samples.length-1].frame==frame)row.samples[row.samples.length-1]=sample;
         else if(row.samples.length<128)row.samples.push(sample);else overflow=true;
         if(withPart==null && v.visible && v.stage!=null && v.alpha>=.5)capturePixels(v,row,frame);''',
            '''         var sample:Object=pose(v,now,frame);
         sample.observedAt=now;sample.observedWall=sample.wall;sample.revision=0;
         if(row.samples.length>0 && row.samples[row.samples.length-1].frame==frame) {
            var previous:Object=row.samples[row.samples.length-1];
            // Preserve the first observation identity/time in this game frame.
            // Replace the final pose, but never mutate a captured sample object.
            sample.at=previous.at;sample.wall=previous.wall;sample.revision=int(previous.revision)+1;
            sample.sampleId=String(frame)+":"+String(sample.revision);
            row.samples[row.samples.length-1]=sample;
         } else {
            sample.sampleId=String(frame)+":0";
            if(row.samples.length<128)row.samples.push(sample);else overflow=true;
         }
         if(withPart==null && v.visible && v.stage!=null && v.alpha>=.5)capturePixels(v,row,frame,sample);''')
        t = one(t, 'private function capturePixels(v:DisplayObject,row:Object,frame:int):void {',
            'private function capturePixels(v:DisplayObject,row:Object,frame:int,sample:Object):void {')
        t = one(t, '''         try {withPart.draw(root,matrix);v.visible=false;withoutPart.draw(root,matrix);}finally{v.visible=visible;}
         pixel={visual:row.id,frame:frame,sampleAt:row.samples[row.samples.length-1].at,
            pose:pose(v,start,frame),at:start,wall:new Date().time,drawMs:getTimer()-start,''',
            '''         var beforePose:Object=pose(v,start,frame);
         row.captures.push(sample); // An immutable reference to this exact RENDER revision.
         try {withPart.draw(root,matrix);v.visible=false;withoutPart.draw(root,matrix);}finally{v.visible=visible;}
         pixel={visual:row.id,frame:frame,sampleAt:sample.at,sampleId:sample.sampleId,observedAt:sample.observedAt,
            pose:beforePose,afterPose:pose(v,getTimer(),frame),at:start,wall:new Date().time,drawMs:getTimer()-start,''')
        t = one(t, 'quietMs:readAt-lastActivity,lastActivity:lastActivity,clockObservation:',
            'quietMs:readAt-lastActivity,lastActivity:lastActivity,observationSchema:"first-time-final-pose-capture-revision-v2",clockObservation:')
    else: raise ValueError(name)
    return t

def main():
    patch = ''
    for name in BASE_HASHES:
        text = source(name)
        put(HERE/'native'/name, text)
        patch += ''.join(difflib.unified_diff((BASE/name).read_text(encoding='utf-8').splitlines(True), text.splitlines(True),
                                             fromfile='frozen-driver01/'+name, tofile='native-v2/'+name))
    put(HERE/'driver.patch', patch)
    plan = dict(entry='GasPulseNativeTestDoc', baseline=str(BASE.relative_to(ROOT)), baseline_hashes=BASE_HASHES,
                files={n:sha(HERE/'native'/n) for n in BASE_HASHES}, rounds=4, seconds=360,
                per_phase_timeout_ms=26000, cold_first_round=True, generator_sha256=sha(Path(__file__)),
                compiled=False, air_started=False, performance_qualified=False)
    put(HERE/'native-plan.json', json.dumps(plan, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(dict(written=True, files=list(plan['files']), JVM_started=False, AIR_started=False)))

if __name__ == '__main__': main()
