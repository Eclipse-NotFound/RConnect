"""Generate source-only CPU sampler inserts against the frozen shared scene driver."""
from pathlib import Path
import difflib,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-seed-gate-driver-01'
BASE_PIN='fe7659ab07e113a2a873c54ee39169f9d769b954892ac0a49d5751ee5c94174d'
BEGIN='// BEGIN EXTERNAL INPUT CPU';END='// END EXTERNAL INPUT CPU'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,s):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def block(s):return '      '+BEGIN+'\n'+s+'\n      '+END+'\n'
def after(s,needle,addition):
    assert s.count(needle)==1,needle
    return s.replace(needle,needle+block(addition),1)
def strip(s):return re.sub(r'^ *'+re.escape(BEGIN)+r'\n.*?^ *'+re.escape(END)+r'\n','',s,flags=re.M|re.S)
def main():
    assert sha(BASE/'prepared.json')==BASE_PIN
    meta=read(BASE/'prepared.json')
    for n,h in meta['files'].items():assert sha(BASE/n)==h,n
    original=(BASE/'tests/RoomTravelTimingTestDoc.as').read_text('utf-8-sig');s=original
    s=after(s,'      private var soloBootTravel:Boolean=false;\n','      private var inputProfile:RoomInputCpuProfile;')
    s=after(s,'         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}\n',
        '         if(inputProfile!=null)inputProfile.watch(link);')
    s=after(s,'            rasterProbe=new FirstRasterSceneProbe(mod);\n',
        '''            if(!host&&!solo)inputProfile=new RoomInputCpuProfile(
               function():Boolean{return round==0 && phase=="travel" && target=="random_mane";},
               function():Object {var w:Object=mod.game.world,r:Object=mod.session.rooms;
                  return {phase:phase,round:round,ready:r.ready,busy:r.busy,cover:r.entryPending,
                     pause:w.onPause,exit:w.t_exit,term:r.term,epoch:r.epoch};});''')
    s=after(s,'         rasterProbe.sample();\n','         if(inputProfile!=null)inputProfile.frame();')
    s=after(s,'         inputEvidence.baseline.push(inputSample("baseline-start"));phase="input-baseline";\n',
        '         if(inputProfile!=null)inputProfile.mark("baseline-start",baselineAt);')
    s=after(s,'         var row:Object=inputSample("baseline-frame");inputEvidence.baseline.push(row);\n',
        '         if(inputProfile!=null)inputProfile.mark("baseline-frame",int(row.t));')
    s=after(s,'      private function inputError(label:String):void {\n',
        '         if(inputProfile!=null)inputProfile.stop("input-failure");')
    s=after(s,'         check(true,"native travel and input restoration finished");\n',
        '         if(inputProfile!=null && round==0)inputProfile.stop("round0-input-complete");')
    # At normal finish all three original rounds have already measured input.
    # On failure inputError stops before JSON/log/leave cleanup.
    s=after(s,'         if(metrics!=null)metrics.finish();\n',
        '         if(inputProfile!=null)inputProfile.finish();')
    assert strip(s)==original,'Removing diagnostic inserts must recover the exact frozen driver'
    for source in sorted((BASE/'tests').glob('*.as')):
        write(HERE/'tests'/source.name,s if source.name=='RoomTravelTimingTestDoc.as' else source.read_text('utf-8-sig'))
    write(HERE/'tests/RoomInputCpuProfile.as',(HERE/'RoomInputCpuProfile.as').read_text('utf-8'))
    write(HERE/'driver.patch',''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='frozen-shared-scene/RoomTravelTimingTestDoc.as',tofile='input-cpu/RoomTravelTimingTestDoc.as')))
    write(HERE/'driver-inputs.json',json.dumps(dict(sources={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))},
        ancestor=str(BASE.relative_to(ROOT)),ancestor_manifest_sha256=BASE_PIN,diagnostic_only=True,
        original_driver_recovered_by_stripping=True,compiled=False,runtime_tested=False),indent=2)+'\n')
    print('Generated source-only CPU diagnostic; no JVM/AIR')
if __name__=='__main__':main()
