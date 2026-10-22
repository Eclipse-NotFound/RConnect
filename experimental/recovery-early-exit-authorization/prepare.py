"""Prepare only source and real-class regression components; no compiler/AIR."""
from pathlib import Path
import hashlib,json,re,difflib,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-early-compile-01'
EARLY=ROOT/'experimental/recovery-early-travel'
PIN='10b249871b6d6189f4fab4705dd8d4dae4db619d9b3159972010e8e24791fae6'
VERSION='0.2.24-early-travel2'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*.as'))}
def put(path,s):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(s,encoding='utf-8',newline='\n')
def change(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b,1)
def main():
    assert not (HERE/'src').exists() and not (HERE/'components').exists(),'Already prepared; preserve frozen evidence'
    meta=read(BASE/'prepared.json');before=inventory(BASE/'src')
    assert meta['compiled'] and meta['source']==before and sha(BASE/'RConnectMod.swf')==meta['sha256']==PIN
    inputs={str(BASE/'prepared.json'):sha(BASE/'prepared.json'),str(BASE/'integration.json'):sha(BASE/'integration.json'),str(Path(__file__)):sha(Path(__file__))}
    for p in sorted((BASE/'src').rglob('*.as')):
        rel=p.relative_to(BASE/'src');data=p.read_bytes();inputs[str(p)]=sha(p)
        if rel.as_posix()=='rconnect/core/RoomSync.as':
            old=data.decode('utf-8-sig');s=change(old,'         if(!game.mapGeneration.releaseEarly(id))throw new Error("External travel hold did not release");\n         if(nativeTravel.current!=null)',
                '         if(!game.mapGeneration.releaseEarly(id))throw new Error("External travel hold did not release");\n         TravelGuard.endTravel();\n         if(nativeTravel.current!=null)')
            s=change(s,'               TravelGuard.endTravel();\n               if(completingEarly) {','               if(!completingEarly)TravelGuard.endTravel();\n               if(completingEarly) {')
            data=s.encode('utf-8');put(HERE/'RoomSync.patch',''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='early1/RoomSync.as',tofile='early2/RoomSync.as')))
        elif rel.as_posix()=='RConnectMod.as':
            s=data.decode('utf-8-sig');s=change(s,'0.2.24-early-travel1',VERSION);data=s.encode('utf-8')
        dest=HERE/'src'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    after=inventory(HERE/'src');changed=sorted(n for n in before if before[n]!=after[n])
    assert changed==['RConnectMod.as','rconnect/core/RoomSync.as'] and len(after)==len(before)==90
    components=read(EARLY/'component-inputs.json')
    for group,files in components['components'].items():
        for rel,h in files.items():
            source=EARLY/'components'/group/rel;assert sha(source)==h;inputs[str(source)]=h
            dest=HERE/'components'/group/rel;dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(HERE/'src/rconnect/core/RoomSync.as' if rel=='rconnect/core/RoomSync.as' else source,dest)
    # New guard regression uses the full actual classes. Only native I/O and
    # unused page-click access are fixtures; old component assertions stay exact.
    for kind in ('guard-fixed','guard-baseline'):
        dest=HERE/'components'/kind;shutil.copytree(HERE/'components/room',dest)
        shutil.copyfile(BASE/'src/rconnect/core/TravelGuard.as',dest/'rconnect/core/TravelGuard.as')
        if kind=='guard-baseline':shutil.copyfile(BASE/'src/rconnect/core/RoomSync.as',dest/'rconnect/core/RoomSync.as')
        put(dest/'fe/inter/RConnectTravelAccess.as','package fe.inter { import flash.display.DisplayObject; public class RConnectTravelAccess { public static function blocked(page:Object,target:DisplayObject):Boolean {return false;} } }\n')
        shutil.copyfile(HERE/'tests/EarlyExitAuthorizationChecks.as',dest/'EarlyExitAuthorizationChecks.as')
    inputs[str(HERE/'tests/EarlyExitAuthorizationChecks.as')]=sha(HERE/'tests/EarlyExitAuthorizationChecks.as')
    assert inventory(BASE/'src')==before and all(sha(Path(p))==h for p,h in inputs.items())
    integration=dict(version=VERSION,baseline=str(BASE),baseline_sha256=PIN,input_sources=inputs,
        source=[{'path':n,'sha256':h} for n,h in after.items()],static_errors=[],changed=changed,added=[],
        compiled=False,runtime_tested=False,diagnostic_only=True,requires_host='exact early 2D415D',requires_external_contract='sandy-travel-hold/1')
    put(HERE/'integration.json',json.dumps(integration,indent=2)+'\n')
    put(HERE/'component-inputs.json',json.dumps(dict(original=str(EARLY/'component-inputs.json'),original_sha256=sha(EARLY/'component-inputs.json'),
        components={g.name:inventory(g) for g in sorted((HERE/'components').iterdir()) if g.is_dir()},
        old_assertions_unchanged=True,new_guard_entry='EarlyExitAuthorizationChecks.as',compiled=False,air_started=False),indent=2)+'\n')
    print(json.dumps({'classes':len(after),'changed':changed,'compiled':False,'air_started':False}))
if __name__=='__main__':main()
