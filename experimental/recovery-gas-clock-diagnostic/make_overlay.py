"""Removable read-only clock insertions over exact recovery13 and gas-v2."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-13';BASE_SHA='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
BASE_MANIFEST='e7109bec3f02ef8c7b5cf1070293022bc1ebf941942b91486910a742fc139fc4'
DRIVER=ROOT/'experimental/recovery-gas-native-v2/native/GasPulseNativeTestDoc.as'
DRIVER_SHA='ce59b035fddb83dc1c37be145523884aef1ea621784321ff742bfb8ae25373ea'
SUPPORT=DRIVER.parent/'GasPulseProbe.as';SUPPORT_SHA='f92507b2a8da89f8d2653c90a617f5ab1eaf008726e74129033065a332a61a72'
VERIFIER=DRIVER.parent.parent/'verify_results.py';VERIFIER_SHA='929201d6a5e4720b98c3ce073b89486cf2db35e4ca49ade181eac091af93716c'
OLD=ROOT/'experimental/recovery-flight-diagnostics/make_overlay.py'
OLD_SHA='6b6dcb0c53d51e614ab9c8c6dc536d5affe18b1c136c347a30f6ce1904a57f98'
PARSER=ROOT/'experimental/recovery-flight-timing08/make_overlay.py'
PARSER_SHA='0a2c3b23ce32c3047297b91ff862aa3ba8c204a88bb512d43735869b28e351e1'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p,name):
    spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
assert sha(OLD)==OLD_SHA and sha(PARSER)==PARSER_SHA
old=load(OLD,'gas_clock_insertions');parser=load(PARSER,'gas_clock_braces')
block,plain,after,before=old.block,old.plain,old.add_after,old.add_before
def wrap(text,name,start,finish):
    m=list(re.finditer(r'(?:public|private) function '+name+r'\([^\n]*\):[^\n{]+\s*\{',text))
    assert len(m)==1,name
    opening=m[0].end()-1;closing=parser.closing_brace(text,opening)
    # AS3's static return checker does not always prove try/finally return
    # completeness. Original Object paths all return; this is unreachable.
    fallback='         return null;\n' if name in ('sampleTimed','settle') else ''
    return text[:opening+1]+block('\n'+start+'\n         try {')+text[opening+1:closing]+block('\n         } finally {\n'+finish+'\n         }\n'+fallback)+text[closing:]
def bridge(s):
    s=after(s,'   import flash.utils.getTimer;\n','   import rconnect.diagnostics.FlightDiagnostics;')
    return before(s,'            rec.motion.push(snap,getTimer());',
        '            if(FlightDiagnostics.sink!=null)FlightDiagnostics.bind(rec.motion,world,loc,id,roomEpoch,\n'
        '               Number(snap.sampleTime),getTimer(),presentationTime(),roomHold,coopPaused);')
def motion(s):
    s=after(s,'   import flash.utils.Dictionary;\n','   import rconnect.diagnostics.FlightDiagnostics;')
    s=before(s,'         var previous:Object=sample(now);',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(8,now,NaN,NaN,0);')
    s=after(s,'         frames=[];\n',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(9,now,NaN,NaN,0);')
    s=wrap(s,'pushTimed',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(1,now,Number(snap.sampleTime),NaN,0);',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(2,now,Number(snap.sampleTime),NaN,0);')
    s=after(s,'offset=clockOffset;cursor=stamp-(immediateStart?0:delay());sampledAt=now;\n',
        '             if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(3,now,stamp,NaN,0);')
    s=wrap(s,'sampleTimed','         var _gasBranch:int=0;',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(5,now,NaN,wanted,_gasBranch);')
    s=after(s,'var beforeCursor:Number=cursor;\n',
        '          if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(4,now,NaN,wanted,0);')
    s=after(s,'if(rateHeld()) {\n','             if(FlightDiagnostics.sink!=null)_gasBranch=1;')
    s=after(s,'else if(enemyRecovery) {\n','             if(FlightDiagnostics.sink!=null)_gasBranch=2;')
    s=after(s,'} else if(actorCalibration()) {\n','             if(FlightDiagnostics.sink!=null)_gasBranch=3;')
    s=wrap(s,'settle',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(6,now,NaN,NaN,0);',
        '         if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))gasObserve(7,now,NaN,NaN,0);')
    # No rateOwners traversal and no extra call to sample(), push(), delay().
    s=before(s,'private function delay():Number {', '''       private function gasObserve(op:int,now:int,stamp:Number,wanted:Number,branch:int):void {
          FlightDiagnostics.motion(this,op,now,cursor,offset,stamp,sampledAt,arrivedAt,frames.length,
             wanted,playbackRate,calibrationDebt,calibrationRate,calibrating,latestSampleTime,branch);
       }''')
    return s
def energy(s):
    s=after(s,'   import rconnect.core.Log;\n','   import rconnect.diagnostics.FlightDiagnostics;')
    s=after(s,'state.records[String(id)]=a;active.push(a);\n',
        '             if(FlightDiagnostics.sink!=null)FlightDiagnostics.gas(a,1,now,NaN);')
    s=after(s,'a.shown=point;a.shownAt=Math.max(int(a.shownAt),now);\n',
        '                if(FlightDiagnostics.sink!=null)FlightDiagnostics.gas(a,2,now,time);')
    s=after(s,'if(ended && s.strictEnd===true) {',
        '\n               if(FlightDiagnostics.sink!=null)FlightDiagnostics.gas(a,4,now,time);\n')
    s=after(s,'         var a:Object=active[index],v:DisplayObject=a.vis as DisplayObject;\n',
        '         if(FlightDiagnostics.sink!=null)FlightDiagnostics.gas(a,3,getTimer(),NaN);')
    return s
def driver(s):
    s=after(s,'      private var releasePending:Boolean=false,throwGates:Array=[];\n','      private var clockDiagnostic:GasClockRecorder;')
    s=after(s,'          t.addEventListener(TimerEvent.TIMER,tick);t.start();'.lstrip(),
        '\n          clockDiagnostic=new GasClockRecorder(host);clockDiagnostic.start();')
    s=after(s,'          mod=RConnectMod.instance;'.lstrip(),
        '\n          if(clockDiagnostic!=null && mod!=null)clockDiagnostic.attach(mod.stage);')
    s=before(s,'          setPhase("result");var proof:Object=ground.result(),shots:Array=[];'.lstrip(),
        '          if(round==0 && clockDiagnostic!=null)clockDiagnostic.stop(true);')
    s=before(s,'          Log.d("COOP EFFECTS DONE gas-pulse-native "+(host?"host":"join"));'.lstrip(),
        '          if(clockDiagnostic!=null)clockDiagnostic.finish();')
    return s
def main():
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA and sha(BASE/'prepared.json')==BASE_MANIFEST
    manifest=json.loads((BASE/'prepared.json').read_text(encoding='utf-8'))
    assert all(sha(BASE/'src'/n)==h for n,h in manifest['source'].items())
    assert sha(DRIVER)==DRIVER_SHA and sha(SUPPORT)==SUPPORT_SHA and sha(VERIFIER)==VERIFIER_SHA
    items=[]
    for name,transform in [('GameBridge',bridge),('RemoteMotion',motion),('EnergyImpactVisuals',energy)]:
        original=BASE/f'src/rconnect/game/{name}.as';text=original.read_bytes().decode('utf-8');modified=transform(text)
        assert plain(modified).encode('utf-8')==original.read_bytes()
        dest=HERE/f'src/rconnect/game/{name}.as';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(modified.encode('utf-8'))
        items.append(dict(source=str(original),source_sha256=sha(original),overlay=dest.relative_to(HERE).as_posix(),sha256=sha(dest),stripped_bytes_equal=True))
    original=DRIVER.read_bytes().decode('utf-8');modified=driver(original)
    assert plain(modified).encode('utf-8')==DRIVER.read_bytes()
    dest=HERE/'tests'/DRIVER.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(modified.encode('utf-8'))
    items.append(dict(source=str(DRIVER),source_sha256=sha(DRIVER),overlay=dest.relative_to(HERE).as_posix(),sha256=sha(dest),stripped_bytes_equal=True))
    result=dict(kind='gas-clock-diagnostic',baseline_sha256=BASE_SHA,baseline_manifest_sha256=BASE_MANIFEST,
        files=items,support={str(SUPPORT):SUPPORT_SHA,str(VERIFIER):VERIFIER_SHA},
        dependencies={str(OLD):OLD_SHA,str(PARSER):PARSER_SHA},diagnostic_only=True,
        new_files={p:sha(HERE/p) for p in ['src/rconnect/diagnostics/FlightDiagnostics.as','tests/GasClockRecorder.as']})
    (HERE/'inputs.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'overlays':3,'driver_stripped_equal':True,'JVM':False,'AIR':False}))
if __name__=='__main__':main()
